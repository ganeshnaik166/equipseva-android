-- Round r2919: Hospital Chain Quarterly OR Surgical Smoke Evacuation Compliance
-- HEAVY founder ops round

CREATE TABLE IF NOT EXISTS or_smoke_evacuation_audits_r2919 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_code text NOT NULL,
  city text NOT NULL,
  or_room_label text NOT NULL,
  audit_quarter text NOT NULL,
  audit_date date NOT NULL,
  evacuator_model text NOT NULL,
  filter_hours_used numeric(8,1) NOT NULL,
  filter_life_hours numeric(8,1) NOT NULL,
  capture_velocity_fpm numeric(6,2) NOT NULL,
  decibel_level numeric(5,2) NOT NULL,
  surgeon_compliance_pct numeric(5,2) NOT NULL,
  pass_status text NOT NULL CHECK (pass_status IN ('pass','marginal','fail')),
  remediation_due_days int NOT NULL DEFAULT 0,
  fine_exposure_rupees numeric(12,2) NOT NULL DEFAULT 0
);
ALTER TABLE or_smoke_evacuation_audits_r2919 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS or_smoke_remediation_actions_r2919 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_code text NOT NULL,
  or_room_label text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('filter_swap','calibration','training','hardware_replace','policy_update')),
  opened_at timestamptz NOT NULL,
  closed_at timestamptz,
  owner_engineer_email text NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','closed','blocked')),
  cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  notes text
);
ALTER TABLE or_smoke_remediation_actions_r2919 ENABLE ROW LEVEL SECURITY;

-- Seed audits
INSERT INTO or_smoke_evacuation_audits_r2919 (chain_name, hospital_code, city, or_room_label, audit_quarter, audit_date, evacuator_model, filter_hours_used, filter_life_hours, capture_velocity_fpm, decibel_level, surgeon_compliance_pct, pass_status, remediation_due_days, fine_exposure_rupees) VALUES
('Apollo','APL-HYD-01','Hyderabad','OR-1','Q2-2026','2026-05-12'::date,'Buffalo PlumeSafe',120.5,150.0,105.2,62.3,92.5,'pass',0,0),
('Apollo','APL-HYD-01','Hyderabad','OR-2','Q2-2026','2026-05-12'::date,'Buffalo PlumeSafe',148.0,150.0,82.4,68.1,78.0,'marginal',14,25000),
('Apollo','APL-CHN-02','Chennai','OR-1','Q2-2026','2026-05-14'::date,'Stryker NEPTUNE',160.0,150.0,70.0,72.5,65.0,'fail',7,150000),
('Fortis','FOR-DEL-01','Delhi','OR-3','Q2-2026','2026-05-15'::date,'ConMed AER',95.0,200.0,110.0,58.0,95.0,'pass',0,0),
('Fortis','FOR-MUM-02','Mumbai','OR-1','Q2-2026','2026-05-16'::date,'ConMed AER',180.0,200.0,75.0,65.5,72.0,'marginal',21,50000),
('Manipal','MAN-BLR-01','Bangalore','OR-2','Q2-2026','2026-05-17'::date,'Buffalo PlumeSafe',60.0,150.0,115.5,60.2,98.0,'pass',0,0),
('Manipal','MAN-BLR-03','Bangalore','OR-5','Q2-2026','2026-05-17'::date,'Olympus SES',200.0,180.0,68.0,74.0,55.0,'fail',5,200000),
('Max','MAX-DEL-04','Delhi','OR-1','Q2-2026','2026-05-18'::date,'ConMed AER',88.0,200.0,108.0,61.5,90.0,'pass',0,0),
('Max','MAX-DEL-04','Delhi','OR-4','Q2-2026','2026-05-18'::date,'ConMed AER',155.0,200.0,80.0,67.0,76.5,'marginal',14,30000),
('Narayana','NAR-BLR-02','Bangalore','OR-1','Q2-2026','2026-05-19'::date,'Buffalo PlumeSafe',75.0,150.0,112.0,59.5,94.0,'pass',0,0),
('Narayana','NAR-BLR-02','Bangalore','OR-3','Q2-2026','2026-05-19'::date,'Buffalo PlumeSafe',142.0,150.0,85.0,66.0,80.0,'marginal',10,20000),
('Medanta','MED-GUR-01','Gurgaon','OR-2','Q2-2026','2026-05-20'::date,'Stryker NEPTUNE',110.0,150.0,98.0,63.0,88.0,'pass',0,0),
('Medanta','MED-GUR-01','Gurgaon','OR-6','Q2-2026','2026-05-20'::date,'Stryker NEPTUNE',175.0,150.0,72.0,71.0,60.0,'fail',7,180000),
('AIIMS','AII-DEL-01','Delhi','OR-1','Q2-2026','2026-05-21'::date,'ConMed AER',55.0,200.0,118.0,58.5,97.0,'pass',0,0),
('AIIMS','AII-DEL-01','Delhi','OR-7','Q2-2026','2026-05-21'::date,'ConMed AER',165.0,200.0,77.0,68.0,74.0,'marginal',14,45000),
('KIMS','KIM-HYD-02','Hyderabad','OR-2','Q2-2026','2026-05-22'::date,'Buffalo PlumeSafe',195.0,150.0,65.0,73.5,58.0,'fail',5,175000),
('CARE','CAR-HYD-03','Hyderabad','OR-1','Q2-2026','2026-05-23'::date,'Olympus SES',82.0,180.0,107.0,60.0,91.0,'pass',0,0),
('Yashoda','YAS-HYD-04','Hyderabad','OR-3','Q2-2026','2026-05-24'::date,'Buffalo PlumeSafe',128.0,150.0,90.0,64.5,84.0,'pass',0,0),
('Rainbow','RNB-HYD-05','Hyderabad','OR-1','Q2-2026','2026-05-25'::date,'ConMed AER',100.0,200.0,102.0,62.0,89.5,'pass',0,0),
('Continental','CON-HYD-06','Hyderabad','OR-2','Q2-2026','2026-05-26'::date,'Stryker NEPTUNE',158.0,150.0,78.0,69.0,71.0,'marginal',14,40000);

-- Seed remediation
INSERT INTO or_smoke_remediation_actions_r2919 (chain_name, hospital_code, or_room_label, action_type, opened_at, closed_at, owner_engineer_email, status, cost_rupees, severity, notes) VALUES
('Apollo','APL-HYD-01','OR-2','filter_swap','2026-05-13 09:00:00+05:30'::timestamptz,'2026-05-14 11:00:00+05:30'::timestamptz,'eng1@equipseva.in','closed',8500,'p2','HEPA cartridge swap'),
('Apollo','APL-CHN-02','OR-1','hardware_replace','2026-05-14 14:00:00+05:30'::timestamptz,NULL,'eng2@equipseva.in','in_progress',125000,'p1','Pump head failure'),
('Fortis','FOR-MUM-02','OR-1','calibration','2026-05-16 10:00:00+05:30'::timestamptz,'2026-05-17 12:00:00+05:30'::timestamptz,'eng3@equipseva.in','closed',5500,'p2','Velocity probe recalibrated'),
('Manipal','MAN-BLR-03','OR-5','hardware_replace','2026-05-17 11:00:00+05:30'::timestamptz,NULL,'eng4@equipseva.in','blocked',180000,'p0','Awaiting OEM part'),
('Max','MAX-DEL-04','OR-4','training','2026-05-18 13:00:00+05:30'::timestamptz,'2026-05-20 16:00:00+05:30'::timestamptz,'eng5@equipseva.in','closed',12000,'p3','Surgeon refresher'),
('Narayana','NAR-BLR-02','OR-3','filter_swap','2026-05-19 09:30:00+05:30'::timestamptz,'2026-05-20 10:00:00+05:30'::timestamptz,'eng6@equipseva.in','closed',7800,'p2','Filter overdue'),
('Medanta','MED-GUR-01','OR-6','hardware_replace','2026-05-20 12:00:00+05:30'::timestamptz,NULL,'eng7@equipseva.in','open',165000,'p1','Replace evacuator unit'),
('AIIMS','AII-DEL-01','OR-7','calibration','2026-05-21 10:00:00+05:30'::timestamptz,'2026-05-22 13:00:00+05:30'::timestamptz,'eng8@equipseva.in','closed',6200,'p2','Acoustic dampener tuned'),
('KIMS','KIM-HYD-02','OR-2','hardware_replace','2026-05-22 14:00:00+05:30'::timestamptz,NULL,'eng9@equipseva.in','in_progress',155000,'p0','Motor + filter combo'),
('Continental','CON-HYD-06','OR-2','policy_update','2026-05-26 15:00:00+05:30'::timestamptz,NULL,'eng10@equipseva.in','open',2500,'p3','SOP doc revision'),
('Apollo','APL-HYD-01','OR-1','training','2026-05-12 16:00:00+05:30'::timestamptz,'2026-05-13 17:00:00+05:30'::timestamptz,'eng1@equipseva.in','closed',9000,'p3','Quarterly refresher'),
('Fortis','FOR-DEL-01','OR-3','filter_swap','2026-05-15 09:00:00+05:30'::timestamptz,'2026-05-15 11:00:00+05:30'::timestamptz,'eng3@equipseva.in','closed',8200,'p2','Preventive swap'),
('Manipal','MAN-BLR-01','OR-2','calibration','2026-05-17 10:00:00+05:30'::timestamptz,'2026-05-17 12:00:00+05:30'::timestamptz,'eng4@equipseva.in','closed',4800,'p3','Routine check'),
('Yashoda','YAS-HYD-04','OR-3','filter_swap','2026-05-24 11:00:00+05:30'::timestamptz,'2026-05-24 13:00:00+05:30'::timestamptz,'eng9@equipseva.in','closed',7200,'p2','Scheduled swap'),
('CARE','CAR-HYD-03','OR-1','training','2026-05-23 14:00:00+05:30'::timestamptz,NULL,'eng8@equipseva.in','open',11000,'p3','Plume safety refresh');

-- RPC 1: chain summary
CREATE OR REPLACE FUNCTION r2919_chain_summary()
RETURNS TABLE(chain_name text, audits int, pass_rate numeric, total_fine_exposure numeric, avg_compliance numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name,
         COUNT(*)::int,
         ROUND(100.0 * SUM(CASE WHEN a.pass_status='pass' THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2),
         SUM(a.fine_exposure_rupees),
         ROUND(AVG(a.surgeon_compliance_pct), 2)
  FROM or_smoke_evacuation_audits_r2919 a
  GROUP BY a.chain_name
  ORDER BY total_fine_exposure DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2919_chain_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_chain_summary() TO authenticated;

-- RPC 2: failing OR rooms
CREATE OR REPLACE FUNCTION r2919_failing_rooms()
RETURNS TABLE(id uuid, chain_name text, hospital_code text, or_room_label text, capture_velocity_fpm numeric, decibel_level numeric, fine_exposure_rupees numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_code, a.or_room_label, a.capture_velocity_fpm, a.decibel_level, a.fine_exposure_rupees
  FROM or_smoke_evacuation_audits_r2919 a
  WHERE a.pass_status = 'fail'
  ORDER BY a.fine_exposure_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2919_failing_rooms() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_failing_rooms() TO authenticated;

-- RPC 3: filter overdue
CREATE OR REPLACE FUNCTION r2919_filter_overdue()
RETURNS TABLE(id uuid, chain_name text, hospital_code text, or_room_label text, evacuator_model text, hours_over numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.hospital_code, a.or_room_label, a.evacuator_model, (a.filter_hours_used - a.filter_life_hours) AS hours_over
  FROM or_smoke_evacuation_audits_r2919 a
  WHERE a.filter_hours_used > a.filter_life_hours
  ORDER BY hours_over DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2919_filter_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_filter_overdue() TO authenticated;

-- RPC 4: open remediation
CREATE OR REPLACE FUNCTION r2919_open_remediation()
RETURNS TABLE(id uuid, chain_name text, hospital_code text, or_room_label text, action_type text, severity text, cost_rupees numeric, owner_engineer_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.chain_name, r.hospital_code, r.or_room_label, r.action_type, r.severity, r.cost_rupees, r.owner_engineer_email
  FROM or_smoke_remediation_actions_r2919 r
  WHERE r.status IN ('open','in_progress','blocked')
  ORDER BY r.severity, r.cost_rupees DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2919_open_remediation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_open_remediation() TO authenticated;

-- RPC 5: model fleet breakdown
CREATE OR REPLACE FUNCTION r2919_model_breakdown()
RETURNS TABLE(evacuator_model text, units int, avg_velocity numeric, avg_compliance numeric, fail_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.evacuator_model, COUNT(*)::int,
         ROUND(AVG(a.capture_velocity_fpm), 2),
         ROUND(AVG(a.surgeon_compliance_pct), 2),
         SUM(CASE WHEN a.pass_status='fail' THEN 1 ELSE 0 END)::int
  FROM or_smoke_evacuation_audits_r2919 a
  GROUP BY a.evacuator_model
  ORDER BY fail_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2919_model_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_model_breakdown() TO authenticated;

-- RPC 6: city heatmap
CREATE OR REPLACE FUNCTION r2919_city_heatmap()
RETURNS TABLE(city text, audits int, fails int, marginal int, total_exposure numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.city, COUNT(*)::int,
         SUM(CASE WHEN a.pass_status='fail' THEN 1 ELSE 0 END)::int,
         SUM(CASE WHEN a.pass_status='marginal' THEN 1 ELSE 0 END)::int,
         SUM(a.fine_exposure_rupees)
  FROM or_smoke_evacuation_audits_r2919 a
  GROUP BY a.city
  ORDER BY total_exposure DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2919_city_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_city_heatmap() TO authenticated;

-- RPC 7: engineer workload
CREATE OR REPLACE FUNCTION r2919_engineer_workload()
RETURNS TABLE(owner_engineer_email text, open_jobs int, closed_jobs int, total_cost numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.owner_engineer_email,
         SUM(CASE WHEN r.status IN ('open','in_progress','blocked') THEN 1 ELSE 0 END)::int,
         SUM(CASE WHEN r.status='closed' THEN 1 ELSE 0 END)::int,
         SUM(r.cost_rupees)
  FROM or_smoke_remediation_actions_r2919 r
  GROUP BY r.owner_engineer_email
  ORDER BY total_cost DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2919_engineer_workload() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_engineer_workload() TO authenticated;

-- RPC 8: KPI summary
CREATE OR REPLACE FUNCTION r2919_kpi_summary()
RETURNS TABLE(total_audits int, fail_count int, marginal_count int, pass_count int, total_fine_exposure numeric, open_actions int, total_remediation_cost numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT (SELECT COUNT(*)::int FROM or_smoke_evacuation_audits_r2919),
         (SELECT COUNT(*)::int FROM or_smoke_evacuation_audits_r2919 WHERE pass_status='fail'),
         (SELECT COUNT(*)::int FROM or_smoke_evacuation_audits_r2919 WHERE pass_status='marginal'),
         (SELECT COUNT(*)::int FROM or_smoke_evacuation_audits_r2919 WHERE pass_status='pass'),
         (SELECT COALESCE(SUM(fine_exposure_rupees),0) FROM or_smoke_evacuation_audits_r2919),
         (SELECT COUNT(*)::int FROM or_smoke_remediation_actions_r2919 WHERE status IN ('open','in_progress','blocked')),
         (SELECT COALESCE(SUM(cost_rupees),0) FROM or_smoke_remediation_actions_r2919);
END $$;
REVOKE EXECUTE ON FUNCTION r2919_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2919_kpi_summary() TO authenticated;
