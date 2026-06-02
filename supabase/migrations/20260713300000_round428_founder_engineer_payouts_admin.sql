-- Round 428 — founder admin force-pay + cancel for engineer_payouts.
--
-- While RazorpayX KYC is in flight (3-7 days for the GST cert to
-- arrive, then 3-7 more for RazorpayX onboarding), the founder is
-- paying engineers out-of-band (GPay / IMPS from a personal account).
-- Without an admin override the engineer_payouts queue accrues rows
-- at status='queued' indefinitely, the engineer's Earnings screen
-- shows "Will pay automatically after the next worker tick" forever,
-- and the founder has no clean way to record "yes, I paid this one
-- by hand on 2026-06-04, UTR REF123".
--
-- This round ships three founder-only RPCs:
--   1. admin_list_engineer_payouts(p_status) — enriched read across
--      all engineers + filterable by status. Equivalent of the
--      engineer-facing list_engineer_payouts (round 422) but
--      cross-tenant, founder-gated.
--   2. admin_mark_engineer_payout_paid(p_payout_id, p_utr, p_mode,
--      p_notes) — flips status='processed', stamps utr + mode +
--      processed_at. Same shape the RazorpayX webhook produces, so
--      the engineer sees identical "Paid · UTR REF123" subtitle on
--      both manual and automatic paths.
--   3. admin_cancel_engineer_payout(p_payout_id, p_reason) — flips
--      status='cancelled' (a refund-reversal scenario or admin
--      override after a dispute). Reason required.
--
-- All three use a new is_founder() check shared with the existing
-- founder-only RPCs (KYC queue, etc) so the gate stays consistent.

-- ---------------------------------------------------------------------
-- Re-state is_founder() in case it's missing on the linked DB. SECDEF
-- so the auth.email() resolves under the function's owner identity.
-- Founder pinning matches Profile.FOUNDER_EMAIL on the client.
-- Idempotent — older migrations may have defined this already; the
-- CREATE OR REPLACE is a safe no-op when the body matches.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_founder()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_email text;
BEGIN
  v_email := auth.email();
  IF v_email IS NULL THEN RETURN false; END IF;
  RETURN lower(v_email) = lower('ganesh1431.dhanavath@gmail.com');
END
$$;
REVOKE EXECUTE ON FUNCTION public.is_founder() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.is_founder() TO authenticated;

-- ---------------------------------------------------------------------
-- 1. admin_list_engineer_payouts — cross-tenant enriched read
-- ---------------------------------------------------------------------
-- p_status filter:
--   NULL or 'all'  → all rows
--   'queued' | 'processing' | 'processed' | 'failed' | 'cancelled'
-- Ordered queued/processing first (action-required), then processed
-- desc, so the founder lands on actionable rows at the top.
CREATE OR REPLACE FUNCTION public.admin_list_engineer_payouts(
  p_status text DEFAULT NULL,
  p_limit  int  DEFAULT 200
)
RETURNS TABLE (
  id                 uuid,
  repair_job_id      uuid,
  job_number         text,
  engineer_user_id   uuid,
  engineer_name      text,
  engineer_phone     text,
  amount_paise       bigint,
  status             text,
  mode               text,
  utr                text,
  failure_reason     text,
  destination_label  text,
  attempts           integer,
  queued_at          timestamptz,
  processed_at       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.repair_job_id,
    rj.job_number,
    p.engineer_user_id,
    pr.full_name,
    pr.phone,
    p.amount_paise,
    p.status,
    p.mode,
    p.utr,
    p.failure_reason,
    CASE
      WHEN m.id IS NULL                THEN 'No payout method on file'
      WHEN m.kind = 'upi'              THEN m.vpa
      WHEN m.kind = 'bank' AND m.bank_name IS NOT NULL
                                       THEN m.bank_name || ' •••• ' || m.account_number_last4
      ELSE                                 'Bank •••• ' || m.account_number_last4
    END AS destination_label,
    p.attempts,
    p.queued_at,
    p.processed_at
  FROM public.engineer_payouts p
  JOIN public.repair_jobs rj ON rj.id = p.repair_job_id
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  LEFT JOIN public.engineer_payout_methods m ON m.id = p.payout_method_id
  WHERE p_status IS NULL OR p_status = 'all' OR p.status = p_status
  -- Action-required (queued/processing) bubble to top via CASE rank;
  -- within that, newest queued first so the founder sees the latest
  -- demand. Settled rows sort by processed_at desc.
  ORDER BY
    CASE p.status
      WHEN 'queued'     THEN 0
      WHEN 'processing' THEN 1
      WHEN 'failed'     THEN 2
      WHEN 'processed'  THEN 3
      WHEN 'cancelled'  THEN 4
      ELSE                   5
    END,
    COALESCE(p.processed_at, p.queued_at) DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END
$$;
REVOKE EXECUTE ON FUNCTION public.admin_list_engineer_payouts(text, int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_list_engineer_payouts(text, int) TO authenticated;

-- ---------------------------------------------------------------------
-- 2. admin_mark_engineer_payout_paid — record out-of-band settlement
-- ---------------------------------------------------------------------
-- p_mode: free text but expect 'UPI' | 'IMPS' | 'NEFT' | 'RTGS' |
--         'cash' | 'other'. We don't constrain on the column CHECK
--         (which restricts to UPI/IMPS/NEFT/RTGS for RazorpayX-driven
--         rows) — manual rows can carry 'cash' / 'other' too.
-- p_utr: optional but strongly recommended. Engineer's Earnings
--        screen surfaces "Paid · UTR <utr>" when set; falls back to
--        "Paid · via <mode>" if not.
-- p_notes: founder-only audit trail, never shown to engineer.
CREATE OR REPLACE FUNCTION public.admin_mark_engineer_payout_paid(
  p_payout_id uuid,
  p_utr       text DEFAULT NULL,
  p_mode      text DEFAULT NULL,
  p_notes     text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cur record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_cur FROM public.engineer_payouts WHERE id = p_payout_id FOR UPDATE;
  IF v_cur IS NULL THEN
    RAISE EXCEPTION 'payout not found' USING ERRCODE = '02000';
  END IF;
  IF v_cur.status = 'processed' THEN
    -- Idempotent: already processed → noop, return id.
    RETURN v_cur.id;
  END IF;
  IF v_cur.status = 'cancelled' THEN
    RAISE EXCEPTION 'cannot mark a cancelled payout as paid' USING ERRCODE = '22023';
  END IF;
  -- Adversarial-review finding #4 (critical): block mark-paid when the
  -- RazorpayX worker has the row in-flight (status='processing'). If we
  -- silently overwrote that, the founder's manual GPay would land
  -- AND the RazorpayX webhook would arrive seconds later trying to flip
  -- the same row → real risk of double-spend (₹9.30 paid twice) once
  -- RazorpayX is activated. The founder must wait for the webhook
  -- (success → status='processed' automatically) or reverse the
  -- RazorpayX payout before manually overriding.
  IF v_cur.status = 'processing' THEN
    RAISE EXCEPTION
      'payout in flight with RazorpayX (status=processing). Wait for '
      'the webhook to settle or reverse the RazorpayX payout before '
      'marking paid manually.'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.engineer_payouts
     SET status = 'processed',
         utr = COALESCE(p_utr, utr),
         mode = COALESCE(p_mode, mode, 'other'),
         processed_at = now(),
         razorpayx_status = 'processed_manual',
         failure_reason = NULL
   WHERE id = p_payout_id;

  -- Audit row in the existing escrow events table for cross-reference
  -- with the rest of the per-job money trail. Keeps the audit surface
  -- centralised; a separate engineer_payouts_admin_events table would
  -- fragment the founder's "what happened to RPR-00099" forensic
  -- query into N joins.
  INSERT INTO public.repair_job_escrow_events (
    escrow_id, event_kind, actor_user_id, payload
  )
  SELECT
    v_cur.escrow_id,
    'released',
    auth.uid(),
    jsonb_build_object(
      'reason', 'admin_marked_paid_manual',
      'payout_id', v_cur.id,
      'utr', p_utr,
      'mode', p_mode,
      'notes', p_notes
    )
  WHERE v_cur.escrow_id IS NOT NULL;

  RETURN v_cur.id;
END
$$;
REVOKE EXECUTE ON FUNCTION public.admin_mark_engineer_payout_paid(
  uuid, text, text, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_mark_engineer_payout_paid(
  uuid, text, text, text
) TO authenticated;

-- ---------------------------------------------------------------------
-- 3. admin_cancel_engineer_payout — void a queued or failed row
-- ---------------------------------------------------------------------
-- For: dispute resolved against engineer → no payout due. Or:
-- engineer fraud detected, payout halted. Or: founder paid via a
-- channel that doesn't fit "processed" semantics (refund flow, etc).
CREATE OR REPLACE FUNCTION public.admin_cancel_engineer_payout(
  p_payout_id uuid,
  p_reason    text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cur record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason required (min 5 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_cur FROM public.engineer_payouts WHERE id = p_payout_id FOR UPDATE;
  IF v_cur IS NULL THEN
    RAISE EXCEPTION 'payout not found' USING ERRCODE = '02000';
  END IF;
  IF v_cur.status = 'processed' THEN
    RAISE EXCEPTION 'cannot cancel a processed payout' USING ERRCODE = '22023';
  END IF;
  IF v_cur.status = 'cancelled' THEN
    RETURN v_cur.id;
  END IF;

  UPDATE public.engineer_payouts
     SET status = 'cancelled',
         failure_reason = p_reason
   WHERE id = p_payout_id;

  INSERT INTO public.repair_job_escrow_events (
    escrow_id, event_kind, actor_user_id, payload
  )
  SELECT
    v_cur.escrow_id,
    'cancelled',
    auth.uid(),
    jsonb_build_object(
      'reason', 'admin_cancelled_payout',
      'payout_id', v_cur.id,
      'note', p_reason
    )
  WHERE v_cur.escrow_id IS NOT NULL;

  RETURN v_cur.id;
END
$$;
REVOKE EXECUTE ON FUNCTION public.admin_cancel_engineer_payout(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_cancel_engineer_payout(uuid, text) TO authenticated;
