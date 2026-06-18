BEGIN;
DROP FUNCTION IF EXISTS public.founder_gst_invoices_by_month_by_source();
CREATE OR REPLACE FUNCTION public.founder_gst_invoices_by_month_by_source()
RETURNS TABLE (
  month_ist                       date,
  total_cnt                       bigint,
  repair_job_platform_fee_cnt     bigint,
  amc_visit_platform_fee_cnt      bigint,
  spare_part_platform_fee_cnt     bigint,
  engineer_service_cnt            bigint,
  refund_credit_note_cnt          bigint,
  amc_subscription_fee_cnt        bigint,
  total_taxable_inr               numeric,
  total_gst_inr                   numeric,
  total_invoice_inr               numeric
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
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'repair_job_platform_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_visit_platform_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'spare_part_platform_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'engineer_service_to_hospital'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'refund_credit_note'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind = 'amc_subscription_fee'
                AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(i.taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(i.total_gst_rupees)::numeric FROM public.gst_invoices i
              WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0),
    coalesce((SELECT sum(i.total_invoice_rupees)::numeric FROM public.gst_invoices i
              WHERE date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gst_invoices_by_month_by_source() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_gst_invoices_by_month_by_source() TO authenticated;
COMMIT;
