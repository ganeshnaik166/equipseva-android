-- Round 358 — partial index for admin_top_engineers (round 349).
--
-- The leaderboard RPC sums released-escrow per engineer within a window:
--
--   SELECT engineer_user_id, sum(amount_rupees), count(*)
--   FROM repair_job_escrow
--   WHERE status = 'released' AND released_at >= cutoff
--   GROUP BY engineer_user_id
--
-- Existing indexes:
--   idx_repair_job_escrow_status     — status alone, full table
--   idx_repair_job_escrow_engineer   — engineer_user_id alone
--   idx_repair_job_escrow_release_due — partial on 'held', wrong status
--
-- None lets Postgres narrow to released-only AND scan engineer-ordered
-- for the GROUP BY in one shot. A partial covering index on the two
-- predicates pays for itself once released_count crosses ~1k.

CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_released_leaderboard
  ON public.repair_job_escrow (engineer_user_id, released_at)
  WHERE status = 'released';
