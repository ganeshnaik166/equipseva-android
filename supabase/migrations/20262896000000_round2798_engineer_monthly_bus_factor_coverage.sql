BEGIN;

-- ============================================================================
-- Round 2798: Engineer Monthly Bus-Factor Coverage
-- Engineer x specialty x backup count x city x bus-factor risk x cross-train action
-- ============================================================================

-- Tables ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineer_bus_factor_coverage_r2798 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  specialty text NOT NULL,
  city text NOT NULL,
  backup_engineer_count int NOT NULL CHECK (backup_engineer_count >= 0),
  active_jobs_30d int NOT NULL CHECK (active_jobs_30d >= 0),
  hospitals_served int NOT NULL CHECK (hospitals_served >= 0),
  bus_factor_risk text NOT NULL CHECK (bus_factor_risk IN ('critical','high','medium','low')),
  cross_train_action text NOT NULL,
  action_owner text NOT NULL,
  target_completion_date date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_bus_factor_coverage_r2798 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_bus_factor_coverage_r2798;
CREATE POLICY founder_all ON engineer_bus_factor_coverage_r2798
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_cross_train_plan_r2798 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  trainee_engineer_name text NOT NULL,
  specialty text NOT NULL,
  city text NOT NULL,
  training_hours_planned int NOT NULL CHECK (training_hours_planned >= 0),
  training_hours_completed int NOT NULL CHECK (training_hours_completed >= 0),
  certification_target text NOT NULL,
  plan_status text NOT NULL CHECK (plan_status IN ('planned','in_progress','blocked','completed','cancelled')),
  expected_completion_date date NOT NULL,
  cost_rupees int NOT NULL CHECK (cost_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_cross_train_plan_r2798 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_cross_train_plan_r2798;
CREATE POLICY founder_all ON engineer_cross_train_plan_r2798
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Seed data ------------------------------------------------------------------

INSERT INTO engineer_bus_factor_coverage_r2798
  (month_label, engineer_name, specialty, city, backup_engineer_count, active_jobs_30d, hospitals_served, bus_factor_risk, cross_train_action, action_owner, target_completion_date, notes)
VALUES
  ('2026-06','Ravi Kumar','Anesthesia Machines','Hyderabad',0,18,7,'critical','Pair-train Suresh on Drager Fabius','ops.lead','2026-07-15'::date,'Only certified engineer in city for Drager fleet'),
  ('2026-06','Anita Reddy','CT Scanners','Bengaluru',1,12,4,'high','Add second backup via vendor program','training.lead','2026-08-01'::date,'Single backup is on long leave'),
  ('2026-06','Vikram Singh','Dialysis Units','Chennai',2,22,9,'medium','Refresh Nipro training for backups','vendor.mgr','2026-07-30'::date,'Backups certified but rusty'),
  ('2026-06','Priya Sharma','Ventilators','Mumbai',3,28,11,'low','Maintain quarterly drills','ops.lead','2026-09-15'::date,'Strong bench coverage'),
  ('2026-06','Karthik Iyer','MRI Coils','Hyderabad',0,9,3,'critical','Emergency hire + Siemens cert path','founder','2026-07-10'::date,'Loss of engineer = SLA breach on 3 hospitals'),
  ('2026-06','Deepa Nair','Patient Monitors','Pune',2,31,12,'low','Steady state','ops.lead','2026-09-30'::date,'Commodity skill, deep bench'),
  ('2026-06','Sanjay Patel','C-Arms','Ahmedabad',1,14,5,'high','Sponsor Manish for Ziehm cert','training.lead','2026-08-20'::date,'Backup leaves in Q3');

INSERT INTO engineer_cross_train_plan_r2798
  (month_label, engineer_name, trainee_engineer_name, specialty, city, training_hours_planned, training_hours_completed, certification_target, plan_status, expected_completion_date, cost_rupees, notes)
VALUES
  ('2026-06','Ravi Kumar','Suresh Babu','Anesthesia Machines','Hyderabad',40,12,'Drager Fabius L2','in_progress','2026-07-15'::date,85000,'Vendor classroom + 3 shadow jobs'),
  ('2026-06','Anita Reddy','Mohan Das','CT Scanners','Bengaluru',60,0,'Siemens Somatom L1','planned','2026-08-01'::date,140000,'Awaiting vendor slot confirmation'),
  ('2026-06','Vikram Singh','Lakshmi Rao','Dialysis Units','Chennai',24,24,'Nipro refresher','completed','2026-06-18'::date,32000,'Cert renewed'),
  ('2026-06','Karthik Iyer','New Hire (TBD)','MRI Coils','Hyderabad',80,0,'Siemens MRI L2','blocked','2026-09-15'::date,260000,'Hire pending; founder approval needed'),
  ('2026-06','Sanjay Patel','Manish Bhatt','C-Arms','Ahmedabad',32,8,'Ziehm Vision L1','in_progress','2026-08-20'::date,72000,'Self-study + 1 vendor week'),
  ('2026-06','Priya Sharma','Rohit Verma','Ventilators','Mumbai',16,16,'Hamilton C1 drill','completed','2026-06-12'::date,18000,'Quarterly drill'),
  ('2026-06','Deepa Nair','Asha Kulkarni','Patient Monitors','Pune',12,4,'Mindray BeneVision','in_progress','2026-07-05'::date,15000,'Light upskill');

-- RPCs -----------------------------------------------------------------------

DROP FUNCTION IF EXISTS r2798_kpi_summary();
CREATE OR REPLACE FUNCTION r2798_kpi_summary()
RETURNS TABLE(
  total_engineers int,
  critical_risk_count int,
  high_risk_count int,
  zero_backup_count int,
  avg_backup_count numeric,
  total_active_jobs int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE bus_factor_risk='critical')::int,
    COUNT(*) FILTER (WHERE bus_factor_risk='high')::int,
    COUNT(*) FILTER (WHERE backup_engineer_count=0)::int,
    ROUND(AVG(backup_engineer_count)::numeric, 2),
    COALESCE(SUM(active_jobs_30d),0)::int
  FROM engineer_bus_factor_coverage_r2798;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_kpi_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2798_coverage_by_risk();
CREATE OR REPLACE FUNCTION r2798_coverage_by_risk()
RETURNS TABLE(bus_factor_risk text, engineer_count int, total_jobs int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.bus_factor_risk, COUNT(*)::int, COALESCE(SUM(c.active_jobs_30d),0)::int
  FROM engineer_bus_factor_coverage_r2798 c
  GROUP BY c.bus_factor_risk
  ORDER BY CASE c.bus_factor_risk
    WHEN 'critical' THEN 1 WHEN 'high' THEN 2
    WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_coverage_by_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_coverage_by_risk() TO authenticated;

DROP FUNCTION IF EXISTS r2798_coverage_by_city();
CREATE OR REPLACE FUNCTION r2798_coverage_by_city()
RETURNS TABLE(city text, engineer_count int, critical_count int, avg_backup numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.city, COUNT(*)::int,
    COUNT(*) FILTER (WHERE c.bus_factor_risk='critical')::int,
    ROUND(AVG(c.backup_engineer_count)::numeric,2)
  FROM engineer_bus_factor_coverage_r2798 c
  GROUP BY c.city
  ORDER BY COUNT(*) FILTER (WHERE c.bus_factor_risk='critical') DESC, c.city;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_coverage_by_city() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_coverage_by_city() TO authenticated;

DROP FUNCTION IF EXISTS r2798_coverage_by_specialty();
CREATE OR REPLACE FUNCTION r2798_coverage_by_specialty()
RETURNS TABLE(specialty text, engineer_count int, total_hospitals int, max_risk text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.specialty, COUNT(*)::int, COALESCE(SUM(c.hospitals_served),0)::int,
    MIN(CASE c.bus_factor_risk
      WHEN 'critical' THEN 'critical' WHEN 'high' THEN 'high'
      WHEN 'medium' THEN 'medium' ELSE 'low' END)
  FROM engineer_bus_factor_coverage_r2798 c
  GROUP BY c.specialty
  ORDER BY c.specialty;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_coverage_by_specialty() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_coverage_by_specialty() TO authenticated;

DROP FUNCTION IF EXISTS r2798_coverage_list();
CREATE OR REPLACE FUNCTION r2798_coverage_list()
RETURNS TABLE(
  id uuid, engineer_name text, specialty text, city text,
  backup_engineer_count int, active_jobs_30d int, hospitals_served int,
  bus_factor_risk text, cross_train_action text, action_owner text,
  target_completion_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_name, c.specialty, c.city,
    c.backup_engineer_count, c.active_jobs_30d, c.hospitals_served,
    c.bus_factor_risk, c.cross_train_action, c.action_owner, c.target_completion_date
  FROM engineer_bus_factor_coverage_r2798 c
  ORDER BY CASE c.bus_factor_risk
    WHEN 'critical' THEN 1 WHEN 'high' THEN 2
    WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END,
    c.active_jobs_30d DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_coverage_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_coverage_list() TO authenticated;

DROP FUNCTION IF EXISTS r2798_cross_train_summary();
CREATE OR REPLACE FUNCTION r2798_cross_train_summary()
RETURNS TABLE(
  total_plans int,
  planned_count int,
  in_progress_count int,
  blocked_count int,
  completed_count int,
  total_cost_rupees bigint,
  hours_planned_sum int,
  hours_completed_sum int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE plan_status='planned')::int,
    COUNT(*) FILTER (WHERE plan_status='in_progress')::int,
    COUNT(*) FILTER (WHERE plan_status='blocked')::int,
    COUNT(*) FILTER (WHERE plan_status='completed')::int,
    COALESCE(SUM(cost_rupees),0)::bigint,
    COALESCE(SUM(training_hours_planned),0)::int,
    COALESCE(SUM(training_hours_completed),0)::int
  FROM engineer_cross_train_plan_r2798;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_cross_train_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_cross_train_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2798_cross_train_list();
CREATE OR REPLACE FUNCTION r2798_cross_train_list()
RETURNS TABLE(
  id uuid, engineer_name text, trainee_engineer_name text, specialty text,
  city text, training_hours_planned int, training_hours_completed int,
  certification_target text, plan_status text, expected_completion_date date,
  cost_rupees int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.engineer_name, p.trainee_engineer_name, p.specialty,
    p.city, p.training_hours_planned, p.training_hours_completed,
    p.certification_target, p.plan_status, p.expected_completion_date, p.cost_rupees
  FROM engineer_cross_train_plan_r2798 p
  ORDER BY CASE p.plan_status
    WHEN 'blocked' THEN 1 WHEN 'planned' THEN 2
    WHEN 'in_progress' THEN 3 WHEN 'completed' THEN 4
    WHEN 'cancelled' THEN 5 END,
    p.expected_completion_date;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_cross_train_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_cross_train_list() TO authenticated;

DROP FUNCTION IF EXISTS r2798_critical_engineers();
CREATE OR REPLACE FUNCTION r2798_critical_engineers()
RETURNS TABLE(
  engineer_name text, specialty text, city text,
  active_jobs_30d int, hospitals_served int, cross_train_action text,
  action_owner text, target_completion_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_name, c.specialty, c.city,
    c.active_jobs_30d, c.hospitals_served, c.cross_train_action,
    c.action_owner, c.target_completion_date
  FROM engineer_bus_factor_coverage_r2798 c
  WHERE c.bus_factor_risk IN ('critical','high')
  ORDER BY CASE c.bus_factor_risk WHEN 'critical' THEN 1 ELSE 2 END,
    c.active_jobs_30d DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2798_critical_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2798_critical_engineers() TO authenticated;

COMMIT;
