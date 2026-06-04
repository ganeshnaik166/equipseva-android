-- Round 445 — close finance-fraud + state-machine holes in the
-- engineer payouts webhook + dispatch pipeline. Findings from the
-- 2026-06-04 cron+edge surface audit:
--
--   1. payouts-webhook RPC `record_engineer_payout_webhook`
--      unconditionally moves a row to 'processed' regardless of
--      current status. A replayed/out-of-order TRANSFER_SUCCESS or
--      TRANSFER_FAILED could yo-yo a payout's terminal state and
--      cascade onto payout_method.status (verified ↔ invalid).
--
--   2. No webhook event log / dedup table. Replayed events can re-fire
--      every side-effect including payout_method status changes.
--
--   3. pick_engineer_payouts_for_processing only scans status='queued'.
--      Rows that flipped to 'processing' and never received a webhook
--      (worker crash, Cashfree event drop, secret rotation) sit stuck
--      forever with no resume path. Engineer's money in limbo.
--
-- Fix:
--   A. record_engineer_payout_webhook — guard every destructive branch
--      with a WHERE status clause so the FSM becomes forward-only.
--      Idempotency via a new payouts_webhook_events table.
--
--   B. payouts_webhook_events — append-only audit log keyed on
--      (razorpay_payout_id, event_kind). UPSERT and short-circuit on
--      duplicate. Operators can `SELECT * FROM payouts_webhook_events
--      WHERE razorpay_payout_id = ...` to replay any sequence.
--
--   C. requeue_stuck_engineer_payouts(p_max_age) — reaper that picks
--      rows in 'processing' older than p_max_age, flips back to
--      'queued' (or to 'failed' after N total attempts via
--      attempts_count). Called from cron-tick on a new slot.

-- ---------------------------------------------------------------------
-- 0. attempts_count column on engineer_payouts (round-trips per row)
-- ---------------------------------------------------------------------
ALTER TABLE public.engineer_payouts
  ADD COLUMN IF NOT EXISTS attempts_count int NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------
-- 1. payouts_webhook_events — append-only audit + dedup table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payouts_webhook_events (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  razorpay_payout_id    text NOT NULL,
  event_kind            text NOT NULL,
  payload_hash          text,
  utr                   text,
  mode                  text,
  failure_reason        text,
  received_at           timestamptz NOT NULL DEFAULT now(),
  applied               boolean NOT NULL DEFAULT false,
  apply_outcome         text,
  -- Dedup key: same payout + same event_kind only logs once. If
  -- Cashfree replays the SAME event, we ignore the duplicate without
  -- re-firing side-effects.
  CONSTRAINT payouts_webhook_events_unique_event UNIQUE (razorpay_payout_id, event_kind)
);

CREATE INDEX IF NOT EXISTS idx_payouts_webhook_events_payout
  ON public.payouts_webhook_events (razorpay_payout_id);
CREATE INDEX IF NOT EXISTS idx_payouts_webhook_events_received
  ON public.payouts_webhook_events (received_at DESC);

-- All writes via the RPC below; no direct inserts.
REVOKE INSERT, UPDATE, DELETE ON public.payouts_webhook_events
  FROM anon, authenticated;

ALTER TABLE public.payouts_webhook_events ENABLE ROW LEVEL SECURITY;
-- Only founder + service_role can read. Operators investigate via the
-- founder admin surfaces; engineers never see raw webhook bodies.
CREATE POLICY "Founder reads payouts_webhook_events"
  ON public.payouts_webhook_events
  FOR SELECT
  TO authenticated
  USING (public.is_founder());

-- ---------------------------------------------------------------------
-- 2. record_engineer_payout_webhook — forward-only FSM + dedup
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_engineer_payout_webhook(
  p_razorpay_payout_id text,
  p_event_kind         text,
  p_utr                text DEFAULT NULL,
  p_mode               text DEFAULT NULL,
  p_failure_reason     text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id          uuid;
  v_method_id   uuid;
  v_cur_status  text;
  v_event_row   uuid;
  v_existing    public.payouts_webhook_events%ROWTYPE;
BEGIN
  IF p_razorpay_payout_id IS NULL THEN
    RAISE EXCEPTION 'razorpay_payout_id required' USING ERRCODE = '22023';
  END IF;
  IF p_event_kind IS NULL THEN
    RAISE EXCEPTION 'event_kind required' USING ERRCODE = '22023';
  END IF;

  -- Dedup: same (payout_id, event_kind) seen before? Short-circuit.
  -- A retry from Cashfree of the EXACT same event is a no-op — but a
  -- new event_kind for the same payout still flows through. The audit
  -- row is updated with `applied=true` only when the side-effect
  -- actually fires below.
  SELECT * INTO v_existing
    FROM public.payouts_webhook_events
   WHERE razorpay_payout_id = p_razorpay_payout_id
     AND event_kind = p_event_kind;

  IF FOUND THEN
    -- Already processed (or already seen). Don't re-fire side-effects.
    SELECT id INTO v_id FROM public.engineer_payouts
      WHERE razorpay_payout_id = p_razorpay_payout_id;
    RETURN v_id;
  END IF;

  -- Reserve the event row first so concurrent webhook deliveries dedup
  -- on the unique constraint instead of double-running the FSM update.
  INSERT INTO public.payouts_webhook_events (
    razorpay_payout_id, event_kind, utr, mode, failure_reason
  ) VALUES (
    p_razorpay_payout_id, p_event_kind, p_utr, p_mode, p_failure_reason
  )
  ON CONFLICT (razorpay_payout_id, event_kind) DO NOTHING
  RETURNING id INTO v_event_row;

  IF v_event_row IS NULL THEN
    -- Lost the insert race to another concurrent webhook delivery —
    -- that delivery owns the side-effect.
    SELECT id INTO v_id FROM public.engineer_payouts
      WHERE razorpay_payout_id = p_razorpay_payout_id;
    RETURN v_id;
  END IF;

  -- Resolve the payout row + current status under FOR UPDATE.
  SELECT id, payout_method_id, status::text
    INTO v_id, v_method_id, v_cur_status
    FROM public.engineer_payouts
   WHERE razorpay_payout_id = p_razorpay_payout_id
   FOR UPDATE;

  IF v_id IS NULL THEN
    -- Webhook for a payout we never created. Log the audit row but
    -- can't apply side-effects. Could happen if Cashfree retries an
    -- event after a different env (staging) sent it.
    UPDATE public.payouts_webhook_events
       SET applied = false, apply_outcome = 'no_matching_payout'
     WHERE id = v_event_row;
    RETURN NULL;
  END IF;

  CASE p_event_kind
    WHEN 'processed' THEN
      -- Forward-only: must currently be in queued/processing.
      -- Refuse to overwrite a 'failed' or 'processed' terminal row.
      UPDATE public.engineer_payouts
         SET status = 'processed',
             utr = COALESCE(p_utr, utr),
             mode = COALESCE(p_mode, mode),
             razorpayx_status = 'processed',
             failure_reason = NULL,
             processed_at = COALESCE(processed_at, now())
       WHERE id = v_id
         AND status IN ('queued', 'processing');
      -- First successful payout flips the method to verified.
      IF FOUND AND v_method_id IS NOT NULL THEN
        UPDATE public.engineer_payout_methods
           SET status = 'verified'
         WHERE id = v_method_id AND status <> 'verified';
      END IF;
    WHEN 'failed' THEN
      -- Refuse to downgrade a 'processed' row to 'failed' — that's the
      -- replay attack path (money moved, fake failure event would
      -- corrupt the ledger).
      UPDATE public.engineer_payouts
         SET status = 'failed',
             razorpayx_status = 'failed',
             failure_reason = p_failure_reason
       WHERE id = v_id
         AND status NOT IN ('processed', 'failed');
      IF FOUND AND v_method_id IS NOT NULL THEN
        UPDATE public.engineer_payout_methods
           SET status = 'invalid'
         WHERE id = v_method_id;
      END IF;
    WHEN 'reversed' THEN
      -- A reversal AFTER successful processing is a real event
      -- (charge-back, fraud reverse). Allow it from processed too.
      UPDATE public.engineer_payouts
         SET status = 'failed',
             razorpayx_status = 'reversed',
             failure_reason = COALESCE(p_failure_reason, 'reversed by Cashfree')
       WHERE id = v_id
         AND status IN ('queued', 'processing', 'processed');
    WHEN 'processing','queued' THEN
      -- In-flight echoes — refresh the mirror but never DOWNGRADE.
      -- e.g. an out-of-order TRANSFER_PROCESSING after TRANSFER_SUCCESS
      -- must not flip a processed row back to processing.
      UPDATE public.engineer_payouts
         SET razorpayx_status = p_event_kind
       WHERE id = v_id
         AND status NOT IN ('processed', 'failed');
    ELSE
      UPDATE public.payouts_webhook_events
         SET applied = false, apply_outcome = 'unknown_event_kind'
       WHERE id = v_event_row;
      RAISE EXCEPTION 'unknown event_kind %', p_event_kind USING ERRCODE = '22023';
  END CASE;

  -- Mark the audit row as applied (either the UPDATE matched or the
  -- guard blocked it because the row was already in terminal state).
  UPDATE public.payouts_webhook_events
     SET applied = true,
         apply_outcome = CASE
           WHEN FOUND THEN 'applied'
           ELSE 'guarded_terminal_state'
         END
   WHERE id = v_event_row;

  RETURN v_id;
END
$$;

REVOKE EXECUTE ON FUNCTION public.record_engineer_payout_webhook(
  text, text, text, text, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.record_engineer_payout_webhook(
  text, text, text, text, text
) TO service_role;

-- ---------------------------------------------------------------------
-- 3. requeue_stuck_engineer_payouts — reaper for rows stuck in
-- 'processing' past p_max_age. Bumps attempts_count + flips back to
-- 'queued' for re-dispatch. After 5 total attempts, gives up to
-- 'failed' so an operator notices.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.requeue_stuck_engineer_payouts(
  p_max_age interval DEFAULT interval '30 minutes',
  p_max_attempts int DEFAULT 5
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row          public.engineer_payouts%ROWTYPE;
  v_requeued     int := 0;
  v_dead         int := 0;
BEGIN
  FOR v_row IN
    SELECT *
      FROM public.engineer_payouts
     WHERE status = 'processing'
       AND last_attempt_at IS NOT NULL
       AND last_attempt_at < now() - p_max_age
     FOR UPDATE SKIP LOCKED
  LOOP
    IF v_row.attempts_count + 1 >= p_max_attempts THEN
      UPDATE public.engineer_payouts
         SET status = 'failed',
             failure_reason = COALESCE(
               failure_reason,
               'reaper: stuck in processing past max attempts'
             ),
             attempts_count = attempts_count + 1
       WHERE id = v_row.id;
      v_dead := v_dead + 1;
    ELSE
      UPDATE public.engineer_payouts
         SET status = 'queued',
             razorpay_payout_id = NULL,
             razorpayx_status = NULL,
             attempts_count = attempts_count + 1
       WHERE id = v_row.id;
      v_requeued := v_requeued + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'requeue_stuck_engineer_payouts: requeued % dead-lettered %',
    v_requeued, v_dead;
  RETURN v_requeued + v_dead;
END
$$;

REVOKE EXECUTE ON FUNCTION public.requeue_stuck_engineer_payouts(interval, int)
  FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.requeue_stuck_engineer_payouts(interval, int)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. Audit hook: optional comment for the cron-tick slot wiring.
-- Operator will add a new slot to supabase/functions/cron-tick/index.ts
-- in the same PR that calls requeue_stuck_engineer_payouts() every
-- hour. Choosing the cron-tick slot path (not pg_cron) so the GitHub
-- Actions log surfaces a green tick + RAISE NOTICE goes to function
-- logs for ops triage.
-- ---------------------------------------------------------------------
COMMENT ON FUNCTION public.requeue_stuck_engineer_payouts(interval, int) IS
  'Round 445 — reaper for engineer_payouts rows stuck in processing. '
  'Call hourly from cron-tick slot ''payouts-reaper''. '
  'Default: 30min stuck → requeue, 5 attempts → dead-letter to failed.';
