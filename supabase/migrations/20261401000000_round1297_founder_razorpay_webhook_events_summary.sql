BEGIN;
-- Round 1297 — founder_razorpay_webhook_events_summary.
--
-- razorpay_webhook_events (round 471) is the append-only audit log of every
-- inbound Razorpay webhook (payment.captured, payment.authorized,
-- refund.created, refund.processed). Distinct from payment_verify_events
-- (server-side verify-* ledger) and razorpay_payments (gateway-side capture
-- counters) — this is the SAFETY-NET ledger that catches stranded payments
-- when the verify-* fn 5xx'd and the client never returned.
--
-- 14-KPI overview: receipt volume, apply outcomes, orphan/exception signals,
-- per-intake flip breakdown, and stale-stream health.

DROP FUNCTION IF EXISTS public.founder_razorpay_webhook_events_summary();

CREATE OR REPLACE FUNCTION public.founder_razorpay_webhook_events_summary()
RETURNS TABLE (
  events_1h                bigint,
  events_24h               bigint,
  events_7d                bigint,
  applied_24h              bigint,
  no_match_24h             bigint,
  exception_24h            bigint,
  escrow_flips_7d          bigint,
  spare_flips_7d           bigint,
  amc_flips_7d             bigint,
  refunds_processed_7d     bigint,
  distinct_event_types_24h bigint,
  distinct_orders_24h      bigint,
  distinct_payments_24h    bigint,
  last_event_at            timestamptz
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH recent AS (
    SELECT received_at, event_type, applied, apply_outcome,
           razorpay_order_id, razorpay_payment_id
      FROM public.razorpay_webhook_events
     WHERE received_at >= now() - interval '7 days'
  )
  SELECT
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '1 hour')::bigint                                                AS events_1h,
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '24 hours')::bigint                                              AS events_24h,
    (SELECT count(*) FROM recent)::bigint                                                                                                AS events_7d,
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '24 hours' AND applied = true)::bigint                            AS applied_24h,
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '24 hours' AND apply_outcome = 'no_matching_row')::bigint         AS no_match_24h,
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '24 hours' AND apply_outcome = 'exception')::bigint               AS exception_24h,
    (SELECT count(*) FROM recent WHERE apply_outcome = 'escrow_flipped_to_held')::bigint                                                 AS escrow_flips_7d,
    (SELECT count(*) FROM recent WHERE apply_outcome = 'order_flipped_to_completed')::bigint                                             AS spare_flips_7d,
    (SELECT count(*) FROM recent WHERE apply_outcome = 'amc_order_flipped_to_paid')::bigint                                              AS amc_flips_7d,
    (SELECT count(*) FROM recent WHERE event_type = 'refund.processed' OR apply_outcome IN ('escrow_refunded','spare_order_refunded','amc_order_refunded'))::bigint AS refunds_processed_7d,
    (SELECT count(DISTINCT event_type) FROM recent WHERE received_at >= now() - interval '24 hours')::bigint                             AS distinct_event_types_24h,
    (SELECT count(DISTINCT razorpay_order_id) FROM recent WHERE received_at >= now() - interval '24 hours' AND razorpay_order_id IS NOT NULL)::bigint AS distinct_orders_24h,
    (SELECT count(DISTINCT razorpay_payment_id) FROM recent WHERE received_at >= now() - interval '24 hours' AND razorpay_payment_id IS NOT NULL)::bigint AS distinct_payments_24h,
    (SELECT max(received_at) FROM recent)                                                                                                AS last_event_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_razorpay_webhook_events_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_razorpay_webhook_events_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_razorpay_webhook_events_summary() IS
  'Round 1297: 14-KPI snapshot over razorpay_webhook_events (round 471). Inbound Razorpay gateway audit log — safety net for verify-* 5xx. Distinct from payment_verify_events (server-side verify ledger) and razorpay_payments (gateway-side capture counters). Pair with /founder_razorpay_webhook_orphans for row-level triage.';

COMMIT;
