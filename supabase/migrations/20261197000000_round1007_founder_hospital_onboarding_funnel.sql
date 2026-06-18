BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_onboarding_funnel();
CREATE OR REPLACE FUNCTION public.founder_hospital_onboarding_funnel()
RETURNS TABLE (
  stage           text,
  stage_order     int,
  hospitals       bigint,
  pct_of_signups  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_signups bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signups
  FROM public.profiles WHERE role = 'hospital';
  IF v_signups IS NULL THEN v_signups := 0; END IF;

  RETURN QUERY
  WITH stages AS (
    SELECT '1. Signed up'::text AS stage, 1 AS stage_order, v_signups AS hospitals
    UNION ALL
    SELECT '2. Profile started (phone or avatar)', 2,
      (SELECT count(*)::bigint FROM public.profiles
       WHERE role = 'hospital'
         AND (coalesce(trim(phone), '') <> '' OR coalesce(trim(avatar_url), '') <> ''))
    UNION ALL
    SELECT '3. Posted first job', 3,
      (SELECT count(DISTINCT j.hospital_user_id)::bigint
       FROM public.repair_jobs j WHERE j.hospital_user_id IS NOT NULL)
    UNION ALL
    SELECT '4. Job got a bid', 4,
      (SELECT count(DISTINCT j.hospital_user_id)::bigint
       FROM public.repair_jobs j
       WHERE j.hospital_user_id IS NOT NULL
         AND EXISTS (SELECT 1 FROM public.repair_job_bids b WHERE b.repair_job_id = j.id))
    UNION ALL
    SELECT '5. First job completed', 5,
      (SELECT count(DISTINCT j.hospital_user_id)::bigint
       FROM public.repair_jobs j
       WHERE j.hospital_user_id IS NOT NULL AND j.status = 'completed')
    UNION ALL
    SELECT '6. First AMC purchased', 6,
      (SELECT count(DISTINCT c.hospital_user_id)::bigint
       FROM public.amc_contracts c
       WHERE c.hospital_user_id IS NOT NULL
         AND c.status IN ('active','paused','expired'))
  )
  SELECT
    s.stage, s.stage_order, s.hospitals,
    CASE WHEN v_signups = 0 THEN 0::numeric
         ELSE round(100.0 * s.hospitals / v_signups, 1) END
  FROM stages s
  ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_onboarding_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_onboarding_funnel() TO authenticated;
COMMIT;
