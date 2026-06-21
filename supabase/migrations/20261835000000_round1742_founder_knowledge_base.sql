BEGIN;

-- ============================================================================
-- Round 1742: Founder Knowledge Base
-- Internal founder wiki: how-tos, decisions, playbooks
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_knowledge_articles_r1742 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  category text NOT NULL CHECK (category IN ('playbook','decision','how_to','policy','research','sop')),
  body_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  author_email text,
  published_at timestamptz,
  view_count int NOT NULL DEFAULT 0,
  last_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_knowledge_article_views_r1742 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id uuid NOT NULL REFERENCES public.founder_knowledge_articles_r1742(id) ON DELETE CASCADE,
  viewer_email text,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  search_query text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fkb_art_r1742_status ON public.founder_knowledge_articles_r1742(status, category);
CREATE INDEX IF NOT EXISTS idx_fkb_art_r1742_published_at ON public.founder_knowledge_articles_r1742(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_fkb_views_r1742_article ON public.founder_knowledge_article_views_r1742(article_id, viewed_at DESC);

ALTER TABLE public.founder_knowledge_articles_r1742 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_knowledge_article_views_r1742 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fkb_art_r1742_founder_all ON public.founder_knowledge_articles_r1742;
CREATE POLICY fkb_art_r1742_founder_all ON public.founder_knowledge_articles_r1742
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fkb_views_r1742_founder_all ON public.founder_knowledge_article_views_r1742;
CREATE POLICY fkb_views_r1742_founder_all ON public.founder_knowledge_article_views_r1742
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_articles
-- ============================================================================
DROP FUNCTION IF EXISTS public.fkb_list_articles_r1742(text, text);
CREATE OR REPLACE FUNCTION public.fkb_list_articles_r1742(
  p_status text DEFAULT NULL,
  p_category text DEFAULT NULL
)
RETURNS TABLE(
  id uuid,
  title text,
  category text,
  status text,
  author_email text,
  published_at timestamptz,
  view_count int,
  last_reviewed_at timestamptz,
  created_at timestamptz
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
  SELECT a.id, a.title, a.category, a.status, a.author_email,
         a.published_at, a.view_count, a.last_reviewed_at, a.created_at
  FROM public.founder_knowledge_articles_r1742 a
  WHERE (p_status IS NULL OR a.status = p_status)
    AND (p_category IS NULL OR a.category = p_category)
  ORDER BY COALESCE(a.published_at, a.created_at) DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fkb_list_articles_r1742(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fkb_list_articles_r1742(text, text) TO authenticated;

-- ============================================================================
-- RPC 2: publish_article
-- ============================================================================
DROP FUNCTION IF EXISTS public.fkb_publish_article_r1742(uuid);
CREATE OR REPLACE FUNCTION public.fkb_publish_article_r1742(p_article_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_knowledge_articles_r1742
  SET status = 'published',
      published_at = COALESCE(published_at, now()),
      updated_at = now()
  WHERE id = p_article_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'article_not_found';
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fkb_publish_article_r1742',
          jsonb_build_object('article_id', v_id));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fkb_publish_article_r1742(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fkb_publish_article_r1742(uuid) TO authenticated;

-- ============================================================================
-- RPC 3: list_views
-- ============================================================================
DROP FUNCTION IF EXISTS public.fkb_list_views_r1742(uuid, int);
CREATE OR REPLACE FUNCTION public.fkb_list_views_r1742(
  p_article_id uuid DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE(
  id uuid,
  article_id uuid,
  article_title text,
  viewer_email text,
  viewed_at timestamptz,
  search_query text
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
  SELECT v.id, v.article_id, a.title, v.viewer_email, v.viewed_at, v.search_query
  FROM public.founder_knowledge_article_views_r1742 v
  JOIN public.founder_knowledge_articles_r1742 a ON a.id = v.article_id
  WHERE (p_article_id IS NULL OR v.article_id = p_article_id)
  ORDER BY v.viewed_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fkb_list_views_r1742(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fkb_list_views_r1742(uuid, int) TO authenticated;

-- ============================================================================
-- RPC 4: log_view
-- ============================================================================
DROP FUNCTION IF EXISTS public.fkb_log_view_r1742(uuid, text);
CREATE OR REPLACE FUNCTION public.fkb_log_view_r1742(
  p_article_id uuid,
  p_search_query text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_view_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_knowledge_article_views_r1742 (article_id, viewer_email, search_query)
  VALUES (p_article_id, (auth.jwt()->>'email'), p_search_query)
  RETURNING id INTO v_view_id;

  UPDATE public.founder_knowledge_articles_r1742
  SET view_count = view_count + 1,
      updated_at = now()
  WHERE id = p_article_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fkb_log_view_r1742',
          jsonb_build_object('article_id', p_article_id, 'view_id', v_view_id));

  RETURN v_view_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fkb_log_view_r1742(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fkb_log_view_r1742(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 5: archive_article
-- ============================================================================
DROP FUNCTION IF EXISTS public.fkb_archive_article_r1742(uuid);
CREATE OR REPLACE FUNCTION public.fkb_archive_article_r1742(p_article_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_knowledge_articles_r1742
  SET status = 'archived',
      updated_at = now()
  WHERE id = p_article_id
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'article_not_found';
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fkb_archive_article_r1742',
          jsonb_build_object('article_id', v_id));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fkb_archive_article_r1742(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fkb_archive_article_r1742(uuid) TO authenticated;

-- ============================================================================
-- RPC 6: top_viewed
-- ============================================================================
DROP FUNCTION IF EXISTS public.fkb_top_viewed_r1742(int);
CREATE OR REPLACE FUNCTION public.fkb_top_viewed_r1742(p_limit int DEFAULT 20)
RETURNS TABLE(
  id uuid,
  title text,
  category text,
  view_count int,
  published_at timestamptz
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
  SELECT a.id, a.title, a.category, a.view_count, a.published_at
  FROM public.founder_knowledge_articles_r1742 a
  WHERE a.status = 'published'
  ORDER BY a.view_count DESC, a.published_at DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fkb_top_viewed_r1742(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fkb_top_viewed_r1742(int) TO authenticated;

-- ============================================================================
-- RPC 7: stale_articles_needing_review
-- ============================================================================
DROP FUNCTION IF EXISTS public.fkb_stale_articles_r1742(int);
CREATE OR REPLACE FUNCTION public.fkb_stale_articles_r1742(p_days int DEFAULT 90)
RETURNS TABLE(
  id uuid,
  title text,
  category text,
  last_reviewed_at timestamptz,
  published_at timestamptz,
  days_since_review int
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
  SELECT a.id, a.title, a.category, a.last_reviewed_at, a.published_at,
         EXTRACT(DAY FROM (now() - COALESCE(a.last_reviewed_at, a.published_at, a.created_at)))::int AS days_since_review
  FROM public.founder_knowledge_articles_r1742 a
  WHERE a.status = 'published'
    AND COALESCE(a.last_reviewed_at, a.published_at, a.created_at) < (now() - (GREATEST(1, p_days) || ' days')::interval)
  ORDER BY COALESCE(a.last_reviewed_at, a.published_at, a.created_at) ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fkb_stale_articles_r1742(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fkb_stale_articles_r1742(int) TO authenticated;

COMMIT;