BEGIN;
DROP FUNCTION IF EXISTS public.founder_amc_revenue_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_amc_revenue_by_week_13wk()
RETURNS TABLE (
  week_start         date,
  new_mrr_inr        numeric,
  expired_mrr_inr    numeric,
  net_mrr_change     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS week_start
  )
  SELECT
    w.week_start,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE date_trunc('week', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS new_mrr_inr,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE c.status = 'expired'
                AND c.end_date IS NOT NULL
                AND date_trunc('week', c.end_date)::date = w.week_start), 0)                                              AS expired_mrr_inr,
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE date_trunc('week', (c.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)
    - coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
                WHERE c.status = 'expired'
                  AND c.end_date IS NOT NULL
                  AND date_trunc('week', c.end_date)::date = w.week_start), 0)                                             AS net_mrr_change
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_revenue_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_revenue_by_week_13wk() TO authenticated;
COMMIT;
