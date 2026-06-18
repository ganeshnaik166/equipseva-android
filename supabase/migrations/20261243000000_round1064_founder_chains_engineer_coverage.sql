BEGIN;
DROP FUNCTION IF EXISTS public.founder_chains_engineer_coverage();
CREATE OR REPLACE FUNCTION public.founder_chains_engineer_coverage()
RETURNS TABLE (
  chain_name              text,
  member_hospitals        bigint,
  distinct_cities         bigint,
  engineers_in_those_cities bigint,
  verified_engineers      bigint,
  coverage_pct            numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH chain_cities AS (
    SELECT
      ch.id        AS chain_id,
      ch.name      AS chain_name,
      m.hospital_user_id,
      coalesce(nullif(trim(p.city), ''), '(unknown)')::text AS city
    FROM public.hospital_chains ch
    JOIN public.hospital_chain_memberships m ON m.chain_id = ch.id
    LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  )
  SELECT
    coalesce(cc.chain_name, '(unknown)')::text                                 AS chain_name,
    count(DISTINCT cc.hospital_user_id)::bigint                                 AS member_hospitals,
    count(DISTINCT cc.city)::bigint                                             AS distinct_cities,
    coalesce((
      SELECT count(*)::bigint FROM public.engineers e
      JOIN public.profiles ep ON ep.id = e.user_id
      WHERE coalesce(nullif(trim(ep.city), ''), '(unknown)') IN (SELECT DISTINCT city FROM chain_cities WHERE chain_id = cc.chain_id)
    ), 0)::bigint                                                              AS engineers_in_those_cities,
    coalesce((
      SELECT count(*)::bigint FROM public.engineers e
      JOIN public.profiles ep ON ep.id = e.user_id
      WHERE e.verification_status = 'verified'
        AND coalesce(nullif(trim(ep.city), ''), '(unknown)') IN (SELECT DISTINCT city FROM chain_cities WHERE chain_id = cc.chain_id)
    ), 0)::bigint                                                              AS verified_engineers,
    CASE WHEN coalesce((
            SELECT count(*)::bigint FROM public.engineers e
            JOIN public.profiles ep ON ep.id = e.user_id
            WHERE coalesce(nullif(trim(ep.city), ''), '(unknown)') IN (SELECT DISTINCT city FROM chain_cities WHERE chain_id = cc.chain_id)
          ), 0) = 0 THEN 0::numeric
         ELSE round(
           100.0 * coalesce((
             SELECT count(*)::numeric FROM public.engineers e
             JOIN public.profiles ep ON ep.id = e.user_id
             WHERE e.verification_status = 'verified'
               AND coalesce(nullif(trim(ep.city), ''), '(unknown)') IN (SELECT DISTINCT city FROM chain_cities WHERE chain_id = cc.chain_id)
           ), 0)
           / coalesce((
             SELECT count(*)::numeric FROM public.engineers e
             JOIN public.profiles ep ON ep.id = e.user_id
             WHERE coalesce(nullif(trim(ep.city), ''), '(unknown)') IN (SELECT DISTINCT city FROM chain_cities WHERE chain_id = cc.chain_id)
           ), 1),
           1)
    END                                                                         AS coverage_pct
  FROM chain_cities cc
  GROUP BY cc.chain_id, cc.chain_name
  ORDER BY count(DISTINCT cc.hospital_user_id) DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_chains_engineer_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_chains_engineer_coverage() TO authenticated;
COMMIT;
