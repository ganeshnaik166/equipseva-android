BEGIN;
DROP FUNCTION IF EXISTS public.founder_tier_distribution_by_city();
CREATE OR REPLACE FUNCTION public.founder_tier_distribution_by_city()
RETURNS TABLE (
  city       text,
  none_cnt   bigint,
  bronze_cnt bigint,
  silver_cnt bigint,
  gold_cnt   bigint,
  total_cnt  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      coalesce(nullif(trim(p.city), ''), '(unknown)') AS city,
      coalesce(ecp.current_tier, 'none') AS tier
    FROM public.engineer_certification_progress ecp
    JOIN public.profiles p ON p.id = ecp.user_id
    WHERE p.role = 'engineer'
  )
  SELECT
    b.city,
    count(*) FILTER (WHERE b.tier = 'none')::bigint,
    count(*) FILTER (WHERE b.tier = 'bronze')::bigint,
    count(*) FILTER (WHERE b.tier = 'silver')::bigint,
    count(*) FILTER (WHERE b.tier = 'gold')::bigint,
    count(*)::bigint
  FROM base b
  GROUP BY b.city
  ORDER BY total_cnt DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_tier_distribution_by_city() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_distribution_by_city() TO authenticated;
COMMIT;
