BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_attempts_recent();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_attempts_recent()
RETURNS TABLE (
  attempted_at      timestamptz,
  amc_contract_id   uuid,
  hospital_name     text,
  tier              text,
  attempt_number    int,
  status            text,
  amount_rupees     numeric,
  error_message     text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    a.attempted_at,
    a.amc_contract_id,
    coalesce(p.full_name, '(no name)')::text                AS hospital_name,
    coalesce(c.amc_tier, 'unknown')::text                   AS tier,
    a.attempt_number,
    a.status,
    a.amount_rupees,
    coalesce(a.error_message, '')::text                     AS error_message
  FROM public.amc_renewal_attempts a
  JOIN public.amc_contracts c ON c.id = a.amc_contract_id
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  ORDER BY a.attempted_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_attempts_recent() TO authenticated;
COMMIT;
