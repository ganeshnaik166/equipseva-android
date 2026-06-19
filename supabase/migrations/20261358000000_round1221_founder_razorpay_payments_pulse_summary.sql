-- =====================================================================
-- Round 1221 — Founder Razorpay payments pulse summary
-- =====================================================================
--
-- Console has 7 amc-payment-* routes but those measure the AMC-contract
-- payment funnel. There's NO consolidated gateway-side pulse: incoming
-- Razorpay capture volume, authorized→captured lag, webhook→DB
-- reconciliation gap, refund inflight count, stuck pending-orders
-- across all 3 intake tables. Audit-6 + Audit-2 surfaced these as
-- recurring failure modes; this is the single-glance health dashboard.
--
-- 14 KPIs, all sourced from verified columns:
--   razorpay_webhook_events (r471): received_at, event_type, applied,
--     apply_outcome, apply_error, amount_paise, razorpay_payment_id
--   amc_payment_orders (v21): status ∈ pending/paid/failed/refunded,
--     amount_rupees, created_at
--   repair_job_escrow (v21): status ∈ pending/held/released/refunded,
--     amount_rupees, created_at
--   spare_part_orders: payment_status, razorpay_order_id, created_at
--
-- KPIs:
--   1.  captured_1h           — payment.captured events last 1h
--   2.  captured_24h          — payment.captured events last 24h
--   3.  authorized_24h        — payment.authorized (capture-lag indicator)
--   4.  refunds_created_7d    — refund.created (refund initiated)
--   5.  refunds_processed_7d  — refund.processed (money out)
--   6.  refunds_inflight      — created − processed (7d window, ≥0)
--   7.  amc_orders_pending    — amc_payment_orders.status='pending'
--   8.  escrows_pending       — repair_job_escrow.status='pending'
--   9.  spare_orders_pending  — spare_part_orders.payment_status='pending'
--                               (with razorpay_order_id set)
--   10. stale_pending_24h     — combined pending across 3 tables, >24h old
--   11. inflow_inr_24h        — sum amount_paise/100 from captured events 24h
--   12. orphan_rows_7d        — webhook event with apply_outcome='no_matching_row'
--   13. exception_rows_7d     — webhook event with apply_outcome='exception'
--   14. last_captured_at      — most recent payment.captured timestamp

BEGIN;

DROP FUNCTION IF EXISTS public.founder_razorpay_payments_pulse_summary();

CREATE OR REPLACE FUNCTION public.founder_razorpay_payments_pulse_summary()
RETURNS TABLE (
  captured_1h          bigint,
  captured_24h         bigint,
  authorized_24h       bigint,
  refunds_created_7d   bigint,
  refunds_processed_7d bigint,
  refunds_inflight     bigint,
  amc_orders_pending   bigint,
  escrows_pending      bigint,
  spare_orders_pending bigint,
  stale_pending_24h    bigint,
  inflow_inr_24h       numeric,
  orphan_rows_7d       bigint,
  exception_rows_7d    bigint,
  last_captured_at     timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hour timestamptz := now() - interval '1 hour';
  v_day  timestamptz := now() - interval '24 hours';
  v_week timestamptz := now() - interval '7 days';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- 1. payment.captured volume — last 1h
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_hour
        AND event_type = 'payment.captured')                       AS captured_1h,

    -- 2. payment.captured volume — last 24h
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day
        AND event_type = 'payment.captured')                       AS captured_24h,

    -- 3. payment.authorized 24h — gap between authorized and captured
    -- = capture-lag risk (auto-capture should normally fire same second).
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day
        AND event_type = 'payment.authorized')                     AS authorized_24h,

    -- 4. refund.created 7d
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_week
        AND event_type = 'refund.created')                         AS refunds_created_7d,

    -- 5. refund.processed 7d (money has left Razorpay)
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_week
        AND event_type = 'refund.processed')                       AS refunds_processed_7d,

    -- 6. refunds inflight = created − processed (clamped ≥ 0)
    GREATEST(0,
      (SELECT count(*)::bigint
         FROM public.razorpay_webhook_events
        WHERE received_at >= v_week
          AND event_type = 'refund.created')
      -
      (SELECT count(*)::bigint
         FROM public.razorpay_webhook_events
        WHERE received_at >= v_week
          AND event_type = 'refund.processed')
    )                                                              AS refunds_inflight,

    -- 7. AMC payment orders stuck pending (gateway intake table)
    (SELECT count(*)::bigint
       FROM public.amc_payment_orders
      WHERE status = 'pending')                                    AS amc_orders_pending,

    -- 8. Repair-job escrows stuck pending
    (SELECT count(*)::bigint
       FROM public.repair_job_escrow
      WHERE status = 'pending')                                    AS escrows_pending,

    -- 9. Spare-part orders stuck pending (with razorpay_order_id bound)
    (SELECT count(*)::bigint
       FROM public.spare_part_orders
      WHERE coalesce(payment_status,'') = 'pending'
        AND razorpay_order_id IS NOT NULL)                         AS spare_orders_pending,

    -- 10. Stale pending >24h across all 3 intake tables
    ((SELECT count(*)::bigint
        FROM public.amc_payment_orders
       WHERE status = 'pending' AND created_at < v_day)
     +
     (SELECT count(*)::bigint
        FROM public.repair_job_escrow
       WHERE status = 'pending' AND created_at < v_day)
     +
     (SELECT count(*)::bigint
        FROM public.spare_part_orders
       WHERE coalesce(payment_status,'') = 'pending'
         AND razorpay_order_id IS NOT NULL
         AND created_at < v_day))                                  AS stale_pending_24h,

    -- 11. Inflow captured 24h — amount_paise / 100 → rupees
    (SELECT coalesce(sum(amount_paise), 0)::numeric / 100.0
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day
        AND event_type = 'payment.captured'
        AND amount_paise IS NOT NULL)                              AS inflow_inr_24h,

    -- 12. Orphan rows 7d — webhook fired but no intake row matched.
    -- Common cause: env mismatch or race with create-order. Manual
    -- triage required.
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_week
        AND apply_outcome = 'no_matching_row')                     AS orphan_rows_7d,

    -- 13. Exception rows 7d — handler threw applying side-effect.
    -- Hard failure; investigate apply_error.
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_week
        AND apply_outcome = 'exception')                           AS exception_rows_7d,

    -- 14. Last payment.captured timestamp — webhook silence detector
    (SELECT max(received_at)
       FROM public.razorpay_webhook_events
      WHERE event_type = 'payment.captured')                       AS last_captured_at;
END
$$;

REVOKE EXECUTE ON FUNCTION public.founder_razorpay_payments_pulse_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_razorpay_payments_pulse_summary()
  TO authenticated;

COMMENT ON FUNCTION public.founder_razorpay_payments_pulse_summary() IS
  'Round 1221: founder console — 14-KPI gateway-side Razorpay pulse. Captured/authorized event volume (1h/24h), refund inflight, stuck-pending across all 3 intake tables (amc_payment_orders + repair_job_escrow + spare_part_orders), stale-pending >24h, captured inflow rupees 24h, orphan + exception webhook rows 7d, last-captured recency. Distinct from /amc-payment-* (AMC funnel) and /webhooks-snapshot (event volume only): this surface measures gateway health = silent revenue loss detector. Audit-6 + Audit-2 recurring failure modes.';

COMMIT;
