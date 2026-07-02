-- Round 2495: Hospital Chain Customer Advocacy Flywheel
-- Track hospital-chain advocates by score, activity mix, and bonus pipeline.

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_customer_advocates_r2495 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  advocate_name text NOT NULL,
  advocate_email text NOT NULL,
  advocate_score int NOT NULL DEFAULT 0 CHECK (advocate_score BETWEEN 0 AND 100),
  referrals_made int NOT NULL DEFAULT 0 CHECK (referrals_made >= 0),
  case_studies_count int NOT NULL DEFAULT 0 CHECK (case_studies_count >= 0),
  linkedin_posts_count int NOT NULL DEFAULT 0 CHECK (linkedin_posts_count >= 0),
  conference_talks_count int NOT NULL DEFAULT 0 CHECK (conference_talks_count >= 0),
  total_bonus_rupees bigint NOT NULL DEFAULT 0 CHECK (total_bonus_rupees >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','lapsed','champion','super_champion')),
  last_activity_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.advocacy_activities_r2495 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  advocate_id uuid NOT NULL REFERENCES public.chain_customer_advocates_r2495(id) ON DELETE CASCADE,
  activity_at timestamptz NOT NULL DEFAULT now(),
  activity_kind text NOT NULL CHECK (activity_kind IN ('referral','case_study','linkedin','conference','webinar','podcast')),
  value_estimate_rupees bigint NOT NULL DEFAULT 0 CHECK (value_estimate_rupees >= 0),
  bonus_paid_rupees int NOT NULL DEFAULT 0 CHECK (bonus_paid_rupees >= 0),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','cancelled','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_customer_advocates_r2495 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.advocacy_activities_r2495 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_customer_advocates_r2495;
CREATE POLICY founder_all ON public.chain_customer_advocates_r2495
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.advocacy_activities_r2495;
CREATE POLICY founder_all ON public.advocacy_activities_r2495
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.chain_customer_advocates_r2495
  (id, chain_name, advocate_name, advocate_email, advocate_score, referrals_made, case_studies_count, linkedin_posts_count, conference_talks_count, total_bonus_rupees, status, last_activity_at, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111','Apollo Hospitals','Dr Meera Rao','meera.rao@apollo.in',92,5,2,4,1,75000,'super_champion', now() - interval '3 days','Top advocate'),
  ('22222222-2222-2222-2222-222222222222','Fortis Healthcare','Dr Vinay Shah','vinay.shah@fortis.in',78,3,1,2,1,40000,'champion', now() - interval '10 days','Strong LinkedIn presence'),
  ('33333333-3333-3333-3333-333333333333','Manipal Hospitals','Dr Anjali Kumar','anjali.kumar@manipal.in',55,1,1,1,0,12000,'active', now() - interval '25 days','Warming up'),
  ('44444444-4444-4444-4444-444444444444','Max Healthcare','Dr Rohit Mehta','rohit.mehta@max.in',30,0,0,1,0,3000,'lapsed', now() - interval '70 days','Lapsed - re-engage');

INSERT INTO public.advocacy_activities_r2495
  (advocate_id, activity_at, activity_kind, value_estimate_rupees, bonus_paid_rupees, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111', now() - interval '3 days','referral',500000,25000,'completed','Apollo Chennai referral'),
  ('11111111-1111-1111-1111-111111111111', now() - interval '20 days','linkedin',0,5000,'completed','Viral post 12k views'),
  ('11111111-1111-1111-1111-111111111111', now() - interval '40 days','conference',200000,15000,'completed','AHPI Summit talk'),
  ('22222222-2222-2222-2222-222222222222', now() - interval '10 days','case_study',300000,20000,'completed','Cath lab uptime case'),
  ('22222222-2222-2222-2222-222222222222', now() - interval '5 days','webinar',0,0,'planned','Scheduled next month'),
  ('33333333-3333-3333-3333-333333333333', now() - interval '25 days','linkedin',0,3000,'completed','First post'),
  ('33333333-3333-3333-3333-333333333333', now() - interval '2 days','podcast',0,0,'planned','HealthTech podcast pencilled'),
  ('44444444-4444-4444-4444-444444444444', now() - interval '70 days','linkedin',0,3000,'completed','Single post then quiet'),
  ('44444444-4444-4444-4444-444444444444', now() - interval '90 days','referral',100000,0,'dropped','Referral dropped pre-signature');

-- RPCs
CREATE OR REPLACE FUNCTION public.list_advocates_r2495()
RETURNS TABLE (
  id uuid,
  chain_name text,
  advocate_name text,
  advocate_email text,
  advocate_score int,
  referrals_made int,
  case_studies_count int,
  linkedin_posts_count int,
  conference_talks_count int,
  total_bonus_rupees bigint,
  status text,
  last_activity_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.advocate_name, a.advocate_email, a.advocate_score,
         a.referrals_made, a.case_studies_count, a.linkedin_posts_count,
         a.conference_talks_count, a.total_bonus_rupees, a.status, a.last_activity_at
  FROM public.chain_customer_advocates_r2495 a
  ORDER BY a.advocate_score DESC, a.last_activity_at DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_advocates_r2495() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_advocates_r2495() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_activities_r2495()
RETURNS TABLE (
  id uuid,
  advocate_name text,
  chain_name text,
  activity_at timestamptz,
  activity_kind text,
  value_estimate_rupees bigint,
  bonus_paid_rupees int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ac.id, a.advocate_name, a.chain_name, ac.activity_at, ac.activity_kind,
         ac.value_estimate_rupees, ac.bonus_paid_rupees, ac.status
  FROM public.advocacy_activities_r2495 ac
  JOIN public.chain_customer_advocates_r2495 a ON a.id = ac.advocate_id
  ORDER BY ac.activity_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_activities_r2495() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_activities_r2495() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_score_advocates_r2495()
RETURNS TABLE (
  id uuid,
  chain_name text,
  advocate_name text,
  advocate_score int,
  status text,
  total_bonus_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.advocate_name, a.advocate_score, a.status, a.total_bonus_rupees
  FROM public.chain_customer_advocates_r2495 a
  ORDER BY a.advocate_score DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_score_advocates_r2495() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_score_advocates_r2495() TO authenticated;

CREATE OR REPLACE FUNCTION public.activity_kind_summary_r2495()
RETURNS TABLE (
  activity_kind text,
  activity_count bigint,
  completed_count bigint,
  total_value_rupees bigint,
  total_bonus_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ac.activity_kind,
         count(*)::bigint,
         count(*) FILTER (WHERE ac.status = 'completed')::bigint,
         COALESCE(sum(ac.value_estimate_rupees),0)::bigint,
         COALESCE(sum(ac.bonus_paid_rupees),0)::bigint
  FROM public.advocacy_activities_r2495 ac
  GROUP BY ac.activity_kind
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.activity_kind_summary_r2495() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activity_kind_summary_r2495() TO authenticated;

CREATE OR REPLACE FUNCTION public.lapsed_focus_r2495()
RETURNS TABLE (
  id uuid,
  chain_name text,
  advocate_name text,
  advocate_email text,
  advocate_score int,
  last_activity_at timestamptz,
  days_since_activity int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.advocate_name, a.advocate_email, a.advocate_score,
         a.last_activity_at,
         COALESCE(EXTRACT(DAY FROM (now() - a.last_activity_at))::int, 999)
  FROM public.chain_customer_advocates_r2495 a
  WHERE a.status = 'lapsed'
     OR (a.last_activity_at IS NOT NULL AND a.last_activity_at < now() - interval '45 days')
  ORDER BY a.last_activity_at ASC NULLS FIRST
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.lapsed_focus_r2495() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lapsed_focus_r2495() TO authenticated;

CREATE OR REPLACE FUNCTION public.bonus_pipeline_r2495()
RETURNS TABLE (
  status text,
  activity_count bigint,
  bonus_paid_rupees bigint,
  value_estimate_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ac.status,
         count(*)::bigint,
         COALESCE(sum(ac.bonus_paid_rupees),0)::bigint,
         COALESCE(sum(ac.value_estimate_rupees),0)::bigint
  FROM public.advocacy_activities_r2495 ac
  GROUP BY ac.status
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.bonus_pipeline_r2495() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bonus_pipeline_r2495() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_activity_trend_r2495()
RETURNS TABLE (
  month_start timestamptz,
  activity_count bigint,
  completed_count bigint,
  bonus_paid_rupees bigint,
  value_estimate_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', ac.activity_at)::timestamptz AS month_start,
         count(*)::bigint,
         count(*) FILTER (WHERE ac.status = 'completed')::bigint,
         COALESCE(sum(ac.bonus_paid_rupees),0)::bigint,
         COALESCE(sum(ac.value_estimate_rupees),0)::bigint
  FROM public.advocacy_activities_r2495 ac
  WHERE ac.activity_at > now() - interval '12 months'
  GROUP BY 1
  ORDER BY 1 DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_activity_trend_r2495() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_activity_trend_r2495() TO authenticated;

