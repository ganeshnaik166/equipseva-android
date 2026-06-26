BEGIN;

-- ============================================================================
-- Round 2862: Engineer Monthly Customer Job Narrative Publish Frequency
-- ============================================================================

-- Table 1: engineer monthly narrative publishing records
CREATE TABLE IF NOT EXISTS engineer_monthly_narrative_publish_r2862 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_handle text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('bronze','silver','gold','platinum','diamond')),
  cycle_month date NOT NULL,
  narrative_title text NOT NULL,
  narrative_kind text NOT NULL CHECK (narrative_kind IN ('case_study','before_after','rescue_story','training_log','customer_quote','tech_dive')),
  job_id_ref text NOT NULL,
  customer_org text NOT NULL,
  word_count int NOT NULL CHECK (word_count >= 0),
  publish_status text NOT NULL CHECK (publish_status IN ('draft','submitted','approved','published','retracted')),
  publish_channel text NOT NULL CHECK (publish_channel IN ('blog','linkedin','newsletter','case_pdf','internal_wiki')),
  cadence_target_per_month int NOT NULL CHECK (cadence_target_per_month >= 1),
  cadence_actual_this_month int NOT NULL CHECK (cadence_actual_this_month >= 0),
  engagement_views int NOT NULL DEFAULT 0,
  engagement_reactions int NOT NULL DEFAULT 0,
  engagement_replies int NOT NULL DEFAULT 0,
  audience_segment text NOT NULL CHECK (audience_segment IN ('hospital','dental','diagnostic','veterinary','homecare','mixed')),
  verdict text NOT NULL CHECK (verdict IN ('on_pace','behind','ahead','at_risk','exceptional')),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_narrative_publish_r2862 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_narrative_publish_r2862;
CREATE POLICY founder_all ON engineer_monthly_narrative_publish_r2862
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: monthly cadence rollup per engineer
CREATE TABLE IF NOT EXISTS engineer_cadence_rollup_r2862 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_handle text NOT NULL,
  cycle_month date NOT NULL,
  narratives_target int NOT NULL CHECK (narratives_target >= 0),
  narratives_drafted int NOT NULL CHECK (narratives_drafted >= 0),
  narratives_published int NOT NULL CHECK (narratives_published >= 0),
  total_views int NOT NULL DEFAULT 0,
  total_reactions int NOT NULL DEFAULT 0,
  primary_audience text NOT NULL CHECK (primary_audience IN ('hospital','dental','diagnostic','veterinary','homecare','mixed')),
  streak_months int NOT NULL DEFAULT 0 CHECK (streak_months >= 0),
  coach_note text NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('on_pace','behind','ahead','at_risk','exceptional')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_cadence_rollup_r2862 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_cadence_rollup_r2862;
CREATE POLICY founder_all ON engineer_cadence_rollup_r2862
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Seed data
-- ============================================================================

INSERT INTO engineer_monthly_narrative_publish_r2862
  (engineer_handle, engineer_tier, cycle_month, narrative_title, narrative_kind, job_id_ref, customer_org, word_count, publish_status, publish_channel, cadence_target_per_month, cadence_actual_this_month, engagement_views, engagement_reactions, engagement_replies, audience_segment, verdict, published_at)
VALUES
  ('eng_ravi', 'diamond', '2026-06-01'::date, 'How we revived a 12-year-old C-arm in 6 hours', 'rescue_story', 'JOB-44812', 'Apollo Hyderabad', 1840, 'published', 'blog', 4, 4, 5240, 312, 48, 'hospital', 'exceptional', '2026-06-18 10:00:00+00'),
  ('eng_priya', 'platinum', '2026-06-01'::date, 'Dental autoclave preventive cadence — case file', 'case_study', 'JOB-44910', 'SmilesDental Pune', 1420, 'published', 'linkedin', 4, 3, 2810, 184, 22, 'dental', 'on_pace', '2026-06-15 09:30:00+00'),
  ('eng_arjun', 'gold', '2026-06-01'::date, 'Before/After: ultrasound probe head replacement', 'before_after', 'JOB-44765', 'Lotus Diagnostics', 980, 'approved', 'newsletter', 3, 1, 0, 0, 0, 'diagnostic', 'behind', NULL),
  ('eng_sneha', 'silver', '2026-06-01'::date, 'Field-training log: ventilator firmware patch', 'training_log', 'JOB-44688', 'Manipal Bengaluru', 1100, 'draft', 'internal_wiki', 2, 0, 0, 0, 0, 'hospital', 'at_risk', NULL),
  ('eng_kabir', 'bronze', '2026-06-01'::date, 'Vet clinic X-ray retrofit — customer quote', 'customer_quote', 'JOB-44621', 'PawCare Vet', 420, 'submitted', 'case_pdf', 1, 0, 0, 0, 0, 'veterinary', 'behind', NULL),
  ('eng_meera', 'platinum', '2026-06-01'::date, 'Tech dive: home oxygen concentrator calibration', 'tech_dive', 'JOB-44559', 'HomeMed Delhi', 2160, 'published', 'blog', 3, 3, 4120, 256, 39, 'homecare', 'ahead', '2026-06-12 14:00:00+00'),
  ('eng_ravi', 'diamond', '2026-06-01'::date, 'Mixed-fleet AMC narrative — Q2 review', 'case_study', 'JOB-44490', 'Fortis Chennai', 2480, 'published', 'newsletter', 4, 4, 6310, 401, 67, 'mixed', 'exceptional', '2026-06-08 11:00:00+00');

INSERT INTO engineer_cadence_rollup_r2862
  (engineer_handle, cycle_month, narratives_target, narratives_drafted, narratives_published, total_views, total_reactions, primary_audience, streak_months, coach_note, verdict)
VALUES
  ('eng_ravi', '2026-06-01'::date, 4, 4, 4, 11550, 713, 'mixed', 9, 'Diamond cadence sustained — promote to brand ambassador stream', 'exceptional'),
  ('eng_priya', '2026-06-01'::date, 4, 3, 3, 2810, 184, 'dental', 5, 'Strong dental voice — needs one more publish to hit target', 'on_pace'),
  ('eng_arjun', '2026-06-01'::date, 3, 2, 1, 0, 0, 'diagnostic', 2, 'Approved drafts sitting unpublished — escalate to ops review', 'behind'),
  ('eng_sneha', '2026-06-01'::date, 2, 1, 0, 0, 0, 'hospital', 0, 'Silver tier stalling at draft — pair with eng_priya for mentorship', 'at_risk'),
  ('eng_kabir', '2026-06-01'::date, 1, 1, 0, 0, 0, 'veterinary', 1, 'Bronze ramp — coach on customer-quote brevity (target 400-600 words)', 'behind'),
  ('eng_meera', '2026-06-01'::date, 3, 3, 3, 4120, 256, 'homecare', 4, 'Ahead of cadence — invite to lead homecare vertical narrative track', 'ahead');

-- ============================================================================
-- RPCs (all SECURITY DEFINER, founder-gated)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2862_kpi_snapshot();
CREATE OR REPLACE FUNCTION founder_r2862_kpi_snapshot()
RETURNS TABLE (
  total_engineers int,
  total_narratives int,
  published_count int,
  draft_count int,
  total_views bigint,
  exceptional_count int,
  at_risk_count int,
  on_pace_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(DISTINCT engineer_handle)::int FROM engineer_monthly_narrative_publish_r2862),
    (SELECT COUNT(*)::int FROM engineer_monthly_narrative_publish_r2862),
    (SELECT COUNT(*)::int FROM engineer_monthly_narrative_publish_r2862 WHERE publish_status = 'published'),
    (SELECT COUNT(*)::int FROM engineer_monthly_narrative_publish_r2862 WHERE publish_status = 'draft'),
    (SELECT COALESCE(SUM(engagement_views),0)::bigint FROM engineer_monthly_narrative_publish_r2862),
    (SELECT COUNT(*)::int FROM engineer_cadence_rollup_r2862 WHERE verdict = 'exceptional'),
    (SELECT COUNT(*)::int FROM engineer_cadence_rollup_r2862 WHERE verdict = 'at_risk'),
    (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE verdict IN ('on_pace','ahead','exceptional')) / NULLIF(COUNT(*),0), 1)
     FROM engineer_cadence_rollup_r2862);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_kpi_snapshot() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2862_engineer_cadence();
CREATE OR REPLACE FUNCTION founder_r2862_engineer_cadence()
RETURNS TABLE (
  engineer_handle text,
  narratives_target int,
  narratives_published int,
  total_views int,
  primary_audience text,
  streak_months int,
  verdict text,
  coach_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_handle, r.narratives_target, r.narratives_published, r.total_views,
         r.primary_audience, r.streak_months, r.verdict, r.coach_note
  FROM engineer_cadence_rollup_r2862 r
  ORDER BY r.narratives_published DESC, r.total_views DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_engineer_cadence() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_engineer_cadence() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2862_narratives_by_status();
CREATE OR REPLACE FUNCTION founder_r2862_narratives_by_status()
RETURNS TABLE (
  publish_status text,
  narrative_count int,
  avg_word_count numeric,
  total_views bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.publish_status,
         COUNT(*)::int,
         ROUND(AVG(n.word_count), 0),
         COALESCE(SUM(n.engagement_views),0)::bigint
  FROM engineer_monthly_narrative_publish_r2862 n
  GROUP BY n.publish_status
  ORDER BY narrative_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_narratives_by_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_narratives_by_status() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2862_audience_split();
CREATE OR REPLACE FUNCTION founder_r2862_audience_split()
RETURNS TABLE (
  audience_segment text,
  narrative_count int,
  published_count int,
  total_engagement int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.audience_segment,
         COUNT(*)::int,
         COUNT(*) FILTER (WHERE n.publish_status = 'published')::int,
         COALESCE(SUM(n.engagement_views + n.engagement_reactions + n.engagement_replies), 0)::int
  FROM engineer_monthly_narrative_publish_r2862 n
  GROUP BY n.audience_segment
  ORDER BY total_engagement DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_audience_split() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_audience_split() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2862_top_published();
CREATE OR REPLACE FUNCTION founder_r2862_top_published()
RETURNS TABLE (
  engineer_handle text,
  narrative_title text,
  narrative_kind text,
  customer_org text,
  publish_channel text,
  engagement_views int,
  engagement_reactions int,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.engineer_handle, n.narrative_title, n.narrative_kind, n.customer_org,
         n.publish_channel, n.engagement_views, n.engagement_reactions, n.verdict
  FROM engineer_monthly_narrative_publish_r2862 n
  WHERE n.publish_status = 'published'
  ORDER BY n.engagement_views DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_top_published() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_top_published() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2862_behind_engineers();
CREATE OR REPLACE FUNCTION founder_r2862_behind_engineers()
RETURNS TABLE (
  engineer_handle text,
  narratives_target int,
  narratives_published int,
  gap int,
  verdict text,
  coach_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_handle, r.narratives_target, r.narratives_published,
         (r.narratives_target - r.narratives_published) AS gap,
         r.verdict, r.coach_note
  FROM engineer_cadence_rollup_r2862 r
  WHERE r.verdict IN ('behind','at_risk')
  ORDER BY (r.narratives_target - r.narratives_published) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_behind_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_behind_engineers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2862_channel_performance();
CREATE OR REPLACE FUNCTION founder_r2862_channel_performance()
RETURNS TABLE (
  publish_channel text,
  total_published int,
  avg_views numeric,
  avg_reactions numeric,
  total_replies int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.publish_channel,
         COUNT(*) FILTER (WHERE n.publish_status = 'published')::int,
         ROUND(AVG(n.engagement_views) FILTER (WHERE n.publish_status = 'published'), 0),
         ROUND(AVG(n.engagement_reactions) FILTER (WHERE n.publish_status = 'published'), 0),
         COALESCE(SUM(n.engagement_replies) FILTER (WHERE n.publish_status = 'published'), 0)::int
  FROM engineer_monthly_narrative_publish_r2862 n
  GROUP BY n.publish_channel
  ORDER BY total_published DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_channel_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_channel_performance() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2862_recent_narratives();
CREATE OR REPLACE FUNCTION founder_r2862_recent_narratives()
RETURNS TABLE (
  engineer_handle text,
  engineer_tier text,
  narrative_title text,
  narrative_kind text,
  customer_org text,
  word_count int,
  publish_status text,
  audience_segment text,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.engineer_handle, n.engineer_tier, n.narrative_title, n.narrative_kind,
         n.customer_org, n.word_count, n.publish_status, n.audience_segment, n.verdict
  FROM engineer_monthly_narrative_publish_r2862 n
  ORDER BY n.created_at DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2862_recent_narratives() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2862_recent_narratives() TO authenticated;

COMMIT;
