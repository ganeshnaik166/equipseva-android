BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_attempts_recent();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_attempts_recent()
RETURNS TABLE (
  attempt_id       uuid,
  amc_contract_id  uuid,
  hospital_name    text,
  attempt_number   int,
  status           text,
  amount_rupees    numeric,
  error_message    text,
  attempted_at     timestamptz,
  resolved_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.amc_contract_id,
    coalesce(p.full_name, '(hospital)'),
    a.attempt_number,
    a.status,
    a.amount_rupees,
    a.error_message,
    a.attempted_at,
    a.resolved_at
  FROM public.amc_renewal_attempts a
  JOIN public.amc_contracts c ON c.id = a.amc_contract_id
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE a.attempted_at >= now() - interval '30 days'
  ORDER BY a.attempted_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_recent() TO authenticated;
COMMIT;
