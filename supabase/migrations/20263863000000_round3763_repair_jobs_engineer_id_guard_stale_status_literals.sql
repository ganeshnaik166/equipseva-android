-- Round 3763 — fix repair_jobs_engineer_id_guard()'s early-phase bypass,
-- which checks OLD.status against status literals that don't exist in the
-- job_status enum.
--
-- Found during a systematic sweep for more instances of the round3760/3761/
-- 3762 bug classes (enum/text mismatches + stale literals), prioritized to
-- the 67 trigger functions + 106 Android-called RPCs (the highest-blast-
-- radius + highest-reachability subset of the ~9000 functions across
-- supabase/migrations, rather than an infeasible full sweep).
--
-- The trigger's intent (per its own comment, round465):
--   "Hospital can re-assign during pending / bidding / awarded phases
--   (legitimate change-of-engineer). Once in_progress / en_route /
--   completed / cancelled, engineer_id is fixed."
--
-- But job_status's real labels are requested / assigned / en_route /
-- in_progress / completed / cancelled / disputed (confirmed: no migration
-- ever ALTER TYPE job_status ADD VALUE 'pending'/'bidding'/'awarded';
-- these three literals never existed). So:
--   IF OLD.status::text IN ('pending','bidding','awarded') THEN
--     RETURN NEW;  -- never reached — condition is always false
--   END IF;
-- ALWAYS falls through to the strict lock below, for every status,
-- including 'requested' (before ANY engineer is even assigned).
--
-- Currently DORMANT, not actively breaking users: every real write path to
-- repair_jobs.engineer_id (accept_repair_bid, auto_create_due_amc_visits,
-- re_rotate_on_engineer_unavailable — confirmed via grep) runs inside a
-- SECURITY DEFINER function owned by `postgres`, so the trigger's OWN
-- `current_user = 'postgres'` bypass already lets every legitimate call
-- through regardless of this bug; direct client PATCHes are separately
-- blocked by the column-level `REVOKE UPDATE (engineer_id) ... FROM
-- authenticated, anon` in the same migration. So today this is a latent /
-- defense-in-depth bug, not a live outage — but it means the trigger's own
-- nuanced status-based protection has never actually been exercised, and
-- would immediately misfire (block ALL engineer reassignment, even
-- legitimate pre-work-start ones) the moment any future code path writes
-- engineer_id outside a postgres-owned SECURITY DEFINER function.
--
-- Fix: correct the literal list to the real enum labels the comment
-- actually describes as "before work has started" — requested (no
-- engineer yet; accept_repair_bid's first assignment must not be blocked)
-- and assigned (hospital picks a different engineer before the assigned
-- one starts travelling). en_route and later stay locked, matching the
-- comment's stated intent exactly.
BEGIN;

CREATE OR REPLACE FUNCTION public.repair_jobs_engineer_id_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Allow during early phases (before work starts). After work starts,
  -- lock. Round 3763: was ('pending','bidding','awarded') — labels that
  -- don't exist in job_status, so this branch never fired.
  IF OLD.status::text IN ('requested','assigned') THEN
    RETURN NEW;
  END IF;

  IF NEW.engineer_id IS DISTINCT FROM OLD.engineer_id THEN
    RAISE EXCEPTION 'engineer_id cannot be changed once work has started (status=%)', OLD.status
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.repair_jobs_engineer_id_guard IS
  'Round 465 (fixed round 3763) — locks repair_jobs.engineer_id once work has started. Early-phase bypass corrected to the real job_status labels (requested, assigned); the previous literal set (pending/bidding/awarded) never matched any real status, so the bypass never fired. service_role/founder/admin/postgres-owner bypass unchanged.';

COMMIT;
