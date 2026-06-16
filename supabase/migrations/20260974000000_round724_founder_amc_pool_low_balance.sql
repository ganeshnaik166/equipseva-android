BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_low_balance();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_low_balance()
RETURNS TABLE (
  contract_id       uuid,
  hospital_user_id  uuid,
  display_name      text,
  amc_tier          text,
  monthly_fee       numeric,
  pool_balance      numeric,
  buffer_months     numeric,
  end_date          date
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
  )
  SELECT
    c.id,
    c.hospital_user_id,
    coalesce(pr.full_name, '(hospital)'),
    c.amc_tier,
    c.monthly_fee_rupees,
    coalesce(l.balance_after, 0)::numeric                    AS pool_balance,
    CASE WHEN c.monthly_fee_rupees > 0
         THEN round(coalesce(l.balance_after, 0)::numeric / c.monthly_fee_rupees::numeric, 2)
         ELSE 0::numeric
    END                                                       AS buffer_months,
    c.end_date
  FROM public.amc_contracts c
  LEFT JOIN public.profiles pr ON pr.id = c.hospital_user_id
  LEFT JOIN latest l ON l.amc_contract_id = c.id
  WHERE c.status = 'active'
    AND coalesce(l.balance_after, 0) < (c.monthly_fee_rupees * 2)
  ORDER BY coalesce(l.balance_after, 0) ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_low_balance() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_low_balance() TO authenticated;
COMMIT;
