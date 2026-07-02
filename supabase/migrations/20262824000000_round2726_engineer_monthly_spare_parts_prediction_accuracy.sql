BEGIN;

-- ============================================================================
-- Round 2726 — Engineer Monthly Spare Parts Prediction Accuracy
-- ============================================================================

-- Table 1: engineer monthly prediction accuracy ledger
CREATE TABLE IF NOT EXISTS engineer_spare_parts_prediction_accuracy_r2726 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  predicted_parts_count integer NOT NULL CHECK (predicted_parts_count >= 0),
  actual_parts_used integer NOT NULL CHECK (actual_parts_used >= 0),
  exact_match_count integer NOT NULL CHECK (exact_match_count >= 0),
  hit_rate_pct numeric(5,2) NOT NULL CHECK (hit_rate_pct >= 0 AND hit_rate_pct <= 100),
  miss_kind text NOT NULL CHECK (miss_kind IN ('over_predicted','under_predicted','wrong_sku','timing_off','near_perfect')),
  miss_cost_rupees integer NOT NULL CHECK (miss_cost_rupees >= 0),
  calibration_action text NOT NULL CHECK (calibration_action IN ('coach_1on1','model_retrain','tier_review','peer_shadow','no_action','escalate_lead')),
  calibration_due_date date NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_spare_parts_prediction_accuracy_r2726 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_spare_parts_prediction_accuracy_r2726;
CREATE POLICY founder_all ON engineer_spare_parts_prediction_accuracy_r2726
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: monthly miss kind aggregates with coaching outcomes
CREATE TABLE IF NOT EXISTS engineer_prediction_miss_aggregates_r2726 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  miss_kind text NOT NULL CHECK (miss_kind IN ('over_predicted','under_predicted','wrong_sku','timing_off','near_perfect')),
  affected_engineers integer NOT NULL CHECK (affected_engineers >= 0),
  total_miss_cost_rupees integer NOT NULL CHECK (total_miss_cost_rupees >= 0),
  median_hit_rate_pct numeric(5,2) NOT NULL CHECK (median_hit_rate_pct >= 0 AND median_hit_rate_pct <= 100),
  recommended_action text NOT NULL CHECK (recommended_action IN ('coach_1on1','model_retrain','tier_review','peer_shadow','no_action','escalate_lead')),
  improvement_target_pct numeric(5,2) NOT NULL CHECK (improvement_target_pct >= 0 AND improvement_target_pct <= 100),
  closed boolean NOT NULL DEFAULT false,
  observed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_prediction_miss_aggregates_r2726 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_prediction_miss_aggregates_r2726;
CREATE POLICY founder_all ON engineer_prediction_miss_aggregates_r2726
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed: engineer ledger (6 rows)
INSERT INTO engineer_spare_parts_prediction_accuracy_r2726
  (month_label, engineer_name, engineer_tier, predicted_parts_count, actual_parts_used, exact_match_count, hit_rate_pct, miss_kind, miss_cost_rupees, calibration_action, calibration_due_date)
VALUES
  ('2026-06', 'Ravi Kumar', 'platinum', 42, 41, 38, 90.48, 'near_perfect', 1200, 'no_action', '2026-07-15'::date),
  ('2026-06', 'Suresh Reddy', 'gold', 38, 45, 28, 73.68, 'under_predicted', 8400, 'coach_1on1', '2026-07-10'::date),
  ('2026-06', 'Anita Singh', 'silver', 31, 24, 22, 70.97, 'over_predicted', 5600, 'peer_shadow', '2026-07-12'::date),
  ('2026-06', 'Vijay Patel', 'gold', 36, 35, 24, 66.67, 'wrong_sku', 9200, 'model_retrain', '2026-07-08'::date),
  ('2026-06', 'Deepa Iyer', 'bronze', 28, 30, 14, 50.00, 'timing_off', 7800, 'tier_review', '2026-07-14'::date),
  ('2026-06', 'Mahesh Rao', 'silver', 33, 41, 18, 54.55, 'under_predicted', 11200, 'escalate_lead', '2026-07-05'::date);

-- Seed: aggregates (5 rows)
INSERT INTO engineer_prediction_miss_aggregates_r2726
  (month_label, miss_kind, affected_engineers, total_miss_cost_rupees, median_hit_rate_pct, recommended_action, improvement_target_pct, closed)
VALUES
  ('2026-06', 'near_perfect', 8, 9600, 89.50, 'no_action', 92.00, true),
  ('2026-06', 'under_predicted', 6, 48200, 71.20, 'coach_1on1', 82.00, false),
  ('2026-06', 'over_predicted', 5, 26400, 70.10, 'peer_shadow', 80.00, false),
  ('2026-06', 'wrong_sku', 4, 31600, 65.40, 'model_retrain', 78.00, false),
  ('2026-06', 'timing_off', 3, 18900, 56.20, 'tier_review', 75.00, false);

-- ============================================================================
-- RPCs (7+ founder-gated)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2726_kpis();
CREATE FUNCTION founder_r2726_kpis()
RETURNS TABLE (
  total_engineers integer,
  avg_hit_rate_pct numeric,
  total_miss_cost_rupees bigint,
  open_calibration_actions integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    ROUND(AVG(hit_rate_pct)::numeric, 2),
    COALESCE(SUM(miss_cost_rupees), 0)::bigint,
    COUNT(*) FILTER (WHERE calibration_action <> 'no_action')::integer
  FROM engineer_spare_parts_prediction_accuracy_r2726;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2726_engineer_ledger();
CREATE FUNCTION founder_r2726_engineer_ledger()
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  predicted_parts_count integer,
  actual_parts_used integer,
  hit_rate_pct numeric,
  miss_kind text,
  miss_cost_rupees integer,
  calibration_action text,
  calibration_due_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_name, e.engineer_tier, e.predicted_parts_count, e.actual_parts_used,
         e.hit_rate_pct, e.miss_kind, e.miss_cost_rupees, e.calibration_action, e.calibration_due_date
  FROM engineer_spare_parts_prediction_accuracy_r2726 e
  ORDER BY e.hit_rate_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_engineer_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_engineer_ledger() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2726_miss_kind_aggregates();
CREATE FUNCTION founder_r2726_miss_kind_aggregates()
RETURNS TABLE (
  miss_kind text,
  affected_engineers integer,
  total_miss_cost_rupees integer,
  median_hit_rate_pct numeric,
  recommended_action text,
  improvement_target_pct numeric,
  closed boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.miss_kind, a.affected_engineers, a.total_miss_cost_rupees, a.median_hit_rate_pct,
         a.recommended_action, a.improvement_target_pct, a.closed
  FROM engineer_prediction_miss_aggregates_r2726 a
  ORDER BY a.total_miss_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_miss_kind_aggregates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_miss_kind_aggregates() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2726_top_offenders();
CREATE FUNCTION founder_r2726_top_offenders()
RETURNS TABLE (
  engineer_name text,
  engineer_tier text,
  hit_rate_pct numeric,
  miss_cost_rupees integer,
  calibration_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_name, e.engineer_tier, e.hit_rate_pct, e.miss_cost_rupees, e.calibration_action
  FROM engineer_spare_parts_prediction_accuracy_r2726 e
  WHERE e.hit_rate_pct < 75
  ORDER BY e.miss_cost_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_top_offenders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_top_offenders() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2726_tier_rollup();
CREATE FUNCTION founder_r2726_tier_rollup()
RETURNS TABLE (
  engineer_tier text,
  engineers_count integer,
  avg_hit_rate_pct numeric,
  total_miss_cost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_tier,
         COUNT(*)::integer,
         ROUND(AVG(e.hit_rate_pct)::numeric, 2),
         COALESCE(SUM(e.miss_cost_rupees), 0)::bigint
  FROM engineer_spare_parts_prediction_accuracy_r2726 e
  GROUP BY e.engineer_tier
  ORDER BY AVG(e.hit_rate_pct) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_tier_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_tier_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2726_calibration_queue();
CREATE FUNCTION founder_r2726_calibration_queue()
RETURNS TABLE (
  engineer_name text,
  calibration_action text,
  calibration_due_date date,
  miss_kind text,
  miss_cost_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_name, e.calibration_action, e.calibration_due_date, e.miss_kind, e.miss_cost_rupees
  FROM engineer_spare_parts_prediction_accuracy_r2726 e
  WHERE e.calibration_action <> 'no_action'
  ORDER BY e.calibration_due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_calibration_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_calibration_queue() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2726_open_aggregates();
CREATE FUNCTION founder_r2726_open_aggregates()
RETURNS TABLE (
  miss_kind text,
  affected_engineers integer,
  total_miss_cost_rupees integer,
  recommended_action text,
  improvement_target_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.miss_kind, a.affected_engineers, a.total_miss_cost_rupees, a.recommended_action, a.improvement_target_pct
  FROM engineer_prediction_miss_aggregates_r2726 a
  WHERE a.closed = false
  ORDER BY a.total_miss_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_open_aggregates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_open_aggregates() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2726_close_aggregate(uuid);
CREATE FUNCTION founder_r2726_close_aggregate(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_prediction_miss_aggregates_r2726
     SET closed = true
   WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2726_close_aggregate(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2726_close_aggregate(uuid) TO authenticated;

COMMIT;
