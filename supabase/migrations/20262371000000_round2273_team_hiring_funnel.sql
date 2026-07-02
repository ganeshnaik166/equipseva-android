BEGIN;

CREATE TABLE IF NOT EXISTS public.hiring_applicants_r2273 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_name text NOT NULL,
  applicant_email text NOT NULL,
  role_bucket text NOT NULL CHECK (role_bucket IN ('engineer','ops','sales','support','finance','product')),
  source text NOT NULL CHECK (source IN ('referral','linkedin','naukri','careers_page','agency','inbound')),
  stage text NOT NULL CHECK (stage IN ('applied','screened','interviewed','offer','joined','rejected','withdrawn')),
  applied_at timestamptz NOT NULL DEFAULT now(),
  screened_at timestamptz,
  interviewed_at timestamptz,
  offered_at timestamptz,
  joined_at timestamptz,
  rejected_at timestamptz,
  expected_ctc_lakhs numeric(8,2),
  offered_ctc_lakhs numeric(8,2),
  recruiter_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hiring_stage_events_r2273 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  applicant_id uuid NOT NULL REFERENCES public.hiring_applicants_r2273(id) ON DELETE CASCADE,
  from_stage text,
  to_stage text NOT NULL,
  moved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reason text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hiring_applicants_r2273 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hiring_stage_events_r2273 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hiring_applicants_r2273_founder_all ON public.hiring_applicants_r2273;
CREATE POLICY hiring_applicants_r2273_founder_all ON public.hiring_applicants_r2273
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hiring_stage_events_r2273_founder_all ON public.hiring_stage_events_r2273;
CREATE POLICY hiring_stage_events_r2273_founder_all ON public.hiring_stage_events_r2273
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.hiring_applicants_r2273 (applicant_name, applicant_email, role_bucket, source, stage, applied_at, screened_at, interviewed_at, offered_at, joined_at, expected_ctc_lakhs, offered_ctc_lakhs)
VALUES
 ('Asha Reddy','asha.reddy@example.com','engineer','referral','joined', now() - interval '60 days', now() - interval '55 days', now() - interval '50 days', now() - interval '45 days', now() - interval '20 days', 8.0, 7.5),
 ('Vikram Singh','vikram.singh@example.com','engineer','linkedin','offer', now() - interval '40 days', now() - interval '35 days', now() - interval '28 days', now() - interval '10 days', NULL, 9.0, 8.2),
 ('Priya Nair','priya.nair@example.com','sales','naukri','interviewed', now() - interval '30 days', now() - interval '25 days', now() - interval '15 days', NULL, NULL, 12.0, NULL),
 ('Rahul Mehta','rahul.mehta@example.com','ops','careers_page','screened', now() - interval '20 days', now() - interval '15 days', NULL, NULL, NULL, 6.0, NULL),
 ('Sneha Iyer','sneha.iyer@example.com','support','inbound','applied', now() - interval '10 days', NULL, NULL, NULL, NULL, 5.0, NULL),
 ('Karthik Rao','karthik.rao@example.com','finance','agency','rejected', now() - interval '50 days', now() - interval '45 days', now() - interval '40 days', NULL, NULL, 15.0, NULL),
 ('Meena Joshi','meena.joshi@example.com','product','referral','joined', now() - interval '90 days', now() - interval '85 days', now() - interval '78 days', now() - interval '70 days', now() - interval '40 days', 18.0, 17.0),
 ('Arjun Patel','arjun.patel@example.com','engineer','linkedin','withdrawn', now() - interval '35 days', now() - interval '30 days', now() - interval '22 days', NULL, NULL, 10.0, NULL),
 ('Divya Kumar','divya.kumar@example.com','sales','referral','joined', now() - interval '75 days', now() - interval '70 days', now() - interval '62 days', now() - interval '55 days', now() - interval '30 days', 11.0, 10.5),
 ('Rohit Bhat','rohit.bhat@example.com','ops','linkedin','interviewed', now() - interval '25 days', now() - interval '20 days', now() - interval '8 days', NULL, NULL, 7.0, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO public.hiring_stage_events_r2273 (applicant_id, from_stage, to_stage, occurred_at)
SELECT id, 'applied','screened', screened_at FROM public.hiring_applicants_r2273 WHERE screened_at IS NOT NULL
ON CONFLICT DO NOTHING;

-- 1) Funnel counts overall
CREATE OR REPLACE FUNCTION public.founder_hiring_funnel_overview_r2273()
RETURNS TABLE(stage text, applicants int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.stage, (COUNT(a.id) FILTER (WHERE a.id IS NOT NULL))::int AS applicants
  FROM (VALUES ('applied'),('screened'),('interviewed'),('offer'),('joined')) AS s(stage)
  LEFT JOIN public.hiring_applicants_r2273 a
    ON (s.stage = 'applied' AND a.applied_at IS NOT NULL)
    OR (s.stage = 'screened' AND a.screened_at IS NOT NULL)
    OR (s.stage = 'interviewed' AND a.interviewed_at IS NOT NULL)
    OR (s.stage = 'offer' AND a.offered_at IS NOT NULL)
    OR (s.stage = 'joined' AND a.joined_at IS NOT NULL)
  GROUP BY s.stage
  ORDER BY CASE s.stage WHEN 'applied' THEN 1 WHEN 'screened' THEN 2 WHEN 'interviewed' THEN 3 WHEN 'offer' THEN 4 WHEN 'joined' THEN 5 END;
END;
$$;

-- 2) Funnel per role bucket
CREATE OR REPLACE FUNCTION public.founder_hiring_funnel_by_role_r2273()
RETURNS TABLE(role_bucket text, applied int, screened int, interviewed int, offered int, joined int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.role_bucket,
    (COUNT(*) FILTER (WHERE a.applied_at IS NOT NULL))::int,
    (COUNT(*) FILTER (WHERE a.screened_at IS NOT NULL))::int,
    (COUNT(*) FILTER (WHERE a.interviewed_at IS NOT NULL))::int,
    (COUNT(*) FILTER (WHERE a.offered_at IS NOT NULL))::int,
    (COUNT(*) FILTER (WHERE a.joined_at IS NOT NULL))::int
  FROM public.hiring_applicants_r2273 a
  GROUP BY a.role_bucket
  ORDER BY a.role_bucket;
END;
$$;

-- 3) Conversion rates by role
CREATE OR REPLACE FUNCTION public.founder_hiring_conversion_r2273()
RETURNS TABLE(role_bucket text, screen_rate numeric, interview_rate numeric, offer_rate numeric, join_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.role_bucket,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE a.screened_at IS NOT NULL))::numeric
      / NULLIF((COUNT(*) FILTER (WHERE a.applied_at IS NOT NULL))::numeric, 0), 1),
    ROUND(100.0 * (COUNT(*) FILTER (WHERE a.interviewed_at IS NOT NULL))::numeric
      / NULLIF((COUNT(*) FILTER (WHERE a.screened_at IS NOT NULL))::numeric, 0), 1),
    ROUND(100.0 * (COUNT(*) FILTER (WHERE a.offered_at IS NOT NULL))::numeric
      / NULLIF((COUNT(*) FILTER (WHERE a.interviewed_at IS NOT NULL))::numeric, 0), 1),
    ROUND(100.0 * (COUNT(*) FILTER (WHERE a.joined_at IS NOT NULL))::numeric
      / NULLIF((COUNT(*) FILTER (WHERE a.offered_at IS NOT NULL))::numeric, 0), 1)
  FROM public.hiring_applicants_r2273 a
  GROUP BY a.role_bucket
  ORDER BY a.role_bucket;
END;
$$;

-- 4) Time to hire per role
CREATE OR REPLACE FUNCTION public.founder_hiring_time_to_hire_r2273()
RETURNS TABLE(role_bucket text, avg_days_to_screen numeric, avg_days_to_interview numeric, avg_days_to_offer numeric, avg_days_to_join numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.role_bucket,
    ROUND(AVG(EXTRACT(EPOCH FROM (a.screened_at - a.applied_at))/86400.0)::numeric, 1),
    ROUND(AVG(EXTRACT(EPOCH FROM (a.interviewed_at - a.screened_at))/86400.0)::numeric, 1),
    ROUND(AVG(EXTRACT(EPOCH FROM (a.offered_at - a.interviewed_at))/86400.0)::numeric, 1),
    ROUND(AVG(EXTRACT(EPOCH FROM (a.joined_at - a.offered_at))/86400.0)::numeric, 1)
  FROM public.hiring_applicants_r2273 a
  GROUP BY a.role_bucket
  ORDER BY a.role_bucket;
END;
$$;

-- 5) Active pipeline
CREATE OR REPLACE FUNCTION public.founder_hiring_active_pipeline_r2273()
RETURNS TABLE(applicant_name text, role_bucket text, stage text, source text, applied_at timestamptz, days_in_pipeline int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.applicant_name, a.role_bucket, a.stage, a.source, a.applied_at,
    EXTRACT(DAY FROM (now() - a.applied_at))::int
  FROM public.hiring_applicants_r2273 a
  WHERE a.stage NOT IN ('joined','rejected','withdrawn')
  ORDER BY a.applied_at ASC;
END;
$$;

-- 6) Source effectiveness
CREATE OR REPLACE FUNCTION public.founder_hiring_source_effectiveness_r2273()
RETURNS TABLE(source text, applied int, joined int, join_rate numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.source,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE a.joined_at IS NOT NULL))::int,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE a.joined_at IS NOT NULL))::numeric
      / NULLIF((COUNT(*))::numeric, 0), 1)
  FROM public.hiring_applicants_r2273 a
  GROUP BY a.source
  ORDER BY (COUNT(*) FILTER (WHERE a.joined_at IS NOT NULL)) DESC;
END;
$$;

-- 7) Offer CTC summary
CREATE OR REPLACE FUNCTION public.founder_hiring_offer_ctc_r2273()
RETURNS TABLE(role_bucket text, offers_count int, avg_offered_lakhs numeric, avg_expected_lakhs numeric, gap_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.role_bucket,
    (COUNT(*) FILTER (WHERE a.offered_at IS NOT NULL))::int,
    ROUND(AVG(a.offered_ctc_lakhs)::numeric, 2),
    ROUND(AVG(a.expected_ctc_lakhs)::numeric, 2),
    ROUND(100.0 * (AVG(a.offered_ctc_lakhs) - AVG(a.expected_ctc_lakhs))
      / NULLIF(AVG(a.expected_ctc_lakhs), 0), 1)
  FROM public.hiring_applicants_r2273 a
  WHERE a.offered_at IS NOT NULL
  GROUP BY a.role_bucket
  ORDER BY a.role_bucket;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_hiring_funnel_overview_r2273() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hiring_funnel_by_role_r2273() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hiring_conversion_r2273() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hiring_time_to_hire_r2273() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hiring_active_pipeline_r2273() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hiring_source_effectiveness_r2273() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_hiring_offer_ctc_r2273() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_hiring_funnel_overview_r2273() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hiring_funnel_by_role_r2273() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hiring_conversion_r2273() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hiring_time_to_hire_r2273() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hiring_active_pipeline_r2273() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hiring_source_effectiveness_r2273() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hiring_offer_ctc_r2273() TO authenticated;

COMMIT;
