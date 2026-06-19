BEGIN;
DROP FUNCTION IF EXISTS public.founder_money_in_flight_summary();
CREATE OR REPLACE FUNCTION public.founder_money_in_flight_summary()
RETURNS TABLE (
  escrow_held_inr             numeric,
  escrow_held_cnt             bigint,
  escrow_in_dispute_inr       numeric,
  payouts_queued_inr          numeric,
  payouts_queued_cnt          bigint,
  payouts_processing_inr      numeric,
  spare_parts_paid_unshipped_inr  numeric,
  spare_parts_paid_unshipped_cnt  bigint,
  amc_pool_total_balance_inr  numeric,
  referral_bounty_queued_inr  numeric,
  disputes_open_at_stake_inr  numeric,
  total_in_flight_inr         numeric,
  released_today_inr          numeric,
  refunded_today_inr          numeric,
  paid_payouts_today_inr      numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_escrow_held numeric;
  v_payouts_queued numeric;
  v_spare_unship numeric;
  v_amc_pool numeric;
  v_bounty numeric;
  v_disputes numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_escrow_held
    FROM public.repair_job_escrow WHERE status = 'held';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_payouts_queued
    FROM public.engineer_payouts WHERE status = 'queued';
  SELECT coalesce(sum(total_amount), 0)::numeric INTO v_spare_unship
    FROM public.spare_part_orders
    WHERE coalesce(payment_status, '') = 'paid'
      AND coalesce(order_status, '') NOT IN ('shipped','delivered','cancelled','refunded');
  SELECT coalesce(sum(coalesce((SELECT balance_rupees FROM public.v_amc_pool_balance v WHERE v.amc_contract_id = c.id), 0)), 0)::numeric INTO v_amc_pool
    FROM public.amc_contracts c WHERE c.status = 'active';
  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_bounty
    FROM public.referral_bounty_payouts WHERE status = 'queued';
  SELECT coalesce(sum(total_money_at_stake_rupees), 0)::numeric INTO v_disputes
    FROM public.dispute_evidence_packs WHERE status = 'submitted' AND mediator_decision_at IS NULL;

  RETURN QUERY
  SELECT
    v_escrow_held,
    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow WHERE status = 'held'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'in_dispute'), 0),
    v_payouts_queued,
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts WHERE status = 'queued'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status = 'processing'), 0),
    v_spare_unship,
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders
              WHERE coalesce(payment_status, '') = 'paid'
                AND coalesce(order_status, '') NOT IN ('shipped','delivered','cancelled','refunded')), 0),
    v_amc_pool,
    v_bounty,
    v_disputes,
    (v_escrow_held + v_payouts_queued + v_spare_unship + v_amc_pool + v_bounty)::numeric,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'released' AND released_at >= v_today_start AND released_at < v_today_end), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.repair_job_escrow WHERE status = 'refunded' AND refunded_at >= v_today_start AND refunded_at < v_today_end), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= v_today_start AND queued_at < v_today_end), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_money_in_flight_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_money_in_flight_summary() TO authenticated;
COMMIT;
