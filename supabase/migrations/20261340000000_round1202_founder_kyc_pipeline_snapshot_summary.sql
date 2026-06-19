-- =====================================================================
-- Round 1202 — Founder KYC pipeline snapshot summary
-- =====================================================================
-- One-pane consolidated snapshot of KYC backlog across engineer + buyer
-- roles. KYC backlog is a regulatory existential risk — directly gates
-- Cashfree activation and Class A/B hospital onboarding.
--
-- Engineer KYC: public.engineers (verification_status pending/verified/
-- rejected, created_at, verified_at) + public.engineer_kyc_renewals
-- (status pending/in_progress/completed/expired/waived, due_at,
-- grace_until). Buyer KYC: public.buyer_kyc_verifications (status
-- pending/verified/rejected, submitted_at, reviewed_at).
--
-- KPIs: pending counts per role, aging buckets, rekyc-due-30d,
-- rejected/needs-resubmit, intake-vs-approval (today + 30d).

BEGIN;
DROP FUNCTION IF EXISTS public.founder_kyc_pipeline_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_kyc_pipeline_snapshot_summary()
RETURNS TABLE (
  engineer_pending          bigint,
  engineer_rejected         bigint,
  engineer_pending_0_7d     bigint,
  engineer_pending_7_30d    bigint,
  engineer_pending_over_30d bigint,
  engineer_oldest_age_days  int,
  buyer_pending             bigint,
  buyer_rejected            bigint,
  buyer_pending_0_7d        bigint,
  buyer_pending_7_30d       bigint,
  buyer_pending_over_30d    bigint,
  rekyc_due_30d             bigint,
  rekyc_overdue             bigint,
  rekyc_grace_expiring_7d   bigint,
  engineer_intake_today     bigint,
  engineer_verified_today   bigint,
  engineer_verified_30d     bigint,
  buyer_intake_today        bigint,
  buyer_verified_today      bigint,
  buyer_verified_30d        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- Engineer KYC backlog
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status,'pending') IN ('pending','in_review')),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.verification_status = 'rejected'),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status,'pending') IN ('pending','in_review')
        AND e.created_at >= now() - interval '7 days'),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status,'pending') IN ('pending','in_review')
        AND e.created_at <  now() - interval '7 days'
        AND e.created_at >= now() - interval '30 days'),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE coalesce(e.verification_status,'pending') IN ('pending','in_review')
        AND e.created_at <  now() - interval '30 days'),
    coalesce((SELECT (extract(epoch FROM (now() - min(e.created_at)))::int / 86400)
                FROM public.engineers e
               WHERE coalesce(e.verification_status,'pending') IN ('pending','in_review')), 0),

    -- Buyer KYC backlog
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b WHERE b.status = 'pending'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b WHERE b.status = 'rejected'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'pending' AND b.submitted_at >= now() - interval '7 days'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'pending'
        AND b.submitted_at <  now() - interval '7 days'
        AND b.submitted_at >= now() - interval '30 days'),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'pending' AND b.submitted_at < now() - interval '30 days'),

    -- Re-KYC pipeline
    (SELECT count(*)::bigint FROM public.engineer_kyc_renewals r
      WHERE r.status IN ('pending','in_progress')
        AND r.due_at <= now() + interval '30 days'),
    (SELECT count(*)::bigint FROM public.engineer_kyc_renewals r
      WHERE r.status IN ('pending','in_progress')
        AND r.due_at < now()),
    (SELECT count(*)::bigint FROM public.engineer_kyc_renewals r
      WHERE r.status IN ('pending','in_progress')
        AND r.grace_until <= now() + interval '7 days'),

    -- Intake vs approval — engineer side
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.created_at >= v_today_start AND e.created_at < v_today_end),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.verification_status = 'verified'
        AND e.verified_at >= v_today_start AND e.verified_at < v_today_end),
    (SELECT count(*)::bigint FROM public.engineers e
      WHERE e.verification_status = 'verified'
        AND e.verified_at >= now() - interval '30 days'),

    -- Intake vs approval — buyer side
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.submitted_at >= v_today_start AND b.submitted_at < v_today_end),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'verified'
        AND b.reviewed_at >= v_today_start AND b.reviewed_at < v_today_end),
    (SELECT count(*)::bigint FROM public.buyer_kyc_verifications b
      WHERE b.status = 'verified'
        AND b.reviewed_at >= now() - interval '30 days');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_kyc_pipeline_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_kyc_pipeline_snapshot_summary() TO authenticated;
COMMIT;
