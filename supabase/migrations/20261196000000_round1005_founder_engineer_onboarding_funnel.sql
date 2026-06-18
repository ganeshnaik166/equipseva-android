BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_onboarding_funnel();
CREATE OR REPLACE FUNCTION public.founder_engineer_onboarding_funnel()
RETURNS TABLE (
  stage           text,
  stage_order     int,
  engineers       bigint,
  pct_of_signups  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_signups bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signups
  FROM public.profiles WHERE role = 'engineer';
  IF v_signups IS NULL THEN v_signups := 0; END IF;

  RETURN QUERY
  WITH stages AS (
    SELECT '1. Signed up'::text AS stage, 1 AS stage_order, v_signups AS engineers
    UNION ALL
    SELECT '2. Profile started (bio or city)', 2,
      (SELECT count(*)::bigint FROM public.engineers e
       JOIN public.profiles p ON p.id = e.user_id
       WHERE p.role = 'engineer'
         AND (coalesce(trim(e.bio), '') <> '' OR coalesce(trim(e.city), '') <> ''))
    UNION ALL
    SELECT '3. Verified', 3,
      (SELECT count(*)::bigint FROM public.engineers e
       JOIN public.profiles p ON p.id = e.user_id
       WHERE p.role = 'engineer'
         AND e.verification_status = 'verified')
    UNION ALL
    SELECT '4. First bid placed', 4,
      (SELECT count(DISTINCT b.engineer_user_id)::bigint
       FROM public.repair_job_bids b
       JOIN public.profiles p ON p.id = b.engineer_user_id
       WHERE p.role = 'engineer')
    UNION ALL
    SELECT '5. First job completed', 5,
      (SELECT count(DISTINCT j.engineer_id)::bigint
       FROM public.repair_jobs j
       WHERE j.engineer_id IS NOT NULL AND j.status = 'completed')
    UNION ALL
    SELECT '6. First payout processed', 6,
      (SELECT count(DISTINCT po.engineer_id)::bigint
       FROM public.engineer_payouts po
       WHERE po.status IN ('processed','paid'))
  )
  SELECT
    s.stage, s.stage_order, s.engineers,
    CASE WHEN v_signups = 0 THEN 0::numeric
         ELSE round(100.0 * s.engineers / v_signups, 1) END AS pct_of_signups
  FROM stages s
  ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_onboarding_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_onboarding_funnel() TO authenticated;
COMMIT;
