BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_resolution_funnel_30d();
CREATE OR REPLACE FUNCTION public.founder_code_red_resolution_funnel_30d()
RETURNS TABLE (
  stage           text,
  stage_order     int,
  cnt             bigint,
  pct_of_total    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total
  FROM public.code_red_requests WHERE created_at >= now() - interval '30 days';
  IF v_total IS NULL THEN v_total := 0; END IF;

  RETURN QUERY
  WITH cohort AS (
    SELECT * FROM public.code_red_requests WHERE created_at >= now() - interval '30 days'
  ),
  stages AS (
    SELECT '1. Created (denominator)'::text AS stage, 1 AS stage_order, v_total AS cnt
    UNION ALL
    SELECT '2. Engineer accepted', 2,
      (SELECT count(*)::bigint FROM cohort WHERE status NOT IN ('open','timed_out','cancelled'))
    UNION ALL
    SELECT '3. Resolved ✓', 3,
      (SELECT count(*)::bigint FROM cohort WHERE status = 'resolved')
    UNION ALL
    SELECT '4. Timed out ✗', 4,
      (SELECT count(*)::bigint FROM cohort WHERE status = 'timed_out')
    UNION ALL
    SELECT '5. Cancelled', 5,
      (SELECT count(*)::bigint FROM cohort WHERE status = 'cancelled')
    UNION ALL
    SELECT '6. Still open', 6,
      (SELECT count(*)::bigint FROM cohort WHERE status = 'open')
  )
  SELECT
    s.stage, s.stage_order, s.cnt,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(100.0 * s.cnt / v_total, 1) END
  FROM stages s
  ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_resolution_funnel_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_resolution_funnel_30d() TO authenticated;
COMMIT;
