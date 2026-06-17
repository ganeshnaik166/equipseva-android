BEGIN;
DROP FUNCTION IF EXISTS public.founder_bonded_intake_cumulative();
CREATE OR REPLACE FUNCTION public.founder_bonded_intake_cumulative()
RETURNS TABLE (
  month_ist date,
  rows_in bigint,
  cum_rows bigint,
  qty bigint,
  cum_qty bigint,
  cum_cost numeric
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
      coalesce((SELECT count(*)::bigint FROM public.bonded_parts_intake i
                WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT sum(i.quantity_received)::bigint FROM public.bonded_parts_intake i
                WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS q,
      coalesce((SELECT sum(i.total_cost_rupees)::numeric FROM public.bonded_parts_intake i
                WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS c
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    sum(monthly.n) OVER (ORDER BY monthly.month_ist),
    monthly.q,
    sum(monthly.q) OVER (ORDER BY monthly.month_ist),
    sum(monthly.c) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bonded_intake_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bonded_intake_cumulative() TO authenticated;
COMMIT;
