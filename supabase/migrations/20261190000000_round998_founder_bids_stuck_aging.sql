BEGIN;
DROP FUNCTION IF EXISTS public.founder_bids_stuck_aging();
CREATE OR REPLACE FUNCTION public.founder_bids_stuck_aging()
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
        WHEN b.created_at >= now() - interval '1 hour'    THEN '<1h'
        WHEN b.created_at >= now() - interval '4 hours'   THEN '1-4h'
        WHEN b.created_at >= now() - interval '24 hours'  THEN '4-24h'
        WHEN b.created_at >= now() - interval '3 days'    THEN '1-3d'
        WHEN b.created_at >= now() - interval '7 days'    THEN '3-7d'
        ELSE '>7d'
      END                                          AS bucket,
      CASE
        WHEN b.created_at >= now() - interval '1 hour'    THEN 1
        WHEN b.created_at >= now() - interval '4 hours'   THEN 2
        WHEN b.created_at >= now() - interval '24 hours'  THEN 3
        WHEN b.created_at >= now() - interval '3 days'    THEN 4
        WHEN b.created_at >= now() - interval '7 days'    THEN 5
        ELSE 6
      END                                          AS bucket_order,
      b.created_at
    FROM public.repair_job_bids b
    WHERE b.status IN ('submitted', 'pending')
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
REVOKE EXECUTE ON FUNCTION public.founder_bids_stuck_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bids_stuck_aging() TO authenticated;
COMMIT;
