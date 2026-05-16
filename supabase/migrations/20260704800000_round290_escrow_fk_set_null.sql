-- Round 290 — fix terminal-escrow FK gap left by round 285.
--
-- Round 285 (PR #733) closed the v2.1 FK gaps for delete_my_account
-- by NULLing audit columns + raising 22023 if the user has any open
-- escrow (pending / held / in_dispute). But terminal escrows
-- (released / refunded / cancelled) still hold the
-- repair_job_escrow.{hospital,engineer}_user_id FK with NO ACTION
-- semantics — `DELETE FROM auth.users` fails for anyone whose escrow
-- history is non-empty even after every open row is resolved.
--
-- Schema change here:
--
--   1. Make hospital_user_id / engineer_user_id nullable.
--   2. Drop + recreate the auth.users FKs with ON DELETE SET NULL so
--      a user delete gracefully NULLs the column instead of blocking.
--   3. Add a row-level CHECK that REQUIRES non-null on OPEN escrows
--      (status pending/held/in_dispute). Belt-and-braces with the
--      round-285 pre-check — if the pre-check ever regresses, the
--      CHECK still rejects the SET NULL on an open row.
--   4. Also flip repair_job_escrow_events.actor_user_id and
--      repair_job_escrow.dispute_resolved_by FKs to ON DELETE SET NULL
--      (they're already nullable; round 285 NULLs them by hand. This
--      makes the schema agree with that intent so a missed delete
--      path still cleans up.)
--
-- The companion migration (20260704900000_round290_escrow_rpcs_null_safe)
-- updates the 4 RPCs that compare against the now-nullable columns so
-- a NULL value doesn't accidentally bypass an owner-check IF guard.
-- (`a <> NULL` returns NULL which IF treats as FALSE — the guard
-- silently passes and an unauthorized caller proceeds. PG-only
-- footgun.)
--
-- Idempotent: each ALTER drops first or uses IF EXISTS.

-- ---------------------------------------------------------------------
-- 1. Hospital + engineer user_id columns: drop NOT NULL.
-- ---------------------------------------------------------------------
ALTER TABLE public.repair_job_escrow
  ALTER COLUMN hospital_user_id DROP NOT NULL,
  ALTER COLUMN engineer_user_id DROP NOT NULL;

-- ---------------------------------------------------------------------
-- 2. CHECK constraint: open escrows still REQUIRE both user_ids.
--    Status-vs-nullability invariant; lets terminal rows go NULL on
--    user delete while keeping any in-flight financial row whole.
-- ---------------------------------------------------------------------
ALTER TABLE public.repair_job_escrow
  DROP CONSTRAINT IF EXISTS repair_job_escrow_open_status_user_ids_chk;
ALTER TABLE public.repair_job_escrow
  ADD CONSTRAINT repair_job_escrow_open_status_user_ids_chk
    CHECK (
      status NOT IN ('pending', 'held', 'in_dispute')
      OR (hospital_user_id IS NOT NULL AND engineer_user_id IS NOT NULL)
    );

-- ---------------------------------------------------------------------
-- 3. Re-create auth.users FKs with ON DELETE SET NULL.
--    Default constraint name = repair_job_escrow_<column>_fkey.
-- ---------------------------------------------------------------------
ALTER TABLE public.repair_job_escrow
  DROP CONSTRAINT IF EXISTS repair_job_escrow_hospital_user_id_fkey,
  DROP CONSTRAINT IF EXISTS repair_job_escrow_engineer_user_id_fkey,
  DROP CONSTRAINT IF EXISTS repair_job_escrow_dispute_resolved_by_fkey;

ALTER TABLE public.repair_job_escrow
  ADD CONSTRAINT repair_job_escrow_hospital_user_id_fkey
    FOREIGN KEY (hospital_user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD CONSTRAINT repair_job_escrow_engineer_user_id_fkey
    FOREIGN KEY (engineer_user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD CONSTRAINT repair_job_escrow_dispute_resolved_by_fkey
    FOREIGN KEY (dispute_resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------
-- 4. repair_job_escrow_events.actor_user_id — also SET NULL.
-- ---------------------------------------------------------------------
ALTER TABLE public.repair_job_escrow_events
  DROP CONSTRAINT IF EXISTS repair_job_escrow_events_actor_user_id_fkey;

ALTER TABLE public.repair_job_escrow_events
  ADD CONSTRAINT repair_job_escrow_events_actor_user_id_fkey
    FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

COMMENT ON CONSTRAINT repair_job_escrow_open_status_user_ids_chk
  ON public.repair_job_escrow IS
  'Round 290 — terminal escrows (released/refunded/cancelled) may go '
  'NULL on user delete (ON DELETE SET NULL on the FK). Open escrows '
  '(pending/held/in_dispute) must keep both user_id columns set — '
  'delete_my_account refuses if any open row would orphan, and this '
  'CHECK is the hard backstop.';
