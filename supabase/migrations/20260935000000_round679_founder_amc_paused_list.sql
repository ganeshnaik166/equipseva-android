BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_paused_list();
CREATE OR REPLACE FUNCTION public.founder_amc_paused_list()
RETURNS TABLE (
  contract_id      uuid,
  hospital_user_id uuid,
  display_name     text,
  amc_tier         text,
  monthly_fee      numeric,
  paused_age_days  int,
  end_date         date
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
    (extract(epoch FROM (now() - c.updated_at))::int / 86400),
    c.end_date
  FROM public.amc_contracts c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status = 'paused'
  ORDER BY c.updated_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_paused_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_paused_list() TO authenticated;
COMMIT;
