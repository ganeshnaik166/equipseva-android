-- Round 424 — engineer-payouts worker helpers + razorpayx webhook RPCs.
--
-- Pair with edge fn `process-engineer-payouts` (picks queued rows, calls
-- RazorpayX Payouts API, records the result) and `razorpayx-webhook`
-- (receives payout.processed / payout.failed and flips the row).
--
-- These RPCs are all SECDEF, service_role-only (the edge functions use
-- the service-role key). No authenticated grants — the worker is the
-- single writer to engineer_payouts after the round-422 trigger.

-- ---------------------------------------------------------------------
-- 1. pick_engineer_payouts_for_processing — claim a batch atomically.
-- ---------------------------------------------------------------------
-- Worker calls with a small batch limit (default 25); we FOR UPDATE
-- SKIP LOCKED so a second concurrent worker won't claim the same rows.
-- Marks each row status='processing' + bumps attempts so the worker
-- can record retry counts even on transient failure.
--
-- Also re-resolves payout_method_id at pickup time when it's NULL —
-- handles the "engineer added their UPI AFTER the release-trigger
-- fired" case (which is exactly the 3 backfill rows from round 422).
CREATE OR REPLACE FUNCTION public.pick_engineer_payouts_for_processing(
  p_limit int DEFAULT 25
)
RETURNS TABLE (
  payout_id        uuid,
  engineer_user_id uuid,
  amount_paise     bigint,
  attempts         integer,
  method_id        uuid,
  method_kind      text,
  vpa              text,
  bank_account_holder text,
  bank_name        text,
  ifsc             text,
  account_number_encrypted text,
  account_number_last4 text,
  razorpay_contact_id text,
  razorpay_fund_account_id text,
  job_number       text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_lim int := GREATEST(1, LEAST(p_limit, 100));
BEGIN
  -- Two-stage pick: select+lock the IDs first, then patch+return the
  -- joined row data. Keeps the SKIP LOCKED scope tight to engineer_payouts
  -- without confusing the join planner.
  RETURN QUERY
  WITH claimed AS (
    SELECT p.id
      FROM public.engineer_payouts p
     WHERE p.status = 'queued'
     ORDER BY p.queued_at
     FOR UPDATE SKIP LOCKED
     LIMIT v_lim
  ),
  resolved AS (
    UPDATE public.engineer_payouts p
       SET status = 'processing',
           attempts = p.attempts + 1,
           last_attempt_at = now(),
           -- Late-bind the method: if NULL at queue time, look up the
           -- engineer's current default now. Worker still skips on NULL
           -- (no method on file) by checking method_id in the response.
           payout_method_id = COALESCE(
             p.payout_method_id,
             (SELECT id FROM public.engineer_payout_methods m
               WHERE m.user_id = p.engineer_user_id AND m.is_default = true
               LIMIT 1)
           )
      FROM claimed c
     WHERE p.id = c.id
    RETURNING p.id, p.engineer_user_id, p.amount_paise, p.attempts,
              p.payout_method_id, p.repair_job_id
  )
  SELECT
    r.id,
    r.engineer_user_id,
    r.amount_paise,
    r.attempts,
    r.payout_method_id,
    m.kind,
    m.vpa,
    m.bank_account_holder,
    m.bank_name,
    m.ifsc,
    m.account_number_encrypted,
    m.account_number_last4,
    m.razorpay_contact_id,
    m.razorpay_fund_account_id,
    rj.job_number
  FROM resolved r
  LEFT JOIN public.engineer_payout_methods m ON m.id = r.payout_method_id
  JOIN public.repair_jobs rj ON rj.id = r.repair_job_id;
END
$$;
REVOKE EXECUTE ON FUNCTION public.pick_engineer_payouts_for_processing(int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.pick_engineer_payouts_for_processing(int) TO service_role;

-- ---------------------------------------------------------------------
-- 2. record_engineer_payout_dispatch — worker stamps the call result.
-- ---------------------------------------------------------------------
-- Called once the worker has POSTed to RazorpayX. p_status comes back
-- as one of:
--   'processing'  — RazorpayX accepted (we wait for webhook to flip
--                   processed)
--   'failed'      — RazorpayX rejected synchronously (bad VPA, no
--                   contact, etc); attempts already incremented at
--                   pickup
--   'no_method'   — engineer had no default method even after the late
--                   bind in step 1 — we leave the row at 'queued' so
--                   the next worker tick can re-resolve when they add
--                   one. Also reverts attempts to keep the count honest.
CREATE OR REPLACE FUNCTION public.record_engineer_payout_dispatch(
  p_payout_id           uuid,
  p_status              text,
  p_razorpay_payout_id  text DEFAULT NULL,
  p_razorpayx_status    text DEFAULT NULL,
  p_failure_reason      text DEFAULT NULL,
  p_razorpay_contact_id text DEFAULT NULL,
  p_razorpay_fund_account_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_method_id uuid;
BEGIN
  IF p_status NOT IN ('processing','failed','no_method') THEN
    RAISE EXCEPTION 'invalid dispatch status %', p_status USING ERRCODE = '22023';
  END IF;

  IF p_status = 'no_method' THEN
    UPDATE public.engineer_payouts
       SET status = 'queued',
           -- Roll back the bump so the visible attempt count only
           -- reflects calls that actually reached RazorpayX.
           attempts = GREATEST(0, attempts - 1)
     WHERE id = p_payout_id;
    RETURN;
  END IF;

  UPDATE public.engineer_payouts
     SET status = p_status,
         razorpay_payout_id = COALESCE(p_razorpay_payout_id, razorpay_payout_id),
         razorpayx_status = COALESCE(p_razorpayx_status, razorpayx_status),
         failure_reason = p_failure_reason
   WHERE id = p_payout_id
  RETURNING payout_method_id INTO v_method_id;

  -- Cache the Razorpay handles on the method row so the next payout
  -- for this engineer skips the contact/fund_account creation calls.
  IF v_method_id IS NOT NULL
     AND (p_razorpay_contact_id IS NOT NULL OR p_razorpay_fund_account_id IS NOT NULL) THEN
    UPDATE public.engineer_payout_methods
       SET razorpay_contact_id = COALESCE(p_razorpay_contact_id, razorpay_contact_id),
           razorpay_fund_account_id = COALESCE(p_razorpay_fund_account_id, razorpay_fund_account_id)
     WHERE id = v_method_id;
  END IF;
END
$$;
REVOKE EXECUTE ON FUNCTION public.record_engineer_payout_dispatch(
  uuid, text, text, text, text, text, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.record_engineer_payout_dispatch(
  uuid, text, text, text, text, text, text
) TO service_role;

-- ---------------------------------------------------------------------
-- 3. record_engineer_payout_webhook — webhook fn flips final state.
-- ---------------------------------------------------------------------
-- Called from `razorpayx-webhook` after HMAC signature verification.
-- p_event_kind: 'processed' | 'failed' | 'reversed' | 'queued' |
--               'processing' (the in-flight echoes we just log).
-- Idempotent on (razorpay_payout_id, event_kind) via a guard inside.
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
  v_id uuid;
  v_method_id uuid;
BEGIN
  IF p_razorpay_payout_id IS NULL OR length(trim(p_razorpay_payout_id)) = 0 THEN
    RAISE EXCEPTION 'razorpay_payout_id required' USING ERRCODE = '22023';
  END IF;

  SELECT id, payout_method_id INTO v_id, v_method_id
    FROM public.engineer_payouts
   WHERE razorpay_payout_id = p_razorpay_payout_id
   FOR UPDATE;
  IF v_id IS NULL THEN
    -- Webhook for a payout we never created — log and ignore. Could
    -- happen if RazorpayX retries an event after a different env
    -- (staging) sent it.
    RETURN NULL;
  END IF;

  CASE p_event_kind
    WHEN 'processed' THEN
      UPDATE public.engineer_payouts
         SET status = 'processed',
             utr = COALESCE(p_utr, utr),
             mode = COALESCE(p_mode, mode),
             razorpayx_status = 'processed',
             failure_reason = NULL,
             processed_at = COALESCE(processed_at, now())
       WHERE id = v_id;
      -- First successful payout flips the method to verified.
      IF v_method_id IS NOT NULL THEN
        UPDATE public.engineer_payout_methods
           SET status = 'verified'
         WHERE id = v_method_id AND status <> 'verified';
      END IF;
    WHEN 'failed' THEN
      UPDATE public.engineer_payouts
         SET status = 'failed',
             razorpayx_status = 'failed',
             failure_reason = p_failure_reason
       WHERE id = v_id;
      IF v_method_id IS NOT NULL THEN
        UPDATE public.engineer_payout_methods
           SET status = 'invalid'
         WHERE id = v_method_id;
      END IF;
    WHEN 'reversed' THEN
      UPDATE public.engineer_payouts
         SET status = 'failed',
             razorpayx_status = 'reversed',
             failure_reason = COALESCE(p_failure_reason, 'reversed by RazorpayX')
       WHERE id = v_id;
    WHEN 'processing','queued' THEN
      -- In-flight echoes — refresh the mirror but don't reclassify our
      -- internal status (worker has already set processing).
      UPDATE public.engineer_payouts
         SET razorpayx_status = p_event_kind
       WHERE id = v_id;
    ELSE
      RAISE EXCEPTION 'unknown event_kind %', p_event_kind USING ERRCODE = '22023';
  END CASE;

  RETURN v_id;
END
$$;
REVOKE EXECUTE ON FUNCTION public.record_engineer_payout_webhook(
  text, text, text, text, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.record_engineer_payout_webhook(
  text, text, text, text, text
) TO service_role;
