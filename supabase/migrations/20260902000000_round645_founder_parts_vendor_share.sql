BEGIN;
DROP FUNCTION IF EXISTS public.founder_parts_vendor_share();
CREATE OR REPLACE FUNCTION public.founder_parts_vendor_share()
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
    count(i.id)::bigint                                       AS intake_rows,
    coalesce(sum(i.quantity_received), 0)::bigint             AS total_qty,
    coalesce(sum(i.total_cost_rupees), 0)::numeric            AS total_cost
  FROM public.bonded_parts_suppliers s
  LEFT JOIN public.bonded_parts_intake i ON i.supplier_id = s.id
  GROUP BY s.supplier_name, s.supplier_tier
  ORDER BY total_qty DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_parts_vendor_share() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_parts_vendor_share() TO authenticated;
COMMIT;
