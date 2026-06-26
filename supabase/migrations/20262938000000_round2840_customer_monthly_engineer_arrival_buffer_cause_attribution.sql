BEGIN;

CREATE TABLE IF NOT EXISTS customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  job_code text NOT NULL,
  customer_org text NOT NULL,
  engineer_name text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  actual_arrival_at timestamptz NOT NULL,
  buffer_minutes integer NOT NULL,
  delay_cause text NOT NULL CHECK (delay_cause IN ('traffic','prior_job_overrun','parts_pickup','customer_reschedule','navigation_error','vehicle_breakdown')),
  actionability text NOT NULL CHECK (actionability IN ('fully_actionable','partially_actionable','external')),
  prevention_lever text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('on_time_after_buffer','sla_breach','customer_waived','rescheduled')),
  customer_satisfaction integer NOT NULL CHECK (customer_satisfaction BETWEEN 1 AND 5),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_monthly_engineer_arrival_buffer_cause_attribution_r2840
  (month_label, job_code, customer_org, engineer_name, scheduled_at, actual_arrival_at, buffer_minutes, delay_cause, actionability, prevention_lever, outcome, customer_satisfaction)
VALUES
  ('2026-06','JOB-9821','Apollo Jubilee','Ravi K','2026-06-03 09:00+05:30'::timestamptz,'2026-06-03 09:42+05:30'::timestamptz,42,'traffic','partially_actionable','depart 30m earlier on Mon/Wed','on_time_after_buffer',4),
  ('2026-06','JOB-9847','KIMS Secunderabad','Suresh M','2026-06-05 11:00+05:30'::timestamptz,'2026-06-05 12:15+05:30'::timestamptz,75,'prior_job_overrun','fully_actionable','cap slot duration at 90m','sla_breach',2),
  ('2026-06','JOB-9883','Yashoda Somajiguda','Priya R','2026-06-08 14:30+05:30'::timestamptz,'2026-06-08 15:05+05:30'::timestamptz,35,'parts_pickup','fully_actionable','pre-stage parts night before','on_time_after_buffer',4),
  ('2026-06','JOB-9912','Care Banjara','Anil J','2026-06-12 10:00+05:30'::timestamptz,'2026-06-12 10:55+05:30'::timestamptz,55,'navigation_error','fully_actionable','mandatory Google Maps screenshot','customer_waived',3),
  ('2026-06','JOB-9941','Continental Gachibowli','Ravi K','2026-06-15 16:00+05:30'::timestamptz,'2026-06-15 17:20+05:30'::timestamptz,80,'vehicle_breakdown','external','backup vehicle on-call','rescheduled',2),
  ('2026-06','JOB-9978','Rainbow Banjara','Suresh M','2026-06-18 09:30+05:30'::timestamptz,'2026-06-18 10:08+05:30'::timestamptz,38,'customer_reschedule','external','SMS confirm 1h before','on_time_after_buffer',5);

CREATE TABLE IF NOT EXISTS customer_monthly_arrival_buffer_cause_summary_r2840 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  delay_cause text NOT NULL,
  occurrence_count integer NOT NULL,
  avg_buffer_minutes numeric(6,2) NOT NULL,
  sla_breach_count integer NOT NULL,
  actionable_share_pct numeric(5,2) NOT NULL,
  top_prevention_lever text NOT NULL,
  est_monthly_minutes_savable integer NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_monthly_arrival_buffer_cause_summary_r2840 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON customer_monthly_arrival_buffer_cause_summary_r2840 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_monthly_arrival_buffer_cause_summary_r2840
  (month_label, delay_cause, occurrence_count, avg_buffer_minutes, sla_breach_count, actionable_share_pct, top_prevention_lever, est_monthly_minutes_savable)
VALUES
  ('2026-06','traffic',18,41.50,2,55.00,'depart earlier on peak corridors',420),
  ('2026-06','prior_job_overrun',12,68.30,5,100.00,'cap slot duration at 90m',520),
  ('2026-06','parts_pickup',9,33.80,1,100.00,'pre-stage parts night before',280),
  ('2026-06','navigation_error',6,48.20,1,100.00,'mandatory Google Maps screenshot',210),
  ('2026-06','vehicle_breakdown',3,82.10,2,10.00,'backup vehicle on-call',180),
  ('2026-06','customer_reschedule',7,36.40,0,15.00,'SMS confirm 1h before',95);

DROP FUNCTION IF EXISTS founder_r2840_kpis();
CREATE OR REPLACE FUNCTION founder_r2840_kpis()
RETURNS TABLE(total_jobs integer, avg_buffer_minutes numeric, sla_breaches integer, actionable_share_pct numeric, monthly_minutes_savable integer, top_cause text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::int FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840),
      (SELECT round(avg(buffer_minutes)::numeric,2) FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840),
      (SELECT count(*)::int FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 WHERE outcome = 'sla_breach'),
      (SELECT round((sum(CASE WHEN actionability = 'fully_actionable' THEN 1 ELSE 0 END)::numeric * 100) / NULLIF(count(*),0), 2)
         FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840),
      (SELECT coalesce(sum(est_monthly_minutes_savable),0)::int FROM customer_monthly_arrival_buffer_cause_summary_r2840),
      (SELECT delay_cause FROM customer_monthly_arrival_buffer_cause_summary_r2840 ORDER BY occurrence_count DESC LIMIT 1);
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2840_attribution_rows();
CREATE OR REPLACE FUNCTION founder_r2840_attribution_rows()
RETURNS SETOF customer_monthly_engineer_arrival_buffer_cause_attribution_r2840
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 ORDER BY scheduled_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_attribution_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_attribution_rows() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2840_cause_summary();
CREATE OR REPLACE FUNCTION founder_r2840_cause_summary()
RETURNS SETOF customer_monthly_arrival_buffer_cause_summary_r2840
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM customer_monthly_arrival_buffer_cause_summary_r2840 ORDER BY occurrence_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_cause_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_cause_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2840_engineer_leaderboard();
CREATE OR REPLACE FUNCTION founder_r2840_engineer_leaderboard()
RETURNS TABLE(engineer_name text, jobs integer, avg_buffer_minutes numeric, breaches integer, csat_avg numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      a.engineer_name,
      count(*)::int,
      round(avg(a.buffer_minutes)::numeric,2),
      sum(CASE WHEN a.outcome = 'sla_breach' THEN 1 ELSE 0 END)::int,
      round(avg(a.customer_satisfaction)::numeric,2)
    FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 a
    GROUP BY a.engineer_name
    ORDER BY avg(a.buffer_minutes) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2840_actionability_breakdown();
CREATE OR REPLACE FUNCTION founder_r2840_actionability_breakdown()
RETURNS TABLE(actionability text, jobs integer, avg_buffer_minutes numeric, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE total integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840;
  RETURN QUERY
    SELECT a.actionability, count(*)::int, round(avg(a.buffer_minutes)::numeric,2),
      round((count(*)::numeric * 100) / NULLIF(total,0), 2)
    FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 a
    GROUP BY a.actionability
    ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_actionability_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_actionability_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2840_outcome_distribution();
CREATE OR REPLACE FUNCTION founder_r2840_outcome_distribution()
RETURNS TABLE(outcome text, jobs integer, avg_csat numeric, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE total integer;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840;
  RETURN QUERY
    SELECT a.outcome, count(*)::int, round(avg(a.customer_satisfaction)::numeric,2),
      round((count(*)::numeric * 100) / NULLIF(total,0), 2)
    FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 a
    GROUP BY a.outcome
    ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_outcome_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_outcome_distribution() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2840_top_prevention_levers();
CREATE OR REPLACE FUNCTION founder_r2840_top_prevention_levers()
RETURNS TABLE(prevention_lever text, occurrence_count integer, minutes_savable integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.top_prevention_lever, s.occurrence_count, s.est_monthly_minutes_savable
    FROM customer_monthly_arrival_buffer_cause_summary_r2840 s
    ORDER BY s.est_monthly_minutes_savable DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_top_prevention_levers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_top_prevention_levers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2840_sla_breach_jobs();
CREATE OR REPLACE FUNCTION founder_r2840_sla_breach_jobs()
RETURNS TABLE(job_code text, customer_org text, engineer_name text, buffer_minutes integer, delay_cause text, prevention_lever text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.job_code, a.customer_org, a.engineer_name, a.buffer_minutes, a.delay_cause, a.prevention_lever
    FROM customer_monthly_engineer_arrival_buffer_cause_attribution_r2840 a
    WHERE a.outcome IN ('sla_breach','rescheduled')
    ORDER BY a.buffer_minutes DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2840_sla_breach_jobs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2840_sla_breach_jobs() TO authenticated;

COMMIT;