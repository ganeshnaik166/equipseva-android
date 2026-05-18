-- Round 342 — add indexes the next 6 months of growth will need.
--
-- Scout audit (this session) cross-referenced migration history vs.
-- query patterns and found 4 missing indexes that would full-scan at
-- 100s-1000s of rows:
--
--   1. chat_messages has ZERO indexes — every per-conversation fetch
--      currently sequential-scans the entire table. Each chat tab open
--      triggers this; at 50+ conversations × 1000+ messages it dominates.
--   2. chat_messages has no FK index on sender_user_id either —
--      "messages I sent" queries (founder admin, dispute audits) scan.
--   3. (scout claim about amc_payment_orders.hospital_user_id was
--      wrong — that table joins through amc_contracts for the hospital
--      filter, so amc_contract_id index (already present) covers it.)
--   4. repair_jobs has idx_repair_jobs_status_open partial index for
--      ('requested','assigned') only. The active-jobs admin dashboard
--      includes 'in_progress' too; queries fall back to seq scan.
--
-- All CREATE INDEX IF NOT EXISTS so a re-deploy is a no-op. No
-- CONCURRENTLY (Supabase migrations don't allow it inside the
-- transactional default; if the table is small enough that this
-- migration takes too long, run CREATE INDEX CONCURRENTLY by hand
-- outside the migration channel).

-- 1+2: chat_messages — composite on (conversation_id, created_at DESC)
-- so the per-conversation message list paginates by recency in
-- index order, plus a bare sender_user_id index for FK joins.
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created
  ON public.chat_messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_user_id
  ON public.chat_messages (sender_user_id);

-- 3: active jobs admin view — broader partial index that catches all
-- three open statuses, sorted newest-first to match dashboard rendering.
-- repair_jobs.status is plain text (no enum), so the literal IN list
-- is IMMUTABLE without any cast — necessary for partial index predicates.
CREATE INDEX IF NOT EXISTS idx_repair_jobs_active_status_created
  ON public.repair_jobs (status, created_at DESC)
  WHERE status IN ('requested', 'assigned', 'in_progress');
