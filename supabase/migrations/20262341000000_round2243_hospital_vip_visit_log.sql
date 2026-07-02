BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_vip_visits_r2243 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  hospital_name text NOT NULL,
  hospital_city text,
  hospital_tier text CHECK (hospital_tier IN ('flagship','tier1','tier2','tier3','prospect')),
  visit_date date NOT NULL,
  visit_type text NOT NULL CHECK (visit_type IN ('intro','quarterly_review','escalation','renewal_pitch','social','crisis','closeout','board_demo')),
  visited_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  visited_by_name text NOT NULL,
  visited_by_role text CHECK (visited_by_role IN ('founder','ceo','coo','vp_sales','vp_ops','board_member')),
  counterpart_name text NOT NULL,
  counterpart_title text,
  counterpart_seniority text CHECK (counterpart_seniority IN ('owner','md','ceo','coo','cfo','head_biomed','head_proc','head_admin','manager')),
  agenda text NOT NULL,
  key_discussion_points text,
  outcomes text,
  commitments_made text,
  asks_from_hospital text,
  relationship_temperature text NOT NULL CHECK (relationship_temperature IN ('cold','cool','neutral','warm','hot','on_fire')),
  satisfaction_score int CHECK (satisfaction_score BETWEEN 1 AND 10),
  churn_risk text CHECK (churn_risk IN ('low','medium','high','critical')),
  next_visit_due_date date,
  duration_minutes int,
  visit_location text CHECK (visit_location IN ('hospital_premises','equipseva_office','restaurant','conference','video_call','other')),
  gift_value_rupees int DEFAULT 0,
  contract_value_rupees bigint DEFAULT 0,
  internal_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_vip_followups_r2243 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id uuid NOT NULL REFERENCES public.hospital_vip_visits_r2243(id) ON DELETE CASCADE,
  followup_type text NOT NULL CHECK (followup_type IN ('proposal','demo','escalation_fix','call','email','site_visit','contract_amend','custom_report','exec_intro')),
  description text NOT NULL,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  owner_name text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','blocked','cancelled')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  closed_at timestamptz,
  closure_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_vip_visits_r2243 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_vip_followups_r2243 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_vip_visits_r2243;
CREATE POLICY founder_all ON public.hospital_vip_visits_r2243 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_vip_followups_r2243;
CREATE POLICY founder_all ON public.hospital_vip_followups_r2243 FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_vip_visits_r2243_date ON public.hospital_vip_visits_r2243(visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_vip_visits_r2243_temp ON public.hospital_vip_visits_r2243(relationship_temperature);
CREATE INDEX IF NOT EXISTS idx_vip_visits_r2243_risk ON public.hospital_vip_visits_r2243(churn_risk);
CREATE INDEX IF NOT EXISTS idx_vip_followups_r2243_status ON public.hospital_vip_followups_r2243(status);
CREATE INDEX IF NOT EXISTS idx_vip_followups_r2243_due ON public.hospital_vip_followups_r2243(due_date);

CREATE OR REPLACE FUNCTION public.list_hospital_vip_visits_r2243()
RETURNS TABLE(
  id uuid, hospital_name text, hospital_city text, hospital_tier text,
  visit_date date, visit_type text, visited_by_name text, counterpart_name text,
  counterpart_title text, relationship_temperature text, satisfaction_score int,
  churn_risk text, next_visit_due_date date, contract_value_rupees bigint, agenda text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_name, v.hospital_city, v.hospital_tier,
    v.visit_date, v.visit_type, v.visited_by_name, v.counterpart_name,
    v.counterpart_title, v.relationship_temperature, v.satisfaction_score,
    v.churn_risk, v.next_visit_due_date, v.contract_value_rupees, v.agenda
  FROM public.hospital_vip_visits_r2243 v
  ORDER BY v.visit_date DESC, v.created_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.summary_hospital_vip_visits_r2243()
RETURNS TABLE(
  total_visits int, visits_30d int, visits_90d int,
  hot_relationships int, cold_relationships int,
  critical_churn_risks int, high_churn_risks int,
  avg_satisfaction numeric, overdue_next_visits int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE visit_date >= current_date - INTERVAL '30 days'))::int,
    (COUNT(*) FILTER (WHERE visit_date >= current_date - INTERVAL '90 days'))::int,
    (COUNT(*) FILTER (WHERE relationship_temperature IN ('hot','on_fire')))::int,
    (COUNT(*) FILTER (WHERE relationship_temperature IN ('cold','cool')))::int,
    (COUNT(*) FILTER (WHERE churn_risk = 'critical'))::int,
    (COUNT(*) FILTER (WHERE churn_risk = 'high'))::int,
    ROUND(AVG(satisfaction_score)::numeric, 2),
    (COUNT(*) FILTER (WHERE next_visit_due_date IS NOT NULL AND next_visit_due_date < current_date))::int
  FROM public.hospital_vip_visits_r2243;
END $$;

CREATE OR REPLACE FUNCTION public.list_hospital_vip_followups_r2243()
RETURNS TABLE(
  id uuid, visit_id uuid, hospital_name text, followup_type text,
  description text, owner_name text, due_date date, status text, priority text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.visit_id, v.hospital_name, f.followup_type,
    f.description, f.owner_name, f.due_date, f.status, f.priority
  FROM public.hospital_vip_followups_r2243 f
  JOIN public.hospital_vip_visits_r2243 v ON v.id = f.visit_id
  WHERE f.status NOT IN ('done','cancelled')
  ORDER BY 
    CASE f.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
    f.due_date ASC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.temperature_breakdown_hospital_vip_r2243()
RETURNS TABLE(temperature text, visit_count int, avg_satisfaction numeric, total_contract_value bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT relationship_temperature,
    (COUNT(*))::int,
    ROUND(AVG(satisfaction_score)::numeric, 2),
    COALESCE(SUM(contract_value_rupees), 0)::bigint
  FROM public.hospital_vip_visits_r2243
  GROUP BY relationship_temperature
  ORDER BY 
    CASE relationship_temperature 
      WHEN 'on_fire' THEN 0 WHEN 'hot' THEN 1 WHEN 'warm' THEN 2 
      WHEN 'neutral' THEN 3 WHEN 'cool' THEN 4 WHEN 'cold' THEN 5 
    END;
END $$;

CREATE OR REPLACE FUNCTION public.visit_type_breakdown_hospital_vip_r2243()
RETURNS TABLE(visit_type text, visit_count int, avg_satisfaction numeric, hot_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.visit_type,
    (COUNT(*))::int,
    ROUND(AVG(v.satisfaction_score)::numeric, 2),
    (COUNT(*) FILTER (WHERE v.relationship_temperature IN ('hot','on_fire')))::int
  FROM public.hospital_vip_visits_r2243 v
  GROUP BY v.visit_type
  ORDER BY COUNT(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.top_hospitals_by_visit_count_r2243()
RETURNS TABLE(
  hospital_name text, hospital_tier text, visit_count int,
  last_visit_date date, last_temperature text, last_churn_risk text,
  total_contract_value bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.hospital_name,
    MAX(v.hospital_tier) AS hospital_tier,
    (COUNT(*))::int,
    MAX(v.visit_date),
    (ARRAY_AGG(v.relationship_temperature ORDER BY v.visit_date DESC))[1],
    (ARRAY_AGG(v.churn_risk ORDER BY v.visit_date DESC))[1],
    COALESCE(SUM(v.contract_value_rupees), 0)::bigint
  FROM public.hospital_vip_visits_r2243 v
  GROUP BY v.hospital_name
  ORDER BY COUNT(*) DESC, MAX(v.visit_date) DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.overdue_visits_hospital_vip_r2243()
RETURNS TABLE(
  hospital_name text, hospital_tier text, last_visit_date date,
  next_visit_due_date date, days_overdue int, last_temperature text, last_churn_risk text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.hospital_name, v.hospital_tier, v.visit_date,
    v.next_visit_due_date,
    (current_date - v.next_visit_due_date)::int,
    v.relationship_temperature, v.churn_risk
  FROM public.hospital_vip_visits_r2243 v
  WHERE v.next_visit_due_date IS NOT NULL
    AND v.next_visit_due_date < current_date
  ORDER BY (current_date - v.next_visit_due_date) DESC
  LIMIT 100;
END $$;

REVOKE ALL ON FUNCTION public.list_hospital_vip_visits_r2243() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.summary_hospital_vip_visits_r2243() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_hospital_vip_followups_r2243() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.temperature_breakdown_hospital_vip_r2243() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.visit_type_breakdown_hospital_vip_r2243() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_hospitals_by_visit_count_r2243() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.overdue_visits_hospital_vip_r2243() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hospital_vip_visits_r2243() TO authenticated;
GRANT EXECUTE ON FUNCTION public.summary_hospital_vip_visits_r2243() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_hospital_vip_followups_r2243() TO authenticated;
GRANT EXECUTE ON FUNCTION public.temperature_breakdown_hospital_vip_r2243() TO authenticated;
GRANT EXECUTE ON FUNCTION public.visit_type_breakdown_hospital_vip_r2243() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_visit_count_r2243() TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_visits_hospital_vip_r2243() TO authenticated;

COMMIT;
