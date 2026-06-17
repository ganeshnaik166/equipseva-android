BEGIN;
DROP FUNCTION IF EXISTS public.founder_escrow_cumulative();
CREATE OR REPLACE FUNCTION public.founder_escrow_cumulative()
RETURNS TABLE (
  month_ist date,
  released_rupees   numeric,
  refunded_rupees   numeric,
  cum_released      numeric,
  cum_refunded      numeric
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
      coalesce((SELECT sum(e.amount_rupees)::numeric FROM public.repair_job_escrow e
                WHERE e.released_at IS NOT NULL
                  AND date_trunc('month', (e.released_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS rel,
      coalesce((SELECT sum(e.amount_rupees)::numeric FROM public.repair_job_escrow e
                WHERE e.refunded_at IS NOT NULL
                  AND date_trunc('month', (e.refunded_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS ref
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.rel,
    monthly.ref,
    sum(monthly.rel) OVER (ORDER BY monthly.month_ist),
    sum(monthly.ref) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_escrow_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_escrow_cumulative() TO authenticated;
COMMIT;
