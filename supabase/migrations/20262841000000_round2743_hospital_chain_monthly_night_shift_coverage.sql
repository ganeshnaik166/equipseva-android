BEGIN;

-- =========================================================================
-- Round 2743: Hospital Chain Monthly Night Shift Coverage
-- chain × night SLA × on-call × emergency × response time × outcome
-- =========================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_night_shift_months_r2743 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  month_label text NOT NULL,
  month_start date NOT NULL,
  hospital_count int NOT NULL,
  night_shifts_total int NOT NULL,
  night_shifts_covered int NOT NULL,
  on_call_engineers int NOT NULL,
  emergency_calls int NOT NULL,
  emergency_resolved int NOT NULL,
  avg_response_minutes numeric(6,2) NOT NULL,
  median_response_minutes numeric(6,2) NOT NULL,
  p95_response_minutes numeric(6,2) NOT NULL,
  sla_breach_count int NOT NULL,
  uptime_pct numeric(5,2) NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('green','amber','red')),
  penalty_rupees bigint NOT NULL DEFAULT 0,
  bonus_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_night_shift_months_r2743 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON hospital_chain_night_shift_months_r2743;
CREATE POLICY founder_all ON hospital_chain_night_shift_months_r2743
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_night_shift_months_r2743
  (chain_code, chain_name, month_label, month_start, hospital_count,
   night_shifts_total, night_shifts_covered, on_call_engineers,
   emergency_calls, emergency_resolved, avg_response_minutes,
   median_response_minutes, p95_response_minutes, sla_breach_count,
   uptime_pct, outcome, penalty_rupees, bonus_rupees, notes)
VALUES
  ('APOLLO-SOUTH','Apollo South Cluster','May 2026','2026-05-01'::date,
   12, 372, 368, 8, 47, 46, 11.40, 9.50, 22.30, 2, 99.46,
   'green', 0, 180000, 'Best chain — only 2 SLA breaches across 372 night shifts'),
  ('FORTIS-NCR','Fortis NCR Cluster','May 2026','2026-05-01'::date,
   9, 279, 271, 6, 38, 35, 14.80, 12.20, 31.40, 8, 97.13,
   'amber', 45000, 0, '3 emergencies unresolved within window — escalation pending'),
  ('MAX-WEST','Max West Belt','May 2026','2026-05-01'::date,
   7, 217, 215, 5, 29, 29, 9.80, 8.10, 18.70, 1, 99.54,
   'green', 0, 95000, 'Strong p95 — cluster lead bonus triggered'),
  ('MANIPAL-KAR','Manipal Karnataka','May 2026','2026-05-01'::date,
   11, 341, 318, 7, 54, 47, 19.70, 17.30, 44.10, 23, 93.26,
   'red', 230000, 0, 'CRITICAL — 23 breaches, p95 over 40min, 7 unresolved emergencies'),
  ('NARAYANA-EAST','Narayana East','May 2026','2026-05-01'::date,
   8, 248, 246, 6, 33, 33, 10.20, 8.90, 20.10, 2, 99.19,
   'green', 0, 110000, 'Consistent — all emergencies resolved'),
  ('AIIMS-PARTNER','AIIMS Partner Network','May 2026','2026-05-01'::date,
   5, 155, 150, 4, 22, 19, 17.50, 15.00, 38.20, 5, 96.77,
   'amber', 30000, 0, 'Borderline — 3 emergencies dropped to morning shift');

CREATE TABLE IF NOT EXISTS hospital_chain_night_incidents_r2743 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_id uuid NOT NULL REFERENCES hospital_chain_night_shift_months_r2743(id) ON DELETE CASCADE,
  chain_code text NOT NULL,
  incident_at timestamptz NOT NULL,
  hospital_unit text NOT NULL,
  device_category text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  response_minutes numeric(6,2) NOT NULL,
  resolution_minutes numeric(6,2),
  on_call_engineer text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('resolved','escalated','dropped','transferred')),
  sla_breach boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_night_incidents_r2743 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON hospital_chain_night_incidents_r2743;
CREATE POLICY founder_all ON hospital_chain_night_incidents_r2743
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_night_incidents_r2743
  (month_id, chain_code, incident_at, hospital_unit, device_category,
   severity, response_minutes, resolution_minutes, on_call_engineer,
   outcome, sla_breach, notes)
SELECT id, 'APOLLO-SOUTH', '2026-05-12 02:14:00+05:30'::timestamptz,
       'Apollo Hyderabad ICU', 'ventilator', 'p0', 8.50, 42.00,
       'Suresh K', 'resolved', false, 'On-call engineer 8min response — ventilator restored'
FROM hospital_chain_night_shift_months_r2743 WHERE chain_code='APOLLO-SOUTH'
UNION ALL
SELECT id, 'FORTIS-NCR', '2026-05-18 03:40:00+05:30'::timestamptz,
       'Fortis Gurgaon CCU', 'monitor', 'p1', 16.20, NULL,
       'Rohit M', 'escalated', true, 'Spare not available — escalated to morning'
FROM hospital_chain_night_shift_months_r2743 WHERE chain_code='FORTIS-NCR'
UNION ALL
SELECT id, 'MAX-WEST', '2026-05-09 01:55:00+05:30'::timestamptz,
       'Max Mumbai OT-3', 'anesthesia-machine', 'p0', 7.80, 38.50,
       'Anil J', 'resolved', false, 'Anesthesia machine valve replaced from local cache'
FROM hospital_chain_night_shift_months_r2743 WHERE chain_code='MAX-WEST'
UNION ALL
SELECT id, 'MANIPAL-KAR', '2026-05-22 04:10:00+05:30'::timestamptz,
       'Manipal Bangalore NICU', 'incubator', 'p0', 28.40, NULL,
       'Vinod R', 'dropped', true, 'CRITICAL — 28min response, baby transferred to backup unit'
FROM hospital_chain_night_shift_months_r2743 WHERE chain_code='MANIPAL-KAR'
UNION ALL
SELECT id, 'NARAYANA-EAST', '2026-05-15 02:30:00+05:30'::timestamptz,
       'Narayana Kolkata Cath Lab', 'cath-lab', 'p1', 11.10, 55.00,
       'Debashis P', 'resolved', false, 'Cath lab table motor — resolved in 55min'
FROM hospital_chain_night_shift_months_r2743 WHERE chain_code='NARAYANA-EAST'
UNION ALL
SELECT id, 'AIIMS-PARTNER', '2026-05-26 03:05:00+05:30'::timestamptz,
       'AIIMS Bhopal ICU-2', 'defibrillator', 'p0', 19.30, NULL,
       'Karthik V', 'transferred', true, 'Defib transferred to morning shift — battery pack ordered'
FROM hospital_chain_night_shift_months_r2743 WHERE chain_code='AIIMS-PARTNER'
UNION ALL
SELECT id, 'MANIPAL-KAR', '2026-05-28 02:50:00+05:30'::timestamptz,
       'Manipal Mangalore ICU', 'ventilator', 'p1', 22.10, NULL,
       'Vinod R', 'escalated', true, 'Second Manipal breach same week — pattern'
FROM hospital_chain_night_shift_months_r2743 WHERE chain_code='MANIPAL-KAR';

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS r2743_chain_month_summary();
CREATE OR REPLACE FUNCTION r2743_chain_month_summary()
RETURNS TABLE (
  total_chains int,
  total_hospitals int,
  total_night_shifts int,
  total_covered int,
  coverage_pct numeric,
  total_emergencies int,
  total_resolved int,
  avg_response numeric,
  total_breaches int,
  total_penalty bigint,
  total_bonus bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int,
         SUM(hospital_count)::int,
         SUM(night_shifts_total)::int,
         SUM(night_shifts_covered)::int,
         ROUND(100.0 * SUM(night_shifts_covered)::numeric / NULLIF(SUM(night_shifts_total),0), 2),
         SUM(emergency_calls)::int,
         SUM(emergency_resolved)::int,
         ROUND(AVG(avg_response_minutes), 2),
         SUM(sla_breach_count)::int,
         SUM(penalty_rupees)::bigint,
         SUM(bonus_rupees)::bigint
  FROM hospital_chain_night_shift_months_r2743;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_chain_month_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_chain_month_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2743_chain_rows();
CREATE OR REPLACE FUNCTION r2743_chain_rows()
RETURNS TABLE (
  id uuid,
  chain_code text,
  chain_name text,
  month_label text,
  hospital_count int,
  night_shifts_total int,
  night_shifts_covered int,
  coverage_pct numeric,
  emergency_calls int,
  emergency_resolved int,
  avg_response_minutes numeric,
  p95_response_minutes numeric,
  sla_breach_count int,
  uptime_pct numeric,
  outcome text,
  penalty_rupees bigint,
  bonus_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.chain_code, m.chain_name, m.month_label, m.hospital_count,
         m.night_shifts_total, m.night_shifts_covered,
         ROUND(100.0 * m.night_shifts_covered::numeric / NULLIF(m.night_shifts_total,0), 2),
         m.emergency_calls, m.emergency_resolved, m.avg_response_minutes,
         m.p95_response_minutes, m.sla_breach_count, m.uptime_pct,
         m.outcome, m.penalty_rupees, m.bonus_rupees
  FROM hospital_chain_night_shift_months_r2743 m
  ORDER BY m.sla_breach_count DESC, m.chain_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_chain_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_chain_rows() TO authenticated;

DROP FUNCTION IF EXISTS r2743_outcome_breakdown();
CREATE OR REPLACE FUNCTION r2743_outcome_breakdown()
RETURNS TABLE (
  outcome text,
  chain_count int,
  total_breaches int,
  total_penalty bigint,
  total_bonus bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.outcome, COUNT(*)::int,
         SUM(m.sla_breach_count)::int,
         SUM(m.penalty_rupees)::bigint,
         SUM(m.bonus_rupees)::bigint
  FROM hospital_chain_night_shift_months_r2743 m
  GROUP BY m.outcome
  ORDER BY CASE m.outcome WHEN 'red' THEN 1 WHEN 'amber' THEN 2 WHEN 'green' THEN 3 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_outcome_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_outcome_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2743_incidents_rows();
CREATE OR REPLACE FUNCTION r2743_incidents_rows()
RETURNS TABLE (
  id uuid,
  chain_code text,
  incident_at timestamptz,
  hospital_unit text,
  device_category text,
  severity text,
  response_minutes numeric,
  resolution_minutes numeric,
  on_call_engineer text,
  outcome text,
  sla_breach boolean,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.chain_code, i.incident_at, i.hospital_unit, i.device_category,
         i.severity, i.response_minutes, i.resolution_minutes,
         i.on_call_engineer, i.outcome, i.sla_breach, i.notes
  FROM hospital_chain_night_incidents_r2743 i
  ORDER BY i.incident_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_incidents_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_incidents_rows() TO authenticated;

DROP FUNCTION IF EXISTS r2743_response_distribution();
CREATE OR REPLACE FUNCTION r2743_response_distribution()
RETURNS TABLE (
  bucket text,
  incident_count int,
  breach_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN i.response_minutes < 10 THEN 'under-10-min'
      WHEN i.response_minutes < 15 THEN '10-15-min'
      WHEN i.response_minutes < 20 THEN '15-20-min'
      WHEN i.response_minutes < 30 THEN '20-30-min'
      ELSE 'over-30-min'
    END,
    COUNT(*)::int,
    SUM(CASE WHEN i.sla_breach THEN 1 ELSE 0 END)::int
  FROM hospital_chain_night_incidents_r2743 i
  GROUP BY 1
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_response_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_response_distribution() TO authenticated;

DROP FUNCTION IF EXISTS r2743_severity_outcome_matrix();
CREATE OR REPLACE FUNCTION r2743_severity_outcome_matrix()
RETURNS TABLE (
  severity text,
  outcome text,
  incident_count int,
  avg_response numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.severity, i.outcome, COUNT(*)::int,
         ROUND(AVG(i.response_minutes), 2)
  FROM hospital_chain_night_incidents_r2743 i
  GROUP BY i.severity, i.outcome
  ORDER BY i.severity, i.outcome;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_severity_outcome_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_severity_outcome_matrix() TO authenticated;

DROP FUNCTION IF EXISTS r2743_red_chains();
CREATE OR REPLACE FUNCTION r2743_red_chains()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  sla_breach_count int,
  uptime_pct numeric,
  penalty_rupees bigint,
  emergency_calls int,
  emergency_resolved int,
  unresolved int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.chain_code, m.chain_name, m.sla_breach_count, m.uptime_pct,
         m.penalty_rupees, m.emergency_calls, m.emergency_resolved,
         (m.emergency_calls - m.emergency_resolved)::int
  FROM hospital_chain_night_shift_months_r2743 m
  WHERE m.outcome IN ('amber','red')
  ORDER BY m.sla_breach_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_red_chains() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_red_chains() TO authenticated;

DROP FUNCTION IF EXISTS r2743_on_call_load();
CREATE OR REPLACE FUNCTION r2743_on_call_load()
RETURNS TABLE (
  on_call_engineer text,
  incident_count int,
  breach_count int,
  avg_response numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.on_call_engineer, COUNT(*)::int,
         SUM(CASE WHEN i.sla_breach THEN 1 ELSE 0 END)::int,
         ROUND(AVG(i.response_minutes), 2)
  FROM hospital_chain_night_incidents_r2743 i
  GROUP BY i.on_call_engineer
  ORDER BY breach_count DESC, incident_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2743_on_call_load() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2743_on_call_load() TO authenticated;

COMMIT;
