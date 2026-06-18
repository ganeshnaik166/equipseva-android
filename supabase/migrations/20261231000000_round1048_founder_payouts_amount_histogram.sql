BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_amount_histogram();
CREATE OR REPLACE FUNCTION public.founder_payouts_amount_histogram()
RETURNS TABLE (
  bucket         text,
  bucket_order   int,
  cnt            bigint,
  total_inr      numeric,
  pct_of_total   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_tot
  FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '90 days';
  IF v_tot IS NULL THEN v_tot := 0; END IF;

  RETURN QUERY
  WITH agg AS (
    SELECT amount_inr,
      CASE
        WHEN amount_inr < 100    THEN '<₹100'
        WHEN amount_inr < 500    THEN '₹100-500'
        WHEN amount_inr < 1000   THEN '₹500-1k'
        WHEN amount_inr < 5000   THEN '₹1k-5k'
        WHEN amount_inr < 10000  THEN '₹5k-10k'
        WHEN amount_inr < 50000  THEN '₹10k-50k'
        ELSE '>₹50k'
      END AS bucket,
      CASE
        WHEN amount_inr < 100    THEN 1
        WHEN amount_inr < 500    THEN 2
        WHEN amount_inr < 1000   THEN 3
        WHEN amount_inr < 5000   THEN 4
        WHEN amount_inr < 10000  THEN 5
        WHEN amount_inr < 50000  THEN 6
        ELSE 7
      END AS bucket_order
    FROM public.engineer_payouts
    WHERE status IN ('processed','paid')
      AND queued_at >= now() - interval '90 days'
  )
  SELECT
    a.bucket::text,
    a.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    sum(a.amount_inr)::numeric                             AS total_inr,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / v_tot, 1) END        AS pct_of_total
  FROM agg a
  GROUP BY a.bucket, a.bucket_order
  ORDER BY a.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_amount_histogram() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_amount_histogram() TO authenticated;
COMMIT;
