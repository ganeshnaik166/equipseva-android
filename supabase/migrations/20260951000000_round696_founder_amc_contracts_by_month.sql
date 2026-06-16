BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_contracts_by_month();
CREATE OR REPLACE FUNCTION public.founder_amc_contracts_by_month()
RETURNS TABLE (
  month_ist   date,
  new_amcs    bigint,
  net_mrr     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '11 months'),
      date_trunc('month', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 month'
    )::date AS month_ist
  )
  SELECT
    m.month_ist,
    coalesce(
      (SELECT count(*)::bigint FROM public.amc_contracts c
       WHERE date_trunc('month', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::bigint,
    coalesce(
      (SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
       WHERE date_trunc('month', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist
      ), 0)::numeric
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_contracts_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_contracts_by_month() TO authenticated;
COMMIT;
