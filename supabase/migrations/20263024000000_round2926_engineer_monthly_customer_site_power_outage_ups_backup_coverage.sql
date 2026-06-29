-- Round r2926 — Engineer Monthly Customer-Site Power-Outage UPS Backup Tested Coverage
-- 2 tables (_r2926) + 7 RPCs gated by is_founder()

BEGIN;

-- =========================
-- Table 1: ups_backup_tests_r2926
-- =========================
CREATE TABLE IF NOT EXISTS public.ups_backup_tests_r2926 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_id uuid,
  hospital_org_id uuid,
  site_code text NOT NULL,
  site_name text NOT NULL,
  city text NOT NULL,
  test_month date NOT NULL,
  tested_at timestamptz NOT NULL,
  ups_model text NOT NULL,
  rated_capacity_kva numeric(8,2) NOT NULL,
  measured_backup_minutes integer NOT NULL,
  required_backup_minutes integer NOT NULL DEFAULT 30,
  battery_health_pct numeric(5,2) NOT NULL,
  load_pct numeric(5,2) NOT NULL,
  test_result text NOT NULL CHECK (test_result IN ('pass','fail','marginal','skipped')),
  notes text
);
ALTER TABLE public.ups_backup_tests_r2926 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.ups_backup_tests_r2926
  (site_code, site_name, city, test_month, tested_at, ups_model, rated_capacity_kva, measured_backup_minutes, required_backup_minutes, battery_health_pct, load_pct, test_result, notes)
VALUES
  ('HYD-APO-01','Apollo Jubilee Hills','Hyderabad','2026-06-01'::date,'2026-06-03 10:15:00+05:30'::timestamptz,'APC Smart-UPS 10kVA',10.0,42,30,92.5,55.0,'pass','Routine monthly'),
  ('HYD-KIM-02','KIMS Secunderabad','Hyderabad','2026-06-01'::date,'2026-06-04 11:00:00+05:30'::timestamptz,'Eaton 9PX 8kVA',8.0,28,30,78.0,62.5,'marginal','Battery aging'),
  ('BLR-MAN-01','Manipal Old Airport','Bangalore','2026-06-01'::date,'2026-06-05 09:30:00+05:30'::timestamptz,'Vertiv Liebert 15kVA',15.0,55,30,95.0,48.0,'pass','New batteries Q1'),
  ('BLR-FOR-03','Fortis Bannerghatta','Bangalore','2026-06-01'::date,'2026-06-06 14:20:00+05:30'::timestamptz,'APC Smart-UPS 6kVA',6.0,18,30,65.0,72.0,'fail','Replace battery bank'),
  ('CHN-APO-02','Apollo Greams Road','Chennai','2026-06-01'::date,'2026-06-07 10:45:00+05:30'::timestamptz,'Eaton 9PX 10kVA',10.0,38,30,88.0,52.0,'pass',null),
  ('MUM-LIL-01','Lilavati Bandra','Mumbai','2026-06-01'::date,'2026-06-08 16:10:00+05:30'::timestamptz,'Vertiv Liebert 20kVA',20.0,65,30,94.0,45.0,'pass','Excellent'),
  ('MUM-HIN-04','Hinduja Mahim','Mumbai','2026-06-01'::date,'2026-06-09 11:30:00+05:30'::timestamptz,'APC Smart-UPS 8kVA',8.0,22,30,70.0,68.0,'marginal','Schedule replacement'),
  ('DEL-AII-01','AIIMS Ansari Nagar','Delhi','2026-06-01'::date,'2026-06-10 09:00:00+05:30'::timestamptz,'Eaton 9PX 12kVA',12.0,48,30,91.0,50.0,'pass',null),
  ('DEL-MAX-02','Max Saket','Delhi','2026-06-01'::date,'2026-06-11 13:15:00+05:30'::timestamptz,'Vertiv Liebert 10kVA',10.0,15,30,55.0,80.0,'fail','Critical - replace'),
  ('KOL-AMR-01','AMRI Dhakuria','Kolkata','2026-06-01'::date,'2026-06-12 10:30:00+05:30'::timestamptz,'APC Smart-UPS 6kVA',6.0,32,30,85.0,58.0,'pass',null),
  ('PUN-RUB-01','Ruby Hall Pune','Pune','2026-06-01'::date,'2026-06-13 14:45:00+05:30'::timestamptz,'Eaton 9PX 8kVA',8.0,40,30,90.0,53.0,'pass','Good'),
  ('AHM-STG-01','Sterling Ahmedabad','Ahmedabad','2026-06-01'::date,'2026-06-14 11:20:00+05:30'::timestamptz,'Vertiv Liebert 15kVA',15.0,52,30,93.0,47.0,'pass',null),
  ('HYD-CON-03','Continental Gachibowli','Hyderabad','2026-06-01'::date,'2026-06-15 10:00:00+05:30'::timestamptz,'APC Smart-UPS 10kVA',10.0,0,30,30.0,0.0,'skipped','Site access denied'),
  ('BLR-NAR-02','Narayana Health City','Bangalore','2026-06-01'::date,'2026-06-16 09:45:00+05:30'::timestamptz,'Eaton 9PX 20kVA',20.0,70,30,96.0,42.0,'pass','Brand new install'),
  ('CHN-MIO-01','MIOT International','Chennai','2026-06-01'::date,'2026-06-17 15:30:00+05:30'::timestamptz,'Vertiv Liebert 12kVA',12.0,36,30,86.0,55.0,'pass',null),
  ('MUM-KOK-02','Kokilaben Mumbai','Mumbai','2026-06-01'::date,'2026-06-18 12:00:00+05:30'::timestamptz,'APC Smart-UPS 15kVA',15.0,45,30,89.0,50.0,'pass',null),
  ('DEL-FOR-04','Fortis Vasant Kunj','Delhi','2026-06-01'::date,'2026-06-19 11:15:00+05:30'::timestamptz,'Eaton 9PX 10kVA',10.0,25,30,72.0,65.0,'marginal','Watch list'),
  ('PUN-JEH-02','Jehangir Pune','Pune','2026-06-01'::date,'2026-06-20 14:00:00+05:30'::timestamptz,'Vertiv Liebert 8kVA',8.0,33,30,83.0,57.0,'pass',null);

-- =========================
-- Table 2: ups_backup_coverage_targets_r2926
-- =========================
CREATE TABLE IF NOT EXISTS public.ups_backup_coverage_targets_r2926 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  city text NOT NULL,
  month date NOT NULL,
  target_sites integer NOT NULL,
  required_pass_pct numeric(5,2) NOT NULL DEFAULT 85.0,
  sla_minutes integer NOT NULL DEFAULT 30,
  owner text NOT NULL,
  notes text
);
ALTER TABLE public.ups_backup_coverage_targets_r2926 ENABLE ROW LEVEL SECURITY;

INSERT INTO public.ups_backup_coverage_targets_r2926
  (city, month, target_sites, required_pass_pct, sla_minutes, owner, notes)
VALUES
  ('Hyderabad','2026-06-01'::date,8,85.0,30,'Ravi Kumar','South 1 cluster'),
  ('Bangalore','2026-06-01'::date,10,85.0,30,'Priya Sharma','South 2'),
  ('Chennai','2026-06-01'::date,7,85.0,30,'Arjun Iyer','South 3'),
  ('Mumbai','2026-06-01'::date,12,90.0,45,'Neha Patel','West 1 - tier1'),
  ('Delhi','2026-06-01'::date,11,90.0,45,'Vikram Singh','North 1 - tier1'),
  ('Kolkata','2026-06-01'::date,5,85.0,30,'Rohit Das','East 1'),
  ('Pune','2026-06-01'::date,6,85.0,30,'Snehal Kale','West 2'),
  ('Ahmedabad','2026-06-01'::date,4,85.0,30,'Mehul Shah','West 3'),
  ('Hyderabad','2026-05-01'::date,8,85.0,30,'Ravi Kumar','Prior month'),
  ('Bangalore','2026-05-01'::date,10,85.0,30,'Priya Sharma','Prior month'),
  ('Mumbai','2026-05-01'::date,12,90.0,45,'Neha Patel','Prior month'),
  ('Delhi','2026-05-01'::date,11,90.0,45,'Vikram Singh','Prior month'),
  ('Chennai','2026-05-01'::date,7,85.0,30,'Arjun Iyer','Prior month'),
  ('Pune','2026-05-01'::date,6,85.0,30,'Snehal Kale','Prior month');

-- =========================
-- RPCs (7) — all SECURITY DEFINER + is_founder() gated
-- =========================

CREATE OR REPLACE FUNCTION public.r2926_ups_coverage_overview()
RETURNS TABLE(
  city text,
  month date,
  target_sites integer,
  tested_sites bigint,
  passed_sites bigint,
  pass_pct numeric,
  required_pass_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.city, t.month, t.target_sites,
    COUNT(u.id) FILTER (WHERE u.test_result <> 'skipped') AS tested,
    COUNT(u.id) FILTER (WHERE u.test_result = 'pass') AS passed,
    ROUND(100.0 * COUNT(u.id) FILTER (WHERE u.test_result = 'pass')
      / NULLIF(COUNT(u.id) FILTER (WHERE u.test_result <> 'skipped'),0), 2) AS pass_pct,
    t.required_pass_pct
  FROM public.ups_backup_coverage_targets_r2926 t
  LEFT JOIN public.ups_backup_tests_r2926 u
    ON u.city = t.city AND u.test_month = t.month
  GROUP BY t.city, t.month, t.target_sites, t.required_pass_pct
  ORDER BY t.month DESC, t.city;
END;$$;

CREATE OR REPLACE FUNCTION public.r2926_failed_sites_this_month()
RETURNS TABLE(
  site_code text, site_name text, city text, ups_model text,
  measured_backup_minutes integer, required_backup_minutes integer,
  battery_health_pct numeric, tested_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.site_code, u.site_name, u.city, u.ups_model,
    u.measured_backup_minutes, u.required_backup_minutes,
    u.battery_health_pct, u.tested_at
  FROM public.ups_backup_tests_r2926 u
  WHERE u.test_result = 'fail'
    AND u.test_month = (SELECT MAX(test_month) FROM public.ups_backup_tests_r2926)
  ORDER BY u.battery_health_pct ASC;
END;$$;

CREATE OR REPLACE FUNCTION public.r2926_marginal_watchlist()
RETURNS TABLE(
  site_code text, site_name text, city text,
  battery_health_pct numeric, load_pct numeric,
  measured_backup_minutes integer, notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.site_code, u.site_name, u.city,
    u.battery_health_pct, u.load_pct, u.measured_backup_minutes, u.notes
  FROM public.ups_backup_tests_r2926 u
  WHERE u.test_result = 'marginal'
  ORDER BY u.battery_health_pct ASC;
END;$$;

CREATE OR REPLACE FUNCTION public.r2926_battery_health_distribution()
RETURNS TABLE(bucket text, site_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN battery_health_pct >= 90 THEN '90-100 excellent'
      WHEN battery_health_pct >= 80 THEN '80-89 good'
      WHEN battery_health_pct >= 70 THEN '70-79 fair'
      WHEN battery_health_pct >= 60 THEN '60-69 weak'
      ELSE 'below 60 critical'
    END AS bucket,
    COUNT(*)
  FROM public.ups_backup_tests_r2926
  WHERE test_result <> 'skipped'
  GROUP BY 1
  ORDER BY 1;
END;$$;

CREATE OR REPLACE FUNCTION public.r2926_skipped_or_overdue()
RETURNS TABLE(site_code text, site_name text, city text, test_month date, test_result text, notes text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.site_code, u.site_name, u.city, u.test_month, u.test_result, u.notes
  FROM public.ups_backup_tests_r2926 u
  WHERE u.test_result = 'skipped'
  ORDER BY u.test_month DESC, u.city;
END;$$;

CREATE OR REPLACE FUNCTION public.r2926_city_sla_breach()
RETURNS TABLE(city text, sla_minutes integer, tested bigint, breached bigint, breach_pct numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.city, t.sla_minutes,
    COUNT(u.id) FILTER (WHERE u.test_result <> 'skipped') AS tested,
    COUNT(u.id) FILTER (WHERE u.measured_backup_minutes < t.sla_minutes AND u.test_result <> 'skipped') AS breached,
    ROUND(100.0 * COUNT(u.id) FILTER (WHERE u.measured_backup_minutes < t.sla_minutes AND u.test_result <> 'skipped')
      / NULLIF(COUNT(u.id) FILTER (WHERE u.test_result <> 'skipped'),0), 2) AS breach_pct
  FROM public.ups_backup_coverage_targets_r2926 t
  LEFT JOIN public.ups_backup_tests_r2926 u
    ON u.city = t.city AND u.test_month = t.month
  WHERE t.month = (SELECT MAX(month) FROM public.ups_backup_coverage_targets_r2926)
  GROUP BY t.city, t.sla_minutes
  ORDER BY breach_pct DESC NULLS LAST;
END;$$;

CREATE OR REPLACE FUNCTION public.r2926_ups_model_reliability()
RETURNS TABLE(ups_model text, tests bigint, pass_count bigint, fail_count bigint, avg_backup_minutes numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.ups_model,
    COUNT(*) AS tests,
    COUNT(*) FILTER (WHERE u.test_result = 'pass') AS pass_count,
    COUNT(*) FILTER (WHERE u.test_result = 'fail') AS fail_count,
    ROUND(AVG(u.measured_backup_minutes)::numeric, 1) AS avg_backup_minutes
  FROM public.ups_backup_tests_r2926 u
  WHERE u.test_result <> 'skipped'
  GROUP BY u.ups_model
  ORDER BY pass_count DESC, tests DESC;
END;$$;

-- =========================
-- Permissions
-- =========================
REVOKE EXECUTE ON FUNCTION public.r2926_ups_coverage_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2926_failed_sites_this_month() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2926_marginal_watchlist() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2926_battery_health_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2926_skipped_or_overdue() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2926_city_sla_breach() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r2926_ups_model_reliability() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2926_ups_coverage_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2926_failed_sites_this_month() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2926_marginal_watchlist() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2926_battery_health_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2926_skipped_or_overdue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2926_city_sla_breach() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2926_ups_model_reliability() TO authenticated;

COMMIT;
