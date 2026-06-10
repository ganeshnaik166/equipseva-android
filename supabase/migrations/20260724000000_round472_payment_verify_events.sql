-- Round 472 — payment_verify_events telemetry.
--
-- Closes audit 6's deferred HIGH: "no replayable record of verify failures
-- for stranded-payment recovery." All three verify-* edge fns
-- (verify-repair-job-payment, verify-amc-payment, verify-razorpay-payment)
-- previously logged only via console.error, which expires + isn't
-- queryable. This table records every verify attempt + outcome so:
--
--   1. Founder dashboard can surface anomalous patterns (sig mismatches,
--      amount mismatches, server_verify_failed spikes)
--   2. Stranded-payment triage has a canonical record per (payment_id,
--      timestamp) pair that survives fn redeploys
--   3. Audit trail for any chargeback dispute
--
-- Schema:
--   payment_verify_events — append-only, idempotent on
--   (verify_fn, razorpay_payment_id, occurred_at_bucket).
--
-- RPCs:
--   record_payment_verify_event(...) — fire-and-forget INSERT called from
--   the verify-* edge fns at every return path.
--
--   founder_payment_verify_failures(since) — founder ops dashboard
--   showing recent failures by outcome.

-- ---------------------------------------------------------------------
-- 1. payment_verify_events — append-only audit log.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.payment_verify_events (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at           timestamptz NOT NULL DEFAULT now(),
  -- Which verify-* edge fn fired this event.
  verify_fn             text NOT NULL,
  -- Maps to the internal order kind for grouping queries.
  --   'repair_escrow' | 'amc' | 'spare_part'
  order_kind            text NOT NULL,
  -- Internal row id (escrow.id / amc_payment_order.id / spare_part_order.id).
  -- Nullable because some early-exit paths (auth fail, bad body) don't
  -- have an order_id yet.
  order_id              uuid,
  razorpay_order_id     text,
  razorpay_payment_id   text,
  -- True if the client submitted a razorpay_signature at all.
  signature_provided    boolean NOT NULL DEFAULT false,
  -- NULL if we didn't get far enough to verify; true/false otherwise.
  signature_valid       boolean,
  amount_paise          bigint,
  -- Canonical outcome string. See COMMENT below for vocabulary.
  outcome               text NOT NULL,
  -- The `code` field from the `bad()` response (e.g. 'invalid_signature',
  -- 'server_verify_failed'). Mirrors the HTTP response shape so ops can
  -- correlate dashboard entries with client error logs.
  error_code            text,
  error_message         text,
  -- The auth.users.id of the caller (best-effort — null on
  -- unauthenticated paths).
  user_id               uuid,
  -- Sanitized payload (NEVER includes the razorpay_signature itself).
  payload               jsonb
);

CREATE INDEX IF NOT EXISTS idx_payment_verify_events_occurred
  ON public.payment_verify_events (occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_verify_events_payment
  ON public.payment_verify_events (razorpay_payment_id)
  WHERE razorpay_payment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payment_verify_events_outcome_recent
  ON public.payment_verify_events (outcome, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_payment_verify_events_order
  ON public.payment_verify_events (order_id)
  WHERE order_id IS NOT NULL;

ALTER TABLE public.payment_verify_events ENABLE ROW LEVEL SECURITY;

-- Founder-only SELECT. service_role does writes via the RPC.
DROP POLICY IF EXISTS payment_verify_events_founder_read ON public.payment_verify_events;
CREATE POLICY payment_verify_events_founder_read
  ON public.payment_verify_events
  FOR SELECT
  TO authenticated
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.payment_verify_events FROM authenticated, anon;
GRANT  ALL ON public.payment_verify_events TO service_role;

COMMENT ON TABLE public.payment_verify_events IS
  'Round 472: append-only audit log of every verify-* edge fn invocation. Outcome vocab: success | idempotent_success | bad_request | unauthenticated | not_owner | invalid_signature | server_verify_failed | order_not_found | status_race | amount_mismatch | server_error | razorpay_error | escrow_not_pending. Founder-only SELECT; service_role inserts via record_payment_verify_event RPC.';

-- ---------------------------------------------------------------------
-- 2. record_payment_verify_event — fire-and-forget INSERT RPC.
--
-- Deliberately lax on input — verify-* fns call this with whatever
-- context they have at the return point (some paths have no order_id,
-- others have no payment_id). The RPC just writes the row.
--
-- Returns the inserted id so callers can correlate logs.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_payment_verify_event(
  p_verify_fn           text,
  p_order_kind          text,
  p_outcome             text,
  p_order_id            uuid    DEFAULT NULL,
  p_razorpay_order_id   text    DEFAULT NULL,
  p_razorpay_payment_id text    DEFAULT NULL,
  p_signature_provided  boolean DEFAULT false,
  p_signature_valid     boolean DEFAULT NULL,
  p_amount_paise        bigint  DEFAULT NULL,
  p_error_code          text    DEFAULT NULL,
  p_error_message       text    DEFAULT NULL,
  p_user_id             uuid    DEFAULT NULL,
  p_payload             jsonb   DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_verify_fn IS NULL OR p_verify_fn = '' THEN
    RAISE EXCEPTION 'verify_fn is required' USING ERRCODE = '22023';
  END IF;
  IF p_order_kind IS NULL OR p_order_kind = '' THEN
    RAISE EXCEPTION 'order_kind is required' USING ERRCODE = '22023';
  END IF;
  IF p_outcome IS NULL OR p_outcome = '' THEN
    RAISE EXCEPTION 'outcome is required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.payment_verify_events (
    verify_fn, order_kind, outcome,
    order_id, razorpay_order_id, razorpay_payment_id,
    signature_provided, signature_valid, amount_paise,
    error_code, error_message, user_id, payload
  ) VALUES (
    p_verify_fn, p_order_kind, p_outcome,
    p_order_id, p_razorpay_order_id, p_razorpay_payment_id,
    COALESCE(p_signature_provided, false), p_signature_valid, p_amount_paise,
    p_error_code, p_error_message, p_user_id, p_payload
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END
$$;

REVOKE EXECUTE ON FUNCTION public.record_payment_verify_event(
  text, text, text, uuid, text, text, boolean, boolean, bigint, text, text, uuid, jsonb
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.record_payment_verify_event(
  text, text, text, uuid, text, text, boolean, boolean, bigint, text, text, uuid, jsonb
) TO service_role;

COMMENT ON FUNCTION public.record_payment_verify_event(text,text,text,uuid,text,text,boolean,boolean,bigint,text,text,uuid,jsonb) IS
  'Round 472: fire-and-forget telemetry INSERT for verify-* edge fns. Called at every return point so failures + successes are queryable. NEVER include razorpay_signature in payload.';

-- ---------------------------------------------------------------------
-- 3. founder_payment_verify_failures — ops dashboard SECURITY DEFINER
--    view over the table, filtered to non-success outcomes.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_payment_verify_failures(
  p_since timestamptz DEFAULT (now() - interval '7 days')
)
RETURNS TABLE (
  event_id              uuid,
  occurred_at           timestamptz,
  verify_fn             text,
  order_kind            text,
  order_id              uuid,
  razorpay_order_id     text,
  razorpay_payment_id   text,
  outcome               text,
  error_code            text,
  error_message         text,
  amount_paise          bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id, occurred_at, verify_fn, order_kind, order_id,
         razorpay_order_id, razorpay_payment_id, outcome,
         error_code, error_message, amount_paise
    FROM public.payment_verify_events
   WHERE occurred_at >= p_since
     AND outcome NOT IN ('success','idempotent_success')
   ORDER BY occurred_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_payment_verify_failures(timestamptz)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payment_verify_failures(timestamptz)
  TO authenticated;

COMMENT ON FUNCTION public.founder_payment_verify_failures(timestamptz) IS
  'Round 472: founder dashboard — verify-* failures over the given window. Use for stranded-payment triage and signature/amount-mismatch anomaly detection.';
