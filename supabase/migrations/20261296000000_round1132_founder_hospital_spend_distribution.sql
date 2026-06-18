BEGIN;
DROP FUNCTION IF EXISTS public.founder_hospital_spend_distribution();
CREATE OR REPLACE FUNCTION public.founder_hospital_spend_distribution()
RETURNS TABLE (
  bucket          text,
  bucket_order    int,
  hospital_cnt    bigint,
  total_inr       numeric,
  pct_of_total    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH spend AS (
    SELECT j.hospital_user_id, sum(j.hospital_amount)::numeric AS total_spent
    FROM public.repair_jobs j
    WHERE j.status = 'completed'
      AND j.completed_at >= now() - interval '90 days'
      AND j.hospital_amount IS NOT NULL
    GROUP BY j.hospital_user_id
  ),
  bucketed AS (
    SELECT
      total_spent,
      CASE
        WHEN total_spent < 5000    THEN '<₹5k'
        WHEN total_spent < 25000   THEN '₹5k-25k'
        WHEN total_spent < 50000   THEN '₹25k-50k'
        WHEN total_spent < 100000  THEN '₹50k-1L'
        WHEN total_spent < 500000  THEN '₹1L-5L'
        WHEN total_spent < 1000000 THEN '₹5L-10L'
        ELSE '>₹10L'
      END                                  AS bucket,
      CASE
        WHEN total_spent < 5000    THEN 1
        WHEN total_spent < 25000   THEN 2
        WHEN total_spent < 50000   THEN 3
        WHEN total_spent < 100000  THEN 4
        WHEN total_spent < 500000  THEN 5
        WHEN total_spent < 1000000 THEN 6
        ELSE 7
      END                                  AS bucket_order
    FROM spend
  ),
  totals AS (
    SELECT count(*)::bigint AS n FROM bucketed
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                              AS hospital_cnt,
    sum(b.total_spent)::numeric                                   AS total_inr,
    CASE WHEN (SELECT n FROM totals) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / (SELECT n FROM totals), 1)
    END                                                            AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_spend_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_spend_distribution() TO authenticated;
COMMIT;
