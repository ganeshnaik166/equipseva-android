BEGIN;

-- ============================================================================
-- Round 1830 — Founder Weekly Reading Log
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_weekly_reading_log_r1830 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date UNIQUE NOT NULL,
  articles_read int NOT NULL DEFAULT 0,
  books_pages_read int NOT NULL DEFAULT 0,
  podcasts_minutes int NOT NULL DEFAULT 0,
  talks_watched int NOT NULL DEFAULT 0,
  key_takeaways_md text,
  applied_to_business_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_reading_source_breakdown_r1830 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL REFERENCES public.founder_weekly_reading_log_r1830(week_start) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (source_type IN ('article','book','podcast','talk','movie')),
  source_label text NOT NULL,
  duration_minutes int NOT NULL DEFAULT 0,
  helpful_score int NOT NULL CHECK (helpful_score BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reading_src_r1830_week ON public.founder_reading_source_breakdown_r1830(week_start);
CREATE INDEX IF NOT EXISTS idx_reading_src_r1830_type ON public.founder_reading_source_breakdown_r1830(source_type);

ALTER TABLE public.founder_weekly_reading_log_r1830 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_reading_source_breakdown_r1830 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_reading_log_r1830 ON public.founder_weekly_reading_log_r1830;
CREATE POLICY p_founder_all_reading_log_r1830 ON public.founder_weekly_reading_log_r1830
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_all_reading_src_r1830 ON public.founder_reading_source_breakdown_r1830;
CREATE POLICY p_founder_all_reading_src_r1830 ON public.founder_reading_source_breakdown_r1830
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_logs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_logs_r1830(p_limit int DEFAULT 26)
RETURNS TABLE (
  week_start date,
  articles_read int,
  books_pages_read int,
  podcasts_minutes int,
  talks_watched int,
  key_takeaways_md text,
  applied_to_business_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.week_start, l.articles_read, l.books_pages_read, l.podcasts_minutes,
         l.talks_watched, l.key_takeaways_md, l.applied_to_business_md, l.recorded_at
  FROM public.founder_weekly_reading_log_r1830 l
  ORDER BY l.week_start DESC
  LIMIT p_limit;
END $$;

-- ============================================================================
-- RPC 2: record_week (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.record_week_r1830(
  p_week_start date,
  p_articles_read int,
  p_books_pages_read int,
  p_podcasts_minutes int,
  p_talks_watched int,
  p_key_takeaways_md text,
  p_applied_to_business_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_weekly_reading_log_r1830 (
    week_start, articles_read, books_pages_read, podcasts_minutes,
    talks_watched, key_takeaways_md, applied_to_business_md
  ) VALUES (
    p_week_start, COALESCE(p_articles_read,0), COALESCE(p_books_pages_read,0),
    COALESCE(p_podcasts_minutes,0), COALESCE(p_talks_watched,0),
    p_key_takeaways_md, p_applied_to_business_md
  )
  ON CONFLICT (week_start) DO UPDATE SET
    articles_read = EXCLUDED.articles_read,
    books_pages_read = EXCLUDED.books_pages_read,
    podcasts_minutes = EXCLUDED.podcasts_minutes,
    talks_watched = EXCLUDED.talks_watched,
    key_takeaways_md = EXCLUDED.key_takeaways_md,
    applied_to_business_md = EXCLUDED.applied_to_business_md,
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_week_r1830',
          jsonb_build_object('week_start', p_week_start, 'id', v_id));
  RETURN v_id;
END $$;

-- ============================================================================
-- RPC 3: list_sources
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_sources_r1830(p_week_start date DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  week_start date,
  source_type text,
  source_label text,
  duration_minutes int,
  helpful_score int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.week_start, s.source_type, s.source_label,
         s.duration_minutes, s.helpful_score, s.created_at
  FROM public.founder_reading_source_breakdown_r1830 s
  WHERE p_week_start IS NULL OR s.week_start = p_week_start
  ORDER BY s.week_start DESC, s.helpful_score DESC
  LIMIT p_limit;
END $$;

-- ============================================================================
-- RPC 4: add_source (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_source_r1830(
  p_week_start date,
  p_source_type text,
  p_source_label text,
  p_duration_minutes int,
  p_helpful_score int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.founder_weekly_reading_log_r1830 WHERE week_start = p_week_start) THEN
    INSERT INTO public.founder_weekly_reading_log_r1830 (week_start) VALUES (p_week_start);
  END IF;
  INSERT INTO public.founder_reading_source_breakdown_r1830 (
    week_start, source_type, source_label, duration_minutes, helpful_score
  ) VALUES (
    p_week_start, p_source_type, p_source_label,
    COALESCE(p_duration_minutes,0), p_helpful_score
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_source_r1830',
          jsonb_build_object('week_start', p_week_start, 'source_type', p_source_type, 'id', v_id));
  RETURN v_id;
END $$;

-- ============================================================================
-- RPC 5: top_helpful_sources
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_helpful_sources_r1830(p_limit int DEFAULT 20)
RETURNS TABLE (
  source_type text,
  source_label text,
  week_start date,
  helpful_score int,
  duration_minutes int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.source_type, s.source_label, s.week_start, s.helpful_score, s.duration_minutes
  FROM public.founder_reading_source_breakdown_r1830 s
  ORDER BY s.helpful_score DESC, s.week_start DESC
  LIMIT p_limit;
END $$;

-- ============================================================================
-- RPC 6: monthly_reading_trend
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_reading_trend_r1830(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start date,
  weeks_logged int,
  total_articles int,
  total_book_pages int,
  total_podcast_minutes int,
  total_talks int,
  avg_helpful_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('month', l.week_start)::date AS month_start,
    (COUNT(*) )::int AS weeks_logged,
    COALESCE(SUM(l.articles_read),0)::int AS total_articles,
    COALESCE(SUM(l.books_pages_read),0)::int AS total_book_pages,
    COALESCE(SUM(l.podcasts_minutes),0)::int AS total_podcast_minutes,
    COALESCE(SUM(l.talks_watched),0)::int AS total_talks,
    COALESCE((
      SELECT ROUND(AVG(s.helpful_score)::numeric, 2)
      FROM public.founder_reading_source_breakdown_r1830 s
      WHERE date_trunc('month', s.week_start) = date_trunc('month', l.week_start)
    ), 0) AS avg_helpful_score
  FROM public.founder_weekly_reading_log_r1830 l
  WHERE l.week_start >= (CURRENT_DATE - (p_months || ' months')::interval)
  GROUP BY date_trunc('month', l.week_start)
  ORDER BY month_start DESC;
END $$;

-- ============================================================================
-- RPC 7: applied_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.applied_summary_r1830(p_limit int DEFAULT 20)
RETURNS TABLE (
  week_start date,
  applied_to_business_md text,
  key_takeaways_md text,
  total_minutes int,
  source_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.week_start,
    l.applied_to_business_md,
    l.key_takeaways_md,
    (l.podcasts_minutes + COALESCE((
      SELECT SUM(s.duration_minutes)::int
      FROM public.founder_reading_source_breakdown_r1830 s
      WHERE s.week_start = l.week_start
    ), 0))::int AS total_minutes,
    COALESCE((
      SELECT COUNT(*)::int
      FROM public.founder_reading_source_breakdown_r1830 s
      WHERE s.week_start = l.week_start
    ), 0) AS source_count
  FROM public.founder_weekly_reading_log_r1830 l
  WHERE l.applied_to_business_md IS NOT NULL AND length(trim(l.applied_to_business_md)) > 0
  ORDER BY l.week_start DESC
  LIMIT p_limit;
END $$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_logs_r1830(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_week_r1830(date,int,int,int,int,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_sources_r1830(date,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_source_r1830(date,text,text,int,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_helpful_sources_r1830(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.monthly_reading_trend_r1830(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.applied_summary_r1830(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_logs_r1830(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_week_r1830(date,int,int,int,int,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_sources_r1830(date,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_source_r1830(date,text,text,int,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_helpful_sources_r1830(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.monthly_reading_trend_r1830(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.applied_summary_r1830(int) TO authenticated;

COMMIT;