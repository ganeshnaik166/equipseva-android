BEGIN;
DROP FUNCTION IF EXISTS public.founder_top_referrers_90d();
CREATE OR REPLACE FUNCTION public.founder_top_referrers_90d()
RETURNS TABLE (
  referrer_user_id   uuid,
  display_name       text,
  referrals_90d      bigint,
  paid_bounties_90d  bigint,
  total_bounty_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT r.referrer_user_id,
           count(*)::bigint AS referrals_90d,
           coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts bp
                     JOIN public.engineer_referrals r2 ON r2.id = bp.referral_id
                     WHERE r2.referrer_user_id = r.referrer_user_id
                       AND r2.created_at >= now() - interval '90 days'), 0)::bigint AS paid_bounties_90d,
           coalesce((SELECT sum(bp.amount_rupees)::numeric FROM public.referral_bounty_payouts bp
                     JOIN public.engineer_referrals r2 ON r2.id = bp.referral_id
                     WHERE r2.referrer_user_id = r.referrer_user_id
                       AND r2.created_at >= now() - interval '90 days'), 0)::numeric AS total_bounty_rupees
    FROM public.engineer_referrals r
    WHERE r.created_at >= now() - interval '90 days'
    GROUP BY r.referrer_user_id
  )
  SELECT
    b.referrer_user_id,
    coalesce(p.full_name, '(engineer)'),
    b.referrals_90d,
    b.paid_bounties_90d,
    b.total_bounty_rupees
  FROM base b
  LEFT JOIN public.profiles p ON p.id = b.referrer_user_id
  ORDER BY b.paid_bounties_90d DESC, b.referrals_90d DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_top_referrers_90d() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_top_referrers_90d() TO authenticated;
COMMIT;
