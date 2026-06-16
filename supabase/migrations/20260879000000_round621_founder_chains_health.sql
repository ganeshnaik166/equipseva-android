BEGIN;
DROP FUNCTION IF EXISTS public.founder_chains_health();
CREATE OR REPLACE FUNCTION public.founder_chains_health()
RETURNS TABLE (
  chain_id            uuid,
  chain_name          text,
  member_count        bigint,
  amc_active_count    bigint,
  amc_pct             numeric,
  jobs_completed_30d  bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH members AS (
    SELECT chain_id, hospital_user_id
    FROM public.hospital_chain_memberships
    WHERE coalesce(status, 'active') = 'active'
  ),
  per_chain AS (
    SELECT
      m.chain_id,
      count(*)::bigint                                        AS member_count,
      (SELECT count(*)::bigint
         FROM public.amc_contracts c
        WHERE c.hospital_user_id IN (SELECT hospital_user_id FROM members WHERE chain_id = m.chain_id)
          AND c.status = 'active')                            AS amc_active_count,
      (SELECT count(*)::bigint
         FROM public.repair_jobs rj
        WHERE rj.hospital_user_id IN (SELECT hospital_user_id FROM members WHERE chain_id = m.chain_id)
          AND rj.status = 'completed'
          AND rj.completed_at >= now() - interval '30 days')  AS jobs_completed_30d
    FROM members m
    GROUP BY m.chain_id
  )
  SELECT
    hc.id                                  AS chain_id,
    hc.name                                AS chain_name,
    coalesce(pc.member_count, 0)           AS member_count,
    coalesce(pc.amc_active_count, 0)       AS amc_active_count,
    CASE WHEN coalesce(pc.member_count, 0) = 0 THEN 0::numeric
         ELSE round(coalesce(pc.amc_active_count, 0)::numeric / pc.member_count::numeric * 100.0, 1) END AS amc_pct,
    coalesce(pc.jobs_completed_30d, 0)     AS jobs_completed_30d
  FROM public.hospital_chains hc
  LEFT JOIN per_chain pc ON pc.chain_id = hc.id
  ORDER BY member_count DESC, jobs_completed_30d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_chains_health() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_chains_health() TO authenticated;
COMMIT;
