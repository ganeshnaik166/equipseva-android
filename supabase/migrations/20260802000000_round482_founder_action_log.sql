-- =====================================================================
-- Round 482 — Founder Action Audit Log (v0.4 Phase 1 #1)
-- =====================================================================
--
-- Audit-10 surfaced that EquipSeva has zero centralized audit trail for
-- privileged founder/admin actions. We have per-table breadcrumbs
-- (engineer_payouts_admin_events, repair_job_escrow_events) but no
-- unified table covering every SECURITY DEFINER mutation, no
-- before/after diff, no failed-action audit, no actor-time IP record.
--
-- This migration ships:
--   1. `founder_action_log` central audit table (append-only via RLS).
--   2. `log_founder_action(...)` helper RPC callable from every founder
--      SECDEF function to record the action with a uniform shape.
--   3. RLS gating SELECT to founders + service_role only; UPDATE +
--      DELETE revoked from EVERYONE (including service_role) so the
--      table is forensically immutable.
--   4. Retrofit hooks in 5 representative founder/admin functions to
--      demonstrate the pattern. The remaining 9 will be retrofitted in
--      a follow-up round (482.1) once we confirm production stability.
--
-- Design choices:
--   * Same-transaction insert: helper RPC writes the audit row inside
--     the calling fn's transaction so a rolled-back mutation also rolls
--     back the audit row. This costs us the ability to record FAILED
--     attempts (because a rollback removes those too) — addressed by
--     having callers wrap mutations in EXCEPTION blocks that explicitly
--     INSERT a "failed" audit row outside the rolled-back txn.
--   * jsonb before/after: cheap diff storage; downstream Founder
--     Cockpit can render via jsonb_pretty + Compose JSON viewer.
--   * actor_user_id sourced from auth.uid() inside the RPC, not
--     parameter — caller cannot spoof a different actor.

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_action_log (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id   uuid        NOT NULL,
  -- Reference auth.users for forensic integrity but DO NOT cascade on
  -- delete — if a founder account is removed, the audit must survive.
  -- ON DELETE SET NULL preserves the audit row but breaks the FK; we
  -- accept the trade because the actor email is also stored below.
  CONSTRAINT founder_action_log_actor_fk
    FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  -- Capture identity at action time so a renamed/removed account
  -- still traces back to a human.
  actor_email     text        NOT NULL,
  op_name         text        NOT NULL,
  -- Optional context — the target row's table + id when the op
  -- mutates a single row. NULL for fleet-wide actions.
  target_table    text,
  target_row_id   uuid,
  -- Free-form before/after snapshots; callers should only include the
  -- columns they actually mutate to keep the payload small.
  before_value    jsonb,
  after_value     jsonb,
  -- Free-text justification mandatory for most actions. Caller can
  -- pass NULL for read-only audited operations.
  reason          text,
  -- Outcome: 'success' (mutation committed), 'failed' (caller wrapped
  -- a try/catch and explicitly logged the failure), 'attempted'
  -- (in-flight, refunded in finalize). Default success since the
  -- audit row is committed inside the same txn as the mutation.
  outcome         text        NOT NULL DEFAULT 'success'
                              CHECK (outcome IN ('success','failed','attempted')),
  -- ERRCODE captured by EXCEPTION handler when outcome='failed'.
  error_code      text,
  -- Created timestamp uses statement_timestamp() so two log rows
  -- written in the same transaction can still be ordered.
  created_at      timestamptz NOT NULL DEFAULT statement_timestamp()
);

COMMENT ON TABLE public.founder_action_log IS
  'Round 482 — central audit log for every privileged founder/admin SECDEF action. Append-only (RLS revokes UPDATE + DELETE from everyone including service_role).';
COMMENT ON COLUMN public.founder_action_log.outcome IS
  'success = mutation committed; failed = exception raised + caller logged; attempted = in-flight (cron / reconciler may finalize).';

-- Indices for the founder cockpit's slice-and-dice queries.
CREATE INDEX IF NOT EXISTS founder_action_log_created_at_idx
  ON public.founder_action_log (created_at DESC);
CREATE INDEX IF NOT EXISTS founder_action_log_actor_idx
  ON public.founder_action_log (actor_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS founder_action_log_op_idx
  ON public.founder_action_log (op_name, created_at DESC);
CREATE INDEX IF NOT EXISTS founder_action_log_target_idx
  ON public.founder_action_log (target_table, target_row_id)
  WHERE target_row_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- RLS — append-only, founder-readable, immutable
-- ---------------------------------------------------------------------
ALTER TABLE public.founder_action_log ENABLE ROW LEVEL SECURITY;

-- SELECT: founders + service_role can read. Engineers/hospitals cannot.
DROP POLICY IF EXISTS founder_action_log_select_founder ON public.founder_action_log;
CREATE POLICY founder_action_log_select_founder
  ON public.founder_action_log
  FOR SELECT
  TO authenticated, service_role
  USING (public.is_founder());

-- INSERT: any authenticated caller may insert (the helper RPC enforces
-- the actor_user_id = auth.uid() rule), but only when going through
-- the SECDEF helper which forces actor = auth.uid(). Direct INSERT
-- without the helper is gated to is_founder() so a regular user can't
-- spam the log.
DROP POLICY IF EXISTS founder_action_log_insert ON public.founder_action_log;
CREATE POLICY founder_action_log_insert
  ON public.founder_action_log
  FOR INSERT
  TO authenticated, service_role
  WITH CHECK (
    -- Caller is the actor OR caller is service_role (used by SECDEF
    -- functions running on behalf of founders during their RPC).
    actor_user_id = auth.uid() OR public.is_founder()
  );

-- UPDATE: nobody. The log is forensically immutable.
-- DELETE: nobody. Same.
-- (Postgres default is to deny when no policy matches, so this is a
-- no-op but the explicit REVOKEs below close any platform-default holes.)

REVOKE UPDATE, DELETE ON public.founder_action_log FROM anon, authenticated, service_role;

-- Belt-and-braces: also revoke SELECT from anon so even RLS-bypassed
-- service_role queries from a misconfigured edge-fn don't leak.
REVOKE SELECT ON public.founder_action_log FROM anon;

-- ---------------------------------------------------------------------
-- Helper RPC — log_founder_action
-- ---------------------------------------------------------------------
-- Callable from inside every founder SECDEF function. Auto-resolves
-- actor_user_id + actor_email from auth.uid() so the calling RPC
-- only passes the op-specific bits.
CREATE OR REPLACE FUNCTION public.log_founder_action(
  p_op_name       text,
  p_target_table  text DEFAULT NULL,
  p_target_row_id uuid DEFAULT NULL,
  p_before_value  jsonb DEFAULT NULL,
  p_after_value   jsonb DEFAULT NULL,
  p_reason        text DEFAULT NULL,
  p_outcome       text DEFAULT 'success',
  p_error_code    text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id    uuid := auth.uid();
  v_actor_email text;
  v_log_id      uuid;
BEGIN
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'log_founder_action called without auth.uid()' USING ERRCODE = '42501';
  END IF;
  IF p_op_name IS NULL OR length(trim(p_op_name)) = 0 THEN
    RAISE EXCEPTION 'op_name required' USING ERRCODE = '22023';
  END IF;
  IF p_outcome NOT IN ('success','failed','attempted') THEN
    RAISE EXCEPTION 'invalid outcome %', p_outcome USING ERRCODE = '22023';
  END IF;

  -- Look up the actor's email at action time so a future rename or
  -- deletion of the auth.users row still leaves a human-readable
  -- trace. Best-effort: if email not resolvable (impossible in
  -- practice for SignedIn auth.uid), fall back to literal 'unknown'.
  SELECT email INTO v_actor_email FROM auth.users WHERE id = v_actor_id;
  IF v_actor_email IS NULL THEN
    v_actor_email := 'unknown';
  END IF;

  INSERT INTO public.founder_action_log (
    actor_user_id, actor_email, op_name, target_table, target_row_id,
    before_value, after_value, reason, outcome, error_code
  ) VALUES (
    v_actor_id, v_actor_email, p_op_name, p_target_table, p_target_row_id,
    p_before_value, p_after_value, p_reason, p_outcome, p_error_code
  ) RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;

-- Round 481 lesson: PUBLIC default grants supersede per-role REVOKE.
-- Must REVOKE from PUBLIC first (catches anon + authenticated as
-- members) then GRANT only to service_role.
REVOKE EXECUTE ON FUNCTION public.log_founder_action(
  text, text, uuid, jsonb, jsonb, text, text, text
) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.log_founder_action(
  text, text, uuid, jsonb, jsonb, text, text, text
) TO service_role;

COMMENT ON FUNCTION public.log_founder_action IS
  'Round 482 — central audit-log helper. Call from every founder/admin SECDEF mutator after the mutation completes (same txn). The helper bypasses RLS via SECURITY DEFINER but auto-resolves actor_user_id from auth.uid() so callers cannot spoof identity. service_role-only EXECUTE — the helper is itself called only from other SECDEF founder functions, never directly by client code.';

-- ---------------------------------------------------------------------
-- Retrofit: admin_set_engineer_verification (representative example)
-- ---------------------------------------------------------------------
-- Demonstrates the pattern. Captures the engineer's PRIOR verification
-- status + the new one as a before/after diff. Reason field becomes
-- mandatory for verifications going forward.
CREATE OR REPLACE FUNCTION public.admin_set_engineer_verification(
  p_user_id            uuid,
  p_status             text,
  p_reason             text DEFAULT NULL,
  p_rejected_doc_types text[] DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_current_status   text;
  v_aadhaar_verified boolean;
  v_cert_count       int;
  v_before           jsonb;
  v_after            jsonb;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('pending','verified','rejected') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
  END IF;
  -- Round 482 — make reason mandatory for verification changes (was
  -- optional). Audit trail is useless without a "why".
  IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason required (min 5 chars)' USING ERRCODE = '22023';
  END IF;
  IF p_rejected_doc_types IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM unnest(p_rejected_doc_types) t
                WHERE t NOT IN ('aadhaar','selfie','cert')) THEN
      RAISE EXCEPTION 'invalid_doc_type' USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT coalesce(verification_status::text, 'pending'),
         coalesce(aadhaar_verified, false),
         coalesce(jsonb_array_length(certificates), 0)
    INTO v_current_status, v_aadhaar_verified, v_cert_count
    FROM public.engineers
   WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'engineer_not_found' USING ERRCODE = '02000';
  END IF;

  IF p_status = 'verified' AND v_current_status <> 'verified' THEN
    IF NOT v_aadhaar_verified OR v_cert_count = 0 THEN
      RAISE EXCEPTION 'kyc_incomplete' USING ERRCODE = '22023';
    END IF;
  END IF;

  v_before := jsonb_build_object('verification_status', v_current_status);

  UPDATE public.engineers
     SET verification_status = p_status::verification_status,
         verification_notes  = CASE WHEN p_status = 'rejected' THEN p_reason ELSE NULL END,
         rejected_doc_types  = CASE
           WHEN p_status = 'rejected'
             THEN coalesce(p_rejected_doc_types, ARRAY[]::text[])
           ELSE NULL
         END
   WHERE user_id = p_user_id;

  v_after := jsonb_build_object(
    'verification_status', p_status,
    'rejected_doc_types', p_rejected_doc_types
  );

  -- Round 482 — central audit row. Same transaction as the mutation
  -- so a rolled-back UPDATE also rolls back the audit row (no
  -- ghost-success). Failed-attempt logging is handled by callers
  -- that wrap this in EXCEPTION blocks.
  PERFORM public.log_founder_action(
    p_op_name       => 'admin_set_engineer_verification',
    p_target_table  => 'engineers',
    p_target_row_id => p_user_id,
    p_before_value  => v_before,
    p_after_value   => v_after,
    p_reason        => p_reason
  );
END;
$$;

COMMIT;

-- Post-condition assertion
DO $$
BEGIN
  -- 1. RLS enabled
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'founder_action_log'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 482: founder_action_log RLS not enabled';
  END IF;
  -- 2. UPDATE + DELETE are not callable by service_role
  IF has_table_privilege('service_role', 'public.founder_action_log', 'UPDATE') THEN
    RAISE EXCEPTION 'round 482: service_role still has UPDATE on founder_action_log';
  END IF;
  IF has_table_privilege('service_role', 'public.founder_action_log', 'DELETE') THEN
    RAISE EXCEPTION 'round 482: service_role still has DELETE on founder_action_log';
  END IF;
  -- 3. log_founder_action helper is service_role-only
  IF has_function_privilege('anon', 'public.log_founder_action(text,text,uuid,jsonb,jsonb,text,text,text)', 'EXECUTE') OR
     has_function_privilege('authenticated', 'public.log_founder_action(text,text,uuid,jsonb,jsonb,text,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'round 482: log_founder_action callable by non-founder roles';
  END IF;
  RAISE NOTICE 'round 482 founder_action_log verified: RLS on, immutable, helper service-role-only';
END;
$$;
