BEGIN;
DROP FUNCTION IF EXISTS public.founder_payouts_cumulative();
CREATE OR REPLACE FUNCTION public.founder_payouts_cumulative()
RETURNS TABLE (
  month_ist            date,
  monthly_processed    numeric,
  cumulative_processed numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now() - interval '11 months')::date,
      date_trunc('month', now())::date,
      interval '1 month'
    )::date AS month_ist
  ),
  monthly AS (
    SELECT
      m.month_ist,
      coalesce((SELECT sum(amount_inr)::numeric FROM public.engineer_payouts p
                WHERE p.status IN ('processed','paid')
                  AND date_trunc('month', (p.queued_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS monthly_processed
    FROM months m
  )
  SELECT
    m.month_ist,
    m.monthly_processed,
    sum(m.monthly_processed) OVER (ORDER BY m.month_ist ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::numeric
                                                AS cumulative_processed
  FROM monthly m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_payouts_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_cumulative() TO authenticated;
COMMIT;
