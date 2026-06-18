BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_part_order_funnel_30d();
CREATE OR REPLACE FUNCTION public.founder_spare_part_order_funnel_30d()
RETURNS TABLE (
  stage           text,
  stage_order     int,
  cnt             bigint,
  total_inr       numeric,
  pct_of_orders   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total
  FROM public.spare_part_orders WHERE created_at >= now() - interval '30 days';
  IF v_total IS NULL THEN v_total := 0; END IF;

  RETURN QUERY
  WITH cohort AS (
    SELECT * FROM public.spare_part_orders WHERE created_at >= now() - interval '30 days'
  ),
  stages AS (
    SELECT '1. Created (denominator)'::text AS stage, 1 AS stage_order,
           v_total AS cnt,
           coalesce(sum(total_amount), 0)::numeric AS total_inr
    FROM cohort
    UNION ALL
    SELECT '2. Paid', 2,
      count(*) FILTER (WHERE payment_status = 'paid')::bigint,
      coalesce(sum(total_amount) FILTER (WHERE payment_status = 'paid'), 0)::numeric
    FROM cohort
    UNION ALL
    SELECT '3. Shipped', 3,
      count(*) FILTER (WHERE order_status = 'shipped')::bigint,
      coalesce(sum(total_amount) FILTER (WHERE order_status = 'shipped'), 0)::numeric
    FROM cohort
    UNION ALL
    SELECT '4. Delivered ✓', 4,
      count(*) FILTER (WHERE order_status = 'delivered')::bigint,
      coalesce(sum(total_amount) FILTER (WHERE order_status = 'delivered'), 0)::numeric
    FROM cohort
    UNION ALL
    SELECT '5. Cancelled', 5,
      count(*) FILTER (WHERE order_status = 'cancelled')::bigint,
      coalesce(sum(total_amount) FILTER (WHERE order_status = 'cancelled'), 0)::numeric
    FROM cohort
    UNION ALL
    SELECT '6. Refunded', 6,
      count(*) FILTER (WHERE payment_status = 'refunded')::bigint,
      coalesce(sum(total_amount) FILTER (WHERE payment_status = 'refunded'), 0)::numeric
    FROM cohort
  )
  SELECT
    s.stage, s.stage_order, s.cnt, s.total_inr,
    CASE WHEN v_total = 0 THEN 0::numeric
         ELSE round(100.0 * s.cnt / v_total, 1) END
  FROM stages s
  ORDER BY s.stage_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_part_order_funnel_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_part_order_funnel_30d() TO authenticated;
COMMIT;
