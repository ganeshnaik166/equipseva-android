-- Round 429 — durable audit log for engineer-payout admin actions +
-- server-side allowlists for mode / UTR + distinct event kinds.
--
-- Addresses findings #1, #2, #3, #7, #8 from the round-428 adversarial
-- review. Each one was real but defer-able at ship time:
--   #1, #2: Audit rows lived in repair_job_escrow_events keyed by
--     escrow_id. ON DELETE CASCADE through repair_job_escrow ->
--     repair_jobs means a delete_my_account flow would erase the
--     founder's force-pay history. Also engineer_payouts.escrow_id is
--     nullable, and round-428 RPCs guarded the INSERT with
--     WHERE escrow_id IS NOT NULL, so NULL-escrow rows produced zero
--     audit.
--   #3: mode and UTR were free text on the server, defended only at the
--     client. A direct RPC caller could store anything.
--   #7, #8: Audit rows used escrow event_kinds ('released', 'cancelled')
--     so escrow consumers couldn't tell apart real escrow events from
--     payout admin actions.
--
-- Fix: new public.engineer_payouts_admin_events table (FK-free,
-- INSERT-only) + tightened RPC validation + dedicated kinds.

-- ---------------------------------------------------------------------
-- 1. engineer_payouts_admin_events — durable, FK-free audit log
-- ---------------------------------------------------------------------
-- No FK on payout_id deliberately: if the parent payout is ever hard-
-- deleted (today there's no such path, but a future delete_my_account
-- extension might add one), the audit rows survive. Trade-off: a
-- forensic query must be tolerant of orphan payout_id values.
CREATE TABLE IF NOT EXISTS public.engineer_payouts_admin_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payout_id       uuid NOT NULL,
  actor_user_id   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  event_kind      text NOT NULL
                    CHECK (event_kind IN (
                      'admin_marked_paid',
                      'admin_cancelled',
                      'admin_revived'
                    )),
  payload         jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_payouts_admin_events_payout
  ON public.engineer_payouts_admin_events (payout_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_payouts_admin_events_actor
  ON public.engineer_payouts_admin_events (actor_user_id, occurred_at DESC);

-- INSERT-only enforcement: revoke UPDATE / DELETE entirely; only the
-- SECDEF RPCs (which run as the function owner — postgres) can write.
ALTER TABLE public.engineer_payouts_admin_events ENABLE ROW LEVEL SECURITY;

-- Founder-only SELECT (admin forensic query surface).
DROP POLICY IF EXISTS epae_select_founder ON public.engineer_payouts_admin_events;
CREATE POLICY epae_select_founder
  ON public.engineer_payouts_admin_events FOR SELECT TO authenticated
  USING (public.is_founder());
-- No INSERT/UPDATE/DELETE policies — all writes go through SECDEF.

COMMENT ON TABLE public.engineer_payouts_admin_events IS
  'Append-only audit log of founder force-pay / cancel / revive actions '
  'on engineer_payouts. FK-free against payout_id so rows survive '
  'parent-deletion. Round 429.';

-- ---------------------------------------------------------------------
-- 2. admin_mark_engineer_payout_paid — tightened validation + dedicated
--    audit table writes.
-- ---------------------------------------------------------------------
-- Changes vs round 428:
--   * (#3) Server-side allowlist on p_mode (UPI / IMPS / NEFT / RTGS /
--     cash / other). p_utr length-bounded + alphanumeric/hyphen regex.
--     p_notes capped at 1000 chars.
--   * (#1, #2) Audit row goes to engineer_payouts_admin_events
--     UNCONDITIONALLY (no escrow_id guard). The legacy
--     repair_job_escrow_events insert is kept as a SECONDARY breadcrumb
--     (still gated on escrow_id so the per-job money trail surface
--     stays intact) using a distinct payout-specific kind. The dedicated
--     event_kind 'engineer_payout_processed_manual' is NEW — needs to
--     be added to the repair_job_escrow_events.event_kind CHECK
--     constraint first (#7).
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

  -- (#3) Validate inputs server-side.
  IF p_mode IS NOT NULL AND p_mode NOT IN ('UPI','IMPS','NEFT','RTGS','cash','other') THEN
    RAISE EXCEPTION 'invalid mode % (allowed: UPI, IMPS, NEFT, RTGS, cash, other)', p_mode
      USING ERRCODE = '22023';
  END IF;
  IF p_utr IS NOT NULL THEN
    IF length(p_utr) > 64 THEN
      RAISE EXCEPTION 'utr too long (max 64 chars)' USING ERRCODE = '22023';
    END IF;
    -- Razorpay / RBI UTRs are alphanumeric, sometimes with a hyphen.
    -- Block control chars / quoting that could throw off downstream
    -- log surfaces (CSV exports, email templates).
    IF p_utr !~ '^[A-Za-z0-9-]+$' THEN
      RAISE EXCEPTION 'utr must be alphanumeric or hyphen only' USING ERRCODE = '22023';
    END IF;
  END IF;
  IF p_notes IS NOT NULL AND length(p_notes) > 1000 THEN
    RAISE EXCEPTION 'notes too long (max 1000 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_cur FROM public.engineer_payouts WHERE id = p_payout_id FOR UPDATE;
  IF v_cur IS NULL THEN
    RAISE EXCEPTION 'payout not found' USING ERRCODE = '02000';
  END IF;
  IF v_cur.status = 'processed' THEN
    RETURN v_cur.id;
  END IF;
  IF v_cur.status = 'cancelled' THEN
    RAISE EXCEPTION 'cannot mark a cancelled payout as paid' USING ERRCODE = '22023';
  END IF;
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

  -- (#1, #2) Primary durable audit — unconditional, FK-free.
  INSERT INTO public.engineer_payouts_admin_events (
    payout_id, actor_user_id, event_kind, payload
  ) VALUES (
    v_cur.id, auth.uid(), 'admin_marked_paid',
    jsonb_build_object(
      'utr', p_utr,
      'mode', p_mode,
      'notes', p_notes,
      'prior_status', v_cur.status,
      'prior_failure_reason', v_cur.failure_reason  -- #6 forensic snapshot
    )
  );

  -- Secondary breadcrumb on the per-job money trail (when escrow
  -- exists). Uses a payout-specific event_kind so escrow consumers
  -- can filter it out cleanly.
  INSERT INTO public.repair_job_escrow_events (
    escrow_id, event_kind, actor_user_id, payload
  )
  SELECT
    v_cur.escrow_id,
    'engineer_payout_processed_manual',  -- (#7) distinct kind
    auth.uid(),
    jsonb_build_object(
      'reason', 'admin_marked_paid_manual',
      'payout_id', v_cur.id,
      'utr', p_utr,
      'mode', p_mode
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
-- 3. admin_cancel_engineer_payout — dedicated audit kind + unconditional
--    durable audit row.
-- ---------------------------------------------------------------------
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
  IF length(p_reason) > 1000 THEN
    RAISE EXCEPTION 'reason too long (max 1000 chars)' USING ERRCODE = '22023';
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

  -- Primary durable audit (FK-free).
  INSERT INTO public.engineer_payouts_admin_events (
    payout_id, actor_user_id, event_kind, payload
  ) VALUES (
    v_cur.id, auth.uid(), 'admin_cancelled',
    jsonb_build_object(
      'reason', p_reason,
      'prior_status', v_cur.status,
      'prior_failure_reason', v_cur.failure_reason
    )
  );

  -- Secondary escrow breadcrumb (when escrow exists).
  INSERT INTO public.repair_job_escrow_events (
    escrow_id, event_kind, actor_user_id, payload
  )
  SELECT
    v_cur.escrow_id,
    'engineer_payout_cancelled',  -- (#8) distinct kind
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

-- ---------------------------------------------------------------------
-- 4. Extend repair_job_escrow_events.event_kind CHECK to accept the
--    new payout-specific kinds. Safe ALTER — only adds values.
-- ---------------------------------------------------------------------
-- pg can't extend a CHECK constraint in place; drop + recreate.
ALTER TABLE public.repair_job_escrow_events
  DROP CONSTRAINT IF EXISTS repair_job_escrow_events_event_kind_check;
ALTER TABLE public.repair_job_escrow_events
  ADD CONSTRAINT repair_job_escrow_events_event_kind_check
  CHECK (event_kind IN (
    -- Existing escrow lifecycle kinds (from round 422 / earlier).
    'created','paid','release_scheduled','released',
    'refunded','disputed','dispute_resolved','cancelled',
    -- Round 429 — payout admin breadcrumbs. Distinct so escrow consumers
    -- can filter them out (a payout cancellation does NOT mean the
    -- escrow itself was cancelled).
    'engineer_payout_processed_manual',
    'engineer_payout_cancelled'
  ));
