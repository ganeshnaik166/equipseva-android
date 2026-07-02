BEGIN;

-- ============================================================================
-- r2271: Hospital Pricing-Power Assessment
-- Track rate-hike outcomes by hospital + compute price-elasticity score
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_rate_hike_events_r2271 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier_1','tier_2','tier_3','government','chain')),
  hike_category text NOT NULL CHECK (hike_category IN ('amc_renewal','spare_part','labor_rate','emergency_callout','consumable')),
  old_rate_rupees numeric(12,2) NOT NULL CHECK (old_rate_rupees > 0),
  new_rate_rupees numeric(12,2) NOT NULL CHECK (new_rate_rupees > 0),
  hike_pct numeric(6,2) NOT NULL,
  proposed_at timestamptz NOT NULL DEFAULT now(),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','accepted','negotiated_down','rejected','churned')),
  final_rate_rupees numeric(12,2),
  pushback_notes text,
  decided_at timestamptz,
  decided_by_email text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rate_hike_hospital_r2271
  ON public.hospital_rate_hike_events_r2271(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_rate_hike_outcome_r2271
  ON public.hospital_rate_hike_events_r2271(outcome);
CREATE INDEX IF NOT EXISTS idx_rate_hike_proposed_r2271
  ON public.hospital_rate_hike_events_r2271(proposed_at DESC);

ALTER TABLE public.hospital_rate_hike_events_r2271 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_rate_hikes_r2271 ON public.hospital_rate_hike_events_r2271;
CREATE POLICY founder_all_rate_hikes_r2271 ON public.hospital_rate_hike_events_r2271
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_elasticity_scores_r2271 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  hospital_tier text NOT NULL CHECK (hospital_tier IN ('tier_1','tier_2','tier_3','government','chain')),
  elasticity_score numeric(5,2) NOT NULL CHECK (elasticity_score BETWEEN 0 AND 100),
  power_band text NOT NULL CHECK (power_band IN ('locked_in','high_power','medium_power','low_power','at_risk')),
  total_hikes_proposed int NOT NULL DEFAULT 0,
  accepted_count int NOT NULL DEFAULT 0,
  negotiated_count int NOT NULL DEFAULT 0,
  rejected_count int NOT NULL DEFAULT 0,
  churned_count int NOT NULL DEFAULT 0,
  avg_accepted_hike_pct numeric(6,2),
  last_assessed_at timestamptz NOT NULL DEFAULT now(),
  recommended_action text NOT NULL CHECK (recommended_action IN ('push_harder','steady_hold','soften_terms','lock_msa','offboard')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(hospital_org_id)
);

CREATE INDEX IF NOT EXISTS idx_elasticity_score_r2271
  ON public.hospital_elasticity_scores_r2271(elasticity_score DESC);
CREATE INDEX IF NOT EXISTS idx_elasticity_band_r2271
  ON public.hospital_elasticity_scores_r2271(power_band);

ALTER TABLE public.hospital_elasticity_scores_r2271 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_elasticity_r2271 ON public.hospital_elasticity_scores_r2271;
CREATE POLICY founder_all_elasticity_r2271 ON public.hospital_elasticity_scores_r2271
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================

INSERT INTO public.hospital_rate_hike_events_r2271
  (hospital_org_id, hospital_name, hospital_tier, hike_category, old_rate_rupees, new_rate_rupees, hike_pct, outcome, final_rate_rupees, pushback_notes, decided_at, decided_by_email)
SELECT
  o.id,
  'Apollo Hospitals Hyderabad',
  'tier_1',
  'amc_renewal',
  240000, 288000, 20.00,
  'accepted', 288000, 'CFO approved on first ask. Strong dependency on our engineer pool.',
  now() - interval '14 days', 'cfo@apollo-hyd.example'
FROM public.organizations o LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO public.hospital_rate_hike_events_r2271
  (hospital_org_id, hospital_name, hospital_tier, hike_category, old_rate_rupees, new_rate_rupees, hike_pct, outcome, final_rate_rupees, pushback_notes, decided_at, decided_by_email)
SELECT
  o.id,
  'Yashoda Hospitals Secunderabad',
  'chain',
  'spare_part',
  85000, 102000, 20.00,
  'negotiated_down', 93500, 'Procurement pushed back. Settled at 10 pct hike with 2-year price lock.',
  now() - interval '21 days', 'procurement@yashoda.example'
FROM public.organizations o LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO public.hospital_rate_hike_events_r2271
  (hospital_org_id, hospital_name, hospital_tier, hike_category, old_rate_rupees, new_rate_rupees, hike_pct, outcome, final_rate_rupees, pushback_notes, decided_at, decided_by_email)
SELECT
  o.id,
  'KIMS Kondapur',
  'tier_2',
  'labor_rate',
  3500, 4200, 20.00,
  'rejected', NULL, 'Asked us to match competitor quote at flat 3500. Held the line.',
  now() - interval '7 days', 'admin@kims-kondapur.example'
FROM public.organizations o LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO public.hospital_rate_hike_events_r2271
  (hospital_org_id, hospital_name, hospital_tier, hike_category, old_rate_rupees, new_rate_rupees, hike_pct, outcome, final_rate_rupees, pushback_notes, decided_at, decided_by_email)
SELECT
  o.id,
  'Govt General Hospital Gandhi',
  'government',
  'amc_renewal',
  180000, 216000, 20.00,
  'churned', NULL, 'Lost tender to L1 bidder. Cannot match govt price floor.',
  now() - interval '40 days', 'tender@ggh.example'
FROM public.organizations o LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO public.hospital_rate_hike_events_r2271
  (hospital_org_id, hospital_name, hospital_tier, hike_category, old_rate_rupees, new_rate_rupees, hike_pct, outcome, final_rate_rupees, pushback_notes, decided_at, decided_by_email)
SELECT
  o.id,
  'Care Hospitals Banjara Hills',
  'tier_1',
  'emergency_callout',
  6000, 7500, 25.00,
  'accepted', 7500, 'Critical-care wing needs 4-hour SLA. Price-insensitive segment.',
  now() - interval '5 days', 'biomed@care-bh.example'
FROM public.organizations o LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO public.hospital_rate_hike_events_r2271
  (hospital_org_id, hospital_name, hospital_tier, hike_category, old_rate_rupees, new_rate_rupees, hike_pct, outcome, final_rate_rupees, pushback_notes, decided_at, decided_by_email)
SELECT
  o.id,
  'Sunshine Hospitals Gachibowli',
  'tier_2',
  'consumable',
  1200, 1440, 20.00,
  'pending',
  NULL,
  'Quote sent. Awaiting purchase committee review.',
  NULL, NULL
FROM public.organizations o LIMIT 1
ON CONFLICT DO NOTHING;

-- ============================================================================

INSERT INTO public.hospital_elasticity_scores_r2271
  (hospital_org_id, hospital_name, hospital_tier, elasticity_score, power_band,
   total_hikes_proposed, accepted_count, negotiated_count, rejected_count, churned_count,
   avg_accepted_hike_pct, recommended_action, notes)
SELECT
  o.id,
  'Apollo Hospitals Hyderabad',
  'tier_1',
  18.50, 'locked_in', 8, 7, 1, 0, 0, 19.20,
  'push_harder', 'Lowest elasticity in book. Test 25 pct AMC hike next renewal.'
FROM public.organizations o LIMIT 1
ON CONFLICT (hospital_org_id) DO NOTHING;

INSERT INTO public.hospital_elasticity_scores_r2271
  (hospital_org_id, hospital_name, hospital_tier, elasticity_score, power_band,
   total_hikes_proposed, accepted_count, negotiated_count, rejected_count, churned_count,
   avg_accepted_hike_pct, recommended_action, notes)
SELECT
  o.id,
  'Yashoda Hospitals Secunderabad',
  'chain',
  42.00, 'medium_power', 12, 5, 6, 1, 0, 11.80,
  'lock_msa', 'Heavy negotiator. Lock 3-year MSA to remove annual battle.'
FROM public.organizations o LIMIT 1
ON CONFLICT (hospital_org_id) DO NOTHING;

INSERT INTO public.hospital_elasticity_scores_r2271
  (hospital_org_id, hospital_name, hospital_tier, elasticity_score, power_band,
   total_hikes_proposed, accepted_count, negotiated_count, rejected_count, churned_count,
   avg_accepted_hike_pct, recommended_action, notes)
SELECT
  o.id,
  'KIMS Kondapur',
  'tier_2',
  68.00, 'high_power', 6, 1, 2, 3, 0, 8.00,
  'soften_terms', 'High pushback. Offer value-add (free preventive visits) instead of price.'
FROM public.organizations o LIMIT 1
ON CONFLICT (hospital_org_id) DO NOTHING;

INSERT INTO public.hospital_elasticity_scores_r2271
  (hospital_org_id, hospital_name, hospital_tier, elasticity_score, power_band,
   total_hikes_proposed, accepted_count, negotiated_count, rejected_count, churned_count,
   avg_accepted_hike_pct, recommended_action, notes)
SELECT
  o.id,
  'Govt General Hospital Gandhi',
  'government',
  92.00, 'at_risk', 4, 0, 1, 1, 2, 0.00,
  'offboard', 'L1-bidder structure makes hikes impossible. Wind down low-margin accounts.'
FROM public.organizations o LIMIT 1
ON CONFLICT (hospital_org_id) DO NOTHING;

INSERT INTO public.hospital_elasticity_scores_r2271
  (hospital_org_id, hospital_name, hospital_tier, elasticity_score, power_band,
   total_hikes_proposed, accepted_count, negotiated_count, rejected_count, churned_count,
   avg_accepted_hike_pct, recommended_action, notes)
SELECT
  o.id,
  'Care Hospitals Banjara Hills',
  'tier_1',
  22.50, 'locked_in', 10, 9, 1, 0, 0, 22.10,
  'push_harder', 'Emergency callout segment is fully price-insensitive. Premium-pricing candidate.'
FROM public.organizations o LIMIT 1
ON CONFLICT (hospital_org_id) DO NOTHING;

INSERT INTO public.hospital_elasticity_scores_r2271
  (hospital_org_id, hospital_name, hospital_tier, elasticity_score, power_band,
   total_hikes_proposed, accepted_count, negotiated_count, rejected_count, churned_count,
   avg_accepted_hike_pct, recommended_action, notes)
SELECT
  o.id,
  'Sunshine Hospitals Gachibowli',
  'tier_2',
  55.00, 'low_power', 5, 2, 2, 1, 0, 9.50,
  'steady_hold', 'Mid-range elasticity. Hold at 10 pct annual cadence and monitor.'
FROM public.organizations o LIMIT 1
ON CONFLICT (hospital_org_id) DO NOTHING;

-- ============================================================================
-- RPC 1: KPI summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r2271_pricing_kpis()
RETURNS TABLE (
  total_hospitals_assessed int,
  locked_in_count int,
  at_risk_count int,
  avg_elasticity numeric,
  total_hikes_logged int,
  acceptance_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.hospital_elasticity_scores_r2271),
    (SELECT COUNT(*) FILTER (WHERE power_band = 'locked_in')::int FROM public.hospital_elasticity_scores_r2271),
    (SELECT COUNT(*) FILTER (WHERE power_band = 'at_risk')::int FROM public.hospital_elasticity_scores_r2271),
    (SELECT ROUND(AVG(elasticity_score), 2) FROM public.hospital_elasticity_scores_r2271),
    (SELECT COUNT(*)::int FROM public.hospital_rate_hike_events_r2271),
    (SELECT
       CASE WHEN COUNT(*) > 0 THEN
         ROUND((COUNT(*) FILTER (WHERE outcome = 'accepted')::numeric * 100 / COUNT(*)), 2)
       ELSE 0 END
     FROM public.hospital_rate_hike_events_r2271
     WHERE outcome != 'pending');
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2271_pricing_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2271_pricing_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: Power-band distribution
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r2271_power_band_distribution()
RETURNS TABLE (
  power_band text,
  hospital_count int,
  avg_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.power_band::text,
    COUNT(*)::int,
    ROUND(AVG(e.elasticity_score), 2)
  FROM public.hospital_elasticity_scores_r2271 e
  GROUP BY e.power_band
  ORDER BY AVG(e.elasticity_score) ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2271_power_band_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2271_power_band_distribution() TO authenticated;

-- ============================================================================
-- RPC 3: Elasticity ranking
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r2271_elasticity_ranking()
RETURNS TABLE (
  hospital_name text,
  hospital_tier text,
  elasticity_score numeric,
  power_band text,
  total_hikes int,
  accepted int,
  rejected int,
  recommended_action text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.hospital_name,
    e.hospital_tier,
    e.elasticity_score,
    e.power_band,
    e.total_hikes_proposed,
    e.accepted_count,
    e.rejected_count,
    e.recommended_action
  FROM public.hospital_elasticity_scores_r2271 e
  ORDER BY e.elasticity_score ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2271_elasticity_ranking() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2271_elasticity_ranking() TO authenticated;

-- ============================================================================
-- RPC 4: Recent hike events
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r2271_recent_hikes()
RETURNS TABLE (
  hospital_name text,
  hike_category text,
  old_rate numeric,
  new_rate numeric,
  hike_pct numeric,
  outcome text,
  final_rate numeric,
  proposed_at timestamptz,
  pushback_notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    h.hospital_name,
    h.hike_category,
    h.old_rate_rupees,
    h.new_rate_rupees,
    h.hike_pct,
    h.outcome,
    h.final_rate_rupees,
    h.proposed_at,
    h.pushback_notes
  FROM public.hospital_rate_hike_events_r2271 h
  ORDER BY h.proposed_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2271_recent_hikes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2271_recent_hikes() TO authenticated;

-- ============================================================================
-- RPC 5: Outcome breakdown by category
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r2271_outcome_by_category()
RETURNS TABLE (
  hike_category text,
  total int,
  accepted int,
  negotiated int,
  rejected int,
  churned int,
  acceptance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    h.hike_category,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE h.outcome = 'accepted'))::int,
    (COUNT(*) FILTER (WHERE h.outcome = 'negotiated_down'))::int,
    (COUNT(*) FILTER (WHERE h.outcome = 'rejected'))::int,
    (COUNT(*) FILTER (WHERE h.outcome = 'churned'))::int,
    CASE WHEN COUNT(*) FILTER (WHERE h.outcome != 'pending') > 0
      THEN ROUND((COUNT(*) FILTER (WHERE h.outcome = 'accepted')::numeric * 100
                  / COUNT(*) FILTER (WHERE h.outcome != 'pending')), 2)
      ELSE 0 END
  FROM public.hospital_rate_hike_events_r2271 h
  GROUP BY h.hike_category
  ORDER BY h.hike_category;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2271_outcome_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2271_outcome_by_category() TO authenticated;

-- ============================================================================
-- RPC 6: Action queue
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r2271_action_queue()
RETURNS TABLE (
  hospital_name text,
  power_band text,
  recommended_action text,
  notes text,
  elasticity_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.hospital_name,
    e.power_band,
    e.recommended_action,
    e.notes,
    e.elasticity_score
  FROM public.hospital_elasticity_scores_r2271 e
  ORDER BY
    CASE e.recommended_action
      WHEN 'push_harder' THEN 1
      WHEN 'lock_msa' THEN 2
      WHEN 'soften_terms' THEN 3
      WHEN 'steady_hold' THEN 4
      WHEN 'offboard' THEN 5
    END,
    e.elasticity_score ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2271_action_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2271_action_queue() TO authenticated;

-- ============================================================================
-- RPC 7: Pending decisions (followups)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_r2271_pending_decisions()
RETURNS TABLE (
  hospital_name text,
  hike_category text,
  hike_pct numeric,
  new_rate numeric,
  days_since_proposed int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    h.hospital_name,
    h.hike_category,
    h.hike_pct,
    h.new_rate_rupees,
    EXTRACT(DAY FROM (now() - h.proposed_at))::int
  FROM public.hospital_rate_hike_events_r2271 h
  WHERE h.outcome = 'pending'
  ORDER BY h.proposed_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_r2271_pending_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_r2271_pending_decisions() TO authenticated;

COMMIT;
