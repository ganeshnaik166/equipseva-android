BEGIN;
DROP FUNCTION IF EXISTS public.founder_cart_abandonment_summary();
CREATE OR REPLACE FUNCTION public.founder_cart_abandonment_summary()
RETURNS TABLE (
  active_carts            bigint,
  cart_lines_total        bigint,
  cart_value_inr          numeric,
  avg_cart_value_inr      numeric,
  unique_skus_in_carts    bigint,
  top_sku_qty             bigint,
  carts_aged_1h_plus      bigint,
  carts_aged_24h_plus     bigint,
  carts_aged_7d_plus      bigint,
  updated_today           bigint,
  orders_paid_30d         bigint,
  conversion_pct_30d      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_active_carts bigint;
  v_cart_value numeric;
  v_orders_paid_30d bigint;
  v_new_cart_users_30d bigint;
  v_converted_users_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(DISTINCT user_id)::bigint INTO v_active_carts FROM public.cart_items;

  SELECT coalesce(sum(ci.quantity * sp.price)::numeric, 0) INTO v_cart_value
    FROM public.cart_items ci
    JOIN public.spare_parts sp ON sp.id = ci.spare_part_id;

  SELECT count(*)::bigint INTO v_orders_paid_30d
    FROM public.spare_part_orders
    WHERE coalesce(payment_status,'') = 'paid'
      AND created_at >= now() - interval '30 days';

  SELECT count(DISTINCT user_id)::bigint INTO v_new_cart_users_30d
    FROM public.cart_items
    WHERE updated_at >= now() - interval '30 days';

  SELECT count(DISTINCT buyer_user_id)::bigint INTO v_converted_users_30d
    FROM public.spare_part_orders
    WHERE coalesce(payment_status,'') = 'paid'
      AND created_at >= now() - interval '30 days';

  RETURN QUERY
  SELECT
    coalesce(v_active_carts, 0),
    coalesce((SELECT count(*)::bigint FROM public.cart_items), 0),
    coalesce(v_cart_value, 0)::numeric,
    CASE WHEN coalesce(v_active_carts, 0) = 0 THEN 0::numeric
         ELSE round(v_cart_value / v_active_carts, 2) END,
    coalesce((SELECT count(DISTINCT spare_part_id)::bigint FROM public.cart_items), 0),
    coalesce((SELECT max(qty)::bigint FROM (
        SELECT sum(quantity) AS qty FROM public.cart_items GROUP BY spare_part_id
      ) s), 0),
    coalesce((SELECT count(DISTINCT user_id)::bigint FROM public.cart_items
              WHERE updated_at < now() - interval '1 hour'), 0),
    coalesce((SELECT count(DISTINCT user_id)::bigint FROM public.cart_items
              WHERE updated_at < now() - interval '24 hours'), 0),
    coalesce((SELECT count(DISTINCT user_id)::bigint FROM public.cart_items
              WHERE updated_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.cart_items
              WHERE updated_at >= v_today_start AND updated_at < v_today_end), 0),
    coalesce(v_orders_paid_30d, 0),
    CASE WHEN coalesce(v_new_cart_users_30d, 0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_converted_users_30d / v_new_cart_users_30d, 1) END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cart_abandonment_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cart_abandonment_summary() TO authenticated;
COMMIT;
