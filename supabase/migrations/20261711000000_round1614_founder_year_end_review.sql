BEGIN;

-- =====================================================================
-- Round 1614 — Founder Year-End Review
-- Compile annual review: top 10 wins/losses, lessons, founder essay,
-- archive for next year.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: founder_year_end_reviews
--   One row per fiscal year (founder-authored annual reflection)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_year_end_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_year int NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  reflection_essay text,
  north_star_next_year text,
  founder_mood text CHECK (founder_mood IN ('elated','optimistic','steady','anxious','exhausted','grieving')),
  word_count int DEFAULT 0,
  total_revenue_rupees bigint DEFAULT 0,
  total_jobs_closed int DEFAULT 0,
  total_amc_contracts int DEFAULT 0,
  net_promoter_score numeric(4,1),
  archived_at timestamptz,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_year_end_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_year_end_reviews_founder_all ON founder_year_end_reviews;
CREATE POLICY founder_year_end_reviews_founder_all
  ON founder_year_end_reviews
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_founder_year_end_reviews_year
  ON founder_year_end_reviews(fiscal_year DESC);

-- ---------------------------------------------------------------------
-- Table 2: founder_year_end_entries
--   Wins / losses / lessons (kind enum), ordered by rank
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_year_end_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES founder_year_end_reviews(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('win','loss','lesson')),
  rank int NOT NULL CHECK (rank BETWEEN 1 AND 20),
  title text NOT NULL,
  description text,
  impact_score int CHECK (impact_score BETWEEN 1 AND 10),
  tags text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (review_id, kind, rank)
);

ALTER TABLE founder_year_end_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_year_end_entries_founder_all ON founder_year_end_entries;
CREATE POLICY founder_year_end_entries_founder_all
  ON founder_year_end_entries
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_founder_year_end_entries_review
  ON founder_year_end_entries(review_id, kind, rank);

-- ---------------------------------------------------------------------
-- log_founder_* helpers (VOLATILE SECDEF, founder-gated)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_founder_year_end_review_upsert(
  p_fiscal_year int,
  p_status text,
  p_word_count int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'year_end_review_upsert',
    jsonb_build_object('fiscal_year', p_fiscal_year, 'status', p_status, 'word_count', p_word_count),
    now());
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_year_end_review_upsert(int, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_year_end_review_upsert(int, text, int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_year_end_entry_added(
  p_review_id uuid,
  p_kind text,
  p_rank int,
  p_title text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'year_end_entry_added',
    jsonb_build_object('review_id', p_review_id, 'kind', p_kind, 'rank', p_rank, 'title', p_title),
    now());
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_year_end_entry_added(uuid, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_year_end_entry_added(uuid, text, int, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_year_end_published(
  p_fiscal_year int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'year_end_published',
    jsonb_build_object('fiscal_year', p_fiscal_year),
    now());
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_year_end_published(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_year_end_published(int) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_year_end_archived(
  p_fiscal_year int
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'year_end_archived',
    jsonb_build_object('fiscal_year', p_fiscal_year),
    now());
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_year_end_archived(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_year_end_archived(int) TO authenticated;

-- ---------------------------------------------------------------------
-- READ RPCs (STABLE)
-- ---------------------------------------------------------------------

-- 1) Overview KPIs for current year-in-progress
CREATE OR REPLACE FUNCTION rpc_year_end_overview()
RETURNS TABLE(
  fiscal_year int,
  status text,
  word_count int,
  total_revenue_rupees bigint,
  total_jobs_closed int,
  total_amc_contracts int,
  net_promoter_score numeric,
  entries_count int,
  wins_count int,
  losses_count int,
  lessons_count int,
  published_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH cur AS (
    SELECT * FROM founder_year_end_reviews
    ORDER BY fiscal_year DESC LIMIT 1
  ),
  ent AS (
    SELECT review_id,
           count(*)::int AS n_all,
           count(*) FILTER (WHERE kind='win')::int AS n_wins,
           count(*) FILTER (WHERE kind='loss')::int AS n_losses,
           count(*) FILTER (WHERE kind='lesson')::int AS n_lessons
    FROM founder_year_end_entries
    GROUP BY review_id
  )
  SELECT c.fiscal_year, c.status, c.word_count, c.total_revenue_rupees,
         c.total_jobs_closed, c.total_amc_contracts, c.net_promoter_score,
         COALESCE(e.n_all,0), COALESCE(e.n_wins,0),
         COALESCE(e.n_losses,0), COALESCE(e.n_lessons,0),
         c.published_at, c.archived_at, c.created_at, c.updated_at
  FROM cur c LEFT JOIN ent e ON e.review_id = c.id;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_year_end_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_year_end_overview() TO authenticated;

-- 2) Top 10 wins
CREATE OR REPLACE FUNCTION rpc_year_end_top_wins()
RETURNS TABLE(
  id uuid, rank int, title text, description text,
  impact_score int, tags text[], created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.rank, e.title, e.description, e.impact_score, e.tags, e.created_at
  FROM founder_year_end_entries e
  JOIN founder_year_end_reviews r ON r.id = e.review_id
  WHERE e.kind = 'win'
  ORDER BY r.fiscal_year DESC, e.rank ASC
  LIMIT 10;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_year_end_top_wins() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_year_end_top_wins() TO authenticated;

-- 3) Top 10 losses
CREATE OR REPLACE FUNCTION rpc_year_end_top_losses()
RETURNS TABLE(
  id uuid, rank int, title text, description text,
  impact_score int, tags text[], created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.rank, e.title, e.description, e.impact_score, e.tags, e.created_at
  FROM founder_year_end_entries e
  JOIN founder_year_end_reviews r ON r.id = e.review_id
  WHERE e.kind = 'loss'
  ORDER BY r.fiscal_year DESC, e.rank ASC
  LIMIT 10;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_year_end_top_losses() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_year_end_top_losses() TO authenticated;

-- 4) Biggest lessons
CREATE OR REPLACE FUNCTION rpc_year_end_lessons()
RETURNS TABLE(
  id uuid, rank int, title text, description text,
  impact_score int, tags text[], created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.rank, e.title, e.description, e.impact_score, e.tags, e.created_at
  FROM founder_year_end_entries e
  JOIN founder_year_end_reviews r ON r.id = e.review_id
  WHERE e.kind = 'lesson'
  ORDER BY r.fiscal_year DESC, e.rank ASC
  LIMIT 10;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_year_end_lessons() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_year_end_lessons() TO authenticated;

-- 5) Archived reviews (past years)
CREATE OR REPLACE FUNCTION rpc_year_end_archive()
RETURNS TABLE(
  id uuid, fiscal_year int, status text, word_count int,
  total_revenue_rupees bigint, total_jobs_closed int,
  total_amc_contracts int, net_promoter_score numeric,
  archived_at timestamptz, published_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.fiscal_year, r.status, r.word_count,
         r.total_revenue_rupees, r.total_jobs_closed,
         r.total_amc_contracts, r.net_promoter_score,
         r.archived_at, r.published_at
  FROM founder_year_end_reviews r
  WHERE r.status = 'archived'
  ORDER BY r.fiscal_year DESC
  LIMIT 20;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_year_end_archive() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_year_end_archive() TO authenticated;

-- 6) Auto-computed year metrics (revenue + jobs + amc + nps proxy)
CREATE OR REPLACE FUNCTION rpc_year_end_auto_metrics()
RETURNS TABLE(
  metric_name text,
  metric_value numeric,
  metric_unit text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH rev AS (
    SELECT COALESCE(SUM(contracted_amount_rupees),0)::numeric AS v
    FROM repair_jobs
    WHERE status = 'closed'
      AND created_at >= date_trunc('year', now())
  ),
  jobs AS (
    SELECT count(*)::numeric AS v
    FROM repair_jobs
    WHERE status = 'closed'
      AND created_at >= date_trunc('year', now())
  ),
  amc AS (
    SELECT count(*)::numeric AS v
    FROM amc_contracts
    WHERE created_at >= date_trunc('year', now())
  ),
  rating AS (
    SELECT COALESCE(AVG(hospital_rating),0)::numeric AS v
    FROM repair_jobs
    WHERE hospital_rating IS NOT NULL
      AND created_at >= date_trunc('year', now())
  )
  SELECT 'revenue'::text, (SELECT v FROM rev), 'rupees'::text
  UNION ALL
  SELECT 'jobs_closed'::text, (SELECT v FROM jobs), 'count'::text
  UNION ALL
  SELECT 'amc_contracts'::text, (SELECT v FROM amc), 'count'::text
  UNION ALL
  SELECT 'avg_rating'::text, (SELECT v FROM rating), 'stars'::text;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_year_end_auto_metrics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_year_end_auto_metrics() TO authenticated;

-- 7) Recent activity (audit trail for this feature)
CREATE OR REPLACE FUNCTION rpc_year_end_recent_activity()
RETURNS TABLE(
  id uuid, actor_email text, op_name text,
  after_value jsonb, created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT fal.id, fal.actor_email, fal.op_name, fal.after_value, fal.created_at
  FROM founder_action_log fal
  WHERE fal.op_name LIKE 'year_end_%'
  ORDER BY fal.created_at DESC
  LIMIT 25;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_year_end_recent_activity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_year_end_recent_activity() TO authenticated;

COMMIT;