BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_contracts_by_week();
CREATE OR REPLACE FUNCTION public.founder_amc_contracts_by_week()
RETURNS TABLE (
  week_start date,
  new_amcs   bigint,
  net_mrr    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date - interval '12 weeks'),
      date_trunc('week', (now() AT TIME ZONE 'Asia/Kolkata')::date),
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE date_trunc('week', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::bigint,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE date_trunc('week', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_contracts_by_week() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_contracts_by_week() TO authenticated;
COMMIT;
