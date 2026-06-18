BEGIN;
DROP FUNCTION IF EXISTS public.founder_platform_fee_revenue_by_month();
CREATE OR REPLACE FUNCTION public.founder_platform_fee_revenue_by_month()
RETURNS TABLE (
  month_ist        date,
  repair_job_fee   numeric,
  amc_visit_fee    numeric,
  spare_part_fee   numeric,
  amc_sub_fee      numeric,
  total_fee_inr    numeric
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
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'repair_job_platform_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_visit_platform_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'spare_part_platform_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_subscription_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_platform_fee_revenue_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_platform_fee_revenue_by_month() TO authenticated;
COMMIT;
