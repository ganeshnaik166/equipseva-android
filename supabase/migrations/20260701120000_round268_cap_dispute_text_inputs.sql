-- Round 268 — cap dispute reason + engineer response lengths.
--
-- dispute_repair_job_escrow (PR-D5) and engineer_respond_to_escrow_dispute
-- (PR-D14) both enforce a *minimum* length on their text inputs (10 chars
-- so the field carries enough context for the admin review queue) but
-- accept an arbitrary *maximum*. The columns themselves are `text`
-- (unbounded), so a hostile or buggy client could write multi-megabyte
-- payloads that:
--   • bloat the row + every admin queue query that pulls these strings
--   • make the admin queue's textarea unrenderable in the founder UI
--   • inflate notifications.body excerpts indirectly
--
-- Both UI screens already cap user input at 500 chars (dispute reason)
-- and 500 chars (engineer response) on the client. This migration adds
-- the matching server-side cap so a non-Android client can't bypass.
-- Generous: 2000 chars — 4× the client cap so we don't break existing
-- queued responses on rollout, but small enough to keep the row tight.

CREATE OR REPLACE FUNCTION public.dispute_repair_job_escrow(
  p_repair_job_id uuid,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
  v_completed_at timestamptz;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF coalesce(length(trim(p_reason)),0) < 10 THEN
    RAISE EXCEPTION 'dispute reason too short (min 10 chars)' USING ERRCODE = '22023';
  END IF;
  IF length(p_reason) > 2000 THEN
    RAISE EXCEPTION 'dispute reason too long (max 2000 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow
    FROM public.repair_job_escrow
   WHERE repair_job_id = p_repair_job_id
   FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_escrow.hospital_user_id THEN
    RAISE EXCEPTION 'only hospital can open dispute' USING ERRCODE = '42501';
  END IF;
  IF v_escrow.status <> 'held' THEN
    RAISE EXCEPTION 'escrow not in held state (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  SELECT completed_at INTO v_completed_at
    FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF v_completed_at IS NULL THEN
    RAISE EXCEPTION 'job not completed' USING ERRCODE = '22023';
  END IF;
  IF now() > v_completed_at + interval '48 hours' THEN
    RAISE EXCEPTION 'dispute window closed' USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_escrow
     SET status = 'in_dispute',
         dispute_opened_at = now(),
         dispute_reason = p_reason
   WHERE id = v_escrow.id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow.id, 'disputed', v_caller,
          jsonb_build_object('reason', p_reason));

  RETURN v_escrow.id;
END;
$$;

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
  IF length(p_response) > 2000 THEN
    RAISE EXCEPTION 'response too long (max 2000 chars)' USING ERRCODE = '22023';
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

  -- Admin fan-out preserved verbatim from PR-D14. CREATE OR REPLACE
  -- would otherwise strip this side-effect.
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
