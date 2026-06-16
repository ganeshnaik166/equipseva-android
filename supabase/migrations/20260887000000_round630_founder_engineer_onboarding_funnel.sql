BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_onboarding_funnel();
CREATE OR REPLACE FUNCTION public.founder_engineer_onboarding_funnel()
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
  v_verified bigint;
  v_first_bid bigint;
  v_first_completed bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signups
    FROM public.engineers e WHERE e.created_at >= v_cohort_cutoff;

  SELECT count(*)::bigint INTO v_verified
    FROM public.engineers e
    WHERE e.created_at >= v_cohort_cutoff
      AND e.verification_status = 'verified';

  SELECT count(DISTINCT e.user_id)::bigint INTO v_first_bid
    FROM public.engineers e
    JOIN public.repair_job_bids b ON b.engineer_user_id = e.user_id
    WHERE e.created_at >= v_cohort_cutoff;

  SELECT count(DISTINCT b.engineer_user_id)::bigint INTO v_first_completed
    FROM public.engineers e
    JOIN public.repair_job_bids b ON b.engineer_user_id = e.user_id AND b.status = 'accepted'
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id AND rj.status = 'completed'
    WHERE e.created_at >= v_cohort_cutoff;

  RETURN QUERY
  SELECT
    t.stage,
    t.c::bigint,
    CASE WHEN v_signups = 0 THEN 0::numeric
         ELSE round((t.c::numeric / v_signups::numeric) * 100.0, 1) END
  FROM (VALUES
    ('1. signed up'::text,        v_signups,         1),
    ('2. verified'::text,         v_verified,        2),
    ('3. placed first bid'::text, v_first_bid,       3),
    ('4. completed first job'::text, v_first_completed, 4)
  ) AS t(stage, c, ord)
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_onboarding_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_onboarding_funnel() TO authenticated;
COMMIT;
