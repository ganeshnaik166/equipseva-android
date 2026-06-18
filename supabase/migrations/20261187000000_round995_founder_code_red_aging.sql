BEGIN;
DROP FUNCTION IF EXISTS public.founder_code_red_aging();
CREATE OR REPLACE FUNCTION public.founder_code_red_aging()
RETURNS TABLE (
  bucket             text,
  bucket_order       int,
  cnt                bigint,
  oldest_created_at  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN r.created_at >= now() - interval '15 minutes' THEN '<15m'
        WHEN r.created_at >= now() - interval '1 hour'     THEN '15m-1h'
        WHEN r.created_at >= now() - interval '4 hours'    THEN '1-4h'
        WHEN r.created_at >= now() - interval '24 hours'   THEN '4-24h'
        WHEN r.created_at >= now() - interval '3 days'     THEN '1-3d'
        ELSE '>3d'
      END                                          AS bucket,
      CASE
        WHEN r.created_at >= now() - interval '15 minutes' THEN 1
        WHEN r.created_at >= now() - interval '1 hour'     THEN 2
        WHEN r.created_at >= now() - interval '4 hours'    THEN 3
        WHEN r.created_at >= now() - interval '24 hours'   THEN 4
        WHEN r.created_at >= now() - interval '3 days'     THEN 5
        ELSE 6
      END                                          AS bucket_order,
      r.created_at
    FROM public.code_red_requests r
    WHERE r.status NOT IN ('resolved', 'timed_out')
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint           AS cnt,
    min(a.created_at)          AS oldest_created_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_code_red_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_code_red_aging() TO authenticated;
COMMIT;
