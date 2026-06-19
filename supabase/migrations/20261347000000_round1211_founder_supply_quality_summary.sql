BEGIN;
DROP FUNCTION IF EXISTS public.founder_supply_quality_summary();
CREATE OR REPLACE FUNCTION public.founder_supply_quality_summary()
RETURNS TABLE (
  total_engineers              bigint,
  verified_pct                 numeric,
  kyc_pending_over_7d          bigint,
  tier_gold_pct                numeric,
  tier_silver_pct              numeric,
  tier_none_pct                numeric,
  avg_audit_rating_30d         numeric,
  audit_pass_pct_30d           numeric,
  avg_payout_success_pct_30d   numeric,
  avg_jobs_per_active_30d      numeric,
  engineers_no_jobs_90d_pct    numeric,
  disputes_against_engineers_30d bigint,
  composite_supply_score       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
  v_verified bigint;
  v_tier_gold bigint;
  v_tier_silver bigint;
  v_tier_none bigint;
  v_audit_resp_30d bigint;
  v_audit_pass_30d bigint;
  v_audit_avg numeric;
  v_payouts_30d bigint;
  v_payouts_success_30d bigint;
  v_jobs_30d bigint;
  v_active_30d bigint;
  v_no_jobs_90d bigint;
  v_disputes_30d bigint;
  v_verified_pct numeric;
  v_audit_pct numeric;
  v_payout_pct numeric;
  v_active_pct numeric;
  v_score numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total FROM public.engineers;
  IF v_total IS NULL THEN v_total := 0; END IF;
  SELECT count(*)::bigint INTO v_verified FROM public.engineers WHERE verification_status = 'verified';
  SELECT count(*)::bigint INTO v_tier_gold FROM public.engineers WHERE coalesce(cached_highest_tier, 'none') = 'gold';
  SELECT count(*)::bigint INTO v_tier_silver FROM public.engineers WHERE coalesce(cached_highest_tier, 'none') = 'silver';
  SELECT count(*)::bigint INTO v_tier_none FROM public.engineers WHERE coalesce(cached_highest_tier, 'none') = 'none';

  SELECT count(*)::bigint INTO v_audit_resp_30d FROM public.spot_audit_responses WHERE responded_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_audit_pass_30d FROM public.spot_audit_responses WHERE responded_at >= now() - interval '30 days' AND rating >= 4;
  SELECT coalesce(round(avg(rating)::numeric, 2), 0) INTO v_audit_avg FROM public.spot_audit_responses WHERE responded_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_payouts_30d FROM public.engineer_payouts WHERE queued_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_payouts_success_30d FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '30 days';

  SELECT count(*)::bigint INTO v_jobs_30d FROM public.repair_jobs WHERE engineer_id IS NOT NULL AND status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT count(DISTINCT engineer_id)::bigint INTO v_active_30d FROM public.repair_jobs WHERE engineer_id IS NOT NULL AND status = 'completed' AND completed_at >= now() - interval '30 days';
  IF v_active_30d IS NULL THEN v_active_30d := 0; END IF;

  SELECT count(*)::bigint INTO v_no_jobs_90d FROM public.engineers e
    WHERE NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.engineer_id = e.id
                       AND j.status = 'completed' AND j.completed_at >= now() - interval '90 days');

  SELECT count(*)::bigint INTO v_disputes_30d FROM public.dispute_evidence_packs
    WHERE submitted_at IS NOT NULL AND submitted_at >= now() - interval '30 days'
      AND filer_role = 'hospital';

  v_verified_pct := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_verified / v_total, 1) END;
  v_audit_pct    := CASE WHEN v_audit_resp_30d = 0 THEN 100::numeric ELSE round(100.0 * v_audit_pass_30d / v_audit_resp_30d, 1) END;
  v_payout_pct   := CASE WHEN v_payouts_30d = 0 THEN 100::numeric ELSE round(100.0 * v_payouts_success_30d / v_payouts_30d, 1) END;
  v_active_pct   := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_active_30d / v_total, 1) END;
  v_score        := round((v_verified_pct + v_audit_pct + v_payout_pct + v_active_pct) / 4.0, 1);

  RETURN QUERY
  SELECT
    v_total,
    v_verified_pct,
    coalesce((SELECT count(*)::bigint FROM public.engineers
              WHERE coalesce(verification_status, 'pending') = 'pending'
                AND created_at < now() - interval '7 days'), 0),
    CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_tier_gold / v_total, 1) END,
    CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_tier_silver / v_total, 1) END,
    CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_tier_none / v_total, 1) END,
    v_audit_avg,
    v_audit_pct,
    v_payout_pct,
    CASE WHEN v_active_30d = 0 THEN 0::numeric ELSE round(v_jobs_30d::numeric / v_active_30d, 2) END,
    CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_no_jobs_90d / v_total, 1) END,
    v_disputes_30d,
    v_score;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_supply_quality_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_supply_quality_summary() TO authenticated;
COMMIT;
