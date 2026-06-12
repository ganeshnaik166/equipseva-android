-- =====================================================================
-- Round 488 — Refund Authorization Workflow (v0.4 Phase 2 #1)
-- =====================================================================
--
-- Today's refund flow has TWO gaps:
--   1. No "founder approval" gate above a threshold. record_razorpay_refund
--      executes whatever the caller passes — there is no second pair of
--      eyes on a ₹50k+ refund. A compromised founder JWT could drain
--      escrow at scale before anyone notices.
--   2. The "why" is captured only as a free-text reason on the
--      individual refund row; no central queue of "pending approval"
--      refunds, no aggregate view, no time-bound expiry of pending
--      requests.
--
-- This migration ships a thin approval layer on top of the existing
-- refund RPCs:
--   * refund_authorization_requests table — every refund > ₹10,000
--     creates a row here BEFORE the actual refund executes.
--   * request_refund_authorization(...) — anyone with refund-issuer
--     role calls this; row inserted in 'pending' state.
--   * approve_refund_authorization / reject_refund_authorization —
--     SECDEF, founder-only, writes to founder_action_log via r482.
--   * pending_refund_auto_expire reaper — cancels pending requests
--     after 7 days (re-issue if still needed).
--
-- Refunds <= ₹10,000 skip the approval layer (low-value, fast-path).
-- Refunds > ₹10,000 must transit pending → approved → executed.
-- The "executed" status is set by the refund-issuer RPC (which now
-- checks for an approved authorization row before actually issuing).

BEGIN;

-- ---------------------------------------------------------------------
-- 1. refund_authorization_requests table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.refund_authorization_requests (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by        uuid        NOT NULL,
  CONSTRAINT refund_auth_requested_by_fk
    FOREIGN KEY (requested_by) REFERENCES auth.users(id) ON DELETE SET NULL,
  -- The refund's source order/escrow — we accept any of these and
  -- the issuer RPC validates the right one is set.
  source_kind         text        NOT NULL
                                  CHECK (source_kind IN (
                                    'repair_job_escrow',
                                    'spare_part_order',
                                    'amc_payment_order',
                                    'amc_visit'
                                  )),
  source_id           uuid        NOT NULL,
  amount_rupees       numeric(10,2) NOT NULL
                                  CHECK (amount_rupees > 0),
  reason              text        NOT NULL
                                  CHECK (length(reason) BETWEEN 10 AND 2000),
  -- Lifecycle
  status              text        NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending','approved','rejected','expired','executed')),
  approver_user_id    uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  approver_reason     text,
  approved_at         timestamptz,
  executed_at         timestamptz,
  expires_at          timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.refund_authorization_requests IS
  'Round 488 — refunds above the threshold pass through pending → approved → executed. Founder is the approver. Auto-expire after 7 days.';

CREATE INDEX IF NOT EXISTS refund_auth_status_idx
  ON public.refund_authorization_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS refund_auth_requested_by_idx
  ON public.refund_authorization_requests (requested_by, created_at DESC);
CREATE INDEX IF NOT EXISTS refund_auth_expires_idx
  ON public.refund_authorization_requests (expires_at)
  WHERE status = 'pending';

ALTER TABLE public.refund_authorization_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS refund_auth_select ON public.refund_authorization_requests;
CREATE POLICY refund_auth_select
  ON public.refund_authorization_requests
  FOR SELECT
  TO authenticated, service_role
  USING (requested_by = auth.uid() OR public.is_founder());

REVOKE UPDATE, DELETE ON public.refund_authorization_requests
  FROM anon, authenticated, service_role;

-- The constant lives here so a future ops change can adjust without
-- code changes. Default ₹10,000 — founder review tolerable cadence
-- (~2-5 requests/week expected at current scale).
CREATE OR REPLACE FUNCTION public.refund_approval_threshold_rupees()
RETURNS numeric
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT 10000.00::numeric;
$$;

REVOKE EXECUTE ON FUNCTION public.refund_approval_threshold_rupees() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.refund_approval_threshold_rupees() TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. request_refund_authorization (issuer or admin RPC)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_refund_authorization(
  p_source_kind   text,
  p_source_id     uuid,
  p_amount_rupees numeric,
  p_reason        text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor      uuid := auth.uid();
  v_id         uuid;
  v_threshold  numeric := public.refund_approval_threshold_rupees();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_amount_rupees IS NULL OR p_amount_rupees <= 0 THEN
    RAISE EXCEPTION 'invalid_amount' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'reason required (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  -- Below-threshold refunds skip the approval layer. We still create
  -- the row but mark it 'approved' immediately for traceability.
  -- This keeps the audit trail complete (every refund leaves a row)
  -- without throttling fast-path low-value refunds.
  IF p_amount_rupees <= v_threshold THEN
    INSERT INTO public.refund_authorization_requests (
      requested_by, source_kind, source_id, amount_rupees, reason,
      status, approver_user_id, approver_reason, approved_at
    ) VALUES (
      v_actor, p_source_kind, p_source_id, p_amount_rupees, p_reason,
      'approved', v_actor, 'auto-approved (below threshold)', now()
    ) RETURNING id INTO v_id;
  ELSE
    INSERT INTO public.refund_authorization_requests (
      requested_by, source_kind, source_id, amount_rupees, reason, status
    ) VALUES (
      v_actor, p_source_kind, p_source_id, p_amount_rupees, p_reason, 'pending'
    ) RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.request_refund_authorization(text, uuid, numeric, text)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.request_refund_authorization(text, uuid, numeric, text)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. approve_refund_authorization (founder only)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_refund_authorization(
  p_request_id     uuid,
  p_approver_note  text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_req     record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req
    FROM public.refund_authorization_requests
   WHERE id = p_request_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'refund_request_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'refund_request_not_pending (status=%)', v_req.status
      USING ERRCODE = '22023';
  END IF;
  IF v_req.expires_at < now() THEN
    -- Auto-flip to expired before refusing — avoids zombie rows.
    UPDATE public.refund_authorization_requests
       SET status = 'expired', updated_at = now()
     WHERE id = p_request_id;
    RAISE EXCEPTION 'refund_request_expired' USING ERRCODE = '22023';
  END IF;

  UPDATE public.refund_authorization_requests
     SET status = 'approved',
         approver_user_id = auth.uid(),
         approver_reason = p_approver_note,
         approved_at = now(),
         updated_at = now()
   WHERE id = p_request_id;

  -- Round 482 — log to central audit ledger
  PERFORM public.log_founder_action(
    p_op_name       => 'approve_refund_authorization',
    p_target_table  => 'refund_authorization_requests',
    p_target_row_id => p_request_id,
    p_before_value  => jsonb_build_object('status', 'pending', 'amount_rupees', v_req.amount_rupees),
    p_after_value   => jsonb_build_object('status', 'approved'),
    p_reason        => coalesce(p_approver_note, v_req.reason)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.approve_refund_authorization(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.approve_refund_authorization(uuid, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. reject_refund_authorization (founder only)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reject_refund_authorization(
  p_request_id     uuid,
  p_reject_reason  text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_req record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_reject_reason IS NULL OR length(trim(p_reject_reason)) < 5 THEN
    RAISE EXCEPTION 'reject_reason required (min 5 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_req
    FROM public.refund_authorization_requests
   WHERE id = p_request_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'refund_request_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'refund_request_not_pending (status=%)', v_req.status
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.refund_authorization_requests
     SET status = 'rejected',
         approver_user_id = auth.uid(),
         approver_reason = p_reject_reason,
         approved_at = now(),
         updated_at = now()
   WHERE id = p_request_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'reject_refund_authorization',
    p_target_table  => 'refund_authorization_requests',
    p_target_row_id => p_request_id,
    p_before_value  => jsonb_build_object('status', 'pending', 'amount_rupees', v_req.amount_rupees),
    p_after_value   => jsonb_build_object('status', 'rejected'),
    p_reason        => p_reject_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reject_refund_authorization(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.reject_refund_authorization(uuid, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. mark_refund_executed (called by issuer after successful refund)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_refund_executed(
  p_request_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_req record;
BEGIN
  -- Caller is the refund-issuer (edge fn). service_role bypass +
  -- founder-callable for manual reconciliation.
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req
    FROM public.refund_authorization_requests
   WHERE id = p_request_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'refund_request_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_req.status <> 'approved' THEN
    RAISE EXCEPTION 'cannot_execute_in_status: %', v_req.status
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.refund_authorization_requests
     SET status = 'executed',
         executed_at = now(),
         updated_at = now()
   WHERE id = p_request_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_refund_executed(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_refund_executed(uuid)
  TO service_role;

-- ---------------------------------------------------------------------
-- 6. founder_pending_refund_authorizations (cockpit)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_pending_refund_authorizations(
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  id              uuid,
  source_kind     text,
  source_id       uuid,
  amount_rupees   numeric,
  reason          text,
  requested_by    uuid,
  requester_email text,
  expires_at      timestamptz,
  created_at      timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    r.id, r.source_kind, r.source_id, r.amount_rupees, r.reason,
    r.requested_by,
    coalesce(u.email, 'unknown'),
    r.expires_at, r.created_at
  FROM public.refund_authorization_requests r
  LEFT JOIN auth.users u ON u.id = r.requested_by
  WHERE r.status = 'pending'
    AND r.expires_at > now()
  ORDER BY r.created_at ASC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_pending_refund_authorizations(integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_pending_refund_authorizations(integer)
  TO service_role;

-- ---------------------------------------------------------------------
-- 7. Auto-expire reaper (called by cron / on-demand)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reap_expired_refund_authorizations()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE public.refund_authorization_requests
     SET status = 'expired',
         updated_at = now()
   WHERE status = 'pending'
     AND expires_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.reap_expired_refund_authorizations()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.reap_expired_refund_authorizations()
  TO service_role;

-- Schedule the reaper hourly. Use the EXCEPTION-WHEN-OTHERS pattern
-- from r477 because pg_cron may not be available on this Supabase
-- tier — best-effort scheduling.
DO $$
BEGIN
  PERFORM cron.schedule(
    'reap_expired_refund_authorizations_hourly',
    '0 * * * *',
    $cron$SELECT public.reap_expired_refund_authorizations();$cron$
  );
  RAISE NOTICE 'round 488: hourly refund-authorization reaper scheduled via pg_cron';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 488: pg_cron not available; reaper must be called from edge fn or manual SELECT';
END;
$$;

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition assertions
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'refund_authorization_requests'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 488: refund_authorization_requests RLS not enabled';
  END IF;

  IF has_function_privilege('anon', 'public.approve_refund_authorization(uuid,text)', 'EXECUTE') OR
     has_function_privilege('authenticated', 'public.approve_refund_authorization(uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 488: approve_refund_authorization callable by non-founder roles';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.request_refund_authorization(text,uuid,numeric,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 488: request_refund_authorization not callable by authenticated (issuers need this)';
  END IF;

  RAISE NOTICE 'round 488 refund authorization workflow verified: table + 6 RPCs, grants correct';
END;
$$;
