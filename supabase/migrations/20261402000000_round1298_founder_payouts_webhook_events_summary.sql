BEGIN;
-- Round 1298 — founder_payouts_webhook_events_summary.
--
-- payouts_webhook_events (round 445) is the append-only Cashfree outbound-payout
-- webhook audit + dedup table. Each row = one (razorpay_payout_id, event_kind)
-- pair: payout.success, payout.failed, payout.reversed, payout.queued, etc.
-- Side-effects fire at most once; `applied=true` means the FSM transition was
-- actually written to engineer_payouts.
--
-- Distinct from /webhooks-snapshot-summary (consolidates BOTH inbound razorpay
-- + outbound payouts) — this is the OUTBOUND-ONLY drill. Distinct from
-- /engineer-payouts-* (which surfaces the payout rows themselves) — this is
-- the TELEMETRY ledger from Cashfree's side.
--
-- Founder needs this visible while Cashfree activation is pending: queued
-- payouts are accumulating, and once activation lands we need terminal-state
-- distribution + apply-success ratio at a single glance.

DROP FUNCTION IF EXISTS public.founder_payouts_webhook_events_summary();

CREATE OR REPLACE FUNCTION public.founder_payouts_webhook_events_summary()
RETURNS TABLE (
  events_1h               bigint,
  events_24h              bigint,
  events_7d               bigint,
  success_7d              bigint,
  failed_7d               bigint,
  reversed_7d             bigint,
  queued_7d               bigint,
  other_kinds_7d          bigint,
  applied_24h             bigint,
  unapplied_24h           bigint,
  with_utr_7d             bigint,
  distinct_payouts_24h    bigint,
  distinct_payouts_7d     bigint,
  last_event_at           timestamptz
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
    SELECT received_at, event_kind, applied, utr, razorpay_payout_id
      FROM public.payouts_webhook_events
     WHERE received_at >= now() - interval '7 days'
  )
  SELECT
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '1 hour')::bigint                                              AS events_1h,
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '24 hours')::bigint                                            AS events_24h,
    (SELECT count(*) FROM recent)::bigint                                                                                              AS events_7d,
    (SELECT count(*) FROM recent WHERE lower(event_kind) LIKE '%success%' OR lower(event_kind) LIKE '%processed%')::bigint             AS success_7d,
    (SELECT count(*) FROM recent WHERE lower(event_kind) LIKE '%fail%' OR lower(event_kind) LIKE '%reject%')::bigint                   AS failed_7d,
    (SELECT count(*) FROM recent WHERE lower(event_kind) LIKE '%revers%' OR lower(event_kind) LIKE '%return%')::bigint                 AS reversed_7d,
    (SELECT count(*) FROM recent WHERE lower(event_kind) LIKE '%queue%' OR lower(event_kind) LIKE '%pending%' OR lower(event_kind) LIKE '%initiated%')::bigint AS queued_7d,
    (SELECT count(*) FROM recent
      WHERE lower(event_kind) NOT LIKE '%success%'
        AND lower(event_kind) NOT LIKE '%processed%'
        AND lower(event_kind) NOT LIKE '%fail%'
        AND lower(event_kind) NOT LIKE '%reject%'
        AND lower(event_kind) NOT LIKE '%revers%'
        AND lower(event_kind) NOT LIKE '%return%'
        AND lower(event_kind) NOT LIKE '%queue%'
        AND lower(event_kind) NOT LIKE '%pending%'
        AND lower(event_kind) NOT LIKE '%initiated%')::bigint                                                                          AS other_kinds_7d,
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '24 hours' AND applied = true)::bigint                          AS applied_24h,
    (SELECT count(*) FROM recent WHERE received_at >= now() - interval '24 hours' AND applied = false)::bigint                         AS unapplied_24h,
    (SELECT count(*) FROM recent WHERE utr IS NOT NULL AND utr <> '')::bigint                                                          AS with_utr_7d,
    (SELECT count(DISTINCT razorpay_payout_id) FROM recent WHERE received_at >= now() - interval '24 hours')::bigint                   AS distinct_payouts_24h,
    (SELECT count(DISTINCT razorpay_payout_id) FROM recent)::bigint                                                                    AS distinct_payouts_7d,
    (SELECT max(received_at) FROM recent)                                                                                              AS last_event_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_payouts_webhook_events_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_webhook_events_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_payouts_webhook_events_summary() IS
  'Round 1298: 14-KPI snapshot over payouts_webhook_events (r445). Cashfree outbound-payout telemetry — terminal-state distribution (success/failed/reversed/queued), applied vs unapplied 24h, UTR coverage, distinct-payout reach, stream liveness. Pair with /webhooks-snapshot-summary (full consolidated) + /engineer-payout-history (row-level).';

COMMIT;