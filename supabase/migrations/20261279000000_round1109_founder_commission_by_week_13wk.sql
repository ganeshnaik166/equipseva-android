BEGIN;
DROP FUNCTION IF EXISTS public.founder_commission_by_week_13wk();
CREATE OR REPLACE FUNCTION public.founder_commission_by_week_13wk()
RETURNS TABLE (
  week_start         date,
  total_fees_inr     numeric,
  invoice_cnt        bigint
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
    coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
              WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                AND date_trunc('week', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS total_fees_inr,
    coalesce((SELECT count(*)::bigint FROM public.gst_invoices i
              WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                AND date_trunc('week', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = w.week_start), 0)              AS invoice_cnt
  FROM weeks w
  ORDER BY w.week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_commission_by_week_13wk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_commission_by_week_13wk() TO authenticated;
COMMIT;
