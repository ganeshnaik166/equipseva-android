BEGIN;
DROP FUNCTION IF EXISTS public.founder_platform_fee_cumulative();
CREATE OR REPLACE FUNCTION public.founder_platform_fee_cumulative()
RETURNS TABLE (
  month_ist            date,
  monthly_fee_inr      numeric,
  cumulative_fee_inr   numeric
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
      coalesce((SELECT sum(taxable_amount_rupees)::numeric FROM public.gst_invoices i
                WHERE i.source_kind IN ('repair_job_platform_fee','amc_visit_platform_fee','spare_part_platform_fee','amc_subscription_fee')
                  AND date_trunc('month', (i.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) AS monthly_fee_inr
    FROM months m
  )
  SELECT
    m.month_ist,
    m.monthly_fee_inr,
    sum(m.monthly_fee_inr) OVER (ORDER BY m.month_ist ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::numeric
                                                AS cumulative_fee_inr
  FROM monthly m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_platform_fee_cumulative() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_platform_fee_cumulative() TO authenticated;
COMMIT;
