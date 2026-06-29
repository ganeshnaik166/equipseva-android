-- Round 2920: Customer Monthly Engineer Post-Visit Hospital Recommendation NPS Lift
-- HEAVY founder ops round

BEGIN;

-- ============================================================
-- Table 1: Monthly post-visit NPS surveys (per hospital × engineer × month)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_visit_nps_surveys_r2920 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid,
  engineer_id uuid,
  survey_month date NOT NULL,
  visits_in_month int NOT NULL DEFAULT 0,
  surveys_sent int NOT NULL DEFAULT 0,
  surveys_responded int NOT NULL DEFAULT 0,
  promoters int NOT NULL DEFAULT 0,
  passives int NOT NULL DEFAULT 0,
  detractors int NOT NULL DEFAULT 0,
  nps_score numeric(5,2) NOT NULL DEFAULT 0,
  prev_month_nps numeric(5,2),
  nps_lift numeric(5,2) NOT NULL DEFAULT 0,
  recommendation_rate numeric(5,2) NOT NULL DEFAULT 0,
  avg_response_hours numeric(6,2) NOT NULL DEFAULT 0,
  top_strength text,
  top_weakness text,
  region text,
  hospital_name text,
  engineer_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE post_visit_nps_surveys_r2920 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Table 2: Recommendation lift actions / coaching interventions
-- ============================================================
CREATE TABLE IF NOT EXISTS nps_lift_actions_r2920 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid,
  hospital_org_id uuid,
  action_month date NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('coaching','retraining','reassignment','bonus','warning','recognition','survey_followup')),
  action_status text NOT NULL DEFAULT 'open' CHECK (action_status IN ('open','in_progress','completed','dropped')),
  trigger_nps_score numeric(5,2),
  target_nps_lift numeric(5,2),
  realized_nps_lift numeric(5,2),
  owner_name text,
  notes text,
  due_date date,
  completed_at timestamptz,
  engineer_name text,
  hospital_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE nps_lift_actions_r2920 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Seeds: post_visit_nps_surveys_r2920 (20 rows)
-- ============================================================
INSERT INTO post_visit_nps_surveys_r2920
(survey_month, visits_in_month, surveys_sent, surveys_responded, promoters, passives, detractors, nps_score, prev_month_nps, nps_lift, recommendation_rate, avg_response_hours, top_strength, top_weakness, region, hospital_name, engineer_name) VALUES
('2026-05-01'::date, 42, 38, 31, 22, 6, 3, 61.29, 54.10, 7.19, 89.50, 18.40, 'punctual_arrival','slow_part_eta','South','Apollo Jubilee Hills','Ravi Kumar'),
('2026-05-01'::date, 38, 34, 28, 18, 7, 3, 53.57, 48.20, 5.37, 84.30, 22.10, 'clear_explanation','followup_delay','South','KIMS Secunderabad','Sai Krishna'),
('2026-05-01'::date, 51, 46, 39, 28, 8, 3, 64.10, 70.50, -6.40, 92.10, 14.20, 'first_time_fix','rushed_demo','West','Lilavati Mumbai','Anita Sharma'),
('2026-05-01'::date, 29, 27, 22, 11, 7, 4, 31.82, 36.40, -4.58, 72.40, 28.70, 'friendly','escalation_lag','North','Max Saket','Priya Mehta'),
('2026-05-01'::date, 47, 43, 36, 26, 7, 3, 63.89, 58.20, 5.69, 90.80, 16.10, 'thorough_checklist','noisy_workspace','South','Yashoda Somajiguda','Rajesh Reddy'),
('2026-05-01'::date, 33, 30, 25, 14, 8, 3, 44.00, 41.10, 2.90, 78.90, 24.50, 'spare_availability','documentation_thin','East','Fortis Anandapur','Debasis Roy'),
('2026-05-01'::date, 56, 52, 44, 33, 8, 3, 68.18, 62.40, 5.78, 93.20, 12.80, 'sla_compliance','small_talk_low','West','Hinduja Mahim','Kunal Joshi'),
('2026-05-01'::date, 24, 22, 18, 9, 6, 3, 33.33, 29.80, 3.53, 70.10, 30.20, 'patient','phone_etiquette','North','Medanta Gurgaon','Vikram Singh'),
('2026-05-01'::date, 40, 36, 30, 21, 6, 3, 60.00, 55.30, 4.70, 88.40, 17.90, 'tooling','site_briefing','South','CARE Banjara','Mohan Reddy'),
('2026-05-01'::date, 35, 32, 26, 15, 8, 3, 46.15, 50.20, -4.05, 80.30, 21.60, 'technical_depth','status_updates','West','Jaslok Mumbai','Farhan Sheikh'),
('2026-04-01'::date, 41, 37, 30, 20, 7, 3, 56.67, 52.10, 4.57, 86.20, 19.50, 'punctual_arrival','part_eta','South','Apollo Jubilee Hills','Ravi Kumar'),
('2026-04-01'::date, 37, 33, 27, 16, 8, 3, 48.15, 45.30, 2.85, 82.40, 23.30, 'clear_explanation','followup','South','KIMS Secunderabad','Sai Krishna'),
('2026-04-01'::date, 49, 44, 37, 27, 7, 3, 64.86, 68.10, -3.24, 91.80, 14.90, 'first_time_fix','demo_rushed','West','Lilavati Mumbai','Anita Sharma'),
('2026-04-01'::date, 28, 26, 21, 10, 7, 4, 28.57, 33.40, -4.83, 70.20, 29.10, 'friendly','escalation','North','Max Saket','Priya Mehta'),
('2026-04-01'::date, 45, 41, 34, 24, 7, 3, 61.76, 55.80, 5.96, 89.60, 16.80, 'thorough','workspace','South','Yashoda Somajiguda','Rajesh Reddy'),
('2026-05-01'::date, 31, 28, 23, 12, 8, 3, 39.13, 35.20, 3.93, 75.40, 25.80, 'spare_avail','docs','East','AMRI Dhakuria','Subir Banerjee'),
('2026-05-01'::date, 44, 40, 33, 23, 7, 3, 60.61, 57.90, 2.71, 87.10, 18.20, 'reliability','quote_turnaround','West','Wockhardt Mira','Imran Patel'),
('2026-05-01'::date, 27, 25, 20, 10, 7, 3, 35.00, 39.50, -4.50, 73.20, 27.40, 'cleanliness','noise','South','Rainbow Banjara','Lakshmi Iyer'),
('2026-05-01'::date, 36, 33, 28, 19, 6, 3, 57.14, 52.30, 4.84, 85.70, 19.30, 'kpi_tracking','small_talk','North','BLK Delhi','Amit Verma'),
('2026-05-01'::date, 42, 39, 32, 22, 7, 3, 59.38, 53.40, 5.98, 88.10, 17.50, 'punctuality','quote_clarity','South','Continental Hosp','Naveen Rao');

-- ============================================================
-- Seeds: nps_lift_actions_r2920 (16 rows)
-- ============================================================
INSERT INTO nps_lift_actions_r2920
(action_month, action_type, action_status, trigger_nps_score, target_nps_lift, realized_nps_lift, owner_name, notes, due_date, completed_at, engineer_name, hospital_name) VALUES
('2026-05-01'::date,'coaching','completed',31.82,10.00,8.40,'Ops Lead - Priya','soft-skills + escalation training','2026-05-20'::date,'2026-05-22 14:30'::timestamptz,'Priya Mehta','Max Saket'),
('2026-05-01'::date,'coaching','in_progress',33.33,12.00,NULL,'Ops Lead - Priya','phone-etiquette module','2026-06-15'::date,NULL,'Vikram Singh','Medanta Gurgaon'),
('2026-05-01'::date,'recognition','completed',68.18,5.00,5.78,'Founder','top-engineer bonus dispatch','2026-05-10'::date,'2026-05-09 11:00'::timestamptz,'Kunal Joshi','Hinduja Mahim'),
('2026-05-01'::date,'retraining','open',46.15,8.00,NULL,'Tech Lead - Sandeep','status-update SOP','2026-06-30'::date,NULL,'Farhan Sheikh','Jaslok Mumbai'),
('2026-05-01'::date,'survey_followup','completed',35.00,6.00,4.10,'CX - Asha','hospital callback + apology','2026-05-25'::date,'2026-05-27 09:15'::timestamptz,'Lakshmi Iyer','Rainbow Banjara'),
('2026-05-01'::date,'coaching','open',39.13,7.00,NULL,'Ops Lead - Priya','documentation discipline','2026-06-20'::date,NULL,'Subir Banerjee','AMRI Dhakuria'),
('2026-04-01'::date,'coaching','completed',28.57,12.00,4.76,'Ops Lead - Priya','retraining 2-day off-site','2026-04-25'::date,'2026-04-26 16:00'::timestamptz,'Priya Mehta','Max Saket'),
('2026-05-01'::date,'bonus','completed',64.10,0.00,-6.40,'Founder','bonus paid before regression','2026-05-05'::date,'2026-05-05 10:00'::timestamptz,'Anita Sharma','Lilavati Mumbai'),
('2026-05-01'::date,'warning','in_progress',-4.58,5.00,NULL,'Ops Lead - Priya','formal warning issued','2026-06-10'::date,NULL,'Priya Mehta','Max Saket'),
('2026-05-01'::date,'reassignment','dropped',44.00,8.00,NULL,'Ops Lead - Priya','reassignment declined','2026-06-01'::date,NULL,'Debasis Roy','Fortis Anandapur'),
('2026-05-01'::date,'recognition','completed',63.89,3.00,5.69,'Founder','LinkedIn shout-out','2026-05-15'::date,'2026-05-14 18:00'::timestamptz,'Rajesh Reddy','Yashoda Somajiguda'),
('2026-05-01'::date,'coaching','in_progress',48.15,6.00,NULL,'Ops Lead - Priya','followup playbook','2026-06-25'::date,NULL,'Sai Krishna','KIMS Secunderabad'),
('2026-05-01'::date,'survey_followup','open',57.14,3.00,NULL,'CX - Asha','callbacks scheduled','2026-06-12'::date,NULL,'Amit Verma','BLK Delhi'),
('2026-05-01'::date,'recognition','completed',61.29,4.00,7.19,'Founder','engineer-of-month bonus','2026-05-18'::date,'2026-05-18 12:00'::timestamptz,'Ravi Kumar','Apollo Jubilee Hills'),
('2026-05-01'::date,'coaching','open',60.61,4.00,NULL,'Ops Lead - Priya','quote turnaround coaching','2026-06-28'::date,NULL,'Imran Patel','Wockhardt Mira'),
('2026-05-01'::date,'retraining','completed',53.57,5.00,5.37,'Tech Lead - Sandeep','followup SLA training','2026-05-20'::date,'2026-05-21 15:30'::timestamptz,'Sai Krishna','KIMS Secunderabad');

-- ============================================================
-- RPC 1: KPI summary
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_r2920_nps_kpi_summary()
RETURNS TABLE (
  metric text,
  value numeric,
  unit text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;

  RETURN QUERY
  SELECT 'avg_nps_current_month'::text, ROUND(AVG(nps_score)::numeric,2), 'pts'::text
    FROM post_visit_nps_surveys_r2920 WHERE survey_month = '2026-05-01'::date
  UNION ALL
  SELECT 'avg_nps_lift'::text, ROUND(AVG(nps_lift)::numeric,2), 'pts'::text
    FROM post_visit_nps_surveys_r2920 WHERE survey_month = '2026-05-01'::date
  UNION ALL
  SELECT 'response_rate_pct'::text,
         ROUND((SUM(surveys_responded)::numeric / NULLIF(SUM(surveys_sent),0) * 100)::numeric,2),
         'pct'::text
    FROM post_visit_nps_surveys_r2920 WHERE survey_month = '2026-05-01'::date
  UNION ALL
  SELECT 'recommendation_rate_pct'::text, ROUND(AVG(recommendation_rate)::numeric,2), 'pct'::text
    FROM post_visit_nps_surveys_r2920 WHERE survey_month = '2026-05-01'::date
  UNION ALL
  SELECT 'open_lift_actions'::text, COUNT(*)::numeric, 'count'::text
    FROM nps_lift_actions_r2920 WHERE action_status IN ('open','in_progress');
END;
$$;

-- ============================================================
-- RPC 2: Top engineers by NPS lift
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_r2920_top_engineers_by_lift()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  hospital_name text,
  nps_score numeric,
  prev_month_nps numeric,
  nps_lift numeric,
  recommendation_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;

  RETURN QUERY
  SELECT s.id, s.engineer_name, s.hospital_name, s.nps_score, s.prev_month_nps, s.nps_lift, s.recommendation_rate
  FROM post_visit_nps_surveys_r2920 s
  WHERE s.survey_month = '2026-05-01'::date
  ORDER BY s.nps_lift DESC NULLS LAST
  LIMIT 10;
END;
$$;

-- ============================================================
-- RPC 3: Detractors needing intervention
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_r2920_detractor_engineers()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  hospital_name text,
  nps_score numeric,
  detractors int,
  top_weakness text,
  region text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;

  RETURN QUERY
  SELECT s.id, s.engineer_name, s.hospital_name, s.nps_score, s.detractors, s.top_weakness, s.region
  FROM post_visit_nps_surveys_r2920 s
  WHERE s.survey_month = '2026-05-01'::date
    AND s.nps_score < 50
  ORDER BY s.nps_score ASC;
END;
$$;

-- ============================================================
-- RPC 4: Hospital recommendation leaderboard
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_r2920_hospital_recommendation_leaderboard()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  region text,
  avg_nps numeric,
  avg_recommendation_rate numeric,
  total_surveys_responded bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;

  RETURN QUERY
  SELECT
    (gen_random_uuid())::uuid AS id,
    s.hospital_name,
    MAX(s.region) AS region,
    ROUND(AVG(s.nps_score)::numeric,2) AS avg_nps,
    ROUND(AVG(s.recommendation_rate)::numeric,2) AS avg_recommendation_rate,
    SUM(s.surveys_responded)::bigint AS total_surveys_responded
  FROM post_visit_nps_surveys_r2920 s
  WHERE s.survey_month = '2026-05-01'::date
  GROUP BY s.hospital_name
  ORDER BY avg_nps DESC
  LIMIT 12;
END;
$$;

-- ============================================================
-- RPC 5: Action effectiveness
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_r2920_action_effectiveness()
RETURNS TABLE (
  id uuid,
  action_type text,
  action_status text,
  engineer_name text,
  hospital_name text,
  trigger_nps_score numeric,
  target_nps_lift numeric,
  realized_nps_lift numeric,
  owner_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;

  RETURN QUERY
  SELECT a.id, a.action_type, a.action_status, a.engineer_name, a.hospital_name,
         a.trigger_nps_score, a.target_nps_lift, a.realized_nps_lift, a.owner_name
  FROM nps_lift_actions_r2920 a
  ORDER BY
    CASE WHEN a.realized_nps_lift IS NULL THEN 1 ELSE 0 END,
    a.realized_nps_lift DESC NULLS LAST
  LIMIT 15;
END;
$$;

-- ============================================================
-- RPC 6: Regional NPS breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_r2920_regional_breakdown()
RETURNS TABLE (
  id uuid,
  region text,
  avg_nps numeric,
  avg_lift numeric,
  total_visits bigint,
  response_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;

  RETURN QUERY
  SELECT
    (gen_random_uuid())::uuid AS id,
    s.region,
    ROUND(AVG(s.nps_score)::numeric,2),
    ROUND(AVG(s.nps_lift)::numeric,2),
    SUM(s.visits_in_month)::bigint,
    ROUND((SUM(s.surveys_responded)::numeric / NULLIF(SUM(s.surveys_sent),0) * 100)::numeric,2)
  FROM post_visit_nps_surveys_r2920 s
  WHERE s.survey_month = '2026-05-01'::date
  GROUP BY s.region
  ORDER BY AVG(s.nps_score) DESC;
END;
$$;

-- ============================================================
-- RPC 7: Month-over-month trend
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_r2920_month_over_month_trend()
RETURNS TABLE (
  id uuid,
  survey_month date,
  avg_nps numeric,
  avg_lift numeric,
  total_promoters bigint,
  total_detractors bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'founder only';
  END IF;

  RETURN QUERY
  SELECT
    (gen_random_uuid())::uuid AS id,
    s.survey_month,
    ROUND(AVG(s.nps_score)::numeric,2),
    ROUND(AVG(s.nps_lift)::numeric,2),
    SUM(s.promoters)::bigint,
    SUM(s.detractors)::bigint
  FROM post_visit_nps_surveys_r2920 s
  GROUP BY s.survey_month
  ORDER BY s.survey_month DESC;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE EXECUTE ON FUNCTION rpc_r2920_nps_kpi_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2920_top_engineers_by_lift() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2920_detractor_engineers() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2920_hospital_recommendation_leaderboard() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2920_action_effectiveness() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2920_regional_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_r2920_month_over_month_trend() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_r2920_nps_kpi_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2920_top_engineers_by_lift() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2920_detractor_engineers() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2920_hospital_recommendation_leaderboard() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2920_action_effectiveness() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2920_regional_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_r2920_month_over_month_trend() TO authenticated;

COMMIT;
