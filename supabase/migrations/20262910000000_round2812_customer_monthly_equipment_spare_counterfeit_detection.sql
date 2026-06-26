BEGIN;

-- ============================================================================
-- Round r2812 — Customer Monthly Equipment Spare Counterfeit Detection
-- Asset x part x counterfeit signal x verification x quarantine x supplier action
-- ============================================================================

CREATE TABLE IF NOT EXISTS spare_counterfeit_signals_r2812 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_code text NOT NULL UNIQUE,
  customer_org text NOT NULL,
  hospital_city text NOT NULL,
  asset_model text NOT NULL,
  asset_serial text NOT NULL,
  spare_part_name text NOT NULL,
  spare_part_sku text NOT NULL,
  supplier_name text NOT NULL,
  detection_month date NOT NULL,
  signal_type text NOT NULL CHECK (signal_type IN ('hologram_missing','serial_collision','weight_off','packaging_mismatch','performance_failure','barcode_invalid')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  verification_status text NOT NULL CHECK (verification_status IN ('pending','field_inspection','lab_test','confirmed_counterfeit','cleared_genuine','inconclusive')),
  quarantine_status text NOT NULL CHECK (quarantine_status IN ('not_quarantined','quarantined','released','destroyed')),
  units_affected integer NOT NULL CHECK (units_affected >= 0),
  estimated_loss_rupees integer NOT NULL CHECK (estimated_loss_rupees >= 0),
  detected_by text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE spare_counterfeit_signals_r2812 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON spare_counterfeit_signals_r2812;
CREATE POLICY founder_all ON spare_counterfeit_signals_r2812 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO spare_counterfeit_signals_r2812 (signal_code, customer_org, hospital_city, asset_model, asset_serial, spare_part_name, spare_part_sku, supplier_name, detection_month, signal_type, severity, verification_status, quarantine_status, units_affected, estimated_loss_rupees, detected_by, notes) VALUES
  ('CFS-2812-001','Apollo Jubilee Hills','Hyderabad','GE Voluson E10','VE10-22451','Ultrasound Probe Cable','UPC-C5-2MHz','MediParts Wholesale','2026-06-01'::date,'hologram_missing','p0','confirmed_counterfeit','quarantined',8,184000,'Engineer Suresh','Hologram strip absent on all 8 units'),
  ('CFS-2812-002','KIMS Secunderabad','Hyderabad','Philips IntelliVue MX450','MX450-9981','SpO2 Sensor','SPO2-NX-ADT','BulkMedicals Pvt','2026-06-02'::date,'serial_collision','p0','confirmed_counterfeit','quarantined',12,96000,'Engineer Ramya','3 distinct units shared serial SN-771422'),
  ('CFS-2812-003','Fortis Banjara','Hyderabad','Drager Fabius MRI','FAB-MRI-4421','O2 Flow Sensor','OFS-FAB-002','SwiftMed Trading','2026-06-04'::date,'weight_off','p1','lab_test','quarantined',4,52000,'QA Lab Rajiv','Weight 14% below spec, lab sent to BIS'),
  ('CFS-2812-004','Yashoda Somajiguda','Hyderabad','Mindray BeneView T8','BV-T8-3315','NIBP Hose','NIBP-T8-ADL','MediParts Wholesale','2026-06-07'::date,'packaging_mismatch','p2','field_inspection','not_quarantined',6,18000,'Engineer Anjali','Packaging font differs from OEM original'),
  ('CFS-2812-005','Continental Gachibowli','Hyderabad','Stryker System 7','SYS7-1188','Surgical Burr','SB-S7-MAX','BulkMedicals Pvt','2026-06-09'::date,'performance_failure','p1','confirmed_counterfeit','destroyed',3,87000,'OT Nurse Latha','Burr fractured mid-procedure'),
  ('CFS-2812-006','AIG Hospitals','Hyderabad','Olympus CV-190','CV190-7762','Endoscope Lens Cap','ELC-OL-190','TrueMed Genuine Co','2026-06-11'::date,'barcode_invalid','p3','cleared_genuine','released',2,0,'Engineer Vikram','Barcode reader fault, lens genuine'),
  ('CFS-2812-007','CARE Banjara','Hyderabad','Siemens Acuson S2000','S2000-4419','Doppler Transducer','DT-S2K-9L4','SwiftMed Trading','2026-06-13'::date,'hologram_missing','p0','confirmed_counterfeit','quarantined',5,425000,'Engineer Karthik','High-value confirmed counterfeit'),
  ('CFS-2812-008','Sunshine Secunderabad','Hyderabad','Mindray DC-70','DC70-2298','Linear Array Probe','LAP-DC70-L14','MediParts Wholesale','2026-06-15'::date,'weight_off','p2','inconclusive','quarantined',2,38000,'QA Lab Rajiv','Lab inconclusive, second sample pending');

CREATE TABLE IF NOT EXISTS supplier_quarantine_actions_r2812 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_code text NOT NULL UNIQUE,
  supplier_name text NOT NULL,
  related_signal_code text,
  action_month date NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('warning_letter','partial_blacklist','full_blacklist','recovery_invoice','legal_notice','reinstated','spot_audit')),
  monetary_recovery_rupees integer NOT NULL CHECK (monetary_recovery_rupees >= 0),
  action_status text NOT NULL CHECK (action_status IN ('queued','in_progress','recovered','escalated','closed')),
  responsible_owner text NOT NULL,
  due_at date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE supplier_quarantine_actions_r2812 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON supplier_quarantine_actions_r2812;
CREATE POLICY founder_all ON supplier_quarantine_actions_r2812 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO supplier_quarantine_actions_r2812 (action_code, supplier_name, related_signal_code, action_month, action_type, monetary_recovery_rupees, action_status, responsible_owner, due_at, notes) VALUES
  ('SQA-2812-001','MediParts Wholesale','CFS-2812-001','2026-06-01'::date,'full_blacklist',184000,'in_progress','Founder','2026-06-25'::date,'Repeat offender, blacklist drafted'),
  ('SQA-2812-002','BulkMedicals Pvt','CFS-2812-002','2026-06-03'::date,'recovery_invoice',96000,'recovered','Finance Pradeep','2026-06-20'::date,'Full recovery received via NEFT'),
  ('SQA-2812-003','SwiftMed Trading','CFS-2812-003','2026-06-05'::date,'spot_audit',0,'in_progress','QA Lab Rajiv','2026-06-30'::date,'Spot audit of warehouse scheduled'),
  ('SQA-2812-004','MediParts Wholesale','CFS-2812-004','2026-06-08'::date,'warning_letter',0,'closed','Founder','2026-06-15'::date,'Warning letter issued, response received'),
  ('SQA-2812-005','BulkMedicals Pvt','CFS-2812-005','2026-06-10'::date,'legal_notice',87000,'escalated','Legal Counsel','2026-07-10'::date,'Legal notice via counsel'),
  ('SQA-2812-006','TrueMed Genuine Co','CFS-2812-006','2026-06-12'::date,'reinstated',0,'closed','Founder','2026-06-18'::date,'Reinstated after false-positive cleared'),
  ('SQA-2812-007','SwiftMed Trading','CFS-2812-007','2026-06-14'::date,'partial_blacklist',425000,'in_progress','Founder','2026-07-05'::date,'Doppler line partial blacklist'),
  ('SQA-2812-008','MediParts Wholesale',NULL,'2026-06-16'::date,'spot_audit',0,'queued','QA Lab Rajiv','2026-07-12'::date,'Followup spot audit on Q3 deliveries');

-- ============================================================================
-- RPCs (7+ SECDEF, founder-gated)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2812_signals_overview();
CREATE OR REPLACE FUNCTION founder_r2812_signals_overview()
RETURNS TABLE (
  total_signals integer,
  confirmed_count integer,
  pending_count integer,
  quarantined_count integer,
  total_loss_rupees bigint,
  total_units_affected bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE verification_status = 'confirmed_counterfeit')::integer,
    COUNT(*) FILTER (WHERE verification_status = 'pending')::integer,
    COUNT(*) FILTER (WHERE quarantine_status = 'quarantined')::integer,
    COALESCE(SUM(estimated_loss_rupees),0)::bigint,
    COALESCE(SUM(units_affected),0)::bigint
  FROM spare_counterfeit_signals_r2812;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_signals_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_signals_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2812_signals_list();
CREATE OR REPLACE FUNCTION founder_r2812_signals_list()
RETURNS TABLE (
  signal_code text,
  customer_org text,
  asset_model text,
  spare_part_name text,
  supplier_name text,
  signal_type text,
  severity text,
  verification_status text,
  quarantine_status text,
  units_affected integer,
  estimated_loss_rupees integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.signal_code, s.customer_org, s.asset_model, s.spare_part_name,
         s.supplier_name, s.signal_type, s.severity, s.verification_status,
         s.quarantine_status, s.units_affected, s.estimated_loss_rupees
  FROM spare_counterfeit_signals_r2812 s
  ORDER BY s.detection_month DESC, s.severity;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_signals_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_signals_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2812_signals_by_type();
CREATE OR REPLACE FUNCTION founder_r2812_signals_by_type()
RETURNS TABLE (
  signal_type text,
  signal_count integer,
  total_units bigint,
  total_loss bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.signal_type,
         COUNT(*)::integer,
         COALESCE(SUM(s.units_affected),0)::bigint,
         COALESCE(SUM(s.estimated_loss_rupees),0)::bigint
  FROM spare_counterfeit_signals_r2812 s
  GROUP BY s.signal_type
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_signals_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_signals_by_type() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2812_supplier_breakdown();
CREATE OR REPLACE FUNCTION founder_r2812_supplier_breakdown()
RETURNS TABLE (
  supplier_name text,
  signal_count integer,
  confirmed_count integer,
  total_loss bigint,
  open_actions integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.supplier_name,
         COUNT(*)::integer,
         COUNT(*) FILTER (WHERE s.verification_status = 'confirmed_counterfeit')::integer,
         COALESCE(SUM(s.estimated_loss_rupees),0)::bigint,
         (SELECT COUNT(*)::integer FROM supplier_quarantine_actions_r2812 a
            WHERE a.supplier_name = s.supplier_name
              AND a.action_status IN ('queued','in_progress','escalated'))
  FROM spare_counterfeit_signals_r2812 s
  GROUP BY s.supplier_name
  ORDER BY COUNT(*) FILTER (WHERE s.verification_status = 'confirmed_counterfeit') DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_supplier_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_supplier_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2812_actions_list();
CREATE OR REPLACE FUNCTION founder_r2812_actions_list()
RETURNS TABLE (
  action_code text,
  supplier_name text,
  related_signal_code text,
  action_type text,
  monetary_recovery_rupees integer,
  action_status text,
  responsible_owner text,
  due_at date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_code, a.supplier_name, a.related_signal_code, a.action_type,
         a.monetary_recovery_rupees, a.action_status, a.responsible_owner, a.due_at
  FROM supplier_quarantine_actions_r2812 a
  ORDER BY a.due_at, a.action_status;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_actions_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_actions_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2812_actions_overview();
CREATE OR REPLACE FUNCTION founder_r2812_actions_overview()
RETURNS TABLE (
  total_actions integer,
  open_actions integer,
  recovered_count integer,
  escalated_count integer,
  total_recovery bigint,
  pending_recovery bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE action_status IN ('queued','in_progress','escalated'))::integer,
    COUNT(*) FILTER (WHERE action_status = 'recovered')::integer,
    COUNT(*) FILTER (WHERE action_status = 'escalated')::integer,
    COALESCE(SUM(monetary_recovery_rupees) FILTER (WHERE action_status = 'recovered'),0)::bigint,
    COALESCE(SUM(monetary_recovery_rupees) FILTER (WHERE action_status IN ('queued','in_progress','escalated')),0)::bigint
  FROM supplier_quarantine_actions_r2812;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_actions_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_actions_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2812_severity_breakdown();
CREATE OR REPLACE FUNCTION founder_r2812_severity_breakdown()
RETURNS TABLE (
  severity text,
  signal_count integer,
  confirmed_count integer,
  quarantined_count integer,
  total_loss bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.severity,
         COUNT(*)::integer,
         COUNT(*) FILTER (WHERE s.verification_status = 'confirmed_counterfeit')::integer,
         COUNT(*) FILTER (WHERE s.quarantine_status = 'quarantined')::integer,
         COALESCE(SUM(s.estimated_loss_rupees),0)::bigint
  FROM spare_counterfeit_signals_r2812 s
  GROUP BY s.severity
  ORDER BY s.severity;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_severity_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_severity_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2812_customer_exposure();
CREATE OR REPLACE FUNCTION founder_r2812_customer_exposure()
RETURNS TABLE (
  customer_org text,
  signal_count integer,
  units_affected bigint,
  loss_rupees bigint,
  worst_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.customer_org,
         COUNT(*)::integer,
         COALESCE(SUM(s.units_affected),0)::bigint,
         COALESCE(SUM(s.estimated_loss_rupees),0)::bigint,
         MIN(s.severity)
  FROM spare_counterfeit_signals_r2812 s
  GROUP BY s.customer_org
  ORDER BY COALESCE(SUM(s.estimated_loss_rupees),0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2812_customer_exposure() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2812_customer_exposure() TO authenticated;

COMMIT;