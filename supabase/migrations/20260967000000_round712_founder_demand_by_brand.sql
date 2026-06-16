BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_by_brand();
CREATE OR REPLACE FUNCTION public.founder_demand_by_brand()
RETURNS TABLE (
  brand          text,
  signals_90d    bigint,
  distinct_skus  bigint,
  resolved_90d   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(lower(trim(s.equipment_brand)), ''), '(unknown)') AS brand,
    count(*)::bigint AS signals_90d,
    count(DISTINCT coalesce(lower(s.part_number), '?'))::bigint        AS distinct_skus,
    count(*) FILTER (WHERE s.resolved_at IS NOT NULL)::bigint          AS resolved_90d
  FROM public.spare_part_demand_signals s
  WHERE s.occurred_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY signals_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_by_brand() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_by_brand() TO authenticated;
COMMIT;
