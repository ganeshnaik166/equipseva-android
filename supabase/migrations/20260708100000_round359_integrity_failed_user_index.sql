-- Round 359 — partial index pairing with round-351 admin_recent_payments
-- integrity-join CTE:
--
--   SELECT user_id, count(*)
--   FROM device_integrity_checks
--   WHERE pass = false
--   GROUP BY user_id
--
-- Existing indexes:
--   device_integrity_checks_user_idx   (user_id, created_at desc)
--     — user_id-first but full table (no partial), so the planner still
--       has to filter pass=false per row.
--   device_integrity_checks_dirty_idx  (created_at desc) WHERE pass=false
--     — partial on the right predicate but keyed by created_at; no help
--       for GROUP BY user_id.
--
-- Add a partial on (user_id) WHERE pass=false so the CTE becomes an
-- index-only group-by walk. Pairs with r358 leaderboard index — both
-- close the "round X added a query, no index supports it" gap.

CREATE INDEX IF NOT EXISTS device_integrity_checks_failed_user_idx
  ON public.device_integrity_checks (user_id)
  WHERE pass = false;
