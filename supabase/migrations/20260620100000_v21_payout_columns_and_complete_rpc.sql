-- v2.1 PR-D45 — close two money-fraud holes surfaced by the 2026-05-07
-- security audit:
--
-- 1. Engineer (or anyone with UPDATE rights on repair_jobs) could PATCH
--    repair_jobs.engineer_payout / platform_commission via raw REST and
--    inflate their own payout. Compute trigger only writes once on the
--    in_progress→completed transition; nothing was rejecting subsequent
--    direct writes.
--
-- 2. Engineer could self-flip status assigned/en_route/in_progress →
--    completed via the same raw REST PATCH. The status-transition guard
--    (20260428260000) explicitly allowed those pairs for non-admin
--    callers, which lets an engineer who never went on-site mark the job
--    done and start the 48h escrow auto-release timer to grab the
--    hospital's escrow without doing the work.
--
-- Fix:
--   a. Add BEFORE-UPDATE column guard rejecting any change to
--      engineer_payout / platform_commission AFTER status='completed'
--      (i.e. on already-completed rows). The compute trigger fires on
--      the same transition where OLD.status≠'completed' so it isn't
--      blocked. Admin / founder / postgres / service_role bypass for
--      ops fixes + future SECDEF refresh helpers.
--   b. Drop 'completed' from the non-admin allow-list in the status
--      transition guard. Replace the engineer-facing path with a
--      SECDEF RPC `complete_repair_job(...)` that verifies caller is
--      the assigned engineer + the row is in a transitional state, then
--      flips status='completed' as postgres (bypassing the guard).
--   c. While here, harden the status-transition guard's bypass clause
--      to accept current_user='postgres' OR session_user='postgres'
--      per memory:column_guard_bypass_pattern — future SECDEF callers
--      would otherwise hit the allow-list and fail.

-- ---------- (a) payout/commission column guard ----------------------------

CREATE OR REPLACE FUNCTION public.repair_jobs_payout_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- Bypass for elevated callers. compute_repair_job_commission_on_complete
  -- runs as part of the same UPDATE statement initiated by the caller, so
  -- we DO NOT bypass on its behalf — instead we let the row through when
  -- the transition itself is the legitimate completion (OLD.status != 'completed').
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Allow the legitimate write that happens during the in_progress/en_route
  -- → completed transition (compute trigger sets the columns from 0 to the
  -- 7%/93% split). After that, the row is in OLD.status='completed' and
  -- any further mutation of these columns from a non-admin caller is a
  -- tamper attempt.
  IF OLD.status::text <> 'completed' THEN
    RETURN NEW;
  END IF;

  IF NEW.platform_commission IS DISTINCT FROM OLD.platform_commission THEN
    RAISE EXCEPTION 'platform_commission cannot be modified after completion'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.engineer_payout IS DISTINCT FROM OLD.engineer_payout THEN
    RAISE EXCEPTION 'engineer_payout cannot be modified after completion'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS repair_jobs_payout_columns_guard_trg ON public.repair_jobs;
-- Trigger name starts 'r' so it fires AFTER 'compute_repair_job_*'
-- alphabetically. Postgres fires BEFORE-UPDATE row triggers in name
-- order so compute (which sets the columns on the legit transition)
-- runs first; this guard then evaluates OLD vs NEW correctly.
CREATE TRIGGER repair_jobs_payout_columns_guard_trg
  BEFORE UPDATE ON public.repair_jobs
  FOR EACH ROW
  WHEN (
    NEW.platform_commission IS DISTINCT FROM OLD.platform_commission
    OR NEW.engineer_payout IS DISTINCT FROM OLD.engineer_payout
  )
  EXECUTE FUNCTION public.repair_jobs_payout_columns_guard();

REVOKE ALL ON FUNCTION public.repair_jobs_payout_columns_guard() FROM PUBLIC;

-- ---------- (b) status-transition guard: drop client `→ completed` -------

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
  -- (c) bypass clause hardened: accept either session_user OR current_user
  -- = 'postgres' so SECDEF helpers can drive transitions without hitting
  -- the allow-list.
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

  -- Allow-list: 'completed' removed from non-admin paths. Engineers
  -- must call the complete_repair_job(...) SECDEF RPC below.
  IF NOT (
    (v_old = 'requested'   AND v_new IN ('assigned','cancelled')) OR
    (v_old = 'assigned'    AND v_new IN ('en_route','in_progress','cancelled','disputed')) OR
    (v_old = 'en_route'    AND v_new IN ('in_progress','cancelled','disputed')) OR
    (v_old = 'in_progress' AND v_new IN ('disputed')) OR
    (v_old = 'completed'   AND v_new IN ('disputed'))
  ) THEN
    RAISE EXCEPTION 'invalid status transition % -> %', v_old, v_new
      USING ERRCODE = '22023';
  END IF;

  RETURN NEW;
END;
$$;

-- ---------- (d) SECDEF complete_repair_job RPC ---------------------------

-- RETURNS SETOF so PostgREST emits a JSON array (matching the existing
-- pattern used by engineer_check_in_with_geo + every other repair_jobs
-- RPC). The Android client `decodeList` expects an array.
CREATE OR REPLACE FUNCTION public.complete_repair_job(
  p_repair_job_id uuid
)
RETURNS SETOF public.repair_jobs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_job public.repair_jobs;
  v_engineer_user_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_repair_job_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair job not found' USING ERRCODE = 'P0002';
  END IF;

  -- Resolve assigned engineer's user_id via engineers.user_id.
  SELECT e.user_id INTO v_engineer_user_id
    FROM public.engineers e
   WHERE e.id = v_job.engineer_id;

  IF v_engineer_user_id IS NULL OR v_engineer_user_id <> v_caller THEN
    RAISE EXCEPTION 'only the assigned engineer can mark this job complete'
      USING ERRCODE = '42501';
  END IF;

  IF v_job.status::text NOT IN ('assigned','en_route','in_progress') THEN
    RAISE EXCEPTION 'cannot complete job in status %', v_job.status
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
    UPDATE public.repair_jobs
       SET status = 'completed',
           completed_at = COALESCE(completed_at, now()),
           started_at = COALESCE(started_at, now())
     WHERE id = p_repair_job_id
   RETURNING *;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_repair_job(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_repair_job(uuid) TO authenticated;

COMMENT ON FUNCTION public.complete_repair_job(uuid) IS
  'v2.1 PR-D45 — engineer-only SECDEF path to mark a repair_job completed. '
  'Bypasses the status-transition guard (which now refuses non-admin '
  '→completed) by running as postgres. Verifies caller is the assigned '
  'engineer and the row is in assigned/en_route/in_progress.';
