BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineers_by_tier_by_city();
CREATE OR REPLACE FUNCTION public.founder_engineers_by_tier_by_city()
RETURNS TABLE (
  city           text,
  total          bigint,
  gold_cnt       bigint,
  silver_cnt     bigint,
  bronze_cnt     bigint,
  none_cnt       bigint,
  verified_cnt   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(nullif(trim(e.city), ''), '(unknown)')::text                                AS city,
    count(*)::bigint                                                                      AS total,
    count(*) FILTER (WHERE e.cached_highest_tier = 'gold')::bigint                        AS gold_cnt,
    count(*) FILTER (WHERE e.cached_highest_tier = 'silver')::bigint                      AS silver_cnt,
    count(*) FILTER (WHERE e.cached_highest_tier = 'bronze')::bigint                      AS bronze_cnt,
    count(*) FILTER (WHERE e.cached_highest_tier = 'none' OR e.cached_highest_tier IS NULL)::bigint AS none_cnt,
    count(*) FILTER (WHERE e.verification_status = 'verified')::bigint                    AS verified_cnt
  FROM public.engineers e
  GROUP BY coalesce(nullif(trim(e.city), ''), '(unknown)')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineers_by_tier_by_city() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineers_by_tier_by_city() TO authenticated;
COMMIT;
