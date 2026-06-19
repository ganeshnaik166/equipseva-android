BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_parts_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_snapshot_summary()
RETURNS TABLE (
  total_all_time         bigint,
  paid_30d               bigint,
  paid_gmv_30d           numeric,
  pending_payment_now    bigint,
  shipped_30d            bigint,
  delivered_30d          bigint,
  cancelled_30d          bigint,
  refunded_30d           bigint,
  stuck_over_7d          bigint,
  stuck_inr_over_7d      numeric,
  distinct_buyers_30d    bigint,
  distinct_suppliers_30d bigint,
  avg_order_inr_30d      numeric,
  created_today          bigint,
  paid_today             bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'pending' AND coalesce(order_status,'') NOT IN ('cancelled','refunded')), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(order_status,'') = 'shipped' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(order_status,'') = 'delivered' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(order_status,'') = 'cancelled' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(order_status,'') = 'refunded' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded') AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(DISTINCT buyer_user_id)::bigint FROM public.spare_part_orders WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT supplier_org_id)::bigint FROM public.spare_part_orders WHERE supplier_org_id IS NOT NULL AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT round(avg(total_amount)::numeric, 2) FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND created_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders WHERE coalesce(payment_status,'') = 'paid' AND created_at >= v_today_start AND created_at < v_today_end), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_snapshot_summary() TO authenticated;
COMMIT;
