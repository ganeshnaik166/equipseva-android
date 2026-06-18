BEGIN;
DROP FUNCTION IF EXISTS public.founder_weekly_revenue_summary();
CREATE OR REPLACE FUNCTION public.founder_weekly_revenue_summary()
RETURNS TABLE (
  week_start    date,
  jobs_gross    numeric,
  amc_paid      numeric,
  parts_revenue numeric,
  total         numeric
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
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('week', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric,
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              WHERE o.status='paid'
                AND date_trunc('week', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric,
    coalesce((SELECT sum(spo.total_amount)::numeric FROM public.spare_part_orders spo
              WHERE coalesce(spo.payment_status, '') = 'paid'
                AND date_trunc('week', (spo.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric FROM public.repair_jobs rj
              WHERE rj.status='completed'
                AND date_trunc('week', (rj.completed_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric +
    coalesce((SELECT sum(o.amount_rupees)::numeric FROM public.amc_payment_orders o
              WHERE o.status='paid'
                AND date_trunc('week', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric +
    coalesce((SELECT sum(spo.total_amount)::numeric FROM public.spare_part_orders spo
              WHERE coalesce(spo.payment_status, '') = 'paid'
                AND date_trunc('week', (spo.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)::numeric
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_weekly_revenue_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_weekly_revenue_summary() TO authenticated;
COMMIT;
