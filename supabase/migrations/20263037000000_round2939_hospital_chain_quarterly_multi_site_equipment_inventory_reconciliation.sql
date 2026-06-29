-- Round r2939: Hospital Chain Quarterly Multi-Site Equipment Inventory Reconciliation Sweep

CREATE TABLE IF NOT EXISTS hospital_chain_inventory_sweeps_r2939 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  site_code text NOT NULL,
  city text NOT NULL,
  sweep_quarter text NOT NULL CHECK (sweep_quarter IN ('q1_fy27','q2_fy27','q3_fy27','q4_fy27')),
  sweep_status text NOT NULL CHECK (sweep_status IN ('scheduled','in_progress','reconciled','exceptions_open','closed')),
  expected_units int NOT NULL DEFAULT 0,
  scanned_units int NOT NULL DEFAULT 0,
  missing_units int NOT NULL DEFAULT 0,
  extra_units int NOT NULL DEFAULT 0,
  reconciliation_pct numeric(5,2) NOT NULL DEFAULT 0,
  swept_at timestamptz
);
ALTER TABLE hospital_chain_inventory_sweeps_r2939 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS hospital_chain_inventory_exceptions_r2939 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  sweep_id uuid REFERENCES hospital_chain_inventory_sweeps_r2939(id) ON DELETE CASCADE,
  asset_tag text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('ventilator','monitor','infusion_pump','ultrasound','xray','defibrillator','ecg','suction','autoclave','dialysis')),
  exception_type text NOT NULL CHECK (exception_type IN ('missing','damaged','mislabeled','unauthorized_move','duplicate_tag','warranty_lapsed')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  resolution_status text NOT NULL CHECK (resolution_status IN ('open','investigating','resolved','escalated','written_off')),
  est_value_rupees int NOT NULL DEFAULT 0,
  resolved_at timestamptz
);
ALTER TABLE hospital_chain_inventory_exceptions_r2939 ENABLE ROW LEVEL SECURITY;

-- Seed sweeps (20 rows)
INSERT INTO hospital_chain_inventory_sweeps_r2939 (chain_name, site_code, city, sweep_quarter, sweep_status, expected_units, scanned_units, missing_units, extra_units, reconciliation_pct, swept_at) VALUES
('Apollo','APL-HYD-01','Hyderabad','q3_fy27','reconciled',420,418,2,0,99.52,(now()-interval '12 days')::timestamptz),
('Apollo','APL-CHN-02','Chennai','q3_fy27','exceptions_open',380,372,8,0,97.89,(now()-interval '10 days')::timestamptz),
('Apollo','APL-BLR-03','Bangalore','q3_fy27','closed',510,510,0,0,100.00,(now()-interval '20 days')::timestamptz),
('Manipal','MNP-BLR-01','Bangalore','q3_fy27','reconciled',290,287,3,0,98.97,(now()-interval '8 days')::timestamptz),
('Manipal','MNP-VJW-02','Vijayawada','q3_fy27','in_progress',180,165,0,0,91.67,(now()-interval '2 days')::timestamptz),
('Fortis','FRT-MUM-01','Mumbai','q3_fy27','exceptions_open',460,450,10,0,97.83,(now()-interval '15 days')::timestamptz),
('Fortis','FRT-DEL-02','Delhi','q3_fy27','reconciled',520,518,2,0,99.62,(now()-interval '14 days')::timestamptz),
('Max','MAX-DEL-01','Delhi','q3_fy27','scheduled',340,0,0,0,0.00,NULL),
('Max','MAX-GGN-02','Gurgaon','q3_fy27','in_progress',310,280,0,0,90.32,(now()-interval '1 days')::timestamptz),
('Narayana','NRY-BLR-01','Bangalore','q3_fy27','reconciled',270,269,1,0,99.63,(now()-interval '6 days')::timestamptz),
('Narayana','NRY-KOL-02','Kolkata','q3_fy27','closed',250,250,0,0,100.00,(now()-interval '22 days')::timestamptz),
('AIIMS','AIM-DEL-01','Delhi','q3_fy27','exceptions_open',620,608,12,0,98.06,(now()-interval '18 days')::timestamptz),
('KIMS','KMS-HYD-01','Hyderabad','q3_fy27','reconciled',310,308,2,0,99.35,(now()-interval '9 days')::timestamptz),
('KIMS','KMS-SCD-02','Secunderabad','q3_fy27','in_progress',220,200,0,0,90.91,(now()-interval '3 days')::timestamptz),
('Yashoda','YSD-HYD-01','Hyderabad','q3_fy27','reconciled',340,338,2,0,99.41,(now()-interval '11 days')::timestamptz),
('Yashoda','YSD-HYD-02','Hyderabad','q3_fy27','exceptions_open',360,348,12,0,96.67,(now()-interval '13 days')::timestamptz),
('Care','CRE-HYD-01','Hyderabad','q2_fy27','closed',290,290,0,0,100.00,(now()-interval '95 days')::timestamptz),
('Continental','CNT-HYD-01','Hyderabad','q3_fy27','scheduled',310,0,0,0,0.00,NULL),
('Rainbow','RNB-HYD-01','Hyderabad','q3_fy27','in_progress',150,140,0,0,93.33,(now()-interval '4 days')::timestamptz),
('Sunshine','SNS-HYD-01','Hyderabad','q3_fy27','reconciled',180,179,1,0,99.44,(now()-interval '7 days')::timestamptz);

-- Seed exceptions (24 rows)
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-APL-0001','ventilator','missing','p0','investigating',850000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='APL-CHN-02' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-APL-0002','monitor','damaged','p2','resolved',120000,(now()-interval '3 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='APL-CHN-02' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-APL-0003','infusion_pump','mislabeled','p3','resolved',45000,(now()-interval '5 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='APL-CHN-02' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-FRT-0001','ultrasound','missing','p0','escalated',1200000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='FRT-MUM-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-FRT-0002','defibrillator','unauthorized_move','p1','investigating',220000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='FRT-MUM-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-FRT-0003','xray','damaged','p2','resolved',380000,(now()-interval '6 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='FRT-MUM-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-AIM-0001','dialysis','missing','p0','escalated',1800000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='AIM-DEL-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-AIM-0002','ventilator','duplicate_tag','p2','resolved',850000,(now()-interval '4 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='AIM-DEL-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-AIM-0003','ecg','mislabeled','p3','resolved',35000,(now()-interval '8 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='AIM-DEL-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-AIM-0004','autoclave','warranty_lapsed','p2','open',180000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='AIM-DEL-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-YSD-0001','monitor','missing','p1','investigating',120000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='YSD-HYD-02' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-YSD-0002','suction','damaged','p3','resolved',28000,(now()-interval '2 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='YSD-HYD-02' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-YSD-0003','infusion_pump','unauthorized_move','p1','escalated',45000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='YSD-HYD-02' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-APL-0010','ecg','mislabeled','p3','resolved',35000,(now()-interval '15 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='APL-HYD-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-APL-0011','monitor','missing','p2','resolved',120000,(now()-interval '11 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='APL-HYD-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-MNP-0001','xray','damaged','p2','investigating',380000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='MNP-BLR-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-MNP-0002','ventilator','mislabeled','p3','resolved',850000,(now()-interval '7 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='MNP-BLR-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-NRY-0001','dialysis','warranty_lapsed','p1','escalated',1800000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='NRY-BLR-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-KMS-0001','autoclave','damaged','p2','resolved',180000,(now()-interval '5 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='KMS-HYD-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-KMS-0002','ecg','duplicate_tag','p3','resolved',35000,(now()-interval '6 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='KMS-HYD-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-SNS-0001','suction','missing','p3','resolved',28000,(now()-interval '4 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='SNS-HYD-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-RNB-0001','infusion_pump','unauthorized_move','p2','open',45000,NULL FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='RNB-HYD-01' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-FRT-0010','monitor','duplicate_tag','p3','written_off',120000,(now()-interval '9 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='FRT-DEL-02' LIMIT 1;
INSERT INTO hospital_chain_inventory_exceptions_r2939 (sweep_id, asset_tag, equipment_category, exception_type, severity, resolution_status, est_value_rupees, resolved_at)
SELECT id, 'AST-NRY-0010','defibrillator','mislabeled','p3','resolved',220000,(now()-interval '14 days')::timestamptz FROM hospital_chain_inventory_sweeps_r2939 WHERE site_code='NRY-KOL-02' LIMIT 1;

-- RPC 1: chain rollup
CREATE OR REPLACE FUNCTION r2939_chain_rollup()
RETURNS TABLE(chain_name text, sites int, expected_units bigint, scanned_units bigint, missing_units bigint, avg_reconciliation numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, count(*)::int, sum(s.expected_units), sum(s.scanned_units), sum(s.missing_units), round(avg(s.reconciliation_pct),2)
    FROM hospital_chain_inventory_sweeps_r2939 s
    GROUP BY s.chain_name
    ORDER BY sum(s.missing_units) DESC;
END $$;

-- RPC 2: sweep status mix
CREATE OR REPLACE FUNCTION r2939_status_mix()
RETURNS TABLE(sweep_status text, cnt int, total_missing bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.sweep_status, count(*)::int, sum(s.missing_units)
    FROM hospital_chain_inventory_sweeps_r2939 s
    GROUP BY s.sweep_status
    ORDER BY count(*) DESC;
END $$;

-- RPC 3: exceptions by severity
CREATE OR REPLACE FUNCTION r2939_exceptions_by_severity()
RETURNS TABLE(severity text, total int, open_cnt int, value_at_risk bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.severity,
           count(*)::int,
           (count(*) filter (where e.resolution_status IN ('open','investigating','escalated')))::int,
           sum(e.est_value_rupees) filter (where e.resolution_status IN ('open','investigating','escalated'))
    FROM hospital_chain_inventory_exceptions_r2939 e
    GROUP BY e.severity
    ORDER BY e.severity;
END $$;

-- RPC 4: top loss sites
CREATE OR REPLACE FUNCTION r2939_top_loss_sites()
RETURNS TABLE(chain_name text, site_code text, city text, missing_units int, value_at_risk bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.chain_name, s.site_code, s.city, s.missing_units,
           COALESCE(sum(e.est_value_rupees) filter (where e.resolution_status IN ('open','investigating','escalated')), 0)
    FROM hospital_chain_inventory_sweeps_r2939 s
    LEFT JOIN hospital_chain_inventory_exceptions_r2939 e ON e.sweep_id = s.id
    GROUP BY s.chain_name, s.site_code, s.city, s.missing_units
    ORDER BY s.missing_units DESC, COALESCE(sum(e.est_value_rupees),0) DESC
    LIMIT 10;
END $$;

-- RPC 5: category breakdown
CREATE OR REPLACE FUNCTION r2939_category_breakdown()
RETURNS TABLE(equipment_category text, exceptions int, value_at_risk bigint, p0_cnt int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.equipment_category, count(*)::int, sum(e.est_value_rupees),
           (count(*) filter (where e.severity = 'p0'))::int
    FROM hospital_chain_inventory_exceptions_r2939 e
    GROUP BY e.equipment_category
    ORDER BY sum(e.est_value_rupees) DESC;
END $$;

-- RPC 6: open p0 exceptions
CREATE OR REPLACE FUNCTION r2939_open_p0_exceptions()
RETURNS TABLE(asset_tag text, chain_name text, site_code text, equipment_category text, exception_type text, value_rupees int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.asset_tag, s.chain_name, s.site_code, e.equipment_category, e.exception_type, e.est_value_rupees
    FROM hospital_chain_inventory_exceptions_r2939 e
    JOIN hospital_chain_inventory_sweeps_r2939 s ON s.id = e.sweep_id
    WHERE e.severity = 'p0' AND e.resolution_status IN ('open','investigating','escalated')
    ORDER BY e.est_value_rupees DESC;
END $$;

-- RPC 7: kpi summary
CREATE OR REPLACE FUNCTION r2939_kpi_summary()
RETURNS TABLE(total_sweeps int, sites_closed int, sites_open int, total_exceptions int, open_value_rupees bigint, avg_recon_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::int FROM hospital_chain_inventory_sweeps_r2939),
      (SELECT (count(*) filter (where sweep_status = 'closed'))::int FROM hospital_chain_inventory_sweeps_r2939),
      (SELECT (count(*) filter (where sweep_status IN ('scheduled','in_progress','exceptions_open')))::int FROM hospital_chain_inventory_sweeps_r2939),
      (SELECT count(*)::int FROM hospital_chain_inventory_inventory_safe()),
      (SELECT COALESCE(sum(est_value_rupees),0) FROM hospital_chain_inventory_exceptions_r2939 WHERE resolution_status IN ('open','investigating','escalated')),
      (SELECT round(avg(reconciliation_pct),2) FROM hospital_chain_inventory_sweeps_r2939 WHERE sweep_status <> 'scheduled');
END $$;

-- helper view fn for count
CREATE OR REPLACE FUNCTION hospital_chain_inventory_inventory_safe()
RETURNS SETOF hospital_chain_inventory_exceptions_r2939
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  RETURN QUERY SELECT * FROM hospital_chain_inventory_exceptions_r2939;
END $$;

REVOKE EXECUTE ON FUNCTION r2939_chain_rollup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2939_status_mix() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2939_exceptions_by_severity() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2939_top_loss_sites() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2939_category_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2939_open_p0_exceptions() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION r2939_kpi_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION hospital_chain_inventory_inventory_safe() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION r2939_chain_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION r2939_status_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION r2939_exceptions_by_severity() TO authenticated;
GRANT EXECUTE ON FUNCTION r2939_top_loss_sites() TO authenticated;
GRANT EXECUTE ON FUNCTION r2939_category_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION r2939_open_p0_exceptions() TO authenticated;
GRANT EXECUTE ON FUNCTION r2939_kpi_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION hospital_chain_inventory_inventory_safe() TO authenticated;
