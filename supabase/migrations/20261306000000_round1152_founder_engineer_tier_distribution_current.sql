BEGIN;
DROP FUNCTION IF EXISTS public.founder_engineer_tier_distribution_current();
CREATE OR REPLACE FUNCTION public.founder_engineer_tier_distribution_current()
RETURNS TABLE (
  tier               text,
  engineer_cnt       bigint,
  verified_cnt       bigint,
  active_30d_cnt     bigint,
  verified_pct       numeric,
  active_30d_pct     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(e.cached_highest_tier, 'none')::text                                                            AS tier,
    count(*)::bigint                                                                                          AS engineer_cnt,
    count(*) FILTER (WHERE e.verification_status = 'verified')::bigint                                        AS verified_cnt,
    count(*) FILTER (WHERE EXISTS (
      SELECT 1 FROM public.repair_jobs j
      WHERE j.engineer_id = e.id
        AND j.status = 'completed'
        AND j.completed_at >= now() - interval '30 days'
    ))::bigint                                                                                                AS active_30d_cnt,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE e.verification_status = 'verified')::numeric / count(*), 1) END    AS verified_pct,
    CASE WHEN count(*) = 0 THEN 0::numeric
         ELSE round(100.0 * count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM public.repair_jobs j
           WHERE j.engineer_id = e.id
             AND j.status = 'completed'
             AND j.completed_at >= now() - interval '30 days'
         ))::numeric / count(*), 1) END                                                                       AS active_30d_pct
  FROM public.engineers e
  GROUP BY coalesce(e.cached_highest_tier, 'none')
  ORDER BY CASE coalesce(e.cached_highest_tier, 'none')
    WHEN 'gold' THEN 1 WHEN 'silver' THEN 2 WHEN 'bronze' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_tier_distribution_current() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_tier_distribution_current() TO authenticated;
COMMIT;
