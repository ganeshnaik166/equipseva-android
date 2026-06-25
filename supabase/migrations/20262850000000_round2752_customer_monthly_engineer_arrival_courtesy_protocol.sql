BEGIN;

CREATE TABLE IF NOT EXISTS customer_arrival_courtesy_visits_r2752 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_code text NOT NULL UNIQUE,
  job_code text NOT NULL,
  customer_name text NOT NULL,
  engineer_name text NOT NULL,
  city text NOT NULL,
  visit_month date NOT NULL,
  visit_at timestamptz NOT NULL,
  greeting_quality text NOT NULL CHECK (greeting_quality IN ('warm','polite','neutral','curt','cold')),
  intro_completeness text NOT NULL CHECK (intro_completeness IN ('full','partial','minimal','missing')),
  wait_minutes integer NOT NULL CHECK (wait_minutes >= 0),
  courtesy_score integer NOT NULL CHECK (courtesy_score BETWEEN 0 AND 100),
  outcome text NOT NULL CHECK (outcome IN ('delighted','satisfied','acceptable','disappointed','complaint')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS customer_arrival_courtesy_actions_r2752 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_code text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('coach','retrain','recognize','escalate','apology_call','bonus')),
  owner text NOT NULL,
  due_on date NOT NULL,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','cancelled')),
  impact_rupees integer NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_arrival_courtesy_visits_r2752 ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_arrival_courtesy_actions_r2752 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON customer_arrival_courtesy_visits_r2752;
CREATE POLICY founder_all ON customer_arrival_courtesy_visits_r2752 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON customer_arrival_courtesy_actions_r2752;
CREATE POLICY founder_all ON customer_arrival_courtesy_actions_r2752 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_arrival_courtesy_visits_r2752 (visit_code, job_code, customer_name, engineer_name, city, visit_month, visit_at, greeting_quality, intro_completeness, wait_minutes, courtesy_score, outcome, notes) VALUES
  ('V-2752-001','J-77821','Apollo Hyderabad','Ravi Kumar','Hyderabad','2026-06-01'::date,'2026-06-04 10:12:00+05:30','warm','full',3,94,'delighted','Greeted by name; explained scope before starting'),
  ('V-2752-002','J-77845','Yashoda Secunderabad','Suresh Reddy','Secunderabad','2026-06-01'::date,'2026-06-06 09:42:00+05:30','polite','full',7,82,'satisfied','Clean intro; slight wait at gate'),
  ('V-2752-003','J-77863','KIMS Kondapur','Anil Verma','Hyderabad','2026-06-01'::date,'2026-06-08 11:05:00+05:30','neutral','partial',18,61,'acceptable','Skipped tool walkthrough'),
  ('V-2752-004','J-77904','Rainbow Banjara','Deepak Singh','Hyderabad','2026-06-01'::date,'2026-06-10 14:25:00+05:30','curt','minimal',22,38,'disappointed','Did not introduce himself; biomed annoyed'),
  ('V-2752-005','J-77917','Continental Gachibowli','Manoj Patel','Hyderabad','2026-06-01'::date,'2026-06-12 08:55:00+05:30','cold','missing',31,18,'complaint','Customer escalated to Bharath; apology call needed'),
  ('V-2752-006','J-77952','Care Hitec City','Priya Sharma','Hyderabad','2026-06-01'::date,'2026-06-15 10:30:00+05:30','warm','full',2,96,'delighted','Customer asked for her on next visit')
ON CONFLICT (visit_code) DO NOTHING;

INSERT INTO customer_arrival_courtesy_actions_r2752 (visit_code, action_type, owner, due_on, status, impact_rupees, notes) VALUES
  ('V-2752-005','apology_call','Bharath','2026-06-26'::date,'open',0,'Founder apology + ₹2000 credit'),
  ('V-2752-005','retrain','Field Ops Lead','2026-06-30'::date,'in_progress',0,'Manoj retraining on greeting protocol'),
  ('V-2752-004','coach','Field Ops Lead','2026-06-28'::date,'open',0,'Deepak 1:1 coach on intro script'),
  ('V-2752-001','recognize','Founder','2026-06-26'::date,'done',500,'₹500 spot bonus to Ravi'),
  ('V-2752-006','bonus','Founder','2026-06-27'::date,'open',1000,'₹1000 customer-delight bonus for Priya'),
  ('V-2752-003','coach','Field Ops Lead','2026-06-29'::date,'open',0,'Walkthrough refresher for Anil')
ON CONFLICT DO NOTHING;

DROP FUNCTION IF EXISTS r2752_overview();
CREATE FUNCTION r2752_overview()
RETURNS TABLE(total_visits integer, avg_courtesy numeric, avg_wait numeric, delighted integer, complaints integer, open_actions integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::integer FROM customer_arrival_courtesy_visits_r2752),
    COALESCE((SELECT ROUND(AVG(courtesy_score)::numeric,1) FROM customer_arrival_courtesy_visits_r2752),0),
    COALESCE((SELECT ROUND(AVG(wait_minutes)::numeric,1) FROM customer_arrival_courtesy_visits_r2752),0),
    (SELECT COUNT(*)::integer FROM customer_arrival_courtesy_visits_r2752 WHERE outcome='delighted'),
    (SELECT COUNT(*)::integer FROM customer_arrival_courtesy_visits_r2752 WHERE outcome='complaint'),
    (SELECT COUNT(*)::integer FROM customer_arrival_courtesy_actions_r2752 WHERE status IN ('open','in_progress'));
END $$;
REVOKE EXECUTE ON FUNCTION r2752_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_overview() TO authenticated;

DROP FUNCTION IF EXISTS r2752_visits();
CREATE FUNCTION r2752_visits()
RETURNS SETOF customer_arrival_courtesy_visits_r2752
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_arrival_courtesy_visits_r2752 ORDER BY visit_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2752_visits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_visits() TO authenticated;

DROP FUNCTION IF EXISTS r2752_by_greeting();
CREATE FUNCTION r2752_by_greeting()
RETURNS TABLE(greeting_quality text, visits integer, avg_score numeric, avg_wait numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.greeting_quality, COUNT(*)::integer, ROUND(AVG(v.courtesy_score)::numeric,1), ROUND(AVG(v.wait_minutes)::numeric,1)
  FROM customer_arrival_courtesy_visits_r2752 v
  GROUP BY v.greeting_quality
  ORDER BY 3 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2752_by_greeting() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_by_greeting() TO authenticated;

DROP FUNCTION IF EXISTS r2752_by_engineer();
CREATE FUNCTION r2752_by_engineer()
RETURNS TABLE(engineer_name text, visits integer, avg_score numeric, complaints integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.engineer_name, COUNT(*)::integer, ROUND(AVG(v.courtesy_score)::numeric,1),
    SUM(CASE WHEN v.outcome='complaint' THEN 1 ELSE 0 END)::integer
  FROM customer_arrival_courtesy_visits_r2752 v
  GROUP BY v.engineer_name
  ORDER BY 3 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2752_by_engineer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_by_engineer() TO authenticated;

DROP FUNCTION IF EXISTS r2752_by_outcome();
CREATE FUNCTION r2752_by_outcome()
RETURNS TABLE(outcome text, visits integer, avg_wait numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.outcome, COUNT(*)::integer, ROUND(AVG(v.wait_minutes)::numeric,1)
  FROM customer_arrival_courtesy_visits_r2752 v
  GROUP BY v.outcome
  ORDER BY 2 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2752_by_outcome() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_by_outcome() TO authenticated;

DROP FUNCTION IF EXISTS r2752_actions();
CREATE FUNCTION r2752_actions()
RETURNS SETOF customer_arrival_courtesy_actions_r2752
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_arrival_courtesy_actions_r2752 ORDER BY due_on ASC;
END $$;
REVOKE EXECUTE ON FUNCTION r2752_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_actions() TO authenticated;

DROP FUNCTION IF EXISTS r2752_top_problems();
CREATE FUNCTION r2752_top_problems()
RETURNS TABLE(visit_code text, engineer_name text, courtesy_score integer, outcome text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.visit_code, v.engineer_name, v.courtesy_score, v.outcome, v.notes
  FROM customer_arrival_courtesy_visits_r2752 v
  WHERE v.outcome IN ('disappointed','complaint') OR v.courtesy_score < 60
  ORDER BY v.courtesy_score ASC;
END $$;
REVOKE EXECUTE ON FUNCTION r2752_top_problems() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_top_problems() TO authenticated;

DROP FUNCTION IF EXISTS r2752_log_visit(text, text, text, text, text, date, timestamptz, text, text, integer, integer, text, text);
CREATE FUNCTION r2752_log_visit(p_visit_code text, p_job_code text, p_customer_name text, p_engineer_name text, p_city text, p_visit_month date, p_visit_at timestamptz, p_greeting text, p_intro text, p_wait integer, p_score integer, p_outcome text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO customer_arrival_courtesy_visits_r2752 (visit_code, job_code, customer_name, engineer_name, city, visit_month, visit_at, greeting_quality, intro_completeness, wait_minutes, courtesy_score, outcome, notes)
  VALUES (p_visit_code, p_job_code, p_customer_name, p_engineer_name, p_city, p_visit_month, p_visit_at, p_greeting, p_intro, p_wait, p_score, p_outcome, p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION r2752_log_visit(text, text, text, text, text, date, timestamptz, text, text, integer, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2752_log_visit(text, text, text, text, text, date, timestamptz, text, text, integer, integer, text, text) TO authenticated;

COMMIT;
