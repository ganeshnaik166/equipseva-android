-- v2.1 PR-D32: admin dispute resolution captures a note.
--
-- PR-D4 ships admin_resolve_escrow_dispute(p_escrow_id, p_outcome).
-- Today the founder picks Release vs Refund and the row flips with
-- only the outcome stamped — no record of *why*. If a hospital later
-- asks "why did the engineer get paid even though I disputed?" or an
-- engineer asks "why was I refunded when I clearly delivered?", the
-- admin has nothing to point to.
--
-- This migration:
--   1. Adds dispute_resolution_note text column to repair_job_escrow
--      (stamped at resolution, never edited)
--   2. Drops + recreates admin_resolve_escrow_dispute with a third
--      arg p_note text DEFAULT NULL (back-compat — existing two-arg
--      callers keep working)
--   3. Stamps the note on the row + on the dispute_resolved event
--      payload so both PR-D26's timeline and the resolved row's
--      detail screen surface it.

ALTER TABLE public.repair_job_escrow
  ADD COLUMN IF NOT EXISTS dispute_resolution_note text;

DROP FUNCTION IF EXISTS public.admin_resolve_escrow_dispute(uuid, text);
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
