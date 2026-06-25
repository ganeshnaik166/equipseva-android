BEGIN;

-- ============================================================
-- Round 2721: Founder Quarterly Vision Statement Evolution
-- Tracks vision statement drafts, audience reactions, refinements
-- clarity scores, and adoption metrics across quarters
-- ============================================================

-- Table 1: Vision statement versions with drafts and refinements
CREATE TABLE IF NOT EXISTS founder_vision_statements_r2721 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  version_number int NOT NULL,
  draft_text text NOT NULL,
  refined_text text,
  clarity_score numeric(4,2) NOT NULL CHECK (clarity_score >= 0 AND clarity_score <= 10),
  word_count int NOT NULL CHECK (word_count > 0),
  status text NOT NULL CHECK (status IN ('draft','review','refined','published','archived')),
  audience_segment text NOT NULL CHECK (audience_segment IN ('investors','team','customers','board','all_hands')),
  refinement_round int NOT NULL DEFAULT 0 CHECK (refinement_round >= 0),
  authored_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  notes text
);

ALTER TABLE founder_vision_statements_r2721 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_vision_statements_r2721;
CREATE POLICY founder_all ON founder_vision_statements_r2721 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: Audience reactions and adoption metrics
CREATE TABLE IF NOT EXISTS founder_vision_reactions_r2721 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  statement_id uuid NOT NULL REFERENCES founder_vision_statements_r2721(id) ON DELETE CASCADE,
  audience_member text NOT NULL,
  audience_role text NOT NULL CHECK (audience_role IN ('investor','engineer','sales','founder','advisor','customer','board_member')),
  reaction_sentiment text NOT NULL CHECK (reaction_sentiment IN ('strongly_positive','positive','neutral','negative','strongly_negative')),
  clarity_rating int NOT NULL CHECK (clarity_rating BETWEEN 1 AND 10),
  resonance_rating int NOT NULL CHECK (resonance_rating BETWEEN 1 AND 10),
  adopted boolean NOT NULL DEFAULT false,
  recall_after_week boolean NOT NULL DEFAULT false,
  feedback_text text,
  reaction_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_vision_reactions_r2721 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON founder_vision_reactions_r2721;
CREATE POLICY founder_all ON founder_vision_reactions_r2721 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed vision statements (8 rows across quarters and versions)
INSERT INTO founder_vision_statements_r2721 (quarter, version_number, draft_text, refined_text, clarity_score, word_count, status, audience_segment, refinement_round, authored_by, created_at, published_at, notes) VALUES
('2026-Q1', 1, 'Be the trusted medical equipment partner for every hospital in India', 'Trusted medical equipment uptime partner for Indian hospitals', 6.20, 12, 'archived', 'all_hands', 0, 'founder', '2026-01-05'::timestamptz, '2026-01-10'::timestamptz, 'first cut too generic'),
('2026-Q1', 2, 'Guarantee zero downtime for critical medical equipment across India', 'Zero downtime guarantee for critical hospital equipment in India', 7.80, 10, 'archived', 'investors', 2, 'founder', '2026-01-15'::timestamptz, '2026-01-20'::timestamptz, 'sharpened around uptime SLA'),
('2026-Q2', 1, 'Make equipment failure invisible to patients by predictive maintenance', 'Make equipment failure invisible to patients', 7.50, 7, 'archived', 'team', 1, 'founder', '2026-04-02'::timestamptz, '2026-04-05'::timestamptz, 'team loved the patient framing'),
('2026-Q2', 2, 'Become the operating system of medical equipment uptime in tier-2 India', 'OS of medical equipment uptime for tier-2 India', 8.40, 9, 'published', 'investors', 3, 'founder', '2026-04-20'::timestamptz, '2026-04-25'::timestamptz, 'investors pattern-matched to OS thesis'),
('2026-Q3', 1, 'Make every hospital in India 10x more reliable through equipment intelligence', 'Hospitals 10x more reliable via equipment intelligence', 7.90, 7, 'refined', 'board', 2, 'founder', '2026-07-05'::timestamptz, NULL, 'board wanted measurable outcome'),
('2026-Q3', 2, 'Reduce medical equipment downtime by 90 percent across 1000 hospitals by 2028', NULL, 8.70, 13, 'review', 'board', 0, 'founder', '2026-07-12'::timestamptz, NULL, 'pending board sync'),
('2026-Q4', 1, 'Equipment that heals itself before the patient knows it failed', 'Equipment heals itself before patients notice failure', 9.10, 8, 'draft', 'customers', 1, 'founder', '2026-10-08'::timestamptz, NULL, 'highest clarity score yet'),
('2026-Q4', 2, 'Predictive medical equipment uptime as a utility for every Indian hospital', NULL, 7.40, 11, 'draft', 'all_hands', 0, 'founder', '2026-10-15'::timestamptz, NULL, 'utility framing test');

-- Seed audience reactions (10 rows across statements)
INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Investor A — Lightspeed', 'investor', 'positive', 7, 8, true, true, 'OS framing landed', '2026-04-26'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q2' AND version_number=2;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Engineer Lead — Hyderabad', 'engineer', 'strongly_positive', 9, 9, true, true, 'patient framing inspires team', '2026-04-08'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q2' AND version_number=1;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Board member — Naveen', 'board_member', 'neutral', 6, 6, false, false, 'wants concrete metric', '2026-07-08'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q3' AND version_number=1;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Board member — Sequoia partner', 'board_member', 'strongly_positive', 9, 9, true, true, '90 percent + 1000 hospital target = great', '2026-07-15'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q3' AND version_number=2;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Customer — Apollo CTO', 'customer', 'strongly_positive', 10, 9, true, true, 'self-heal framing is a magic line', '2026-10-10'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q4' AND version_number=1;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Sales rep — Bangalore', 'sales', 'positive', 8, 7, true, false, 'easy to pitch but forgot exact wording', '2026-10-12'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q4' AND version_number=1;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Advisor — ex-Practo VP', 'advisor', 'negative', 4, 5, false, false, 'utility framing too abstract', '2026-10-18'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q4' AND version_number=2;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Engineer — Chennai', 'engineer', 'neutral', 6, 5, false, false, 'first draft felt corporate', '2026-01-08'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q1' AND version_number=1;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Investor — Accel', 'investor', 'positive', 8, 8, true, true, 'uptime SLA framing is sharp', '2026-01-22'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q1' AND version_number=2;

INSERT INTO founder_vision_reactions_r2721 (statement_id, audience_member, audience_role, reaction_sentiment, clarity_rating, resonance_rating, adopted, recall_after_week, feedback_text, reaction_at)
SELECT id, 'Founder — co-founder', 'founder', 'strongly_positive', 9, 10, true, true, 'this is the one for Q4 launch', '2026-10-09'::timestamptz FROM founder_vision_statements_r2721 WHERE quarter='2026-Q4' AND version_number=1;

-- ============================================================
-- RPCs
-- ============================================================

-- RPC 1: List all vision statements by quarter
DROP FUNCTION IF EXISTS founder_list_vision_statements_r2721();
CREATE OR REPLACE FUNCTION founder_list_vision_statements_r2721()
RETURNS TABLE (
  id uuid,
  quarter text,
  version_number int,
  draft_text text,
  refined_text text,
  clarity_score numeric,
  word_count int,
  status text,
  audience_segment text,
  refinement_round int,
  authored_by text,
  created_at timestamptz,
  published_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT v.id, v.quarter, v.version_number, v.draft_text, v.refined_text,
           v.clarity_score, v.word_count, v.status, v.audience_segment,
           v.refinement_round, v.authored_by, v.created_at, v.published_at
    FROM founder_vision_statements_r2721 v
    ORDER BY v.quarter DESC, v.version_number DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_list_vision_statements_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_list_vision_statements_r2721() TO authenticated;

-- RPC 2: KPI summary
DROP FUNCTION IF EXISTS founder_vision_kpis_r2721();
CREATE OR REPLACE FUNCTION founder_vision_kpis_r2721()
RETURNS TABLE (
  total_statements int,
  published_count int,
  avg_clarity_score numeric,
  total_reactions int,
  adoption_rate_pct numeric,
  recall_rate_pct numeric,
  avg_refinement_rounds numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM founder_vision_statements_r2721),
      (SELECT COUNT(*)::int FROM founder_vision_statements_r2721 WHERE status='published'),
      (SELECT ROUND(AVG(clarity_score)::numeric, 2) FROM founder_vision_statements_r2721),
      (SELECT COUNT(*)::int FROM founder_vision_reactions_r2721),
      (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE adopted) / NULLIF(COUNT(*),0)::numeric, 1) FROM founder_vision_reactions_r2721),
      (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE recall_after_week) / NULLIF(COUNT(*),0)::numeric, 1) FROM founder_vision_reactions_r2721),
      (SELECT ROUND(AVG(refinement_round)::numeric, 2) FROM founder_vision_statements_r2721);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vision_kpis_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vision_kpis_r2721() TO authenticated;

-- RPC 3: Clarity score by quarter
DROP FUNCTION IF EXISTS founder_vision_clarity_by_quarter_r2721();
CREATE OR REPLACE FUNCTION founder_vision_clarity_by_quarter_r2721()
RETURNS TABLE (
  quarter text,
  versions_count int,
  avg_clarity numeric,
  max_clarity numeric,
  best_version_text text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT v.quarter,
           COUNT(*)::int,
           ROUND(AVG(v.clarity_score)::numeric, 2),
           MAX(v.clarity_score),
           (SELECT v2.draft_text FROM founder_vision_statements_r2721 v2
             WHERE v2.quarter = v.quarter
             ORDER BY v2.clarity_score DESC LIMIT 1)
    FROM founder_vision_statements_r2721 v
    GROUP BY v.quarter
    ORDER BY v.quarter DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vision_clarity_by_quarter_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vision_clarity_by_quarter_r2721() TO authenticated;

-- RPC 4: Audience reaction breakdown
DROP FUNCTION IF EXISTS founder_vision_reactions_breakdown_r2721();
CREATE OR REPLACE FUNCTION founder_vision_reactions_breakdown_r2721()
RETURNS TABLE (
  audience_role text,
  total_reactions int,
  positive_count int,
  negative_count int,
  avg_clarity_rating numeric,
  avg_resonance_rating numeric,
  adoption_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT r.audience_role,
           COUNT(*)::int,
           COUNT(*) FILTER (WHERE r.reaction_sentiment IN ('positive','strongly_positive'))::int,
           COUNT(*) FILTER (WHERE r.reaction_sentiment IN ('negative','strongly_negative'))::int,
           ROUND(AVG(r.clarity_rating)::numeric, 2),
           ROUND(AVG(r.resonance_rating)::numeric, 2),
           ROUND(100.0 * COUNT(*) FILTER (WHERE r.adopted) / NULLIF(COUNT(*),0)::numeric, 1)
    FROM founder_vision_reactions_r2721 r
    GROUP BY r.audience_role
    ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vision_reactions_breakdown_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vision_reactions_breakdown_r2721() TO authenticated;

-- RPC 5: Refinement evolution timeline
DROP FUNCTION IF EXISTS founder_vision_refinement_timeline_r2721();
CREATE OR REPLACE FUNCTION founder_vision_refinement_timeline_r2721()
RETURNS TABLE (
  quarter text,
  version_number int,
  refinement_round int,
  draft_word_count int,
  refined_word_count int,
  clarity_score numeric,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT v.quarter, v.version_number, v.refinement_round,
           v.word_count,
           COALESCE(array_length(string_to_array(v.refined_text, ' '), 1), 0),
           v.clarity_score, v.status
    FROM founder_vision_statements_r2721 v
    ORDER BY v.quarter ASC, v.version_number ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vision_refinement_timeline_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vision_refinement_timeline_r2721() TO authenticated;

-- RPC 6: Top adopted statements
DROP FUNCTION IF EXISTS founder_vision_top_adopted_r2721();
CREATE OR REPLACE FUNCTION founder_vision_top_adopted_r2721()
RETURNS TABLE (
  quarter text,
  version_number int,
  statement_text text,
  total_reactions int,
  adopted_count int,
  recall_count int,
  avg_resonance numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT v.quarter, v.version_number,
           COALESCE(v.refined_text, v.draft_text),
           COUNT(r.id)::int,
           COUNT(*) FILTER (WHERE r.adopted)::int,
           COUNT(*) FILTER (WHERE r.recall_after_week)::int,
           ROUND(AVG(r.resonance_rating)::numeric, 2)
    FROM founder_vision_statements_r2721 v
    LEFT JOIN founder_vision_reactions_r2721 r ON r.statement_id = v.id
    GROUP BY v.id, v.quarter, v.version_number, v.refined_text, v.draft_text
    HAVING COUNT(r.id) > 0
    ORDER BY COUNT(*) FILTER (WHERE r.adopted) DESC, AVG(r.resonance_rating) DESC NULLS LAST
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vision_top_adopted_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vision_top_adopted_r2721() TO authenticated;

-- RPC 7: Reactions detail list
DROP FUNCTION IF EXISTS founder_vision_reactions_list_r2721();
CREATE OR REPLACE FUNCTION founder_vision_reactions_list_r2721()
RETURNS TABLE (
  reaction_id uuid,
  quarter text,
  version_number int,
  audience_member text,
  audience_role text,
  reaction_sentiment text,
  clarity_rating int,
  resonance_rating int,
  adopted boolean,
  recall_after_week boolean,
  feedback_text text,
  reaction_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT r.id, v.quarter, v.version_number, r.audience_member, r.audience_role,
           r.reaction_sentiment, r.clarity_rating, r.resonance_rating, r.adopted,
           r.recall_after_week, r.feedback_text, r.reaction_at
    FROM founder_vision_reactions_r2721 r
    JOIN founder_vision_statements_r2721 v ON v.id = r.statement_id
    ORDER BY r.reaction_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vision_reactions_list_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vision_reactions_list_r2721() TO authenticated;

-- RPC 8: Status pipeline
DROP FUNCTION IF EXISTS founder_vision_status_pipeline_r2721();
CREATE OR REPLACE FUNCTION founder_vision_status_pipeline_r2721()
RETURNS TABLE (
  status text,
  statement_count int,
  avg_clarity numeric,
  avg_refinement_rounds numeric,
  latest_quarter text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT v.status,
           COUNT(*)::int,
           ROUND(AVG(v.clarity_score)::numeric, 2),
           ROUND(AVG(v.refinement_round)::numeric, 2),
           MAX(v.quarter)
    FROM founder_vision_statements_r2721 v
    GROUP BY v.status
    ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_vision_status_pipeline_r2721() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vision_status_pipeline_r2721() TO authenticated;

COMMIT;
