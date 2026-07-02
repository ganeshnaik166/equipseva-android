BEGIN;

CREATE TABLE IF NOT EXISTS engineering_blog_articles_r2881 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  author_engineer text NOT NULL,
  topic text NOT NULL CHECK (topic IN ('architecture','scaling','reliability','ml','devex','security')),
  word_count int NOT NULL CHECK (word_count > 0),
  published_on date NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1-2026','Q2-2026','Q3-2026','Q4-2026')),
  page_views int NOT NULL DEFAULT 0 CHECK (page_views >= 0),
  hn_points int NOT NULL DEFAULT 0 CHECK (hn_points >= 0),
  inbound_applications int NOT NULL DEFAULT 0 CHECK (inbound_applications >= 0),
  hires_attributed int NOT NULL DEFAULT 0 CHECK (hires_attributed >= 0),
  verdict text NOT NULL CHECK (verdict IN ('hit','breakeven','dud','viral')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineering_blog_articles_r2881 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineering_blog_articles_r2881;
CREATE POLICY founder_all ON engineering_blog_articles_r2881 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineering_blog_articles_r2881 (slug, title, author_engineer, topic, word_count, published_on, quarter, page_views, hn_points, inbound_applications, hires_attributed, verdict) VALUES
  ('scaling-amc-cron-jobs', 'Scaling 14k AMC cron jobs on Supabase', 'Ravi Kumar', 'scaling', 3200, '2026-04-12'::date, 'Q2-2026', 48200, 412, 18, 2, 'viral'),
  ('rls-policies-at-scale', 'RLS policies that survive 200 founder-only RPCs', 'Priya Iyer', 'security', 2800, '2026-04-29'::date, 'Q2-2026', 22100, 187, 9, 1, 'hit'),
  ('compose-recomposition-debug', 'Hunting recomposition leaks in Compose', 'Arjun Mehta', 'devex', 2400, '2026-05-14'::date, 'Q2-2026', 31500, 245, 12, 1, 'hit'),
  ('ml-triage-pipeline', 'A small-LLM triage pipeline for repair jobs', 'Sneha Rao', 'ml', 4100, '2026-05-30'::date, 'Q2-2026', 9800, 64, 4, 0, 'breakeven'),
  ('postgres-cron-gotchas', 'pg_cron has no JWT and other surprises', 'Vikram Joshi', 'reliability', 2100, '2026-06-04'::date, 'Q2-2026', 14700, 98, 6, 1, 'hit'),
  ('event-bus-postmortem', 'Why we killed our internal event bus', 'Karan Bhatia', 'architecture', 3600, '2026-06-15'::date, 'Q2-2026', 5200, 21, 1, 0, 'dud');

CREATE TABLE IF NOT EXISTS engineering_blog_topic_signals_r2881 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic text NOT NULL UNIQUE CHECK (topic IN ('architecture','scaling','reliability','ml','devex','security')),
  target_articles_per_quarter int NOT NULL CHECK (target_articles_per_quarter > 0),
  articles_shipped int NOT NULL DEFAULT 0 CHECK (articles_shipped >= 0),
  avg_engagement_score numeric(6,2) NOT NULL DEFAULT 0 CHECK (avg_engagement_score >= 0),
  recruit_signal text NOT NULL CHECK (recruit_signal IN ('strong','moderate','weak')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineering_blog_topic_signals_r2881 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineering_blog_topic_signals_r2881;
CREATE POLICY founder_all ON engineering_blog_topic_signals_r2881 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineering_blog_topic_signals_r2881 (topic, target_articles_per_quarter, articles_shipped, avg_engagement_score, recruit_signal, notes) VALUES
  ('scaling', 2, 1, 88.50, 'strong', 'Top funnel; viral on HN'),
  ('security', 1, 1, 72.30, 'moderate', 'Niche but high signal'),
  ('devex', 2, 1, 81.40, 'strong', 'Compose audience converts'),
  ('ml', 1, 1, 45.20, 'weak', 'Too long; audience drift'),
  ('reliability', 2, 1, 76.80, 'moderate', 'Cron deep-dives land'),
  ('architecture', 1, 1, 28.10, 'weak', 'Cut next quarter');

DROP FUNCTION IF EXISTS founder_blog_articles_list_r2881();
CREATE FUNCTION founder_blog_articles_list_r2881()
RETURNS TABLE(slug text, title text, author_engineer text, topic text, quarter text, page_views int, hn_points int, hires_attributed int, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.slug, a.title, a.author_engineer, a.topic, a.quarter, a.page_views, a.hn_points, a.hires_attributed, a.verdict
    FROM engineering_blog_articles_r2881 a ORDER BY a.published_on DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_blog_articles_list_r2881() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blog_articles_list_r2881() TO authenticated;

DROP FUNCTION IF EXISTS founder_blog_topic_signals_r2881();
CREATE FUNCTION founder_blog_topic_signals_r2881()
RETURNS TABLE(topic text, target_articles_per_quarter int, articles_shipped int, avg_engagement_score numeric, recruit_signal text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.topic, t.target_articles_per_quarter, t.articles_shipped, t.avg_engagement_score, t.recruit_signal, t.notes
    FROM engineering_blog_topic_signals_r2881 t ORDER BY t.avg_engagement_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_blog_topic_signals_r2881() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blog_topic_signals_r2881() TO authenticated;

DROP FUNCTION IF EXISTS founder_blog_kpis_r2881();
CREATE FUNCTION founder_blog_kpis_r2881()
RETURNS TABLE(total_articles bigint, total_views bigint, total_hires bigint, viral_count bigint, dud_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(page_views),0)::bigint,
    COALESCE(SUM(hires_attributed),0)::bigint,
    COUNT(*) FILTER (WHERE verdict='viral')::bigint,
    COUNT(*) FILTER (WHERE verdict='dud')::bigint
  FROM engineering_blog_articles_r2881;
END $$;
REVOKE EXECUTE ON FUNCTION founder_blog_kpis_r2881() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blog_kpis_r2881() TO authenticated;

DROP FUNCTION IF EXISTS founder_blog_top_authors_r2881();
CREATE FUNCTION founder_blog_top_authors_r2881()
RETURNS TABLE(author_engineer text, articles bigint, total_views bigint, total_hires bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.author_engineer, COUNT(*)::bigint, SUM(a.page_views)::bigint, SUM(a.hires_attributed)::bigint
    FROM engineering_blog_articles_r2881 a GROUP BY a.author_engineer ORDER BY SUM(a.page_views) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_blog_top_authors_r2881() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blog_top_authors_r2881() TO authenticated;

DROP FUNCTION IF EXISTS founder_blog_viral_only_r2881();
CREATE FUNCTION founder_blog_viral_only_r2881()
RETURNS TABLE(slug text, title text, page_views int, hn_points int, hires_attributed int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.slug, a.title, a.page_views, a.hn_points, a.hires_attributed
    FROM engineering_blog_articles_r2881 a WHERE a.verdict='viral' ORDER BY a.hn_points DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_blog_viral_only_r2881() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blog_viral_only_r2881() TO authenticated;

DROP FUNCTION IF EXISTS founder_blog_duds_r2881();
CREATE FUNCTION founder_blog_duds_r2881()
RETURNS TABLE(slug text, title text, topic text, page_views int, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.slug, a.title, a.topic, a.page_views, a.verdict
    FROM engineering_blog_articles_r2881 a WHERE a.verdict='dud' ORDER BY a.page_views ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_blog_duds_r2881() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blog_duds_r2881() TO authenticated;

DROP FUNCTION IF EXISTS founder_blog_quarter_summary_r2881();
CREATE FUNCTION founder_blog_quarter_summary_r2881()
RETURNS TABLE(quarter text, articles bigint, views bigint, hires bigint, viral bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.quarter, COUNT(*)::bigint, SUM(a.page_views)::bigint, SUM(a.hires_attributed)::bigint, COUNT(*) FILTER (WHERE a.verdict='viral')::bigint
    FROM engineering_blog_articles_r2881 a GROUP BY a.quarter ORDER BY a.quarter;
END $$;
REVOKE EXECUTE ON FUNCTION founder_blog_quarter_summary_r2881() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_blog_quarter_summary_r2881() TO authenticated;

COMMIT;
