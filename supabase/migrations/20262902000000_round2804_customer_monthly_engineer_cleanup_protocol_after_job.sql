BEGIN;

-- ============================================================================
-- Round 2804 — Customer Monthly Engineer Cleanup Protocol After Job
-- Spec: job × cleanup score × waste × space × customer feedback × refine action
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: cleanup_protocol_logs_r2804
-- Per-job cleanup protocol scoring + waste accounting + space restoration
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cleanup_protocol_logs_r2804 (
  id BIGSERIAL PRIMARY KEY,
  log_month DATE NOT NULL,
  job_code TEXT NOT NULL,
  engineer_name TEXT NOT NULL,
  customer_org TEXT NOT NULL,
  device_category TEXT NOT NULL CHECK (device_category IN ('imaging','diagnostic','dental','surgical','lab')),
  cleanup_score_pct NUMERIC(5,2) NOT NULL CHECK (cleanup_score_pct BETWEEN 0 AND 100),
  waste_kg NUMERIC(8,2) NOT NULL CHECK (waste_kg >= 0),
  biohazard_bags INTEGER NOT NULL CHECK (biohazard_bags >= 0),
  space_restored_pct NUMERIC(5,2) NOT NULL CHECK (space_restored_pct BETWEEN 0 AND 100),
  customer_feedback_stars NUMERIC(3,2) NOT NULL CHECK (customer_feedback_stars BETWEEN 1 AND 5),
  customer_quote TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('exemplary','passed','minor_gap','major_gap','failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE cleanup_protocol_logs_r2804 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON cleanup_protocol_logs_r2804;
CREATE POLICY founder_all ON cleanup_protocol_logs_r2804
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO cleanup_protocol_logs_r2804 (log_month, job_code, engineer_name, customer_org, device_category, cleanup_score_pct, waste_kg, biohazard_bags, space_restored_pct, customer_feedback_stars, customer_quote, status) VALUES
('2026-06-01'::date, 'JOB-88421', 'Ravi Kumar',     'Apollo Jubilee Hills', 'imaging',    98.50, 2.40, 1, 99.00, 4.90, 'Spotless — could not tell anyone worked here.', 'exemplary'),
('2026-06-01'::date, 'JOB-88422', 'Anita Sharma',   'KIMS Secunderabad',    'diagnostic', 92.00, 3.10, 2, 95.50, 4.60, 'Tidy. Floor was even mopped.',                'passed'),
('2026-06-01'::date, 'JOB-88423', 'Vivek Reddy',    'Yashoda Somajiguda',   'dental',     78.00, 5.80, 3, 82.00, 3.40, 'Some debris near suction unit, otherwise ok.', 'minor_gap'),
('2026-06-01'::date, 'JOB-88424', 'Sneha Patil',    'Care Banjara Hills',   'surgical',   65.00, 8.20, 4, 70.00, 2.80, 'Cleaned but left wrappers in corner bin.',     'major_gap'),
('2026-06-01'::date, 'JOB-88425', 'Manoj Iyer',     'Continental Gachibowli','lab',       45.00,12.10, 6, 50.00, 1.90, 'Had to call housekeeping to redo the bench.',  'failed'),
('2026-06-01'::date, 'JOB-88426', 'Pooja Nair',     'Rainbow Hyderguda',    'imaging',    96.00, 2.80, 1, 97.50, 4.80, 'Engineer even wiped down the patient bed.',    'exemplary'),
('2026-06-01'::date, 'JOB-88427', 'Karthik Menon',  'AIG Gachibowli',       'diagnostic', 88.50, 3.50, 2, 90.00, 4.20, 'Clean enough — next patient walked right in.', 'passed');

-- ---------------------------------------------------------------------------
-- Table 2: cleanup_refine_actions_r2804
-- Refinement actions driven by gaps + customer feedback
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cleanup_refine_actions_r2804 (
  id BIGSERIAL PRIMARY KEY,
  action_month DATE NOT NULL,
  engineer_name TEXT NOT NULL,
  gap_theme TEXT NOT NULL CHECK (gap_theme IN ('waste_segregation','floor_mop','workspace_reset','biohazard_handling','customer_handoff')),
  refine_action TEXT NOT NULL,
  owner TEXT NOT NULL,
  due_in_days INTEGER NOT NULL CHECK (due_in_days BETWEEN 1 AND 90),
  expected_score_lift_pct NUMERIC(5,2) NOT NULL CHECK (expected_score_lift_pct BETWEEN 0 AND 50),
  priority TEXT NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  status TEXT NOT NULL CHECK (status IN ('queued','in_training','rolling_out','verified','dropped')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE cleanup_refine_actions_r2804 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON cleanup_refine_actions_r2804;
CREATE POLICY founder_all ON cleanup_refine_actions_r2804
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO cleanup_refine_actions_r2804 (action_month, engineer_name, gap_theme, refine_action, owner, due_in_days, expected_score_lift_pct, priority, status) VALUES
('2026-06-01'::date, 'Manoj Iyer',    'workspace_reset',    'Mandatory 2-day refresher on bench-reset SOP + buddy shadowing.', 'Field Ops Lead', 14, 25.00, 'p0', 'in_training'),
('2026-06-01'::date, 'Sneha Patil',   'waste_segregation',  'Pocket card with biohazard vs general waste decision tree.',      'Compliance',      7, 12.00, 'p1', 'rolling_out'),
('2026-06-01'::date, 'Vivek Reddy',   'floor_mop',          'Add suction-area mop check to job-close checklist app.',          'Product',        21,  9.00, 'p2', 'queued'),
('2026-06-01'::date, 'Anita Sharma',  'customer_handoff',   'Verbal handoff script + photo-of-cleaned-bay before sign-off.',   'Field Ops Lead', 10,  5.00, 'p2', 'verified'),
('2026-06-01'::date, 'Karthik Menon', 'biohazard_handling', 'Annual biohazard recert refresher with KIMS infection control.',  'Compliance',     30,  7.00, 'p1', 'queued'),
('2026-06-01'::date, 'Ravi Kumar',    'customer_handoff',   'Promote to peer-trainer for cleanup protocol — best in class.',   'HR',             45,  0.00, 'p3', 'queued'),
('2026-06-01'::date, 'Pooja Nair',    'workspace_reset',    'Film walkthrough video for new-engineer onboarding library.',     'Training',       21,  0.00, 'p3', 'in_training');

-- ---------------------------------------------------------------------------
-- RPC 1: KPI summary
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2804_kpi_summary()
RETURNS TABLE (
  total_jobs INTEGER,
  avg_cleanup_score NUMERIC,
  avg_customer_stars NUMERIC,
  total_waste_kg NUMERIC,
  failed_jobs INTEGER,
  exemplary_jobs INTEGER
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::INTEGER,
    ROUND(AVG(cleanup_score_pct)::NUMERIC, 2),
    ROUND(AVG(customer_feedback_stars)::NUMERIC, 2),
    ROUND(SUM(waste_kg)::NUMERIC, 2),
    COUNT(*) FILTER (WHERE status = 'failed')::INTEGER,
    COUNT(*) FILTER (WHERE status = 'exemplary')::INTEGER
  FROM cleanup_protocol_logs_r2804;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_kpi_summary() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 2: list job logs
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_list_job_logs();
CREATE OR REPLACE FUNCTION founder_r2804_list_job_logs()
RETURNS TABLE (
  id BIGINT,
  job_code TEXT,
  engineer_name TEXT,
  customer_org TEXT,
  device_category TEXT,
  cleanup_score_pct NUMERIC,
  customer_feedback_stars NUMERIC,
  status TEXT,
  customer_quote TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT l.id, l.job_code, l.engineer_name, l.customer_org, l.device_category,
         l.cleanup_score_pct, l.customer_feedback_stars, l.status, l.customer_quote
  FROM cleanup_protocol_logs_r2804 l
  ORDER BY l.cleanup_score_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_list_job_logs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_list_job_logs() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 3: engineer scorecard rollup
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_engineer_scorecard();
CREATE OR REPLACE FUNCTION founder_r2804_engineer_scorecard()
RETURNS TABLE (
  engineer_name TEXT,
  jobs_count INTEGER,
  avg_score NUMERIC,
  avg_stars NUMERIC,
  total_waste_kg NUMERIC,
  worst_status TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    l.engineer_name,
    COUNT(*)::INTEGER,
    ROUND(AVG(l.cleanup_score_pct)::NUMERIC, 2),
    ROUND(AVG(l.customer_feedback_stars)::NUMERIC, 2),
    ROUND(SUM(l.waste_kg)::NUMERIC, 2),
    MIN(l.status)
  FROM cleanup_protocol_logs_r2804 l
  GROUP BY l.engineer_name
  ORDER BY AVG(l.cleanup_score_pct) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_engineer_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_engineer_scorecard() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 4: device category breakdown
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_category_breakdown();
CREATE OR REPLACE FUNCTION founder_r2804_category_breakdown()
RETURNS TABLE (
  device_category TEXT,
  jobs INTEGER,
  avg_score NUMERIC,
  avg_space_restored NUMERIC,
  avg_stars NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    l.device_category,
    COUNT(*)::INTEGER,
    ROUND(AVG(l.cleanup_score_pct)::NUMERIC, 2),
    ROUND(AVG(l.space_restored_pct)::NUMERIC, 2),
    ROUND(AVG(l.customer_feedback_stars)::NUMERIC, 2)
  FROM cleanup_protocol_logs_r2804 l
  GROUP BY l.device_category
  ORDER BY AVG(l.cleanup_score_pct) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_category_breakdown() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 5: refine action backlog
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_refine_actions();
CREATE OR REPLACE FUNCTION founder_r2804_refine_actions()
RETURNS TABLE (
  id BIGINT,
  engineer_name TEXT,
  gap_theme TEXT,
  refine_action TEXT,
  owner TEXT,
  due_in_days INTEGER,
  expected_score_lift_pct NUMERIC,
  priority TEXT,
  status TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_name, a.gap_theme, a.refine_action, a.owner,
         a.due_in_days, a.expected_score_lift_pct, a.priority, a.status
  FROM cleanup_refine_actions_r2804 a
  ORDER BY
    CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    a.due_in_days ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_refine_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_refine_actions() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 6: waste accounting
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_waste_accounting();
CREATE OR REPLACE FUNCTION founder_r2804_waste_accounting()
RETURNS TABLE (
  device_category TEXT,
  total_waste_kg NUMERIC,
  total_biohazard_bags INTEGER,
  jobs INTEGER,
  kg_per_job NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    l.device_category,
    ROUND(SUM(l.waste_kg)::NUMERIC, 2),
    SUM(l.biohazard_bags)::INTEGER,
    COUNT(*)::INTEGER,
    ROUND((SUM(l.waste_kg) / NULLIF(COUNT(*),0))::NUMERIC, 2)
  FROM cleanup_protocol_logs_r2804 l
  GROUP BY l.device_category
  ORDER BY SUM(l.waste_kg) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_waste_accounting() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_waste_accounting() TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 7: queue refine action (VOLATILE)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_queue_refine_action(TEXT, TEXT, TEXT, TEXT, INTEGER, NUMERIC, TEXT);
CREATE OR REPLACE FUNCTION founder_r2804_queue_refine_action(
  p_engineer TEXT,
  p_gap_theme TEXT,
  p_refine_action TEXT,
  p_owner TEXT,
  p_due_in_days INTEGER,
  p_expected_lift NUMERIC,
  p_priority TEXT
) RETURNS BIGINT
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id BIGINT;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO cleanup_refine_actions_r2804
    (action_month, engineer_name, gap_theme, refine_action, owner, due_in_days, expected_score_lift_pct, priority, status)
  VALUES
    (date_trunc('month', now())::date, p_engineer, p_gap_theme, p_refine_action, p_owner, p_due_in_days, p_expected_lift, p_priority, 'queued')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_queue_refine_action(TEXT, TEXT, TEXT, TEXT, INTEGER, NUMERIC, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_queue_refine_action(TEXT, TEXT, TEXT, TEXT, INTEGER, NUMERIC, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC 8: top customer quotes (positive + negative)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2804_top_customer_quotes();
CREATE OR REPLACE FUNCTION founder_r2804_top_customer_quotes()
RETURNS TABLE (
  customer_org TEXT,
  engineer_name TEXT,
  customer_feedback_stars NUMERIC,
  customer_quote TEXT,
  status TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT l.customer_org, l.engineer_name, l.customer_feedback_stars, l.customer_quote, l.status
  FROM cleanup_protocol_logs_r2804 l
  ORDER BY l.customer_feedback_stars DESC, l.cleanup_score_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2804_top_customer_quotes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2804_top_customer_quotes() TO authenticated;

COMMIT;
