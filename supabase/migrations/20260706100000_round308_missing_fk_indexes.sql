-- Round 308 — add missing FK indexes to hot tables.
--
-- Postgres doesn't auto-index FK columns. The columns below back JOIN
-- predicates from admin dashboards, audit-trail queries, and reverse
-- FK lookups; at scale these are full table scans. Identified via a
-- 10-scout audit cross-checking REFERENCES against CREATE INDEX.
--
-- All partial WHERE-NOT-NULL where the column is nullable, to keep
-- the index small and skip the long tail of unresolved/in-progress rows.

CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_dispute_resolved_by
  ON public.repair_job_escrow (dispute_resolved_by)
  WHERE dispute_resolved_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_amc_admin_escalations_visit_id
  ON public.amc_admin_escalations (visit_id)
  WHERE visit_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_amc_admin_escalations_resolved_by
  ON public.amc_admin_escalations (resolved_by)
  WHERE resolved_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_amc_sla_breaches_credit_ledger_id
  ON public.amc_sla_breaches (credit_ledger_id)
  WHERE credit_ledger_id IS NOT NULL;

-- amc_engineer_rotation already has (contract_id, priority) WHERE active=true,
-- but engineer-keyed queries ("which contracts is engineer X in rotation for?")
-- have to scan the whole table.
CREATE INDEX IF NOT EXISTS idx_amc_engineer_rotation_engineer_id
  ON public.amc_engineer_rotation (engineer_id);

CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_events_actor_user_id
  ON public.repair_job_escrow_events (actor_user_id)
  WHERE actor_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_repair_job_cost_revisions_decision_by
  ON public.repair_job_cost_revisions (decision_by)
  WHERE decision_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_buyer_kyc_reviewed_by
  ON public.buyer_kyc (reviewed_by)
  WHERE reviewed_by IS NOT NULL;
