BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_balance_by_city();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_balance_by_city()
RETURNS TABLE (
  city           text,
  hospitals      bigint,
  contracts      bigint,
  total_balance  numeric,
  mrr            numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH active AS (
    SELECT c.id, c.hospital_user_id, c.monthly_fee_rupees,
           coalesce(b.balance_rupees, 0)::numeric AS balance
    FROM public.amc_contracts c
    LEFT JOIN public.v_amc_pool_balance b ON b.amc_contract_id = c.id
    WHERE c.status = 'active'
  ),
  with_city AS (
    SELECT coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
           a.hospital_user_id, a.id AS contract_id, a.balance, a.monthly_fee_rupees
    FROM active a
    LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  )
  SELECT
    wc.city,
    count(DISTINCT wc.hospital_user_id)::bigint,
    count(*)::bigint,
    coalesce(sum(wc.balance), 0)::numeric,
    coalesce(sum(wc.monthly_fee_rupees), 0)::numeric
  FROM with_city wc
  GROUP BY wc.city
  ORDER BY total_balance DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_city() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_city() TO authenticated;
COMMIT;
