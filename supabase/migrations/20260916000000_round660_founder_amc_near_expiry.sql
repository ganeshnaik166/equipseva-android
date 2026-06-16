BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_near_expiry();
CREATE OR REPLACE FUNCTION public.founder_amc_near_expiry()
RETURNS TABLE (
  contract_id       uuid,
  hospital_user_id  uuid,
  display_name      text,
  end_date          date,
  days_left         int,
  monthly_fee       numeric,
  auto_renew        boolean,
  amc_tier          text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Kolkata')::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.hospital_user_id,
    coalesce(p.full_name, '(hospital)'),
    c.end_date,
    (c.end_date - v_today)::int,
    c.monthly_fee_rupees,
    c.auto_renew,
    c.amc_tier
  FROM public.amc_contracts c
  LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
  WHERE c.status = 'active'
    AND c.end_date BETWEEN v_today AND (v_today + 30)
  ORDER BY c.end_date ASC, c.monthly_fee_rupees DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_near_expiry() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_near_expiry() TO authenticated;
COMMIT;
