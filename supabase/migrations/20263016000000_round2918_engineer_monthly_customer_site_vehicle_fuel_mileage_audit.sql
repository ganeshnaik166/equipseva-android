-- Round r2918 — Engineer Monthly Customer Site Vehicle Fuel & Mileage Reimbursement Audit
-- HEAVY founder ops round

-- =====================================================================
-- Tables
-- =====================================================================

CREATE TABLE IF NOT EXISTS engineer_vehicle_fuel_logs_r2918 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  log_month date NOT NULL,
  vehicle_plate text NOT NULL,
  vehicle_type text NOT NULL,
  odometer_start_km numeric(10,1) NOT NULL,
  odometer_end_km numeric(10,1) NOT NULL,
  claimed_km numeric(10,1) NOT NULL,
  gps_verified_km numeric(10,1) NOT NULL,
  fuel_litres numeric(8,2) NOT NULL,
  fuel_cost_rupees numeric(10,2) NOT NULL,
  receipts_uploaded int NOT NULL,
  receipts_required int NOT NULL,
  reimbursement_status text NOT NULL,
  flagged_reason text
);
ALTER TABLE engineer_vehicle_fuel_logs_r2918 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS engineer_site_visit_mileage_r2918 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_code text NOT NULL,
  hospital_name text NOT NULL,
  city text NOT NULL,
  visit_date date NOT NULL,
  distance_one_way_km numeric(7,1) NOT NULL,
  reimbursable_rate_per_km numeric(5,2) NOT NULL,
  claimed_amount_rupees numeric(10,2) NOT NULL,
  approved_amount_rupees numeric(10,2) NOT NULL,
  variance_rupees numeric(10,2) NOT NULL,
  audit_status text NOT NULL,
  notes text
);
ALTER TABLE engineer_site_visit_mileage_r2918 ENABLE ROW LEVEL SECURITY;

-- =====================================================================
-- Seeds (>=12 rows each)
-- =====================================================================

INSERT INTO engineer_vehicle_fuel_logs_r2918 (engineer_code, engineer_name, log_month, vehicle_plate, vehicle_type, odometer_start_km, odometer_end_km, claimed_km, gps_verified_km, fuel_litres, fuel_cost_rupees, receipts_uploaded, receipts_required, reimbursement_status, flagged_reason) VALUES
('ENG-001','Ravi Kumar','2026-05-01'::date,'TS09AB1234','bike',12450.0,13180.0,730.0,712.0,14.20,1490.00,8,8,'approved',NULL),
('ENG-002','Sunita Reddy','2026-05-01'::date,'TS10CD5678','car',45120.0,46050.0,930.0,895.0,72.40,7820.00,12,12,'approved',NULL),
('ENG-003','Arun Joshi','2026-05-01'::date,'TS08EF9012','bike',8820.0,9710.0,890.0,612.0,17.10,1795.00,6,9,'flagged','gps gap > 270 km'),
('ENG-004','Kavya Iyer','2026-05-01'::date,'TS07GH3456','car',31200.0,32010.0,810.0,808.0,63.50,6857.00,10,10,'approved',NULL),
('ENG-005','Manish Patil','2026-05-01'::date,'TS11IJ7890','bike',15600.0,16210.0,610.0,595.0,12.30,1290.00,7,7,'approved',NULL),
('ENG-006','Deepa Nair','2026-05-01'::date,'TS09KL2345','car',22400.0,23380.0,980.0,940.0,76.80,8295.00,11,11,'approved',NULL),
('ENG-007','Vikram Sethi','2026-05-01'::date,'TS06MN6789','bike',9990.0,11200.0,1210.0,580.0,23.10,2425.00,4,12,'flagged','claimed 2x gps + receipts short'),
('ENG-008','Priya Menon','2026-05-01'::date,'TS09OP0123','car',58300.0,59180.0,880.0,872.0,68.40,7388.00,9,9,'approved',NULL),
('ENG-009','Rahul Verma','2026-05-01'::date,'TS10QR4567','bike',7400.0,8050.0,650.0,640.0,12.80,1340.00,8,8,'approved',NULL),
('ENG-010','Anjali Singh','2026-05-01'::date,'TS07ST8901','car',41200.0,42100.0,900.0,896.0,70.20,7585.00,10,10,'approved',NULL),
('ENG-011','Suresh Babu','2026-05-01'::date,'TS08UV2345','bike',13300.0,14010.0,710.0,378.0,13.80,1455.00,3,9,'flagged','receipts missing'),
('ENG-012','Neha Sharma','2026-05-01'::date,'TS09WX6789','car',27800.0,28720.0,920.0,918.0,71.50,7728.00,11,11,'approved',NULL),
('ENG-013','Krishna Rao','2026-05-01'::date,'TS11YZ0123','bike',18900.0,19560.0,660.0,655.0,13.20,1385.00,7,7,'approved',NULL),
('ENG-014','Lakshmi Pillai','2026-05-01'::date,'TS06AB4567','car',34500.0,35450.0,950.0,940.0,74.10,7995.00,12,12,'approved',NULL),
('ENG-015','Tarun Mehta','2026-05-01'::date,'TS08CD8901','bike',11200.0,12180.0,980.0,495.0,18.80,1975.00,5,11,'flagged','distance inflation suspected');

INSERT INTO engineer_site_visit_mileage_r2918 (engineer_code, hospital_name, city, visit_date, distance_one_way_km, reimbursable_rate_per_km, claimed_amount_rupees, approved_amount_rupees, variance_rupees, audit_status, notes) VALUES
('ENG-001','Apollo Hyderabad','Hyderabad','2026-05-04'::date,18.5,7.00,259.00,259.00,0.00,'approved','clean'),
('ENG-002','KIMS Secunderabad','Secunderabad','2026-05-05'::date,22.0,7.00,308.00,308.00,0.00,'approved','clean'),
('ENG-003','Yashoda Somajiguda','Hyderabad','2026-05-06'::date,15.4,7.00,310.00,216.00,-94.00,'reduced','rate misapplied'),
('ENG-004','Care Banjara','Hyderabad','2026-05-07'::date,9.8,7.00,137.00,137.00,0.00,'approved','clean'),
('ENG-005','Continental Gachibowli','Hyderabad','2026-05-08'::date,28.3,7.00,396.00,396.00,0.00,'approved','clean'),
('ENG-006','Sunshine Paradise','Hyderabad','2026-05-09'::date,12.1,7.00,200.00,170.00,-30.00,'reduced','rounding'),
('ENG-007','Star Banjara','Hyderabad','2026-05-10'::date,11.5,7.00,322.00,161.00,-161.00,'reduced','distance doubled'),
('ENG-008','Manipal Tadepalli','Vijayawada','2026-05-11'::date,275.0,7.00,3850.00,3850.00,0.00,'approved','intercity'),
('ENG-009','Rainbow Childrens','Hyderabad','2026-05-12'::date,7.4,7.00,103.00,103.00,0.00,'approved','clean'),
('ENG-010','AIG Hospitals','Hyderabad','2026-05-13'::date,14.2,7.00,199.00,199.00,0.00,'approved','clean'),
('ENG-011','Omega Cancer','Hyderabad','2026-05-14'::date,21.0,7.00,294.00,147.00,-147.00,'reduced','no receipts'),
('ENG-012','Citizens Specialty','Hyderabad','2026-05-15'::date,16.8,7.00,235.00,235.00,0.00,'approved','clean'),
('ENG-013','Krishna Institute','Secunderabad','2026-05-16'::date,19.5,7.00,273.00,273.00,0.00,'approved','clean'),
('ENG-014','MaxCure','Hyderabad','2026-05-17'::date,13.6,7.00,190.00,190.00,0.00,'approved','clean'),
('ENG-015','Renova Hospitals','Hyderabad','2026-05-18'::date,17.3,7.00,485.00,242.00,-243.00,'reduced','duplicate visit');

-- =====================================================================
-- RPCs (7)
-- =====================================================================

CREATE OR REPLACE FUNCTION rpc_r2918_fuel_log_overview()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  log_month date,
  vehicle_plate text,
  claimed_km numeric,
  gps_verified_km numeric,
  fuel_cost_rupees numeric,
  reimbursement_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.engineer_code, f.engineer_name, f.log_month, f.vehicle_plate,
         f.claimed_km, f.gps_verified_km, f.fuel_cost_rupees, f.reimbursement_status
  FROM engineer_vehicle_fuel_logs_r2918 f
  ORDER BY f.fuel_cost_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2918_fuel_log_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2918_fuel_log_overview() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_r2918_flagged_fuel_logs()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  claimed_km numeric,
  gps_verified_km numeric,
  km_gap numeric,
  flagged_reason text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.engineer_code, f.engineer_name, f.claimed_km, f.gps_verified_km,
         (f.claimed_km - f.gps_verified_km) AS km_gap,
         f.flagged_reason
  FROM engineer_vehicle_fuel_logs_r2918 f
  WHERE f.reimbursement_status = 'flagged'
  ORDER BY (f.claimed_km - f.gps_verified_km) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2918_flagged_fuel_logs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2918_flagged_fuel_logs() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_r2918_site_visit_audit()
RETURNS TABLE (
  engineer_code text,
  hospital_name text,
  city text,
  visit_date date,
  distance_one_way_km numeric,
  claimed_amount_rupees numeric,
  approved_amount_rupees numeric,
  variance_rupees numeric,
  audit_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.hospital_name, s.city, s.visit_date,
         s.distance_one_way_km, s.claimed_amount_rupees,
         s.approved_amount_rupees, s.variance_rupees, s.audit_status
  FROM engineer_site_visit_mileage_r2918 s
  ORDER BY s.visit_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2918_site_visit_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2918_site_visit_audit() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_r2918_engineer_reimbursement_totals()
RETURNS TABLE (
  engineer_code text,
  total_fuel_rupees numeric,
  total_mileage_claimed numeric,
  total_mileage_approved numeric,
  total_variance numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.engineer_code,
         COALESCE(SUM(f.fuel_cost_rupees),0) AS total_fuel_rupees,
         COALESCE(SUM(s.claimed_amount_rupees),0) AS total_mileage_claimed,
         COALESCE(SUM(s.approved_amount_rupees),0) AS total_mileage_approved,
         COALESCE(SUM(s.variance_rupees),0) AS total_variance
  FROM engineer_vehicle_fuel_logs_r2918 f
  LEFT JOIN engineer_site_visit_mileage_r2918 s ON s.engineer_code = f.engineer_code
  GROUP BY f.engineer_code
  ORDER BY total_fuel_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2918_engineer_reimbursement_totals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2918_engineer_reimbursement_totals() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_r2918_receipt_compliance()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  receipts_uploaded int,
  receipts_required int,
  compliance_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT f.engineer_code, f.engineer_name,
         f.receipts_uploaded, f.receipts_required,
         ROUND((f.receipts_uploaded::numeric / NULLIF(f.receipts_required,0)) * 100, 1) AS compliance_pct
  FROM engineer_vehicle_fuel_logs_r2918 f
  ORDER BY compliance_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2918_receipt_compliance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2918_receipt_compliance() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_r2918_top_variance_visits()
RETURNS TABLE (
  engineer_code text,
  hospital_name text,
  visit_date date,
  claimed_amount_rupees numeric,
  approved_amount_rupees numeric,
  variance_rupees numeric,
  notes text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.hospital_name, s.visit_date,
         s.claimed_amount_rupees, s.approved_amount_rupees,
         s.variance_rupees, s.notes
  FROM engineer_site_visit_mileage_r2918 s
  WHERE s.variance_rupees < 0
  ORDER BY s.variance_rupees ASC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2918_top_variance_visits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2918_top_variance_visits() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_r2918_monthly_kpis()
RETURNS TABLE (
  total_engineers int,
  total_fuel_spend numeric,
  total_km_claimed numeric,
  total_km_verified numeric,
  flagged_logs int,
  total_visits int,
  total_variance numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT engineer_code)::int FROM engineer_vehicle_fuel_logs_r2918),
    (SELECT COALESCE(SUM(fuel_cost_rupees),0) FROM engineer_vehicle_fuel_logs_r2918),
    (SELECT COALESCE(SUM(claimed_km),0) FROM engineer_vehicle_fuel_logs_r2918),
    (SELECT COALESCE(SUM(gps_verified_km),0) FROM engineer_vehicle_fuel_logs_r2918),
    (SELECT COUNT(*)::int FROM engineer_vehicle_fuel_logs_r2918 WHERE reimbursement_status='flagged'),
    (SELECT COUNT(*)::int FROM engineer_site_visit_mileage_r2918),
    (SELECT COALESCE(SUM(variance_rupees),0) FROM engineer_site_visit_mileage_r2918);
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2918_monthly_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2918_monthly_kpis() TO authenticated;
