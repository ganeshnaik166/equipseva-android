BEGIN;

-- ============================================================================
-- Round 2252 — Customer Service Knowledge-Base Usage Analytics
-- Which KB articles are read most, which solve, which need rewrite.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.cs_kb_articles_r2252 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_code text NOT NULL UNIQUE,
  title text NOT NULL,
  category text NOT NULL CHECK (category IN ('billing','amc','warranty','repair','installation','spare_parts','account','app_usage','escalation','policy')),
  audience text NOT NULL CHECK (audience IN ('customer','agent','engineer','internal')),
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('draft','published','retired','flagged_for_rewrite')),
  word_count int NOT NULL DEFAULT 0 CHECK (word_count >= 0),
  author_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cs_kb_article_reads_r2252 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id uuid NOT NULL REFERENCES public.cs_kb_articles_r2252(id) ON DELETE CASCADE,
  reader_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reader_role text NOT NULL CHECK (reader_role IN ('customer','agent','engineer','internal')),
  read_source text NOT NULL CHECK (read_source IN ('search','suggested','direct_link','chatbot','email_link')),
  seconds_on_page int NOT NULL DEFAULT 0 CHECK (seconds_on_page >= 0),
  resolved_issue boolean,
  rated_helpful boolean,
  feedback_note text,
  read_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cs_kb_articles_r2252_status ON public.cs_kb_articles_r2252(status);
CREATE INDEX IF NOT EXISTS idx_cs_kb_articles_r2252_category ON public.cs_kb_articles_r2252(category);
CREATE INDEX IF NOT EXISTS idx_cs_kb_reads_r2252_article ON public.cs_kb_article_reads_r2252(article_id);
CREATE INDEX IF NOT EXISTS idx_cs_kb_reads_r2252_at ON public.cs_kb_article_reads_r2252(read_at DESC);

ALTER TABLE public.cs_kb_articles_r2252 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cs_kb_article_reads_r2252 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.cs_kb_articles_r2252;
CREATE POLICY founder_all ON public.cs_kb_articles_r2252
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.cs_kb_article_reads_r2252;
CREATE POLICY founder_all ON public.cs_kb_article_reads_r2252
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

-- 1. Top read articles last 30d
CREATE OR REPLACE FUNCTION public.r2252_top_read_articles()
RETURNS TABLE(
  article_code text,
  title text,
  category text,
  audience text,
  status text,
  total_reads int,
  unique_readers int,
  avg_seconds_on_page numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.article_code,
    a.title,
    a.category,
    a.audience,
    a.status,
    (COUNT(r.id))::int AS total_reads,
    (COUNT(DISTINCT r.reader_user_id))::int AS unique_readers,
    ROUND(AVG(r.seconds_on_page)::numeric, 1) AS avg_seconds_on_page
  FROM public.cs_kb_articles_r2252 a
  LEFT JOIN public.cs_kb_article_reads_r2252 r
    ON r.article_id = a.id AND r.read_at >= now() - interval '30 days'
  GROUP BY a.id, a.article_code, a.title, a.category, a.audience, a.status
  ORDER BY total_reads DESC
  LIMIT 30;
END;
$$;

-- 2. Lowest resolution articles — need rewrite
CREATE OR REPLACE FUNCTION public.r2252_low_resolution_articles()
RETURNS TABLE(
  article_code text,
  title text,
  category text,
  total_reads int,
  resolved_count int,
  resolution_rate_pct numeric,
  flagged boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.article_code,
    a.title,
    a.category,
    (COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL))::int AS total_reads,
    (COUNT(r.id) FILTER (WHERE r.resolved_issue = true))::int AS resolved_count,
    CASE WHEN COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL) > 0
      THEN ROUND(100.0 * COUNT(r.id) FILTER (WHERE r.resolved_issue = true)
        / NULLIF(COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL), 0), 1)
      ELSE NULL END AS resolution_rate_pct,
    (a.status = 'flagged_for_rewrite') AS flagged
  FROM public.cs_kb_articles_r2252 a
  LEFT JOIN public.cs_kb_article_reads_r2252 r
    ON r.article_id = a.id AND r.read_at >= now() - interval '60 days'
  GROUP BY a.id, a.article_code, a.title, a.category, a.status
  HAVING COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL) >= 5
  ORDER BY resolution_rate_pct ASC NULLS LAST
  LIMIT 30;
END;
$$;

-- 3. Category mix
CREATE OR REPLACE FUNCTION public.r2252_category_mix()
RETURNS TABLE(
  category text,
  articles_published int,
  reads_30d int,
  resolved_30d int,
  resolution_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.category,
    (COUNT(DISTINCT a.id) FILTER (WHERE a.status = 'published'))::int AS articles_published,
    (COUNT(r.id))::int AS reads_30d,
    (COUNT(r.id) FILTER (WHERE r.resolved_issue = true))::int AS resolved_30d,
    CASE WHEN COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL) > 0
      THEN ROUND(100.0 * COUNT(r.id) FILTER (WHERE r.resolved_issue = true)
        / NULLIF(COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL), 0), 1)
      ELSE NULL END AS resolution_rate_pct
  FROM public.cs_kb_articles_r2252 a
  LEFT JOIN public.cs_kb_article_reads_r2252 r
    ON r.article_id = a.id AND r.read_at >= now() - interval '30 days'
  GROUP BY a.category
  ORDER BY reads_30d DESC;
END;
$$;

-- 4. Read-source mix
CREATE OR REPLACE FUNCTION public.r2252_read_source_mix()
RETURNS TABLE(
  read_source text,
  reads_30d int,
  helpful_pct numeric,
  resolved_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.read_source,
    (COUNT(r.id))::int AS reads_30d,
    CASE WHEN COUNT(r.id) FILTER (WHERE r.rated_helpful IS NOT NULL) > 0
      THEN ROUND(100.0 * COUNT(r.id) FILTER (WHERE r.rated_helpful = true)
        / NULLIF(COUNT(r.id) FILTER (WHERE r.rated_helpful IS NOT NULL), 0), 1)
      ELSE NULL END AS helpful_pct,
    CASE WHEN COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL) > 0
      THEN ROUND(100.0 * COUNT(r.id) FILTER (WHERE r.resolved_issue = true)
        / NULLIF(COUNT(r.id) FILTER (WHERE r.resolved_issue IS NOT NULL), 0), 1)
      ELSE NULL END AS resolved_pct
  FROM public.cs_kb_article_reads_r2252 r
  WHERE r.read_at >= now() - interval '30 days'
  GROUP BY r.read_source
  ORDER BY reads_30d DESC;
END;
$$;

-- 5. Recent feedback notes
CREATE OR REPLACE FUNCTION public.r2252_recent_feedback()
RETURNS TABLE(
  read_at timestamptz,
  article_code text,
  title text,
  reader_role text,
  rated_helpful boolean,
  resolved_issue boolean,
  feedback_note text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.read_at,
    a.article_code,
    a.title,
    r.reader_role,
    r.rated_helpful,
    r.resolved_issue,
    r.feedback_note
  FROM public.cs_kb_article_reads_r2252 r
  JOIN public.cs_kb_articles_r2252 a ON a.id = r.article_id
  WHERE r.feedback_note IS NOT NULL AND length(r.feedback_note) > 0
  ORDER BY r.read_at DESC
  LIMIT 40;
END;
$$;

-- 6. Stale articles never updated
CREATE OR REPLACE FUNCTION public.r2252_stale_articles()
RETURNS TABLE(
  article_code text,
  title text,
  category text,
  status text,
  days_since_update int,
  reads_30d int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.article_code,
    a.title,
    a.category,
    a.status,
    EXTRACT(day FROM now() - a.last_updated_at)::int AS days_since_update,
    (COUNT(r.id))::int AS reads_30d
  FROM public.cs_kb_articles_r2252 a
  LEFT JOIN public.cs_kb_article_reads_r2252 r
    ON r.article_id = a.id AND r.read_at >= now() - interval '30 days'
  WHERE a.status = 'published'
    AND a.last_updated_at < now() - interval '180 days'
  GROUP BY a.id, a.article_code, a.title, a.category, a.status, a.last_updated_at
  ORDER BY days_since_update DESC
  LIMIT 30;
END;
$$;

-- 7. Header KPI summary
CREATE OR REPLACE FUNCTION public.r2252_summary()
RETURNS TABLE(
  total_published int,
  flagged_for_rewrite int,
  reads_30d int,
  resolution_rate_pct numeric,
  helpful_rate_pct numeric,
  stale_180d int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FILTER (WHERE status = 'published') FROM public.cs_kb_articles_r2252)::int,
    (SELECT COUNT(*) FILTER (WHERE status = 'flagged_for_rewrite') FROM public.cs_kb_articles_r2252)::int,
    (SELECT COUNT(*) FROM public.cs_kb_article_reads_r2252 WHERE read_at >= now() - interval '30 days')::int,
    (SELECT CASE WHEN COUNT(*) FILTER (WHERE resolved_issue IS NOT NULL) > 0
        THEN ROUND(100.0 * COUNT(*) FILTER (WHERE resolved_issue = true)
          / NULLIF(COUNT(*) FILTER (WHERE resolved_issue IS NOT NULL), 0), 1)
        ELSE NULL END
      FROM public.cs_kb_article_reads_r2252
      WHERE read_at >= now() - interval '30 days'),
    (SELECT CASE WHEN COUNT(*) FILTER (WHERE rated_helpful IS NOT NULL) > 0
        THEN ROUND(100.0 * COUNT(*) FILTER (WHERE rated_helpful = true)
          / NULLIF(COUNT(*) FILTER (WHERE rated_helpful IS NOT NULL), 0), 1)
        ELSE NULL END
      FROM public.cs_kb_article_reads_r2252
      WHERE read_at >= now() - interval '30 days'),
    (SELECT COUNT(*) FROM public.cs_kb_articles_r2252
      WHERE status = 'published' AND last_updated_at < now() - interval '180 days')::int;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE ALL ON FUNCTION public.r2252_top_read_articles() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2252_low_resolution_articles() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2252_category_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2252_read_source_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2252_recent_feedback() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2252_stale_articles() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2252_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2252_top_read_articles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2252_low_resolution_articles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2252_category_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2252_read_source_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2252_recent_feedback() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2252_stale_articles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2252_summary() TO authenticated;

COMMIT;
