-- Round 237 — repair_jobs_status_transition_guard bypass clause completeness.
--
-- The bypass at the top of the trigger only checks `session_user =
-- 'postgres'`. Per the column-guard-bypass memo (round 234), guards
-- invoked from SECURITY DEFINER RPCs see `session_user = 'authenticator'`
-- and `current_user = 'postgres'` — the session_user-only check fails
-- for client-initiated SECDEF calls.
--
-- Specifically: `complete_repair_job_v21` (SECURITY DEFINER, called by
-- engineers) sets status = 'completed' via UPDATE inside the function
-- body. The trigger fires under the SECDEF execution context, where
-- session_user is the *caller's* authenticator role (NOT postgres) and
-- current_user has been switched to postgres. The bypass therefore
-- doesn't trigger, the allow-list check runs, and 'in_progress ->
-- completed' falls through normally — *but* the cancellation /
-- dispute hospital-only checks at lines 57 and 66 also fire,
-- comparing auth.uid() against NEW.hospital_user_id, which works in
-- this case because completion sets v_new='completed' (not
-- 'cancelled' or 'disputed'), so the guard is silent today.
--
-- The latent hole: any future SECDEF RPC that needs to cancel or
-- dispute a job server-side (admin actions, automated SLA breaches,
-- founder ops queue) would be rejected by the hospital-only checks
-- since auth.uid() would be the admin / founder, not the hospital.
-- The fix is to mirror the bypass clause in
-- repair_jobs_payout_columns_guard (migration 20260620100000) which
-- correctly checks both.

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
  -- service_role / direct postgres / SECDEF-invoked / founder bypass.
  -- Both session_user and current_user must be checked: SECDEF calls
  -- from client roles run with session_user='authenticator' but
  -- current_user='postgres'.
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF v_new = v_old THEN
    RETURN NEW;
  END IF;

  IF NOT (
    (v_old = 'requested'   AND v_new IN ('assigned','cancelled')) OR
    (v_old = 'assigned'    AND v_new IN ('en_route','in_progress','cancelled','disputed')) OR
    (v_old = 'en_route'    AND v_new IN ('in_progress','completed','cancelled','disputed')) OR
    (v_old = 'in_progress' AND v_new IN ('completed','disputed')) OR
    (v_old = 'completed'   AND v_new IN ('disputed'))
  ) THEN
    RAISE EXCEPTION 'invalid status transition % -> %', v_old, v_new
      USING ERRCODE = '22023';
  END IF;

  IF v_new = 'cancelled' AND auth.uid() IS NOT NULL
     AND auth.uid() <> NEW.hospital_user_id THEN
    RAISE EXCEPTION 'only the hospital can cancel a job'
      USING ERRCODE = '42501';
  END IF;

  IF v_new = 'disputed' AND auth.uid() IS NOT NULL
     AND auth.uid() <> NEW.hospital_user_id THEN
    RAISE EXCEPTION 'only the hospital can open a dispute'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;
