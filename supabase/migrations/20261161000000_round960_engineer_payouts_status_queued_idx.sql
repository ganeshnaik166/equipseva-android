-- Round 960 — Performance index on engineer_payouts(status, queued_at).
--
-- The existing r422 schema indexes:
--   - (queued_at) WHERE status='queued' AND payout_method_id IS NOT NULL
--     — narrow, optimized for the worker's SKIP LOCKED claim path.
--   - (engineer_user_id, status, queued_at DESC)
--     — works great for per-engineer drilldowns; less useful for the
--     platform-wide aggregates this session shipped (r798, r809, r815,
--     r833, r860, r879, r927 etc.).
--
-- Aggregate queries like:
--   SELECT count(*) FROM engineer_payouts
--    WHERE status = 'processed' AND queued_at >= now() - interval '30 days';
-- currently can use the (engineer_user_id, status, queued_at) index with
-- an index skip-scan, but Postgres often falls back to a seq scan when
-- the leading column has high cardinality. A dedicated (status, queued_at)
-- partial index over only the non-terminal + processed/failed rows
-- (the only statuses worth scanning across windows) gives the planner
-- a clean choice.
BEGIN;

CREATE INDEX IF NOT EXISTS idx_engineer_payouts_status_queued_at
  ON public.engineer_payouts (status, queued_at DESC)
  WHERE status IN ('queued','processing','processed','failed');

COMMIT;
