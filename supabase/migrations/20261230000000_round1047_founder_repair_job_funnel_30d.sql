BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_job_funnel_30d();
CREATE OR REPLACE FUNCTION public.founder_repair_job_funnel_30d()
RETURNS TABLE (
  stage           text,
  stage_order     int,
  cnt             bigint,
  pct_of_posted   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_posted bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_posted
  FROM public.repair_jobs WHERE created_at >= now() - interval '30 days';
  IF v_posted IS NULL THEN v_posted := 0; END IF;

  RETURN QUERY
  WITH stages AS (
    SELECT '1. Posted'::text AS stage, 1 AS stage_order, v_posted AS cnt
    UNION ALL
    SELECT '2. Got a bid', 2,
      (SELECT count(DISTINCT j.id)::bigint
       FROM public.repair_jobs j
       WHERE j.created_at >= now() - interval '30 days'
         AND EXISTS (SELECT 1 FROM public.repair_job_bids b WHERE b.repair_job_id = j.id))
    UNION ALL
    SELECT '3. Engineer assigned', 3,
      (SELECT count(*)::bigint FROM public.repair_jobs
       WHERE created_at >= now() - interval '30 days'
         AND engineer_id IS NOT NULL)
    UNION ALL
    SELECT '4. Completed ✓', 4,
      (SELECT count(*)::bigint FROM public.repair_jobs
       WHERE created_at >= now() - interval '30 days'
         AND status = 'completed')
    UNION ALL
    SELECT '5. Cancelled', 5,
      (SELECT count(*)::bigint FROM public.repair_jobs
       WHERE created_at >= now() - interval '30 days'
         AND status = 'cancelled')
  )
  SELECT
    s.stage, s.stage_order, s.cnt,
    CASE WHEN v_posted = 0 THEN 0::numeric
         ELSE round(100.0 * s.cnt / v_posted, 1) END
  FROM stages s
  ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_job_funnel_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_job_funnel_30d() TO authenticated;
COMMIT;
