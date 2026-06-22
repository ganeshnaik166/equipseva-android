BEGIN;

CREATE TABLE IF NOT EXISTS public.org_chart_target_roles_r2281 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_code text NOT NULL UNIQUE,
  role_title text NOT NULL,
  department text NOT NULL,
  level text NOT NULL CHECK (level IN ('exec','lead','senior','mid','junior')),
  target_headcount int NOT NULL CHECK (target_headcount >= 0),
  current_headcount int NOT NULL DEFAULT 0,
  reports_to_role_code text,
  monthly_cost_rupees bigint NOT NULL DEFAULT 0,
  hiring_priority text NOT NULL DEFAULT 'medium' CHECK (hiring_priority IN ('critical','high','medium','low')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.org_chart_drift_events_r2281 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_code text NOT NULL REFERENCES public.org_chart_target_roles_r2281(role_code) ON DELETE CASCADE,
  drift_type text NOT NULL CHECK (drift_type IN ('gap','surplus','restructure','aligned')),
  drift_delta int NOT NULL,
  recommendation text NOT NULL,
  detected_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_by uuid REFERENCES public.profiles(id),
  acknowledged_at timestamptz,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_drift_events_role_2281 ON public.org_chart_drift_events_r2281(role_code, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_drift_events_type_2281 ON public.org_chart_drift_events_r2281(drift_type, detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_target_dept_2281 ON public.org_chart_target_roles_r2281(department, level);

ALTER TABLE public.org_chart_target_roles_r2281 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.org_chart_drift_events_r2281 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.org_chart_target_roles_r2281;
CREATE POLICY founder_all ON public.org_chart_target_roles_r2281
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.org_chart_drift_events_r2281;
CREATE POLICY founder_all ON public.org_chart_drift_events_r2281
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed target org chart
INSERT INTO public.org_chart_target_roles_r2281 (role_code, role_title, department, level, target_headcount, current_headcount, reports_to_role_code, monthly_cost_rupees, hiring_priority, notes) VALUES
  ('ceo','Chief Executive Officer','executive','exec',1,1,NULL,800000,'low','Founder seat'),
  ('cto','Chief Technology Officer','engineering','exec',1,0,'ceo',650000,'critical','Open — blocking platform scale'),
  ('coo','Chief Operating Officer','operations','exec',1,1,'ceo',600000,'low','Filled'),
  ('vp_eng','VP Engineering','engineering','lead',1,1,'cto',450000,'medium','Acting CTO'),
  ('eng_lead_android','Android Engineering Lead','engineering','lead',1,1,'vp_eng',280000,'low','Filled'),
  ('eng_lead_web','Web Engineering Lead','engineering','lead',1,2,'vp_eng',280000,'medium','Surplus — restructure'),
  ('sr_android','Senior Android Engineer','engineering','senior',3,2,'eng_lead_android',180000,'high','1 open seat'),
  ('sr_web','Senior Web Engineer','engineering','senior',3,4,'eng_lead_web',180000,'medium','Surplus 1'),
  ('field_ops_head','Head of Field Ops','operations','lead',1,1,'coo',350000,'low','Filled'),
  ('regional_mgr','Regional Operations Manager','operations','senior',5,3,'field_ops_head',150000,'critical','2 gaps Tier-2 cities'),
  ('engineer_mgr','Engineer Network Manager','operations','mid',3,2,'field_ops_head',95000,'high','1 gap'),
  ('amc_ops_lead','AMC Operations Lead','operations','lead',1,0,'coo',280000,'critical','Blocking AMC scale'),
  ('cs_head','Head of Customer Success','customer_success','lead',1,1,'coo',300000,'low','Filled'),
  ('cs_agent','Customer Success Agent','customer_success','junior',8,5,'cs_head',45000,'high','3 gaps'),
  ('finance_head','Head of Finance','finance','lead',1,1,'ceo',400000,'low','Filled'),
  ('finance_analyst','Finance Analyst','finance','mid',2,3,'finance_head',120000,'low','Surplus 1'),
  ('gst_compliance','GST + Compliance Officer','finance','mid',1,0,'finance_head',110000,'critical','GST filing risk'),
  ('hr_head','Head of People','hr','lead',1,0,'ceo',280000,'critical','No HR — 60+ headcount'),
  ('hr_recruiter','Talent Acquisition','hr','mid',2,0,'hr_head',95000,'high','Hiring is blocked'),
  ('marketing_head','Head of Marketing','marketing','lead',1,1,'ceo',280000,'low','Filled'),
  ('content_writer','Content + ASO Writer','marketing','mid',1,0,'marketing_head',85000,'medium','Open'),
  ('data_analyst','Senior Data Analyst','engineering','senior',2,1,'vp_eng',180000,'high','1 gap'),
  ('qa_lead','QA Lead','engineering','lead',1,0,'vp_eng',220000,'critical','Manual QA only today'),
  ('security_eng','Security Engineer','engineering','senior',1,0,'cto',250000,'critical','No security hire'),
  ('legal_counsel','In-house Legal','legal','lead',1,0,'ceo',350000,'high','Outsourced today')
ON CONFLICT (role_code) DO NOTHING;

-- Seed drift events
INSERT INTO public.org_chart_drift_events_r2281 (role_code, drift_type, drift_delta, recommendation, detected_at) VALUES
  ('cto','gap',-1,'Run executive search via top-tier recruiter; aim to close in 12 weeks. Acting VP Eng can bridge.', now() - interval '3 days'),
  ('eng_lead_web','surplus',1,'Promote one lead to Principal Engineer IC track; collapse to single lead seat.', now() - interval '2 days'),
  ('sr_android','gap',-1,'Open 1 senior Android req; prioritize Hyderabad/Bangalore market.', now() - interval '5 days'),
  ('sr_web','surplus',1,'Reallocate 1 web senior to platform/infra team; do not backfill on attrition.', now() - interval '1 day'),
  ('regional_mgr','gap',-2,'Critical Tier-2 expansion blocker — open 2 reqs in Pune + Ahmedabad markets immediately.', now() - interval '7 days'),
  ('engineer_mgr','gap',-1,'1 gap; promote top regional manager internally if possible.', now() - interval '4 days'),
  ('amc_ops_lead','gap',-1,'BLOCKING AMC scale — direct founder-led search; offer equity.', now() - interval '10 days'),
  ('cs_agent','gap',-3,'3 junior CS gaps; batch hire via campus + outsource overflow temporarily.', now() - interval '6 days'),
  ('finance_analyst','surplus',1,'Cross-train 1 analyst into FP&A specialist; do not backfill.', now() - interval '2 days'),
  ('gst_compliance','gap',-1,'CRITICAL — GST filing slipping; hire dedicated compliance officer within 4 weeks.', now() - interval '14 days'),
  ('hr_head','gap',-1,'Headcount past 60 with no HR head — hire Head of People immediately.', now() - interval '21 days'),
  ('hr_recruiter','gap',-2,'Hiring pipeline blocked; bring in 2 recruiters as soon as HR head joins.', now() - interval '20 days'),
  ('content_writer','gap',-1,'Marketing content velocity low — open req or contract.', now() - interval '8 days'),
  ('data_analyst','gap',-1,'Founder reports manually pulled — 1 senior analyst gap.', now() - interval '9 days'),
  ('qa_lead','gap',-1,'CRITICAL — no QA leadership; quality gates ad-hoc. Hire within 8 weeks.', now() - interval '12 days'),
  ('security_eng','gap',-1,'CRITICAL — DPDP + payment data risk; security engineer gap.', now() - interval '15 days'),
  ('legal_counsel','gap',-1,'Outsourced legal expensive — in-house counsel will pay back in 9 months.', now() - interval '11 days'),
  ('ceo','aligned',0,'Filled', now() - interval '30 days'),
  ('coo','aligned',0,'Filled', now() - interval '30 days'),
  ('eng_lead_android','aligned',0,'Filled', now() - interval '30 days')
;

CREATE OR REPLACE FUNCTION public.r2281_org_summary()
RETURNS TABLE(total_target int, total_current int, total_gaps int, total_surplus int, monthly_gap_cost_rupees bigint, critical_gaps int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COALESCE(SUM(target_headcount),0))::int,
    (COALESCE(SUM(current_headcount),0))::int,
    (COALESCE(SUM(GREATEST(target_headcount - current_headcount, 0)),0))::int,
    (COALESCE(SUM(GREATEST(current_headcount - target_headcount, 0)),0))::int,
    COALESCE(SUM(GREATEST(target_headcount - current_headcount, 0) * monthly_cost_rupees), 0)::bigint,
    (COUNT(*) FILTER (WHERE hiring_priority = 'critical' AND current_headcount < target_headcount))::int
  FROM public.org_chart_target_roles_r2281;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2281_dept_breakdown()
RETURNS TABLE(department text, target_seats int, filled_seats int, gap_seats int, surplus_seats int, monthly_cost_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.department,
    (SUM(t.target_headcount))::int,
    (SUM(LEAST(t.current_headcount, t.target_headcount)))::int,
    (SUM(GREATEST(t.target_headcount - t.current_headcount, 0)))::int,
    (SUM(GREATEST(t.current_headcount - t.target_headcount, 0)))::int,
    (SUM(t.current_headcount * t.monthly_cost_rupees))::bigint
  FROM public.org_chart_target_roles_r2281 t
  GROUP BY t.department
  ORDER BY (SUM(GREATEST(t.target_headcount - t.current_headcount, 0))) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2281_critical_gaps()
RETURNS TABLE(role_code text, role_title text, department text, target_headcount int, current_headcount int, gap int, monthly_cost_rupees bigint, hiring_priority text, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.role_code, t.role_title, t.department, t.target_headcount, t.current_headcount,
    (t.target_headcount - t.current_headcount)::int,
    t.monthly_cost_rupees, t.hiring_priority, t.notes
  FROM public.org_chart_target_roles_r2281 t
  WHERE t.current_headcount < t.target_headcount
  ORDER BY
    CASE t.hiring_priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    (t.target_headcount - t.current_headcount) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2281_surplus_roles()
RETURNS TABLE(role_code text, role_title text, department text, target_headcount int, current_headcount int, surplus int, monthly_cost_rupees bigint, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.role_code, t.role_title, t.department, t.target_headcount, t.current_headcount,
    (t.current_headcount - t.target_headcount)::int,
    t.monthly_cost_rupees, t.notes
  FROM public.org_chart_target_roles_r2281 t
  WHERE t.current_headcount > t.target_headcount
  ORDER BY (t.current_headcount - t.target_headcount) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2281_recent_drift_events()
RETURNS TABLE(role_code text, role_title text, drift_type text, drift_delta int, recommendation text, detected_at timestamptz, acknowledged_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.role_code, t.role_title, e.drift_type, e.drift_delta, e.recommendation, e.detected_at, e.acknowledged_at
  FROM public.org_chart_drift_events_r2281 e
  JOIN public.org_chart_target_roles_r2281 t ON t.role_code = e.role_code
  ORDER BY e.detected_at DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2281_level_distribution()
RETURNS TABLE(level text, target_count int, current_count int, drift int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.level,
    (SUM(t.target_headcount))::int,
    (SUM(t.current_headcount))::int,
    (SUM(t.current_headcount - t.target_headcount))::int
  FROM public.org_chart_target_roles_r2281 t
  GROUP BY t.level
  ORDER BY CASE t.level WHEN 'exec' THEN 1 WHEN 'lead' THEN 2 WHEN 'senior' THEN 3 WHEN 'mid' THEN 4 ELSE 5 END;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2281_restructure_recommendations()
RETURNS TABLE(role_code text, role_title text, current_headcount int, target_headcount int, recommendation text, monthly_cost_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (e.role_code)
    e.role_code, t.role_title, t.current_headcount, t.target_headcount,
    e.recommendation, t.monthly_cost_rupees
  FROM public.org_chart_drift_events_r2281 e
  JOIN public.org_chart_target_roles_r2281 t ON t.role_code = e.role_code
  WHERE e.drift_type IN ('surplus','restructure')
  ORDER BY e.role_code, e.detected_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.r2281_org_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2281_dept_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2281_critical_gaps() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2281_surplus_roles() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2281_recent_drift_events() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2281_level_distribution() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2281_restructure_recommendations() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2281_org_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2281_dept_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2281_critical_gaps() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2281_surplus_roles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2281_recent_drift_events() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2281_level_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2281_restructure_recommendations() TO authenticated;

COMMIT;
