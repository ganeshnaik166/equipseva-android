BEGIN;

-- ============================================================================
-- Round 2826: Engineer Monthly Job Prep & Bench Stage Tracker
-- engineer x job x prep stage x parts x kit x eta x completion verdict
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: engineer_monthly_job_prep_stages_r2826
-- Tracks each engineer-job combination through prep stages each month
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_job_prep_stages_r2826 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  job_code text NOT NULL,
  hospital_name text NOT NULL,
  equipment_category text NOT NULL,
  prep_stage text NOT NULL CHECK (prep_stage IN ('assigned','parts_requested','parts_received','kit_assembled','bench_test','dispatched','onsite','completed','rework')),
  parts_required int NOT NULL CHECK (parts_required >= 0),
  parts_received int NOT NULL CHECK (parts_received >= 0),
  kit_completeness_pct numeric(5,2) NOT NULL CHECK (kit_completeness_pct >= 0 AND kit_completeness_pct <= 100),
  bench_test_passed boolean NOT NULL DEFAULT false,
  eta_hours numeric(6,2) NOT NULL CHECK (eta_hours >= 0),
  actual_hours numeric(6,2),
  completion_verdict text CHECK (completion_verdict IN ('pending','on_time','delayed','escalated','reassigned','closed_ok','closed_fail')),
  prep_score numeric(5,2) NOT NULL CHECK (prep_score >= 0 AND prep_score <= 100),
  blocker_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_job_prep_stages_r2826 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_monthly_job_prep_stages_r2826;
CREATE POLICY founder_all ON engineer_monthly_job_prep_stages_r2826
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_job_prep_stages_r2826 (cycle_month, engineer_code, engineer_name, engineer_tier, job_code, hospital_name, equipment_category, prep_stage, parts_required, parts_received, kit_completeness_pct, bench_test_passed, eta_hours, actual_hours, completion_verdict, prep_score, blocker_note) VALUES
  ('2026-06-01'::date, 'ENG-101', 'Ravi Kumar',     'platinum', 'JOB-7701', 'Apollo Hyd',       'ventilator',     'completed',       6, 6,  100.00, true,  18.0, 17.5, 'on_time',    96.50, NULL),
  ('2026-06-01'::date, 'ENG-101', 'Ravi Kumar',     'platinum', 'JOB-7702', 'Yashoda Sec',      'dialysis',       'bench_test',      4, 4,  100.00, true,  12.0, NULL, 'pending',    92.00, NULL),
  ('2026-06-01'::date, 'ENG-102', 'Anjali Reddy',   'gold',     'JOB-7703', 'KIMS Kondapur',    'infusion_pump',  'parts_received',  5, 5,  100.00, false, 14.0, NULL, 'pending',    78.50, NULL),
  ('2026-06-01'::date, 'ENG-102', 'Anjali Reddy',   'gold',     'JOB-7704', 'Sunshine Hosp',    'ct_scanner',     'parts_requested', 9, 3,   33.33, false, 36.0, NULL, 'delayed',    52.00, 'tube assembly backorder 5d'),
  ('2026-06-01'::date, 'ENG-103', 'Suresh Naidu',   'silver',   'JOB-7705', 'Care Banjara',     'patient_monitor','dispatched',      3, 3,  100.00, true,  6.0,  6.5,  'on_time',    88.00, NULL),
  ('2026-06-01'::date, 'ENG-103', 'Suresh Naidu',   'silver',   'JOB-7706', 'Continental Gachi','ecg_machine',    'rework',          2, 2,  100.00, false, 8.0,  14.0, 'closed_fail',41.00, 'calibration drift on re-test'),
  ('2026-06-01'::date, 'ENG-104', 'Priya Sharma',   'gold',     'JOB-7707', 'Star Hyd',         'ultrasound',     'onsite',          5, 5,  100.00, true,  20.0, NULL, 'pending',    90.50, NULL),
  ('2026-06-01'::date, 'ENG-104', 'Priya Sharma',   'gold',     'JOB-7708', 'AIG Gachibowli',   'endoscope',      'assigned',        7, 0,    0.00, false, 24.0, NULL, 'pending',    20.00, 'awaiting parts spec confirmation'),
  ('2026-06-01'::date, 'ENG-105', 'Mohan Reddy',    'bronze',   'JOB-7709', 'Citizens Hosp',    'autoclave',      'kit_assembled',   3, 3,  100.00, false, 10.0, NULL, 'pending',    72.00, NULL),
  ('2026-06-01'::date, 'ENG-105', 'Mohan Reddy',    'bronze',   'JOB-7710', 'Olive Hosp',       'xray',           'rework',          4, 1, 25.00, false, 16.0, 30.0, 'escalated', 38.00, 'engineer unable to source HV cable'),
  ('2026-06-01'::date, 'ENG-106', 'Kavya Iyer',     'silver',   'JOB-7711', 'Krishna Inst',     'defibrillator',  'completed',       2, 2,  100.00, true,  6.0,  5.5,  'closed_ok',  94.00, NULL),
  ('2026-06-01'::date, 'ENG-106', 'Kavya Iyer',     'silver',   'JOB-7712', 'Rainbow Banjara',  'incubator',      'parts_received',  3, 3,  100.00, false, 9.0,  NULL, 'pending',    76.50, NULL);

-- Fix the 10th row which I built with an expression accidentally — replace with proper value
DELETE FROM engineer_monthly_job_prep_stages_r2826 WHERE engineer_code='ENG-105' AND job_code='JOB-7710';
INSERT INTO engineer_monthly_job_prep_stages_r2826 (cycle_month, engineer_code, engineer_name, engineer_tier, job_code, hospital_name, equipment_category, prep_stage, parts_required, parts_received, kit_completeness_pct, bench_test_passed, eta_hours, actual_hours, completion_verdict, prep_score, blocker_note) VALUES
  ('2026-06-01'::date, 'ENG-105', 'Mohan Reddy', 'bronze', 'JOB-7710', 'Olive Hosp', 'xray', 'rework', 4, 1, 25.00, false, 16.0, 30.0, 'escalated', 38.00, 'engineer unable to source HV cable');

CREATE INDEX IF NOT EXISTS idx_emjps_r2826_month ON engineer_monthly_job_prep_stages_r2826(cycle_month);
CREATE INDEX IF NOT EXISTS idx_emjps_r2826_eng   ON engineer_monthly_job_prep_stages_r2826(engineer_code);
CREATE INDEX IF NOT EXISTS idx_emjps_r2826_stage ON engineer_monthly_job_prep_stages_r2826(prep_stage);

-- ----------------------------------------------------------------------------
-- Table 2: engineer_bench_stage_events_r2826
-- Audit/event log of stage transitions with bench-test telemetry
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_bench_stage_events_r2826 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prep_id uuid NOT NULL REFERENCES engineer_monthly_job_prep_stages_r2826(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  from_stage text NOT NULL CHECK (from_stage IN ('assigned','parts_requested','parts_received','kit_assembled','bench_test','dispatched','onsite','completed','rework','none')),
  to_stage   text NOT NULL CHECK (to_stage   IN ('assigned','parts_requested','parts_received','kit_assembled','bench_test','dispatched','onsite','completed','rework','none')),
  duration_hours numeric(6,2) NOT NULL CHECK (duration_hours >= 0),
  bench_check_passed boolean NOT NULL DEFAULT false,
  bench_check_score numeric(5,2) CHECK (bench_check_score IS NULL OR (bench_check_score >= 0 AND bench_check_score <= 100)),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_bench_stage_events_r2826 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_bench_stage_events_r2826;
CREATE POLICY founder_all ON engineer_bench_stage_events_r2826
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '12 days', 'none',            'assigned',        0.50, false, NULL,  'auto-assigned by ops'        FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '11 days', 'assigned',        'parts_requested', 2.00, false, NULL,  'BOM raised'                  FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '10 days', 'parts_requested', 'parts_received',  6.00, false, NULL,  'all 6 parts received OK'     FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '9 days',  'parts_received',  'kit_assembled',   3.00, false, NULL,  'kit signed off by lead'      FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '8 days',  'kit_assembled',   'bench_test',      4.00, true,  96.5,  'bench pass first attempt'    FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '7 days',  'bench_test',      'dispatched',      1.00, false, NULL,  'shipped to hospital'         FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '2 days',  'dispatched',      'onsite',          4.00, false, NULL,  'installed onsite'            FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '1 days',  'onsite',          'completed',       2.00, true,  96.5,  'closed clean'                FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7701';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '5 days',  'parts_requested', 'parts_received', 12.00, false, NULL,  'partial 3 of 9 received'     FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7704';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '3 days',  'bench_test',      'rework',          5.00, false, 41.0,  'calibration drift detected'  FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7706';
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '1 days',  'onsite',          'rework',  6.0, false, 38.0,  'HV cable not in market — escalate' FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7710';

-- Replace the malformed row above
DELETE FROM engineer_bench_stage_events_r2826
  WHERE prep_id = (SELECT id FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7710')
    AND to_stage = 'rework' AND bench_check_score = 38.0;
INSERT INTO engineer_bench_stage_events_r2826 (prep_id, event_at, from_stage, to_stage, duration_hours, bench_check_passed, bench_check_score, note)
SELECT id, now() - interval '1 days', 'onsite', 'rework', 6.0, false, 38.0, 'HV cable not in market — escalate'
FROM engineer_monthly_job_prep_stages_r2826 WHERE job_code='JOB-7710';

CREATE INDEX IF NOT EXISTS idx_ebse_r2826_prep   ON engineer_bench_stage_events_r2826(prep_id);
CREATE INDEX IF NOT EXISTS idx_ebse_r2826_event  ON engineer_bench_stage_events_r2826(event_at DESC);

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. KPI summary
DROP FUNCTION IF EXISTS founder_r2826_kpi_summary();
CREATE OR REPLACE FUNCTION founder_r2826_kpi_summary()
RETURNS TABLE (
  total_jobs int,
  active_engineers int,
  avg_prep_score numeric,
  on_time_rate numeric,
  bench_pass_rate numeric,
  blocked_jobs int,
  kit_full_pct numeric,
  avg_eta_hours numeric
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
    COUNT(*)::int,
    COUNT(DISTINCT engineer_code)::int,
    ROUND(AVG(prep_score)::numeric, 2),
    ROUND( (SUM(CASE WHEN completion_verdict IN ('on_time','closed_ok') THEN 1 ELSE 0 END)::numeric
            / NULLIF(COUNT(*),0)) * 100, 2),
    ROUND( (SUM(CASE WHEN bench_test_passed THEN 1 ELSE 0 END)::numeric
            / NULLIF(COUNT(*),0)) * 100, 2),
    SUM(CASE WHEN blocker_note IS NOT NULL THEN 1 ELSE 0 END)::int,
    ROUND( (SUM(CASE WHEN kit_completeness_pct >= 100 THEN 1 ELSE 0 END)::numeric
            / NULLIF(COUNT(*),0)) * 100, 2),
    ROUND(AVG(eta_hours)::numeric, 2)
  FROM engineer_monthly_job_prep_stages_r2826;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_kpi_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_kpi_summary() TO authenticated;

-- 2. Stage funnel
DROP FUNCTION IF EXISTS founder_r2826_stage_funnel();
CREATE OR REPLACE FUNCTION founder_r2826_stage_funnel()
RETURNS TABLE (
  prep_stage text,
  job_count int,
  share_pct numeric,
  avg_score numeric
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
  WITH t AS (SELECT COUNT(*)::numeric AS total FROM engineer_monthly_job_prep_stages_r2826)
  SELECT
    p.prep_stage,
    COUNT(*)::int,
    ROUND((COUNT(*)::numeric / NULLIF((SELECT total FROM t),0)) * 100, 2),
    ROUND(AVG(p.prep_score)::numeric, 2)
  FROM engineer_monthly_job_prep_stages_r2826 p
  GROUP BY p.prep_stage
  ORDER BY job_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_stage_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_stage_funnel() TO authenticated;

-- 3. Engineer leaderboard
DROP FUNCTION IF EXISTS founder_r2826_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2826_engineer_leaderboard()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  engineer_tier text,
  job_count int,
  avg_score numeric,
  bench_pass_rate numeric,
  on_time_rate numeric
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
    p.engineer_code,
    MAX(p.engineer_name),
    MAX(p.engineer_tier),
    COUNT(*)::int,
    ROUND(AVG(p.prep_score)::numeric, 2),
    ROUND( (SUM(CASE WHEN p.bench_test_passed THEN 1 ELSE 0 END)::numeric
            / NULLIF(COUNT(*),0)) * 100, 2),
    ROUND( (SUM(CASE WHEN p.completion_verdict IN ('on_time','closed_ok') THEN 1 ELSE 0 END)::numeric
            / NULLIF(COUNT(*),0)) * 100, 2)
  FROM engineer_monthly_job_prep_stages_r2826 p
  GROUP BY p.engineer_code
  ORDER BY avg_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_engineer_leaderboard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_engineer_leaderboard() TO authenticated;

-- 4. Verdict mix
DROP FUNCTION IF EXISTS founder_r2826_verdict_mix();
CREATE OR REPLACE FUNCTION founder_r2826_verdict_mix()
RETURNS TABLE (
  verdict text,
  job_count int,
  share_pct numeric
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
  WITH t AS (SELECT COUNT(*)::numeric AS total FROM engineer_monthly_job_prep_stages_r2826)
  SELECT
    COALESCE(p.completion_verdict, 'unset'),
    COUNT(*)::int,
    ROUND((COUNT(*)::numeric / NULLIF((SELECT total FROM t),0)) * 100, 2)
  FROM engineer_monthly_job_prep_stages_r2826 p
  GROUP BY COALESCE(p.completion_verdict, 'unset')
  ORDER BY job_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_verdict_mix() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_verdict_mix() TO authenticated;

-- 5. Blocked jobs (parts shortfall)
DROP FUNCTION IF EXISTS founder_r2826_blocked_jobs();
CREATE OR REPLACE FUNCTION founder_r2826_blocked_jobs()
RETURNS TABLE (
  job_code text,
  engineer_name text,
  hospital_name text,
  equipment_category text,
  prep_stage text,
  parts_required int,
  parts_received int,
  kit_completeness_pct numeric,
  blocker_note text
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
    p.job_code, p.engineer_name, p.hospital_name, p.equipment_category,
    p.prep_stage, p.parts_required, p.parts_received, p.kit_completeness_pct, p.blocker_note
  FROM engineer_monthly_job_prep_stages_r2826 p
  WHERE p.blocker_note IS NOT NULL OR p.kit_completeness_pct < 100
  ORDER BY p.kit_completeness_pct ASC, p.prep_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_blocked_jobs() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_blocked_jobs() TO authenticated;

-- 6. Bench events for a prep
DROP FUNCTION IF EXISTS founder_r2826_recent_bench_events();
CREATE OR REPLACE FUNCTION founder_r2826_recent_bench_events()
RETURNS TABLE (
  job_code text,
  engineer_name text,
  from_stage text,
  to_stage text,
  duration_hours numeric,
  bench_check_passed boolean,
  bench_check_score numeric,
  event_at timestamptz,
  note text
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
    p.job_code, p.engineer_name,
    e.from_stage, e.to_stage, e.duration_hours,
    e.bench_check_passed, e.bench_check_score, e.event_at, e.note
  FROM engineer_bench_stage_events_r2826 e
  JOIN engineer_monthly_job_prep_stages_r2826 p ON p.id = e.prep_id
  ORDER BY e.event_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_recent_bench_events() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_recent_bench_events() TO authenticated;

-- 7. ETA variance per engineer
DROP FUNCTION IF EXISTS founder_r2826_eta_variance();
CREATE OR REPLACE FUNCTION founder_r2826_eta_variance()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  closed_jobs int,
  avg_eta numeric,
  avg_actual numeric,
  variance_pct numeric
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
    p.engineer_code,
    MAX(p.engineer_name),
    COUNT(*) FILTER (WHERE p.actual_hours IS NOT NULL)::int,
    ROUND(AVG(p.eta_hours)::numeric, 2),
    ROUND(AVG(p.actual_hours)::numeric, 2),
    ROUND( ((AVG(p.actual_hours) - AVG(p.eta_hours)) / NULLIF(AVG(p.eta_hours),0)) * 100, 2)
  FROM engineer_monthly_job_prep_stages_r2826 p
  WHERE p.actual_hours IS NOT NULL
  GROUP BY p.engineer_code
  ORDER BY variance_pct DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_eta_variance() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_eta_variance() TO authenticated;

-- 8. Detailed job list (top-N for table view)
DROP FUNCTION IF EXISTS founder_r2826_job_list();
CREATE OR REPLACE FUNCTION founder_r2826_job_list()
RETURNS TABLE (
  job_code text,
  engineer_name text,
  engineer_tier text,
  hospital_name text,
  equipment_category text,
  prep_stage text,
  parts_required int,
  parts_received int,
  kit_completeness_pct numeric,
  bench_test_passed boolean,
  eta_hours numeric,
  actual_hours numeric,
  completion_verdict text,
  prep_score numeric
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
    p.job_code, p.engineer_name, p.engineer_tier, p.hospital_name, p.equipment_category,
    p.prep_stage, p.parts_required, p.parts_received, p.kit_completeness_pct,
    p.bench_test_passed, p.eta_hours, p.actual_hours, p.completion_verdict, p.prep_score
  FROM engineer_monthly_job_prep_stages_r2826 p
  ORDER BY p.prep_score DESC, p.job_code ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2826_job_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_r2826_job_list() TO authenticated;

COMMIT;
