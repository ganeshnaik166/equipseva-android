BEGIN;

-- =====================================================================
-- r1487 — Founder Competitor Pricing Intel Ladder
-- Capture observed competitor quotes per equipment-category/hospital-tier.
-- Track our-spread vs market; surface under-priced + over-priced segments.
-- =====================================================================

CREATE TABLE IF NOT EXISTS competitor_pricing_observations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  observed_at timestamptz NOT NULL DEFAULT now(),
  equipment_category text NOT NULL,
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier1','tier2','tier3','rural')),
  competitor_name text NOT NULL,
  job_kind text NOT NULL CHECK (job_kind IN ('repair','maintenance','amc')),
  competitor_quote_rupees integer NOT NULL CHECK (competitor_quote_rupees >= 0),
  our_quote_rupees integer CHECK (our_quote_rupees >= 0),
  source text NOT NULL CHECK (source IN ('hospital_reported','engineer_field','public_listing','rfq_loss','other')),
  city text,
  notes text,
  recorded_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cpo_cat_tier ON competitor_pricing_observations(equipment_category, hospital_tier);
CREATE INDEX IF NOT EXISTS idx_cpo_observed ON competitor_pricing_observations(observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_cpo_competitor ON competitor_pricing_observations(competitor_name);

ALTER TABLE competitor_pricing_observations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cpo_founder_all ON competitor_pricing_observations;
CREATE POLICY cpo_founder_all ON competitor_pricing_observations
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS competitor_pricing_segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_category text NOT NULL,
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier1','tier2','tier3','rural')),
  target_spread_pct numeric(6,2) NOT NULL DEFAULT 0,
  floor_price_rupees integer,
  ceiling_price_rupees integer,
  posture text NOT NULL DEFAULT 'neutral' CHECK (posture IN ('aggressive','neutral','premium')),
  notes text,
  updated_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (equipment_category, hospital_tier)
);

CREATE INDEX IF NOT EXISTS idx_cps_cat_tier ON competitor_pricing_segments(equipment_category, hospital_tier);

ALTER TABLE competitor_pricing_segments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cps_founder_all ON competitor_pricing_segments;
CREATE POLICY cps_founder_all ON competitor_pricing_segments
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- LOG HELPERS
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_competitor_obs_added(p_obs_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'competitor_obs_added', jsonb_build_object('obs_id', p_obs_id)
  FROM public.profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_competitor_obs_added(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_competitor_obs_added(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_competitor_obs_deleted(p_obs_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'competitor_obs_deleted', jsonb_build_object('obs_id', p_obs_id)
  FROM public.profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_competitor_obs_deleted(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_competitor_obs_deleted(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_segment_target_set(p_segment_id uuid, p_posture text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'pricing_segment_set', jsonb_build_object('segment_id', p_segment_id, 'posture', p_posture)
  FROM public.profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_segment_target_set(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_segment_target_set(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pricing_review_marked(p_category text, p_tier text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'pricing_review_marked', jsonb_build_object('category', p_category, 'tier', p_tier)
  FROM public.profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_pricing_review_marked(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pricing_review_marked(text, text) TO authenticated;

-- =====================================================================
-- READ RPCs (4)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_competitor_pricing_kpis()
RETURNS TABLE (
  total_observations bigint,
  observations_90d bigint,
  observations_30d bigint,
  observations_7d bigint,
  distinct_competitors bigint,
  distinct_categories bigint,
  distinct_tiers bigint,
  segments_defined bigint,
  segments_aggressive bigint,
  segments_premium bigint,
  avg_competitor_quote_rupees numeric,
  avg_our_quote_rupees numeric,
  avg_spread_pct numeric,
  under_priced_segments bigint,
  over_priced_segments bigint,
  rfq_loss_observations bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM competitor_pricing_observations
  ),
  spreads AS (
    SELECT equipment_category, hospital_tier,
           AVG(competitor_quote_rupees) AS avg_comp,
           AVG(our_quote_rupees) AS avg_ours,
           CASE WHEN AVG(competitor_quote_rupees) > 0
                THEN ((AVG(our_quote_rupees) - AVG(competitor_quote_rupees)) * 100.0 / AVG(competitor_quote_rupees))
                ELSE NULL END AS spread_pct
    FROM base
    WHERE our_quote_rupees IS NOT NULL
    GROUP BY equipment_category, hospital_tier
  )
  SELECT
    (SELECT COUNT(*) FROM base)::bigint,
    (SELECT COUNT(*) FROM base WHERE observed_at >= now() - interval '90 days')::bigint,
    (SELECT COUNT(*) FROM base WHERE observed_at >= now() - interval '30 days')::bigint,
    (SELECT COUNT(*) FROM base WHERE observed_at >= now() - interval '7 days')::bigint,
    (SELECT COUNT(DISTINCT competitor_name) FROM base)::bigint,
    (SELECT COUNT(DISTINCT equipment_category) FROM base)::bigint,
    (SELECT COUNT(DISTINCT hospital_tier) FROM base)::bigint,
    (SELECT COUNT(*) FROM competitor_pricing_segments)::bigint,
    (SELECT COUNT(*) FROM competitor_pricing_segments WHERE posture = 'aggressive')::bigint,
    (SELECT COUNT(*) FROM competitor_pricing_segments WHERE posture = 'premium')::bigint,
    (SELECT ROUND(AVG(competitor_quote_rupees)::numeric, 2) FROM base),
    (SELECT ROUND(AVG(our_quote_rupees)::numeric, 2) FROM base WHERE our_quote_rupees IS NOT NULL),
    (SELECT ROUND(AVG(spread_pct)::numeric, 2) FROM spreads),
    (SELECT COUNT(*) FROM spreads WHERE spread_pct < -10)::bigint,
    (SELECT COUNT(*) FROM spreads WHERE spread_pct > 15)::bigint,
    (SELECT COUNT(*) FROM base WHERE source = 'rfq_loss')::bigint;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_competitor_pricing_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_competitor_pricing_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_competitor_pricing_recent_observations()
RETURNS TABLE (
  id uuid,
  observed_at timestamptz,
  equipment_category text,
  hospital_tier text,
  competitor_name text,
  job_kind text,
  competitor_quote_rupees integer,
  our_quote_rupees integer,
  spread_pct numeric,
  source text,
  city text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.observed_at, o.equipment_category, o.hospital_tier, o.competitor_name,
         o.job_kind, o.competitor_quote_rupees, o.our_quote_rupees,
         CASE WHEN o.our_quote_rupees IS NOT NULL AND o.competitor_quote_rupees > 0
              THEN ROUND(((o.our_quote_rupees - o.competitor_quote_rupees) * 100.0 / o.competitor_quote_rupees)::numeric, 2)
              ELSE NULL END AS spread_pct,
         o.source, o.city
  FROM competitor_pricing_observations o
  ORDER BY o.observed_at DESC
  LIMIT 50;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_competitor_pricing_recent_observations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_competitor_pricing_recent_observations() TO authenticated;

CREATE OR REPLACE FUNCTION founder_competitor_pricing_segment_ladder()
RETURNS TABLE (
  id uuid,
  equipment_category text,
  hospital_tier text,
  observations bigint,
  avg_competitor_rupees numeric,
  avg_our_rupees numeric,
  spread_pct numeric,
  target_spread_pct numeric,
  posture text,
  verdict text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT o.equipment_category, o.hospital_tier,
           COUNT(*) AS observations,
           AVG(o.competitor_quote_rupees)::numeric AS avg_comp,
           AVG(o.our_quote_rupees)::numeric AS avg_ours
    FROM competitor_pricing_observations o
    WHERE o.observed_at >= now() - interval '180 days'
    GROUP BY o.equipment_category, o.hospital_tier
  )
  SELECT s.id, a.equipment_category, a.hospital_tier, a.observations,
         ROUND(a.avg_comp, 2),
         ROUND(a.avg_ours, 2),
         CASE WHEN a.avg_comp > 0
              THEN ROUND(((a.avg_ours - a.avg_comp) * 100.0 / a.avg_comp)::numeric, 2)
              ELSE NULL END AS spread_pct,
         COALESCE(s.target_spread_pct, 0),
         COALESCE(s.posture, 'unset'),
         CASE
           WHEN a.avg_ours IS NULL THEN 'no-our-quote'
           WHEN a.avg_comp = 0 THEN 'no-comp-data'
           WHEN ((a.avg_ours - a.avg_comp) * 100.0 / a.avg_comp) < -10 THEN 'under-priced'
           WHEN ((a.avg_ours - a.avg_comp) * 100.0 / a.avg_comp) > 15 THEN 'over-priced'
           ELSE 'aligned'
         END
  FROM agg a
  LEFT JOIN competitor_pricing_segments s
    ON s.equipment_category = a.equipment_category
   AND s.hospital_tier = a.hospital_tier
  ORDER BY a.observations DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_competitor_pricing_segment_ladder() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_competitor_pricing_segment_ladder() TO authenticated;

CREATE OR REPLACE FUNCTION founder_competitor_pricing_top_competitors()
RETURNS TABLE (
  competitor_name text,
  observations bigint,
  categories_seen bigint,
  tiers_seen bigint,
  avg_quote_rupees numeric,
  last_seen_at timestamptz,
  rfq_losses bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.competitor_name,
         COUNT(*)::bigint,
         COUNT(DISTINCT o.equipment_category)::bigint,
         COUNT(DISTINCT o.hospital_tier)::bigint,
         ROUND(AVG(o.competitor_quote_rupees)::numeric, 2),
         MAX(o.observed_at),
         COUNT(*) FILTER (WHERE o.source = 'rfq_loss')::bigint
  FROM competitor_pricing_observations o
  GROUP BY o.competitor_name
  ORDER BY COUNT(*) DESC
  LIMIT 30;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_competitor_pricing_top_competitors() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_competitor_pricing_top_competitors() TO authenticated;

-- =====================================================================
-- WRITE RPCs (3)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_competitor_pricing_record_observation(
  p_equipment_category text,
  p_hospital_tier text,
  p_competitor_name text,
  p_job_kind text,
  p_competitor_quote_rupees integer,
  p_our_quote_rupees integer,
  p_source text,
  p_city text,
  p_notes text
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO competitor_pricing_observations(
    equipment_category, hospital_tier, competitor_name, job_kind,
    competitor_quote_rupees, our_quote_rupees, source, city, notes, recorded_by
  ) VALUES (
    p_equipment_category, p_hospital_tier, p_competitor_name, p_job_kind,
    p_competitor_quote_rupees, p_our_quote_rupees, p_source, p_city, p_notes, auth.uid()
  ) RETURNING id INTO v_id;
  PERFORM log_founder_competitor_obs_added(v_id);
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_competitor_pricing_record_observation(text,text,text,text,integer,integer,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_competitor_pricing_record_observation(text,text,text,text,integer,integer,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_competitor_pricing_upsert_segment(
  p_equipment_category text,
  p_hospital_tier text,
  p_target_spread_pct numeric,
  p_floor_price_rupees integer,
  p_ceiling_price_rupees integer,
  p_posture text,
  p_notes text
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO competitor_pricing_segments(
    equipment_category, hospital_tier, target_spread_pct,
    floor_price_rupees, ceiling_price_rupees, posture, notes, updated_by, updated_at
  ) VALUES (
    p_equipment_category, p_hospital_tier, p_target_spread_pct,
    p_floor_price_rupees, p_ceiling_price_rupees, p_posture, p_notes, auth.uid(), now()
  )
  ON CONFLICT (equipment_category, hospital_tier) DO UPDATE
    SET target_spread_pct = EXCLUDED.target_spread_pct,
        floor_price_rupees = EXCLUDED.floor_price_rupees,
        ceiling_price_rupees = EXCLUDED.ceiling_price_rupees,
        posture = EXCLUDED.posture,
        notes = EXCLUDED.notes,
        updated_by = auth.uid(),
        updated_at = now()
  RETURNING id INTO v_id;
  PERFORM log_founder_segment_target_set(v_id, p_posture);
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_competitor_pricing_upsert_segment(text,text,numeric,integer,integer,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_competitor_pricing_upsert_segment(text,text,numeric,integer,integer,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_competitor_pricing_delete_observation(p_obs_id uuid)
RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM competitor_pricing_observations WHERE id = p_obs_id;
  PERFORM log_founder_competitor_obs_deleted(p_obs_id);
  RETURN true;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_competitor_pricing_delete_observation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_competitor_pricing_delete_observation(uuid) TO authenticated;

COMMIT;