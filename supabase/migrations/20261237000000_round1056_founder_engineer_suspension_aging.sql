BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_suspension_aging();
CREATE OR REPLACE FUNCTION public.founder_engineer_suspension_aging()
RETURNS TABLE (
  bucket             text,
  bucket_order       int,
  cnt                bigint,
  oldest_suspended_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN e.cash_auto_suspended_at >= now() - interval '24 hours' THEN '<24h'
        WHEN e.cash_auto_suspended_at >= now() - interval '7 days'   THEN '1-7d'
        WHEN e.cash_auto_suspended_at >= now() - interval '14 days'  THEN '7-14d'
        WHEN e.cash_auto_suspended_at >= now() - interval '30 days'  THEN '14-30d'
        WHEN e.cash_auto_suspended_at >= now() - interval '90 days'  THEN '30-90d'
        ELSE '>90d'
      END                                          AS bucket,
      CASE
        WHEN e.cash_auto_suspended_at >= now() - interval '24 hours' THEN 1
        WHEN e.cash_auto_suspended_at >= now() - interval '7 days'   THEN 2
        WHEN e.cash_auto_suspended_at >= now() - interval '14 days'  THEN 3
        WHEN e.cash_auto_suspended_at >= now() - interval '30 days'  THEN 4
        WHEN e.cash_auto_suspended_at >= now() - interval '90 days'  THEN 5
        ELSE 6
      END                                          AS bucket_order,
      e.cash_auto_suspended_at
    FROM public.engineers e
    WHERE e.cash_auto_suspended_at IS NOT NULL
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    min(a.cash_auto_suspended_at)                          AS oldest_suspended_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_suspension_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_suspension_aging() TO authenticated;
COMMIT;
