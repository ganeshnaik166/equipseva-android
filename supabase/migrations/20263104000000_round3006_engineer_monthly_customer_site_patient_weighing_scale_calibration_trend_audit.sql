-- Round r3006: Engineer Monthly Customer Site Patient-Weighing-Scale Calibration & Trend Audit
-- 2 tables, 7 RPCs, is_founder() gated

BEGIN;

-- =====================================================
-- Table 1: Monthly calibration visits per scale per site
-- =====================================================
CREATE TABLE IF NOT EXISTS public.weighing_scale_calibration_visits_r3006 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  visit_month date NOT NULL,
  site_name text NOT NULL,
  city text NOT NULL,
  scale_asset_tag text NOT NULL,
  scale_model text NOT NULL,
  engineer_name text NOT NULL,
  visit_status text NOT NULL CHECK (visit_status IN ('scheduled','in_transit','on_site','completed','missed','rescheduled')),
  pre_cal_drift_grams numeric(8,2) NOT NULL,
  post_cal_drift_grams numeric(8,2) NOT NULL,
  test_load_kg numeric(6,2) NOT NULL,
  ambient_temp_c numeric(5,2) NOT NULL,
  pass_fail text NOT NULL CHECK (pass_fail IN ('pass','fail','marginal','retest_required')),
  certificate_url text,
  next_due_on date NOT NULL,
  trend_flag text NOT NULL CHECK (trend_flag IN ('stable','drifting_up','drifting_down','erratic','baseline'))
);

ALTER TABLE public.weighing_scale_calibration_visits_r3006 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS calvisits_r3006_founder_select ON public.weighing_scale_calibration_visits_r3006;
CREATE POLICY calvisits_r3006_founder_select ON public.weighing_scale_calibration_visits_r3006
  FOR SELECT TO authenticated USING (public.is_founder());

REVOKE ALL ON public.weighing_scale_calibration_visits_r3006 FROM PUBLIC, anon;
GRANT SELECT ON public.weighing_scale_calibration_visits_r3006 TO authenticated;

-- =====================================================
-- Table 2: Patient weight discrepancy incidents
-- =====================================================
CREATE TABLE IF NOT EXISTS public.weighing_scale_patient_incidents_r3006 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  incident_date date NOT NULL,
  site_name text NOT NULL,
  scale_asset_tag text NOT NULL,
  patient_ref_code text NOT NULL,
  ward text NOT NULL,
  reported_weight_kg numeric(6,2) NOT NULL,
  verified_weight_kg numeric(6,2) NOT NULL,
  delta_grams numeric(8,2) NOT NULL,
  severity text NOT NULL CHECK (severity IN ('info','minor','moderate','major','critical')),
  clinical_impact text NOT NULL CHECK (clinical_impact IN ('none','low','medium','high','adverse_event')),
  root_cause text NOT NULL CHECK (root_cause IN ('drift','platform_uneven','load_cell_fault','zeroing_skipped','battery_low','user_error','unknown')),
  resolution_status text NOT NULL CHECK (resolution_status IN ('open','investigating','calibrated','part_replaced','closed','escalated')),
  resolved_on date
);

ALTER TABLE public.weighing_scale_patient_incidents_r3006 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS patincidents_r3006_founder_select ON public.weighing_scale_patient_incidents_r3006;
CREATE POLICY patincidents_r3006_founder_select ON public.weighing_scale_patient_incidents_r3006
  FOR SELECT TO authenticated USING (public.is_founder());

REVOKE ALL ON public.weighing_scale_patient_incidents_r3006 FROM PUBLIC, anon;
GRANT SELECT ON public.weighing_scale_patient_incidents_r3006 TO authenticated;

-- =====================================================
-- Seeds: calibration visits (18 rows)
-- =====================================================
INSERT INTO public.weighing_scale_calibration_visits_r3006 (visit_month, site_name, city, scale_asset_tag, scale_model, engineer_name, visit_status, pre_cal_drift_grams, post_cal_drift_grams, test_load_kg, ambient_temp_c, pass_fail, certificate_url, next_due_on, trend_flag) VALUES
('2026-05-01'::date, 'Apollo Jubilee', 'Hyderabad', 'SCL-AP-001', 'Seca 769', 'Ravi Kumar', 'completed', 45.20, 3.10, 50.00, 24.50, 'pass', 'https://cert/r3006/1.pdf', '2026-06-01'::date, 'stable'),
('2026-05-01'::date, 'Yashoda Secunderabad', 'Hyderabad', 'SCL-YS-014', 'Seca 769', 'Anita Patel', 'completed', 82.00, 5.40, 50.00, 26.10, 'pass', 'https://cert/r3006/2.pdf', '2026-06-01'::date, 'drifting_up'),
('2026-05-02'::date, 'KIMS Kondapur', 'Hyderabad', 'SCL-KK-007', 'Detecto 6855', 'Manoj Reddy', 'completed', 28.50, 2.10, 100.00, 25.00, 'pass', 'https://cert/r3006/3.pdf', '2026-06-02'::date, 'stable'),
('2026-05-03'::date, 'Continental Gachibowli', 'Hyderabad', 'SCL-CG-003', 'Tanita BWB-800', 'Sneha Iyer', 'completed', 110.00, 8.20, 50.00, 27.40, 'marginal', 'https://cert/r3006/4.pdf', '2026-05-17'::date, 'drifting_up'),
('2026-05-04'::date, 'Rainbow Banjara', 'Hyderabad', 'SCL-RB-022', 'Seca 354 (paed)', 'Ravi Kumar', 'completed', 12.40, 1.80, 15.00, 23.80, 'pass', 'https://cert/r3006/5.pdf', '2026-06-04'::date, 'baseline'),
('2026-05-05'::date, 'Care Banjara Hills', 'Hyderabad', 'SCL-CB-019', 'Seca 769', 'Anita Patel', 'completed', 65.00, 4.60, 50.00, 25.50, 'pass', 'https://cert/r3006/6.pdf', '2026-06-05'::date, 'drifting_up'),
('2026-05-06'::date, 'Manipal Vijayawada', 'Vijayawada', 'SCL-MV-011', 'Detecto 6855', 'Vikram Joshi', 'completed', 95.00, 6.10, 100.00, 28.20, 'pass', 'https://cert/r3006/7.pdf', '2026-06-06'::date, 'drifting_up'),
('2026-05-07'::date, 'AIG Gachibowli', 'Hyderabad', 'SCL-AI-005', 'Tanita BWB-800', 'Manoj Reddy', 'completed', 280.00, 240.00, 50.00, 26.80, 'fail', NULL, '2026-05-14'::date, 'erratic'),
('2026-05-08'::date, 'Sunshine Paradise', 'Secunderabad', 'SCL-SP-031', 'Seca 769', 'Sneha Iyer', 'completed', 38.00, 2.90, 50.00, 24.90, 'pass', 'https://cert/r3006/9.pdf', '2026-06-08'::date, 'stable'),
('2026-05-09'::date, 'Star Nampally', 'Hyderabad', 'SCL-SN-028', 'Detecto 6855', 'Ravi Kumar', 'missed', 0.00, 0.00, 0.00, 0.00, 'retest_required', NULL, '2026-05-16'::date, 'baseline'),
('2026-05-10'::date, 'Olive Mehdipatnam', 'Hyderabad', 'SCL-OM-017', 'Seca 769', 'Anita Patel', 'completed', 52.00, 3.40, 50.00, 25.30, 'pass', 'https://cert/r3006/11.pdf', '2026-06-10'::date, 'stable'),
('2026-05-11'::date, 'Aware Gachibowli', 'Hyderabad', 'SCL-AW-009', 'Tanita BWB-800', 'Manoj Reddy', 'completed', 73.00, 4.80, 50.00, 26.50, 'pass', 'https://cert/r3006/12.pdf', '2026-06-11'::date, 'drifting_down'),
('2026-05-12'::date, 'Renova Sarojini', 'Hyderabad', 'SCL-RS-013', 'Seca 354 (paed)', 'Vikram Joshi', 'completed', 18.00, 2.10, 15.00, 24.00, 'pass', 'https://cert/r3006/13.pdf', '2026-06-12'::date, 'baseline'),
('2026-05-13'::date, 'KIMS Vizag', 'Visakhapatnam', 'SCL-KV-025', 'Detecto 6855', 'Sneha Iyer', 'rescheduled', 0.00, 0.00, 0.00, 0.00, 'retest_required', NULL, '2026-05-20'::date, 'baseline'),
('2026-05-14'::date, 'AIG Gachibowli', 'Hyderabad', 'SCL-AI-005', 'Tanita BWB-800', 'Manoj Reddy', 'completed', 240.00, 8.80, 50.00, 26.20, 'pass', 'https://cert/r3006/15.pdf', '2026-06-14'::date, 'stable'),
('2026-05-15'::date, 'Continental Gachibowli', 'Hyderabad', 'SCL-CG-003', 'Tanita BWB-800', 'Sneha Iyer', 'completed', 8.20, 1.40, 50.00, 24.60, 'pass', 'https://cert/r3006/16.pdf', '2026-06-15'::date, 'stable'),
('2026-05-16'::date, 'Apollo Health City', 'Hyderabad', 'SCL-AH-040', 'Seca 769', 'Ravi Kumar', 'completed', 41.00, 2.60, 50.00, 25.10, 'pass', 'https://cert/r3006/17.pdf', '2026-06-16'::date, 'stable'),
('2026-05-17'::date, 'Yashoda Somajiguda', 'Hyderabad', 'SCL-YG-006', 'Detecto 6855', 'Anita Patel', 'on_site', 58.00, 0.00, 100.00, 26.00, 'retest_required', NULL, '2026-05-18'::date, 'drifting_up');

-- =====================================================
-- Seeds: patient incidents (15 rows)
-- =====================================================
INSERT INTO public.weighing_scale_patient_incidents_r3006 (incident_date, site_name, scale_asset_tag, patient_ref_code, ward, reported_weight_kg, verified_weight_kg, delta_grams, severity, clinical_impact, root_cause, resolution_status, resolved_on) VALUES
('2026-05-02'::date, 'Yashoda Secunderabad', 'SCL-YS-014', 'PT-2049', 'Oncology', 64.20, 64.30, -100.00, 'minor', 'none', 'drift', 'calibrated', '2026-05-03'::date),
('2026-05-03'::date, 'Continental Gachibowli', 'SCL-CG-003', 'PT-1188', 'Paediatrics', 18.40, 18.55, -150.00, 'moderate', 'low', 'drift', 'calibrated', '2026-05-04'::date),
('2026-05-04'::date, 'AIG Gachibowli', 'SCL-AI-005', 'PT-3301', 'ICU', 72.00, 72.85, -850.00, 'major', 'medium', 'load_cell_fault', 'part_replaced', '2026-05-07'::date),
('2026-05-05'::date, 'AIG Gachibowli', 'SCL-AI-005', 'PT-3302', 'ICU', 58.40, 59.10, -700.00, 'major', 'medium', 'load_cell_fault', 'part_replaced', '2026-05-07'::date),
('2026-05-06'::date, 'Rainbow Banjara', 'SCL-RB-022', 'PT-9912', 'Neonatal', 3.45, 3.49, -40.00, 'critical', 'high', 'zeroing_skipped', 'closed', '2026-05-06'::date),
('2026-05-07'::date, 'Care Banjara Hills', 'SCL-CB-019', 'PT-4477', 'General', 88.10, 88.30, -200.00, 'minor', 'none', 'drift', 'closed', '2026-05-08'::date),
('2026-05-08'::date, 'Manipal Vijayawada', 'SCL-MV-011', 'PT-6612', 'Surgical', 76.50, 76.75, -250.00, 'minor', 'low', 'drift', 'calibrated', '2026-05-09'::date),
('2026-05-09'::date, 'Star Nampally', 'SCL-SN-028', 'PT-7723', 'General', 92.00, 91.20, 800.00, 'major', 'medium', 'platform_uneven', 'investigating', NULL),
('2026-05-10'::date, 'AIG Gachibowli', 'SCL-AI-005', 'PT-3340', 'ICU', 65.80, 66.50, -700.00, 'major', 'high', 'load_cell_fault', 'escalated', NULL),
('2026-05-11'::date, 'Apollo Jubilee', 'SCL-AP-001', 'PT-1009', 'General', 70.20, 70.22, -20.00, 'info', 'none', 'unknown', 'closed', '2026-05-11'::date),
('2026-05-12'::date, 'Olive Mehdipatnam', 'SCL-OM-017', 'PT-2218', 'Maternity', 68.50, 68.65, -150.00, 'moderate', 'low', 'battery_low', 'closed', '2026-05-13'::date),
('2026-05-13'::date, 'Sunshine Paradise', 'SCL-SP-031', 'PT-5544', 'Cardiology', 81.00, 81.10, -100.00, 'minor', 'none', 'drift', 'closed', '2026-05-14'::date),
('2026-05-14'::date, 'Renova Sarojini', 'SCL-RS-013', 'PT-9001', 'Paediatrics', 12.30, 12.42, -120.00, 'moderate', 'medium', 'drift', 'calibrated', '2026-05-15'::date),
('2026-05-15'::date, 'AIG Gachibowli', 'SCL-AI-005', 'PT-3380', 'ICU', 55.20, 55.85, -650.00, 'critical', 'adverse_event', 'load_cell_fault', 'escalated', NULL),
('2026-05-16'::date, 'Aware Gachibowli', 'SCL-AW-009', 'PT-6650', 'Orthopaedics', 84.00, 84.10, -100.00, 'minor', 'none', 'user_error', 'closed', '2026-05-17'::date);

-- =====================================================
-- RPC 1: Monthly visit completion summary
-- =====================================================
CREATE OR REPLACE FUNCTION public.rpc_r3006_monthly_visit_summary()
RETURNS TABLE (visit_month date, total_visits int, completed int, missed int, failed int, completion_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.visit_month,
    count(*)::int,
    (count(*) filter (where v.visit_status = 'completed'))::int,
    (count(*) filter (where v.visit_status = 'missed'))::int,
    (count(*) filter (where v.pass_fail = 'fail'))::int,
    round(100.0 * (count(*) filter (where v.visit_status = 'completed'))::numeric / nullif(count(*),0), 1)
  FROM public.weighing_scale_calibration_visits_r3006 v
  GROUP BY v.visit_month
  ORDER BY v.visit_month DESC;
END $$;

REVOKE ALL ON FUNCTION public.rpc_r3006_monthly_visit_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3006_monthly_visit_summary() TO authenticated;

-- =====================================================
-- RPC 2: Top drifting scales
-- =====================================================
CREATE OR REPLACE FUNCTION public.rpc_r3006_top_drifting_scales()
RETURNS TABLE (scale_asset_tag text, site_name text, scale_model text, avg_pre_drift numeric, max_pre_drift numeric, trend_flag text, visits int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.scale_asset_tag,
    max(v.site_name),
    max(v.scale_model),
    round(avg(v.pre_cal_drift_grams), 2),
    max(v.pre_cal_drift_grams),
    max(v.trend_flag),
    count(*)::int
  FROM public.weighing_scale_calibration_visits_r3006 v
  GROUP BY v.scale_asset_tag
  ORDER BY max(v.pre_cal_drift_grams) DESC
  LIMIT 12;
END $$;

REVOKE ALL ON FUNCTION public.rpc_r3006_top_drifting_scales() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3006_top_drifting_scales() TO authenticated;

-- =====================================================
-- RPC 3: Engineer leaderboard
-- =====================================================
CREATE OR REPLACE FUNCTION public.rpc_r3006_engineer_leaderboard()
RETURNS TABLE (engineer_name text, visits int, completed int, fails int, avg_post_drift numeric, on_time_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.engineer_name,
    count(*)::int,
    (count(*) filter (where v.visit_status = 'completed'))::int,
    (count(*) filter (where v.pass_fail = 'fail'))::int,
    round(avg(v.post_cal_drift_grams), 2),
    round(100.0 * (count(*) filter (where v.visit_status IN ('completed','on_site')))::numeric / nullif(count(*),0), 1)
  FROM public.weighing_scale_calibration_visits_r3006 v
  GROUP BY v.engineer_name
  ORDER BY (count(*) filter (where v.visit_status = 'completed'))::int DESC;
END $$;

REVOKE ALL ON FUNCTION public.rpc_r3006_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3006_engineer_leaderboard() TO authenticated;

-- =====================================================
-- RPC 4: Patient incident severity rollup
-- =====================================================
CREATE OR REPLACE FUNCTION public.rpc_r3006_incident_severity_rollup()
RETURNS TABLE (severity text, incident_count int, avg_delta_grams numeric, adverse_events int, open_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.severity,
    count(*)::int,
    round(avg(abs(i.delta_grams)), 2),
    (count(*) filter (where i.clinical_impact = 'adverse_event'))::int,
    (count(*) filter (where i.resolution_status IN ('open','investigating','escalated')))::int
  FROM public.weighing_scale_patient_incidents_r3006 i
  GROUP BY i.severity
  ORDER BY count(*) DESC;
END $$;

REVOKE ALL ON FUNCTION public.rpc_r3006_incident_severity_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3006_incident_severity_rollup() TO authenticated;

-- =====================================================
-- RPC 5: Site risk score (joins visits + incidents)
-- =====================================================
CREATE OR REPLACE FUNCTION public.rpc_r3006_site_risk_score()
RETURNS TABLE (site_name text, city text, visits int, fails int, incidents int, critical_incidents int, risk_score numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.site_name,
    max(v.city),
    count(distinct v.id)::int,
    (count(*) filter (where v.pass_fail = 'fail'))::int,
    (SELECT count(*) FROM public.weighing_scale_patient_incidents_r3006 i WHERE i.site_name = v.site_name)::int,
    (SELECT count(*) FROM public.weighing_scale_patient_incidents_r3006 i WHERE i.site_name = v.site_name AND i.severity = 'critical')::int,
    round(
      (count(*) filter (where v.pass_fail = 'fail'))::numeric * 5
      + (SELECT count(*) FROM public.weighing_scale_patient_incidents_r3006 i WHERE i.site_name = v.site_name AND i.severity IN ('major','critical'))::numeric * 3
      + (SELECT count(*) FROM public.weighing_scale_patient_incidents_r3006 i WHERE i.site_name = v.site_name AND i.clinical_impact = 'adverse_event')::numeric * 10
    , 1)
  FROM public.weighing_scale_calibration_visits_r3006 v
  GROUP BY v.site_name
  ORDER BY 7 DESC;
END $$;

REVOKE ALL ON FUNCTION public.rpc_r3006_site_risk_score() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3006_site_risk_score() TO authenticated;

-- =====================================================
-- RPC 6: Upcoming due visits
-- =====================================================
CREATE OR REPLACE FUNCTION public.rpc_r3006_upcoming_due()
RETURNS TABLE (next_due_on date, site_name text, scale_asset_tag text, scale_model text, trend_flag text, days_until int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    v.next_due_on,
    v.site_name,
    v.scale_asset_tag,
    v.scale_model,
    v.trend_flag,
    (v.next_due_on - current_date)::int
  FROM public.weighing_scale_calibration_visits_r3006 v
  WHERE v.next_due_on >= ('2026-05-01'::date)
  ORDER BY v.next_due_on ASC
  LIMIT 20;
END $$;

REVOKE ALL ON FUNCTION public.rpc_r3006_upcoming_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3006_upcoming_due() TO authenticated;

-- =====================================================
-- RPC 7: Root-cause distribution
-- =====================================================
CREATE OR REPLACE FUNCTION public.rpc_r3006_root_cause_distribution()
RETURNS TABLE (root_cause text, count_n int, avg_abs_delta numeric, escalated int, parts_replaced int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.root_cause,
    count(*)::int,
    round(avg(abs(i.delta_grams)), 2),
    (count(*) filter (where i.resolution_status = 'escalated'))::int,
    (count(*) filter (where i.resolution_status = 'part_replaced'))::int
  FROM public.weighing_scale_patient_incidents_r3006 i
  GROUP BY i.root_cause
  ORDER BY count(*) DESC;
END $$;

REVOKE ALL ON FUNCTION public.rpc_r3006_root_cause_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_r3006_root_cause_distribution() TO authenticated;

COMMIT;
