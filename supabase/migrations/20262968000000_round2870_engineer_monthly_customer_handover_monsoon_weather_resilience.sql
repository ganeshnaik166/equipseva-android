BEGIN;

-- ============================================================
-- Round 2870: Engineer Monthly Customer Handover Monsoon Weather Resilience
-- HEAVY ★★★★ — engineer × handover × weather × delay × preparedness × outcome × refine
-- ============================================================

-- TABLE 1: handover weather impact log
CREATE TABLE IF NOT EXISTS engineer_handover_monsoon_log_r2870 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_name text NOT NULL,
  engineer_code text NOT NULL,
  customer_org text NOT NULL,
  city text NOT NULL,
  handover_date date NOT NULL,
  weather_condition text NOT NULL CHECK (weather_condition IN ('clear','light_rain','heavy_rain','flooding','cyclone','thunderstorm')),
  rainfall_mm numeric(6,2) NOT NULL DEFAULT 0,
  scheduled_at timestamptz NOT NULL,
  arrived_at timestamptz,
  completed_at timestamptz,
  delay_minutes int NOT NULL DEFAULT 0,
  preparedness_score int NOT NULL CHECK (preparedness_score BETWEEN 0 AND 100),
  raincoat_kit_carried boolean NOT NULL DEFAULT false,
  waterproof_tools boolean NOT NULL DEFAULT false,
  backup_vehicle boolean NOT NULL DEFAULT false,
  outcome text NOT NULL CHECK (outcome IN ('on_time','minor_delay','major_delay','rescheduled','aborted')),
  customer_csat int CHECK (customer_csat BETWEEN 1 AND 5),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handover_monsoon_log_r2870 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON engineer_handover_monsoon_log_r2870 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- TABLE 2: monsoon refinement plan per engineer
CREATE TABLE IF NOT EXISTS engineer_monsoon_refinement_r2870 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  refinement_month date NOT NULL,
  total_handovers int NOT NULL DEFAULT 0,
  weather_disrupted int NOT NULL DEFAULT 0,
  avg_delay_min numeric(6,2) NOT NULL DEFAULT 0,
  avg_csat numeric(3,2),
  preparedness_grade text NOT NULL CHECK (preparedness_grade IN ('A','B','C','D','F')),
  action_taken text NOT NULL CHECK (action_taken IN ('kit_issued','training_assigned','vehicle_upgrade','route_replan','mentor_pairing','none')),
  next_review_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('pending','in_progress','completed','escalated')),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monsoon_refinement_r2870 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON engineer_monsoon_refinement_r2870 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- SEED DATA
INSERT INTO engineer_handover_monsoon_log_r2870 (engineer_name, engineer_code, customer_org, city, handover_date, weather_condition, rainfall_mm, scheduled_at, arrived_at, completed_at, delay_minutes, preparedness_score, raincoat_kit_carried, waterproof_tools, backup_vehicle, outcome, customer_csat, notes) VALUES
('Ramesh Kumar','ENG-2870-01','Apollo Dental','Hyderabad','2026-06-10'::date,'heavy_rain',85.5,'2026-06-10 09:00+05:30','2026-06-10 09:42+05:30','2026-06-10 11:15+05:30',42,78,true,true,false,'minor_delay',4,'Heavy rain Banjara Hills; kit carried saved tools'),
('Suresh Patil','ENG-2870-02','Care Hospital','Mumbai','2026-06-12'::date,'flooding',142.0,'2026-06-12 10:00+05:30','2026-06-12 12:30+05:30','2026-06-12 14:00+05:30',150,55,false,true,false,'major_delay',2,'Andheri flooding; no backup vehicle; equipment got wet'),
('Anita Reddy','ENG-2870-03','Manipal Clinic','Bengaluru','2026-06-14'::date,'thunderstorm',38.2,'2026-06-14 11:00+05:30','2026-06-14 11:08+05:30','2026-06-14 12:30+05:30',8,92,true,true,true,'on_time',5,'Full prep; thunder did not impact'),
('Vikram Singh','ENG-2870-04','Fortis Healthcare','Delhi','2026-06-15'::date,'cyclone',0,'2026-06-15 08:00+05:30',NULL,NULL,0,40,false,false,false,'rescheduled',NULL,'Pre-cyclone alert; safely rescheduled to 06-17'),
('Deepa Iyer','ENG-2870-05','Kauvery Hospital','Chennai','2026-06-16'::date,'heavy_rain',95.0,'2026-06-16 09:30+05:30','2026-06-16 09:55+05:30','2026-06-16 11:20+05:30',25,85,true,true,false,'minor_delay',4,'T Nagar wading water; kit prevented damage'),
('Mohammed Ali','ENG-2870-06','KIMS','Hyderabad','2026-06-18'::date,'light_rain',12.0,'2026-06-18 10:00+05:30','2026-06-18 10:05+05:30','2026-06-18 11:00+05:30',5,90,true,true,false,'on_time',5,'Smooth handover; light drizzle only'),
('Priya Nair','ENG-2870-07','Aster Medcity','Kochi','2026-06-19'::date,'flooding',180.5,'2026-06-19 09:00+05:30',NULL,NULL,0,45,true,false,false,'aborted',NULL,'Aluva flooded; aborted for safety'),
('Karthik Rao','ENG-2870-08','Yashoda Hospitals','Hyderabad','2026-06-20'::date,'clear',0,'2026-06-20 14:00+05:30','2026-06-20 14:00+05:30','2026-06-20 15:30+05:30',0,95,true,true,true,'on_time',5,'Clear day; perfect handover');

INSERT INTO engineer_monsoon_refinement_r2870 (engineer_code, engineer_name, refinement_month, total_handovers, weather_disrupted, avg_delay_min, avg_csat, preparedness_grade, action_taken, next_review_date, status, founder_note) VALUES
('ENG-2870-01','Ramesh Kumar','2026-06-01'::date,12,4,28.5,4.20,'B','kit_issued','2026-07-15'::date,'in_progress','Kit working; needs backup vehicle'),
('ENG-2870-02','Suresh Patil','2026-06-01'::date,10,6,85.2,2.80,'D','training_assigned','2026-07-10'::date,'escalated','Mumbai monsoon — 60% disruption; mandatory 2-day training'),
('ENG-2870-03','Anita Reddy','2026-06-01'::date,14,3,5.8,4.85,'A','none','2026-08-01'::date,'completed','Exemplary; pair as mentor for new engineers'),
('ENG-2870-04','Vikram Singh','2026-06-01'::date,8,5,0.0,3.20,'C','vehicle_upgrade','2026-07-20'::date,'in_progress','Delhi cyclone scares; needs 4WD assignment'),
('ENG-2870-05','Deepa Iyer','2026-06-01'::date,11,5,32.4,4.10,'B','route_replan','2026-07-15'::date,'in_progress','Chennai routes need flood-aware re-mapping'),
('ENG-2870-06','Mohammed Ali','2026-06-01'::date,13,2,8.2,4.80,'A','none','2026-08-01'::date,'completed','Strong consistency; eligible for senior tier'),
('ENG-2870-07','Priya Nair','2026-06-01'::date,9,5,45.0,3.50,'C','mentor_pairing','2026-07-12'::date,'in_progress','Kerala monsoon brutal; pair with Anita Reddy');

-- ============================================================
-- RPCs — all SECDEF, is_founder gated
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2870_handover_overview();
CREATE FUNCTION founder_r2870_handover_overview()
RETURNS TABLE(total_handovers bigint, weather_disrupted bigint, avg_delay_min numeric, avg_csat numeric, avg_preparedness numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE weather_condition <> 'clear')::bigint,
    ROUND(AVG(delay_minutes)::numeric,2),
    ROUND(AVG(customer_csat)::numeric,2),
    ROUND(AVG(preparedness_score)::numeric,2)
  FROM engineer_handover_monsoon_log_r2870;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_handover_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_handover_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2870_weather_breakdown();
CREATE FUNCTION founder_r2870_weather_breakdown()
RETURNS TABLE(weather_condition text, handover_count bigint, avg_delay numeric, aborted bigint, avg_rainfall numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.weather_condition,
    COUNT(*)::bigint,
    ROUND(AVG(l.delay_minutes)::numeric,2),
    COUNT(*) FILTER (WHERE l.outcome = 'aborted')::bigint,
    ROUND(AVG(l.rainfall_mm)::numeric,2)
  FROM engineer_handover_monsoon_log_r2870 l
  GROUP BY l.weather_condition
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_weather_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_weather_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2870_engineer_leaderboard();
CREATE FUNCTION founder_r2870_engineer_leaderboard()
RETURNS TABLE(engineer_code text, engineer_name text, handovers bigint, avg_prep numeric, avg_csat numeric, on_time_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.engineer_code,
    MAX(l.engineer_name),
    COUNT(*)::bigint,
    ROUND(AVG(l.preparedness_score)::numeric,2),
    ROUND(AVG(l.customer_csat)::numeric,2),
    ROUND((COUNT(*) FILTER (WHERE l.outcome = 'on_time')::numeric / NULLIF(COUNT(*),0)) * 100, 2)
  FROM engineer_handover_monsoon_log_r2870 l
  GROUP BY l.engineer_code
  ORDER BY AVG(l.preparedness_score) DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2870_city_impact();
CREATE FUNCTION founder_r2870_city_impact()
RETURNS TABLE(city text, handovers bigint, avg_rainfall numeric, avg_delay numeric, aborted bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.city,
    COUNT(*)::bigint,
    ROUND(AVG(l.rainfall_mm)::numeric,2),
    ROUND(AVG(l.delay_minutes)::numeric,2),
    COUNT(*) FILTER (WHERE l.outcome = 'aborted')::bigint
  FROM engineer_handover_monsoon_log_r2870 l
  GROUP BY l.city
  ORDER BY AVG(l.rainfall_mm) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_city_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_city_impact() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2870_preparedness_kit_correlation();
CREATE FUNCTION founder_r2870_preparedness_kit_correlation()
RETURNS TABLE(kit_status text, handovers bigint, avg_delay numeric, avg_csat numeric, on_time_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE WHEN l.raincoat_kit_carried THEN 'kit_present' ELSE 'no_kit' END,
    COUNT(*)::bigint,
    ROUND(AVG(l.delay_minutes)::numeric,2),
    ROUND(AVG(l.customer_csat)::numeric,2),
    ROUND((COUNT(*) FILTER (WHERE l.outcome = 'on_time')::numeric / NULLIF(COUNT(*),0)) * 100, 2)
  FROM engineer_handover_monsoon_log_r2870 l
  GROUP BY l.raincoat_kit_carried;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_preparedness_kit_correlation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_preparedness_kit_correlation() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2870_refinement_queue();
CREATE FUNCTION founder_r2870_refinement_queue()
RETURNS TABLE(engineer_code text, engineer_name text, grade text, action text, status text, next_review date, note text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.engineer_code,
    r.engineer_name,
    r.preparedness_grade,
    r.action_taken,
    r.status,
    r.next_review_date,
    r.founder_note
  FROM engineer_monsoon_refinement_r2870 r
  ORDER BY
    CASE r.preparedness_grade WHEN 'F' THEN 1 WHEN 'D' THEN 2 WHEN 'C' THEN 3 WHEN 'B' THEN 4 ELSE 5 END,
    r.next_review_date ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_refinement_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_refinement_queue() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2870_recent_handovers();
CREATE FUNCTION founder_r2870_recent_handovers()
RETURNS TABLE(handover_date date, engineer text, customer text, city text, weather text, delay_min int, outcome text, csat int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.handover_date,
    l.engineer_name,
    l.customer_org,
    l.city,
    l.weather_condition,
    l.delay_minutes,
    l.outcome,
    l.customer_csat
  FROM engineer_handover_monsoon_log_r2870 l
  ORDER BY l.handover_date DESC, l.scheduled_at DESC
  LIMIT 20;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_recent_handovers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_recent_handovers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2870_outcome_distribution();
CREATE FUNCTION founder_r2870_outcome_distribution()
RETURNS TABLE(outcome text, cnt bigint, pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM engineer_handover_monsoon_log_r2870;
  RETURN QUERY
  SELECT
    l.outcome,
    COUNT(*)::bigint,
    ROUND((COUNT(*)::numeric / NULLIF(total,0)) * 100, 2)
  FROM engineer_handover_monsoon_log_r2870 l
  GROUP BY l.outcome
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2870_outcome_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2870_outcome_distribution() TO authenticated;

COMMIT;
