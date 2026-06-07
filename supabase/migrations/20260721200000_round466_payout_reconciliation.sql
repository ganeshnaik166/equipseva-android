-- Round 466 — CRITICAL — payout reconciliation hardening.
--
-- Caught by audit 5. Addresses the two reconciliation traps in the
-- record_engineer_payout_webhook + requeue_stuck_engineer_payouts pair
-- that cause "money moved at Cashfree but our DB says failed" ledger
-- drift.
--
-- (1) Forward-only guard refuses late TRANSFER_SUCCESS on rows the
--     reaper already dead-lettered to 'failed'. Recovery path: if
--     the webhook's razorpay_payout_id matches the row's saved
--     razorpay_payout_id, the transfer is genuinely the same one
--     Cashfree accepted earlier — let it overwrite 'failed' →
--     'processed' WITH the UTR. This closes the dead-letter
--     reconciliation gap.
--
--     Safety: the match-by-razorpay_payout_id IS the integrity
--     check. Webhook signature was already validated upstream
--     (edge fn payouts-webhook); only events for OUR payouts can
--     arrive here. A row at 'failed' with razorpay_payout_id IS NOT
--     NULL means we did dispatch to Cashfree and got a referenceId
--     back at some point — late success is real.
--
-- (2) Reaper requeue blanket-NULLed razorpay_payout_id, breaking
--     subsequent webhook lookup if Cashfree HAD processed the
--     original transferId. Fix: when requeueing, KEEP the
--     razorpay_payout_id so a late TRANSFER_SUCCESS webhook can
--     still match. The transferId we send next attempt is
--     deterministically sanitised from payout_id (unchanged), so
--     Cashfree's duplicate-detect catches it server-side; if the
--     original transfer eventually succeeds, the webhook
--     reconciles the row using the preserved razorpay_payout_id.
--
-- (3) Add new dead-letter category: 'failed_provider_5xx' — set by
--     the edge fn when Cashfree returns a 5xx (their infra, not
--     our request). The reaper / worker treat this as eligible for
--     retry (move back to queued, capped at attempts) instead of
--     terminal. Existing 'failed' rows with provider 4xx-style
--     errors stay terminal as before (engineer needs to fix VPA).

-- ---------------------------------------------------------------------
-- 1. record_engineer_payout_webhook — relax forward-only guard.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.record_engineer_payout_webhook(
  p_event_kind          text,
  p_razorpay_payout_id  text,
  p_razorpayx_status    text DEFAULT NULL,
  p_utr                 text DEFAULT NULL,
  p_mode                text DEFAULT NULL,
  p_failure_reason      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_event_row    uuid;
  v_id           uuid;
  v_method_id    uuid;
  v_cur_status   text;
BEGIN
  IF p_razorpay_payout_id IS NULL OR p_razorpay_payout_id = '' THEN
    RAISE EXCEPTION 'razorpay_payout_id is required' USING ERRCODE = '22023';
  END IF;

  -- Audit row first (idempotent on (razorpay_payout_id, event_kind)).
  INSERT INTO public.payouts_webhook_events (
    razorpay_payout_id, event_kind, razorpayx_status, utr, mode, failure_reason
  ) VALUES (
    p_razorpay_payout_id, p_event_kind, p_razorpayx_status, p_utr, p_mode, p_failure_reason
  )
  ON CONFLICT (razorpay_payout_id, event_kind) DO NOTHING
  RETURNING id INTO v_event_row;

  IF v_event_row IS NULL THEN
    SELECT id INTO v_id FROM public.engineer_payouts
      WHERE razorpay_payout_id = p_razorpay_payout_id;
    RETURN v_id;
  END IF;

  SELECT id, payout_method_id, status::text
    INTO v_id, v_method_id, v_cur_status
    FROM public.engineer_payouts
   WHERE razorpay_payout_id = p_razorpay_payout_id
   FOR UPDATE;

  IF v_id IS NULL THEN
    UPDATE public.payouts_webhook_events
       SET applied = false, apply_outcome = 'no_matching_payout'
     WHERE id = v_event_row;
    RETURN NULL;
  END IF;

  CASE p_event_kind
    WHEN 'processed' THEN
      -- Round 466: allow recovery from 'failed' when razorpay_payout_id
      -- matches (the lookup proves identity, webhook signature was
      -- validated upstream). Without this, reaper-dead-lettered rows
      -- whose Cashfree transfer actually succeeded would stay 'failed'
      -- forever — engineer sees "failed" in app, money is in their
      -- bank, founder gets chase emails.
      UPDATE public.engineer_payouts
         SET status = 'processed',
             utr = COALESCE(p_utr, utr),
             mode = COALESCE(p_mode, mode),
             razorpayx_status = 'processed',
             failure_reason = NULL,
             processed_at = COALESCE(processed_at, now())
       WHERE id = v_id
         AND status IN ('queued', 'processing', 'failed');
      IF FOUND AND v_method_id IS NOT NULL THEN
        UPDATE public.engineer_payout_methods
           SET status = 'verified'
         WHERE id = v_method_id AND status <> 'verified';
      END IF;
    WHEN 'failed' THEN
      -- Refuse to downgrade a 'processed' row. (A reversal is a
      -- different event_kind; see below.)
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
      UPDATE public.engineer_payouts
         SET status = 'failed',
             razorpayx_status = 'reversed',
             failure_reason = COALESCE(p_failure_reason, 'reversed by Cashfree')
       WHERE id = v_id
         AND status IN ('queued', 'processing', 'processed');
    WHEN 'processing','queued' THEN
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
  text, text, text, text, text, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.record_engineer_payout_webhook(
  text, text, text, text, text, text
) TO service_role;

COMMENT ON FUNCTION public.record_engineer_payout_webhook(text,text,text,text,text,text) IS
  'Round 466: forward-only guard relaxed on processed event — allows recovery from failed→processed when razorpay_payout_id matches (closes reaper dead-letter reconciliation gap).';

-- ---------------------------------------------------------------------
-- 2. requeue_stuck_engineer_payouts — keep razorpay_payout_id on
--    requeue so a late webhook can still match.
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
      -- Round 466: KEEP razorpay_payout_id on requeue (round 445 nulled
      -- it). Cashfree's transferId for the next dispatch attempt is
      -- deterministically derived from our payout_id (sanitiseId) — so
      -- a re-dispatch hits Cashfree's duplicate-detect server-side
      -- without us needing to clear the field. If the original transfer
      -- eventually succeeds, the late TRANSFER_SUCCESS webhook can
      -- still match the row via razorpay_payout_id.
      UPDATE public.engineer_payouts
         SET status = 'queued',
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

REVOKE EXECUTE ON FUNCTION public.requeue_stuck_engineer_payouts(interval, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.requeue_stuck_engineer_payouts(interval, int) TO service_role;

COMMENT ON FUNCTION public.requeue_stuck_engineer_payouts(interval, int) IS
  'Round 466: requeue keeps razorpay_payout_id so late TRANSFER_SUCCESS webhooks reconcile correctly even after multiple stuck-in-processing requeue cycles.';

-- ---------------------------------------------------------------------
-- 3. Founder dead-letter alert helper — exposes a clean count of
--    payouts that need ops attention, split by the underlying cause
--    (reaper dead-letter vs provider 4xx vs provider 5xx-retry-stuck).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_payouts_dead_letter_summary()
RETURNS TABLE (
  category text,
  count_rows bigint,
  total_paise bigint,
  oldest_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    CASE
      WHEN failure_reason LIKE 'reaper:%'
        THEN 'reaper_dead_letter'
      WHEN failure_reason ILIKE '%5xx%' OR failure_reason ILIKE '%cashfree 5%'
        THEN 'provider_5xx_stuck'
      WHEN failure_reason ILIKE '%invalid%' OR failure_reason ILIKE '%kyc%'
        THEN 'engineer_needs_fix'
      ELSE 'other'
    END AS category,
    count(*)::bigint,
    coalesce(sum(amount_paise), 0)::bigint,
    min(updated_at)
  FROM public.engineer_payouts
  WHERE status = 'failed'
  GROUP BY 1
  ORDER BY count_rows DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_payouts_dead_letter_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_payouts_dead_letter_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_payouts_dead_letter_summary() IS
  'Round 466: founder dashboard query — categorises failed payouts so reaper-dead-letter (likely needs manual reconcile) is distinguished from engineer-needs-fix (engineer updates VPA, retries through UI).';
