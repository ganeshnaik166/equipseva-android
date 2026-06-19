-- =====================================================================
-- Round 1203 — Founder webhooks snapshot summary
-- =====================================================================
--
-- Webhook health is money-pipeline lifeblood. r471 (razorpay_webhook_events)
-- + r445 (payouts_webhook_events) + r606/r881/r931 (scattered health fns)
-- exist but founder has to query 4 RPCs to know "is webhook OK right now?".
-- This consolidates the 12 most actionable signals into one glance:
-- combined event volume (1h/24h), failure counts (1h/24h), 24h success
-- rate, replay/dedupe hits, orphan rows (no_matching_row), exception
-- count, last-event recency for both sources. Webhook down = silent
-- revenue loss; this is the early-warning dashboard.
--
-- Column refs verified against actual migration files:
--   razorpay_webhook_events (r471): received_at, applied, apply_outcome,
--     apply_error, event_type
--   payouts_webhook_events (r445): received_at, applied, apply_outcome,
--     failure_reason, event_kind
-- Both: applied=false OR error-flavored apply_outcome means "failure".

BEGIN;

DROP FUNCTION IF EXISTS public.founder_webhooks_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_webhooks_snapshot_summary()
RETURNS TABLE (
  rzp_events_1h          bigint,
  rzp_events_24h         bigint,
  rzp_failed_1h          bigint,
  rzp_failed_24h         bigint,
  rzp_success_pct_24h    numeric,
  rzp_last_event_at      timestamptz,
  payouts_events_24h     bigint,
  payouts_failed_24h     bigint,
  payouts_success_pct_24h numeric,
  payouts_last_event_at  timestamptz,
  orphan_rows_7d         bigint,
  exception_rows_7d      bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hour  timestamptz := now() - interval '1 hour';
  v_day   timestamptz := now() - interval '24 hours';
  v_week  timestamptz := now() - interval '7 days';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- Razorpay inbound (payment.captured / refund.* — hospital money in)
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_hour)                              AS rzp_events_1h,

    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day)                               AS rzp_events_24h,

    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_hour
        AND (applied = false OR apply_error IS NOT NULL))       AS rzp_failed_1h,

    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day
        AND (applied = false OR apply_error IS NOT NULL))       AS rzp_failed_24h,

    -- 24h success rate (NULL when zero traffic so UI can show "—")
    (SELECT CASE
       WHEN count(*) = 0 THEN NULL::numeric
       ELSE round(
         count(*) FILTER (WHERE applied = true AND apply_error IS NULL)::numeric
         / count(*)::numeric * 100.0, 1)
     END
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_day)                               AS rzp_success_pct_24h,

    (SELECT max(received_at)
       FROM public.razorpay_webhook_events)                     AS rzp_last_event_at,

    -- Payouts outbound (engineer money out)
    (SELECT count(*)::bigint
       FROM public.payouts_webhook_events
      WHERE received_at >= v_day)                               AS payouts_events_24h,

    (SELECT count(*)::bigint
       FROM public.payouts_webhook_events
      WHERE received_at >= v_day
        AND (applied = false OR failure_reason IS NOT NULL))    AS payouts_failed_24h,

    (SELECT CASE
       WHEN count(*) = 0 THEN NULL::numeric
       ELSE round(
         count(*) FILTER (WHERE applied = true AND failure_reason IS NULL)::numeric
         / count(*)::numeric * 100.0, 1)
     END
       FROM public.payouts_webhook_events
      WHERE received_at >= v_day)                               AS payouts_success_pct_24h,

    (SELECT max(received_at)
       FROM public.payouts_webhook_events)                      AS payouts_last_event_at,

    -- Orphan rows = razorpay event matched no intake row (7d window).
    -- These need manual triage — usually webhook arrived before order
    -- row committed (rare race) or env mismatch.
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_week
        AND apply_outcome = 'no_matching_row')                  AS orphan_rows_7d,

    -- Exception rows = side-effect threw inside record_razorpay_*
    -- handler. Hard fail; investigate apply_error.
    (SELECT count(*)::bigint
       FROM public.razorpay_webhook_events
      WHERE received_at >= v_week
        AND apply_outcome = 'exception')                        AS exception_rows_7d;
END
$$;

REVOKE EXECUTE ON FUNCTION public.founder_webhooks_snapshot_summary()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_webhooks_snapshot_summary()
  TO authenticated;

COMMENT ON FUNCTION public.founder_webhooks_snapshot_summary() IS
  'Round 1203: founder console — 12-KPI single-glance webhook health snapshot. Consolidates razorpay_webhook_events + payouts_webhook_events into one row: 1h/24h volume + failures, 24h success %, orphan + exception counts (7d), last-event recency per source. Webhook down = silent revenue loss; this is the early-warning dashboard. Pair with /webhook-health + /webhook-failures-recent for drill-down.';

COMMIT;
