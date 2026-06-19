BEGIN;
-- Round 1274 — founder_payment_verify_events_summary.
--
-- payment_verify_events (round 472) is the append-only audit log of every
-- verify-* edge fn return point (verify-repair-job-payment, verify-amc-payment,
-- verify-razorpay-payment). Distinct from webhooks (raw inbound from Razorpay)
-- and razorpay-payments-pulse (gateway-side capture/refund counters) — this is
-- the SERVER-SIDE verification ledger of every HMAC-checked client redirect.
--
-- This RPC surfaces a 14-KPI overview: volume, success/failure mix, per-fn
-- breakdown, signature anomalies, and stale-stream health.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_payment_verify_events_summary();

CREATE OR REPLACE FUNCTION public.founder_payment_verify_events_summary()
RETURNS TABLE (
  events_1h                bigint,
  events_24h               bigint,
  events_7d                bigint,
  success_24h              bigint,
  idempotent_success_24h   bigint,
  failures_24h             bigint,
  invalid_signature_7d     bigint,
  amount_mismatch_7d       bigint,
  server_verify_failed_7d  bigint,
  unauthenticated_7d       bigint,
  not_owner_7d             bigint,
  distinct_fns_24h         bigint,
  distinct_payments_24h    bigint,
  last_event_at            timestamptz
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH recent AS (
    SELECT occurred_at, verify_fn, outcome, razorpay_payment_id
      FROM public.payment_verify_events
     WHERE occurred_at >= now() - interval '7 days'
  )
  SELECT
    (SELECT count(*) FROM recent WHERE occurred_at >= now() - interval '1 hour')::bigint                                                AS events_1h,
    (SELECT count(*) FROM recent WHERE occurred_at >= now() - interval '24 hours')::bigint                                              AS events_24h,
    (SELECT count(*) FROM recent)::bigint                                                                                                AS events_7d,
    (SELECT count(*) FROM recent WHERE occurred_at >= now() - interval '24 hours' AND outcome = 'success')::bigint                       AS success_24h,
    (SELECT count(*) FROM recent WHERE occurred_at >= now() - interval '24 hours' AND outcome = 'idempotent_success')::bigint            AS idempotent_success_24h,
    (SELECT count(*) FROM recent WHERE occurred_at >= now() - interval '24 hours' AND outcome NOT IN ('success','idempotent_success'))::bigint AS failures_24h,
    (SELECT count(*) FROM recent WHERE outcome = 'invalid_signature')::bigint                                                            AS invalid_signature_7d,
    (SELECT count(*) FROM recent WHERE outcome = 'amount_mismatch')::bigint                                                              AS amount_mismatch_7d,
    (SELECT count(*) FROM recent WHERE outcome = 'server_verify_failed')::bigint                                                         AS server_verify_failed_7d,
    (SELECT count(*) FROM recent WHERE outcome = 'unauthenticated')::bigint                                                              AS unauthenticated_7d,
    (SELECT count(*) FROM recent WHERE outcome = 'not_owner')::bigint                                                                    AS not_owner_7d,
    (SELECT count(DISTINCT verify_fn) FROM recent WHERE occurred_at >= now() - interval '24 hours')::bigint                              AS distinct_fns_24h,
    (SELECT count(DISTINCT razorpay_payment_id) FROM recent WHERE occurred_at >= now() - interval '24 hours' AND razorpay_payment_id IS NOT NULL)::bigint AS distinct_payments_24h,
    (SELECT max(occurred_at) FROM recent)                                                                                                AS last_event_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_payment_verify_events_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payment_verify_events_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_payment_verify_events_summary() IS
  'Round 1274: 14-KPI snapshot over payment_verify_events (round 472). Server-side verify-* edge fn ledger — distinct from webhooks (gateway inbound) and razorpay-payments-pulse (capture/refund counters). Pair with /founder_payment_verify_failures for row-level triage.';

COMMIT;
