BEGIN;
-- r1376 — /founder-spare-parts-demand-forecast — demand forecast from historic spare_part_orders.

DROP FUNCTION IF EXISTS public.founder_spare_parts_demand_forecast_summary();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_demand_forecast_summary()
RETURNS TABLE (
  total_orders_lifetime         bigint,
  orders_last_30d               bigint,
  orders_last_90d               bigint,
  orders_last_365d              bigint,
  avg_orders_per_month          numeric,
  avg_order_amount_rupees       numeric,
  top_supplier_org_id           uuid,
  top_supplier_orders_count     bigint,
  estimated_orders_next_30d     numeric,
  estimated_amount_next_30d_rupees numeric,
  pending_orders_count          bigint,
  paid_orders_amount_90d_rupees numeric,
  generated_at                  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_avg_per_month numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT coalesce((SELECT count(*) FROM public.spare_part_orders
                   WHERE created_at >= now() - interval '90 days'), 0) / 3.0
  INTO v_avg_per_month;

  RETURN QUERY
  WITH base AS (SELECT * FROM public.spare_part_orders),
  top_sup AS (
    SELECT supplier_org_id, count(*)::bigint AS c
    FROM base WHERE supplier_org_id IS NOT NULL
    GROUP BY supplier_org_id
    ORDER BY count(*) DESC NULLS LAST LIMIT 1
  )
  SELECT
    (SELECT count(*) FROM base)::bigint,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '30 days')::bigint,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '90 days')::bigint,
    (SELECT count(*) FROM base WHERE created_at >= now() - interval '365 days')::bigint,
    round(v_avg_per_month, 2),
    coalesce((SELECT avg(total_amount) FROM base WHERE total_amount IS NOT NULL), 0)::numeric,
    (SELECT supplier_org_id FROM top_sup),
    coalesce((SELECT c FROM top_sup), 0),
    round(v_avg_per_month, 2),
    coalesce((SELECT sum(total_amount) FROM base
              WHERE created_at >= now() - interval '90 days'), 0) / 3.0,
    (SELECT count(*) FROM base WHERE coalesce(payment_status,'') NOT IN ('paid','cancelled','refunded'))::bigint,
    coalesce((SELECT sum(total_amount) FROM base
              WHERE coalesce(payment_status,'') = 'paid'
                AND created_at >= now() - interval '90 days'), 0)::numeric,
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_demand_forecast_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_demand_forecast_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_spare_parts_demand_forecast_monthly_trend(int);
CREATE OR REPLACE FUNCTION public.founder_spare_parts_demand_forecast_monthly_trend(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start            date,
  order_count            int,
  total_amount_rupees    numeric,
  distinct_suppliers     int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_months int := greatest(least(coalesce(p_months, 12), 24), 1);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH months AS (
    SELECT date_trunc('month', generate_series(
      date_trunc('month', now()) - ((v_months - 1) || ' months')::interval,
      date_trunc('month', now()),
      interval '1 month'
    ))::date AS m_start
  ),
  agg AS (
    SELECT date_trunc('month', created_at)::date AS m_start,
           count(*)::int AS cnt,
           coalesce(sum(total_amount), 0)::numeric AS amt,
           count(DISTINCT supplier_org_id)::int AS sup_n
    FROM public.spare_part_orders
    WHERE created_at >= now() - ((v_months + 1) || ' months')::interval
    GROUP BY 1
  )
  SELECT m.m_start, coalesce(a.cnt, 0), coalesce(a.amt, 0), coalesce(a.sup_n, 0)
  FROM months m
  LEFT JOIN agg a ON a.m_start = m.m_start
  ORDER BY m.m_start;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_demand_forecast_monthly_trend(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_demand_forecast_monthly_trend(int) TO authenticated;

COMMIT;
