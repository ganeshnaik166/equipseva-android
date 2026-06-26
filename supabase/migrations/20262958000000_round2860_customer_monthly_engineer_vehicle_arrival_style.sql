BEGIN;

-- Round 2860: Customer monthly engineer vehicle arrival style tracker
-- Captures per-job vehicle arrival impression: vehicle kind, cleanliness,
-- parking discipline, customer impression score, and verdict.

CREATE TABLE IF NOT EXISTS engineer_vehicle_arrival_style_r2860 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_code text NOT NULL,
  engineer_name text NOT NULL,
  customer_org text NOT NULL,
  visit_month text NOT NULL,
  visit_date date NOT NULL,
  vehicle_kind text NOT NULL CHECK (vehicle_kind IN ('two_wheeler','three_wheeler','hatchback','sedan','suv','tempo_van')),
  vehicle_clean_score int NOT NULL CHECK (vehicle_clean_score BETWEEN 0 AND 10),
  parked_correctly boolean NOT NULL,
  customer_impression_score int NOT NULL CHECK (customer_impression_score BETWEEN 0 AND 10),
  verdict text NOT NULL CHECK (verdict IN ('exemplary','acceptable','warn','coach','reassign')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_vehicle_arrival_style_r2860 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_vehicle_arrival_style_r2860;
CREATE POLICY founder_all ON engineer_vehicle_arrival_style_r2860 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_vehicle_arrival_monthly_summary_r2860 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  visit_month text NOT NULL,
  total_visits int NOT NULL DEFAULT 0,
  avg_clean_score numeric(4,2) NOT NULL DEFAULT 0,
  avg_impression_score numeric(4,2) NOT NULL DEFAULT 0,
  parked_correct_pct numeric(5,2) NOT NULL DEFAULT 0,
  exemplary_count int NOT NULL DEFAULT 0,
  warn_count int NOT NULL DEFAULT 0,
  coach_required boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_vehicle_arrival_monthly_summary_r2860 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_vehicle_arrival_monthly_summary_r2860;
CREATE POLICY founder_all ON engineer_vehicle_arrival_monthly_summary_r2860 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds: arrival style observations
INSERT INTO engineer_vehicle_arrival_style_r2860 (job_code, engineer_name, customer_org, visit_month, visit_date, vehicle_kind, vehicle_clean_score, parked_correctly, customer_impression_score, verdict, notes) VALUES
  ('JOB-7710', 'Ravi Kumar',     'Apollo Spectra Tarnaka',   '2026-06', '2026-06-03'::date, 'hatchback',    9, true,  9, 'exemplary',  'Stickers aligned, uniform crisp'),
  ('JOB-7711', 'Sneha Reddy',    'KIMS Secunderabad',        '2026-06', '2026-06-05'::date, 'two_wheeler',  6, true,  7, 'acceptable', 'Helmet on, mild dust on panniers'),
  ('JOB-7712', 'Imran Pasha',    'Yashoda Somajiguda',       '2026-06', '2026-06-07'::date, 'sedan',        4, false, 5, 'warn',       'Parked on hospital ramp, dusty bonnet'),
  ('JOB-7713', 'Naveen Goud',    'AIG Gachibowli',           '2026-06', '2026-06-09'::date, 'suv',          3, false, 4, 'coach',      'Reception flagged loud engine idle'),
  ('JOB-7714', 'Priya Sharma',   'Care Banjara',             '2026-06', '2026-06-11'::date, 'tempo_van',    8, true,  8, 'exemplary',  'Toolbox roped down properly'),
  ('JOB-7715', 'Karthik Naidu',  'Continental Hospitals',    '2026-06', '2026-06-13'::date, 'three_wheeler',7, true,  7, 'acceptable', 'Auto branded, neat'),
  ('JOB-7716', 'Vivek Anand',    'Rainbow Hyderguda',        '2026-06', '2026-06-15'::date, 'hatchback',    2, false, 3, 'reassign',   'Engineer arrived without uniform');

INSERT INTO engineer_vehicle_arrival_monthly_summary_r2860 (engineer_name, visit_month, total_visits, avg_clean_score, avg_impression_score, parked_correct_pct, exemplary_count, warn_count, coach_required) VALUES
  ('Ravi Kumar',    '2026-06', 14, 8.80, 8.90, 96.00, 11, 0, false),
  ('Sneha Reddy',   '2026-06', 12, 6.40, 7.10, 80.00, 3,  1, false),
  ('Imran Pasha',   '2026-06', 10, 4.20, 5.10, 50.00, 0,  4, true),
  ('Naveen Goud',   '2026-06', 9,  3.50, 4.40, 33.00, 0,  5, true),
  ('Priya Sharma',  '2026-06', 13, 8.10, 8.20, 92.00, 9,  0, false),
  ('Karthik Naidu', '2026-06', 11, 7.20, 7.40, 88.00, 4,  1, false),
  ('Vivek Anand',   '2026-06', 8,  2.80, 3.20, 25.00, 0,  6, true);

-- RPCs

DROP FUNCTION IF EXISTS founder_vas_r2860_kpis();
CREATE OR REPLACE FUNCTION founder_vas_r2860_kpis()
RETURNS TABLE(total_visits bigint, avg_clean numeric, avg_impression numeric, exemplary bigint, coach_req bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint,
           ROUND(AVG(vehicle_clean_score)::numeric, 2),
           ROUND(AVG(customer_impression_score)::numeric, 2),
           COUNT(*) FILTER (WHERE verdict = 'exemplary')::bigint,
           COUNT(*) FILTER (WHERE verdict IN ('coach','reassign'))::bigint
    FROM engineer_vehicle_arrival_style_r2860;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_vas_r2860_recent_visits();
CREATE OR REPLACE FUNCTION founder_vas_r2860_recent_visits()
RETURNS SETOF engineer_vehicle_arrival_style_r2860
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM engineer_vehicle_arrival_style_r2860
    ORDER BY visit_date DESC, created_at DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_recent_visits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_recent_visits() TO authenticated;

DROP FUNCTION IF EXISTS founder_vas_r2860_monthly_summary();
CREATE OR REPLACE FUNCTION founder_vas_r2860_monthly_summary()
RETURNS SETOF engineer_vehicle_arrival_monthly_summary_r2860
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM engineer_vehicle_arrival_monthly_summary_r2860
    ORDER BY avg_impression_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_monthly_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_monthly_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_vas_r2860_by_vehicle_kind();
CREATE OR REPLACE FUNCTION founder_vas_r2860_by_vehicle_kind()
RETURNS TABLE(vehicle_kind text, visits bigint, avg_clean numeric, avg_impression numeric, parked_ok_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.vehicle_kind,
           COUNT(*)::bigint,
           ROUND(AVG(v.vehicle_clean_score)::numeric, 2),
           ROUND(AVG(v.customer_impression_score)::numeric, 2),
           ROUND((COUNT(*) FILTER (WHERE v.parked_correctly)::numeric * 100.0) / NULLIF(COUNT(*),0), 2)
    FROM engineer_vehicle_arrival_style_r2860 v
    GROUP BY v.vehicle_kind
    ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_by_vehicle_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_by_vehicle_kind() TO authenticated;

DROP FUNCTION IF EXISTS founder_vas_r2860_verdict_mix();
CREATE OR REPLACE FUNCTION founder_vas_r2860_verdict_mix()
RETURNS TABLE(verdict text, n bigint, pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total_n bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_n FROM engineer_vehicle_arrival_style_r2860;
  RETURN QUERY
    SELECT v.verdict,
           COUNT(*)::bigint,
           ROUND((COUNT(*)::numeric * 100.0) / NULLIF(total_n, 0), 2)
    FROM engineer_vehicle_arrival_style_r2860 v
    GROUP BY v.verdict
    ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_verdict_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_vas_r2860_coach_list();
CREATE OR REPLACE FUNCTION founder_vas_r2860_coach_list()
RETURNS TABLE(engineer_name text, total_visits int, avg_impression numeric, warn_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_name, s.total_visits, s.avg_impression_score, s.warn_count
    FROM engineer_vehicle_arrival_monthly_summary_r2860 s
    WHERE s.coach_required = true
    ORDER BY s.avg_impression_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_coach_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_coach_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_vas_r2860_top_arrivals();
CREATE OR REPLACE FUNCTION founder_vas_r2860_top_arrivals()
RETURNS TABLE(engineer_name text, avg_impression numeric, exemplary_count int, parked_correct_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_name, s.avg_impression_score, s.exemplary_count, s.parked_correct_pct
    FROM engineer_vehicle_arrival_monthly_summary_r2860 s
    ORDER BY s.avg_impression_score DESC, s.exemplary_count DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_top_arrivals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_top_arrivals() TO authenticated;

DROP FUNCTION IF EXISTS founder_vas_r2860_parking_audit();
CREATE OR REPLACE FUNCTION founder_vas_r2860_parking_audit()
RETURNS TABLE(job_code text, engineer_name text, customer_org text, vehicle_kind text, visit_date date, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.job_code, v.engineer_name, v.customer_org, v.vehicle_kind, v.visit_date, v.notes
    FROM engineer_vehicle_arrival_style_r2860 v
    WHERE v.parked_correctly = false
    ORDER BY v.visit_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vas_r2860_parking_audit() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vas_r2860_parking_audit() TO authenticated;

COMMIT;
