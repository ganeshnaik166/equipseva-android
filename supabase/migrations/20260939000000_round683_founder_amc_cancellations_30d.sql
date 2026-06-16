BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_cancellations_30d();
CREATE OR REPLACE FUNCTION public.founder_amc_cancellations_30d()
RETURNS TABLE (
  contract_id      uuid,
  hospital_user_id uuid,
  display_name     text,
  amc_tier         text,
  monthly_fee      numeric,
  status           text,
  updated_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    c.amc_tier,
    c.monthly_fee_rupees,
    c.status,
    c.updated_at
  FROM public.amc_contracts c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status IN ('cancelled','renewal_failed','expired')
    AND c.updated_at >= now() - interval '30 days'
  ORDER BY c.updated_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_cancellations_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_cancellations_30d() TO authenticated;
COMMIT;
