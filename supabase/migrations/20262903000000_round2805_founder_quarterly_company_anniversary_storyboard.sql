BEGIN;

-- =====================================================================
-- Round 2805 — Founder Quarterly Company Anniversary Storyboard
-- Tables: anniversary_milestones_r2805, anniversary_stories_r2805
-- =====================================================================

CREATE TABLE IF NOT EXISTS anniversary_milestones_r2805 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  anniversary_year int NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('q1','q2','q3','q4')),
  milestone_title text NOT NULL,
  milestone_category text NOT NULL CHECK (milestone_category IN ('product','revenue','team','customer','funding','impact')),
  milestone_date date NOT NULL,
  metric_value_rupees numeric(14,2),
  metric_count int,
  narrative text NOT NULL,
  audience text NOT NULL CHECK (audience IN ('all_hands','investors','customers','press','board','public')),
  distribution_channel text NOT NULL CHECK (distribution_channel IN ('blog','email','linkedin','press_release','townhall','offsite')),
  engagement_score int NOT NULL DEFAULT 0,
  tag text NOT NULL,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE anniversary_milestones_r2805 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON anniversary_milestones_r2805;
CREATE POLICY founder_all ON anniversary_milestones_r2805 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS anniversary_stories_r2805 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id uuid REFERENCES anniversary_milestones_r2805(id) ON DELETE CASCADE,
  story_title text NOT NULL,
  storyteller_name text NOT NULL,
  storyteller_role text NOT NULL,
  story_body text NOT NULL,
  story_format text NOT NULL CHECK (story_format IN ('written','video','podcast','photo_essay','infographic')),
  audience text NOT NULL CHECK (audience IN ('all_hands','investors','customers','press','board','public')),
  distribution_channel text NOT NULL CHECK (distribution_channel IN ('blog','email','linkedin','press_release','townhall','offsite')),
  views int NOT NULL DEFAULT 0,
  shares int NOT NULL DEFAULT 0,
  reactions int NOT NULL DEFAULT 0,
  engagement_score int NOT NULL DEFAULT 0,
  tag text NOT NULL,
  published_at date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE anniversary_stories_r2805 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON anniversary_stories_r2805;
CREATE POLICY founder_all ON anniversary_stories_r2805 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ===== Seeds =====
INSERT INTO anniversary_milestones_r2805 (anniversary_year, quarter, milestone_title, milestone_category, milestone_date, metric_value_rupees, metric_count, narrative, audience, distribution_channel, engagement_score, tag, is_published) VALUES
(1, 'q1', 'First 10 hospitals signed', 'customer', '2025-09-15'::date, NULL, 10, 'Ten hospitals trusted us with their equipment within first quarter.', 'all_hands', 'townhall', 88, 'launch', true),
(1, 'q2', 'Crossed 100 repair jobs', 'product', '2025-12-20'::date, NULL, 100, '100 jobs closed with 4.6 average rating.', 'customers', 'email', 91, 'traction', true),
(2, 'q1', 'Seed round closed', 'funding', '2026-03-01'::date, 25000000.00, NULL, 'Closed Rs 2.5 Cr seed from 5 angels and 1 micro-VC.', 'investors', 'press_release', 95, 'funding', true),
(2, 'q2', 'AMC pool launched', 'product', '2026-05-12'::date, 1800000.00, 42, 'AMC contracts crossed Rs 18L MRR across 42 hospitals.', 'board', 'offsite', 87, 'revenue', false),
(2, 'q3', '1000 jobs milestone', 'impact', '2026-06-18'::date, NULL, 1000, '1000th repair job completed in Hyderabad ICU.', 'public', 'linkedin', 93, 'milestone', true),
(3, 'q1', 'Engineer network 100', 'team', '2026-09-01'::date, NULL, 100, '100 verified engineers across 8 cities.', 'all_hands', 'blog', 89, 'team', false);

INSERT INTO anniversary_stories_r2805 (milestone_id, story_title, storyteller_name, storyteller_role, story_body, story_format, audience, distribution_channel, views, shares, reactions, engagement_score, tag, published_at) VALUES
(NULL, 'The first call at 2am', 'Ravi Kumar', 'Co-founder', 'A hospital called at 2am with a broken ventilator. We drove 80 km.', 'written', 'all_hands', 'townhall', 420, 38, 92, 86, 'origin', '2025-09-20'::date),
(NULL, 'Why I chose Equipseva', 'Dr Anita Sharma', 'Hospital director', 'Three vendors ghosted us. Equipseva picked up first try.', 'video', 'customers', 'email', 1280, 145, 312, 92, 'customer_voice', '2025-12-22'::date),
(NULL, 'Closing the seed', 'Founder', 'CEO', 'Term sheet to wire in 11 days.', 'written', 'investors', 'press_release', 2400, 220, 580, 94, 'funding_story', '2026-03-05'::date),
(NULL, 'Pooling AMC math', 'Priya N', 'Finance lead', 'Pool model lets small hospitals afford enterprise SLAs.', 'infographic', 'board', 'offsite', 180, 12, 44, 80, 'product_story', '2026-05-14'::date),
(NULL, 'Job 1000 in an ICU', 'Engineer Sai', 'Sr engineer', 'Replaced a dialyzer board in 38 minutes.', 'photo_essay', 'public', 'linkedin', 5600, 410, 1240, 96, 'milestone_story', '2026-06-18'::date),
(NULL, 'Building the team', 'HR lead', 'People ops', 'From 3 founders to 100 engineers in 18 months.', 'podcast', 'all_hands', 'blog', 340, 28, 78, 82, 'team_story', NULL);

-- ===== RPCs =====

DROP FUNCTION IF EXISTS r2805_kpis();
CREATE OR REPLACE FUNCTION r2805_kpis()
RETURNS TABLE(total_milestones int, published_milestones int, total_stories int, total_views int, total_shares int, avg_engagement numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM anniversary_milestones_r2805),
    (SELECT count(*)::int FROM anniversary_milestones_r2805 WHERE is_published),
    (SELECT count(*)::int FROM anniversary_stories_r2805),
    (SELECT COALESCE(sum(views),0)::int FROM anniversary_stories_r2805),
    (SELECT COALESCE(sum(shares),0)::int FROM anniversary_stories_r2805),
    (SELECT COALESCE(round(avg(engagement_score),1),0) FROM anniversary_stories_r2805);
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_kpis() TO authenticated;

DROP FUNCTION IF EXISTS r2805_milestones_by_year();
CREATE OR REPLACE FUNCTION r2805_milestones_by_year()
RETURNS TABLE(anniversary_year int, milestone_count int, avg_engagement numeric, published_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.anniversary_year, count(*)::int, round(avg(m.engagement_score),1), count(*) FILTER (WHERE m.is_published)::int
  FROM anniversary_milestones_r2805 m
  GROUP BY m.anniversary_year ORDER BY m.anniversary_year;
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_milestones_by_year() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_milestones_by_year() TO authenticated;

DROP FUNCTION IF EXISTS r2805_milestones_by_quarter();
CREATE OR REPLACE FUNCTION r2805_milestones_by_quarter()
RETURNS TABLE(quarter text, milestone_count int, avg_engagement numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.quarter, count(*)::int, round(avg(m.engagement_score),1)
  FROM anniversary_milestones_r2805 m
  GROUP BY m.quarter ORDER BY m.quarter;
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_milestones_by_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_milestones_by_quarter() TO authenticated;

DROP FUNCTION IF EXISTS r2805_milestones_by_category();
CREATE OR REPLACE FUNCTION r2805_milestones_by_category()
RETURNS TABLE(milestone_category text, milestone_count int, total_metric_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.milestone_category, count(*)::int, COALESCE(sum(m.metric_count),0)::int
  FROM anniversary_milestones_r2805 m
  GROUP BY m.milestone_category ORDER BY count(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_milestones_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_milestones_by_category() TO authenticated;

DROP FUNCTION IF EXISTS r2805_stories_by_format();
CREATE OR REPLACE FUNCTION r2805_stories_by_format()
RETURNS TABLE(story_format text, story_count int, total_views int, total_shares int, avg_engagement numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.story_format, count(*)::int, COALESCE(sum(s.views),0)::int, COALESCE(sum(s.shares),0)::int, round(avg(s.engagement_score),1)
  FROM anniversary_stories_r2805 s
  GROUP BY s.story_format ORDER BY sum(s.views) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_stories_by_format() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_stories_by_format() TO authenticated;

DROP FUNCTION IF EXISTS r2805_stories_by_channel();
CREATE OR REPLACE FUNCTION r2805_stories_by_channel()
RETURNS TABLE(distribution_channel text, story_count int, total_views int, total_reactions int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.distribution_channel, count(*)::int, COALESCE(sum(s.views),0)::int, COALESCE(sum(s.reactions),0)::int
  FROM anniversary_stories_r2805 s
  GROUP BY s.distribution_channel ORDER BY sum(s.views) DESC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_stories_by_channel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_stories_by_channel() TO authenticated;

DROP FUNCTION IF EXISTS r2805_top_stories();
CREATE OR REPLACE FUNCTION r2805_top_stories()
RETURNS TABLE(story_title text, storyteller_name text, story_format text, views int, shares int, engagement_score int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.story_title, s.storyteller_name, s.story_format, s.views, s.shares, s.engagement_score
  FROM anniversary_stories_r2805 s
  ORDER BY s.engagement_score DESC, s.views DESC LIMIT 10;
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_top_stories() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_top_stories() TO authenticated;

DROP FUNCTION IF EXISTS r2805_milestones_full();
CREATE OR REPLACE FUNCTION r2805_milestones_full()
RETURNS TABLE(milestone_title text, anniversary_year int, quarter text, milestone_category text, audience text, distribution_channel text, engagement_score int, tag text, is_published boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.milestone_title, m.anniversary_year, m.quarter, m.milestone_category, m.audience, m.distribution_channel, m.engagement_score, m.tag, m.is_published
  FROM anniversary_milestones_r2805 m
  ORDER BY m.anniversary_year, m.quarter;
END;$$;
REVOKE EXECUTE ON FUNCTION r2805_milestones_full() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2805_milestones_full() TO authenticated;

COMMIT;