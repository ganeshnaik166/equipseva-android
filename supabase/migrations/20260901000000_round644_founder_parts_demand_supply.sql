BEGIN;
DROP FUNCTION IF EXISTS public.founder_parts_demand_supply();
CREATE OR REPLACE FUNCTION public.founder_parts_demand_supply()
RETURNS TABLE (
  brand          text,
  part_number    text,
  demand_signals bigint,
  in_stock       bigint,
  gap            bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH demand AS (
    SELECT
      coalesce(nullif(lower(trim(s.equipment_brand)), ''), '(unknown)') AS brand,
      coalesce(nullif(lower(trim(s.part_number)), ''),    '(unknown)') AS part_number,
      count(*)::bigint AS cnt
    FROM public.spare_part_demand_signals s
    WHERE s.occurred_at >= now() - interval '90 days'
    GROUP BY 1, 2
  ),
  supply AS (
    SELECT
      lower(trim(i.oem_brand))   AS brand,
      lower(trim(i.part_number)) AS part_number,
      coalesce(sum(i.quantity_received), 0)::bigint AS qty
    FROM public.bonded_parts_intake i
    WHERE i.status = 'in_stock'
    GROUP BY 1, 2
  )
  SELECT
    d.brand,
    d.part_number,
    d.cnt,
    coalesce(s.qty, 0)::bigint,
    (d.cnt - coalesce(s.qty, 0))::bigint AS gap
  FROM demand d
  LEFT JOIN supply s ON s.brand = d.brand AND s.part_number = d.part_number
  ORDER BY gap DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_parts_demand_supply() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_parts_demand_supply() TO authenticated;
COMMIT;
