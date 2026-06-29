-- Round 2914 — Engineer Monthly Customer-Site Spare-Parts Inventory Truck Audit
-- HEAVY founder ops round: 2 tables + 7 RPCs + seeds

-- =====================================================
-- TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS engineer_truck_audits_r2914 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_month date NOT NULL,
  engineer_label text NOT NULL,
  region text NOT NULL,
  customer_site text NOT NULL,
  truck_plate text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  completed_at timestamptz,
  status text NOT NULL CHECK (status IN ('scheduled','in_progress','completed','overdue','cancelled')),
  parts_scanned int NOT NULL DEFAULT 0,
  parts_expected int NOT NULL DEFAULT 0,
  shrinkage_value_rupees int NOT NULL DEFAULT 0,
  compliance_score numeric(5,2) NOT NULL DEFAULT 0,
  auditor_label text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE engineer_truck_audits_r2914 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS truck_audit_discrepancies_r2914 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid REFERENCES engineer_truck_audits_r2914(id) ON DELETE CASCADE,
  part_sku text NOT NULL,
  part_name text NOT NULL,
  expected_qty int NOT NULL,
  found_qty int NOT NULL,
  variance_qty int NOT NULL,
  unit_cost_rupees int NOT NULL,
  discrepancy_type text NOT NULL CHECK (discrepancy_type IN ('missing','excess','damaged','expired','wrong_location','counterfeit')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  resolved boolean NOT NULL DEFAULT false,
  resolution_note text,
  reported_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE truck_audit_discrepancies_r2914 ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- SEEDS
-- =====================================================

INSERT INTO engineer_truck_audits_r2914 (audit_month, engineer_label, region, customer_site, truck_plate, scheduled_at, completed_at, status, parts_scanned, parts_expected, shrinkage_value_rupees, compliance_score, auditor_label, notes) VALUES
('2026-06-01'::date, 'Rakesh K.', 'Hyderabad', 'Apollo Jubilee Hills', 'TS09AB1234', '2026-06-02 09:00'::timestamptz, '2026-06-02 11:30'::timestamptz, 'completed', 142, 145, 8400, 97.93, 'Region Ops Lead', 'Three missing micro-fuses'),
('2026-06-01'::date, 'Suresh M.', 'Bangalore', 'Manipal Old Airport Rd', 'KA01CD5678', '2026-06-03 10:00'::timestamptz, '2026-06-03 12:15'::timestamptz, 'completed', 198, 200, 3200, 99.00, 'Region Ops Lead', 'Clean audit, minor damage'),
('2026-06-01'::date, 'Vikram S.', 'Chennai', 'Apollo Greams Road', 'TN07EF9012', '2026-06-04 09:00'::timestamptz, NULL, 'in_progress', 88, 165, 0, 0, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Anand P.', 'Mumbai', 'Lilavati Hospital', 'MH02GH3456', '2026-06-05 08:30'::timestamptz, '2026-06-05 10:00'::timestamptz, 'completed', 120, 132, 24500, 90.91, 'Region Ops Lead', 'Counterfeit sensor flagged'),
('2026-06-01'::date, 'Karthik R.', 'Pune', 'Ruby Hall Clinic', 'MH12IJ7890', '2026-06-06 09:00'::timestamptz, '2026-06-06 11:00'::timestamptz, 'completed', 175, 178, 1200, 98.31, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Mohan T.', 'Delhi', 'Max Saket', 'DL01KL2345', '2026-06-07 09:00'::timestamptz, NULL, 'overdue', 0, 190, 0, 0, 'Region Ops Lead', 'Engineer rescheduled twice'),
('2026-06-01'::date, 'Pradeep N.', 'Kolkata', 'AMRI Dhakuria', 'WB02MN6789', '2026-06-08 09:00'::timestamptz, '2026-06-08 12:00'::timestamptz, 'completed', 156, 160, 5800, 97.50, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Ravi G.', 'Ahmedabad', 'Sterling Hospital', 'GJ01OP0123', '2026-06-09 09:30'::timestamptz, '2026-06-09 11:45'::timestamptz, 'completed', 134, 140, 9800, 95.71, 'Region Ops Lead', 'Expired sutures pack'),
('2026-06-01'::date, 'Naveen B.', 'Jaipur', 'Fortis Jaipur', 'RJ14QR4567', '2026-06-10 09:00'::timestamptz, '2026-06-10 11:00'::timestamptz, 'completed', 110, 115, 2400, 95.65, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Sanjay V.', 'Lucknow', 'Medanta Lucknow', 'UP32ST8901', '2026-06-11 09:00'::timestamptz, NULL, 'scheduled', 0, 152, 0, 0, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Deepak H.', 'Kochi', 'Aster Medcity', 'KL07UV2345', '2026-06-12 09:00'::timestamptz, '2026-06-12 10:45'::timestamptz, 'completed', 145, 148, 1800, 97.97, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Arjun L.', 'Indore', 'Bombay Hospital Indore', 'MP09WX6789', '2026-06-13 09:00'::timestamptz, '2026-06-13 11:30'::timestamptz, 'completed', 128, 138, 15200, 92.75, 'Region Ops Lead', 'Cluster of expired items'),
('2026-06-01'::date, 'Manish J.', 'Visakhapatnam', 'KIMS Vizag', 'AP31YZ0123', '2026-06-14 09:00'::timestamptz, '2026-06-14 12:00'::timestamptz, 'completed', 165, 170, 4500, 97.06, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Harish D.', 'Coimbatore', 'KMCH Coimbatore', 'TN38AB4567', '2026-06-15 09:00'::timestamptz, NULL, 'cancelled', 0, 145, 0, 0, 'Region Ops Lead', 'Site emergency, reschedule'),
('2026-06-01'::date, 'Gopal F.', 'Nagpur', 'Wockhardt Nagpur', 'MH40CD8901', '2026-06-16 09:00'::timestamptz, '2026-06-16 11:15'::timestamptz, 'completed', 102, 108, 3600, 94.44, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Sandeep W.', 'Bhubaneswar', 'Apollo Bhubaneswar', 'OD02EF2345', '2026-06-17 09:00'::timestamptz, '2026-06-17 11:00'::timestamptz, 'completed', 118, 122, 2900, 96.72, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Ajay Q.', 'Surat', 'BAPS Surat', 'GJ05GH6789', '2026-06-18 09:00'::timestamptz, '2026-06-18 11:30'::timestamptz, 'completed', 138, 142, 6700, 97.18, 'Region Ops Lead', NULL),
('2026-06-01'::date, 'Tarun X.', 'Patna', 'Paras HMRI', 'BR01IJ0123', '2026-06-19 09:00'::timestamptz, NULL, 'overdue', 0, 130, 0, 0, 'Region Ops Lead', 'Engineer on leave');

INSERT INTO truck_audit_discrepancies_r2914 (audit_id, part_sku, part_name, expected_qty, found_qty, variance_qty, unit_cost_rupees, discrepancy_type, severity, resolved, resolution_note, reported_at) VALUES
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Anand P.' LIMIT 1), 'SNS-OX-200', 'SpO2 Sensor Cable', 4, 2, -2, 8500, 'counterfeit', 'critical', false, NULL, '2026-06-05 10:30'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Anand P.' LIMIT 1), 'BAT-LI-12V', 'Li-Ion Battery 12V', 6, 4, -2, 3500, 'missing', 'high', true, 'Found in van locker', '2026-06-05 10:35'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Rakesh K.' LIMIT 1), 'FUS-MC-5A', 'Micro Fuse 5A', 10, 7, -3, 2800, 'missing', 'medium', false, NULL, '2026-06-02 11:00'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Ravi G.' LIMIT 1), 'SUT-PK-30', 'Suture Pack 30ct', 5, 5, 0, 1960, 'expired', 'high', false, NULL, '2026-06-09 11:00'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Arjun L.' LIMIT 1), 'GLO-NL-M', 'Nitrile Glove M', 12, 8, -4, 1200, 'expired', 'medium', false, NULL, '2026-06-13 11:00'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Arjun L.' LIMIT 1), 'TUB-PVC-2M', 'PVC Tubing 2m', 8, 5, -3, 3400, 'damaged', 'medium', true, 'Returned to depot', '2026-06-13 11:15'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Suresh M.' LIMIT 1), 'CLA-SS-10', 'SS Clamp 10mm', 15, 14, -1, 1600, 'missing', 'low', true, 'Used on prior job', '2026-06-03 12:00'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Karthik R.' LIMIT 1), 'LMP-LED-9W', 'LED Lamp 9W', 6, 7, 1, 1200, 'excess', 'low', true, 'Logged extra', '2026-06-06 10:50'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Pradeep N.' LIMIT 1), 'PRB-EKG-3L', 'EKG Probe 3-Lead', 3, 2, -1, 5800, 'missing', 'high', false, NULL, '2026-06-08 11:45'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Naveen B.' LIMIT 1), 'FIL-AIR-HE', 'HEPA Air Filter', 4, 3, -1, 2400, 'missing', 'medium', false, NULL, '2026-06-10 10:50'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Gopal F.' LIMIT 1), 'SCR-M6-50', 'M6 Screw Pack', 20, 16, -4, 900, 'wrong_location', 'low', true, 'In wrong bin', '2026-06-16 11:00'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Manish J.' LIMIT 1), 'SEN-TMP-HP', 'Temp Sensor HP', 5, 4, -1, 4500, 'missing', 'medium', false, NULL, '2026-06-14 11:50'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Deepak H.' LIMIT 1), 'CBL-USB-C2', 'USB-C Cable 2m', 8, 7, -1, 1800, 'missing', 'low', true, 'Customer kept', '2026-06-12 10:40'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Sandeep W.' LIMIT 1), 'ADP-12V-2A', '12V 2A Adapter', 6, 5, -1, 2900, 'missing', 'medium', false, NULL, '2026-06-17 10:55'::timestamptz),
((SELECT id FROM engineer_truck_audits_r2914 WHERE engineer_label='Ajay Q.' LIMIT 1), 'RES-FLW-PR', 'Flow Restrictor Pro', 4, 3, -1, 6700, 'damaged', 'high', false, NULL, '2026-06-18 11:25'::timestamptz);

-- =====================================================
-- RPCs (7) — is_founder gated
-- =====================================================

CREATE OR REPLACE FUNCTION founder_r2914_summary_kpis()
RETURNS TABLE(metric text, value text) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'Total Audits'::text, COUNT(*)::text FROM engineer_truck_audits_r2914
  UNION ALL SELECT 'Completed', COUNT(*)::text FROM engineer_truck_audits_r2914 WHERE status='completed'
  UNION ALL SELECT 'Overdue', COUNT(*)::text FROM engineer_truck_audits_r2914 WHERE status='overdue'
  UNION ALL SELECT 'In Progress', COUNT(*)::text FROM engineer_truck_audits_r2914 WHERE status='in_progress'
  UNION ALL SELECT 'Avg Compliance %', ROUND(AVG(compliance_score) FILTER (WHERE status='completed'),2)::text FROM engineer_truck_audits_r2914
  UNION ALL SELECT 'Total Shrinkage Rupees', SUM(shrinkage_value_rupees)::text FROM engineer_truck_audits_r2914
  UNION ALL SELECT 'Open Discrepancies', COUNT(*)::text FROM truck_audit_discrepancies_r2914 WHERE resolved=false
  UNION ALL SELECT 'Critical Discrepancies', COUNT(*)::text FROM truck_audit_discrepancies_r2914 WHERE severity='critical';
END $$;

CREATE OR REPLACE FUNCTION founder_r2914_audits_by_region()
RETURNS TABLE(region text, total_audits bigint, completed bigint, overdue bigint, avg_compliance numeric, total_shrinkage bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.region, COUNT(*)::bigint, COUNT(*) FILTER (WHERE a.status='completed')::bigint,
         COUNT(*) FILTER (WHERE a.status='overdue')::bigint,
         ROUND(AVG(a.compliance_score) FILTER (WHERE a.status='completed'),2),
         SUM(a.shrinkage_value_rupees)::bigint
  FROM engineer_truck_audits_r2914 a GROUP BY a.region ORDER BY SUM(a.shrinkage_value_rupees) DESC NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION founder_r2914_top_shrinkage_engineers()
RETURNS TABLE(engineer_label text, region text, audits_count bigint, shrinkage_rupees bigint, avg_compliance numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_label, MAX(a.region), COUNT(*)::bigint,
         SUM(a.shrinkage_value_rupees)::bigint,
         ROUND(AVG(a.compliance_score) FILTER (WHERE a.status='completed'),2)
  FROM engineer_truck_audits_r2914 a GROUP BY a.engineer_label ORDER BY SUM(a.shrinkage_value_rupees) DESC NULLS LAST LIMIT 10;
END $$;

CREATE OR REPLACE FUNCTION founder_r2914_open_critical_discrepancies()
RETURNS TABLE(part_sku text, part_name text, severity text, discrepancy_type text, variance_qty int, unit_cost_rupees int, engineer_label text, customer_site text, reported_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.part_sku, d.part_name, d.severity, d.discrepancy_type, d.variance_qty, d.unit_cost_rupees,
         a.engineer_label, a.customer_site, d.reported_at
  FROM truck_audit_discrepancies_r2914 d JOIN engineer_truck_audits_r2914 a ON a.id=d.audit_id
  WHERE d.resolved=false AND d.severity IN ('high','critical') ORDER BY d.reported_at DESC;
END $$;

CREATE OR REPLACE FUNCTION founder_r2914_discrepancy_type_breakdown()
RETURNS TABLE(discrepancy_type text, total_count bigint, resolved_count bigint, total_loss_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.discrepancy_type, COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE d.resolved)::bigint,
         SUM(ABS(d.variance_qty)*d.unit_cost_rupees)::bigint
  FROM truck_audit_discrepancies_r2914 d GROUP BY d.discrepancy_type ORDER BY SUM(ABS(d.variance_qty)*d.unit_cost_rupees) DESC NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION founder_r2914_overdue_audits()
RETURNS TABLE(engineer_label text, region text, customer_site text, truck_plate text, scheduled_at timestamptz, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_label, a.region, a.customer_site, a.truck_plate, a.scheduled_at, a.notes
  FROM engineer_truck_audits_r2914 a WHERE a.status IN ('overdue','cancelled') ORDER BY a.scheduled_at;
END $$;

CREATE OR REPLACE FUNCTION founder_r2914_recent_audits()
RETURNS TABLE(engineer_label text, region text, customer_site text, status text, parts_scanned int, parts_expected int, compliance_score numeric, shrinkage_value_rupees int, completed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engineer_label, a.region, a.customer_site, a.status, a.parts_scanned, a.parts_expected,
         a.compliance_score, a.shrinkage_value_rupees, a.completed_at
  FROM engineer_truck_audits_r2914 a ORDER BY COALESCE(a.completed_at, a.scheduled_at) DESC LIMIT 25;
END $$;

-- =====================================================
-- GRANTS
-- =====================================================
REVOKE EXECUTE ON FUNCTION founder_r2914_summary_kpis() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2914_audits_by_region() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2914_top_shrinkage_engineers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2914_open_critical_discrepancies() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2914_discrepancy_type_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2914_overdue_audits() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_r2914_recent_audits() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_r2914_summary_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2914_audits_by_region() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2914_top_shrinkage_engineers() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2914_open_critical_discrepancies() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2914_discrepancy_type_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2914_overdue_audits() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_r2914_recent_audits() TO authenticated;
