BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_balance_by_state();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_balance_by_state()
RETURNS TABLE (
  state          text,
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
  with_state AS (
    SELECT coalesce(nullif(trim(p.state), ''), '(unknown)') AS state,
           a.id, a.balance, a.monthly_fee_rupees
    FROM active a
    LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  )
  SELECT
    ws.state,
    count(*)::bigint,
    coalesce(sum(ws.balance), 0)::numeric,
    coalesce(sum(ws.monthly_fee_rupees), 0)::numeric
  FROM with_state ws
  GROUP BY ws.state
  ORDER BY total_balance DESC
  LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_state() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_state() TO authenticated;
COMMIT;
