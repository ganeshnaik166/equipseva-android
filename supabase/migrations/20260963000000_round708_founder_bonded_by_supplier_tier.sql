BEGIN;
DROP FUNCTION IF EXISTS public.founder_bonded_by_supplier_tier();
CREATE OR REPLACE FUNCTION public.founder_bonded_by_supplier_tier()
RETURNS TABLE (
  supplier_tier  text,
  intake_rows    bigint,
  total_qty      bigint,
  total_cost     numeric,
  suppliers      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers(supplier_tier, ord) AS (
    VALUES ('OEM'::text, 1), ('AUTHORIZED'::text, 2), ('VERIFIED'::text, 3)
  )
  SELECT
    t.supplier_tier,
    coalesce((SELECT count(i.id)::bigint FROM public.bonded_parts_intake i
              JOIN public.bonded_parts_suppliers s ON s.id = i.supplier_id
             WHERE s.supplier_tier = t.supplier_tier), 0)::bigint,
    coalesce((SELECT sum(i.quantity_received)::bigint FROM public.bonded_parts_intake i
              JOIN public.bonded_parts_suppliers s ON s.id = i.supplier_id
             WHERE s.supplier_tier = t.supplier_tier), 0)::bigint,
    coalesce((SELECT sum(i.total_cost_rupees)::numeric FROM public.bonded_parts_intake i
              JOIN public.bonded_parts_suppliers s ON s.id = i.supplier_id
             WHERE s.supplier_tier = t.supplier_tier), 0)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.bonded_parts_suppliers s
             WHERE s.supplier_tier = t.supplier_tier), 0)::bigint
  FROM tiers t
  ORDER BY t.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bonded_by_supplier_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bonded_by_supplier_tier() TO authenticated;
COMMIT;
