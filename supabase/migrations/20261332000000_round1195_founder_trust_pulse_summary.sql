BEGIN;
DROP FUNCTION IF EXISTS public.founder_trust_pulse_summary();
CREATE OR REPLACE FUNCTION public.founder_trust_pulse_summary()
RETURNS TABLE (
  disputes_open                bigint,
  disputes_resolution_pct_30d  numeric,
  spot_audits_responded_30d    bigint,
  spot_audit_avg_rating_30d    numeric,
  spot_audit_pass_pct_30d      numeric,
  code_red_resolved_30d        bigint,
  code_red_sla_breach_pct_30d  numeric,
  escrow_refund_pct_30d        numeric,
  payouts_failed_pct_30d       numeric,
  amc_paused_now               bigint,
  amc_expired_30d              bigint,
  engineer_kyc_pending_over_7d bigint,
  hospitals_signup_no_job      bigint,
  overall_trust_score          numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_dispute_submitted_30d bigint;
  v_dispute_resolved_30d  bigint;
  v_audit_resp_30d        bigint;
  v_audit_pass_30d        bigint;
  v_audit_avg_30d         numeric;
  v_cr_resolved_30d       bigint;
  v_cr_breach_30d         bigint;
  v_escrow_terminal_30d   bigint;
  v_escrow_refunded_30d   bigint;
  v_payouts_30d           bigint;
  v_payouts_failed_30d    bigint;
  v_dispute_pct           numeric;
  v_audit_pct             numeric;
  v_cr_pct                numeric;
  v_refund_pct            numeric;
  v_payout_fail_pct       numeric;
  v_score                 numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_dispute_submitted_30d FROM public.dispute_evidence_packs
    WHERE submitted_at IS NOT NULL AND submitted_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_dispute_resolved_30d FROM public.dispute_evidence_packs
    WHERE submitted_at IS NOT NULL AND submitted_at >= now() - interval '30 days'
      AND mediator_decision_at IS NOT NULL;

  SELECT count(*)::bigint INTO v_audit_resp_30d FROM public.spot_audit_responses
    WHERE responded_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_audit_pass_30d FROM public.spot_audit_responses
    WHERE responded_at >= now() - interval '30 days' AND rating >= 4;
  SELECT coalesce(avg(rating)::numeric, 0) INTO v_audit_avg_30d FROM public.spot_audit_responses
    WHERE responded_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_cr_resolved_30d FROM public.code_red_requests
    WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_cr_breach_30d FROM public.code_red_requests
    WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days'
      AND resolved_at > sla_deadline_at;

  SELECT count(*)::bigint INTO v_escrow_terminal_30d FROM public.repair_job_escrow
    WHERE status IN ('released','refunded')
      AND coalesce(released_at, refunded_at) >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_escrow_refunded_30d FROM public.repair_job_escrow
    WHERE status = 'refunded' AND refunded_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_payouts_30d FROM public.engineer_payouts
    WHERE queued_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_payouts_failed_30d FROM public.engineer_payouts
    WHERE status = 'failed' AND queued_at >= now() - interval '30 days';

  v_dispute_pct := CASE WHEN coalesce(v_dispute_submitted_30d, 0) = 0 THEN 100::numeric
                        ELSE round(100.0 * v_dispute_resolved_30d / v_dispute_submitted_30d, 1) END;
  v_audit_pct   := CASE WHEN coalesce(v_audit_resp_30d, 0) = 0 THEN 100::numeric
                        ELSE round(100.0 * v_audit_pass_30d / v_audit_resp_30d, 1) END;
  v_cr_pct      := CASE WHEN coalesce(v_cr_resolved_30d, 0) = 0 THEN 0::numeric
                        ELSE round(100.0 * v_cr_breach_30d / v_cr_resolved_30d, 1) END;
  v_refund_pct  := CASE WHEN coalesce(v_escrow_terminal_30d, 0) = 0 THEN 0::numeric
                        ELSE round(100.0 * v_escrow_refunded_30d / v_escrow_terminal_30d, 1) END;
  v_payout_fail_pct := CASE WHEN coalesce(v_payouts_30d, 0) = 0 THEN 0::numeric
                            ELSE round(100.0 * v_payouts_failed_30d / v_payouts_30d, 1) END;

  -- Composite trust score: average of pass-like rates (higher is better).
  -- Inverts breach/refund/fail rates so all 5 signals trend "high = trust".
  v_score := round((
    v_dispute_pct +
    v_audit_pct +
    (100 - v_cr_pct) +
    (100 - v_refund_pct) +
    (100 - v_payout_fail_pct)
  ) / 5.0, 1);

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs WHERE status = 'submitted' AND mediator_decision_at IS NULL), 0),
    v_dispute_pct,
    v_audit_resp_30d,
    v_audit_avg_30d,
    v_audit_pct,
    v_cr_resolved_30d,
    v_cr_pct,
    v_refund_pct,
    v_payout_fail_pct,
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'paused'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'expired' AND end_date >= (now() - interval '30 days')::date), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE coalesce(verification_status, 'pending') = 'pending' AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles p WHERE p.role = 'hospital'
              AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = p.id)), 0),
    v_score;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_trust_pulse_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_trust_pulse_summary() TO authenticated;
COMMIT;
