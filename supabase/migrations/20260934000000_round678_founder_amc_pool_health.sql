BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_health();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_health()
RETURNS TABLE (
  bucket           text,
  contract_count   bigint,
  total_balance    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (p.amc_contract_id)
      p.amc_contract_id,
      p.balance_after
    FROM public.amc_payment_pool p
    ORDER BY p.amc_contract_id, p.created_at DESC
  ),
  buckets(label, ord) AS (
    VALUES
      ('Healthy (>= Rs.1000)'::text,    1),
      ('Low (0 - Rs.1000)'::text,        2),
      ('Empty (= 0)'::text,             3),
      ('Negative (< 0)'::text,          4)
  )
  SELECT b.label,
    coalesce(count(*) FILTER (
      WHERE (b.ord = 1 AND l.balance_after >= 1000)
         OR (b.ord = 2 AND l.balance_after > 0 AND l.balance_after < 1000)
         OR (b.ord = 3 AND l.balance_after = 0)
         OR (b.ord = 4 AND l.balance_after < 0)
    ), 0)::bigint,
    coalesce(sum(l.balance_after) FILTER (
      WHERE (b.ord = 1 AND l.balance_after >= 1000)
         OR (b.ord = 2 AND l.balance_after > 0 AND l.balance_after < 1000)
         OR (b.ord = 3 AND l.balance_after = 0)
         OR (b.ord = 4 AND l.balance_after < 0)
    ), 0)::numeric
  FROM buckets b LEFT JOIN latest l ON TRUE
  GROUP BY b.label, b.ord
  ORDER BY b.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_health() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_health() TO authenticated;
COMMIT;
