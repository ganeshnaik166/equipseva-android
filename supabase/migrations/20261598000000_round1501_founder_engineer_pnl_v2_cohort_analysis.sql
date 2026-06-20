BEGIN;

-- ============================================================================
-- Round 1501 — Founder Engineer P&L v2 with Cohort Analysis
-- Extends r1434 P&L with cohort cuts (signup-month × tier × utilization)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: founder_engineer_cohort_snapshots
-- Persisted monthly cohort buckets — recomputed weekly
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_cohort_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL DEFAULT CURRENT_DATE,
  signup_month date NOT NULL,
  current_tier text NOT NULL,
  utilization_bucket text NOT NULL,
  engineer_count int NOT NULL DEFAULT 0,
  active_engineer_count int NOT NULL DEFAULT 0,
  total_revenue_rupees bigint NOT NULL DEFAULT 0,
  total_payout_rupees bigint NOT NULL DEFAULT 0,
  total_gross_margin_rupees bigint NOT NULL DEFAULT 0,
  avg_jobs_per_engineer numeric(10,2) NOT NULL DEFAULT 0,
  avg_ltv_rupees bigint NOT NULL DEFAULT 0,
  avg_rating numeric(3,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(snapshot_date, signup_month, current_tier, utilization_bucket)
);

ALTER TABLE founder_engineer_cohort_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_cohort_snapshots ON founder_engineer_cohort_snapshots;
CREATE POLICY founder_only_cohort_snapshots ON founder_engineer_cohort_snapshots
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_cohort_snap_date ON founder_engineer_cohort_snapshots(snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_cohort_snap_signup ON founder_engineer_cohort_snapshots(signup_month DESC);

-- ----------------------------------------------------------------------------
-- Table 2: founder_engineer_ltv_profiles
-- High-LTV engineer profile snapshots — top performers identified
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_engineer_ltv_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL,
  computed_at timestamptz NOT NULL DEFAULT now(),
  signup_month date NOT NULL,
  months_active numeric(8,2) NOT NULL DEFAULT 0,
  current_tier text NOT NULL,
  total_jobs int NOT NULL DEFAULT 0,
  total_revenue_rupees bigint NOT NULL DEFAULT 0,
  total_payout_rupees bigint NOT NULL DEFAULT 0,
  ltv_rupees bigint NOT NULL DEFAULT 0,
  ltv_percentile numeric(5,2),
  utilization_pct numeric(5,2),
  avg_rating numeric(3,2),
  is_high_ltv boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_engineer_ltv_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_ltv_profiles ON founder_engineer_ltv_profiles;
CREATE POLICY founder_only_ltv_profiles ON founder_engineer_ltv_profiles
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_ltv_engineer ON founder_engineer_ltv_profiles(engineer_id);
CREATE INDEX IF NOT EXISTS idx_ltv_computed ON founder_engineer_ltv_profiles(computed_at DESC);
CREATE INDEX IF NOT EXISTS idx_ltv_high ON founder_engineer_ltv_profiles(is_high_ltv) WHERE is_high_ltv;

-- ============================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_cohort_recompute(p_snapshot_count int)
RETURNS void
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email')::text, 'cohort_recompute',
          jsonb_build_object('snapshot_count', p_snapshot_count, 'at', now()));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cohort_recompute(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cohort_recompute(int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ltv_profile_refresh(p_engineer_count int)
RETURNS void
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email')::text, 'ltv_profile_refresh',
          jsonb_build_object('engineer_count', p_engineer_count, 'at', now()));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_ltv_profile_refresh(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ltv_profile_refresh(int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cohort_view(p_filter text)
RETURNS void
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email')::text, 'cohort_view',
          jsonb_build_object('filter', p_filter, 'at', now()));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_cohort_view(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cohort_view(text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_high_ltv_export(p_count int)
RETURNS void
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email')::text, 'high_ltv_export',
          jsonb_build_object('count', p_count, 'at', now()));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_high_ltv_export(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_high_ltv_export(int) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE SECDEF)
-- ============================================================================

-- RPC 1: Top-level KPIs for the P&L v2 page
CREATE OR REPLACE FUNCTION founder_engineer_pnl_v2_kpis()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH eng AS (
    SELECT e.id AS engineer_id,
           e.user_id,
           e.cached_highest_tier AS tier,
           date_trunc('month', e.created_at)::date AS signup_month,
           EXTRACT(EPOCH FROM (now() - e.created_at))/86400.0 AS days_active
    FROM engineers e
  ),
  jobs AS (
    SELECT rj.engineer_id,
           COUNT(*) AS n_jobs,
           COALESCE(SUM(rj.contracted_amount_rupees),0) AS revenue
    FROM repair_jobs rj
    WHERE rj.status='completed' AND rj.engineer_id IS NOT NULL
    GROUP BY rj.engineer_id
  ),
  payouts AS (
    SELECT ep.engineer_user_id, COALESCE(SUM(ep.amount_rupees),0) AS paid
    FROM engineer_payouts ep
    WHERE ep.paid_at IS NOT NULL
    GROUP BY ep.engineer_user_id
  )
  SELECT jsonb_build_object(
    'total_engineers', (SELECT COUNT(*) FROM eng),
    'total_revenue_rupees', COALESCE((SELECT SUM(revenue) FROM jobs),0),
    'total_payout_rupees', COALESCE((SELECT SUM(paid) FROM payouts),0),
    'gross_margin_rupees', COALESCE((SELECT SUM(revenue) FROM jobs),0) - COALESCE((SELECT SUM(paid) FROM payouts),0),
    'distinct_cohorts', (SELECT COUNT(DISTINCT signup_month) FROM eng),
    'tiers_active', (SELECT COUNT(DISTINCT tier) FROM eng),
    'avg_revenue_per_eng', COALESCE((SELECT SUM(revenue) FROM jobs),0) / GREATEST((SELECT COUNT(*) FROM eng),1),
    'avg_payout_per_eng', COALESCE((SELECT SUM(paid) FROM payouts),0) / GREATEST((SELECT COUNT(*) FROM eng),1),
    'high_ltv_count', (SELECT COUNT(*) FROM founder_engineer_ltv_profiles WHERE is_high_ltv AND computed_at > now() - interval '30 days'),
    'avg_ltv_rupees', COALESCE((SELECT AVG(ltv_rupees)::bigint FROM founder_engineer_ltv_profiles WHERE computed_at > now() - interval '30 days'),0),
    'top_cohort_month', (SELECT to_char(signup_month,'YYYY-MM') FROM founder_engineer_cohort_snapshots ORDER BY total_gross_margin_rupees DESC LIMIT 1),
    'top_tier', (SELECT current_tier FROM founder_engineer_cohort_snapshots ORDER BY avg_ltv_rupees DESC LIMIT 1),
    'snapshots_total', (SELECT COUNT(*) FROM founder_engineer_cohort_snapshots),
    'ltv_profiles_total', (SELECT COUNT(*) FROM founder_engineer_ltv_profiles),
    'last_snapshot_at', (SELECT MAX(snapshot_date)::text FROM founder_engineer_cohort_snapshots),
    'last_ltv_at', (SELECT MAX(computed_at)::text FROM founder_engineer_ltv_profiles)
  ) INTO v_result;
  RETURN v_result;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_pnl_v2_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_pnl_v2_kpis() TO authenticated;

-- RPC 2: Cohort matrix (signup_month × tier × utilization)
CREATE OR REPLACE FUNCTION founder_engineer_cohort_matrix()
RETURNS TABLE (
  id text,
  signup_month text,
  current_tier text,
  utilization_bucket text,
  engineer_count int,
  active_engineer_count int,
  total_revenue_rupees bigint,
  total_payout_rupees bigint,
  total_gross_margin_rupees bigint,
  avg_ltv_rupees bigint,
  avg_rating numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id::text,
         to_char(s.signup_month,'YYYY-MM'),
         s.current_tier,
         s.utilization_bucket,
         s.engineer_count,
         s.active_engineer_count,
         s.total_revenue_rupees,
         s.total_payout_rupees,
         s.total_gross_margin_rupees,
         s.avg_ltv_rupees,
         s.avg_rating
  FROM founder_engineer_cohort_snapshots s
  WHERE s.snapshot_date = (SELECT MAX(snapshot_date) FROM founder_engineer_cohort_snapshots)
  ORDER BY s.signup_month DESC, s.current_tier, s.utilization_bucket;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_cohort_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_cohort_matrix() TO authenticated;

-- RPC 3: Retention curves by cohort
CREATE OR REPLACE FUNCTION founder_engineer_retention_curves()
RETURNS TABLE (
  id text,
  signup_month text,
  cohort_size int,
  m0_active int,
  m1_active int,
  m3_active int,
  m6_active int,
  m12_active int,
  retention_m6_pct numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH cohorts AS (
    SELECT date_trunc('month', e.created_at)::date AS signup_month,
           e.id AS engineer_id,
           e.created_at
    FROM engineers e
    WHERE e.created_at > now() - interval '24 months'
  ),
  job_months AS (
    SELECT rj.engineer_id,
           date_trunc('month', rj.created_at)::date AS job_month
    FROM repair_jobs rj
    WHERE rj.status='completed' AND rj.engineer_id IS NOT NULL
    GROUP BY rj.engineer_id, date_trunc('month', rj.created_at)
  ),
  active AS (
    SELECT c.signup_month,
           c.engineer_id,
           FLOOR(EXTRACT(EPOCH FROM (jm.job_month - c.signup_month))/86400.0/30.0)::int AS month_offset
    FROM cohorts c
    JOIN job_months jm ON jm.engineer_id = c.engineer_id
  )
  SELECT (c.signup_month::text)::text,
         to_char(c.signup_month,'YYYY-MM'),
         COUNT(DISTINCT c.engineer_id)::int,
         COUNT(DISTINCT CASE WHEN a.month_offset=0 THEN a.engineer_id END)::int,
         COUNT(DISTINCT CASE WHEN a.month_offset=1 THEN a.engineer_id END)::int,
         COUNT(DISTINCT CASE WHEN a.month_offset=3 THEN a.engineer_id END)::int,
         COUNT(DISTINCT CASE WHEN a.month_offset=6 THEN a.engineer_id END)::int,
         COUNT(DISTINCT CASE WHEN a.month_offset=12 THEN a.engineer_id END)::int,
         ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.month_offset=6 THEN a.engineer_id END)::numeric / GREATEST(COUNT(DISTINCT c.engineer_id),1), 2)
  FROM cohorts c
  LEFT JOIN active a ON a.engineer_id = c.engineer_id
  GROUP BY c.signup_month
  ORDER BY c.signup_month DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_retention_curves() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_retention_curves() TO authenticated;

-- RPC 4: High-LTV engineer profiles
CREATE OR REPLACE FUNCTION founder_engineer_high_ltv_profiles()
RETURNS TABLE (
  id text,
  engineer_id text,
  signup_month text,
  current_tier text,
  months_active numeric,
  total_jobs int,
  total_revenue_rupees bigint,
  ltv_rupees bigint,
  ltv_percentile numeric,
  utilization_pct numeric,
  avg_rating numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id::text,
         p.engineer_id::text,
         to_char(p.signup_month,'YYYY-MM'),
         p.current_tier,
         p.months_active,
         p.total_jobs,
         p.total_revenue_rupees,
         p.ltv_rupees,
         p.ltv_percentile,
         p.utilization_pct,
         p.avg_rating
  FROM founder_engineer_ltv_profiles p
  WHERE p.is_high_ltv = true
    AND p.computed_at > now() - interval '60 days'
  ORDER BY p.ltv_rupees DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_high_ltv_profiles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_high_ltv_profiles() TO authenticated;

-- RPC 5: Tier x utilization heatmap
CREATE OR REPLACE FUNCTION founder_engineer_tier_util_heatmap()
RETURNS TABLE (
  id text,
  current_tier text,
  utilization_bucket text,
  engineer_count bigint,
  avg_ltv_rupees bigint,
  total_revenue_rupees bigint,
  total_gross_margin_rupees bigint
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (s.current_tier||'_'||s.utilization_bucket)::text,
         s.current_tier,
         s.utilization_bucket,
         SUM(s.engineer_count)::bigint,
         (AVG(s.avg_ltv_rupees))::bigint,
         SUM(s.total_revenue_rupees)::bigint,
         SUM(s.total_gross_margin_rupees)::bigint
  FROM founder_engineer_cohort_snapshots s
  WHERE s.snapshot_date = (SELECT MAX(snapshot_date) FROM founder_engineer_cohort_snapshots)
  GROUP BY s.current_tier, s.utilization_bucket
  ORDER BY s.current_tier, s.utilization_bucket;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_tier_util_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_tier_util_heatmap() TO authenticated;

-- RPC 6: Monthly cohort trend (avg ltv over time)
CREATE OR REPLACE FUNCTION founder_engineer_cohort_trend()
RETURNS TABLE (
  id text,
  signup_month text,
  cohort_size bigint,
  avg_ltv_rupees bigint,
  total_gross_margin_rupees bigint,
  avg_rating numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (s.signup_month::text)::text,
         to_char(s.signup_month,'YYYY-MM'),
         SUM(s.engineer_count)::bigint,
         (AVG(s.avg_ltv_rupees))::bigint,
         SUM(s.total_gross_margin_rupees)::bigint,
         AVG(s.avg_rating)
  FROM founder_engineer_cohort_snapshots s
  WHERE s.snapshot_date = (SELECT MAX(snapshot_date) FROM founder_engineer_cohort_snapshots)
  GROUP BY s.signup_month
  ORDER BY s.signup_month DESC
  LIMIT 24;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_cohort_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_cohort_trend() TO authenticated;

-- RPC 7: Recompute cohort snapshots (VOLATILE — write layer)
CREATE OR REPLACE FUNCTION founder_recompute_engineer_cohorts()
RETURNS int
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_inserted int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  WITH eng AS (
    SELECT e.id AS engineer_id,
           e.user_id,
           COALESCE(e.cached_highest_tier,'none') AS tier,
           date_trunc('month', e.created_at)::date AS signup_month
    FROM engineers e
  ),
  jobs AS (
    SELECT rj.engineer_id,
           COUNT(*)::int AS n_jobs,
           COALESCE(SUM(rj.contracted_amount_rupees),0)::bigint AS revenue,
           AVG(rj.hospital_rating)::numeric AS rating
    FROM repair_jobs rj
    WHERE rj.status='completed' AND rj.engineer_id IS NOT NULL
    GROUP BY rj.engineer_id
  ),
  payouts AS (
    SELECT ep.engineer_user_id, COALESCE(SUM(ep.amount_rupees),0)::bigint AS paid
    FROM engineer_payouts ep
    WHERE ep.paid_at IS NOT NULL
    GROUP BY ep.engineer_user_id
  ),
  combined AS (
    SELECT e.signup_month,
           e.tier,
           CASE
             WHEN COALESCE(j.n_jobs,0) = 0 THEN 'inactive'
             WHEN j.n_jobs < 5 THEN 'low'
             WHEN j.n_jobs < 20 THEN 'medium'
             ELSE 'high'
           END AS util_bucket,
           e.engineer_id,
           COALESCE(j.n_jobs,0) AS n_jobs,
           COALESCE(j.revenue,0) AS revenue,
           COALESCE(p.paid,0) AS paid,
           j.rating
    FROM eng e
    LEFT JOIN jobs j ON j.engineer_id = e.engineer_id
    LEFT JOIN payouts p ON p.engineer_user_id = e.user_id
  )
  INSERT INTO founder_engineer_cohort_snapshots(
    snapshot_date, signup_month, current_tier, utilization_bucket,
    engineer_count, active_engineer_count,
    total_revenue_rupees, total_payout_rupees, total_gross_margin_rupees,
    avg_jobs_per_engineer, avg_ltv_rupees, avg_rating
  )
  SELECT CURRENT_DATE,
         signup_month,
         tier,
         util_bucket,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE n_jobs > 0)::int,
         SUM(revenue),
         SUM(paid),
         SUM(revenue) - SUM(paid),
         AVG(n_jobs)::numeric(10,2),
         (AVG(revenue - paid))::bigint,
         AVG(rating)::numeric(3,2)
  FROM combined
  GROUP BY signup_month, tier, util_bucket
  ON CONFLICT (snapshot_date, signup_month, current_tier, utilization_bucket)
  DO UPDATE SET
    engineer_count = EXCLUDED.engineer_count,
    active_engineer_count = EXCLUDED.active_engineer_count,
    total_revenue_rupees = EXCLUDED.total_revenue_rupees,
    total_payout_rupees = EXCLUDED.total_payout_rupees,
    total_gross_margin_rupees = EXCLUDED.total_gross_margin_rupees,
    avg_jobs_per_engineer = EXCLUDED.avg_jobs_per_engineer,
    avg_ltv_rupees = EXCLUDED.avg_ltv_rupees,
    avg_rating = EXCLUDED.avg_rating;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  PERFORM log_founder_cohort_recompute(v_inserted);
  RETURN v_inserted;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_recompute_engineer_cohorts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_recompute_engineer_cohorts() TO authenticated;

COMMIT;