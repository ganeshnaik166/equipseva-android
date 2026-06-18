BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_paused_recent();
CREATE OR REPLACE FUNCTION public.founder_amc_paused_recent()
RETURNS TABLE (
  amc_contract_id   uuid,
  hospital_name     text,
  tier              text,
  monthly_fee       numeric,
  paused_at         timestamptz,
  days_paused       numeric
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
    c.monthly_fee_rupees,
    c.updated_at,
    round(extract(epoch FROM (now() - c.updated_at)) / 86400.0, 1)::numeric
  FROM public.amc_contracts c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status = 'paused'
  ORDER BY c.updated_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_paused_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_paused_recent() TO authenticated;
COMMIT;
