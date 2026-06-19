BEGIN;
DROP FUNCTION IF EXISTS public.founder_referrals_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_referrals_snapshot_summary()
RETURNS TABLE (
  total_referrals_all_time        bigint,
  referrals_registered_today      bigint,
  referrals_registered_30d        bigint,
  bounty_eligible_now             bigint,
  bounty_pending_now              bigint,
  bounty_revoked_all_time         bigint,
  payouts_queued_now              bigint,
  payouts_paid_all_time           bigint,
  queued_bounty_value_rupees      numeric,
  paid_bounty_value_rupees        numeric,
  paid_bounty_value_30d_rupees    numeric,
  active_referrers_30d            bigint,
  stuck_referrals_over_60d        bigint,
  conversion_pct_90d              numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_signed_90d  bigint;
  v_paid_90d    bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_signed_90d
    FROM public.engineer_referrals r
   WHERE r.created_at >= now() - interval '90 days';

  SELECT count(DISTINCT bp.referral_id)::bigint INTO v_paid_90d
    FROM public.referral_bounty_payouts bp
    JOIN public.engineer_referrals r ON r.id = bp.referral_id
   WHERE r.created_at >= now() - interval '90 days'
     AND bp.status = 'paid';

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals
              WHERE created_at >= v_today_start AND created_at < v_today_end), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals
              WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals
              WHERE bounty_eligible = true AND coalesce(bounty_revoked, false) = false), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals
              WHERE bounty_eligible = false AND coalesce(bounty_revoked, false) = false), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals
              WHERE bounty_revoked = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts
              WHERE status = 'queued'), 0),
    coalesce((SELECT count(*)::bigint FROM public.referral_bounty_payouts
              WHERE status = 'paid'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'queued'), 0)::numeric,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'paid'), 0)::numeric,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'paid' AND paid_at >= now() - interval '30 days'), 0)::numeric,
    coalesce((SELECT count(DISTINCT referrer_user_id)::bigint
              FROM public.engineer_referrals
              WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals
              WHERE bounty_eligible = false
                AND coalesce(bounty_revoked, false) = false
                AND created_at < now() - interval '60 days'), 0),
    CASE WHEN v_signed_90d = 0 THEN 0::numeric
         ELSE round((v_paid_90d::numeric / v_signed_90d::numeric) * 100.0, 1)
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referrals_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referrals_snapshot_summary() TO authenticated;
COMMIT;