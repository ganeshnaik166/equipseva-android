-- Scaling pass — adds indexes for the hottest read paths so the app
-- holds up at 10K → 1M users without sequential scans dominating
-- query time. Verified missing today; the only prior index-only
-- migration is 20260425160000 which covered marketplace order history
-- and FK hygiene, not the user-facing repair / directory paths.
--
-- Each CREATE INDEX is IF NOT EXISTS + uses CONCURRENTLY-friendly
-- defaults so a future re-run on a busy production DB doesn't lock
-- writes. (CONCURRENTLY itself can't run inside a migration
-- transaction; the IF NOT EXISTS guard keeps re-applies safe and the
-- ops engineer can recreate manually with CONCURRENTLY when needed.)
--
-- All partial indexes use predicates that match the corresponding
-- WHERE clauses verbatim so the planner picks them up.

-- ---------------------------------------------------------------------------
-- engineers — directory search RPC sorts by rating_avg DESC + total_jobs DESC
-- with status/city filters. At 100K verified engineers, no index = full scan
-- + 100K-row in-memory sort per directory open. (See migration
-- 20260427010000_engineers_directory_rpcs.sql lines 7-77.)
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_engineers_verified_rating
  ON public.engineers (rating_avg DESC, total_jobs DESC)
  WHERE coalesce(verification_status::text, 'pending') = 'verified';

CREATE INDEX IF NOT EXISTS idx_engineers_city_verified
  ON public.engineers (city, rating_avg DESC)
  WHERE coalesce(verification_status::text, 'pending') = 'verified';

-- Trigram-style ILIKE search on full_name lives on profiles, not
-- engineers — but the directory RPC joins through engineers.user_id
-- → profiles.id. profiles already has the standard PK; the
-- directory's `p.full_name ILIKE p_query` benefits from pg_trgm if
-- enabled. We don't force-enable the extension here (project may not
-- have it loaded) — left as a follow-up when query volume warrants.

-- ---------------------------------------------------------------------------
-- repair_jobs — `list_nearby_repair_jobs` filters by status IN
-- ('requested','assigned'); the hospital active-jobs list filters by
-- hospital_user_id + status; the rating aggregator + reviews RPCs
-- both filter by engineer_id + status='completed'.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_repair_jobs_status_open
  ON public.repair_jobs (status, created_at DESC)
  WHERE status::text IN ('requested', 'assigned');

CREATE INDEX IF NOT EXISTS idx_repair_jobs_hospital_user_status
  ON public.repair_jobs (hospital_user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_repair_jobs_engineer_completed
  ON public.repair_jobs (engineer_id, completed_at DESC)
  WHERE status::text = 'completed' AND engineer_id IS NOT NULL;

-- engineer_recent_reviews: filter is (engineer_id, status='completed',
-- hospital_review IS NOT NULL), order by completed_at DESC. The above
-- partial covers most of it; tighten with a hospital_review predicate
-- so the planner skips rated-but-no-text rows.
CREATE INDEX IF NOT EXISTS idx_repair_jobs_engineer_completed_with_review
  ON public.repair_jobs (engineer_id, completed_at DESC)
  WHERE status::text = 'completed'
    AND engineer_id IS NOT NULL
    AND hospital_review IS NOT NULL;

-- ---------------------------------------------------------------------------
-- repair_job_bids — engineer-side `MyBids` filters by engineer_user_id
-- + status; hospital-side detail screen lists bids per job + sorts by
-- amount_rupees ASC. Existing PK index covers `id`; the FK on
-- repair_job_id is auto-indexed in some setups but not all.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_repair_job_bids_engineer_status
  ON public.repair_job_bids (engineer_user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_repair_job_bids_job_status_amount
  ON public.repair_job_bids (repair_job_id, status, amount_rupees);

-- ---------------------------------------------------------------------------
-- notifications — already has idx_notifications_user_sent_at
-- (20260425001745). Add a filtered index for the unread-count badge so
-- it doesn't scan the whole inbox per render. Existing index covers
-- the inbox list; this one covers the count query specifically.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id)
  WHERE coalesce(is_read, false) = false;
