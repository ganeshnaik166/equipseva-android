BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_cumulative();
CREATE OR REPLACE FUNCTION public.founder_payouts_cumulative()
RETURNS TABLE (
  month_ist     date,
  paid_count    bigint,
  paid_rupees   numeric,
  cum_count     bigint,
  cum_rupees    numeric
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
      coalesce((SELECT count(*)::bigint FROM public.engineer_payouts p
                WHERE p.status = 'processed'
                  AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS n,
      coalesce((SELECT round(sum(p.amount_paise)::numeric / 100.0, 2) FROM public.engineer_payouts p
                WHERE p.status = 'processed'
                  AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS r
    FROM months m
  )
  SELECT
    monthly.month_ist,
    monthly.n,
    monthly.r,
    sum(monthly.n) OVER (ORDER BY monthly.month_ist),
    sum(monthly.r) OVER (ORDER BY monthly.month_ist)
  FROM monthly
  ORDER BY monthly.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_cumulative() TO authenticated;
COMMIT;
