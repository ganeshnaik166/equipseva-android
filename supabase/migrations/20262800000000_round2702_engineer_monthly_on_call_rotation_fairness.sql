BEGIN;

-- ============================================================================
-- Round 2702: Engineer Monthly On-Call Rotation Fairness
-- ============================================================================

-- Table 1: engineer monthly on-call rotation entries
DROP TABLE IF EXISTS engineer_on_call_rotation_r2702 CASCADE;
CREATE TABLE engineer_on_call_rotation_r2702 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_region text NOT NULL CHECK (engineer_region IN ('north','south','east','west','central')),
  rotation_month date NOT NULL,
  weekday_hours numeric(6,2) NOT NULL DEFAULT 0 CHECK (weekday_hours >= 0),
  weekend_hours numeric(6,2) NOT NULL DEFAULT 0 CHECK (weekend_hours >= 0),
  night_hours numeric(6,2) NOT NULL DEFAULT 0 CHECK (night_hours >= 0),
  total_hours numeric(7,2) NOT NULL DEFAULT 0 CHECK (total_hours >= 0),
  overload_signal text NOT NULL DEFAULT 'normal' CHECK (overload_signal IN ('normal','elevated','high','critical')),
  fairness_score numeric(5,2) NOT NULL DEFAULT 100 CHECK (fairness_score >= 0 AND fairness_score <= 100),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','rebalanced','swapped','closed')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_on_call_rotation_r2702 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_on_call_rotation_r2702;
CREATE POLICY founder_all ON engineer_on_call_rotation_r2702 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: rebalance actions taken to restore fairness
DROP TABLE IF EXISTS on_call_rebalance_actions_r2702 CASCADE;
CREATE TABLE on_call_rebalance_actions_r2702 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rotation_id uuid NOT NULL REFERENCES engineer_on_call_rotation_r2702(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('swap','reduce','add_backup','redistribute','escalate')),
  triggered_by text NOT NULL,
  hours_shifted numeric(6,2) NOT NULL DEFAULT 0,
  target_engineer text,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','accepted','declined','completed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE on_call_rebalance_actions_r2702 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON on_call_rebalance_actions_r2702;
CREATE POLICY founder_all ON on_call_rebalance_actions_r2702 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seed data
-- ============================================================================

INSERT INTO engineer_on_call_rotation_r2702 (engineer_name, engineer_region, rotation_month, weekday_hours, weekend_hours, night_hours, total_hours, overload_signal, fairness_score, status) VALUES
  ('Rajesh Kumar', 'south', '2026-06-01'::date, 88.00, 32.00, 18.00, 138.00, 'high', 62.50, 'active'),
  ('Priya Menon', 'south', '2026-06-01'::date, 72.00, 16.00, 8.00, 96.00, 'normal', 92.00, 'active'),
  ('Arjun Reddy', 'south', '2026-06-01'::date, 80.00, 24.00, 12.00, 116.00, 'elevated', 78.40, 'rebalanced'),
  ('Sneha Iyer', 'west', '2026-06-01'::date, 96.00, 40.00, 24.00, 160.00, 'critical', 48.20, 'swapped'),
  ('Vikram Singh', 'north', '2026-06-01'::date, 68.00, 12.00, 6.00, 86.00, 'normal', 95.50, 'active'),
  ('Anita Desai', 'central', '2026-06-01'::date, 84.00, 28.00, 16.00, 128.00, 'elevated', 71.80, 'active'),
  ('Deepak Joshi', 'east', '2026-06-01'::date, 60.00, 8.00, 4.00, 72.00, 'normal', 98.10, 'closed');

INSERT INTO on_call_rebalance_actions_r2702 (rotation_id, action_type, triggered_by, hours_shifted, target_engineer, outcome, notes) VALUES
  ((SELECT id FROM engineer_on_call_rotation_r2702 WHERE engineer_name='Sneha Iyer'), 'swap', 'auto_fairness', 24.00, 'Vikram Singh', 'completed', 'Weekend swap to relieve critical overload'),
  ((SELECT id FROM engineer_on_call_rotation_r2702 WHERE engineer_name='Rajesh Kumar'), 'reduce', 'founder_review', 16.00, NULL, 'accepted', 'Reduced night hours after high signal'),
  ((SELECT id FROM engineer_on_call_rotation_r2702 WHERE engineer_name='Arjun Reddy'), 'redistribute', 'regional_ops', 12.00, 'Priya Menon', 'completed', 'Spread weekend coverage across south region'),
  ((SELECT id FROM engineer_on_call_rotation_r2702 WHERE engineer_name='Anita Desai'), 'add_backup', 'auto_fairness', 8.00, 'Deepak Joshi', 'pending', 'Backup engineer added for elevated load'),
  ((SELECT id FROM engineer_on_call_rotation_r2702 WHERE engineer_name='Sneha Iyer'), 'escalate', 'founder_review', 0.00, NULL, 'accepted', 'Escalated to leadership for permanent rotation fix'),
  ((SELECT id FROM engineer_on_call_rotation_r2702 WHERE engineer_name='Rajesh Kumar'), 'add_backup', 'regional_ops', 6.00, 'Priya Menon', 'declined', 'Backup declined due to scheduling conflict');

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_on_call_rotation_summary_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_rotation_summary_r2702()
RETURNS TABLE (
  total_engineers bigint,
  total_hours numeric,
  avg_fairness numeric,
  critical_count bigint,
  high_count bigint,
  elevated_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(r.total_hours), 0)::numeric,
    COALESCE(AVG(r.fairness_score), 0)::numeric,
    COUNT(*) FILTER (WHERE r.overload_signal = 'critical')::bigint,
    COUNT(*) FILTER (WHERE r.overload_signal = 'high')::bigint,
    COUNT(*) FILTER (WHERE r.overload_signal = 'elevated')::bigint
  FROM engineer_on_call_rotation_r2702 r;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_rotation_summary_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_rotation_summary_r2702() TO authenticated;

DROP FUNCTION IF EXISTS founder_on_call_rotation_list_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_rotation_list_r2702()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  engineer_region text,
  rotation_month date,
  weekday_hours numeric,
  weekend_hours numeric,
  night_hours numeric,
  total_hours numeric,
  overload_signal text,
  fairness_score numeric,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_name, r.engineer_region, r.rotation_month,
         r.weekday_hours, r.weekend_hours, r.night_hours, r.total_hours,
         r.overload_signal, r.fairness_score, r.status
  FROM engineer_on_call_rotation_r2702 r
  ORDER BY r.fairness_score ASC, r.total_hours DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_rotation_list_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_rotation_list_r2702() TO authenticated;

DROP FUNCTION IF EXISTS founder_on_call_region_breakdown_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_region_breakdown_r2702()
RETURNS TABLE (
  engineer_region text,
  engineer_count bigint,
  total_hours numeric,
  avg_fairness numeric,
  weekend_share numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.engineer_region,
         COUNT(*)::bigint,
         COALESCE(SUM(r.total_hours), 0)::numeric,
         COALESCE(AVG(r.fairness_score), 0)::numeric,
         CASE WHEN SUM(r.total_hours) > 0
              THEN ROUND((SUM(r.weekend_hours) * 100.0 / SUM(r.total_hours))::numeric, 2)
              ELSE 0 END
  FROM engineer_on_call_rotation_r2702 r
  GROUP BY r.engineer_region
  ORDER BY engineer_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_region_breakdown_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_region_breakdown_r2702() TO authenticated;

DROP FUNCTION IF EXISTS founder_on_call_overload_signal_dist_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_overload_signal_dist_r2702()
RETURNS TABLE (
  overload_signal text,
  engineer_count bigint,
  avg_total_hours numeric,
  avg_fairness numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.overload_signal,
         COUNT(*)::bigint,
         COALESCE(AVG(r.total_hours), 0)::numeric,
         COALESCE(AVG(r.fairness_score), 0)::numeric
  FROM engineer_on_call_rotation_r2702 r
  GROUP BY r.overload_signal
  ORDER BY engineer_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_overload_signal_dist_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_overload_signal_dist_r2702() TO authenticated;

DROP FUNCTION IF EXISTS founder_on_call_rebalance_actions_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_rebalance_actions_r2702()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  action_type text,
  triggered_by text,
  hours_shifted numeric,
  target_engineer text,
  outcome text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, r.engineer_name, a.action_type, a.triggered_by,
         a.hours_shifted, a.target_engineer, a.outcome, a.notes, a.created_at
  FROM on_call_rebalance_actions_r2702 a
  JOIN engineer_on_call_rotation_r2702 r ON r.id = a.rotation_id
  ORDER BY a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_rebalance_actions_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_rebalance_actions_r2702() TO authenticated;

DROP FUNCTION IF EXISTS founder_on_call_fairness_outliers_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_fairness_outliers_r2702()
RETURNS TABLE (
  engineer_name text,
  engineer_region text,
  total_hours numeric,
  fairness_score numeric,
  overload_signal text,
  gap_from_median numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  median_fair numeric;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COALESCE(percentile_cont(0.5) WITHIN GROUP (ORDER BY r.fairness_score), 0)
  INTO median_fair
  FROM engineer_on_call_rotation_r2702 r;
  RETURN QUERY
  SELECT r.engineer_name, r.engineer_region, r.total_hours,
         r.fairness_score, r.overload_signal,
         ROUND((median_fair - r.fairness_score)::numeric, 2)
  FROM engineer_on_call_rotation_r2702 r
  WHERE r.fairness_score < median_fair
  ORDER BY r.fairness_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_fairness_outliers_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_fairness_outliers_r2702() TO authenticated;

DROP FUNCTION IF EXISTS founder_on_call_action_outcomes_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_action_outcomes_r2702()
RETURNS TABLE (
  action_type text,
  outcome text,
  count bigint,
  total_hours_shifted numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.action_type, a.outcome,
         COUNT(*)::bigint,
         COALESCE(SUM(a.hours_shifted), 0)::numeric
  FROM on_call_rebalance_actions_r2702 a
  GROUP BY a.action_type, a.outcome
  ORDER BY count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_action_outcomes_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_action_outcomes_r2702() TO authenticated;

DROP FUNCTION IF EXISTS founder_on_call_top_overloaded_r2702();
CREATE OR REPLACE FUNCTION founder_on_call_top_overloaded_r2702()
RETURNS TABLE (
  engineer_name text,
  engineer_region text,
  total_hours numeric,
  weekend_hours numeric,
  night_hours numeric,
  overload_signal text,
  fairness_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.engineer_name, r.engineer_region, r.total_hours,
         r.weekend_hours, r.night_hours, r.overload_signal, r.fairness_score
  FROM engineer_on_call_rotation_r2702 r
  WHERE r.overload_signal IN ('high','critical','elevated')
  ORDER BY r.total_hours DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_on_call_top_overloaded_r2702() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_on_call_top_overloaded_r2702() TO authenticated;

COMMIT;
