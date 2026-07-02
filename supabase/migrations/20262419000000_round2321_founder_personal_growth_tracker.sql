BEGIN;

-- ============================================================================
-- r2321: Founder Personal Growth Tracker
-- Books read, podcasts heard each month, key takeaways, applied or not
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_growth_media_r2321 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_type text NOT NULL CHECK (media_type IN ('book','podcast','essay','course','talk')),
  title text NOT NULL,
  author_or_host text,
  source_url text,
  topic text,
  month_consumed date NOT NULL,
  duration_hours numeric(6,2),
  rating_out_of_5 integer CHECK (rating_out_of_5 BETWEEN 1 AND 5),
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('queued','in_progress','completed','abandoned')),
  recommended_by text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fgm_r2321_month ON public.founder_growth_media_r2321(month_consumed DESC);
CREATE INDEX IF NOT EXISTS idx_fgm_r2321_type ON public.founder_growth_media_r2321(media_type);
CREATE INDEX IF NOT EXISTS idx_fgm_r2321_status ON public.founder_growth_media_r2321(status);

ALTER TABLE public.founder_growth_media_r2321 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fgm_r2321_founder_all ON public.founder_growth_media_r2321;
CREATE POLICY fgm_r2321_founder_all ON public.founder_growth_media_r2321
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.founder_growth_takeaways_r2321 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_id uuid NOT NULL REFERENCES public.founder_growth_media_r2321(id) ON DELETE CASCADE,
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  takeaway_text text NOT NULL,
  applied_to_business boolean NOT NULL DEFAULT false,
  application_note text,
  applied_at timestamptz,
  impact_rating integer CHECK (impact_rating BETWEEN 1 AND 5),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fgt_r2321_media ON public.founder_growth_takeaways_r2321(media_id);
CREATE INDEX IF NOT EXISTS idx_fgt_r2321_applied ON public.founder_growth_takeaways_r2321(applied_to_business);

ALTER TABLE public.founder_growth_takeaways_r2321 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fgt_r2321_founder_all ON public.founder_growth_takeaways_r2321;
CREATE POLICY fgt_r2321_founder_all ON public.founder_growth_takeaways_r2321
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================================
-- RPC 1: summary stats
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_growth_summary_r2321()
RETURNS TABLE (
  total_items bigint,
  books_completed bigint,
  podcasts_completed bigint,
  in_progress_count bigint,
  total_takeaways bigint,
  applied_takeaways bigint,
  application_rate numeric,
  avg_rating numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.founder_growth_media_r2321),
    (SELECT COUNT(*) FROM public.founder_growth_media_r2321 WHERE media_type='book' AND status='completed'),
    (SELECT COUNT(*) FROM public.founder_growth_media_r2321 WHERE media_type='podcast' AND status='completed'),
    (SELECT COUNT(*) FROM public.founder_growth_media_r2321 WHERE status='in_progress'),
    (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321),
    (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321 WHERE applied_to_business),
    CASE WHEN (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321) = 0 THEN 0
         ELSE ROUND(100.0 * (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321 WHERE applied_to_business)
              / (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321), 1) END,
    COALESCE((SELECT ROUND(AVG(rating_out_of_5)::numeric, 2) FROM public.founder_growth_media_r2321 WHERE rating_out_of_5 IS NOT NULL), 0);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_growth_summary_r2321() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_growth_summary_r2321() TO authenticated;


-- ============================================================================
-- RPC 2: list media by month + type
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_growth_list_media_r2321(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  media_type text,
  title text,
  author_or_host text,
  topic text,
  month_consumed date,
  duration_hours numeric,
  rating_out_of_5 integer,
  status text,
  takeaway_count bigint,
  applied_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.media_type,
    m.title,
    m.author_or_host,
    m.topic,
    m.month_consumed,
    m.duration_hours,
    m.rating_out_of_5,
    m.status,
    (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321 t WHERE t.media_id = m.id),
    (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321 t WHERE t.media_id = m.id AND t.applied_to_business)
  FROM public.founder_growth_media_r2321 m
  ORDER BY m.month_consumed DESC, m.created_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_growth_list_media_r2321(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_growth_list_media_r2321(int) TO authenticated;


-- ============================================================================
-- RPC 3: monthly consumption rollup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_growth_monthly_rollup_r2321()
RETURNS TABLE (
  month_consumed date,
  books_count bigint,
  podcasts_count bigint,
  other_count bigint,
  total_hours numeric,
  takeaways_logged bigint,
  takeaways_applied bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.month_consumed,
    COUNT(*) FILTER (WHERE m.media_type='book'),
    COUNT(*) FILTER (WHERE m.media_type='podcast'),
    COUNT(*) FILTER (WHERE m.media_type NOT IN ('book','podcast')),
    COALESCE(SUM(m.duration_hours), 0),
    (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321 t
       JOIN public.founder_growth_media_r2321 m2 ON m2.id = t.media_id
       WHERE date_trunc('month', m2.month_consumed) = date_trunc('month', m.month_consumed)),
    (SELECT COUNT(*) FROM public.founder_growth_takeaways_r2321 t
       JOIN public.founder_growth_media_r2321 m2 ON m2.id = t.media_id
       WHERE date_trunc('month', m2.month_consumed) = date_trunc('month', m.month_consumed)
       AND t.applied_to_business)
  FROM public.founder_growth_media_r2321 m
  GROUP BY m.month_consumed
  ORDER BY m.month_consumed DESC
  LIMIT 24;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_growth_monthly_rollup_r2321() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_growth_monthly_rollup_r2321() TO authenticated;


-- ============================================================================
-- RPC 4: applied takeaways list
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_growth_applied_takeaways_r2321()
RETURNS TABLE (
  takeaway_id uuid,
  media_title text,
  media_type text,
  takeaway_text text,
  application_note text,
  applied_at timestamptz,
  impact_rating integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    m.title,
    m.media_type,
    t.takeaway_text,
    t.application_note,
    t.applied_at,
    t.impact_rating
  FROM public.founder_growth_takeaways_r2321 t
  JOIN public.founder_growth_media_r2321 m ON m.id = t.media_id
  WHERE t.applied_to_business
  ORDER BY t.applied_at DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_growth_applied_takeaways_r2321() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_growth_applied_takeaways_r2321() TO authenticated;


-- ============================================================================
-- RPC 5: unapplied takeaways (backlog of ideas)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_growth_unapplied_takeaways_r2321()
RETURNS TABLE (
  takeaway_id uuid,
  media_title text,
  media_type text,
  takeaway_text text,
  age_days int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    m.title,
    m.media_type,
    t.takeaway_text,
    GREATEST(0, EXTRACT(DAY FROM (now() - t.created_at))::int)
  FROM public.founder_growth_takeaways_r2321 t
  JOIN public.founder_growth_media_r2321 m ON m.id = t.media_id
  WHERE NOT t.applied_to_business
  ORDER BY t.created_at ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_growth_unapplied_takeaways_r2321() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_growth_unapplied_takeaways_r2321() TO authenticated;


-- ============================================================================
-- RPC 6: top topics studied
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_growth_top_topics_r2321()
RETURNS TABLE (
  topic text,
  items_count bigint,
  avg_rating numeric,
  total_hours numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(m.topic, 'uncategorized'),
    COUNT(*),
    COALESCE(ROUND(AVG(m.rating_out_of_5)::numeric, 2), 0),
    COALESCE(SUM(m.duration_hours), 0)
  FROM public.founder_growth_media_r2321 m
  GROUP BY COALESCE(m.topic, 'uncategorized')
  ORDER BY COUNT(*) DESC
  LIMIT 12;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_growth_top_topics_r2321() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_growth_top_topics_r2321() TO authenticated;


-- ============================================================================
-- RPC 7: in-progress reading list
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_growth_in_progress_r2321()
RETURNS TABLE (
  id uuid,
  title text,
  media_type text,
  author_or_host text,
  started_month date,
  days_in_progress int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    m.title,
    m.media_type,
    m.author_or_host,
    m.month_consumed,
    GREATEST(0, EXTRACT(DAY FROM (now() - m.created_at))::int)
  FROM public.founder_growth_media_r2321 m
  WHERE m.status = 'in_progress'
  ORDER BY m.created_at ASC
  LIMIT 30;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_growth_in_progress_r2321() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_growth_in_progress_r2321() TO authenticated;

COMMIT;
