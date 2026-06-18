BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_debit_events_recent();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_debit_events_recent()
RETURNS TABLE (
  created_at        timestamptz,
  amc_contract_id   uuid,
  hospital_name     text,
  tier              text,
  amount_rupees     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    pp.created_at,
    pp.amc_contract_id,
    coalesce(p.full_name, '(no name)')::text     AS hospital_name,
    coalesce(c.amc_tier, 'unknown')::text         AS tier,
    pp.amount_rupees
  FROM public.amc_payment_pool pp
  JOIN public.amc_contracts c ON c.id = pp.amc_contract_id
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE pp.ledger_kind = 'debit'
  ORDER BY pp.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_debit_events_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_debit_events_recent() TO authenticated;
COMMIT;
