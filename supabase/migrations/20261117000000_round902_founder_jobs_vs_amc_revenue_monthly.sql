BEGIN;
DROP FUNCTION IF EXISTS public.founder_jobs_vs_amc_revenue_monthly();
CREATE OR REPLACE FUNCTION public.founder_jobs_vs_amc_revenue_monthly()
RETURNS TABLE (
  month_ist        date,
  jobs_gross       numeric,
  amc_paid_rupees  numeric,
  total_rupees     numeric,
  amc_share_pct    numeric
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
  )
  SELECT
    m.month_ist,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              WHERE o.status='paid'
                AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric
    +
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              WHERE o.status='paid'
                AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)::numeric,
    CASE WHEN
      (coalesce((SELECT sum(rj.contracted_amount_rupees) FROM public.repair_jobs rj
                 WHERE rj.status='completed'
                   AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) +
       coalesce((SELECT sum(o.amount_rupees) FROM public.amc_payment_orders o
                 WHERE o.status='paid'
                   AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)) = 0
      THEN 0::numeric
      ELSE round(
        coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
                  WHERE o.status='paid'
                    AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
        /
        (coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
                   WHERE rj.status='completed'
                     AND date_trunc('month', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) +
         coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
                   WHERE o.status='paid'
                     AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0))
        * 100.0, 1)
    END
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_jobs_vs_amc_revenue_monthly() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_jobs_vs_amc_revenue_monthly() TO authenticated;
COMMIT;
