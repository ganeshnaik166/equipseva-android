BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_parts_revenue_by_month();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_revenue_by_month()
RETURNS TABLE (
  month_ist     date,
  paid_orders   bigint,
  gmv_inr       numeric,
  avg_inr       numeric
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
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o
              WHERE o.payment_status = 'paid'
                AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)              AS paid_orders,
    coalesce((SELECT sum(o.total_amount)::numeric FROM public.spare_part_orders o
              WHERE o.payment_status = 'paid'
                AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)              AS gmv_inr,
    CASE
      WHEN coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o
                     WHERE o.payment_status = 'paid'
                       AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0) = 0
      THEN 0::numeric
      ELSE round(coalesce((SELECT sum(o.total_amount)::numeric FROM public.spare_part_orders o
                            WHERE o.payment_status = 'paid'
                              AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 0)
                 / coalesce((SELECT count(*)::numeric FROM public.spare_part_orders o
                             WHERE o.payment_status = 'paid'
                               AND date_trunc('month', (o.created_at AT TIME ZONE 'Asia/Kolkata'))::date = m.month_ist), 1),
                 2)
    END                                                                                                                  AS avg_inr
  FROM months m
  ORDER BY m.month_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_revenue_by_month() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_revenue_by_month() TO authenticated;
COMMIT;
