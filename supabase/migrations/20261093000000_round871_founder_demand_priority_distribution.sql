BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_priority_distribution();
CREATE OR REPLACE FUNCTION public.founder_demand_priority_distribution()
RETURNS TABLE (
  priority   text,
  cnt        bigint,
  resolved   bigint,
  open       bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH p(label, ord) AS (
    VALUES ('high'::text, 1), ('med', 2), ('low', 3), ('(unprioritised)', 4)
  )
  SELECT
    p.label,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals d
              WHERE d.created_at >= now() - interval '90 days'
                AND (CASE WHEN p.label = '(unprioritised)' THEN d.founder_priority IS NULL
                          ELSE d.founder_priority = p.label END)), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals d
              WHERE d.created_at >= now() - interval '90 days'
                AND d.resolved_at IS NOT NULL
                AND (CASE WHEN p.label = '(unprioritised)' THEN d.founder_priority IS NULL
                          ELSE d.founder_priority = p.label END)), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_demand_signals d
              WHERE d.created_at >= now() - interval '90 days'
                AND d.resolved_at IS NULL
                AND (CASE WHEN p.label = '(unprioritised)' THEN d.founder_priority IS NULL
                          ELSE d.founder_priority = p.label END)), 0)::bigint
  FROM p
  ORDER BY p.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_priority_distribution() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_priority_distribution() TO authenticated;
COMMIT;
