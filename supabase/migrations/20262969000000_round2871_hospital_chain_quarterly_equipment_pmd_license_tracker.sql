BEGIN;

-- =====================================================================
-- Round r2871 — Hospital Chain Quarterly Equipment PMD License Tracker
-- =====================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_pmd_licenses_r2871 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_unit text NOT NULL,
  city text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('imaging','life_support','surgical','diagnostic','therapeutic','sterilization')),
  asset_model text NOT NULL,
  license_kind text NOT NULL CHECK (license_kind IN ('aerb','pcb','bmw','cdsco','nabh','fire','dg_set','lift')),
  license_number text NOT NULL,
  issued_on date NOT NULL,
  valid_until date NOT NULL,
  renewal_window_days int NOT NULL DEFAULT 90,
  renewal_status text NOT NULL CHECK (renewal_status IN ('current','renewal_due','renewal_in_progress','expired','grace_period')),
  audit_quarter text NOT NULL CHECK (audit_quarter IN ('q1_fy26','q2_fy26','q3_fy26','q4_fy26','q1_fy27')),
  compliance_verdict text NOT NULL CHECK (compliance_verdict IN ('green','amber','red','blocked')),
  last_audited_on date,
  next_audit_on date,
  fine_risk_rupees int NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_pmd_licenses_r2871 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_pmd_licenses_r2871;
CREATE POLICY founder_all ON hospital_chain_pmd_licenses_r2871 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_pmd_audit_events_r2871 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  license_id uuid REFERENCES hospital_chain_pmd_licenses_r2871(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('audit_passed','audit_failed','renewal_filed','renewal_approved','warning_letter','penalty_levied','escalation','remediation_closed')),
  event_on date NOT NULL,
  inspector_name text,
  finding_summary text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('info','minor','major','critical')),
  resolution_owner text,
  resolution_due_on date,
  resolution_status text NOT NULL CHECK (resolution_status IN ('open','in_progress','closed','overdue')),
  attachment_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_pmd_audit_events_r2871 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_pmd_audit_events_r2871;
CREATE POLICY founder_all ON hospital_chain_pmd_audit_events_r2871 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed licenses (8 rows)
INSERT INTO hospital_chain_pmd_licenses_r2871
  (chain_name, hospital_unit, city, asset_category, asset_model, license_kind, license_number, issued_on, valid_until, renewal_window_days, renewal_status, audit_quarter, compliance_verdict, last_audited_on, next_audit_on, fine_risk_rupees, notes)
VALUES
  ('Apollo','Apollo Jubilee Hills','Hyderabad','imaging','Siemens CT Somatom 64','aerb','AERB-TG-2024-1187','2024-04-15'::date,'2026-08-15'::date,90,'renewal_due','q2_fy26','amber','2026-03-12'::date,'2026-07-15'::date,250000,'AERB renewal application drafted'),
  ('Apollo','Apollo Hyderguda','Hyderabad','life_support','GE Carescape B850','cdsco','CDSCO-MD-9912','2023-09-01'::date,'2026-09-01'::date,120,'renewal_in_progress','q2_fy26','green','2026-04-22'::date,'2026-09-15'::date,0,'Renewal docs filed 2026-06-10'),
  ('Manipal','Manipal Whitefield','Bengaluru','surgical','Stryker Mako Robotic Arm','cdsco','CDSCO-MD-7741','2024-01-10'::date,'2026-07-10'::date,60,'expired','q1_fy26','red','2026-02-08'::date,'2026-07-08'::date,1200000,'License expired 2026-07-10 — STOP USE'),
  ('Manipal','Manipal Hebbal','Bengaluru','diagnostic','Roche Cobas 8000','pcb','PCB-KA-2025-441','2025-02-20'::date,'2027-02-20'::date,90,'current','q2_fy26','green','2026-05-30'::date,'2026-10-30'::date,0,'Effluent log compliant'),
  ('Fortis','Fortis Gurgaon','Gurgaon','therapeutic','Varian Halcyon LINAC','aerb','AERB-HR-2023-0099','2023-06-12'::date,'2026-09-30'::date,120,'renewal_due','q2_fy26','amber','2026-03-25'::date,'2026-08-15'::date,500000,'Type-2 radiation device renewal'),
  ('Fortis','Fortis Mohali','Chandigarh','sterilization','Getinge Quadro 8666','bmw','BMW-CH-2024-0234','2024-07-01'::date,'2026-07-01'::date,90,'grace_period','q1_fy26','red','2026-04-10'::date,'2026-07-30'::date,180000,'Grace period until 2026-07-30'),
  ('Max','Max Saket','Delhi','imaging','Philips Ingenia 3T MRI','aerb','AERB-DL-2025-2201','2025-05-18'::date,'2028-05-18'::date,180,'current','q2_fy26','green','2026-05-12'::date,'2026-11-12'::date,0,'Long-validity renewal'),
  ('Narayana','NH Bengaluru','Bengaluru','life_support','Maquet Servo-u Ventilator','cdsco','CDSCO-MD-6612','2023-11-08'::date,'2026-08-08'::date,90,'renewal_due','q2_fy26','amber','2026-04-02'::date,'2026-08-01'::date,150000,'12 unit fleet renewal');

-- Seed audit events (8 rows)
INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Apollo','warning_letter','2026-03-12'::date,'Dr R Krishna (AERB)','Lead shielding gap behind CT gantry door — 0.3mm Pb deficit','major','Apollo BME Lead','2026-07-30'::date,'in_progress',3
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='AERB-TG-2024-1187' LIMIT 1;

INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Manipal','penalty_levied','2026-07-12'::date,'CDSCO Bengaluru','Robotic surgical arm operated 2 days past license expiry','critical','Manipal CMO','2026-08-15'::date,'overdue',7
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='CDSCO-MD-7741' LIMIT 1;

INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Manipal','audit_passed','2026-05-30'::date,'KSPCB Surveyor','Effluent BOD/COD within limits — Form-V filed','info','Manipal Facilities','2026-06-30'::date,'closed',2
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='PCB-KA-2025-441' LIMIT 1;

INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Fortis','renewal_filed','2026-06-15'::date,'AERB Online Portal','Halcyon LINAC e-LORA renewal submitted with QA report','info','Fortis Radiation Safety Officer','2026-09-15'::date,'in_progress',5
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='AERB-HR-2023-0099' LIMIT 1;

INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Fortis','escalation','2026-07-05'::date,'CPCB Regional','BMW autoclave running on expired authorization — grace expires 2026-07-30','major','Fortis Mohali Director','2026-07-25'::date,'open',4
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='BMW-CH-2024-0234' LIMIT 1;

INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Max','audit_passed','2026-05-12'::date,'AERB Delhi','3T MRI shielding integrity verified — no findings','info','Max BME','2026-06-12'::date,'closed',1
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='AERB-DL-2025-2201' LIMIT 1;

INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Narayana','warning_letter','2026-06-20'::date,'CDSCO South Zone','Ventilator fleet renewal pending — submit within 30 days','minor','NH Biomed','2026-07-20'::date,'in_progress',2
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='CDSCO-MD-6612' LIMIT 1;

INSERT INTO hospital_chain_pmd_audit_events_r2871
  (license_id, chain_name, event_type, event_on, inspector_name, finding_summary, severity, resolution_owner, resolution_due_on, resolution_status, attachment_count)
SELECT id,'Apollo','remediation_closed','2026-04-25'::date,'AERB TG','Carescape B850 calibration certificate uploaded','info','Apollo BME Lead','2026-04-30'::date,'closed',1
FROM hospital_chain_pmd_licenses_r2871 WHERE license_number='CDSCO-MD-9912' LIMIT 1;

-- =====================================================================
-- RPCs (8 total)
-- =====================================================================

DROP FUNCTION IF EXISTS r2871_kpis();
CREATE OR REPLACE FUNCTION r2871_kpis()
RETURNS TABLE(
  total_licenses int,
  renewal_due int,
  expired_or_grace int,
  red_verdicts int,
  total_fine_risk_rupees bigint,
  critical_audit_events int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM hospital_chain_pmd_licenses_r2871),
    (SELECT COUNT(*)::int FROM hospital_chain_pmd_licenses_r2871 WHERE renewal_status IN ('renewal_due','renewal_in_progress')),
    (SELECT COUNT(*)::int FROM hospital_chain_pmd_licenses_r2871 WHERE renewal_status IN ('expired','grace_period')),
    (SELECT COUNT(*)::int FROM hospital_chain_pmd_licenses_r2871 WHERE compliance_verdict IN ('red','blocked')),
    (SELECT COALESCE(SUM(fine_risk_rupees),0)::bigint FROM hospital_chain_pmd_licenses_r2871),
    (SELECT COUNT(*)::int FROM hospital_chain_pmd_audit_events_r2871 WHERE severity = 'critical');
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_kpis() TO authenticated;

DROP FUNCTION IF EXISTS r2871_licenses();
CREATE OR REPLACE FUNCTION r2871_licenses()
RETURNS TABLE(
  id uuid,
  chain_name text,
  hospital_unit text,
  city text,
  asset_category text,
  asset_model text,
  license_kind text,
  license_number text,
  valid_until date,
  renewal_status text,
  compliance_verdict text,
  fine_risk_rupees int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id,l.chain_name,l.hospital_unit,l.city,l.asset_category,l.asset_model,l.license_kind,l.license_number,l.valid_until,l.renewal_status,l.compliance_verdict,l.fine_risk_rupees
  FROM hospital_chain_pmd_licenses_r2871 l
  ORDER BY l.valid_until ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_licenses() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_licenses() TO authenticated;

DROP FUNCTION IF EXISTS r2871_by_chain();
CREATE OR REPLACE FUNCTION r2871_by_chain()
RETURNS TABLE(
  chain_name text,
  total_licenses int,
  red_count int,
  amber_count int,
  green_count int,
  total_fine_risk bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.chain_name,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE l.compliance_verdict IN ('red','blocked'))::int,
    COUNT(*) FILTER (WHERE l.compliance_verdict = 'amber')::int,
    COUNT(*) FILTER (WHERE l.compliance_verdict = 'green')::int,
    COALESCE(SUM(l.fine_risk_rupees),0)::bigint
  FROM hospital_chain_pmd_licenses_r2871 l
  GROUP BY l.chain_name
  ORDER BY 6 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS r2871_by_kind();
CREATE OR REPLACE FUNCTION r2871_by_kind()
RETURNS TABLE(
  license_kind text,
  total int,
  due_or_expired int,
  fine_risk bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.license_kind,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE l.renewal_status IN ('renewal_due','renewal_in_progress','expired','grace_period'))::int,
    COALESCE(SUM(l.fine_risk_rupees),0)::bigint
  FROM hospital_chain_pmd_licenses_r2871 l
  GROUP BY l.license_kind
  ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_by_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_by_kind() TO authenticated;

DROP FUNCTION IF EXISTS r2871_renewal_pipeline();
CREATE OR REPLACE FUNCTION r2871_renewal_pipeline()
RETURNS TABLE(
  chain_name text,
  hospital_unit text,
  asset_model text,
  license_kind text,
  valid_until date,
  days_to_expiry int,
  renewal_status text,
  fine_risk_rupees int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.chain_name,l.hospital_unit,l.asset_model,l.license_kind,l.valid_until,
    (l.valid_until - CURRENT_DATE)::int,
    l.renewal_status,l.fine_risk_rupees
  FROM hospital_chain_pmd_licenses_r2871 l
  WHERE l.renewal_status IN ('renewal_due','renewal_in_progress','expired','grace_period')
  ORDER BY l.valid_until ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_renewal_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_renewal_pipeline() TO authenticated;

DROP FUNCTION IF EXISTS r2871_audit_events();
CREATE OR REPLACE FUNCTION r2871_audit_events()
RETURNS TABLE(
  id uuid,
  chain_name text,
  event_type text,
  event_on date,
  inspector_name text,
  finding_summary text,
  severity text,
  resolution_status text,
  resolution_owner text,
  resolution_due_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id,e.chain_name,e.event_type,e.event_on,e.inspector_name,e.finding_summary,e.severity,e.resolution_status,e.resolution_owner,e.resolution_due_on
  FROM hospital_chain_pmd_audit_events_r2871 e
  ORDER BY e.event_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_audit_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_audit_events() TO authenticated;

DROP FUNCTION IF EXISTS r2871_quarter_summary();
CREATE OR REPLACE FUNCTION r2871_quarter_summary()
RETURNS TABLE(
  audit_quarter text,
  licenses int,
  green int,
  amber int,
  red int,
  fine_risk bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.audit_quarter,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE l.compliance_verdict='green')::int,
    COUNT(*) FILTER (WHERE l.compliance_verdict='amber')::int,
    COUNT(*) FILTER (WHERE l.compliance_verdict IN ('red','blocked'))::int,
    COALESCE(SUM(l.fine_risk_rupees),0)::bigint
  FROM hospital_chain_pmd_licenses_r2871 l
  GROUP BY l.audit_quarter
  ORDER BY l.audit_quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_quarter_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_quarter_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2871_critical_blocklist();
CREATE OR REPLACE FUNCTION r2871_critical_blocklist()
RETURNS TABLE(
  chain_name text,
  hospital_unit text,
  asset_model text,
  license_kind text,
  license_number text,
  valid_until date,
  renewal_status text,
  compliance_verdict text,
  fine_risk_rupees int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.chain_name,l.hospital_unit,l.asset_model,l.license_kind,l.license_number,l.valid_until,l.renewal_status,l.compliance_verdict,l.fine_risk_rupees,l.notes
  FROM hospital_chain_pmd_licenses_r2871 l
  WHERE l.compliance_verdict IN ('red','blocked') OR l.renewal_status IN ('expired','grace_period')
  ORDER BY l.fine_risk_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2871_critical_blocklist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2871_critical_blocklist() TO authenticated;

COMMIT;
