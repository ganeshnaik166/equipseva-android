-- Round 406 — cap dispute_resolution_note length server-side.
--
-- Background:
--   v2.1 PR-D32 (migration 20260610100000) added repair_job_escrow.
--   dispute_resolution_note as free-form admin text. The UI side
--   (AdminResolveDisputeSheet) clamps at 500 chars via
--   `if (it.length <= 500) note = it`, and admin_resolve_escrow_dispute
--   trims + nullifs the input but does NOT enforce a length cap.
--
--   A malicious or buggy caller invoking the RPC directly with a 1 MB
--   p_note would persist it, bloat the row, and be served back through
--   admin_resolved_disputes / hospital_my_disputes / engineer_my_disputes
--   (all of which select the column verbatim).
--
-- Fix:
--   1. Add CHECK (col IS NULL OR length(col) <= 500) — matches the UI cap.
--   2. Add explicit length validation inside admin_resolve_escrow_dispute
--      so a noisy caller gets a clean error instead of a 23514 violation.
--
-- Lineage: r716 (dispute reasons), r724 (content_reports.notes),
-- r729 (user_addresses), r731 (amc_contracts.scope_text), r734 (engineers.bio),
-- r281+, r729, r736, etc.

ALTER TABLE public.repair_job_escrow
  DROP CONSTRAINT IF EXISTS repair_job_escrow_dispute_resolution_note_len_chk;

ALTER TABLE public.repair_job_escrow
  ADD CONSTRAINT repair_job_escrow_dispute_resolution_note_len_chk
  CHECK (dispute_resolution_note IS NULL OR length(dispute_resolution_note) <= 500);

-- Rebuild admin_resolve_escrow_dispute with explicit length guard.
-- Body otherwise identical to 20260610100000_v21_admin_resolve_dispute_note.sql.
DROP FUNCTION IF EXISTS public.admin_resolve_escrow_dispute(uuid, text, text);

CREATE OR REPLACE FUNCTION public.admin_resolve_escrow_dispute(
  p_escrow_id uuid,
  p_outcome   text,
  p_note      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
  v_note   text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_outcome NOT IN ('release','refund') THEN
    RAISE EXCEPTION 'outcome must be release or refund' USING ERRCODE = '22023';
  END IF;

  v_note := nullif(trim(coalesce(p_note, '')), '');

  -- Round 406: enforce the UI cap server-side so direct-RPC callers
  -- get a readable error instead of a CHECK violation.
  IF v_note IS NOT NULL AND length(v_note) > 500 THEN
    RAISE EXCEPTION 'note too long (max 500 chars)' USING ERRCODE = '22001';
  END IF;

  SELECT * INTO v_escrow FROM public.repair_job_escrow
   WHERE id = p_escrow_id FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_escrow.status <> 'in_dispute' THEN
    RAISE EXCEPTION 'escrow not in dispute (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  IF p_outcome = 'release' THEN
    UPDATE public.repair_job_escrow
       SET status = 'released',
           released_at = now(),
           dispute_resolved_at = now(),
           dispute_resolution = 'release',
           dispute_resolved_by = v_caller,
           dispute_resolution_note = v_note
     WHERE id = v_escrow.id;
  ELSE
    UPDATE public.repair_job_escrow
       SET status = 'refunded',
           refunded_at = now(),
           dispute_resolved_at = now(),
           dispute_resolution = 'refund',
           dispute_resolved_by = v_caller,
           dispute_resolution_note = v_note
     WHERE id = v_escrow.id;
  END IF;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (
    v_escrow.id,
    'dispute_resolved',
    v_caller,
    jsonb_build_object('outcome', p_outcome) ||
      CASE
        WHEN v_note IS NOT NULL THEN jsonb_build_object('note', v_note)
        ELSE '{}'::jsonb
      END
  );

  RETURN v_escrow.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_resolve_escrow_dispute(uuid, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_resolve_escrow_dispute(uuid, text, text) TO authenticated;
