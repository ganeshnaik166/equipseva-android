BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_stuck_aging();
CREATE OR REPLACE FUNCTION public.founder_payouts_stuck_aging()
RETURNS TABLE (
  bucket           text,
  bucket_order     int,
  cnt              bigint,
  amount_inr       bigint,
  oldest_queued_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN p.queued_at >= now() - interval '24 hours' THEN '<24h'
        WHEN p.queued_at >= now() - interval '3 days'   THEN '1-3d'
        WHEN p.queued_at >= now() - interval '7 days'   THEN '3-7d'
        WHEN p.queued_at >= now() - interval '14 days'  THEN '7-14d'
        WHEN p.queued_at >= now() - interval '30 days'  THEN '14-30d'
        ELSE '>30d'
      END                                                 AS bucket,
      CASE
        WHEN p.queued_at >= now() - interval '24 hours' THEN 1
        WHEN p.queued_at >= now() - interval '3 days'   THEN 2
        WHEN p.queued_at >= now() - interval '7 days'   THEN 3
        WHEN p.queued_at >= now() - interval '14 days'  THEN 4
        WHEN p.queued_at >= now() - interval '30 days'  THEN 5
        ELSE 6
      END                                                 AS bucket_order,
      p.amount_inr,
      p.queued_at
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued', 'processing')
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                                    AS cnt,
    coalesce(sum(a.amount_inr), 0)::bigint                              AS amount_inr,
    min(a.queued_at)                                                    AS oldest_queued_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_stuck_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_stuck_aging() TO authenticated;
COMMIT;
