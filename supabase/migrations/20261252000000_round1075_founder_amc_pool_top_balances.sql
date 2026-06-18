BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_top_balances();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_top_balances()
RETURNS TABLE (
  amc_contract_id   uuid,
  hospital_name     text,
  tier              text,
  monthly_fee       numeric,
  pool_balance      numeric,
  end_date          date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    c.id                                                                       AS amc_contract_id,
    coalesce(p.full_name, '(no name)')::text                                   AS hospital_name,
    coalesce(c.amc_tier, 'unknown')::text                                      AS tier,
    c.monthly_fee_rupees                                                       AS monthly_fee,
    coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)::numeric AS pool_balance,
    c.end_date
  FROM public.amc_contracts c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status = 'active'
  ORDER BY coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)::numeric DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_top_balances() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_top_balances() TO authenticated;
COMMIT;
