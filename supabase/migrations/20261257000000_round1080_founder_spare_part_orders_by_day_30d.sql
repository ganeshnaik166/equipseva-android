BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_part_orders_by_day_30d();
CREATE OR REPLACE FUNCTION public.founder_spare_part_orders_by_day_30d()
RETURNS TABLE (
  day_ist        date,
  orders         bigint,
  paid           bigint,
  shipped        bigint,
  delivered      bigint,
  gmv_inr        numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(
      (now() AT TIME ZONE 'Asia/Kolkata')::date - 29,
      (now() AT TIME ZONE 'Asia/Kolkata')::date,
      interval '1 day'
    )::date AS day_ist
  )
  SELECT
    d.day_ist,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o
              WHERE (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS orders,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o
              WHERE o.payment_status = 'paid'
                AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS paid,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o
              WHERE o.order_status = 'shipped'
                AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS shipped,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders o
              WHERE o.order_status = 'delivered'
                AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS delivered,
    coalesce((SELECT sum(o.total_amount)::numeric FROM public.spare_part_orders o
              WHERE o.payment_status = 'paid'
                AND (o.created_at AT TIME ZONE 'Asia/Kolkata')::date = d.day_ist), 0)              AS gmv_inr
  FROM days d
  ORDER BY d.day_ist DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_part_orders_by_day_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_part_orders_by_day_30d() TO authenticated;
COMMIT;
