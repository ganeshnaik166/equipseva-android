BEGIN;
DROP FUNCTION IF EXISTS public.founder_chains_leaderboard();
CREATE OR REPLACE FUNCTION public.founder_chains_leaderboard()
RETURNS TABLE (
  chain_id        uuid,
  name            text,
  member_count    bigint,
  active_amcs     bigint,
  jobs_30d        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH members AS (
    SELECT m.chain_id, m.hospital_user_id
    FROM public.hospital_chain_memberships m
  )
  SELECT
    c.id,
    c.name,
    coalesce((SELECT count(*)::bigint FROM members m WHERE m.chain_id = c.id), 0)::bigint AS member_count,
    coalesce((SELECT count(DISTINCT a.id)::bigint FROM public.amc_contracts a
              JOIN members m2 ON m2.hospital_user_id = a.hospital_user_id
             WHERE m2.chain_id = c.id AND a.status = 'active'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs rj
              JOIN members m3 ON m3.hospital_user_id = rj.hospital_user_id
             WHERE m3.chain_id = c.id AND rj.created_at >= now() - interval '30 days'), 0)::bigint
  FROM public.hospital_chains c
  ORDER BY member_count DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_chains_leaderboard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_chains_leaderboard() TO authenticated;
COMMIT;
