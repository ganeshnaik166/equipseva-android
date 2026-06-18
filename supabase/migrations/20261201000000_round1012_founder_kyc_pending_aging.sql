BEGIN;
DROP FUNCTION IF EXISTS public.founder_kyc_pending_aging();
CREATE OR REPLACE FUNCTION public.founder_kyc_pending_aging()
RETURNS TABLE (
  bucket              text,
  bucket_order        int,
  cnt                 bigint,
  oldest_created_at   timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN e.created_at >= now() - interval '24 hours' THEN '<24h'
        WHEN e.created_at >= now() - interval '3 days'   THEN '1-3d'
        WHEN e.created_at >= now() - interval '7 days'   THEN '3-7d'
        WHEN e.created_at >= now() - interval '14 days'  THEN '7-14d'
        WHEN e.created_at >= now() - interval '30 days'  THEN '14-30d'
        ELSE '>30d'
      END                                          AS bucket,
      CASE
        WHEN e.created_at >= now() - interval '24 hours' THEN 1
        WHEN e.created_at >= now() - interval '3 days'   THEN 2
        WHEN e.created_at >= now() - interval '7 days'   THEN 3
        WHEN e.created_at >= now() - interval '14 days'  THEN 4
        WHEN e.created_at >= now() - interval '30 days'  THEN 5
        ELSE 6
      END                                          AS bucket_order,
      e.created_at
    FROM public.engineers e
    WHERE coalesce(e.verification_status, 'pending') = 'pending'
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
REVOKE EXECUTE ON FUNCTION public.founder_kyc_pending_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_kyc_pending_aging() TO authenticated;
COMMIT;
