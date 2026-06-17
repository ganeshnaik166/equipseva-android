BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_onboarding_funnel();
CREATE OR REPLACE FUNCTION public.founder_hospital_onboarding_funnel()
RETURNS TABLE (
  stage      text,
  cnt        bigint,
  pct_signup numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_cohort_cutoff timestamptz := now() - interval '90 days';
  v_signups bigint;
  v_first_job bigint;
  v_first_bid_received bigint;
  v_first_completed bigint;
  v_amc bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signups
    FROM public.profiles p
    WHERE p.role = 'hospital' AND p.created_at >= v_cohort_cutoff;

  SELECT count(DISTINCT rj.hospital_user_id)::bigint INTO v_first_job
    FROM public.profiles p
    JOIN public.repair_jobs rj ON rj.hospital_user_id = p.id
    WHERE p.role = 'hospital' AND p.created_at >= v_cohort_cutoff;

  SELECT count(DISTINCT rj.hospital_user_id)::bigint INTO v_first_bid_received
    FROM public.profiles p
    JOIN public.repair_jobs rj ON rj.hospital_user_id = p.id
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id
    WHERE p.role = 'hospital' AND p.created_at >= v_cohort_cutoff;

  SELECT count(DISTINCT rj.hospital_user_id)::bigint INTO v_first_completed
    FROM public.profiles p
    JOIN public.repair_jobs rj ON rj.hospital_user_id = p.id AND rj.status = 'completed'
    WHERE p.role = 'hospital' AND p.created_at >= v_cohort_cutoff;

  SELECT count(DISTINCT c.hospital_user_id)::bigint INTO v_amc
    FROM public.profiles p
    JOIN public.amc_contracts c ON c.hospital_user_id = p.id AND c.status = 'active'
    WHERE p.role = 'hospital' AND p.created_at >= v_cohort_cutoff;

  RETURN QUERY
  SELECT t.stage, t.c::bigint,
    CASE WHEN v_signups = 0 THEN 0::numeric
         ELSE round((t.c::numeric / v_signups::numeric) * 100.0, 1)
    END
  FROM (VALUES
    ('1. hospital signed up'::text,         v_signups,            1),
    ('2. posted first job'::text,           v_first_job,          2),
    ('3. received first bid'::text,         v_first_bid_received, 3),
    ('4. completed first job'::text,        v_first_completed,    4),
    ('5. active AMC'::text,                 v_amc,                5)
  ) AS t(stage, c, ord)
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_onboarding_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_onboarding_funnel() TO authenticated;
COMMIT;
