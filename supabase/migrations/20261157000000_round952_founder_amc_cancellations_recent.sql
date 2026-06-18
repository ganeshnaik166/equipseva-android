BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_cancellations_recent();
CREATE OR REPLACE FUNCTION public.founder_amc_cancellations_recent()
RETURNS TABLE (
  amc_contract_id  uuid,
  hospital_name    text,
  tier             text,
  status           text,
  monthly_fee      numeric,
  end_date         date,
  updated_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    coalesce(p.full_name, '(hospital)'),
    c.amc_tier,
    c.status::text,
    c.monthly_fee_rupees,
    c.end_date,
    c.updated_at
  FROM public.amc_contracts c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status IN ('cancelled','expired','renewal_failed')
    AND c.updated_at >= now() - interval '30 days'
  ORDER BY c.updated_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_cancellations_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_cancellations_recent() TO authenticated;
COMMIT;
