BEGIN;
DROP FUNCTION IF EXISTS public.founder_bonded_inventory();
CREATE OR REPLACE FUNCTION public.founder_bonded_inventory()
RETURNS TABLE (
  oem_brand            text,
  part_number          text,
  intake_lots          bigint,
  units_in_stock       bigint,
  units_dispatched     bigint,
  oldest_intake_days   int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    i.oem_brand,
    i.part_number,
    count(*)::bigint                                                        AS intake_lots,
    coalesce(sum(i.quantity_received) FILTER (WHERE i.status = 'in_stock'), 0)::bigint AS units_in_stock,
    coalesce(sum(i.quantity_received) FILTER (WHERE i.status = 'depleted'), 0)::bigint AS units_dispatched,
    coalesce(max(extract(epoch FROM (now() - i.intake_received_at))::int / 86400), 0) AS oldest_intake_days
  FROM public.bonded_parts_intake i
  GROUP BY i.oem_brand, i.part_number
  ORDER BY units_in_stock DESC, intake_lots DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bonded_inventory() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bonded_inventory() TO authenticated;
COMMIT;
