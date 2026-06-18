BEGIN;
DROP FUNCTION IF EXISTS public.founder_chains_amc_leaderboard();
CREATE OR REPLACE FUNCTION public.founder_chains_amc_leaderboard()
RETURNS TABLE (
  chain_name        text,
  member_hospitals  bigint,
  active_amcs       bigint,
  total_mrr_inr     numeric,
  paused_amcs       bigint,
  expired_amcs      bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(ch.name, '(unknown)')::text                                       AS chain_name,
    count(DISTINCT m.hospital_user_id)::bigint                                  AS member_hospitals,
    count(*) FILTER (WHERE c.status = 'active')::bigint                         AS active_amcs,
    coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.status = 'active'), 0)::numeric AS total_mrr_inr,
    count(*) FILTER (WHERE c.status = 'paused')::bigint                         AS paused_amcs,
    count(*) FILTER (WHERE c.status = 'expired')::bigint                        AS expired_amcs
  FROM public.hospital_chains ch
  JOIN public.hospital_chain_memberships m ON m.chain_id = ch.id
  LEFT JOIN public.amc_contracts c ON c.hospital_user_id = m.hospital_user_id
  GROUP BY coalesce(ch.name, '(unknown)')
  ORDER BY total_mrr_inr DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_chains_amc_leaderboard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_chains_amc_leaderboard() TO authenticated;
COMMIT;
