BEGIN;
DROP FUNCTION IF EXISTS public.founder_referral_payout_conversion();
CREATE OR REPLACE FUNCTION public.founder_referral_payout_conversion()
RETURNS TABLE (
  window_label    text,
  signed_up       bigint,
  completed_first bigint,
  bounty_paid     bigint,
  signup_to_paid_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('30d'::text,  1, now() - interval '30 days'),
      ('90d'::text,  2, now() - interval '90 days'),
      ('365d'::text, 3, now() - interval '365 days')
  )
  SELECT
    w.label,
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
              WHERE r.created_at >= w.cutoff), 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.engineer_referrals r
              WHERE r.created_at >= w.cutoff AND r.referee_first_completed_at IS NOT NULL), 0)::bigint,
    coalesce((SELECT count(DISTINCT bp.referral_id)::bigint FROM public.referral_bounty_payouts bp
              JOIN public.engineer_referrals r ON r.id = bp.referral_id
              WHERE r.created_at >= w.cutoff), 0)::bigint,
    CASE WHEN coalesce((SELECT count(*) FROM public.engineer_referrals r WHERE r.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           (SELECT count(DISTINCT bp.referral_id)::numeric FROM public.referral_bounty_payouts bp
              JOIN public.engineer_referrals r ON r.id = bp.referral_id
              WHERE r.created_at >= w.cutoff)
           / (SELECT count(*)::numeric FROM public.engineer_referrals r WHERE r.created_at >= w.cutoff)
           * 100.0, 1)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referral_payout_conversion() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referral_payout_conversion() TO authenticated;
COMMIT;
