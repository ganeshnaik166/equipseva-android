BEGIN;
-- r1230 — audit-driven sweep (wf ws4nf361d) for r1208/r1209/r1211 bugs.
--
-- 1. r1209 founder_amc_pool_pulse_summary — CRITICAL: references non-existent
--    table public.amc_pool_ledger (real table is public.amc_payment_pool).
--    Every call would runtime-error with 'relation does not exist'.
--
-- 2. r1208 founder_investor_pulse_summary — HIGH (dead literal): uses
--    status IN ('processed','paid') on engineer_payouts. CHECK constraint
--    has no 'paid' value (queued/processing/processed/failed/cancelled).
--    Same drift class as r1163. Functionally OK (reduces to = 'processed')
--    but misleading and would silently undercount any future status renames.
--
-- 3. r1211 founder_supply_quality_summary — LOW: same 'paid' dead literal.
--    Cleanup for consistency.

-- ============================================================================
-- 1. r1209 founder_amc_pool_pulse_summary — table-name fix
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_amc_pool_pulse_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_pool_pulse_summary()
RETURNS TABLE (
  total_pool_balance_inr        numeric,
  active_amc_count              bigint,
  avg_balance_per_amc_inr       numeric,
  zero_balance_amc_count        bigint,
  zero_balance_blocked_mrr_inr  numeric,
  credits_30d_inr               numeric,
  debits_30d_inr                numeric,
  refunds_30d_inr               numeric,
  net_flow_30d_inr              numeric,
  top_up_events_30d             bigint,
  debit_events_30d              bigint,
  hospitals_at_zero_balance     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_credits_30d numeric;
  v_debits_30d numeric;
  v_refunds_30d numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_credits_30d
    FROM public.amc_payment_pool WHERE ledger_kind = 'credit' AND created_at >= now() - interval '30 days';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_debits_30d
    FROM public.amc_payment_pool WHERE ledger_kind = 'debit' AND created_at >= now() - interval '30 days';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_refunds_30d
    FROM public.amc_payment_pool WHERE ledger_kind = 'refund' AND created_at >= now() - interval '30 days';

  RETURN QUERY
  SELECT
    coalesce((SELECT sum(coalesce(v.balance_rupees, 0))::numeric
              FROM public.amc_contracts c
              LEFT JOIN public.v_amc_pool_balance v ON v.amc_contract_id = c.id
              WHERE c.status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT round(avg(coalesce(v.balance_rupees, 0))::numeric, 2)
              FROM public.amc_contracts c
              LEFT JOIN public.v_amc_pool_balance v ON v.amc_contract_id = c.id
              WHERE c.status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts c
              WHERE c.status = 'active'
                AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    coalesce((SELECT sum(c.monthly_fee_rupees)::numeric FROM public.amc_contracts c
              WHERE c.status = 'active'
                AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0),
    v_credits_30d,
    v_debits_30d,
    v_refunds_30d,
    (v_credits_30d - v_debits_30d - v_refunds_30d)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_pool WHERE ledger_kind = 'credit' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_payment_pool WHERE ledger_kind = 'debit' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT c.hospital_user_id)::bigint FROM public.amc_contracts c
              WHERE c.status = 'active'
                AND coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0) <= 0), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_amc_pool_pulse_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_pool_pulse_summary() TO authenticated;

-- ============================================================================
-- 2. r1208 founder_investor_pulse_summary — drop 'paid' dead literal
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_investor_pulse_summary();
CREATE OR REPLACE FUNCTION public.founder_investor_pulse_summary()
RETURNS TABLE (
  active_mrr_inr             numeric,
  active_amc_contracts       bigint,
  gmv_30d_inr                numeric,
  jobs_completed_30d         bigint,
  spare_parts_paid_30d_inr   numeric,
  payouts_paid_30d_inr       numeric,
  new_engineers_30d          bigint,
  new_hospitals_30d          bigint,
  active_engineers_30d       bigint,
  active_hospitals_30d       bigint,
  referral_bounty_paid_30d_inr numeric,
  amc_renewals_30d           bigint,
  total_users_all_time       bigint,
  ttv_lifetime_gmv_inr       numeric,
  lifetime_payouts_inr       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_jobs_gmv_30d numeric;
  v_spare_gmv_30d numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_jobs_gmv_30d
    FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT coalesce(sum(total_amount), 0)::numeric INTO v_spare_gmv_30d
    FROM public.spare_part_orders WHERE coalesce(payment_status, '') = 'paid' AND created_at >= now() - interval '30 days';

  RETURN QUERY
  SELECT
    coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    (v_jobs_gmv_30d + v_spare_gmv_30d)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days'), 0),
    v_spare_gmv_30d,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'processed' AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE role = 'hospital' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT engineer_id)::bigint FROM public.repair_jobs
              WHERE engineer_id IS NOT NULL AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.repair_jobs
              WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'paid' AND paid_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts
              WHERE created_at >= now() - interval '30 days'
                AND (start_date IS NOT NULL AND end_date IS NOT NULL AND end_date > start_date)), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles), 0),
    coalesce((SELECT sum(contracted_amount_rupees)::numeric FROM public.repair_jobs WHERE status = 'completed'), 0)
      + coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status, '') = 'paid'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'processed'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_pulse_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_pulse_summary() TO authenticated;

-- ============================================================================
-- 3. r1211 founder_supply_quality_summary — drop 'paid' dead literal
-- ============================================================================
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
  SELECT count(*)::bigint INTO v_payouts_success_30d FROM public.engineer_payouts WHERE status = 'processed' AND queued_at >= now() - interval '30 days';

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
