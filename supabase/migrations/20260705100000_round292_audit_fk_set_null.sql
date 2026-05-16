-- Round 292 — schema-level ON DELETE SET NULL on remaining audit FKs.
--
-- Round 285 (PR #733) NULLs four audit columns inside delete_my_account
-- before the auth.users delete. That handles the happy path. But:
--
--   * If a user is ever deleted via a path that bypasses
--     delete_my_account (Supabase admin dashboard, future helper RPC,
--     direct service-role DELETE), the FK NO-ACTION default raises
--     a foreign-key violation and the delete is blocked.
--   * The intent of the round-285 UPDATEs is "let the row survive
--     with NULL attribution" — schema-level ON DELETE SET NULL is
--     exactly that intent, expressed declaratively.
--
-- Apply to two columns still on NO ACTION:
--
--   * repair_job_cost_revisions.decision_by
--   * amc_admin_escalations.resolved_by
--
-- Round 290 already flipped repair_job_escrow.dispute_resolved_by and
-- repair_job_escrow_events.actor_user_id. After this PR every audit-
-- only FK to auth.users in the v2.1 schema is ON DELETE SET NULL.

ALTER TABLE public.repair_job_cost_revisions
  DROP CONSTRAINT IF EXISTS repair_job_cost_revisions_decision_by_fkey;

ALTER TABLE public.repair_job_cost_revisions
  ADD CONSTRAINT repair_job_cost_revisions_decision_by_fkey
    FOREIGN KEY (decision_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.amc_admin_escalations
  DROP CONSTRAINT IF EXISTS amc_admin_escalations_resolved_by_fkey;

ALTER TABLE public.amc_admin_escalations
  ADD CONSTRAINT amc_admin_escalations_resolved_by_fkey
    FOREIGN KEY (resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;
