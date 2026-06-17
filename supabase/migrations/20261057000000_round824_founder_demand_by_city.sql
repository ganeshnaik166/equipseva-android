BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_by_city();
CREATE OR REPLACE FUNCTION public.founder_demand_by_city()
RETURNS TABLE (
  city           text,
  signals_90d    bigint,
  reporters      bigint,
  distinct_skus  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH recent AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      d.reporter_user_id,
      coalesce(d.part_number, d.equipment_model, '(none)') AS sku
    FROM public.spare_part_demand_signals d
    LEFT JOIN public.profiles p ON p.id = d.reporter_user_id
    WHERE d.created_at >= now() - interval '90 days'
  )
  SELECT
    r.city,
    count(*)::bigint,
    count(DISTINCT r.reporter_user_id)::bigint,
    count(DISTINCT r.sku)::bigint
  FROM recent r
  GROUP BY r.city
  ORDER BY signals_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_by_city() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_by_city() TO authenticated;
COMMIT;
