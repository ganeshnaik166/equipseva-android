BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_signals_cumulative();
CREATE OR REPLACE FUNCTION public.founder_demand_signals_cumulative()
RETURNS TABLE (
  month_ist     date,
  signals       bigint,
  cum_signals   bigint,
  resolved      bigint,
  cum_resolved  bigint
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
      coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals s
                WHERE date_trunc('month', (s.occurred_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS s,
      coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals s
                WHERE s.resolved_at IS NOT NULL
                  AND date_trunc('month', (s.resolved_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS r
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.s,
    sum(monthly.s) OVER (ORDER BY monthly.month_ist),
    monthly.r,
    sum(monthly.r) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_signals_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_signals_cumulative() TO authenticated;
COMMIT;
