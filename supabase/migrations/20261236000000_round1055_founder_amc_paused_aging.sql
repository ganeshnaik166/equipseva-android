BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_paused_aging();
CREATE OR REPLACE FUNCTION public.founder_amc_paused_aging()
RETURNS TABLE (
  bucket             text,
  bucket_order       int,
  cnt                bigint,
  frozen_mrr_inr     numeric,
  oldest_paused_at   timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      CASE
        WHEN c.updated_at >= now() - interval '7 days'   THEN '<7d'
        WHEN c.updated_at >= now() - interval '14 days'  THEN '7-14d'
        WHEN c.updated_at >= now() - interval '30 days'  THEN '14-30d'
        WHEN c.updated_at >= now() - interval '60 days'  THEN '30-60d'
        WHEN c.updated_at >= now() - interval '90 days'  THEN '60-90d'
        ELSE '>90d'
      END                                          AS bucket,
      CASE
        WHEN c.updated_at >= now() - interval '7 days'   THEN 1
        WHEN c.updated_at >= now() - interval '14 days'  THEN 2
        WHEN c.updated_at >= now() - interval '30 days'  THEN 3
        WHEN c.updated_at >= now() - interval '60 days'  THEN 4
        WHEN c.updated_at >= now() - interval '90 days'  THEN 5
        ELSE 6
      END                                          AS bucket_order,
      c.monthly_fee_rupees AS amount_inr,
      c.updated_at
    FROM public.amc_contracts c
    WHERE c.status = 'paused'
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    coalesce(sum(a.amount_inr), 0)::numeric                AS frozen_mrr_inr,
    min(a.paused_at)                                       AS oldest_paused_at
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_paused_aging() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_paused_aging() TO authenticated;
COMMIT;
