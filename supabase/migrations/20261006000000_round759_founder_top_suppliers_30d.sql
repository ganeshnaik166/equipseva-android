BEGIN;
DROP FUNCTION IF EXISTS public.founder_top_suppliers_30d();
CREATE OR REPLACE FUNCTION public.founder_top_suppliers_30d()
RETURNS TABLE (
  supplier_name text,
  supplier_tier text,
  intake_rows   bigint,
  total_qty     bigint,
  total_cost    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    s.supplier_name,
    s.supplier_tier,
    count(i.id)::bigint,
    coalesce(sum(i.quantity_received), 0)::bigint,
    coalesce(sum(i.total_cost_rupees), 0)::numeric
  FROM public.bonded_parts_suppliers s
  LEFT JOIN public.bonded_parts_intake i ON i.supplier_id = s.id
    AND i.created_at >= now() - interval '30 days'
  GROUP BY s.supplier_name, s.supplier_tier
  HAVING count(i.id) > 0
  ORDER BY total_qty DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_top_suppliers_30d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_top_suppliers_30d() TO authenticated;
COMMIT;
