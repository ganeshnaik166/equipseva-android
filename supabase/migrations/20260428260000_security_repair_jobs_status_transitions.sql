-- repair_jobs.status transitions are gated client-side
-- (transitionStatus.allowedFrom in RepairJobDetailViewModel) but the RLS
-- UPDATE policy on repair_jobs lets any "involved party" — hospital_user_id
-- or assigned engineer — set status to anything. So a hospital could:
--   - UPDATE … SET status='completed' WHERE id=… AND status='requested'
--     to skip the entire bidding + work flow and trigger downstream
--     completion side effects (rating prompt, payout markers)
--   - flip back from 'completed' to 'requested' to re-list a finished job
-- Engineer-side has the symmetric risk (jump 'assigned' → 'completed'
-- without ever doing the work).
--
-- Add a BEFORE UPDATE trigger that validates each (OLD.status, NEW.status)
-- pair against an allow-list. Founder + service_role bypass the check so
-- admin tooling and edge functions (accept_repair_bid, etc.) keep working.
-- The accept_repair_bid RPC itself runs SECURITY DEFINER so it sets the
-- function owner as effective caller — bypass works there too.

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

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS repair_jobs_status_transition_guard_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_status_transition_guard_trg
  BEFORE UPDATE ON public.repair_jobs
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.repair_jobs_status_transition_guard();

REVOKE ALL ON FUNCTION public.repair_jobs_status_transition_guard() FROM PUBLIC;
