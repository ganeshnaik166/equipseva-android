BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_renewal_failures_list();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_failures_list()
RETURNS TABLE (
  amc_contract_id    uuid,
  hospital_user_id   uuid,
  display_name       text,
  city               text,
  monthly_fee_rupees numeric,
  end_date           date,
  days_since_end     int,
  last_attempt_at    timestamptz,
  last_error         text
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
    coalesce(nullif(trim(p.city), ''), '(unknown)'),
    c.monthly_fee_rupees,
    c.end_date,
    (now()::date - c.end_date)::int,
    (SELECT a.attempted_at FROM public.amc_renewal_attempts a
       WHERE a.amc_contract_id = c.id ORDER BY a.attempted_at DESC LIMIT 1),
    (SELECT a.error_message FROM public.amc_renewal_attempts a
       WHERE a.amc_contract_id = c.id AND a.status = 'failed'
       ORDER BY a.attempted_at DESC LIMIT 1)
  FROM public.amc_contracts c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status = 'renewal_failed'
  ORDER BY c.end_date ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_failures_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_failures_list() TO authenticated;
COMMIT;
