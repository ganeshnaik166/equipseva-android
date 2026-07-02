-- Round r2906 — Engineer Monthly Customer Repair Right-First-Time vs Rework Rate
-- HEAVY founder ops round. 2 tables (_r2906) + 7 RPCs. is_founder() gated.

BEGIN;

-- ============================================================================
-- TABLE 1: engineer_monthly_rft_r2906
-- Tracks per-engineer per-month repair RFT vs rework metrics
-- ============================================================================
CREATE TABLE IF NOT EXISTS engineer_monthly_rft_r2906 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid,
  engineer_name text NOT NULL,
  month_label text NOT NULL,
  month_start date NOT NULL,
  total_repairs integer NOT NULL DEFAULT 0,
  rft_repairs integer NOT NULL DEFAULT 0,
  rework_repairs integer NOT NULL DEFAULT 0,
  rft_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  rework_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  avg_repair_hours numeric(6,2) NOT NULL DEFAULT 0,
  customer_csat_avg numeric(3,2) NOT NULL DEFAULT 0,
  tier_at_month text NOT NULL DEFAULT 'silver',
  city text NOT NULL DEFAULT 'Hyderabad',
  risk_flag text NOT NULL DEFAULT 'green',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_rft_r2906 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_monthly_rft_r2906_founder_all ON engineer_monthly_rft_r2906;
CREATE POLICY engineer_monthly_rft_r2906_founder_all ON engineer_monthly_rft_r2906
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- TABLE 2: rework_incidents_r2906
-- Per-rework-incident log of root cause + corrective actions
-- ============================================================================
CREATE TABLE IF NOT EXISTS rework_incidents_r2906 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  original_job_code text NOT NULL,
  rework_job_code text NOT NULL,
  hospital_name text NOT NULL,
  equipment_kind text NOT NULL,
  root_cause text NOT NULL,
  days_to_rework integer NOT NULL DEFAULT 0,
  cost_to_company_rupees integer NOT NULL DEFAULT 0,
  csat_drop numeric(3,2) NOT NULL DEFAULT 0,
  corrective_action text NOT NULL,
  incident_date date NOT NULL,
  severity text NOT NULL DEFAULT 'medium',
  resolved boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE rework_incidents_r2906 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rework_incidents_r2906_founder_all ON rework_incidents_r2906;
CREATE POLICY rework_incidents_r2906_founder_all ON rework_incidents_r2906
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- SEED DATA: engineer_monthly_rft_r2906 (18 rows)
-- ============================================================================
INSERT INTO engineer_monthly_rft_r2906
  (engineer_name, month_label, month_start, total_repairs, rft_repairs, rework_repairs,
   rft_rate_pct, rework_rate_pct, avg_repair_hours, customer_csat_avg, tier_at_month, city, risk_flag)
VALUES
  ('Rajesh Kumar', '2026-04', '2026-04-01'::date, 42, 40, 2, 95.24, 4.76, 3.20, 4.80, 'gold', 'Hyderabad', 'green'),
  ('Rajesh Kumar', '2026-05', '2026-05-01'::date, 48, 47, 1, 97.92, 2.08, 2.95, 4.85, 'gold', 'Hyderabad', 'green'),
  ('Rajesh Kumar', '2026-06', '2026-06-01'::date, 51, 49, 2, 96.08, 3.92, 3.05, 4.82, 'gold', 'Hyderabad', 'green'),
  ('Priya Sharma', '2026-04', '2026-04-01'::date, 38, 35, 3, 92.11, 7.89, 3.50, 4.60, 'silver', 'Bengaluru', 'green'),
  ('Priya Sharma', '2026-05', '2026-05-01'::date, 41, 39, 2, 95.12, 4.88, 3.30, 4.70, 'silver', 'Bengaluru', 'green'),
  ('Priya Sharma', '2026-06', '2026-06-01'::date, 44, 42, 2, 95.45, 4.55, 3.15, 4.75, 'gold', 'Bengaluru', 'green'),
  ('Anil Reddy', '2026-04', '2026-04-01'::date, 35, 29, 6, 82.86, 17.14, 4.80, 3.90, 'silver', 'Chennai', 'amber'),
  ('Anil Reddy', '2026-05', '2026-05-01'::date, 37, 32, 5, 86.49, 13.51, 4.50, 4.10, 'silver', 'Chennai', 'amber'),
  ('Anil Reddy', '2026-06', '2026-06-01'::date, 39, 35, 4, 89.74, 10.26, 4.20, 4.30, 'silver', 'Chennai', 'amber'),
  ('Sunita Patel', '2026-04', '2026-04-01'::date, 28, 20, 8, 71.43, 28.57, 5.60, 3.40, 'bronze', 'Pune', 'red'),
  ('Sunita Patel', '2026-05', '2026-05-01'::date, 30, 24, 6, 80.00, 20.00, 5.10, 3.70, 'bronze', 'Pune', 'amber'),
  ('Sunita Patel', '2026-06', '2026-06-01'::date, 33, 29, 4, 87.88, 12.12, 4.60, 4.00, 'silver', 'Pune', 'amber'),
  ('Vikram Singh', '2026-04', '2026-04-01'::date, 45, 43, 2, 95.56, 4.44, 3.10, 4.78, 'gold', 'Delhi', 'green'),
  ('Vikram Singh', '2026-05', '2026-05-01'::date, 49, 48, 1, 97.96, 2.04, 2.85, 4.88, 'platinum', 'Delhi', 'green'),
  ('Vikram Singh', '2026-06', '2026-06-01'::date, 52, 51, 1, 98.08, 1.92, 2.75, 4.90, 'platinum', 'Delhi', 'green'),
  ('Deepa Iyer', '2026-04', '2026-04-01'::date, 32, 27, 5, 84.38, 15.63, 4.40, 4.05, 'silver', 'Mumbai', 'amber'),
  ('Deepa Iyer', '2026-05', '2026-05-01'::date, 35, 31, 4, 88.57, 11.43, 4.10, 4.25, 'silver', 'Mumbai', 'amber'),
  ('Deepa Iyer', '2026-06', '2026-06-01'::date, 38, 35, 3, 92.11, 7.89, 3.80, 4.45, 'gold', 'Mumbai', 'green');

-- ============================================================================
-- SEED DATA: rework_incidents_r2906 (15 rows)
-- ============================================================================
INSERT INTO rework_incidents_r2906
  (engineer_name, original_job_code, rework_job_code, hospital_name, equipment_kind,
   root_cause, days_to_rework, cost_to_company_rupees, csat_drop, corrective_action,
   incident_date, severity, resolved)
VALUES
  ('Sunita Patel', 'RJ-21401', 'RJ-21455', 'Apollo Hyderabad', 'Ventilator',
   'Incorrect part substitution', 3, 4500, 1.20, 'Mandatory parts verification SOP issued',
   '2026-04-08'::date, 'high', true),
  ('Sunita Patel', 'RJ-21478', 'RJ-21512', 'KIMS Pune', 'Defibrillator',
   'Calibration skipped', 2, 2800, 0.90, 'Calibration checklist enforced',
   '2026-04-15'::date, 'high', true),
  ('Anil Reddy', 'RJ-21523', 'RJ-21561', 'Fortis Chennai', 'Dental Chair',
   'Loose connector reseated improperly', 5, 1800, 0.60, 'Engineer retraining scheduled',
   '2026-04-20'::date, 'medium', true),
  ('Sunita Patel', 'RJ-21580', 'RJ-21622', 'Manipal Pune', 'ECG Monitor',
   'Software firmware not updated', 4, 3200, 0.80, 'Auto-update tool deployed',
   '2026-04-22'::date, 'medium', true),
  ('Anil Reddy', 'RJ-21655', 'RJ-21701', 'MGM Chennai', 'X-Ray Machine',
   'Test not performed post-repair', 6, 5500, 1.10, 'Post-repair test checklist mandatory',
   '2026-05-02'::date, 'high', true),
  ('Deepa Iyer', 'RJ-21712', 'RJ-21748', 'Hinduja Mumbai', 'Ultrasound',
   'Probe seating issue missed', 4, 2200, 0.50, 'Visual inspection protocol added',
   '2026-05-05'::date, 'medium', true),
  ('Sunita Patel', 'RJ-21766', 'RJ-21805', 'Ruby Hall Pune', 'Patient Monitor',
   'Battery diagnostic skipped', 3, 2600, 0.70, 'Battery test added to checklist',
   '2026-05-10'::date, 'medium', true),
  ('Anil Reddy', 'RJ-21822', 'RJ-21861', 'Apollo Chennai', 'Anaesthesia Workstation',
   'Vapouriser leak undetected', 7, 8200, 1.50, 'Leak detection mandatory',
   '2026-05-14'::date, 'high', true),
  ('Deepa Iyer', 'RJ-21878', 'RJ-21915', 'Kokilaben Mumbai', 'Surgical Light',
   'LED driver replacement incomplete', 5, 1900, 0.40, 'Driver test added',
   '2026-05-18'::date, 'low', true),
  ('Priya Sharma', 'RJ-21934', 'RJ-21968', 'Manipal Bengaluru', 'Infusion Pump',
   'Occlusion sensor uncalibrated', 4, 1500, 0.30, 'Sensor cal added to SOP',
   '2026-05-22'::date, 'low', true),
  ('Sunita Patel', 'RJ-21999', 'RJ-22034', 'Sahyadri Pune', 'Centrifuge',
   'Rotor balance check missed', 3, 1200, 0.40, 'Balance check enforced',
   '2026-06-02'::date, 'low', false),
  ('Anil Reddy', 'RJ-22052', 'RJ-22088', 'Global Chennai', 'Autoclave',
   'Pressure seal undermined', 5, 3400, 0.90, 'Seal test added',
   '2026-06-06'::date, 'medium', false),
  ('Deepa Iyer', 'RJ-22102', 'RJ-22134', 'Lilavati Mumbai', 'CT Scanner',
   'Cooling system not purged', 8, 12500, 1.80, 'Purge SOP critical',
   '2026-06-10'::date, 'high', false),
  ('Rajesh Kumar', 'RJ-22156', 'RJ-22189', 'Yashoda Hyderabad', 'Hematology Analyzer',
   'Reagent line misconnected', 2, 2100, 0.50, 'Line label colour code',
   '2026-06-14'::date, 'medium', true),
  ('Vikram Singh', 'RJ-22198', 'RJ-22221', 'AIIMS Delhi', 'Dialysis Machine',
   'Disinfection cycle skipped', 1, 1800, 0.30, 'Cycle enforced via interlock',
   '2026-06-18'::date, 'low', true);

-- ============================================================================
-- RPC 1: founder_r2906_overview — top-line KPI cards
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_r2906_overview()
RETURNS TABLE (
  metric text,
  value text,
  context text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT 'Total Repairs (3 mo)'::text,
         SUM(total_repairs)::text,
         'across all engineers'::text
  FROM engineer_monthly_rft_r2906
  UNION ALL
  SELECT 'Network RFT %'::text,
         ROUND(100.0 * SUM(rft_repairs)::numeric / NULLIF(SUM(total_repairs),0), 2)::text || '%',
         'right-first-time rate'::text
  FROM engineer_monthly_rft_r2906
  UNION ALL
  SELECT 'Network Rework %'::text,
         ROUND(100.0 * SUM(rework_repairs)::numeric / NULLIF(SUM(total_repairs),0), 2)::text || '%',
         'rework rate'::text
  FROM engineer_monthly_rft_r2906
  UNION ALL
  SELECT 'Rework Cost Total'::text,
         '₹' || COALESCE(SUM(cost_to_company_rupees),0)::text,
         'cost-to-company from rework'::text
  FROM rework_incidents_r2906
  UNION ALL
  SELECT 'Open Rework Incidents'::text,
         COUNT(*)::text,
         'not yet resolved'::text
  FROM rework_incidents_r2906
  WHERE resolved = false
  UNION ALL
  SELECT 'Red-Flag Engineers'::text,
         COUNT(DISTINCT engineer_name)::text,
         'flagged red in latest month'::text
  FROM engineer_monthly_rft_r2906
  WHERE risk_flag = 'red';
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2906_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2906_overview() TO authenticated;

-- ============================================================================
-- RPC 2: founder_r2906_engineer_leaderboard — RFT ranking
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_r2906_engineer_leaderboard()
RETURNS TABLE (
  engineer_name text,
  city text,
  tier_at_month text,
  total_repairs bigint,
  rft_rate_pct numeric,
  rework_rate_pct numeric,
  customer_csat_avg numeric,
  risk_flag text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT e.engineer_name,
         MAX(e.city),
         MAX(e.tier_at_month),
         SUM(e.total_repairs)::bigint,
         ROUND(100.0 * SUM(e.rft_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2),
         ROUND(100.0 * SUM(e.rework_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2),
         ROUND(AVG(e.customer_csat_avg), 2),
         MAX(e.risk_flag)
  FROM engineer_monthly_rft_r2906 e
  GROUP BY e.engineer_name
  ORDER BY ROUND(100.0 * SUM(e.rft_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2906_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2906_engineer_leaderboard() TO authenticated;

-- ============================================================================
-- RPC 3: founder_r2906_monthly_trend — month-over-month trend
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_r2906_monthly_trend()
RETURNS TABLE (
  month_label text,
  total_repairs bigint,
  rft_rate_pct numeric,
  rework_rate_pct numeric,
  avg_csat numeric,
  avg_repair_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT e.month_label,
         SUM(e.total_repairs)::bigint,
         ROUND(100.0 * SUM(e.rft_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2),
         ROUND(100.0 * SUM(e.rework_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2),
         ROUND(AVG(e.customer_csat_avg), 2),
         ROUND(AVG(e.avg_repair_hours), 2)
  FROM engineer_monthly_rft_r2906 e
  GROUP BY e.month_label
  ORDER BY e.month_label;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2906_monthly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2906_monthly_trend() TO authenticated;

-- ============================================================================
-- RPC 4: founder_r2906_city_breakdown — city-level RFT performance
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_r2906_city_breakdown()
RETURNS TABLE (
  city text,
  engineer_count bigint,
  total_repairs bigint,
  rft_rate_pct numeric,
  rework_rate_pct numeric,
  avg_csat numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT e.city,
         COUNT(DISTINCT e.engineer_name)::bigint,
         SUM(e.total_repairs)::bigint,
         ROUND(100.0 * SUM(e.rft_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2),
         ROUND(100.0 * SUM(e.rework_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2),
         ROUND(AVG(e.customer_csat_avg), 2)
  FROM engineer_monthly_rft_r2906 e
  GROUP BY e.city
  ORDER BY ROUND(100.0 * SUM(e.rft_repairs)::numeric / NULLIF(SUM(e.total_repairs),0), 2) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2906_city_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2906_city_breakdown() TO authenticated;

-- ============================================================================
-- RPC 5: founder_r2906_root_cause_distribution — top rework causes
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_r2906_root_cause_distribution()
RETURNS TABLE (
  root_cause text,
  incident_count bigint,
  total_cost_rupees bigint,
  avg_csat_drop numeric,
  open_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT r.root_cause,
         COUNT(*)::bigint,
         SUM(r.cost_to_company_rupees)::bigint,
         ROUND(AVG(r.csat_drop), 2),
         COUNT(*) FILTER (WHERE r.resolved = false)::bigint
  FROM rework_incidents_r2906 r
  GROUP BY r.root_cause
  ORDER BY COUNT(*) DESC, SUM(r.cost_to_company_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2906_root_cause_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2906_root_cause_distribution() TO authenticated;

-- ============================================================================
-- RPC 6: founder_r2906_high_severity_open — open high-severity rework incidents
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_r2906_high_severity_open()
RETURNS TABLE (
  engineer_name text,
  hospital_name text,
  equipment_kind text,
  root_cause text,
  severity text,
  cost_to_company_rupees integer,
  incident_date date,
  corrective_action text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT r.engineer_name,
         r.hospital_name,
         r.equipment_kind,
         r.root_cause,
         r.severity,
         r.cost_to_company_rupees,
         r.incident_date,
         r.corrective_action
  FROM rework_incidents_r2906 r
  WHERE r.resolved = false
  ORDER BY CASE r.severity WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
           r.incident_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2906_high_severity_open() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2906_high_severity_open() TO authenticated;

-- ============================================================================
-- RPC 7: founder_r2906_red_flag_engineers — at-risk engineers needing intervention
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_r2906_red_flag_engineers()
RETURNS TABLE (
  engineer_name text,
  city text,
  month_label text,
  rft_rate_pct numeric,
  rework_rate_pct numeric,
  customer_csat_avg numeric,
  risk_flag text,
  recommendation text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT e.engineer_name,
         e.city,
         e.month_label,
         e.rft_rate_pct,
         e.rework_rate_pct,
         e.customer_csat_avg,
         e.risk_flag,
         CASE
           WHEN e.risk_flag = 'red' THEN 'Immediate retraining + mentor pairing'
           WHEN e.risk_flag = 'amber' AND e.rework_rate_pct >= 10 THEN 'Schedule SOP refresh + shadow audit'
           WHEN e.risk_flag = 'amber' THEN 'Light-touch coaching call'
           ELSE 'Monitor only'
         END::text
  FROM engineer_monthly_rft_r2906 e
  WHERE e.risk_flag IN ('amber','red')
  ORDER BY CASE e.risk_flag WHEN 'red' THEN 1 ELSE 2 END,
           e.rework_rate_pct DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2906_red_flag_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2906_red_flag_engineers() TO authenticated;

COMMIT;
