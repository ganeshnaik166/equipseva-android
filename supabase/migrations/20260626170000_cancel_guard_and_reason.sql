-- Round 234 — only-hospital-can-cancel guard + cancellation_reason column.
--
-- The current status-transition guard allows `assigned → cancelled` and
-- `en_route → cancelled` for any authenticated caller. An engineer
-- assigned to a job can therefore cancel it from under the hospital.
-- Tighten: when the new status is 'cancelled', require auth.uid() to
-- match the hospital_user_id (admin/founder/service_role already bypass
-- above this block).
--
-- Add cancellation_reason TEXT column so the UI can persist the
-- hospital's "why" — long-promised in RepairJobDetailScreen.kt and
-- discarded silently until now. Capped at 500 chars via CHECK so a
-- pasted blob doesn't explode the row.

CREATE OR REPLACE FUNCTION public.repair_jobs_status_transition_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
  v_old text := OLD.status::text;
  v_new text := NEW.status::text;
BEGIN
  -- service_role / direct postgres / founder bypass.
  IF v_caller_role = 'service_role' OR session_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- No-op transitions are fine (rating writes, photo array appends, etc.
  -- all UPDATE the row but leave status alone).
  IF v_new = v_old THEN
    RETURN NEW;
  END IF;

  -- Allow-list of (old → new) pairs for non-admin callers.
  IF NOT (
    (v_old = 'requested'   AND v_new IN ('assigned','cancelled')) OR
    (v_old = 'assigned'    AND v_new IN ('en_route','in_progress','cancelled','disputed')) OR
    (v_old = 'en_route'    AND v_new IN ('in_progress','completed','cancelled','disputed')) OR
    (v_old = 'in_progress' AND v_new IN ('completed','disputed')) OR
    (v_old = 'completed'   AND v_new IN ('disputed'))
    -- 'cancelled' and 'disputed' are terminal for non-admins; only admin /
    -- service_role / founder can move them, and they bypass the check above.
  ) THEN
    RAISE EXCEPTION 'invalid status transition % -> %', v_old, v_new
      USING ERRCODE = '22023';
  END IF;

  -- Cancellation is hospital-only. Without this an engineer assigned
  -- to the job could flip status='cancelled' and lose the booking from
  -- under the hospital (RLS UPDATE policy on repair_jobs lets the
  -- engineer touch the row for status writes during in-progress flow).
  IF v_new = 'cancelled' AND auth.uid() IS NOT NULL
     AND auth.uid() <> NEW.hospital_user_id THEN
    RAISE EXCEPTION 'only the hospital can cancel a job'
      USING ERRCODE = '42501';
  END IF;

  -- Dispute is also hospital-only via the trigger fast-path; the proper
  -- entry point is dispute_repair_job_escrow which RPC-checks
  -- ownership, but defend in depth in case a direct PATCH reaches here.
  IF v_new = 'disputed' AND auth.uid() IS NOT NULL
     AND auth.uid() <> NEW.hospital_user_id THEN
    RAISE EXCEPTION 'only the hospital can open a dispute'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- cancellation_reason: persist the hospital's "why" so disputes /
-- support / engineer review have context. 500-char cap mirrors the
-- existing free-text caps in features/.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'repair_jobs'
      AND column_name = 'cancellation_reason'
  ) THEN
    ALTER TABLE public.repair_jobs
      ADD COLUMN cancellation_reason text;
    ALTER TABLE public.repair_jobs
      ADD CONSTRAINT repair_jobs_cancellation_reason_len
      CHECK (cancellation_reason IS NULL OR char_length(cancellation_reason) <= 500) NOT VALID;
    ALTER TABLE public.repair_jobs
      VALIDATE CONSTRAINT repair_jobs_cancellation_reason_len;
  END IF;
END$$;
