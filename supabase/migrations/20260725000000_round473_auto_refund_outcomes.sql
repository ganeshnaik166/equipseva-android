-- Round 473 — auto-refund outcome visibility.
--
-- Pairs with the razorpay-webhook auto-refund branch (verify-vs-cancel
-- race fix). Adds the new apply_outcome values to the founder ops
-- dashboard so triage queries surface auto-refund failures + no-creds
-- gaps.
--
-- New apply_outcome values introduced this round:
--   'auto_refund_issued'           — fresh refund successfully POSTed
--   'auto_refund_already_refunded' — Razorpay 422 already-refunded
--   'auto_refund_failed'           — refund POST returned non-2xx
--   'auto_refund_needed_no_creds'  — webhook fired but RAZORPAY_KEY_ID/SECRET unset
--
-- We update founder_razorpay_webhook_orphans to include the failure
-- outcomes (not the success ones — those don't need triage).
-- We also add founder_razorpay_auto_refunds() so the founder dashboard
-- has a clean "what got auto-refunded" feed.

-- ---------------------------------------------------------------------
-- 1. Expand founder_razorpay_webhook_orphans to surface the new
--    failure outcomes.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_razorpay_webhook_orphans(
  p_since timestamptz DEFAULT (now() - interval '7 days')
)
RETURNS TABLE (
  event_id           uuid,
  razorpay_event_id  text,
  event_type         text,
  razorpay_order_id  text,
  razorpay_payment_id text,
  amount_paise       bigint,
  apply_outcome      text,
  apply_error        text,
  received_at        timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id, razorpay_event_id, event_type, razorpay_order_id,
         razorpay_payment_id, amount_paise, apply_outcome, apply_error,
         received_at
    FROM public.razorpay_webhook_events
   WHERE received_at >= p_since
     AND (applied = false
          OR apply_outcome IN (
            'no_matching_row',
            'exception',
            'auto_refund_failed',
            'auto_refund_needed_no_creds'
          ))
   ORDER BY received_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_razorpay_webhook_orphans(timestamptz)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_razorpay_webhook_orphans(timestamptz)
  TO authenticated;

COMMENT ON FUNCTION public.founder_razorpay_webhook_orphans(timestamptz) IS
  'Round 471 + 473: founder dashboard — Razorpay webhook events needing triage. Includes no_matching_row, exception, and round 473 auto-refund failure outcomes.';

-- ---------------------------------------------------------------------
-- 2. New founder_razorpay_auto_refunds() ops feed — what got auto-refunded
--    in the verify-vs-cancel race window.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_razorpay_auto_refunds(
  p_since timestamptz DEFAULT (now() - interval '30 days')
)
RETURNS TABLE (
  event_id              uuid,
  razorpay_event_id     text,
  razorpay_order_id     text,
  razorpay_payment_id   text,
  razorpay_refund_id    text,
  amount_paise          bigint,
  apply_outcome         text,
  received_at           timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id, razorpay_event_id, razorpay_order_id,
         razorpay_payment_id, razorpay_refund_id, amount_paise,
         apply_outcome, received_at
    FROM public.razorpay_webhook_events
   WHERE received_at >= p_since
     AND apply_outcome IN (
       'auto_refund_issued',
       'auto_refund_already_refunded',
       'auto_refund_failed',
       'auto_refund_needed_no_creds'
     )
   ORDER BY received_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_razorpay_auto_refunds(timestamptz)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_razorpay_auto_refunds(timestamptz)
  TO authenticated;

COMMENT ON FUNCTION public.founder_razorpay_auto_refunds(timestamptz) IS
  'Round 473: founder dashboard — every webhook event that triggered an auto-refund attempt (verify-vs-cancel race recovery). Includes successes + failures + needs-creds.';
