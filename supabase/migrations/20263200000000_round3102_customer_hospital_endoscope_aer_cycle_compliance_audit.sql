-- Round 3102 — Customer Hospital Endoscope Reprocessing AER Cycle Compliance Audit
-- Tracks AER (Automated Endoscope Reprocessor) cycle logs across hospital scopes,
-- with leak tests, chemical concentration checks, abort/failure capture, and
-- patient-link traceability for compliance audit.

-- ============================================================
-- Table 1: AER cycle log entries
-- ============================================================
CREATE TABLE IF NOT EXISTS aer_cycle_logs_r3102 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  aer_unit_code text NOT NULL,
  aer_manufacturer text NOT NULL CHECK (aer_manufacturer IN (
    'Olympus','Medivators','Steris','Wassenburg','Soluscope','Getinge','BHT'
  )),
  scope_serial text NOT NULL,
  scope_model text NOT NULL CHECK (scope_model IN (
    'GIF-HQ190','CF-HQ190','BF-1TH190','TJF-Q190V','PCF-H190','ENF-VH','URF-V3'
  )),
  scope_type text NOT NULL CHECK (scope_type IN (
    'gastroscope','colonoscope','bronchoscope','duodenoscope','sigmoidoscope','cystoscope','choledochoscope'
  )),
  cycle_started_at timestamptz NOT NULL,
  cycle_completed_at timestamptz,
  cycle_duration_minutes integer,
  cycle_phase text NOT NULL CHECK (cycle_phase IN (
    'leak_test','pre_clean','wash','disinfect','rinse','alcohol_flush','dry','complete','aborted'
  )),
  cycle_outcome text NOT NULL CHECK (cycle_outcome IN (
    'pass','fail','aborted','operator_canceled','power_loss','sensor_fault'
  )),
  leak_test_result text NOT NULL CHECK (leak_test_result IN (
    'pass','fail','not_performed','skipped'
  )),
  leak_test_pressure_mbar numeric(6,2),
  chemical_name text NOT NULL CHECK (chemical_name IN (
    'opa','peracetic_acid','glutaraldehyde','hypochlorous_acid','chlorine_dioxide'
  )),
  chemical_concentration_ppm numeric(7,2),
  chemical_min_threshold_ppm numeric(7,2) NOT NULL,
  chemical_pass boolean NOT NULL DEFAULT true,
  temperature_celsius numeric(5,2),
  patient_uhid text,
  patient_procedure text CHECK (patient_procedure IN (
    'upper_gi_endoscopy','colonoscopy','bronchoscopy','ercp','egd','flexible_sigmoidoscopy','cystoscopy','none'
  )),
  operator_profile_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  abort_reason text CHECK (abort_reason IN (
    'leak_detected','chemical_low','power_loss','operator_canceled','sensor_fault','door_open','water_pressure_low','none'
  )),
  compliance_status text NOT NULL CHECK (compliance_status IN (
    'compliant','non_compliant','requires_rewash','quarantined','under_review'
  )),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_aer_cycle_logs_r3102_org ON aer_cycle_logs_r3102(organization_id);
CREATE INDEX IF NOT EXISTS idx_aer_cycle_logs_r3102_scope ON aer_cycle_logs_r3102(scope_serial);
CREATE INDEX IF NOT EXISTS idx_aer_cycle_logs_r3102_outcome ON aer_cycle_logs_r3102(cycle_outcome);
CREATE INDEX IF NOT EXISTS idx_aer_cycle_logs_r3102_started ON aer_cycle_logs_r3102(cycle_started_at DESC);

ALTER TABLE aer_cycle_logs_r3102 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Table 2: AER scope registry + maintenance state
-- ============================================================
CREATE TABLE IF NOT EXISTS aer_scope_registry_r3102 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  scope_serial text NOT NULL UNIQUE,
  scope_model text NOT NULL CHECK (scope_model IN (
    'GIF-HQ190','CF-HQ190','BF-1TH190','TJF-Q190V','PCF-H190','ENF-VH','URF-V3'
  )),
  scope_type text NOT NULL CHECK (scope_type IN (
    'gastroscope','colonoscope','bronchoscope','duodenoscope','sigmoidoscope','cystoscope','choledochoscope'
  )),
  manufacturer text NOT NULL CHECK (manufacturer IN (
    'Olympus','Pentax','Fujifilm','Karl Storz'
  )),
  in_service_at date NOT NULL,
  last_leak_test_at timestamptz,
  last_leak_test_result text CHECK (last_leak_test_result IN (
    'pass','fail','not_performed','skipped'
  )),
  total_cycles_lifetime integer NOT NULL DEFAULT 0,
  cycles_since_service integer NOT NULL DEFAULT 0,
  service_due_at_cycles integer NOT NULL DEFAULT 500,
  current_status text NOT NULL CHECK (current_status IN (
    'available','in_use','reprocessing','quarantined','out_for_service','retired','awaiting_rewash'
  )),
  quarantine_reason text CHECK (quarantine_reason IN (
    'leak_failed','chemical_failed','overdue_service','contamination_suspected','none'
  )),
  last_compliance_status text NOT NULL DEFAULT 'compliant' CHECK (last_compliance_status IN (
    'compliant','non_compliant','requires_rewash','quarantined','under_review'
  )),
  assigned_engineer_id uuid REFERENCES engineers(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_aer_scope_registry_r3102_org ON aer_scope_registry_r3102(organization_id);
CREATE INDEX IF NOT EXISTS idx_aer_scope_registry_r3102_status ON aer_scope_registry_r3102(current_status);

ALTER TABLE aer_scope_registry_r3102 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Seed data
-- ============================================================
DO $$
DECLARE
  v_org uuid;
BEGIN
  SELECT id INTO v_org FROM organizations ORDER BY created_at ASC LIMIT 1;
  IF v_org IS NULL THEN
    RETURN;
  END IF;

  -- Scope registry (7 rows)
  INSERT INTO aer_scope_registry_r3102 (organization_id, scope_serial, scope_model, scope_type, manufacturer, in_service_at, last_leak_test_at, last_leak_test_result, total_cycles_lifetime, cycles_since_service, service_due_at_cycles, current_status, quarantine_reason, last_compliance_status, notes)
  VALUES
    (v_org, 'OLY-GIF-2401881', 'GIF-HQ190', 'gastroscope', 'Olympus', '2024-04-12', now() - interval '6 hours', 'pass', 1842, 142, 500, 'available', 'none', 'compliant', 'GI dept scope 1'),
    (v_org, 'OLY-CF-2402114', 'CF-HQ190', 'colonoscope', 'Olympus', '2024-05-22', now() - interval '4 hours', 'pass', 1567, 67, 500, 'in_use', 'none', 'compliant', 'GI dept colono A'),
    (v_org, 'OLY-BF-2400702', 'BF-1TH190', 'bronchoscope', 'Olympus', '2024-02-08', now() - interval '12 hours', 'fail', 2231, 531, 500, 'quarantined', 'leak_failed', 'quarantined', 'Pulmo dept — leak at distal'),
    (v_org, 'OLY-TJF-2400451', 'TJF-Q190V', 'duodenoscope', 'Olympus', '2024-01-15', now() - interval '2 hours', 'pass', 2998, 298, 500, 'reprocessing', 'none', 'compliant', 'ERCP duodenoscope — high vigilance'),
    (v_org, 'OLY-PCF-2401623', 'PCF-H190', 'sigmoidoscope', 'Olympus', '2024-06-30', now() - interval '8 hours', 'pass', 891, 391, 500, 'awaiting_rewash', 'none', 'requires_rewash', 'OPD sigmoidoscope'),
    (v_org, 'OLY-ENF-2400988', 'ENF-VH', 'cystoscope', 'Olympus', '2024-03-21', now() - interval '30 hours', 'pass', 1422, 22, 500, 'available', 'none', 'compliant', 'ENT — flexible'),
    (v_org, 'OLY-URF-2401205', 'URF-V3', 'choledochoscope', 'Olympus', '2024-07-08', now() - interval '5 hours', 'pass', 612, 112, 500, 'out_for_service', 'overdue_service', 'under_review', 'Sent to Olympus Mumbai');

  -- Cycle logs (14 rows)
  INSERT INTO aer_cycle_logs_r3102 (organization_id, aer_unit_code, aer_manufacturer, scope_serial, scope_model, scope_type, cycle_started_at, cycle_completed_at, cycle_duration_minutes, cycle_phase, cycle_outcome, leak_test_result, leak_test_pressure_mbar, chemical_name, chemical_concentration_ppm, chemical_min_threshold_ppm, chemical_pass, temperature_celsius, patient_uhid, patient_procedure, abort_reason, compliance_status, notes)
  VALUES
    (v_org, 'AER-OLY-OER-PRO-01', 'Olympus', 'OLY-GIF-2401881', 'GIF-HQ190', 'gastroscope', now() - interval '8 hours', now() - interval '7 hours 23 minutes', 37, 'complete', 'pass', 'pass', 160.50, 'opa', 1180.00, 1050.00, true, 25.40, 'UHID-2026-118822', 'upper_gi_endoscopy', 'none', 'compliant', 'Routine OGD'),
    (v_org, 'AER-OLY-OER-PRO-01', 'Olympus', 'OLY-CF-2402114', 'CF-HQ190', 'colonoscope', now() - interval '6 hours', now() - interval '5 hours 22 minutes', 38, 'complete', 'pass', 'pass', 162.10, 'opa', 1205.00, 1050.00, true, 25.20, 'UHID-2026-118901', 'colonoscopy', 'none', 'compliant', 'Screening colono'),
    (v_org, 'AER-MED-DSD-EDGE-02', 'Medivators', 'OLY-BF-2400702', 'BF-1TH190', 'bronchoscope', now() - interval '12 hours', now() - interval '11 hours 55 minutes', 5, 'leak_test', 'aborted', 'fail', 95.20, 'peracetic_acid', 0.00, 1800.00, false, 24.80, NULL, 'none', 'leak_detected', 'quarantined', 'Distal channel leak — pulled from circulation'),
    (v_org, 'AER-OLY-OER-PRO-01', 'Olympus', 'OLY-TJF-2400451', 'TJF-Q190V', 'duodenoscope', now() - interval '4 hours', now() - interval '3 hours 21 minutes', 39, 'complete', 'pass', 'pass', 158.90, 'opa', 1145.00, 1050.00, true, 25.60, 'UHID-2026-118754', 'ercp', 'none', 'compliant', 'ERCP — CBD stone retrieval'),
    (v_org, 'AER-STE-SYS-1E-03', 'Steris', 'OLY-PCF-2401623', 'PCF-H190', 'sigmoidoscope', now() - interval '10 hours', now() - interval '9 hours 47 minutes', 13, 'rinse', 'fail', 'pass', 161.20, 'peracetic_acid', 1620.00, 1800.00, false, 24.50, 'UHID-2026-118688', 'flexible_sigmoidoscopy', 'chemical_low', 'requires_rewash', 'PAA below threshold — rewash queued'),
    (v_org, 'AER-WAS-WD440-04', 'Wassenburg', 'OLY-ENF-2400988', 'ENF-VH', 'cystoscope', now() - interval '14 hours', now() - interval '13 hours 25 minutes', 35, 'complete', 'pass', 'pass', 165.40, 'glutaraldehyde', 2300.00, 2000.00, true, 25.10, 'UHID-2026-118512', 'cystoscopy', 'none', 'compliant', 'Urology OPD'),
    (v_org, 'AER-OLY-OER-PRO-01', 'Olympus', 'OLY-GIF-2401881', 'GIF-HQ190', 'gastroscope', now() - interval '20 hours', now() - interval '19 hours 22 minutes', 38, 'complete', 'pass', 'pass', 159.80, 'opa', 1192.00, 1050.00, true, 25.30, 'UHID-2026-118402', 'egd', 'none', 'compliant', 'EGD biopsy'),
    (v_org, 'AER-MED-DSD-EDGE-02', 'Medivators', 'OLY-CF-2402114', 'CF-HQ190', 'colonoscope', now() - interval '22 hours', now() - interval '21 hours 18 minutes', 42, 'complete', 'pass', 'pass', 163.50, 'opa', 1210.00, 1050.00, true, 25.50, 'UHID-2026-118344', 'colonoscopy', 'none', 'compliant', 'Polypectomy'),
    (v_org, 'AER-SOL-PA20-05', 'Soluscope', 'OLY-URF-2401205', 'URF-V3', 'choledochoscope', now() - interval '26 hours', NULL, NULL, 'aborted', 'power_loss', 'pass', 162.00, 'opa', 1100.00, 1050.00, true, 24.90, NULL, 'none', 'power_loss', 'under_review', 'Mid-cycle power loss — full restart pending'),
    (v_org, 'AER-OLY-OER-PRO-01', 'Olympus', 'OLY-TJF-2400451', 'TJF-Q190V', 'duodenoscope', now() - interval '30 hours', now() - interval '29 hours 24 minutes', 36, 'complete', 'pass', 'pass', 160.10, 'opa', 1188.00, 1050.00, true, 25.40, 'UHID-2026-118201', 'ercp', 'none', 'compliant', 'ERCP — stent placement'),
    (v_org, 'AER-GET-46-06', 'Getinge', 'OLY-ENF-2400988', 'ENF-VH', 'cystoscope', now() - interval '36 hours', now() - interval '35 hours 30 minutes', 30, 'complete', 'pass', 'pass', 164.90, 'glutaraldehyde', 2280.00, 2000.00, true, 25.00, 'UHID-2026-118077', 'cystoscopy', 'none', 'compliant', 'OPD cystoscopy'),
    (v_org, 'AER-BHT-INNOVA-07', 'BHT', 'OLY-PCF-2401623', 'PCF-H190', 'sigmoidoscope', now() - interval '38 hours', now() - interval '37 hours 52 minutes', 8, 'wash', 'operator_canceled', 'pass', 161.80, 'peracetic_acid', 1820.00, 1800.00, true, 24.70, NULL, 'none', 'operator_canceled', 'under_review', 'Operator pressed E-stop — investigating'),
    (v_org, 'AER-OLY-OER-PRO-01', 'Olympus', 'OLY-GIF-2401881', 'GIF-HQ190', 'gastroscope', now() - interval '44 hours', now() - interval '43 hours 23 minutes', 37, 'complete', 'pass', 'pass', 160.70, 'opa', 1175.00, 1050.00, true, 25.20, 'UHID-2026-117988', 'upper_gi_endoscopy', 'none', 'compliant', 'Routine'),
    (v_org, 'AER-MED-DSD-EDGE-02', 'Medivators', 'OLY-CF-2402114', 'CF-HQ190', 'colonoscope', now() - interval '48 hours', now() - interval '47 hours 12 minutes', 48, 'complete', 'fail', 'pass', 158.60, 'opa', 980.00, 1050.00, false, 25.60, 'UHID-2026-117901', 'colonoscopy', 'chemical_low', 'non_compliant', 'OPA concentration low — full reprocess + audit');
END $$;

-- ============================================================
-- RPC 1: cycle outcome rollup
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_cycle_outcome_rollup()
RETURNS TABLE (
  cycle_outcome text,
  total_cycles bigint,
  total_organizations bigint,
  pct_of_total numeric
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
  WITH totals AS (
    SELECT COUNT(*)::numeric AS t FROM aer_cycle_logs_r3102
  )
  SELECT
    c.cycle_outcome,
    COUNT(*)::bigint,
    COUNT(DISTINCT c.organization_id)::bigint,
    ROUND((COUNT(*)::numeric / NULLIF((SELECT t FROM totals), 0)) * 100, 2)
  FROM aer_cycle_logs_r3102 c
  GROUP BY c.cycle_outcome
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_cycle_outcome_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_cycle_outcome_rollup() TO authenticated;

-- ============================================================
-- RPC 2: leak test failure breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_leak_test_breakdown()
RETURNS TABLE (
  scope_type text,
  total_cycles bigint,
  leak_pass bigint,
  leak_fail bigint,
  leak_not_performed bigint,
  leak_fail_pct numeric
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
  SELECT
    c.scope_type,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.leak_test_result = 'pass')::bigint,
    COUNT(*) FILTER (WHERE c.leak_test_result = 'fail')::bigint,
    COUNT(*) FILTER (WHERE c.leak_test_result IN ('not_performed','skipped'))::bigint,
    ROUND(
      (COUNT(*) FILTER (WHERE c.leak_test_result = 'fail')::numeric / NULLIF(COUNT(*)::numeric, 0)) * 100,
      2
    )
  FROM aer_cycle_logs_r3102 c
  GROUP BY c.scope_type
  ORDER BY COUNT(*) FILTER (WHERE c.leak_test_result = 'fail') DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_leak_test_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_leak_test_breakdown() TO authenticated;

-- ============================================================
-- RPC 3: chemical concentration audit
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_chemical_concentration_audit()
RETURNS TABLE (
  chemical_name text,
  total_cycles bigint,
  avg_concentration_ppm numeric,
  min_concentration_ppm numeric,
  below_threshold_count bigint,
  threshold_breach_pct numeric
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
  SELECT
    c.chemical_name,
    COUNT(*)::bigint,
    ROUND(AVG(c.chemical_concentration_ppm), 2),
    MIN(c.chemical_concentration_ppm),
    COUNT(*) FILTER (WHERE NOT c.chemical_pass)::bigint,
    ROUND(
      (COUNT(*) FILTER (WHERE NOT c.chemical_pass)::numeric / NULLIF(COUNT(*)::numeric, 0)) * 100,
      2
    )
  FROM aer_cycle_logs_r3102 c
  GROUP BY c.chemical_name
  ORDER BY COUNT(*) FILTER (WHERE NOT c.chemical_pass) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_chemical_concentration_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_chemical_concentration_audit() TO authenticated;

-- ============================================================
-- RPC 4: abort reason rollup
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_abort_reason_rollup()
RETURNS TABLE (
  abort_reason text,
  total_aborts bigint,
  distinct_scopes bigint,
  distinct_aer_units bigint,
  last_seen timestamptz
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
  SELECT
    c.abort_reason,
    COUNT(*)::bigint,
    COUNT(DISTINCT c.scope_serial)::bigint,
    COUNT(DISTINCT c.aer_unit_code)::bigint,
    MAX(c.cycle_started_at)
  FROM aer_cycle_logs_r3102 c
  WHERE c.abort_reason IS NOT NULL AND c.abort_reason <> 'none'
  GROUP BY c.abort_reason
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_abort_reason_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_abort_reason_rollup() TO authenticated;

-- ============================================================
-- RPC 5: scope-level compliance rollup
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_scope_compliance_rollup()
RETURNS TABLE (
  scope_serial text,
  scope_model text,
  scope_type text,
  total_cycles bigint,
  compliant_cycles bigint,
  non_compliant_cycles bigint,
  compliance_pct numeric,
  current_status text
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
  SELECT
    c.scope_serial,
    c.scope_model,
    c.scope_type,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.compliance_status = 'compliant')::bigint,
    COUNT(*) FILTER (WHERE c.compliance_status <> 'compliant')::bigint,
    ROUND(
      (COUNT(*) FILTER (WHERE c.compliance_status = 'compliant')::numeric / NULLIF(COUNT(*)::numeric, 0)) * 100,
      2
    ),
    COALESCE(r.current_status, 'unknown')
  FROM aer_cycle_logs_r3102 c
  LEFT JOIN aer_scope_registry_r3102 r ON r.scope_serial = c.scope_serial
  GROUP BY c.scope_serial, c.scope_model, c.scope_type, r.current_status
  ORDER BY (COUNT(*) FILTER (WHERE c.compliance_status <> 'compliant'))::numeric DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_scope_compliance_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_scope_compliance_rollup() TO authenticated;

-- ============================================================
-- RPC 6: AER unit performance
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_aer_unit_performance()
RETURNS TABLE (
  aer_unit_code text,
  aer_manufacturer text,
  total_cycles bigint,
  passed bigint,
  failed_or_aborted bigint,
  avg_duration_min numeric,
  pass_rate_pct numeric
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
  SELECT
    c.aer_unit_code,
    c.aer_manufacturer,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.cycle_outcome = 'pass')::bigint,
    COUNT(*) FILTER (WHERE c.cycle_outcome <> 'pass')::bigint,
    ROUND(AVG(c.cycle_duration_minutes), 2),
    ROUND(
      (COUNT(*) FILTER (WHERE c.cycle_outcome = 'pass')::numeric / NULLIF(COUNT(*)::numeric, 0)) * 100,
      2
    )
  FROM aer_cycle_logs_r3102 c
  GROUP BY c.aer_unit_code, c.aer_manufacturer
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_aer_unit_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_aer_unit_performance() TO authenticated;

-- ============================================================
-- RPC 7: patient traceability rollup
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_patient_traceability_rollup()
RETURNS TABLE (
  patient_procedure text,
  total_cycles bigint,
  cycles_with_uhid bigint,
  cycles_missing_uhid bigint,
  non_compliant_cycles bigint,
  traceability_pct numeric
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
  SELECT
    COALESCE(c.patient_procedure, 'none'),
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.patient_uhid IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE c.patient_uhid IS NULL)::bigint,
    COUNT(*) FILTER (WHERE c.compliance_status <> 'compliant')::bigint,
    ROUND(
      (COUNT(*) FILTER (WHERE c.patient_uhid IS NOT NULL)::numeric / NULLIF(COUNT(*)::numeric, 0)) * 100,
      2
    )
  FROM aer_cycle_logs_r3102 c
  GROUP BY COALESCE(c.patient_procedure, 'none')
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_patient_traceability_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_patient_traceability_rollup() TO authenticated;

-- ============================================================
-- RPC 8: scope registry status
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r3102_scope_registry_status()
RETURNS TABLE (
  current_status text,
  scope_count bigint,
  total_lifetime_cycles bigint,
  overdue_service_count bigint,
  quarantined_count bigint
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
  SELECT
    r.current_status,
    COUNT(*)::bigint,
    COALESCE(SUM(r.total_cycles_lifetime), 0)::bigint,
    COUNT(*) FILTER (WHERE r.cycles_since_service > r.service_due_at_cycles)::bigint,
    COUNT(*) FILTER (WHERE r.current_status = 'quarantined')::bigint
  FROM aer_scope_registry_r3102 r
  GROUP BY r.current_status
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r3102_scope_registry_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r3102_scope_registry_status() TO authenticated;
