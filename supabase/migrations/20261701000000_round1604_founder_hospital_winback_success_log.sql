BEGIN;

-- ============================================================================
-- r1604 — Founder Hospital Winback Success Log
-- Log every successful churned->reactivated hospital; track cost-to-save vs
-- revenue-regained; share success stories. Founder-only.
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_hospital_winback_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  churned_at timestamptz NOT NULL,
  reactivated_at timestamptz NOT NULL DEFAULT now(),
  days_churned integer,
  prior_amc_tier text,
  new_amc_tier text,
  cost_to_save_rupees integer NOT NULL DEFAULT 0 CHECK (cost_to_save_rupees >= 0),
  revenue_regained_rupees integer NOT NULL DEFAULT 0 CHECK (revenue_regained_rupees >= 0),
  channel text NOT NULL DEFAULT 'founder_outreach',
  owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhwl_org ON founder_hospital_winback_log(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhwl_reactivated ON founder_hospital_winback_log(reactivated_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhwl_channel ON founder_hospital_winback_log(channel);

ALTER TABLE founder_hospital_winback_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhwl_founder_only ON founder_hospital_winback_log;
CREATE POLICY fhwl_founder_only ON founder_hospital_winback_log
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_hospital_winback_story (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  winback_id uuid NOT NULL REFERENCES founder_hospital_winback_log(id) ON DELETE CASCADE,
  headline text NOT NULL,
  body text NOT NULL,
  shareable boolean NOT NULL DEFAULT false,
  shared_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhws_winback ON founder_hospital_winback_story(winback_id);
CREATE INDEX IF NOT EXISTS idx_fhws_shareable ON founder_hospital_winback_story(shareable);

ALTER TABLE founder_hospital_winback_story ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhws_founder_only ON founder_hospital_winback_story;
CREATE POLICY fhws_founder_only ON founder_hospital_winback_story
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_winback_kpis()
RETURNS TABLE(
  total_winbacks bigint,
  winbacks_30d bigint,
  winbacks_90d bigint,
  winbacks_ytd bigint,
  total_cost_to_save_rupees bigint,
  total_revenue_regained_rupees bigint,
  net_revenue_rupees bigint,
  roi_pct numeric,
  avg_days_churned numeric,
  median_cost_per_save_rupees numeric,
  best_channel text,
  shareable_stories bigint,
  top_tier_recovered text,
  hospitals_recovered bigint,
  cost_30d_rupees bigint,
  revenue_30d_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM founder_hospital_winback_log
  ),
  agg AS (
    SELECT
      COUNT(*)::bigint AS total_winbacks,
      COUNT(*) FILTER (WHERE reactivated_at >= now() - interval '30 days')::bigint AS w30,
      COUNT(*) FILTER (WHERE reactivated_at >= now() - interval '90 days')::bigint AS w90,
      COUNT(*) FILTER (WHERE reactivated_at >= date_trunc('year', now()))::bigint AS wytd,
      COALESCE(SUM(cost_to_save_rupees), 0)::bigint AS total_cost,
      COALESCE(SUM(revenue_regained_rupees), 0)::bigint AS total_rev,
      COALESCE(AVG(days_churned), 0)::numeric AS avg_days,
      COUNT(DISTINCT hospital_org_id)::bigint AS hosp_count,
      COALESCE(SUM(cost_to_save_rupees) FILTER (WHERE reactivated_at >= now() - interval '30 days'), 0)::bigint AS cost_30,
      COALESCE(SUM(revenue_regained_rupees) FILTER (WHERE reactivated_at >= now() - interval '30 days'), 0)::bigint AS rev_30
    FROM base
  ),
  med AS (
    SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY cost_to_save_rupees)::numeric AS m FROM base
  ),
  chan AS (
    SELECT channel FROM base GROUP BY channel ORDER BY SUM(revenue_regained_rupees) DESC NULLS LAST LIMIT 1
  ),
  tier AS (
    SELECT new_amc_tier FROM base WHERE new_amc_tier IS NOT NULL
    GROUP BY new_amc_tier ORDER BY COUNT(*) DESC LIMIT 1
  ),
  stories AS (
    SELECT COUNT(*)::bigint AS c FROM founder_hospital_winback_story WHERE shareable = true
  )
  SELECT
    agg.total_winbacks,
    agg.w30, agg.w90, agg.wytd,
    agg.total_cost,
    agg.total_rev,
    (agg.total_rev - agg.total_cost)::bigint,
    CASE WHEN agg.total_cost > 0 THEN ROUND((agg.total_rev - agg.total_cost)::numeric * 100.0 / agg.total_cost, 1) ELSE 0 END,
    ROUND(agg.avg_days, 1),
    COALESCE(med.m, 0),
    COALESCE((SELECT channel FROM chan), '-'),
    COALESCE((SELECT c FROM stories), 0),
    COALESCE((SELECT new_amc_tier FROM tier), '-'),
    agg.hosp_count,
    agg.cost_30,
    agg.rev_30
  FROM agg LEFT JOIN med ON true;
END; $$;

CREATE OR REPLACE FUNCTION founder_winback_recent(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  hospital_name text,
  reactivated_at timestamptz,
  days_churned integer,
  prior_amc_tier text,
  new_amc_tier text,
  cost_to_save_rupees integer,
  revenue_regained_rupees integer,
  net_rupees integer,
  channel text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_name, w.reactivated_at, w.days_churned, w.prior_amc_tier, w.new_amc_tier,
         w.cost_to_save_rupees, w.revenue_regained_rupees,
         (w.revenue_regained_rupees - w.cost_to_save_rupees)::integer,
         w.channel, w.notes
  FROM founder_hospital_winback_log w
  ORDER BY w.reactivated_at DESC
  LIMIT GREATEST(p_limit, 1);
END; $$;

CREATE OR REPLACE FUNCTION founder_winback_by_channel()
RETURNS TABLE(
  channel text,
  winbacks bigint,
  total_cost_rupees bigint,
  total_revenue_rupees bigint,
  net_rupees bigint,
  roi_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.channel,
         COUNT(*)::bigint,
         COALESCE(SUM(w.cost_to_save_rupees), 0)::bigint,
         COALESCE(SUM(w.revenue_regained_rupees), 0)::bigint,
         COALESCE(SUM(w.revenue_regained_rupees - w.cost_to_save_rupees), 0)::bigint,
         CASE WHEN SUM(w.cost_to_save_rupees) > 0
              THEN ROUND(SUM(w.revenue_regained_rupees - w.cost_to_save_rupees)::numeric * 100.0 / SUM(w.cost_to_save_rupees), 1)
              ELSE 0 END
  FROM founder_hospital_winback_log w
  GROUP BY w.channel
  ORDER BY COUNT(*) DESC;
END; $$;

CREATE OR REPLACE FUNCTION founder_winback_monthly_trend()
RETURNS TABLE(
  month_start date,
  winbacks bigint,
  cost_rupees bigint,
  revenue_rupees bigint,
  net_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', w.reactivated_at)::date,
         COUNT(*)::bigint,
         COALESCE(SUM(w.cost_to_save_rupees), 0)::bigint,
         COALESCE(SUM(w.revenue_regained_rupees), 0)::bigint,
         COALESCE(SUM(w.revenue_regained_rupees - w.cost_to_save_rupees), 0)::bigint
  FROM founder_hospital_winback_log w
  WHERE w.reactivated_at >= now() - interval '12 months'
  GROUP BY 1
  ORDER BY 1 DESC;
END; $$;

CREATE OR REPLACE FUNCTION founder_winback_top_saves(p_limit int DEFAULT 10)
RETURNS TABLE(
  id uuid,
  hospital_name text,
  reactivated_at timestamptz,
  net_rupees integer,
  roi_pct numeric,
  channel text,
  has_story boolean
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, w.hospital_name, w.reactivated_at,
         (w.revenue_regained_rupees - w.cost_to_save_rupees)::integer,
         CASE WHEN w.cost_to_save_rupees > 0
              THEN ROUND((w.revenue_regained_rupees - w.cost_to_save_rupees)::numeric * 100.0 / w.cost_to_save_rupees, 1)
              ELSE 0 END,
         w.channel,
         EXISTS(SELECT 1 FROM founder_hospital_winback_story s WHERE s.winback_id = w.id)
  FROM founder_hospital_winback_log w
  ORDER BY (w.revenue_regained_rupees - w.cost_to_save_rupees) DESC NULLS LAST
  LIMIT GREATEST(p_limit, 1);
END; $$;

CREATE OR REPLACE FUNCTION founder_winback_stories(p_limit int DEFAULT 20)
RETURNS TABLE(
  id uuid,
  winback_id uuid,
  hospital_name text,
  headline text,
  body text,
  shareable boolean,
  shared_at timestamptz,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.winback_id, w.hospital_name, s.headline, s.body, s.shareable, s.shared_at, s.created_at
  FROM founder_hospital_winback_story s
  JOIN founder_hospital_winback_log w ON w.id = s.winback_id
  ORDER BY s.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END; $$;

CREATE OR REPLACE FUNCTION founder_winback_tier_movement()
RETURNS TABLE(
  prior_tier text,
  new_tier text,
  moves bigint,
  revenue_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(w.prior_amc_tier, '-'),
         COALESCE(w.new_amc_tier, '-'),
         COUNT(*)::bigint,
         COALESCE(SUM(w.revenue_regained_rupees), 0)::bigint
  FROM founder_hospital_winback_log w
  GROUP BY 1, 2
  ORDER BY COUNT(*) DESC;
END; $$;

-- ============================================================================
-- WRITE helpers (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_winback_record(
  p_hospital_org_id uuid,
  p_hospital_name text,
  p_churned_at timestamptz,
  p_prior_tier text,
  p_new_tier text,
  p_cost_rupees integer,
  p_revenue_rupees integer,
  p_channel text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_days integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_days := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (now() - p_churned_at)) / 86400.0))::integer;
  INSERT INTO founder_hospital_winback_log(
    hospital_org_id, hospital_name, churned_at, reactivated_at, days_churned,
    prior_amc_tier, new_amc_tier, cost_to_save_rupees, revenue_regained_rupees,
    channel, owner_user_id, notes
  ) VALUES (
    p_hospital_org_id, p_hospital_name, p_churned_at, now(), v_days,
    p_prior_tier, p_new_tier, COALESCE(p_cost_rupees, 0), COALESCE(p_revenue_rupees, 0),
    COALESCE(p_channel, 'founder_outreach'), auth.uid(), p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'winback_record',
          jsonb_build_object('winback_id', v_id, 'hospital_org_id', p_hospital_org_id,
                             'cost', p_cost_rupees, 'revenue', p_revenue_rupees));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION log_founder_winback_story(
  p_winback_id uuid,
  p_headline text,
  p_body text,
  p_shareable boolean
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_hospital_winback_story(winback_id, headline, body, shareable)
  VALUES (p_winback_id, p_headline, p_body, COALESCE(p_shareable, false))
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'winback_story',
          jsonb_build_object('story_id', v_id, 'winback_id', p_winback_id, 'shareable', p_shareable));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION log_founder_winback_share(
  p_story_id uuid
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_hospital_winback_story SET shared_at = now(), shareable = true WHERE id = p_story_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'winback_share',
          jsonb_build_object('story_id', p_story_id, 'shared_at', now()));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_winback_delete(
  p_winback_id uuid
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM founder_hospital_winback_log WHERE id = p_winback_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'winback_delete',
          jsonb_build_object('winback_id', p_winback_id));
END; $$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION founder_winback_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_winback_recent(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_winback_by_channel() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_winback_monthly_trend() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_winback_top_saves(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_winback_stories(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_winback_tier_movement() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_winback_record(uuid, text, timestamptz, text, text, integer, integer, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_winback_story(uuid, text, text, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_winback_share(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_winback_delete(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_winback_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_winback_recent(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_winback_by_channel() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_winback_monthly_trend() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_winback_top_saves(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_winback_stories(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_winback_tier_movement() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_winback_record(uuid, text, timestamptz, text, text, integer, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_winback_story(uuid, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_winback_share(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_winback_delete(uuid) TO authenticated;

COMMIT;