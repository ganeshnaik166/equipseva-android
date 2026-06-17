BEGIN;
DROP FUNCTION IF EXISTS public.founder_chains_amc_gap();
CREATE OR REPLACE FUNCTION public.founder_chains_amc_gap()
RETURNS TABLE (
  chain_id            uuid,
  name                text,
  member_count        bigint,
  members_with_amc    bigint,
  members_without_amc bigint,
  amc_coverage_pct    numeric
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
    coalesce((SELECT count(*)::bigint FROM members m WHERE m.chain_id = c.id), 0)::bigint,
    coalesce((SELECT count(DISTINCT m.hospital_user_id)::bigint FROM members m
              WHERE m.chain_id = c.id
                AND EXISTS (SELECT 1 FROM public.amc_contracts a
                            WHERE a.hospital_user_id = m.hospital_user_id AND a.status='active')), 0)::bigint,
    coalesce((SELECT count(DISTINCT m.hospital_user_id)::bigint FROM members m
              WHERE m.chain_id = c.id
                AND NOT EXISTS (SELECT 1 FROM public.amc_contracts a
                                WHERE a.hospital_user_id = m.hospital_user_id AND a.status='active')), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM members m WHERE m.chain_id = c.id), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(DISTINCT m.hospital_user_id)::numeric FROM members m
              WHERE m.chain_id = c.id
                AND EXISTS (SELECT 1 FROM public.amc_contracts a
                            WHERE a.hospital_user_id = m.hospital_user_id AND a.status='active'))
           / (SELECT count(*)::numeric FROM members m WHERE m.chain_id = c.id)
           * 100.0, 1)
    END
  FROM public.hospital_chains c
  ORDER BY members_without_amc DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_chains_amc_gap() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_chains_amc_gap() TO authenticated;
COMMIT;
