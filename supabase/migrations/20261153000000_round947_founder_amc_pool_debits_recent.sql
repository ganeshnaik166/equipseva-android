BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_debits_recent();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_debits_recent()
RETURNS TABLE (
  id              uuid,
  amc_contract_id uuid,
  hospital_name   text,
  amount_rupees   numeric,
  balance_after   numeric,
  created_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    pl.id,
    pl.amc_contract_id,
    coalesce(p.full_name, '(hospital)'),
    pl.amount_rupees,
    pl.balance_after,
    pl.created_at
  FROM public.amc_payment_pool pl
  JOIN public.amc_contracts c ON c.id = pl.amc_contract_id
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE pl.ledger_kind = 'debit'
    AND pl.created_at >= now() - interval '30 days'
  ORDER BY pl.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_debits_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_debits_recent() TO authenticated;
COMMIT;
