BEGIN;

-- =====================================================================
-- Round 2712 — Customer Monthly Engineer Arrival Window Accuracy
-- Tables:
--   arrival_window_promises_r2712  (job × promised window × actual arrival × variance × cause)
--   arrival_window_refinements_r2712 (promise refinement rules + outcomes)
-- =====================================================================

CREATE TABLE IF NOT EXISTS arrival_window_promises_r2712 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_code text NOT NULL,
  customer_name text NOT NULL,
  engineer_name text NOT NULL,
  city text NOT NULL,
  promised_window_label text NOT NULL,
  promised_start_at timestamptz NOT NULL,
  promised_end_at timestamptz NOT NULL,
  actual_arrival_at timestamptz NOT NULL,
  variance_minutes integer NOT NULL,
  hit_window boolean NOT NULL,
  cause text NOT NULL CHECK (cause IN ('on_time','traffic','prior_job_overrun','customer_unreachable','address_mismatch','engineer_delay','parts_pickup')),
  csat_score integer NOT NULL CHECK (csat_score BETWEEN 1 AND 5),
  reported_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE arrival_window_promises_r2712 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON arrival_window_promises_r2712;
CREATE POLICY founder_all ON arrival_window_promises_r2712 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO arrival_window_promises_r2712
(job_code, customer_name, engineer_name, city, promised_window_label, promised_start_at, promised_end_at, actual_arrival_at, variance_minutes, hit_window, cause, csat_score, reported_on) VALUES
('RJ-22001','Apollo Hyderguda','Ravi K','Hyderabad','10:00-11:00','2026-06-21 10:00+05:30'::timestamptz,'2026-06-21 11:00+05:30'::timestamptz,'2026-06-21 10:18+05:30'::timestamptz,18,true,'on_time',5,'2026-06-21'::date),
('RJ-22002','KIMS Secunderabad','Lakshmi P','Hyderabad','11:30-12:30','2026-06-21 11:30+05:30'::timestamptz,'2026-06-21 12:30+05:30'::timestamptz,'2026-06-21 12:54+05:30'::timestamptz,24,false,'traffic',3,'2026-06-21'::date),
('RJ-22003','Care Banjara','Sanjay D','Hyderabad','14:00-15:00','2026-06-21 14:00+05:30'::timestamptz,'2026-06-21 15:00+05:30'::timestamptz,'2026-06-21 15:48+05:30'::timestamptz,48,false,'prior_job_overrun',2,'2026-06-21'::date),
('RJ-22004','Yashoda Somajiguda','Ravi K','Hyderabad','09:00-10:00','2026-06-21 09:00+05:30'::timestamptz,'2026-06-21 10:00+05:30'::timestamptz,'2026-06-21 09:42+05:30'::timestamptz,0,true,'on_time',5,'2026-06-21'::date),
('RJ-22005','Continental Gachibowli','Meena R','Hyderabad','16:00-17:00','2026-06-21 16:00+05:30'::timestamptz,'2026-06-21 17:00+05:30'::timestamptz,'2026-06-21 17:32+05:30'::timestamptz,32,false,'parts_pickup',3,'2026-06-21'::date),
('RJ-22006','Sunshine Begumpet','Suresh M','Hyderabad','10:00-11:00','2026-06-20 10:00+05:30'::timestamptz,'2026-06-20 11:00+05:30'::timestamptz,'2026-06-20 10:55+05:30'::timestamptz,0,true,'on_time',4,'2026-06-20'::date),
('RJ-22007','Rainbow Vikrampuri','Sanjay D','Hyderabad','13:00-14:00','2026-06-20 13:00+05:30'::timestamptz,'2026-06-20 14:00+05:30'::timestamptz,'2026-06-20 14:22+05:30'::timestamptz,22,false,'address_mismatch',3,'2026-06-20'::date);

-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS arrival_window_refinements_r2712 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_code text NOT NULL UNIQUE,
  rule_label text NOT NULL,
  applies_to_window text NOT NULL,
  buffer_minutes_added integer NOT NULL,
  hit_rate_before numeric(5,2) NOT NULL,
  hit_rate_after numeric(5,2) NOT NULL,
  csat_lift numeric(5,2) NOT NULL,
  status text NOT NULL CHECK (status IN ('proposed','piloting','adopted','rejected')),
  effective_from date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE arrival_window_refinements_r2712 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON arrival_window_refinements_r2712;
CREATE POLICY founder_all ON arrival_window_refinements_r2712 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO arrival_window_refinements_r2712
(rule_code, rule_label, applies_to_window, buffer_minutes_added, hit_rate_before, hit_rate_after, csat_lift, status, effective_from) VALUES
('AWR-01','Add 15min buffer to 14:00-15:00 (post-lunch traffic)','14:00-15:00',15,52.00,81.00,0.70,'adopted','2026-06-15'::date),
('AWR-02','Split 11:30-12:30 into two 45min slots','11:30-12:30',0,60.00,78.00,0.55,'piloting','2026-06-18'::date),
('AWR-03','Pre-call customer 30min before 10:00-11:00 slot','10:00-11:00',0,84.00,92.00,0.30,'adopted','2026-06-10'::date),
('AWR-04','Block parts pickup before 16:00-17:00 slot','16:00-17:00',20,55.00,73.00,0.40,'piloting','2026-06-19'::date),
('AWR-05','Auto-decline 3rd same-day job after 13:00','13:00-14:00',0,58.00,82.00,0.65,'proposed','2026-06-22'::date),
('AWR-06','Geo-verify address night before for outer-zone','09:00-10:00',0,79.00,88.00,0.25,'adopted','2026-06-12'::date);

-- =====================================================================
-- RPCs (7)
-- =====================================================================

DROP FUNCTION IF EXISTS founder_r2712_window_hit_rate();
CREATE OR REPLACE FUNCTION founder_r2712_window_hit_rate()
RETURNS TABLE(total_jobs bigint, hits bigint, misses bigint, hit_rate numeric, avg_variance_min numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint,
         count(*) FILTER (WHERE hit_window)::bigint,
         count(*) FILTER (WHERE NOT hit_window)::bigint,
         ROUND(100.0 * count(*) FILTER (WHERE hit_window)::numeric / NULLIF(count(*),0), 2),
         ROUND(AVG(variance_minutes)::numeric, 2)
  FROM arrival_window_promises_r2712;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2712_window_hit_rate() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2712_window_hit_rate() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2712_cause_breakdown();
CREATE OR REPLACE FUNCTION founder_r2712_cause_breakdown()
RETURNS TABLE(cause text, miss_count bigint, avg_variance_min numeric, avg_csat numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.cause, count(*)::bigint,
         ROUND(AVG(p.variance_minutes)::numeric,2),
         ROUND(AVG(p.csat_score)::numeric,2)
  FROM arrival_window_promises_r2712 p
  WHERE NOT p.hit_window
  GROUP BY p.cause
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2712_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2712_cause_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2712_promises_recent();
CREATE OR REPLACE FUNCTION founder_r2712_promises_recent()
RETURNS TABLE(job_code text, customer_name text, engineer_name text, promised_window_label text, variance_minutes integer, hit_window boolean, cause text, csat_score integer, reported_on date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.job_code, p.customer_name, p.engineer_name, p.promised_window_label, p.variance_minutes, p.hit_window, p.cause, p.csat_score, p.reported_on
  FROM arrival_window_promises_r2712 p
  ORDER BY p.reported_on DESC, p.promised_start_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2712_promises_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2712_promises_recent() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2712_window_label_perf();
CREATE OR REPLACE FUNCTION founder_r2712_window_label_perf()
RETURNS TABLE(promised_window_label text, jobs bigint, hit_rate numeric, avg_variance numeric, avg_csat numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.promised_window_label, count(*)::bigint,
         ROUND(100.0 * count(*) FILTER (WHERE p.hit_window)::numeric / NULLIF(count(*),0),2),
         ROUND(AVG(p.variance_minutes)::numeric,2),
         ROUND(AVG(p.csat_score)::numeric,2)
  FROM arrival_window_promises_r2712 p
  GROUP BY p.promised_window_label
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2712_window_label_perf() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2712_window_label_perf() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2712_engineer_punctuality();
CREATE OR REPLACE FUNCTION founder_r2712_engineer_punctuality()
RETURNS TABLE(engineer_name text, jobs bigint, hits bigint, hit_rate numeric, avg_variance numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.engineer_name, count(*)::bigint,
         count(*) FILTER (WHERE p.hit_window)::bigint,
         ROUND(100.0 * count(*) FILTER (WHERE p.hit_window)::numeric / NULLIF(count(*),0),2),
         ROUND(AVG(p.variance_minutes)::numeric,2)
  FROM arrival_window_promises_r2712 p
  GROUP BY p.engineer_name
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2712_engineer_punctuality() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2712_engineer_punctuality() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2712_refinements_active();
CREATE OR REPLACE FUNCTION founder_r2712_refinements_active()
RETURNS TABLE(rule_code text, rule_label text, applies_to_window text, buffer_minutes_added integer, hit_rate_before numeric, hit_rate_after numeric, csat_lift numeric, status text, effective_from date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.rule_code, r.rule_label, r.applies_to_window, r.buffer_minutes_added, r.hit_rate_before, r.hit_rate_after, r.csat_lift, r.status, r.effective_from
  FROM arrival_window_refinements_r2712 r
  ORDER BY r.effective_from DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2712_refinements_active() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2712_refinements_active() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2712_refinement_summary();
CREATE OR REPLACE FUNCTION founder_r2712_refinement_summary()
RETURNS TABLE(total_rules bigint, adopted bigint, piloting bigint, proposed bigint, avg_lift_pct numeric, avg_csat_lift numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint,
         count(*) FILTER (WHERE status='adopted')::bigint,
         count(*) FILTER (WHERE status='piloting')::bigint,
         count(*) FILTER (WHERE status='proposed')::bigint,
         ROUND(AVG(hit_rate_after - hit_rate_before)::numeric,2),
         ROUND(AVG(csat_lift)::numeric,2)
  FROM arrival_window_refinements_r2712;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2712_refinement_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2712_refinement_summary() TO authenticated;

COMMIT;
