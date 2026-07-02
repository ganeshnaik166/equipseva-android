-- Round r2903 — Hospital Chain Quarterly Anesthesia Workstation Fleet Health Audit
-- Batch 400 milestone — HEAVY founder ops round

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS anesthesia_workstation_audits_r2903 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_site text NOT NULL,
  workstation_model text NOT NULL,
  asset_tag text NOT NULL,
  audit_quarter text NOT NULL,
  audit_date date NOT NULL,
  vaporizer_calibration_status text NOT NULL CHECK (vaporizer_calibration_status IN ('pass','minor_drift','fail','overdue')),
  o2_flush_seconds numeric(6,2) NOT NULL,
  leak_test_ml_per_min numeric(8,2) NOT NULL,
  agas_pressure_kpa numeric(6,2) NOT NULL,
  battery_backup_minutes int NOT NULL,
  soda_lime_hours_remaining int NOT NULL,
  overall_health_score int NOT NULL CHECK (overall_health_score BETWEEN 0 AND 100),
  downtime_risk text NOT NULL CHECK (downtime_risk IN ('low','medium','high','critical')),
  next_pm_due date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE anesthesia_workstation_audits_r2903 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS anesthesia_fleet_remediation_r2903 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid REFERENCES anesthesia_workstation_audits_r2903(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  hospital_site text NOT NULL,
  finding_category text NOT NULL CHECK (finding_category IN ('vaporizer','circuit_leak','battery','soda_lime','ventilator_module','gas_supply','calibration','software_firmware')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  action_required text NOT NULL,
  assigned_engineer text NOT NULL,
  sla_hours int NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','parts_pending','done','escalated')),
  parts_cost_rupees int NOT NULL DEFAULT 0,
  labor_cost_rupees int NOT NULL DEFAULT 0,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE anesthesia_fleet_remediation_r2903 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Seed Data — audits
-- ============================================================

INSERT INTO anesthesia_workstation_audits_r2903
  (chain_name, hospital_site, workstation_model, asset_tag, audit_quarter, audit_date, vaporizer_calibration_status, o2_flush_seconds, leak_test_ml_per_min, agas_pressure_kpa, battery_backup_minutes, soda_lime_hours_remaining, overall_health_score, downtime_risk, next_pm_due)
VALUES
  ('Apollo Chain','Apollo Jubilee Hills','Drager Fabius Plus','AW-AJH-01','Q2-2026','2026-06-01'::date,'pass',4.5,12.0,415.0,90,42,92,'low','2026-09-01'::date),
  ('Apollo Chain','Apollo Hyderguda','GE Aisys CS2','AW-AHG-02','Q2-2026','2026-06-02'::date,'minor_drift',5.1,28.0,410.0,75,18,78,'medium','2026-08-15'::date),
  ('Apollo Chain','Apollo Secunderabad','Mindray A7','AW-ASD-03','Q2-2026','2026-06-03'::date,'pass',4.8,15.0,420.0,85,30,88,'low','2026-09-03'::date),
  ('Yashoda Chain','Yashoda Somajiguda','Drager Atlan A350','AW-YSG-04','Q2-2026','2026-06-04'::date,'fail',7.2,95.0,380.0,40,6,52,'critical','2026-07-04'::date),
  ('Yashoda Chain','Yashoda Malakpet','GE Avance CS2','AW-YMP-05','Q2-2026','2026-06-05'::date,'pass',4.6,10.0,418.0,95,48,94,'low','2026-09-05'::date),
  ('Yashoda Chain','Yashoda Secunderabad','Mindray WATO EX-65','AW-YSB-06','Q2-2026','2026-06-06'::date,'minor_drift',5.5,35.0,405.0,70,12,72,'medium','2026-08-06'::date),
  ('KIMS Chain','KIMS Kondapur','Drager Primus','AW-KKP-07','Q2-2026','2026-06-07'::date,'overdue',6.8,55.0,395.0,55,8,61,'high','2026-07-07'::date),
  ('KIMS Chain','KIMS Begumpet','GE Aisys CS2','AW-KBP-08','Q2-2026','2026-06-08'::date,'pass',4.4,11.0,422.0,90,36,90,'low','2026-09-08'::date),
  ('KIMS Chain','KIMS Sunshine','Mindray A9','AW-KSS-09','Q2-2026','2026-06-09'::date,'pass',4.7,14.0,419.0,88,33,87,'low','2026-09-09'::date),
  ('Care Chain','Care Banjara','Drager Fabius MRI','AW-CBJ-10','Q2-2026','2026-06-10'::date,'fail',8.1,120.0,370.0,30,4,45,'critical','2026-06-25'::date),
  ('Care Chain','Care Nampally','GE Carestation 650','AW-CNP-11','Q2-2026','2026-06-11'::date,'minor_drift',5.3,32.0,408.0,72,16,75,'medium','2026-08-11'::date),
  ('Care Chain','Care Hi-Tec City','Mindray A8','AW-CHC-12','Q2-2026','2026-06-12'::date,'pass',4.9,13.0,417.0,86,28,86,'low','2026-09-12'::date),
  ('Continental Chain','Continental Gachibowli','Drager Atlan A300','AW-CGB-13','Q2-2026','2026-06-13'::date,'pass',4.5,12.5,420.0,92,40,91,'low','2026-09-13'::date),
  ('Continental Chain','Continental Nallagandla','GE Aisys CS2','AW-CNL-14','Q2-2026','2026-06-14'::date,'overdue',6.5,48.0,398.0,58,9,64,'high','2026-07-14'::date),
  ('Sunshine Chain','Sunshine Paradise','Mindray WATO EX-55','AW-SSP-15','Q2-2026','2026-06-15'::date,'minor_drift',5.4,30.0,407.0,68,15,73,'medium','2026-08-15'::date),
  ('Sunshine Chain','Sunshine Secunderabad','Drager Fabius Plus','AW-SSS-16','Q2-2026','2026-06-16'::date,'pass',4.6,11.5,421.0,89,34,89,'low','2026-09-16'::date),
  ('Star Chain','Star Banjara','GE Avance CS2','AW-SBJ-17','Q2-2026','2026-06-17'::date,'fail',7.5,105.0,375.0,35,5,48,'critical','2026-07-01'::date),
  ('Star Chain','Star Malakpet','Mindray A7','AW-SMP-18','Q2-2026','2026-06-18'::date,'pass',4.8,16.0,416.0,84,27,85,'low','2026-09-18'::date);

-- ============================================================
-- Seed Data — remediation
-- ============================================================

INSERT INTO anesthesia_fleet_remediation_r2903
  (audit_id, chain_name, hospital_site, finding_category, severity, action_required, assigned_engineer, sla_hours, status, parts_cost_rupees, labor_cost_rupees, resolved_at)
SELECT id, chain_name, hospital_site,
  CASE WHEN vaporizer_calibration_status = 'fail' THEN 'vaporizer'
       WHEN leak_test_ml_per_min > 50 THEN 'circuit_leak'
       WHEN battery_backup_minutes < 60 THEN 'battery'
       WHEN soda_lime_hours_remaining < 12 THEN 'soda_lime'
       ELSE 'calibration' END,
  CASE WHEN downtime_risk = 'critical' THEN 'p0'
       WHEN downtime_risk = 'high' THEN 'p1'
       WHEN downtime_risk = 'medium' THEN 'p2'
       ELSE 'p3' END,
  'Quarterly audit follow-up — see finding category',
  'Engineer Pool — Tier 3',
  CASE WHEN downtime_risk = 'critical' THEN 24
       WHEN downtime_risk = 'high' THEN 48
       WHEN downtime_risk = 'medium' THEN 168
       ELSE 720 END,
  CASE WHEN downtime_risk IN ('critical','high') THEN 'in_progress'
       WHEN downtime_risk = 'medium' THEN 'open'
       ELSE 'done' END,
  CASE WHEN downtime_risk = 'critical' THEN 85000
       WHEN downtime_risk = 'high' THEN 32000
       WHEN downtime_risk = 'medium' THEN 8500
       ELSE 1200 END,
  CASE WHEN downtime_risk = 'critical' THEN 18000
       WHEN downtime_risk = 'high' THEN 9500
       WHEN downtime_risk = 'medium' THEN 4500
       ELSE 1500 END,
  CASE WHEN downtime_risk = 'low' THEN now() - interval '2 days' ELSE NULL END
FROM anesthesia_workstation_audits_r2903;

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION founder_r2903_chain_fleet_summary()
RETURNS TABLE(chain_name text, workstations_audited bigint, avg_health_score numeric, critical_count bigint, high_count bigint, pass_rate_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name,
    count(*)::bigint,
    round(avg(a.overall_health_score)::numeric, 1),
    count(*) FILTER (WHERE a.downtime_risk = 'critical')::bigint,
    count(*) FILTER (WHERE a.downtime_risk = 'high')::bigint,
    round(100.0 * count(*) FILTER (WHERE a.vaporizer_calibration_status = 'pass') / count(*), 1)
  FROM anesthesia_workstation_audits_r2903 a
  GROUP BY a.chain_name
  ORDER BY avg(a.overall_health_score) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2903_critical_workstations()
RETURNS TABLE(id uuid, chain_name text, hospital_site text, workstation_model text, asset_tag text, overall_health_score int, downtime_risk text, next_pm_due date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_site, a.workstation_model, a.asset_tag, a.overall_health_score, a.downtime_risk, a.next_pm_due
  FROM anesthesia_workstation_audits_r2903 a
  WHERE a.downtime_risk IN ('critical','high')
  ORDER BY a.overall_health_score ASC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2903_vaporizer_calibration_breakdown()
RETURNS TABLE(status text, count bigint, avg_o2_flush_seconds numeric, avg_leak_ml_per_min numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.vaporizer_calibration_status,
    count(*)::bigint,
    round(avg(a.o2_flush_seconds)::numeric, 2),
    round(avg(a.leak_test_ml_per_min)::numeric, 2)
  FROM anesthesia_workstation_audits_r2903 a
  GROUP BY a.vaporizer_calibration_status
  ORDER BY count(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2903_remediation_status()
RETURNS TABLE(status text, severity text, count bigint, total_parts_rupees bigint, total_labor_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status, r.severity, count(*)::bigint, sum(r.parts_cost_rupees)::bigint, sum(r.labor_cost_rupees)::bigint
  FROM anesthesia_fleet_remediation_r2903 r
  GROUP BY r.status, r.severity
  ORDER BY r.severity, r.status;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2903_model_reliability()
RETURNS TABLE(workstation_model text, units bigint, avg_health numeric, avg_battery_min numeric, fail_rate_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.workstation_model,
    count(*)::bigint,
    round(avg(a.overall_health_score)::numeric, 1),
    round(avg(a.battery_backup_minutes)::numeric, 1),
    round(100.0 * count(*) FILTER (WHERE a.vaporizer_calibration_status = 'fail') / count(*), 1)
  FROM anesthesia_workstation_audits_r2903 a
  GROUP BY a.workstation_model
  ORDER BY avg(a.overall_health_score) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2903_pm_due_next_30_days()
RETURNS TABLE(id uuid, chain_name text, hospital_site text, asset_tag text, workstation_model text, next_pm_due date, days_until int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_site, a.asset_tag, a.workstation_model, a.next_pm_due,
    (a.next_pm_due - current_date)::int
  FROM anesthesia_workstation_audits_r2903 a
  WHERE a.next_pm_due <= (current_date + interval '30 days')::date
  ORDER BY a.next_pm_due ASC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2903_remediation_backlog()
RETURNS TABLE(id uuid, chain_name text, hospital_site text, finding_category text, severity text, sla_hours int, status text, assigned_engineer text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.hospital_site, r.finding_category, r.severity, r.sla_hours, r.status, r.assigned_engineer
  FROM anesthesia_fleet_remediation_r2903 r
  WHERE r.status IN ('open','in_progress','parts_pending','escalated')
  ORDER BY CASE r.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END, r.sla_hours ASC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_r2903_fleet_kpis()
RETURNS TABLE(total_workstations bigint, avg_health_score numeric, critical_units bigint, fail_calibration bigint, pm_due_30d bigint, total_remediation_cost_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM anesthesia_workstation_audits_r2903)::bigint,
    (SELECT round(avg(overall_health_score)::numeric, 1) FROM anesthesia_workstation_audits_r2903),
    (SELECT count(*) FROM anesthesia_workstation_audits_r2903 WHERE downtime_risk = 'critical')::bigint,
    (SELECT count(*) FROM anesthesia_workstation_audits_r2903 WHERE vaporizer_calibration_status = 'fail')::bigint,
    (SELECT count(*) FROM anesthesia_workstation_audits_r2903 WHERE next_pm_due <= (current_date + interval '30 days')::date)::bigint,
    (SELECT coalesce(sum(parts_cost_rupees + labor_cost_rupees), 0) FROM anesthesia_fleet_remediation_r2903)::bigint;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_r2903_chain_fleet_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2903_critical_workstations() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2903_vaporizer_calibration_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2903_remediation_status() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2903_model_reliability() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2903_pm_due_next_30_days() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2903_remediation_backlog() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2903_fleet_kpis() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2903_chain_fleet_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2903_critical_workstations() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2903_vaporizer_calibration_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2903_remediation_status() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2903_model_reliability() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2903_pm_due_next_30_days() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2903_remediation_backlog() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2903_fleet_kpis() TO authenticated;
