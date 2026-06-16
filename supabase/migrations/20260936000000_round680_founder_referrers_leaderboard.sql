BEGIN;
DROP FUNCTION IF EXISTS public.founder_referrers_leaderboard();
CREATE OR REPLACE FUNCTION public.founder_referrers_leaderboard()
RETURNS TABLE (
  referrer_user_id  uuid,
  display_name      text,
  referrals_total   bigint,
  first_jobs        bigint,
  bounties_paid     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    r.referrer_user_id,
    coalesce(p.full_name, '(engineer)'),
    count(*)::bigint                                                                     AS referrals_total,
    count(*) FILTER (WHERE r.referee_first_completed_at IS NOT NULL)::bigint              AS first_jobs,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts bp
              WHERE bp.beneficiary_user_id = r.referrer_user_id), 0)::bigint              AS bounties_paid
  FROM public.engineer_referrals r
  LEFT JOIN public.profiles p ON p.id = r.referrer_user_id
  GROUP BY r.referrer_user_id, p.full_name
  ORDER BY first_jobs DESC, referrals_total DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referrers_leaderboard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referrers_leaderboard() TO authenticated;
COMMIT;
