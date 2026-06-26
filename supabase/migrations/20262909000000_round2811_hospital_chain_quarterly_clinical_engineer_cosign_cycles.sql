BEGIN;

-- ============================================================================
-- Round 2811: Hospital Chain Quarterly Clinical-Engineer Cosign Cycles
-- chain x clinician x engineer x cosign request x turnaround x outcome
-- ============================================================================

CREATE TABLE IF NOT EXISTS chain_cosign_cycles_r2811 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  quarter_label text NOT NULL,
  quarter_start_date date NOT NULL,
  quarter_end_date date NOT NULL,
  hospitals_in_scope int NOT NULL CHECK (hospitals_in_scope >= 0),
  clinicians_enrolled int NOT NULL CHECK (clinicians_enrolled >= 0),
  engineers_assigned int NOT NULL CHECK (engineers_assigned >= 0),
  cosign_requests_total int NOT NULL CHECK (cosign_requests_total >= 0),
  cosign_requests_completed int NOT NULL CHECK (cosign_requests_completed >= 0),
  median_turnaround_hours numeric(10,2) NOT NULL CHECK (median_turnaround_hours >= 0),
  sla_breach_count int NOT NULL DEFAULT 0 CHECK (sla_breach_count >= 0),
  cycle_status text NOT NULL CHECK (cycle_status IN ('planning','active','review','closed','escalated')),
  outcome_grade text NOT NULL CHECK (outcome_grade IN ('A','B','C','D','F')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_cosign_cycles_r2811 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_cosign_cycles_r2811;
CREATE POLICY founder_all ON chain_cosign_cycles_r2811 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS cosign_request_events_r2811 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES chain_cosign_cycles_r2811(id) ON DELETE CASCADE,
  chain_code text NOT NULL,
  hospital_unit text NOT NULL,
  clinician_name text NOT NULL,
  clinician_specialty text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum')),
  request_type text NOT NULL CHECK (request_type IN ('calibration','preventive','repair','validation','decommission')),
  requested_at timestamptz NOT NULL,
  cosigned_at timestamptz,
  turnaround_hours numeric(10,2) CHECK (turnaround_hours IS NULL OR turnaround_hours >= 0),
  outcome text NOT NULL CHECK (outcome IN ('approved','rejected','escalated','pending','withdrawn')),
  risk_score int NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE cosign_request_events_r2811 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON cosign_request_events_r2811;
CREATE POLICY founder_all ON cosign_request_events_r2811 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed cycles
INSERT INTO chain_cosign_cycles_r2811 (chain_code, chain_name, quarter_label, quarter_start_date, quarter_end_date, hospitals_in_scope, clinicians_enrolled, engineers_assigned, cosign_requests_total, cosign_requests_completed, median_turnaround_hours, sla_breach_count, cycle_status, outcome_grade, notes) VALUES
  ('APOLLO','Apollo Chain','2026-Q2','2026-04-01'::date,'2026-06-30'::date,18,142,38,612,587,4.20,7,'review','A','Top performer chain; trending toward platinum'),
  ('MEDANTA','Medanta Network','2026-Q2','2026-04-01'::date,'2026-06-30'::date,9,84,21,341,318,5.80,12,'active','B','Steady; one unit lagging on calibration'),
  ('FORTIS','Fortis Healthcare','2026-Q2','2026-04-01'::date,'2026-06-30'::date,14,118,29,498,452,6.45,18,'active','B','Escalations rising in north zone'),
  ('MAX','Max Healthcare','2026-Q2','2026-04-01'::date,'2026-06-30'::date,11,96,24,402,371,5.10,9,'review','A','Strong outcome; renewals locked'),
  ('NARAYANA','Narayana Health','2026-Q2','2026-04-01'::date,'2026-06-30'::date,16,128,32,544,489,7.20,22,'escalated','C','South zone SLA breach pattern'),
  ('MANIPAL','Manipal Hospitals','2026-Q2','2026-04-01'::date,'2026-06-30'::date,13,108,26,461,438,4.85,8,'closed','A','Quarter closed clean'),
  ('AIIMS','AIIMS Group','2026-Q2','2026-04-01'::date,'2026-06-30'::date,7,74,19,289,256,9.10,26,'escalated','D','Govt procurement delays blocking cosigns');

-- Seed events
INSERT INTO cosign_request_events_r2811 (cycle_id, chain_code, hospital_unit, clinician_name, clinician_specialty, engineer_name, engineer_tier, request_type, requested_at, cosigned_at, turnaround_hours, outcome, risk_score, notes)
SELECT id, chain_code, 'Apollo Jubilee Hills','Dr. R. Kashyap','Cardiology','Arun Reddy','platinum','calibration','2026-05-12 09:00:00+05:30'::timestamptz,'2026-05-12 12:30:00+05:30'::timestamptz,3.50,'approved',18,'Routine ECG calibration'
FROM chain_cosign_cycles_r2811 WHERE chain_code='APOLLO' LIMIT 1;

INSERT INTO cosign_request_events_r2811 (cycle_id, chain_code, hospital_unit, clinician_name, clinician_specialty, engineer_name, engineer_tier, request_type, requested_at, cosigned_at, turnaround_hours, outcome, risk_score, notes)
SELECT id, chain_code, 'Medanta Gurugram','Dr. S. Iyer','Nephrology','Priya Nair','gold','validation','2026-05-14 10:15:00+05:30'::timestamptz,'2026-05-14 17:00:00+05:30'::timestamptz,6.75,'approved',32,'Dialysis machine validation'
FROM chain_cosign_cycles_r2811 WHERE chain_code='MEDANTA' LIMIT 1;

INSERT INTO cosign_request_events_r2811 (cycle_id, chain_code, hospital_unit, clinician_name, clinician_specialty, engineer_name, engineer_tier, request_type, requested_at, cosigned_at, turnaround_hours, outcome, risk_score, notes)
SELECT id, chain_code, 'Fortis Mohali','Dr. A. Bhatt','Radiology','Karan Sharma','silver','repair','2026-05-18 08:30:00+05:30'::timestamptz,'2026-05-18 22:45:00+05:30'::timestamptz,14.25,'escalated',68,'CT scanner power module breach'
FROM chain_cosign_cycles_r2811 WHERE chain_code='FORTIS' LIMIT 1;

INSERT INTO cosign_request_events_r2811 (cycle_id, chain_code, hospital_unit, clinician_name, clinician_specialty, engineer_name, engineer_tier, request_type, requested_at, cosigned_at, turnaround_hours, outcome, risk_score, notes)
SELECT id, chain_code, 'Max Saket','Dr. N. Verma','Oncology','Meera Joshi','platinum','preventive','2026-05-20 11:00:00+05:30'::timestamptz,'2026-05-20 15:30:00+05:30'::timestamptz,4.50,'approved',22,'Linear accelerator PM cycle'
FROM chain_cosign_cycles_r2811 WHERE chain_code='MAX' LIMIT 1;

INSERT INTO cosign_request_events_r2811 (cycle_id, chain_code, hospital_unit, clinician_name, clinician_specialty, engineer_name, engineer_tier, request_type, requested_at, cosigned_at, turnaround_hours, outcome, risk_score, notes)
SELECT id, chain_code, 'Narayana Bengaluru','Dr. T. Rao','Cardiothoracic','Vivek Menon','gold','decommission','2026-05-22 09:45:00+05:30'::timestamptz,NULL,NULL,'pending',55,'Legacy bypass pump awaiting clinician sign-off'
FROM chain_cosign_cycles_r2811 WHERE chain_code='NARAYANA' LIMIT 1;

INSERT INTO cosign_request_events_r2811 (cycle_id, chain_code, hospital_unit, clinician_name, clinician_specialty, engineer_name, engineer_tier, request_type, requested_at, cosigned_at, turnaround_hours, outcome, risk_score, notes)
SELECT id, chain_code, 'Manipal Whitefield','Dr. K. Pillai','ICU','Rohit Gupta','silver','calibration','2026-05-25 07:30:00+05:30'::timestamptz,'2026-05-25 11:00:00+05:30'::timestamptz,3.50,'approved',15,'Ventilator FiO2 calibration'
FROM chain_cosign_cycles_r2811 WHERE chain_code='MANIPAL' LIMIT 1;

INSERT INTO cosign_request_events_r2811 (cycle_id, chain_code, hospital_unit, clinician_name, clinician_specialty, engineer_name, engineer_tier, request_type, requested_at, cosigned_at, turnaround_hours, outcome, risk_score, notes)
SELECT id, chain_code, 'AIIMS Delhi','Dr. P. Singh','Neurology','Sneha Patel','bronze','validation','2026-05-28 10:00:00+05:30'::timestamptz,NULL,NULL,'rejected',74,'EEG validation rejected; missing CDSCO bonded part'
FROM chain_cosign_cycles_r2811 WHERE chain_code='AIIMS' LIMIT 1;

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS r2811_overview();
CREATE OR REPLACE FUNCTION r2811_overview()
RETURNS TABLE (
  total_chains int,
  total_hospitals int,
  total_clinicians int,
  total_engineers int,
  total_requests int,
  total_completed int,
  completion_pct numeric,
  median_turnaround numeric,
  total_breaches int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(hospitals_in_scope),0)::int,
    COALESCE(SUM(clinicians_enrolled),0)::int,
    COALESCE(SUM(engineers_assigned),0)::int,
    COALESCE(SUM(cosign_requests_total),0)::int,
    COALESCE(SUM(cosign_requests_completed),0)::int,
    CASE WHEN SUM(cosign_requests_total) > 0
         THEN ROUND(100.0 * SUM(cosign_requests_completed)::numeric / SUM(cosign_requests_total)::numeric, 2)
         ELSE 0 END,
    COALESCE(ROUND(AVG(median_turnaround_hours)::numeric, 2), 0),
    COALESCE(SUM(sla_breach_count),0)::int
  FROM chain_cosign_cycles_r2811;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_overview() TO authenticated;

DROP FUNCTION IF EXISTS r2811_cycles_list();
CREATE OR REPLACE FUNCTION r2811_cycles_list()
RETURNS SETOF chain_cosign_cycles_r2811
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM chain_cosign_cycles_r2811 ORDER BY median_turnaround_hours ASC, chain_name ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_cycles_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_cycles_list() TO authenticated;

DROP FUNCTION IF EXISTS r2811_events_list();
CREATE OR REPLACE FUNCTION r2811_events_list()
RETURNS SETOF cosign_request_events_r2811
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM cosign_request_events_r2811 ORDER BY requested_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_events_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_events_list() TO authenticated;

DROP FUNCTION IF EXISTS r2811_status_breakdown();
CREATE OR REPLACE FUNCTION r2811_status_breakdown()
RETURNS TABLE (cycle_status text, cycle_count int, total_requests int, avg_turnaround numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.cycle_status,
         COUNT(*)::int,
         COALESCE(SUM(c.cosign_requests_total),0)::int,
         COALESCE(ROUND(AVG(c.median_turnaround_hours)::numeric,2),0)
  FROM chain_cosign_cycles_r2811 c
  GROUP BY c.cycle_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_status_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_status_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2811_outcome_grade();
CREATE OR REPLACE FUNCTION r2811_outcome_grade()
RETURNS TABLE (outcome_grade text, chain_count int, hospitals int, breaches int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.outcome_grade,
         COUNT(*)::int,
         COALESCE(SUM(c.hospitals_in_scope),0)::int,
         COALESCE(SUM(c.sla_breach_count),0)::int
  FROM chain_cosign_cycles_r2811 c
  GROUP BY c.outcome_grade
  ORDER BY c.outcome_grade ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_outcome_grade() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_outcome_grade() TO authenticated;

DROP FUNCTION IF EXISTS r2811_engineer_tier_perf();
CREATE OR REPLACE FUNCTION r2811_engineer_tier_perf()
RETURNS TABLE (engineer_tier text, requests int, approved int, avg_turnaround numeric, avg_risk numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.engineer_tier,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE e.outcome = 'approved')::int,
         COALESCE(ROUND(AVG(e.turnaround_hours)::numeric,2),0),
         COALESCE(ROUND(AVG(e.risk_score)::numeric,2),0)
  FROM cosign_request_events_r2811 e
  GROUP BY e.engineer_tier
  ORDER BY e.engineer_tier ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_engineer_tier_perf() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_engineer_tier_perf() TO authenticated;

DROP FUNCTION IF EXISTS r2811_request_type_mix();
CREATE OR REPLACE FUNCTION r2811_request_type_mix()
RETURNS TABLE (request_type text, total int, approved int, escalated int, pending int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.request_type,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE e.outcome='approved')::int,
         COUNT(*) FILTER (WHERE e.outcome='escalated')::int,
         COUNT(*) FILTER (WHERE e.outcome='pending')::int
  FROM cosign_request_events_r2811 e
  GROUP BY e.request_type
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_request_type_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_request_type_mix() TO authenticated;

DROP FUNCTION IF EXISTS r2811_top_breach_chains();
CREATE OR REPLACE FUNCTION r2811_top_breach_chains()
RETURNS TABLE (chain_code text, chain_name text, sla_breach_count int, cosign_requests_total int, breach_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.chain_code, c.chain_name, c.sla_breach_count, c.cosign_requests_total,
         CASE WHEN c.cosign_requests_total > 0
              THEN ROUND(100.0 * c.sla_breach_count::numeric / c.cosign_requests_total::numeric, 2)
              ELSE 0 END
  FROM chain_cosign_cycles_r2811 c
  ORDER BY c.sla_breach_count DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2811_top_breach_chains() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2811_top_breach_chains() TO authenticated;

COMMIT;
