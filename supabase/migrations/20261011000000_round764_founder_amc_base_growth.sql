BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_base_growth();
CREATE OR REPLACE FUNCTION public.founder_amc_base_growth()
RETURNS TABLE (
  month_ist  date,
  new_amcs   bigint,
  new_mrr    numeric,
  cumulative bigint,
  cum_mrr    numeric
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
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
                WHERE date_trunc('month', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
                WHERE date_trunc('month', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS mrr
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    monthly.mrr,
    sum(monthly.n) OVER (ORDER BY monthly.month_ist),
    sum(monthly.mrr) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_base_growth() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_base_growth() TO authenticated;
COMMIT;
