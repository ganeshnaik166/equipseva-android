BEGIN;
DROP FUNCTION IF EXISTS public.founder_referral_bounty_leaderboard();
CREATE OR REPLACE FUNCTION public.founder_referral_bounty_leaderboard()
RETURNS TABLE (
  referrer_name      text,
  total_bounties     bigint,
  paid_cnt           bigint,
  queued_cnt         bigint,
  cancelled_cnt      bigint,
  total_paid_inr     numeric,
  last_bounty_at     timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce(pr.full_name, '(no name)')::text                                 AS referrer_name,
    count(*)::bigint                                                           AS total_bounties,
    count(*) FILTER (WHERE b.status = 'paid')::bigint                          AS paid_cnt,
    count(*) FILTER (WHERE b.status = 'queued')::bigint                        AS queued_cnt,
    count(*) FILTER (WHERE b.status = 'cancelled')::bigint                     AS cancelled_cnt,
    coalesce(sum(b.amount_rupees) FILTER (WHERE b.status = 'paid'), 0)::numeric AS total_paid_inr,
    max(b.queued_at)                                                           AS last_bounty_at
  FROM public.referral_bounty_payouts b
  LEFT JOIN public.profiles pr ON pr.id = b.beneficiary_user_id
  GROUP BY coalesce(pr.full_name, '(no name)')
  ORDER BY count(*) DESC, sum(b.amount_rupees) FILTER (WHERE b.status = 'paid') DESC NULLS LAST
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referral_bounty_leaderboard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referral_bounty_leaderboard() TO authenticated;
COMMIT;
