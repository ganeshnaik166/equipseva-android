BEGIN;
DROP FUNCTION IF EXISTS public.founder_referrers_by_tier();
CREATE OR REPLACE FUNCTION public.founder_referrers_by_tier()
RETURNS TABLE (
  tier             text,
  referrers_cnt    bigint,
  referrals_90d    bigint,
  paid_bounties_90d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH tiers AS (
    SELECT tier, display_order FROM public.amc_subscription_tiers
    UNION ALL VALUES ('none'::text, 0)
  )
  SELECT
    t.tier,
    coalesce((SELECT count(DISTINCT r.referrer_user_id)::bigint FROM public.engineer_referrals r
              LEFT JOIN public.engineer_certification_progress ecp ON ecp.user_id = r.referrer_user_id
              WHERE coalesce(ecp.current_tier, 'none') = t.tier
                AND r.created_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
              LEFT JOIN public.engineer_certification_progress ecp ON ecp.user_id = r.referrer_user_id
              WHERE coalesce(ecp.current_tier, 'none') = t.tier
                AND r.created_at >= now() - interval '90 days'), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts bp
              JOIN public.engineer_referrals r ON r.id = bp.referral_id
              LEFT JOIN public.engineer_certification_progress ecp ON ecp.user_id = r.referrer_user_id
              WHERE coalesce(ecp.current_tier, 'none') = t.tier
                AND r.created_at >= now() - interval '90 days'), 0)::bigint
  FROM tiers t
  ORDER BY t.display_order;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referrers_by_tier() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referrers_by_tier() TO authenticated;
COMMIT;
