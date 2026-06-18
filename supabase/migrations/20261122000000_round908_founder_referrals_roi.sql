BEGIN;
DROP FUNCTION IF EXISTS public.founder_referrals_roi();
CREATE OR REPLACE FUNCTION public.founder_referrals_roi()
RETURNS TABLE (
  window_label    text,
  bounties_paid_rupees numeric,
  referee_gross_rupees numeric,
  roi_multiple    numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH w(label, ord, cutoff) AS (
    VALUES
      ('90d'::text,  1, now() - interval '90 days'),
      ('180d'::text, 2, now() - interval '180 days'),
      ('365d'::text, 3, now() - interval '365 days')
  )
  SELECT
    w.label,
    coalesce((SELECT sum(bp.amount_rupees)::numeric FROM public.referral_bounty_payouts bp
              JOIN public.engineer_referrals r ON r.id = bp.referral_id
              WHERE r.created_at >= w.cutoff), 0)::numeric,
    coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric
              FROM public.engineer_referrals r
              JOIN public.repair_job_bids b ON b.engineer_user_id = r.referee_user_id AND b.status = 'accepted'
              JOIN public.repair_jobs rj ON rj.id = b.repair_job_id AND rj.status = 'completed'
              WHERE r.created_at >= w.cutoff), 0)::numeric,
    CASE WHEN coalesce((SELECT sum(bp.amount_rupees) FROM public.referral_bounty_payouts bp
                        JOIN public.engineer_referrals r ON r.id = bp.referral_id
                        WHERE r.created_at >= w.cutoff), 0) = 0
         THEN 0::numeric
         ELSE round(
           coalesce((SELECT sum(rj.contracted_amount_rupees)::numeric
                     FROM public.engineer_referrals r
                     JOIN public.repair_job_bids b ON b.engineer_user_id = r.referee_user_id AND b.status = 'accepted'
                     JOIN public.repair_jobs rj ON rj.id = b.repair_job_id AND rj.status = 'completed'
                     WHERE r.created_at >= w.cutoff), 0)
           / coalesce((SELECT sum(bp.amount_rupees)::numeric FROM public.referral_bounty_payouts bp
                       JOIN public.engineer_referrals r ON r.id = bp.referral_id
                       WHERE r.created_at >= w.cutoff), 1)
         , 2)
    END
  FROM w
  ORDER BY w.ord;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_referrals_roi() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_referrals_roi() TO authenticated;
COMMIT;
