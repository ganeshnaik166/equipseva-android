BEGIN;

-- ============================================================
-- Round 2710: Engineer Monthly Vehicle Maintenance Log
-- HEAVY ★★★★ founder console
-- ============================================================

-- ------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineer_vehicles_r2710 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  vehicle_reg_no text NOT NULL UNIQUE,
  vehicle_type text NOT NULL CHECK (vehicle_type IN ('two_wheeler','three_wheeler','van','car')),
  vehicle_make text NOT NULL,
  vehicle_model text NOT NULL,
  purchase_year int NOT NULL CHECK (purchase_year BETWEEN 2010 AND 2030),
  current_km int NOT NULL CHECK (current_km >= 0),
  last_service_km int NOT NULL CHECK (last_service_km >= 0),
  next_service_due_km int NOT NULL CHECK (next_service_due_km >= 0),
  next_service_due_date date NOT NULL,
  insurance_expiry date NOT NULL,
  fitness_expiry date NOT NULL,
  status text NOT NULL CHECK (status IN ('active','in_service','retired','accident')),
  region text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_vehicles_r2710 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_vehicles_r2710;
CREATE POLICY founder_all ON engineer_vehicles_r2710 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS vehicle_maintenance_log_r2710 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES engineer_vehicles_r2710(id) ON DELETE CASCADE,
  log_month date NOT NULL,
  service_date date NOT NULL,
  service_type text NOT NULL CHECK (service_type IN ('routine','repair','tyre','battery','oil','accident','inspection')),
  km_reading int NOT NULL CHECK (km_reading >= 0),
  repair_description text NOT NULL,
  parts_cost_rupees numeric(12,2) NOT NULL CHECK (parts_cost_rupees >= 0),
  labour_cost_rupees numeric(12,2) NOT NULL CHECK (labour_cost_rupees >= 0),
  total_cost_rupees numeric(12,2) NOT NULL CHECK (total_cost_rupees >= 0),
  vendor_name text NOT NULL,
  downtime_hours numeric(6,2) NOT NULL CHECK (downtime_hours >= 0),
  approval_status text NOT NULL CHECK (approval_status IN ('approved','pending','rejected')),
  paid_by text NOT NULL CHECK (paid_by IN ('company','engineer_reimburse','insurance')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE vehicle_maintenance_log_r2710 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON vehicle_maintenance_log_r2710;
CREATE POLICY founder_all ON vehicle_maintenance_log_r2710 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ------------------------------------------------------------
-- Seed: engineer_vehicles_r2710
-- ------------------------------------------------------------

INSERT INTO engineer_vehicles_r2710 (engineer_name, engineer_code, vehicle_reg_no, vehicle_type, vehicle_make, vehicle_model, purchase_year, current_km, last_service_km, next_service_due_km, next_service_due_date, insurance_expiry, fitness_expiry, status, region) VALUES
  ('Ravi Kumar','ENG-001','TS09EZ1234','two_wheeler','Hero','Splendor Plus',2023,28450,26000,29000,'2026-07-10'::date,'2026-12-01'::date,'2027-03-15'::date,'active','Hyderabad'),
  ('Anand Reddy','ENG-002','TS10FA5678','van','Maruti','Eeco',2022,68200,65000,70000,'2026-07-05'::date,'2026-09-20'::date,'2026-11-30'::date,'in_service','Hyderabad'),
  ('Vikram Singh','ENG-003','KA01ML9012','two_wheeler','Bajaj','Pulsar 150',2024,15800,14000,17000,'2026-08-20'::date,'2027-01-10'::date,'2027-06-01'::date,'active','Bangalore'),
  ('Sneha Patil','ENG-004','MH12NQ3456','three_wheeler','Piaggio','Ape City',2023,42100,40000,44000,'2026-07-15'::date,'2026-10-25'::date,'2026-12-15'::date,'active','Pune'),
  ('Karan Mehta','ENG-005','GJ05PR7890','van','Tata','Ace Gold',2021,89500,87000,91000,'2026-07-02'::date,'2026-08-15'::date,'2026-09-30'::date,'active','Ahmedabad'),
  ('Deepa Iyer','ENG-006','TN22ST2345','two_wheeler','Honda','Activa 6G',2024,12300,10000,13000,'2026-08-01'::date,'2027-02-20'::date,'2027-05-10'::date,'active','Chennai'),
  ('Manoj Verma','ENG-007','DL08UV6789','car','Maruti','Swift Dzire',2022,72400,70000,74000,'2026-07-25'::date,'2026-11-05'::date,'2027-01-20'::date,'accident','Delhi');

-- ------------------------------------------------------------
-- Seed: vehicle_maintenance_log_r2710
-- ------------------------------------------------------------

INSERT INTO vehicle_maintenance_log_r2710 (vehicle_id, log_month, service_date, service_type, km_reading, repair_description, parts_cost_rupees, labour_cost_rupees, total_cost_rupees, vendor_name, downtime_hours, approval_status, paid_by, notes)
SELECT id, '2026-06-01'::date, '2026-06-10'::date, 'routine', 26000, 'Engine oil + filter change', 450, 200, 650, 'Hero Service Center', 1.5, 'approved', 'company', 'Standard 3K service' FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'TS09EZ1234'
UNION ALL
SELECT id, '2026-06-01'::date, '2026-06-12'::date, 'tyre', 65000, 'Rear tyre replacement x2', 6800, 400, 7200, 'MRF Tyre Hub', 3.0, 'approved', 'company', 'Worn tread reported by engineer' FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'TS10FA5678'
UNION ALL
SELECT id, '2026-06-01'::date, '2026-06-15'::date, 'oil', 14000, 'Synthetic oil top-up', 380, 150, 530, 'Bajaj Probiking', 1.0, 'approved', 'company', NULL FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'KA01ML9012'
UNION ALL
SELECT id, '2026-06-01'::date, '2026-06-18'::date, 'repair', 40000, 'Clutch plate + cable replace', 2200, 800, 3000, 'Piaggio Workshop Pune', 5.5, 'pending', 'company', 'High mileage wear' FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'MH12NQ3456'
UNION ALL
SELECT id, '2026-06-01'::date, '2026-06-20'::date, 'battery', 87000, 'Battery replacement Exide 70AH', 5400, 100, 5500, 'Exide Care Ahmedabad', 0.5, 'approved', 'company', '4-year battery dead' FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'GJ05PR7890'
UNION ALL
SELECT id, '2026-06-01'::date, '2026-06-22'::date, 'inspection', 10000, 'Free service inspection', 0, 0, 0, 'Honda Service', 1.0, 'approved', 'company', 'No issues found' FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'TN22ST2345'
UNION ALL
SELECT id, '2026-06-01'::date, '2026-06-25'::date, 'accident', 70000, 'Front bumper + headlamp damage repair', 18500, 4500, 23000, 'Maruti Authorized', 48.0, 'approved', 'insurance', 'Minor collision, insurance claim filed' FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'DL08UV6789'
UNION ALL
SELECT id, '2026-05-01'::date, '2026-05-15'::date, 'routine', 22000, 'Engine oil + brake pads', 1200, 500, 1700, 'Hero Service Center', 2.0, 'approved', 'company', 'Brake pads worn at 60%' FROM engineer_vehicles_r2710 WHERE vehicle_reg_no = 'TS09EZ1234';

-- ------------------------------------------------------------
-- RPCs
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS r2710_fleet_overview();
CREATE OR REPLACE FUNCTION r2710_fleet_overview()
RETURNS TABLE (
  total_vehicles bigint,
  active_vehicles bigint,
  in_service_vehicles bigint,
  accident_vehicles bigint,
  total_fleet_km bigint,
  vehicles_due_30d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE status = 'active')::bigint,
    count(*) FILTER (WHERE status = 'in_service')::bigint,
    count(*) FILTER (WHERE status = 'accident')::bigint,
    coalesce(sum(current_km),0)::bigint,
    count(*) FILTER (WHERE next_service_due_date <= current_date + 30)::bigint
  FROM engineer_vehicles_r2710;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_fleet_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_fleet_overview() TO authenticated;

DROP FUNCTION IF EXISTS r2710_monthly_cost_summary();
CREATE OR REPLACE FUNCTION r2710_monthly_cost_summary()
RETURNS TABLE (
  total_logs bigint,
  total_parts_cost numeric,
  total_labour_cost numeric,
  total_cost numeric,
  avg_cost_per_service numeric,
  insurance_claims_cost numeric,
  company_paid_cost numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    coalesce(sum(parts_cost_rupees),0),
    coalesce(sum(labour_cost_rupees),0),
    coalesce(sum(total_cost_rupees),0),
    coalesce(avg(total_cost_rupees),0),
    coalesce(sum(total_cost_rupees) FILTER (WHERE paid_by = 'insurance'),0),
    coalesce(sum(total_cost_rupees) FILTER (WHERE paid_by = 'company'),0)
  FROM vehicle_maintenance_log_r2710;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_monthly_cost_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_monthly_cost_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2710_vehicles_list();
CREATE OR REPLACE FUNCTION r2710_vehicles_list()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  engineer_code text,
  vehicle_reg_no text,
  vehicle_type text,
  make_model text,
  current_km int,
  next_service_due_km int,
  km_to_next int,
  next_service_due_date date,
  days_to_next int,
  status text,
  region text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.engineer_name, v.engineer_code, v.vehicle_reg_no, v.vehicle_type,
         (v.vehicle_make || ' ' || v.vehicle_model)::text,
         v.current_km, v.next_service_due_km,
         (v.next_service_due_km - v.current_km)::int,
         v.next_service_due_date,
         (v.next_service_due_date - current_date)::int,
         v.status, v.region
  FROM engineer_vehicles_r2710 v
  ORDER BY v.next_service_due_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_vehicles_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_vehicles_list() TO authenticated;

DROP FUNCTION IF EXISTS r2710_recent_maintenance_logs();
CREATE OR REPLACE FUNCTION r2710_recent_maintenance_logs()
RETURNS TABLE (
  id uuid,
  service_date date,
  engineer_name text,
  vehicle_reg_no text,
  service_type text,
  km_reading int,
  repair_description text,
  total_cost_rupees numeric,
  vendor_name text,
  downtime_hours numeric,
  approval_status text,
  paid_by text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.service_date, v.engineer_name, v.vehicle_reg_no, m.service_type,
         m.km_reading, m.repair_description, m.total_cost_rupees, m.vendor_name,
         m.downtime_hours, m.approval_status, m.paid_by
  FROM vehicle_maintenance_log_r2710 m
  JOIN engineer_vehicles_r2710 v ON v.id = m.vehicle_id
  ORDER BY m.service_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_recent_maintenance_logs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_recent_maintenance_logs() TO authenticated;

DROP FUNCTION IF EXISTS r2710_cost_by_service_type();
CREATE OR REPLACE FUNCTION r2710_cost_by_service_type()
RETURNS TABLE (
  service_type text,
  log_count bigint,
  total_cost numeric,
  avg_cost numeric,
  total_downtime_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.service_type, count(*)::bigint, coalesce(sum(m.total_cost_rupees),0),
         coalesce(avg(m.total_cost_rupees),0), coalesce(sum(m.downtime_hours),0)
  FROM vehicle_maintenance_log_r2710 m
  GROUP BY m.service_type
  ORDER BY sum(m.total_cost_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_cost_by_service_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_cost_by_service_type() TO authenticated;

DROP FUNCTION IF EXISTS r2710_top_spend_vehicles();
CREATE OR REPLACE FUNCTION r2710_top_spend_vehicles()
RETURNS TABLE (
  vehicle_reg_no text,
  engineer_name text,
  total_logs bigint,
  total_spend numeric,
  total_downtime_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.vehicle_reg_no, v.engineer_name, count(m.id)::bigint,
         coalesce(sum(m.total_cost_rupees),0), coalesce(sum(m.downtime_hours),0)
  FROM engineer_vehicles_r2710 v
  LEFT JOIN vehicle_maintenance_log_r2710 m ON m.vehicle_id = v.id
  GROUP BY v.vehicle_reg_no, v.engineer_name
  ORDER BY sum(m.total_cost_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_top_spend_vehicles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_top_spend_vehicles() TO authenticated;

DROP FUNCTION IF EXISTS r2710_pending_approvals();
CREATE OR REPLACE FUNCTION r2710_pending_approvals()
RETURNS TABLE (
  id uuid,
  service_date date,
  engineer_name text,
  vehicle_reg_no text,
  service_type text,
  repair_description text,
  total_cost_rupees numeric,
  vendor_name text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.service_date, v.engineer_name, v.vehicle_reg_no, m.service_type,
         m.repair_description, m.total_cost_rupees, m.vendor_name
  FROM vehicle_maintenance_log_r2710 m
  JOIN engineer_vehicles_r2710 v ON v.id = m.vehicle_id
  WHERE m.approval_status = 'pending'
  ORDER BY m.service_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_pending_approvals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_pending_approvals() TO authenticated;

DROP FUNCTION IF EXISTS r2710_compliance_alerts();
CREATE OR REPLACE FUNCTION r2710_compliance_alerts()
RETURNS TABLE (
  vehicle_reg_no text,
  engineer_name text,
  insurance_expiry date,
  fitness_expiry date,
  days_to_insurance int,
  days_to_fitness int,
  alert_level text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.vehicle_reg_no, v.engineer_name, v.insurance_expiry, v.fitness_expiry,
         (v.insurance_expiry - current_date)::int,
         (v.fitness_expiry - current_date)::int,
         CASE
           WHEN v.insurance_expiry <= current_date + 30 OR v.fitness_expiry <= current_date + 30 THEN 'red'
           WHEN v.insurance_expiry <= current_date + 60 OR v.fitness_expiry <= current_date + 60 THEN 'amber'
           ELSE 'green'
         END::text
  FROM engineer_vehicles_r2710 v
  ORDER BY LEAST(v.insurance_expiry, v.fitness_expiry) ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2710_compliance_alerts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2710_compliance_alerts() TO authenticated;

COMMIT;
