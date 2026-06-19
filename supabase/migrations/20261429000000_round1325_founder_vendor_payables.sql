BEGIN;
-- Round 1325 — /founder-vendor-payables
-- Read-only supplier ledger aggregator over spare_part_orders + dental_bonded_parts_suppliers.
-- NO new tables. Two RPCs: summary + per-supplier roll-up.
--
-- Pending order = spare_part_orders.payment_status NOT IN ('paid')
--                 AND coalesce(order_status,'') NOT IN ('cancelled','refunded').
-- Overdue 30d  = pending AND created_at < now() - interval '30 days'.
-- Bonded      = supplier_org_id present in dental_bonded_parts_suppliers
--                 with bonded_status IN ('signed','active').
-- avg_days_to_pay = avg(extract(epoch from (paid_at - created_at))/86400)
--                   computed off paid orders in last 180 days. We use updated_at
--                   as proxy when paid_at column not present.



-- ============================================================================
-- 1. Summary RPC — 12 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_vendor_payables_summary();
CREATE OR REPLACE FUNCTION public.founder_vendor_payables_summary()
RETURNS TABLE (
  total_active_suppliers                 bigint,
  total_pending_orders                   bigint,
  total_pending_amount_rupees            numeric,
  total_overdue_orders_30d               bigint,
  total_overdue_amount_rupees            numeric,
  largest_pending_amount_rupees          numeric,
  top_supplier_by_pending_org_id         uuid,
  top_supplier_by_pending_name           text,
  top_supplier_by_pending_amount_rupees  numeric,
  bonded_pending_amount_rupees           numeric,
  unbonded_pending_amount_rupees         numeric,
  avg_days_to_pay                        numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_org_id  uuid;
  v_top_name    text;
  v_top_amount  numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Top supplier by pending amount (single pick).
  SELECT o.supplier_org_id,
         COALESCE(org.name, 'Unknown supplier'),
         COALESCE(sum(o.total_amount), 0)::numeric
    INTO v_top_org_id, v_top_name, v_top_amount
    FROM public.spare_part_orders o
    LEFT JOIN public.organizations org ON org.id = o.supplier_org_id
   WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
     AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
     AND o.supplier_org_id IS NOT NULL
   GROUP BY o.supplier_org_id, org.name
   ORDER BY COALESCE(sum(o.total_amount), 0) DESC NULLS LAST
   LIMIT 1;

  RETURN QUERY
  SELECT
    COALESCE((SELECT count(DISTINCT supplier_org_id)::bigint
                FROM public.spare_part_orders
               WHERE supplier_org_id IS NOT NULL
                 AND created_at >= now() - interval '180 days'), 0) AS total_active_suppliers,

    COALESCE((SELECT count(*)::bigint
                FROM public.spare_part_orders
               WHERE COALESCE(payment_status,'') NOT IN ('paid')
                 AND COALESCE(order_status,'')   NOT IN ('cancelled','refunded')), 0) AS total_pending_orders,

    COALESCE((SELECT sum(total_amount)::numeric
                FROM public.spare_part_orders
               WHERE COALESCE(payment_status,'') NOT IN ('paid')
                 AND COALESCE(order_status,'')   NOT IN ('cancelled','refunded')), 0) AS total_pending_amount_rupees,

    COALESCE((SELECT count(*)::bigint
                FROM public.spare_part_orders
               WHERE COALESCE(payment_status,'') NOT IN ('paid')
                 AND COALESCE(order_status,'')   NOT IN ('cancelled','refunded')
                 AND created_at < now() - interval '30 days'), 0) AS total_overdue_orders_30d,

    COALESCE((SELECT sum(total_amount)::numeric
                FROM public.spare_part_orders
               WHERE COALESCE(payment_status,'') NOT IN ('paid')
                 AND COALESCE(order_status,'')   NOT IN ('cancelled','refunded')
                 AND created_at < now() - interval '30 days'), 0) AS total_overdue_amount_rupees,

    COALESCE((SELECT max(total_amount)::numeric
                FROM public.spare_part_orders
               WHERE COALESCE(payment_status,'') NOT IN ('paid')
                 AND COALESCE(order_status,'')   NOT IN ('cancelled','refunded')), 0) AS largest_pending_amount_rupees,

    v_top_org_id, v_top_name, COALESCE(v_top_amount, 0),

    COALESCE((SELECT sum(o.total_amount)::numeric
                FROM public.spare_part_orders o
                JOIN public.dental_bonded_parts_suppliers b
                  ON b.supplier_org_id = o.supplier_org_id
                 AND b.bonded_status IN ('signed','active')
               WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
                 AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')), 0) AS bonded_pending_amount_rupees,

    COALESCE((SELECT sum(o.total_amount)::numeric
                FROM public.spare_part_orders o
               WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
                 AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
                 AND NOT EXISTS (
                       SELECT 1 FROM public.dental_bonded_parts_suppliers b
                        WHERE b.supplier_org_id = o.supplier_org_id
                          AND b.bonded_status IN ('signed','active'))), 0) AS unbonded_pending_amount_rupees,

    COALESCE((SELECT round(avg(extract(epoch from (updated_at - created_at)) / 86400.0)::numeric, 2)
                FROM public.spare_part_orders
               WHERE COALESCE(payment_status,'') = 'paid'
                 AND created_at >= now() - interval '180 days'
                 AND updated_at IS NOT NULL
                 AND updated_at > created_at), 0)::numeric AS avg_days_to_pay;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_vendor_payables_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vendor_payables_summary() TO authenticated;

-- ============================================================================
-- 2. Per-supplier roll-up
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_vendor_payables_by_supplier(integer);
CREATE OR REPLACE FUNCTION public.founder_vendor_payables_by_supplier(p_limit integer DEFAULT 30)
RETURNS TABLE (
  supplier_org_id          uuid,
  supplier_name            text,
  is_bonded                boolean,
  pending_orders           bigint,
  pending_amount_rupees    numeric,
  overdue_orders_30d       bigint,
  overdue_amount_rupees    numeric,
  oldest_pending_days      integer,
  last_order_at            timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    o.supplier_org_id,
    COALESCE(org.name, 'Unknown supplier')::text AS supplier_name,
    EXISTS (
      SELECT 1 FROM public.dental_bonded_parts_suppliers b
       WHERE b.supplier_org_id = o.supplier_org_id
         AND b.bonded_status IN ('signed','active')
    ) AS is_bonded,
    count(*) FILTER (
      WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
        AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
    )::bigint AS pending_orders,
    COALESCE(sum(o.total_amount) FILTER (
      WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
        AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
    ), 0)::numeric AS pending_amount_rupees,
    count(*) FILTER (
      WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
        AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
        AND o.created_at < now() - interval '30 days'
    )::bigint AS overdue_orders_30d,
    COALESCE(sum(o.total_amount) FILTER (
      WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
        AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
        AND o.created_at < now() - interval '30 days'
    ), 0)::numeric AS overdue_amount_rupees,
    COALESCE(
      EXTRACT(day FROM (now() - min(o.created_at) FILTER (
        WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
          AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
      )))::integer,
      0
    ) AS oldest_pending_days,
    max(o.created_at) AS last_order_at
  FROM public.spare_part_orders o
  LEFT JOIN public.organizations org ON org.id = o.supplier_org_id
  WHERE o.supplier_org_id IS NOT NULL
  GROUP BY o.supplier_org_id, org.name
  HAVING count(*) FILTER (
           WHERE COALESCE(o.payment_status,'') NOT IN ('paid')
             AND COALESCE(o.order_status,'')   NOT IN ('cancelled','refunded')
         ) > 0
  ORDER BY pending_amount_rupees DESC NULLS LAST
  LIMIT GREATEST(COALESCE(p_limit, 30), 1);
END;
$$;

REVOKE ALL ON FUNCTION public.founder_vendor_payables_by_supplier(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vendor_payables_by_supplier(integer) TO authenticated;

COMMENT ON FUNCTION public.founder_vendor_payables_summary() IS
  'r1325 — 12-KPI founder summary of supplier payables. Pending = payment_status<>paid AND order_status not in cancelled/refunded.';
COMMENT ON FUNCTION public.founder_vendor_payables_by_supplier(integer) IS
  'r1325 — per-supplier pending/overdue roll-up ranked by pending amount.';

COMMIT;