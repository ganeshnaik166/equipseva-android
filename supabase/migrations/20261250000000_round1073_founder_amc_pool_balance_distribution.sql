BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_balance_distribution();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_balance_distribution()
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
  FROM public.amc_contracts WHERE status = 'active';
  IF v_tot IS NULL THEN v_tot := 0; END IF;

  RETURN QUERY
  WITH balances AS (
    SELECT
      coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)::numeric AS bal
    FROM public.amc_contracts c
    WHERE c.status = 'active'
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN bal <= 0      THEN '0 / negative'
        WHEN bal < 500     THEN '<₹500'
        WHEN bal < 1000    THEN '₹500-1k'
        WHEN bal < 5000    THEN '₹1k-5k'
        WHEN bal < 10000   THEN '₹5k-10k'
        WHEN bal < 50000   THEN '₹10k-50k'
        ELSE '>₹50k'
      END                                  AS bucket,
      CASE
        WHEN bal <= 0      THEN 1
        WHEN bal < 500     THEN 2
        WHEN bal < 1000    THEN 3
        WHEN bal < 5000    THEN 4
        WHEN bal < 10000   THEN 5
        WHEN bal < 50000   THEN 6
        ELSE 7
      END                                  AS bucket_order,
      bal
    FROM balances
  )
  SELECT
    b.bucket::text,
    b.bucket_order::int,
    count(*)::bigint                                       AS cnt,
    coalesce(sum(b.bal), 0)::numeric                       AS total_inr,
    CASE WHEN v_tot = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) / v_tot, 1) END        AS pct_of_total
  FROM bucketed b
  GROUP BY b.bucket, b.bucket_order
  ORDER BY b.bucket_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_balance_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_balance_distribution() TO authenticated;
COMMIT;
