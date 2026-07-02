BEGIN;

-- =========================================================================
-- Round 2716 — Customer monthly equipment noise/vibration complaint console
-- =========================================================================

-- ---- Table 1: complaint log ---------------------------------------------
CREATE TABLE IF NOT EXISTS customer_noise_vibration_complaints_r2716 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_on date NOT NULL,
  hospital_name text NOT NULL,
  equipment_model text NOT NULL,
  equipment_serial text NOT NULL,
  complaint_kind text NOT NULL CHECK (complaint_kind IN ('noise','vibration','both')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  decibel_level numeric(5,2),
  vibration_mm_s numeric(5,2),
  root_cause text NOT NULL,
  fix_action text NOT NULL,
  fix_status text NOT NULL CHECK (fix_status IN ('open','in_progress','fixed','monitoring','escalated')),
  follow_up_on date,
  engineer_assigned text,
  cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  customer_satisfied boolean,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_noise_vibration_complaints_r2716 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_noise_vibration_complaints_r2716;
CREATE POLICY founder_all ON customer_noise_vibration_complaints_r2716
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_noise_vibration_complaints_r2716
  (reported_on, hospital_name, equipment_model, equipment_serial, complaint_kind, severity,
   decibel_level, vibration_mm_s, root_cause, fix_action, fix_status, follow_up_on,
   engineer_assigned, cost_rupees, customer_satisfied, notes)
VALUES
  ('2026-06-01'::date, 'Apollo Hyd',     'GE Optima CT660',   'CT660-A14', 'noise',     'high',     78.5, NULL, 'gantry bearing wear',          'replace gantry bearing',    'fixed',      '2026-06-21'::date, 'Ravi K',    18500.00, true,  'noise dropped to 58 dB post-fix'),
  ('2026-06-03'::date, 'KIMS Sec',       'Siemens Magnetom',  'MR-SEC-2',  'vibration', 'critical', NULL, 6.80, 'chiller mount loose',          'retorque + dampen mount',   'monitoring', '2026-06-28'::date, 'Anita M',    7200.00, true,  'vibration 6.8 -> 1.9 mm/s'),
  ('2026-06-05'::date, 'Yashoda Malak',  'Philips IntelliVue','IV-MAL-7',  'noise',     'medium',   65.0, NULL, 'fan dust accumulation',        'fan clean + filter swap',   'fixed',      '2026-06-25'::date, 'Suresh P',   1200.00, true,  NULL),
  ('2026-06-08'::date, 'Continental',    'Mindray DC-70',     'DC70-CON3', 'both',      'high',     72.0, 4.20, 'pump impeller imbalance',      'balance impeller + bolts',  'in_progress','2026-06-30'::date, 'Vikram J',   9800.00, NULL,  'parts on order'),
  ('2026-06-10'::date, 'CARE Banjara',   'GE Vivid E95',      'VE95-CB1',  'vibration', 'low',      NULL, 2.10, 'cable harness loose',          'secure cable harness',      'fixed',      '2026-06-22'::date, 'Ravi K',      600.00, true,  NULL),
  ('2026-06-12'::date, 'Sunshine',       'Drager Evita V500', 'EV500-SS9', 'noise',     'critical', 84.3, NULL, 'turbine blade crack',          'turbine assembly replace',  'escalated',  '2026-06-24'::date, 'Anita M',   42000.00, false, 'OEM RMA opened'),
  ('2026-06-14'::date, 'AIG Gachibowli', 'Olympus CV-190',    'CV190-AG2', 'vibration', 'medium',   NULL, 3.40, 'trolley caster bearing dry',   'lubricate + replace caster','fixed',      '2026-06-26'::date, 'Suresh P',   1500.00, true,  NULL),
  ('2026-06-16'::date, 'Apollo Hyd',     'Stryker SDC3',      'SDC3-AH4',  'noise',     'low',      62.0, NULL, 'cooling fan bearing chatter',  'replace cooling fan',       'open',       '2026-06-29'::date, 'Vikram J',   2800.00, NULL,  NULL);

-- ---- Table 2: rolling monthly trend summary -----------------------------
CREATE TABLE IF NOT EXISTS customer_noise_vibration_monthly_trend_r2716 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trend_month date NOT NULL,
  equipment_family text NOT NULL,
  complaints_count int NOT NULL DEFAULT 0,
  fixed_count int NOT NULL DEFAULT 0,
  avg_resolution_days numeric(5,2),
  avg_db_post_fix numeric(5,2),
  avg_vib_post_fix numeric(5,2),
  recurrence_pct numeric(5,2),
  top_cause text,
  recommended_action text,
  status text NOT NULL CHECK (status IN ('improving','flat','worsening')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_noise_vibration_monthly_trend_r2716 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_noise_vibration_monthly_trend_r2716;
CREATE POLICY founder_all ON customer_noise_vibration_monthly_trend_r2716
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_noise_vibration_monthly_trend_r2716
  (trend_month, equipment_family, complaints_count, fixed_count, avg_resolution_days,
   avg_db_post_fix, avg_vib_post_fix, recurrence_pct, top_cause, recommended_action, status)
VALUES
  ('2026-04-01'::date, 'CT scanners',         12,  9, 6.40, 60.20, NULL, 12.50, 'gantry bearing wear',     'preempt bearing swap @ 18mo',      'flat'),
  ('2026-05-01'::date, 'CT scanners',         14, 12, 5.10, 58.50, NULL,  8.30, 'gantry bearing wear',     'preempt bearing swap @ 18mo',      'improving'),
  ('2026-06-01'::date, 'CT scanners',          8,  6, 4.80, 57.10, NULL,  6.20, 'gantry bearing wear',     'rollout preemptive program Q3',    'improving'),
  ('2026-04-01'::date, 'MRI scanners',         5,  4, 8.20, NULL,  2.30, 20.00, 'chiller mount loose',      'add vibration dampers OEM kit',    'flat'),
  ('2026-05-01'::date, 'MRI scanners',         7,  5, 7.50, NULL,  2.10, 14.30, 'chiller mount loose',      'add vibration dampers OEM kit',    'improving'),
  ('2026-06-01'::date, 'MRI scanners',         3,  2, 6.10, NULL,  1.90, 10.00, 'chiller mount loose',      'add vibration dampers OEM kit',    'improving'),
  ('2026-06-01'::date, 'ventilators',          4,  2, 5.50, 64.20, NULL, 25.00, 'turbine blade crack',     'OEM turbine recall escalation',    'worsening'),
  ('2026-06-01'::date, 'patient monitors',     6,  6, 2.30, 56.40, NULL,  0.00, 'fan dust accumulation',    'quarterly fan filter program',     'improving');

-- =========================================================================
-- RPCs
-- =========================================================================

-- 1) Top-line KPIs
DROP FUNCTION IF EXISTS founder_r2716_kpis();
CREATE OR REPLACE FUNCTION founder_r2716_kpis()
RETURNS TABLE (
  total_complaints int,
  open_count int,
  fixed_count int,
  critical_count int,
  avg_cost_rupees numeric,
  satisfied_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE fix_status = 'open')::int,
    COUNT(*) FILTER (WHERE fix_status = 'fixed')::int,
    COUNT(*) FILTER (WHERE severity = 'critical')::int,
    COALESCE(ROUND(AVG(cost_rupees)::numeric, 2), 0),
    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE customer_satisfied IS TRUE)::numeric
                   / NULLIF(COUNT(*) FILTER (WHERE customer_satisfied IS NOT NULL), 0), 2), 0)
  FROM customer_noise_vibration_complaints_r2716;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_kpis() TO authenticated;

-- 2) Recent complaints (capped)
DROP FUNCTION IF EXISTS founder_r2716_recent_complaints(int);
CREATE OR REPLACE FUNCTION founder_r2716_recent_complaints(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  reported_on date,
  hospital_name text,
  equipment_model text,
  complaint_kind text,
  severity text,
  root_cause text,
  fix_action text,
  fix_status text,
  follow_up_on date,
  cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.reported_on, c.hospital_name, c.equipment_model, c.complaint_kind,
         c.severity, c.root_cause, c.fix_action, c.fix_status, c.follow_up_on, c.cost_rupees
  FROM customer_noise_vibration_complaints_r2716 c
  ORDER BY c.reported_on DESC, c.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_recent_complaints(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_recent_complaints(int) TO authenticated;

-- 3) Severity breakdown
DROP FUNCTION IF EXISTS founder_r2716_severity_breakdown();
CREATE OR REPLACE FUNCTION founder_r2716_severity_breakdown()
RETURNS TABLE (
  severity text,
  cnt int,
  avg_cost numeric,
  fixed_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.severity,
    COUNT(*)::int,
    COALESCE(ROUND(AVG(c.cost_rupees)::numeric, 2), 0),
    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE c.fix_status = 'fixed')::numeric
                   / NULLIF(COUNT(*), 0), 2), 0)
  FROM customer_noise_vibration_complaints_r2716 c
  GROUP BY c.severity
  ORDER BY CASE c.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_severity_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_severity_breakdown() TO authenticated;

-- 4) Top root causes
DROP FUNCTION IF EXISTS founder_r2716_top_causes(int);
CREATE OR REPLACE FUNCTION founder_r2716_top_causes(p_limit int DEFAULT 10)
RETURNS TABLE (
  root_cause text,
  cnt int,
  total_cost numeric,
  fixed_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.root_cause,
    COUNT(*)::int,
    COALESCE(SUM(c.cost_rupees), 0),
    COALESCE(ROUND(100.0 * COUNT(*) FILTER (WHERE c.fix_status = 'fixed')::numeric
                   / NULLIF(COUNT(*), 0), 2), 0)
  FROM customer_noise_vibration_complaints_r2716 c
  GROUP BY c.root_cause
  ORDER BY COUNT(*) DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_top_causes(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_top_causes(int) TO authenticated;

-- 5) Monthly trend
DROP FUNCTION IF EXISTS founder_r2716_monthly_trend();
CREATE OR REPLACE FUNCTION founder_r2716_monthly_trend()
RETURNS TABLE (
  trend_month date,
  equipment_family text,
  complaints_count int,
  fixed_count int,
  avg_resolution_days numeric,
  recurrence_pct numeric,
  status text,
  recommended_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.trend_month, t.equipment_family, t.complaints_count, t.fixed_count,
         t.avg_resolution_days, t.recurrence_pct, t.status, t.recommended_action
  FROM customer_noise_vibration_monthly_trend_r2716 t
  ORDER BY t.trend_month DESC, t.equipment_family ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_monthly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_monthly_trend() TO authenticated;

-- 6) Pending follow-ups
DROP FUNCTION IF EXISTS founder_r2716_pending_followups();
CREATE OR REPLACE FUNCTION founder_r2716_pending_followups()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  equipment_model text,
  severity text,
  fix_status text,
  follow_up_on date,
  days_remaining int,
  engineer_assigned text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.hospital_name, c.equipment_model, c.severity, c.fix_status,
         c.follow_up_on,
         (c.follow_up_on - CURRENT_DATE)::int AS days_remaining,
         c.engineer_assigned
  FROM customer_noise_vibration_complaints_r2716 c
  WHERE c.fix_status IN ('open','in_progress','monitoring','escalated')
    AND c.follow_up_on IS NOT NULL
  ORDER BY c.follow_up_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_pending_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_pending_followups() TO authenticated;

-- 7) Engineer workload
DROP FUNCTION IF EXISTS founder_r2716_engineer_workload();
CREATE OR REPLACE FUNCTION founder_r2716_engineer_workload()
RETURNS TABLE (
  engineer_assigned text,
  cases int,
  open_cases int,
  fixed_cases int,
  total_cost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(c.engineer_assigned, 'unassigned'),
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE c.fix_status IN ('open','in_progress'))::int,
    COUNT(*) FILTER (WHERE c.fix_status = 'fixed')::int,
    COALESCE(SUM(c.cost_rupees), 0)
  FROM customer_noise_vibration_complaints_r2716 c
  GROUP BY COALESCE(c.engineer_assigned, 'unassigned')
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_engineer_workload() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_engineer_workload() TO authenticated;

-- 8) Equipment family hotspots
DROP FUNCTION IF EXISTS founder_r2716_equipment_hotspots();
CREATE OR REPLACE FUNCTION founder_r2716_equipment_hotspots()
RETURNS TABLE (
  equipment_model text,
  cases int,
  critical_cases int,
  avg_db numeric,
  avg_vib numeric,
  total_cost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.equipment_model,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE c.severity = 'critical')::int,
    ROUND(AVG(c.decibel_level)::numeric, 2),
    ROUND(AVG(c.vibration_mm_s)::numeric, 2),
    COALESCE(SUM(c.cost_rupees), 0)
  FROM customer_noise_vibration_complaints_r2716 c
  GROUP BY c.equipment_model
  ORDER BY COUNT(*) DESC, COUNT(*) FILTER (WHERE c.severity = 'critical') DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2716_equipment_hotspots() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2716_equipment_hotspots() TO authenticated;

COMMIT;
