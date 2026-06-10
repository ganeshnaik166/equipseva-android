-- Round 471 — Razorpay incoming-payment webhook receiver.
--
-- Closes audit 6's deferred CRITICAL: verify-fn 5xx after Razorpay captures
-- = stranded payment with zero automated recovery. Engineer-payout side has
-- payouts_webhook_events (round 445); incoming-payment side never had the
-- mirror table. This is it.
--
-- Schema:
--   razorpay_webhook_events: idempotent audit log of every Razorpay event
--   received (payment.captured, payment.authorized, refund.created,
--   refund.processed, etc.). Same shape as payouts_webhook_events.
--
-- RPCs:
--   record_razorpay_payment_captured(rzp_order_id, rzp_payment_id,
--                                   amount_paise) — idempotent; tries to
--                                   match the order against any of the 3
--                                   intake tables (repair_job_escrow,
--                                   spare_part_orders, amc_payment_orders)
--                                   and flips status appropriately if it
--                                   wasn't already.
--   record_razorpay_refund(rzp_refund_id, rzp_payment_id, rzp_order_id,
--                          amount_paise) — marks refund + propagates to
--                          the matching row.
--
-- The matching edge fn `razorpay-webhook` (separate file) does HMAC
-- verification of the X-Razorpay-Signature header, parses the event,
-- and calls these RPCs.

-- ---------------------------------------------------------------------
-- 1. razorpay_webhook_events — append-only audit log.
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.razorpay_webhook_events (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Razorpay's per-event UUID from the X-Razorpay-Event-Id header.
  -- Same event will arrive multiple times if our 200 is delayed; this
  -- key dedupes them.
  razorpay_event_id     text NOT NULL,
  event_type            text NOT NULL,
  razorpay_payment_id   text,
  razorpay_order_id     text,
  razorpay_refund_id    text,
  amount_paise          bigint,
  currency              text,
  payload_hash          text,
  payload               jsonb,
  received_at           timestamptz NOT NULL DEFAULT now(),
  applied               boolean NOT NULL DEFAULT false,
  apply_outcome         text,
  apply_error           text,
  CONSTRAINT razorpay_webhook_events_unique_event UNIQUE (razorpay_event_id)
);

CREATE INDEX IF NOT EXISTS idx_razorpay_webhook_events_payment
  ON public.razorpay_webhook_events (razorpay_payment_id)
  WHERE razorpay_payment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_razorpay_webhook_events_order
  ON public.razorpay_webhook_events (razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_razorpay_webhook_events_received
  ON public.razorpay_webhook_events (received_at DESC);

CREATE INDEX IF NOT EXISTS idx_razorpay_webhook_events_unapplied
  ON public.razorpay_webhook_events (received_at)
  WHERE applied = false;

ALTER TABLE public.razorpay_webhook_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS razorpay_webhook_events_founder_read ON public.razorpay_webhook_events;
CREATE POLICY razorpay_webhook_events_founder_read
  ON public.razorpay_webhook_events
  FOR SELECT
  TO authenticated
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.razorpay_webhook_events FROM authenticated, anon;
GRANT  ALL ON public.razorpay_webhook_events TO service_role;

COMMENT ON TABLE public.razorpay_webhook_events IS
  'Round 471: audit log of every Razorpay webhook event received. Idempotent on razorpay_event_id. Founder-only SELECT; service_role does all writes via record_razorpay_* RPCs.';

-- ---------------------------------------------------------------------
-- 2. record_razorpay_payment_captured — handles payment.captured AND
--    payment.authorized events. Idempotent: matches on
--    (razorpay_order_id, razorpay_payment_id) across all 3 intake tables.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_razorpay_payment_captured(
  p_razorpay_event_id   text,
  p_event_type          text,
  p_razorpay_order_id   text,
  p_razorpay_payment_id text,
  p_amount_paise        bigint,
  p_currency            text DEFAULT 'INR',
  p_payload             jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_event_row_id      uuid;
  v_matched_table     text;
  v_matched_row_id    uuid;
  v_apply_outcome     text;
  v_apply_error       text;
BEGIN
  IF p_razorpay_event_id IS NULL OR p_razorpay_event_id = '' THEN
    RAISE EXCEPTION 'razorpay_event_id is required' USING ERRCODE = '22023';
  END IF;

  -- Idempotent log insert first; the UNIQUE constraint dedupes Razorpay
  -- replays cleanly without firing side-effects twice.
  INSERT INTO public.razorpay_webhook_events (
    razorpay_event_id, event_type,
    razorpay_payment_id, razorpay_order_id,
    amount_paise, currency, payload
  ) VALUES (
    p_razorpay_event_id, p_event_type,
    p_razorpay_payment_id, p_razorpay_order_id,
    p_amount_paise, p_currency, p_payload
  )
  ON CONFLICT (razorpay_event_id) DO NOTHING
  RETURNING id INTO v_event_row_id;

  IF v_event_row_id IS NULL THEN
    -- Replay of an already-processed event. No-op.
    RETURN jsonb_build_object('ok', true, 'replayed', true);
  END IF;

  -- Try repair_job_escrow first (most common path: hospital paying for
  -- a job). Idempotency: only flip 'pending' → 'held'; if already 'held'
  -- with matching payment_id, no-op success.
  UPDATE public.repair_job_escrow
     SET status = 'held',
         razorpay_payment_id = COALESCE(razorpay_payment_id, p_razorpay_payment_id),
         paid_at = COALESCE(paid_at, now()),
         updated_at = now()
   WHERE razorpay_order_id = p_razorpay_order_id
     AND status = 'pending'
   RETURNING id INTO v_matched_row_id;
  IF v_matched_row_id IS NOT NULL THEN
    v_matched_table := 'repair_job_escrow';
    v_apply_outcome := 'escrow_flipped_to_held';
  END IF;

  -- Try spare_part_orders next.
  IF v_matched_row_id IS NULL THEN
    UPDATE public.spare_part_orders
       SET payment_status = 'completed',
           order_status   = 'confirmed',
           payment_id     = COALESCE(payment_id, p_razorpay_payment_id),
           updated_at     = now()
     WHERE razorpay_order_id = p_razorpay_order_id
       AND payment_status = 'pending'
     RETURNING id INTO v_matched_row_id;
    IF v_matched_row_id IS NOT NULL THEN
      v_matched_table := 'spare_part_orders';
      v_apply_outcome := 'order_flipped_to_completed';
    END IF;
  END IF;

  -- Try amc_payment_orders next. AMC has its own ledger-credit path;
  -- we mark the order paid here and the verify-amc-payment fn will
  -- separately call apply_amc_pool_credit when the client returns.
  -- The webhook is the safety net for "client never returns".
  IF v_matched_row_id IS NULL THEN
    UPDATE public.amc_payment_orders
       SET status = 'paid',
           razorpay_payment_id = COALESCE(razorpay_payment_id, p_razorpay_payment_id),
           paid_at = COALESCE(paid_at, now()),
           updated_at = now()
     WHERE razorpay_order_id = p_razorpay_order_id
       AND status = 'pending'
     RETURNING id INTO v_matched_row_id;
    IF v_matched_row_id IS NOT NULL THEN
      v_matched_table := 'amc_payment_orders';
      v_apply_outcome := 'amc_order_flipped_to_paid';
    END IF;
  END IF;

  -- No matching row. Could be: webhook arrived before create-order
  -- committed (rare), order already in non-pending state from prior
  -- verify-* call, or webhook is for an env mismatch. Logged but not
  -- treated as error.
  IF v_matched_row_id IS NULL THEN
    -- Check if there's a matching row already in a final state (idempotent success path).
    IF EXISTS (
      SELECT 1 FROM public.repair_job_escrow
       WHERE razorpay_order_id = p_razorpay_order_id
         AND status IN ('held','released','refunded')
    ) OR EXISTS (
      SELECT 1 FROM public.spare_part_orders
       WHERE razorpay_order_id = p_razorpay_order_id
         AND payment_status = 'completed'
    ) OR EXISTS (
      SELECT 1 FROM public.amc_payment_orders
       WHERE razorpay_order_id = p_razorpay_order_id
         AND status IN ('paid','refunded')
    ) THEN
      v_apply_outcome := 'already_final_no_op';
    ELSE
      v_apply_outcome := 'no_matching_row';
    END IF;
  END IF;

  UPDATE public.razorpay_webhook_events
     SET applied = (v_apply_outcome NOT IN ('no_matching_row')),
         apply_outcome = v_apply_outcome
   WHERE id = v_event_row_id;

  RETURN jsonb_build_object(
    'ok', true,
    'matched_table', v_matched_table,
    'matched_row_id', v_matched_row_id,
    'apply_outcome', v_apply_outcome
  );
EXCEPTION WHEN OTHERS THEN
  v_apply_error := format('%s / %s', SQLSTATE, SQLERRM);
  IF v_event_row_id IS NOT NULL THEN
    UPDATE public.razorpay_webhook_events
       SET applied = false,
           apply_outcome = 'exception',
           apply_error = v_apply_error
     WHERE id = v_event_row_id;
  END IF;
  RAISE;
END
$$;

REVOKE EXECUTE ON FUNCTION public.record_razorpay_payment_captured(
  text, text, text, text, bigint, text, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_razorpay_payment_captured(
  text, text, text, text, bigint, text, jsonb
) TO service_role;

COMMENT ON FUNCTION public.record_razorpay_payment_captured(text,text,text,text,bigint,text,jsonb) IS
  'Round 471: idempotent webhook handler for Razorpay payment.captured + payment.authorized. Tries to match razorpay_order_id against repair_job_escrow / spare_part_orders / amc_payment_orders and flips the row to its post-payment state. Safe net for verify-fn 5xx where client never returned to the app.';

-- ---------------------------------------------------------------------
-- 3. record_razorpay_refund — handles refund.created + refund.processed.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_razorpay_refund(
  p_razorpay_event_id   text,
  p_event_type          text,
  p_razorpay_refund_id  text,
  p_razorpay_payment_id text,
  p_razorpay_order_id   text,
  p_amount_paise        bigint,
  p_payload             jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_event_row_id      uuid;
  v_matched_table     text;
  v_matched_row_id    uuid;
  v_apply_outcome     text;
BEGIN
  IF p_razorpay_event_id IS NULL OR p_razorpay_event_id = '' THEN
    RAISE EXCEPTION 'razorpay_event_id is required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.razorpay_webhook_events (
    razorpay_event_id, event_type,
    razorpay_payment_id, razorpay_order_id, razorpay_refund_id,
    amount_paise, payload
  ) VALUES (
    p_razorpay_event_id, p_event_type,
    p_razorpay_payment_id, p_razorpay_order_id, p_razorpay_refund_id,
    p_amount_paise, p_payload
  )
  ON CONFLICT (razorpay_event_id) DO NOTHING
  RETURNING id INTO v_event_row_id;

  IF v_event_row_id IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'replayed', true);
  END IF;

  -- Mark refund on whichever intake table matches the order.
  -- We only act on event_type='refund.processed' (money has actually
  -- left Razorpay). 'refund.created' just logs.
  IF p_event_type = 'refund.processed' THEN
    -- repair_job_escrow: flip to 'refunded' if currently 'held' (the
    -- usual pre-release-cancel refund). Engineer payout queue should
    -- already block on this status.
    UPDATE public.repair_job_escrow
       SET status = 'refunded',
           refunded_at = COALESCE(refunded_at, now()),
           updated_at = now()
     WHERE razorpay_payment_id = p_razorpay_payment_id
       AND status IN ('held','released')
     RETURNING id INTO v_matched_row_id;
    IF v_matched_row_id IS NOT NULL THEN
      v_matched_table := 'repair_job_escrow';
      v_apply_outcome := 'escrow_refunded';
    END IF;

    IF v_matched_row_id IS NULL THEN
      UPDATE public.spare_part_orders
         SET payment_status = 'refunded',
             order_status   = 'cancelled',
             updated_at     = now()
       WHERE payment_id = p_razorpay_payment_id
         AND payment_status = 'completed'
       RETURNING id INTO v_matched_row_id;
      IF v_matched_row_id IS NOT NULL THEN
        v_matched_table := 'spare_part_orders';
        v_apply_outcome := 'spare_order_refunded';
      END IF;
    END IF;

    IF v_matched_row_id IS NULL THEN
      UPDATE public.amc_payment_orders
         SET status = 'refunded',
             updated_at = now()
       WHERE razorpay_payment_id = p_razorpay_payment_id
         AND status = 'paid'
       RETURNING id INTO v_matched_row_id;
      IF v_matched_row_id IS NOT NULL THEN
        v_matched_table := 'amc_payment_orders';
        v_apply_outcome := 'amc_order_refunded';
      END IF;
    END IF;

    IF v_matched_row_id IS NULL THEN
      v_apply_outcome := 'no_matching_row';
    END IF;
  ELSE
    -- refund.created (or any other refund event). Just log.
    v_apply_outcome := 'logged_only';
  END IF;

  UPDATE public.razorpay_webhook_events
     SET applied = (v_apply_outcome NOT IN ('no_matching_row')),
         apply_outcome = v_apply_outcome
   WHERE id = v_event_row_id;

  RETURN jsonb_build_object(
    'ok', true,
    'matched_table', v_matched_table,
    'matched_row_id', v_matched_row_id,
    'apply_outcome', v_apply_outcome
  );
END
$$;

REVOKE EXECUTE ON FUNCTION public.record_razorpay_refund(
  text, text, text, text, text, bigint, jsonb
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_razorpay_refund(
  text, text, text, text, text, bigint, jsonb
) TO service_role;

COMMENT ON FUNCTION public.record_razorpay_refund(text,text,text,text,text,bigint,jsonb) IS
  'Round 471: idempotent webhook handler for Razorpay refund.created + refund.processed. Flips matching row to refunded on processed event; logs only on created.';

-- ---------------------------------------------------------------------
-- 4. Founder ops view — unapplied / no-matching-row events for triage.
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
     AND (applied = false OR apply_outcome IN ('no_matching_row','exception'))
   ORDER BY received_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_razorpay_webhook_orphans(timestamptz)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_razorpay_webhook_orphans(timestamptz)
  TO authenticated;

COMMENT ON FUNCTION public.founder_razorpay_webhook_orphans(timestamptz) IS
  'Round 471: founder dashboard — Razorpay webhook events that didn''t match any intake row, or threw an exception applying. Common cause: webhook arrived before create-order committed (rare race). Manual triage via raw SQL when these show up.';
