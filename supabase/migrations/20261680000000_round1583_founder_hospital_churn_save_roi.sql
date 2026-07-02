BEGIN;

-- r1583: Hospital churn-save dollar ROI
-- Extends r1563 churn-save with explicit ROI math:
--   revenue_saved_12mo_rupees / cost_of_save_rupees
-- Per-action ROI rank for founder triage.

CREATE TABLE IF NOT EXISTS founder_churn_save_roi_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  save_action text NOT NULL CHECK (save_action IN ('discount','free_service','engineer_swap','tier_upgrade','founder_call','sla_upgrade','priority_dispatch','custom')),
  action_taken_at timestamptz NOT NULL DEFAULT now(),
  cost_of_save_rupees numeric(12,2) NOT NULL CHECK (cost_of_save_rupees >= 0),
  amc_monthly_fee_rupees numeric(12,2) NOT NULL DEFAULT 0,
  expected_retention_months int NOT NULL DEFAULT 12 CHECK (expected_retention_months > 0),
  revenue_saved_12mo_rupees numeric(14,2) NOT NULL DEFAULT 0,
  roi_ratio numeric(10,2) GENERATED ALWAYS AS (
    CASE WHEN cost_of_save_rupees > 0
      THEN revenue_saved_12mo_rupees / cost_of_save_rupees
      ELSE NULL END
  ) STORED,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','retained','churned','partial')),
  outcome_checked_at timestamptz,
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcsr_v2_org ON founder_churn_save_roi_v2(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fcsr_v2_action ON founder_churn_save_roi_v2(save_action);
CREATE INDEX IF NOT EXISTS idx_fcsr_v2_taken ON founder_churn_save_roi_v2(action_taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_fcsr_v2_outcome ON founder_churn_save_roi_v2(outcome);
CREATE INDEX IF NOT EXISTS idx_fcsr_v2_roi ON founder_churn_save_roi_v2(roi_ratio DESC NULLS LAST);

ALTER TABLE founder_churn_save_roi_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcsr_v2_founder_all ON founder_churn_save_roi_v2;
CREATE POLICY fcsr_v2_founder_all ON founder_churn_save_roi_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_churn_save_roi_targets_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  save_action text NOT NULL UNIQUE CHECK (save_action IN ('discount','free_service','engineer_swap','tier_upgrade','founder_call','sla_upgrade','priority_dispatch','custom')),
  target_roi_ratio numeric(8,2) NOT NULL DEFAULT 5.0,
  max_cost_rupees numeric(12,2) NOT NULL DEFAULT 50000,
  notes text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE founder_churn_save_roi_targets_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcsr_targets_v2_founder_all ON founder_churn_save_roi_targets_v2;
CREATE POLICY fcsr_targets_v2_founder_all ON founder_churn_save_roi_targets_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO founder_churn_save_roi_targets_v2 (save_action, target_roi_ratio, max_cost_rupees)
VALUES
  ('discount', 6.0, 25000),
  ('free_service', 5.0, 15000),
  ('engineer_swap', 8.0, 5000),
  ('tier_upgrade', 10.0, 10000),
  ('founder_call', 20.0, 2000),
  ('sla_upgrade', 7.0, 20000),
  ('priority_dispatch', 9.0, 8000),
  ('custom', 3.0, 50000)
ON CONFLICT (save_action) DO NOTHING;

-- ============= LOG HELPERS (VOLATILE SECDEF) =============

CREATE OR REPLACE FUNCTION log_founder_churn_save_roi_record(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'churn_save_roi_record', p_after);
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_save_roi_record(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_churn_save_roi_record(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_churn_save_roi_outcome(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'churn_save_roi_outcome', p_after);
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_save_roi_outcome(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_churn_save_roi_outcome(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_churn_save_roi_target_update(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'churn_save_roi_target_update', p_after);
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_save_roi_target_update(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_churn_save_roi_target_update(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_churn_save_roi_recompute(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'churn_save_roi_recompute', p_after);
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_churn_save_roi_recompute(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_churn_save_roi_recompute(jsonb) TO authenticated;

-- ============= READ RPCs (STABLE SECDEF) =============

CREATE OR REPLACE FUNCTION founder_churn_save_roi_kpis()
RETURNS TABLE (
  total_saves int,
  retained_count int,
  churned_count int,
  pending_count int,
  total_cost_rupees numeric,
  total_revenue_saved_rupees numeric,
  blended_roi numeric,
  median_roi numeric,
  top_roi numeric,
  worst_roi numeric,
  saves_last_30d int,
  saves_last_90d int,
  retained_rate_pct numeric,
  cost_per_retained_rupees numeric,
  unique_hospitals int,
  best_action text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM founder_churn_save_roi_v2
  ),
  per_action AS (
    SELECT save_action, AVG(roi_ratio) AS avg_roi
    FROM base WHERE roi_ratio IS NOT NULL
    GROUP BY save_action
    ORDER BY avg_roi DESC NULLS LAST LIMIT 1
  )
  SELECT
    (SELECT COUNT(*)::int FROM base),
    (SELECT COUNT(*)::int FROM base WHERE outcome='retained'),
    (SELECT COUNT(*)::int FROM base WHERE outcome='churned'),
    (SELECT COUNT(*)::int FROM base WHERE outcome='pending'),
    COALESCE((SELECT SUM(cost_of_save_rupees) FROM base),0),
    COALESCE((SELECT SUM(revenue_saved_12mo_rupees) FROM base),0),
    CASE WHEN COALESCE((SELECT SUM(cost_of_save_rupees) FROM base),0) > 0
      THEN (SELECT SUM(revenue_saved_12mo_rupees) FROM base) / (SELECT SUM(cost_of_save_rupees) FROM base)
      ELSE 0 END,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY roi_ratio) FROM base WHERE roi_ratio IS NOT NULL),0),
    COALESCE((SELECT MAX(roi_ratio) FROM base),0),
    COALESCE((SELECT MIN(roi_ratio) FROM base WHERE roi_ratio IS NOT NULL),0),
    (SELECT COUNT(*)::int FROM base WHERE action_taken_at > now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM base WHERE action_taken_at > now() - interval '90 days'),
    CASE WHEN (SELECT COUNT(*) FROM base WHERE outcome IN ('retained','churned')) > 0
      THEN ROUND(100.0 * (SELECT COUNT(*) FROM base WHERE outcome='retained') / (SELECT COUNT(*) FROM base WHERE outcome IN ('retained','churned')),1)
      ELSE 0 END,
    CASE WHEN (SELECT COUNT(*) FROM base WHERE outcome='retained') > 0
      THEN ROUND((SELECT SUM(cost_of_save_rupees) FROM base WHERE outcome='retained') / (SELECT COUNT(*) FROM base WHERE outcome='retained'),0)
      ELSE 0 END,
    (SELECT COUNT(DISTINCT hospital_org_id)::int FROM base),
    COALESCE((SELECT save_action FROM per_action),'-');
END $$;

REVOKE EXECUTE ON FUNCTION founder_churn_save_roi_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_churn_save_roi_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_churn_save_roi_per_action_rank()
RETURNS TABLE (
  id uuid,
  save_action text,
  total_saves int,
  retained_count int,
  churned_count int,
  total_cost_rupees numeric,
  total_revenue_saved_rupees numeric,
  blended_roi numeric,
  median_roi numeric,
  target_roi numeric,
  vs_target_pct numeric,
  rank int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH per AS (
    SELECT
      r.save_action,
      COUNT(*)::int AS total_saves,
      SUM(CASE WHEN r.outcome='retained' THEN 1 ELSE 0 END)::int AS retained_count,
      SUM(CASE WHEN r.outcome='churned' THEN 1 ELSE 0 END)::int AS churned_count,
      SUM(r.cost_of_save_rupees) AS total_cost,
      SUM(r.revenue_saved_12mo_rupees) AS total_rev,
      CASE WHEN SUM(r.cost_of_save_rupees) > 0 THEN SUM(r.revenue_saved_12mo_rupees)/SUM(r.cost_of_save_rupees) ELSE 0 END AS blended,
      percentile_cont(0.5) WITHIN GROUP (ORDER BY r.roi_ratio) AS median_roi
    FROM founder_churn_save_roi_v2 r
    GROUP BY r.save_action
  )
  SELECT
    gen_random_uuid(),
    p.save_action,
    p.total_saves,
    p.retained_count,
    p.churned_count,
    COALESCE(p.total_cost,0),
    COALESCE(p.total_rev,0),
    ROUND(COALESCE(p.blended,0),2),
    ROUND(COALESCE(p.median_roi,0),2),
    COALESCE(t.target_roi_ratio,0),
    CASE WHEN COALESCE(t.target_roi_ratio,0) > 0 THEN ROUND(100.0 * p.blended / t.target_roi_ratio,1) ELSE 0 END,
    (ROW_NUMBER() OVER (ORDER BY p.blended DESC NULLS LAST))::int
  FROM per p
  LEFT JOIN founder_churn_save_roi_targets_v2 t ON t.save_action = p.save_action
  ORDER BY p.blended DESC NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION founder_churn_save_roi_per_action_rank() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_churn_save_roi_per_action_rank() TO authenticated;

CREATE OR REPLACE FUNCTION founder_churn_save_roi_top_saves(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  save_action text,
  action_taken_at timestamptz,
  cost_of_save_rupees numeric,
  revenue_saved_12mo_rupees numeric,
  roi_ratio numeric,
  outcome text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_org_id, o.name, r.save_action, r.action_taken_at,
         r.cost_of_save_rupees, r.revenue_saved_12mo_rupees, r.roi_ratio, r.outcome
  FROM founder_churn_save_roi_v2 r
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.roi_ratio IS NOT NULL
  ORDER BY r.roi_ratio DESC NULLS LAST
  LIMIT GREATEST(p_limit,1);
END $$;

REVOKE EXECUTE ON FUNCTION founder_churn_save_roi_top_saves(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_churn_save_roi_top_saves(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_churn_save_roi_worst_saves(p_limit int DEFAULT 25)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  save_action text,
  action_taken_at timestamptz,
  cost_of_save_rupees numeric,
  revenue_saved_12mo_rupees numeric,
  roi_ratio numeric,
  outcome text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_org_id, o.name, r.save_action, r.action_taken_at,
         r.cost_of_save_rupees, r.revenue_saved_12mo_rupees, r.roi_ratio, r.outcome
  FROM founder_churn_save_roi_v2 r
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.outcome = 'churned' OR (r.roi_ratio IS NOT NULL AND r.roi_ratio < 1.0)
  ORDER BY r.roi_ratio ASC NULLS LAST
  LIMIT GREATEST(p_limit,1);
END $$;

REVOKE EXECUTE ON FUNCTION founder_churn_save_roi_worst_saves(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_churn_save_roi_worst_saves(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_churn_save_roi_recent(p_limit int DEFAULT 40)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  save_action text,
  action_taken_at timestamptz,
  cost_of_save_rupees numeric,
  revenue_saved_12mo_rupees numeric,
  roi_ratio numeric,
  outcome text,
  days_since_action numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, o.name, r.save_action, r.action_taken_at, r.cost_of_save_rupees,
         r.revenue_saved_12mo_rupees, r.roi_ratio, r.outcome,
         ROUND(EXTRACT(EPOCH FROM (now() - r.action_taken_at))/86400.0,1)
  FROM founder_churn_save_roi_v2 r
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  ORDER BY r.action_taken_at DESC
  LIMIT GREATEST(p_limit,1);
END $$;

REVOKE EXECUTE ON FUNCTION founder_churn_save_roi_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_churn_save_roi_recent(int) TO authenticated;

-- ============= WRITE RPCs (VOLATILE SECDEF) =============

CREATE OR REPLACE FUNCTION founder_churn_save_roi_record_save(
  p_hospital_org_id uuid,
  p_save_action text,
  p_cost_of_save_rupees numeric,
  p_amc_monthly_fee_rupees numeric,
  p_expected_retention_months int,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_rev numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_rev := COALESCE(p_amc_monthly_fee_rupees,0) * COALESCE(p_expected_retention_months,12);
  INSERT INTO founder_churn_save_roi_v2 (
    hospital_org_id, save_action, cost_of_save_rupees, amc_monthly_fee_rupees,
    expected_retention_months, revenue_saved_12mo_rupees, notes, created_by
  ) VALUES (
    p_hospital_org_id, p_save_action, p_cost_of_save_rupees, COALESCE(p_amc_monthly_fee_rupees,0),
    COALESCE(p_expected_retention_months,12), v_rev, p_notes, auth.uid()
  ) RETURNING id INTO v_id;
  PERFORM log_founder_churn_save_roi_record(jsonb_build_object('id',v_id,'org',p_hospital_org_id,'action',p_save_action,'cost',p_cost_of_save_rupees,'rev',v_rev));
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION founder_churn_save_roi_record_save(uuid,text,numeric,numeric,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_churn_save_roi_record_save(uuid,text,numeric,numeric,int,text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_churn_save_roi_mark_outcome(
  p_id uuid,
  p_outcome text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_churn_save_roi_v2
  SET outcome = p_outcome, outcome_checked_at = now()
  WHERE id = p_id;
  PERFORM log_founder_churn_save_roi_outcome(jsonb_build_object('id',p_id,'outcome',p_outcome));
END $$;

REVOKE EXECUTE ON FUNCTION founder_churn_save_roi_mark_outcome(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_churn_save_roi_mark_outcome(uuid,text) TO authenticated;

COMMIT;