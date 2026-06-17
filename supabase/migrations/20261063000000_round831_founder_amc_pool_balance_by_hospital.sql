BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_pool_balance_by_hospital();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_balance_by_hospital()
RETURNS TABLE (
  hospital_user_id    uuid,
  display_name        text,
  city                text,
  contracts           bigint,
  total_balance       numeric,
  monthly_fee_sum     numeric,
  buffer_months       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH per_hosp AS (
    SELECT c.hospital_user_id,
           count(*)::bigint                              AS contracts,
           coalesce(sum(b.balance_rupees), 0)::numeric   AS total_balance,
           coalesce(sum(c.monthly_fee_rupees), 0)::numeric AS monthly_fee_sum
    FROM public.amc_contracts c
    LEFT JOIN public.v_amc_pool_balance b ON b.amc_contract_id = c.id
    WHERE c.status = 'active'
    GROUP BY c.hospital_user_id
  )
  SELECT
    ph.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    coalesce(nullif(trim(p.city), ''), '(unknown)'),
    ph.contracts,
    ph.total_balance,
    ph.monthly_fee_sum,
    CASE WHEN ph.monthly_fee_sum = 0 THEN 0::numeric
         ELSE round(ph.total_balance / ph.monthly_fee_sum, 2)
    END
  FROM per_hosp ph
  LEFT JOIN public.profiles p ON p.id = ph.hospital_user_id
  ORDER BY ph.total_balance DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_hospital() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_balance_by_hospital() TO authenticated;
COMMIT;
