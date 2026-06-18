BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_earnings_distribution();
CREATE OR REPLACE FUNCTION public.founder_engineer_earnings_distribution()
RETURNS TABLE (
  bucket          text,
  bucket_order    int,
  engineer_cnt    bigint,
  total_inr       numeric,
  pct_of_total    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_tot bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH earnings AS (
    SELECT p.engineer_id, sum(p.amount_inr)::numeric AS total_earned
    FROM public.engineer_payouts p
    WHERE p.status IN ('processed','paid')
      AND p.queued_at >= now() - interval '90 days'
    GROUP BY p.engineer_id
  ),
  bucketed AS (
    SELECT
      total_earned,
      CASE
        WHEN total_earned < 1000   THEN '<₹1k'
        WHEN total_earned < 5000   THEN '₹1k-5k'
        WHEN total_earned < 10000  THEN '₹5k-10k'
        WHEN total_earned < 25000  THEN '₹10k-25k'
        WHEN total_earned < 50000  THEN '₹25k-50k'
        WHEN total_earned < 100000 THEN '₹50k-1L'
        ELSE '>₹1L'
      END                                  AS bucket,
      CASE
        WHEN total_earned < 1000   THEN 1
        WHEN total_earned < 5000   THEN 2
        WHEN total_earned < 10000  THEN 3
        WHEN total_earned < 25000  THEN 4
        WHEN total_earned < 50000  THEN 5
        WHEN total_earned < 100000 THEN 6
        ELSE 7
      END                                  AS bucket_order
    FROM earnings
  ),
  totals AS (
    SELECT count(*)::bigint AS n FROM bucketed
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                              AS engineer_cnt,
    sum(b.total_earned)::numeric                                  AS total_inr,
    CASE WHEN (SELECT n FROM totals) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / (SELECT n FROM totals), 1)
    END                                                            AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_earnings_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_earnings_distribution() TO authenticated;
COMMIT;
