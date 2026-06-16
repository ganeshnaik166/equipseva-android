BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_by_model();
CREATE OR REPLACE FUNCTION public.founder_demand_by_model()
RETURNS TABLE (
  brand        text,
  model        text,
  signals_90d  bigint,
  resolved_90d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(lower(trim(s.equipment_brand)), ''), '(unknown)'),
    coalesce(nullif(lower(trim(s.equipment_model)), ''), '(unknown)'),
    count(*)::bigint,
    count(*) FILTER (WHERE s.resolved_at IS NOT NULL)::bigint
  FROM public.spare_part_demand_signals s
  WHERE s.occurred_at >= now() - interval '90 days'
  GROUP BY 1, 2
  ORDER BY signals_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_by_model() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_by_model() TO authenticated;
COMMIT;
