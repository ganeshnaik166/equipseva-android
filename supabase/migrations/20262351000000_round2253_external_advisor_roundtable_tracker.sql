BEGIN;

CREATE TABLE IF NOT EXISTS public.external_advisor_roundtables_r2253 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advisor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  advisor_name text NOT NULL,
  advisor_domain text NOT NULL CHECK (advisor_domain IN ('product','sales','clinical','finance','legal','operations','technology','marketing')),
  advisor_seniority text NOT NULL CHECK (advisor_seniority IN ('junior','senior','lead','c_suite')),
  meeting_quarter text NOT NULL CHECK (meeting_quarter ~ '^Q[1-4]-FY[0-9]{4}$'),
  meeting_held_on date NOT NULL,
  meeting_format text NOT NULL CHECK (meeting_format IN ('in_person','video','hybrid','async_written')),
  topics_planned int NOT NULL DEFAULT 0 CHECK (topics_planned >= 0),
  topics_covered int NOT NULL DEFAULT 0 CHECK (topics_covered >= 0),
  advice_quality_score numeric(3,1) CHECK (advice_quality_score >= 0 AND advice_quality_score <= 5),
  attendance_status text NOT NULL DEFAULT 'attended' CHECK (attendance_status IN ('attended','no_show','rescheduled','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.external_advisor_advice_items_r2253 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  roundtable_id uuid NOT NULL REFERENCES public.external_advisor_roundtables_r2253(id) ON DELETE CASCADE,
  topic text NOT NULL,
  advice_category text NOT NULL CHECK (advice_category IN ('strategy','tactical','warning','introduction','process','hiring','pricing','positioning')),
  advice_summary text NOT NULL,
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  follow_through_status text NOT NULL DEFAULT 'open' CHECK (follow_through_status IN ('open','in_progress','done','rejected','deferred')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  due_date date,
  closed_at timestamptz,
  impact_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.external_advisor_roundtables_r2253 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.external_advisor_advice_items_r2253 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.external_advisor_roundtables_r2253;
CREATE POLICY founder_all ON public.external_advisor_roundtables_r2253 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.external_advisor_advice_items_r2253;
CREATE POLICY founder_all ON public.external_advisor_advice_items_r2253 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_r2253_rt_quarter ON public.external_advisor_roundtables_r2253(meeting_quarter);
CREATE INDEX IF NOT EXISTS idx_r2253_rt_domain ON public.external_advisor_roundtables_r2253(advisor_domain);
CREATE INDEX IF NOT EXISTS idx_r2253_advice_status ON public.external_advisor_advice_items_r2253(follow_through_status);
CREATE INDEX IF NOT EXISTS idx_r2253_advice_priority ON public.external_advisor_advice_items_r2253(priority);

-- Seed
INSERT INTO public.external_advisor_roundtables_r2253 (advisor_name, advisor_domain, advisor_seniority, meeting_quarter, meeting_held_on, meeting_format, topics_planned, topics_covered, advice_quality_score, attendance_status, notes) VALUES
('Dr Prakash Menon','clinical','c_suite','Q1-FY2026', now()::date - 180, 'in_person', 6, 6, 4.8, 'attended','Hospital chain GTM advisor'),
('Vidya Iyer','sales','lead','Q1-FY2026', now()::date - 175, 'video', 5, 4, 4.2, 'attended','Enterprise B2B sales playbook'),
('Rohan Bhatt','finance','c_suite','Q2-FY2026', now()::date - 90, 'in_person', 7, 7, 4.6, 'attended','Series A prep'),
('Kavya Reddy','legal','senior','Q2-FY2026', now()::date - 85, 'video', 4, 4, 4.4, 'attended','DPDP + GST compliance'),
('Arjun Pillai','technology','lead','Q3-FY2026', now()::date - 30, 'hybrid', 8, 6, 4.0, 'attended','Mobile + offline-first architecture'),
('Meera Joshi','marketing','senior','Q3-FY2026', now()::date - 25, 'video', 5, 0, NULL, 'no_show','Rescheduled to next quarter'),
('Sandeep Rao','operations','c_suite','Q3-FY2026', now()::date - 20, 'in_person', 6, 5, 4.5, 'attended','Field-engineer ops scaling'),
('Dr Anita Verma','clinical','senior','Q3-FY2026', now()::date - 15, 'video', 4, 4, 4.7, 'attended','Bio-medical equipment regulations')
ON CONFLICT DO NOTHING;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, due_date, closed_at, impact_notes)
SELECT id, 'Tier-1 hospital pricing','pricing','Move AMC tier ceiling to Rs 50k+ for super-specialty','p1','done', now()::date + 30, now() - interval '20 days','Closed 3 deals'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Dr Prakash Menon' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, due_date, impact_notes)
SELECT id, 'Hire VP Sales','hiring','Bring in lead with hospital network rolodex','p0','in_progress', now()::date + 45,'2 candidates in pipeline'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Vidya Iyer' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, due_date, closed_at, impact_notes)
SELECT id, 'Cap table cleanup','strategy','Convert SAFE to equity before Series A','p0','done', now()::date - 10, now() - interval '5 days','Done with CA'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Rohan Bhatt' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, due_date, impact_notes)
SELECT id, 'DPDP grievance officer SOP','process','Publish 24-hour SLA on grievance portal','p1','open', now()::date + 14,'Awaiting legal review'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Kavya Reddy' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, impact_notes)
SELECT id, 'Offline-first repair-job sync','tactical','Background workmanager with conflict resolution','p2','in_progress','Engineer subteam started'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Arjun Pillai' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, impact_notes)
SELECT id, 'Engineer rotation policy','process','Rotate engineers across hospitals to prevent collusion','p1','done','Implemented in r1310'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Sandeep Rao' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, impact_notes)
SELECT id, 'CDSCO licence renewal','warning','Renewal cycle drift risk in 90 days','p0','open','Tracker created'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Dr Anita Verma' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, impact_notes)
SELECT id, 'AMC churn dashboard','tactical','Weekly churn cohort review','p2','rejected','Deferred to v0.6'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Vidya Iyer' LIMIT 1;

INSERT INTO public.external_advisor_advice_items_r2253 (roundtable_id, topic, advice_category, advice_summary, priority, follow_through_status, impact_notes)
SELECT id, 'Investor data room','strategy','Standardize on Notion + signed links','p1','deferred','Q4 priority'
FROM public.external_advisor_roundtables_r2253 WHERE advisor_name='Rohan Bhatt' LIMIT 1;

CREATE OR REPLACE FUNCTION public.r2253_summary()
RETURNS TABLE(total_roundtables int, total_advice_items int, open_items int, done_items int, p0_open int, avg_quality numeric, attendance_rate numeric, follow_through_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM external_advisor_roundtables_r2253)::int,
    (SELECT COUNT(*) FROM external_advisor_advice_items_r2253)::int,
    (SELECT COUNT(*) FILTER (WHERE follow_through_status IN ('open','in_progress')) FROM external_advisor_advice_items_r2253)::int,
    (SELECT COUNT(*) FILTER (WHERE follow_through_status='done') FROM external_advisor_advice_items_r2253)::int,
    (SELECT COUNT(*) FILTER (WHERE priority='p0' AND follow_through_status IN ('open','in_progress')) FROM external_advisor_advice_items_r2253)::int,
    (SELECT ROUND(AVG(advice_quality_score)::numeric, 2) FROM external_advisor_roundtables_r2253 WHERE advice_quality_score IS NOT NULL),
    (SELECT ROUND((COUNT(*) FILTER (WHERE attendance_status='attended'))::numeric * 100 / NULLIF(COUNT(*),0), 1) FROM external_advisor_roundtables_r2253),
    (SELECT ROUND((COUNT(*) FILTER (WHERE follow_through_status='done'))::numeric * 100 / NULLIF(COUNT(*),0), 1) FROM external_advisor_advice_items_r2253);
END $$;

CREATE OR REPLACE FUNCTION public.r2253_roundtables()
RETURNS TABLE(id uuid, advisor_name text, advisor_domain text, advisor_seniority text, meeting_quarter text, meeting_held_on date, meeting_format text, topics_planned int, topics_covered int, advice_quality_score numeric, attendance_status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.advisor_name, r.advisor_domain, r.advisor_seniority, r.meeting_quarter, r.meeting_held_on, r.meeting_format, r.topics_planned, r.topics_covered, r.advice_quality_score, r.attendance_status
  FROM external_advisor_roundtables_r2253 r
  ORDER BY r.meeting_held_on DESC NULLS LAST;
END $$;

CREATE OR REPLACE FUNCTION public.r2253_advice_items()
RETURNS TABLE(id uuid, advisor_name text, topic text, advice_category text, advice_summary text, priority text, follow_through_status text, due_date date, closed_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, r.advisor_name, a.topic, a.advice_category, a.advice_summary, a.priority, a.follow_through_status, a.due_date, a.closed_at
  FROM external_advisor_advice_items_r2253 a
  JOIN external_advisor_roundtables_r2253 r ON r.id = a.roundtable_id
  ORDER BY CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END, a.created_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2253_by_domain()
RETURNS TABLE(advisor_domain text, sessions int, advice_count int, done_count int, follow_through_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.advisor_domain,
    COUNT(DISTINCT r.id)::int,
    COUNT(a.id)::int,
    (COUNT(*) FILTER (WHERE a.follow_through_status='done'))::int,
    ROUND((COUNT(*) FILTER (WHERE a.follow_through_status='done'))::numeric * 100 / NULLIF(COUNT(a.id),0), 1)
  FROM external_advisor_roundtables_r2253 r
  LEFT JOIN external_advisor_advice_items_r2253 a ON a.roundtable_id = r.id
  GROUP BY r.advisor_domain
  ORDER BY COUNT(a.id) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2253_by_quarter()
RETURNS TABLE(meeting_quarter text, sessions int, attended int, avg_quality numeric, advice_logged int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.meeting_quarter,
    COUNT(*)::int,
    (COUNT(*) FILTER (WHERE r.attendance_status='attended'))::int,
    ROUND(AVG(r.advice_quality_score)::numeric, 2),
    (SELECT COUNT(*)::int FROM external_advisor_advice_items_r2253 a JOIN external_advisor_roundtables_r2253 r2 ON r2.id=a.roundtable_id WHERE r2.meeting_quarter = r.meeting_quarter)
  FROM external_advisor_roundtables_r2253 r
  GROUP BY r.meeting_quarter
  ORDER BY r.meeting_quarter DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2253_overdue_advice()
RETURNS TABLE(advisor_name text, topic text, priority text, due_date date, days_overdue int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.advisor_name, a.topic, a.priority, a.due_date, (CURRENT_DATE - a.due_date)::int
  FROM external_advisor_advice_items_r2253 a
  JOIN external_advisor_roundtables_r2253 r ON r.id = a.roundtable_id
  WHERE a.follow_through_status IN ('open','in_progress')
    AND a.due_date IS NOT NULL
    AND a.due_date < CURRENT_DATE
  ORDER BY (CURRENT_DATE - a.due_date) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2253_top_advisors()
RETURNS TABLE(advisor_name text, advisor_domain text, sessions int, avg_quality numeric, advice_done int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.advisor_name, MAX(r.advisor_domain),
    COUNT(DISTINCT r.id)::int,
    ROUND(AVG(r.advice_quality_score)::numeric, 2),
    (SELECT COUNT(*)::int FROM external_advisor_advice_items_r2253 a JOIN external_advisor_roundtables_r2253 r2 ON r2.id=a.roundtable_id WHERE r2.advisor_name = r.advisor_name AND a.follow_through_status='done')
  FROM external_advisor_roundtables_r2253 r
  GROUP BY r.advisor_name
  ORDER BY AVG(r.advice_quality_score) DESC NULLS LAST
  LIMIT 10;
END $$;

REVOKE ALL ON FUNCTION public.r2253_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2253_roundtables() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2253_advice_items() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2253_by_domain() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2253_by_quarter() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2253_overdue_advice() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2253_top_advisors() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2253_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2253_roundtables() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2253_advice_items() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2253_by_domain() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2253_by_quarter() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2253_overdue_advice() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2253_top_advisors() TO authenticated;

COMMIT;
