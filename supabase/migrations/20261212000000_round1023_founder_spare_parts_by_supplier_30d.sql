BEGIN;
DROP FUNCTION IF EXISTS public.founder_spare_parts_by_supplier_30d();
CREATE OR REPLACE FUNCTION public.founder_spare_parts_by_supplier_30d()
RETURNS TABLE (
  supplier_name      text,
  orders             bigint,
  paid_orders        bigint,
  total_gmv_inr      numeric,
  last_order_at      timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(o2.name, '(unknown)')::text                                          AS supplier_name,
    count(*)::bigint                                                              AS orders,
    count(*) FILTER (WHERE o.payment_status = 'paid')::bigint                     AS paid_orders,
    coalesce(sum(o.total_amount) FILTER (WHERE o.payment_status = 'paid'), 0)::numeric AS total_gmv_inr,
    max(o.created_at)                                                             AS last_order_at
  FROM public.spare_part_orders o
  LEFT JOIN public.organizations o2 ON o2.id = o.supplier_org_id
  WHERE o.created_at >= now() - interval '30 days'
  GROUP BY coalesce(o2.name, '(unknown)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_spare_parts_by_supplier_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_spare_parts_by_supplier_30d() TO authenticated;
COMMIT;
