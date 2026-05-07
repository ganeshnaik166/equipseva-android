-- v2.1 PR-D29: engineer-side dispute response.
--
-- Today the engineer sees "Hospital opened a dispute" but cannot
-- post their side of the story. Admin decides on hospital's
-- dispute_reason text alone — that's a real fairness gap and a
-- pressure point that pushes engineers off-platform ("if I can't
-- defend myself in the app, I won't trust the app").
--
-- Schema:
--   * engineer_response text   — set by engineer once, mandatory ≥10 chars
--   * engineer_responded_at    — stamps the moment so timeline ordering works
-- RPC:
--   * engineer_respond_to_escrow_dispute(p_repair_job_id, p_response)
--     - Caller must be the escrow's engineer_user_id
--     - Status must be 'in_dispute'
--     - No prior engineer_response (one-shot to prevent edit-wars)
-- Event:
--   * Extends repair_job_escrow_events.event_kind CHECK to add
--     'engineer_responded' so the admin timeline (PR-D26) shows it.
-- Notification:
--   * Fans out kind=`escrow_engineer_responded` to admin/founder
--     users so the founder knows there's new context to read.
--
-- RLS for the column reads: the escrow row's existing party-select
-- policy already covers it (hospital + engineer + admin can SELECT
-- the row; column-level grants stay open).

ALTER TABLE public.repair_job_escrow
  ADD COLUMN IF NOT EXISTS engineer_response       text,
  ADD COLUMN IF NOT EXISTS engineer_responded_at   timestamptz;

-- Extend the events CHECK constraint to include the new kind. Drop +
-- recreate the constraint inline; idempotent on re-run because the
-- new constraint name matches if re-applied.
DO $$
BEGIN
  ALTER TABLE public.repair_job_escrow_events
    DROP CONSTRAINT IF EXISTS repair_job_escrow_events_event_kind_check;
  ALTER TABLE public.repair_job_escrow_events
    ADD  CONSTRAINT repair_job_escrow_events_event_kind_check
    CHECK (event_kind IN (
      'created','paid','release_scheduled','released',
      'refunded','disputed','dispute_resolved','cancelled',
      'engineer_responded'
    ));
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'event_kind constraint update failed (likely already up to date): % / %', SQLSTATE, SQLERRM;
END $$;

CREATE OR REPLACE FUNCTION public.engineer_respond_to_escrow_dispute(
  p_repair_job_id uuid,
  p_response      text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_response IS NULL OR length(trim(p_response)) < 10 THEN
    RAISE EXCEPTION 'response must be at least 10 characters' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow FROM public.repair_job_escrow
   WHERE repair_job_id = p_repair_job_id
   FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_escrow.engineer_user_id <> v_caller THEN
    RAISE EXCEPTION 'caller is not the engineer on this escrow' USING ERRCODE = '42501';
  END IF;
  IF v_escrow.status <> 'in_dispute' THEN
    RAISE EXCEPTION 'escrow not in dispute (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;
  IF v_escrow.engineer_response IS NOT NULL THEN
    RAISE EXCEPTION 'response already submitted at %', v_escrow.engineer_responded_at USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_escrow
     SET engineer_response = trim(p_response),
         engineer_responded_at = now()
   WHERE id = v_escrow.id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow.id, 'engineer_responded', v_caller,
          jsonb_build_object('response_excerpt', left(trim(p_response), 120)));

  -- Admin fan-out — founder/admin users get a notification so they
  -- know there's new context to weigh on their next dispute review.
  DECLARE v_admin uuid;
  BEGIN
    FOR v_admin IN
      SELECT id FROM auth.users u
       WHERE EXISTS (
         SELECT 1 FROM public.profiles p
          WHERE p.id = u.id
            AND (p.role::text = 'admin' OR p.is_founder = true)
       )
    LOOP
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_admin,
          'escrow_engineer_responded',
          'Engineer responded to dispute',
          left(trim(p_response), 140),
          jsonb_build_object(
            'repair_job_id', v_escrow.repair_job_id,
            'escrow_id',     v_escrow.id
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'escrow_engineer_responded notify failed: % / %', SQLSTATE, SQLERRM;
      END;
    END LOOP;
  END;

  RETURN v_escrow.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_respond_to_escrow_dispute(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_respond_to_escrow_dispute(uuid, text) TO authenticated;
