BEGIN;

-- =====================================================================
-- Round 2868 — Customer Monthly Engineer Tool Borrowing Ledger
-- =====================================================================

-- ---------- Table 1: borrowing events ----------
CREATE TABLE IF NOT EXISTS engineer_tool_borrow_events_r2868 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_month date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  tool_code text NOT NULL,
  tool_name text NOT NULL,
  borrowed_from text NOT NULL CHECK (borrowed_from IN ('central_store','regional_depot','peer_engineer','customer_site','vendor_loan')),
  borrowed_at timestamptz NOT NULL,
  due_back_at timestamptz NOT NULL,
  returned_at timestamptz,
  return_condition text NOT NULL CHECK (return_condition IN ('pristine','minor_wear','damaged','lost','not_returned','calibration_due')),
  loss_value_rupees integer NOT NULL DEFAULT 0 CHECK (loss_value_rupees >= 0),
  verdict text NOT NULL CHECK (verdict IN ('clean','warn','recover','suspend','escalate')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_tool_borrow_events_r2868 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_tool_borrow_events_r2868;
CREATE POLICY founder_all ON engineer_tool_borrow_events_r2868
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO engineer_tool_borrow_events_r2868
  (ledger_month, engineer_code, engineer_name, tool_code, tool_name, borrowed_from, borrowed_at, due_back_at, returned_at, return_condition, loss_value_rupees, verdict, notes)
VALUES
  ('2026-06-01'::date, 'ENG-001', 'Ravi Kumar',    'TL-MULTI-12', 'Fluke 87V Multimeter',    'central_store',   '2026-06-02 09:00+05:30', '2026-06-04 18:00+05:30', '2026-06-04 17:10+05:30', 'pristine',        0,      'clean',     'On-time return, clean condition'),
  ('2026-06-01'::date, 'ENG-002', 'Sneha Patel',   'TL-OSC-04',   'Tektronix Oscilloscope',  'regional_depot',  '2026-06-05 10:00+05:30', '2026-06-07 18:00+05:30', '2026-06-08 11:30+05:30', 'minor_wear',      450,    'warn',      'Returned 17h late, scuffed casing'),
  ('2026-06-01'::date, 'ENG-003', 'Arjun Reddy',   'TL-LEAK-09',  'Ultrasonic Leak Detector','peer_engineer',   '2026-06-09 08:30+05:30', '2026-06-10 18:00+05:30', '2026-06-12 16:00+05:30', 'damaged',         8500,   'recover',   'Probe tip cracked, recovery initiated'),
  ('2026-06-01'::date, 'ENG-004', 'Priya Nair',    'TL-XRAY-02',  'Portable X-ray Tester',   'vendor_loan',     '2026-06-12 11:00+05:30', '2026-06-14 18:00+05:30', NULL,                     'not_returned',    45000,  'suspend',   'Engineer non-responsive 5 days'),
  ('2026-06-01'::date, 'ENG-005', 'Vikram Singh',  'TL-CAL-21',   'Pressure Calibrator',     'central_store',   '2026-06-15 09:30+05:30', '2026-06-18 18:00+05:30', '2026-06-19 09:00+05:30', 'calibration_due', 1200,   'warn',      'Returned with cal seal broken'),
  ('2026-06-01'::date, 'ENG-001', 'Ravi Kumar',    'TL-INFRA-07', 'Infrared Thermometer',    'customer_site',   '2026-06-18 14:00+05:30', '2026-06-19 18:00+05:30', '2026-06-19 17:45+05:30', 'pristine',        0,      'clean',     'Customer-site loan, returned clean'),
  ('2026-06-01'::date, 'ENG-006', 'Anita Desai',   'TL-CRANE-03', 'Mini Hydraulic Lift',     'regional_depot',  '2026-06-20 08:00+05:30', '2026-06-22 18:00+05:30', NULL,                     'lost',            120000, 'escalate',  'Reported stolen from van, FIR filed');

-- ---------- Table 2: engineer borrowing scorecard ----------
CREATE TABLE IF NOT EXISTS engineer_borrow_scorecard_r2868 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_month date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  borrow_count integer NOT NULL DEFAULT 0,
  on_time_returns integer NOT NULL DEFAULT 0,
  late_returns integer NOT NULL DEFAULT 0,
  damaged_count integer NOT NULL DEFAULT 0,
  lost_count integer NOT NULL DEFAULT 0,
  total_loss_rupees integer NOT NULL DEFAULT 0,
  risk_grade text NOT NULL CHECK (risk_grade IN ('green','amber','red','blacklist')),
  recommended_action text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ledger_month, engineer_code)
);

ALTER TABLE engineer_borrow_scorecard_r2868 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_borrow_scorecard_r2868;
CREATE POLICY founder_all ON engineer_borrow_scorecard_r2868
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

INSERT INTO engineer_borrow_scorecard_r2868
  (ledger_month, engineer_code, engineer_name, borrow_count, on_time_returns, late_returns, damaged_count, lost_count, total_loss_rupees, risk_grade, recommended_action)
VALUES
  ('2026-06-01'::date, 'ENG-001', 'Ravi Kumar',    2, 2, 0, 0, 0, 0,      'green',     'Maintain — eligible for high-value tool checkouts'),
  ('2026-06-01'::date, 'ENG-002', 'Sneha Patel',   1, 0, 1, 0, 0, 450,    'amber',     'Coach on timeliness, deduct 1 day SLA bonus'),
  ('2026-06-01'::date, 'ENG-003', 'Arjun Reddy',   1, 0, 1, 1, 0, 8500,   'amber',     'Recover INR 8500 from salary advance, retrain'),
  ('2026-06-01'::date, 'ENG-004', 'Priya Nair',    1, 0, 0, 0, 0, 45000,  'red',       'Suspend tool privileges, HR investigation'),
  ('2026-06-01'::date, 'ENG-005', 'Vikram Singh',  1, 0, 1, 0, 0, 1200,   'amber',     'Calibration training mandatory before next checkout'),
  ('2026-06-01'::date, 'ENG-006', 'Anita Desai',   1, 0, 0, 0, 1, 120000, 'blacklist', 'Termination — file insurance claim, recover via FIR');

-- =====================================================================
-- RPCs — all SECDEF, is_founder gated
-- =====================================================================

-- 1) KPI summary
DROP FUNCTION IF EXISTS founder_r2868_borrow_kpis();
CREATE OR REPLACE FUNCTION founder_r2868_borrow_kpis()
RETURNS TABLE (
  total_events integer,
  total_loss_rupees bigint,
  open_borrows integer,
  red_engineers integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM engineer_tool_borrow_events_r2868),
    (SELECT COALESCE(SUM(loss_value_rupees),0)::bigint FROM engineer_tool_borrow_events_r2868),
    (SELECT COUNT(*)::int FROM engineer_tool_borrow_events_r2868 WHERE returned_at IS NULL),
    (SELECT COUNT(*)::int FROM engineer_borrow_scorecard_r2868 WHERE risk_grade IN ('red','blacklist'));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_borrow_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_borrow_kpis() TO authenticated;

-- 2) Full event ledger
DROP FUNCTION IF EXISTS founder_r2868_borrow_events();
CREATE OR REPLACE FUNCTION founder_r2868_borrow_events()
RETURNS SETOF engineer_tool_borrow_events_r2868
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM engineer_tool_borrow_events_r2868
  ORDER BY borrowed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_borrow_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_borrow_events() TO authenticated;

-- 3) Engineer scorecard
DROP FUNCTION IF EXISTS founder_r2868_engineer_scorecard();
CREATE OR REPLACE FUNCTION founder_r2868_engineer_scorecard()
RETURNS SETOF engineer_borrow_scorecard_r2868
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM engineer_borrow_scorecard_r2868
  ORDER BY total_loss_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_engineer_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_engineer_scorecard() TO authenticated;

-- 4) Borrow source breakdown
DROP FUNCTION IF EXISTS founder_r2868_borrow_source_mix();
CREATE OR REPLACE FUNCTION founder_r2868_borrow_source_mix()
RETURNS TABLE (
  borrowed_from text,
  event_count integer,
  loss_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    e.borrowed_from,
    COUNT(*)::int,
    COALESCE(SUM(e.loss_value_rupees),0)::bigint
  FROM engineer_tool_borrow_events_r2868 e
  GROUP BY e.borrowed_from
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_borrow_source_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_borrow_source_mix() TO authenticated;

-- 5) Condition breakdown
DROP FUNCTION IF EXISTS founder_r2868_condition_mix();
CREATE OR REPLACE FUNCTION founder_r2868_condition_mix()
RETURNS TABLE (
  return_condition text,
  event_count integer,
  loss_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    e.return_condition,
    COUNT(*)::int,
    COALESCE(SUM(e.loss_value_rupees),0)::bigint
  FROM engineer_tool_borrow_events_r2868 e
  GROUP BY e.return_condition
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_condition_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_condition_mix() TO authenticated;

-- 6) Verdict mix
DROP FUNCTION IF EXISTS founder_r2868_verdict_mix();
CREATE OR REPLACE FUNCTION founder_r2868_verdict_mix()
RETURNS TABLE (
  verdict text,
  event_count integer,
  loss_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    e.verdict,
    COUNT(*)::int,
    COALESCE(SUM(e.loss_value_rupees),0)::bigint
  FROM engineer_tool_borrow_events_r2868 e
  GROUP BY e.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_verdict_mix() TO authenticated;

-- 7) High-risk engineers (red + blacklist)
DROP FUNCTION IF EXISTS founder_r2868_high_risk_engineers();
CREATE OR REPLACE FUNCTION founder_r2868_high_risk_engineers()
RETURNS SETOF engineer_borrow_scorecard_r2868
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM engineer_borrow_scorecard_r2868
  WHERE risk_grade IN ('red','blacklist')
  ORDER BY total_loss_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_high_risk_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_high_risk_engineers() TO authenticated;

-- 8) Open (not returned) borrows
DROP FUNCTION IF EXISTS founder_r2868_open_borrows();
CREATE OR REPLACE FUNCTION founder_r2868_open_borrows()
RETURNS SETOF engineer_tool_borrow_events_r2868
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT * FROM engineer_tool_borrow_events_r2868
  WHERE returned_at IS NULL
  ORDER BY due_back_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2868_open_borrows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2868_open_borrows() TO authenticated;

COMMIT;
