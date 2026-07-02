BEGIN;
-- r1415 · Founder internal wiki + playbook library
-- 2 tables (articles + revisions) · 7 RPCs · founder-only



-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_internal_wiki_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  category text NOT NULL CHECK (category IN (
    'onboarding','engineering','operations','sales','finance',
    'hr','legal','security','customer_success','playbook'
  )),
  section text NOT NULL CHECK (section IN (
    'how_to','runbook','retrospective','decision_record',
    'reference','template','escalation_playbook'
  )),
  content_md text,
  version int NOT NULL DEFAULT 1,
  is_published boolean NOT NULL DEFAULT false,
  owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  tags text[] NOT NULL DEFAULT ARRAY[]::text[],
  view_count int NOT NULL DEFAULT 0,
  last_reviewed_at timestamptz,
  next_review_due_at date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_internal_wiki_articles_cat_idx
  ON public.founder_internal_wiki_articles (category, section);
CREATE INDEX IF NOT EXISTS founder_internal_wiki_articles_pub_idx
  ON public.founder_internal_wiki_articles (is_published, updated_at DESC);
CREATE INDEX IF NOT EXISTS founder_internal_wiki_articles_due_idx
  ON public.founder_internal_wiki_articles (next_review_due_at)
  WHERE next_review_due_at IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.founder_internal_wiki_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id uuid NOT NULL REFERENCES public.founder_internal_wiki_articles(id) ON DELETE CASCADE,
  version int NOT NULL,
  change_summary text,
  content_md text,
  edited_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  edited_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_internal_wiki_revisions_art_idx
  ON public.founder_internal_wiki_revisions (article_id, version DESC);
CREATE INDEX IF NOT EXISTS founder_internal_wiki_revisions_edited_idx
  ON public.founder_internal_wiki_revisions (edited_at DESC);

ALTER TABLE public.founder_internal_wiki_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_internal_wiki_revisions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RPC 1 · summary (16 KPIs)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_internal_wiki_summary()
RETURNS TABLE (
  total_articles bigint,
  published_count bigint,
  draft_count bigint,
  distinct_categories bigint,
  distinct_sections bigint,
  total_revisions bigint,
  total_views bigint,
  articles_due_review bigint,
  articles_overdue_review bigint,
  articles_never_reviewed bigint,
  top_category text,
  top_category_count bigint,
  top_section text,
  top_section_count bigint,
  most_viewed_article_title text,
  most_viewed_article_views bigint,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH a AS (SELECT * FROM public.founder_internal_wiki_articles),
  cat AS (
    SELECT category, count(*)::bigint AS c FROM a GROUP BY category ORDER BY c DESC LIMIT 1
  ),
  sec AS (
    SELECT section, count(*)::bigint AS c FROM a GROUP BY section ORDER BY c DESC LIMIT 1
  ),
  top_v AS (
    SELECT title, view_count::bigint AS v FROM a ORDER BY view_count DESC NULLS LAST, updated_at DESC LIMIT 1
  )
  SELECT
    (SELECT count(*)::bigint FROM a),
    (SELECT count(*)::bigint FROM a WHERE is_published),
    (SELECT count(*)::bigint FROM a WHERE NOT is_published),
    (SELECT count(DISTINCT category)::bigint FROM a),
    (SELECT count(DISTINCT section)::bigint FROM a),
    (SELECT count(*)::bigint FROM public.founder_internal_wiki_revisions),
    (SELECT COALESCE(sum(view_count),0)::bigint FROM a),
    (SELECT count(*)::bigint FROM a WHERE next_review_due_at IS NOT NULL AND next_review_due_at <= current_date + 30),
    (SELECT count(*)::bigint FROM a WHERE next_review_due_at IS NOT NULL AND next_review_due_at < current_date),
    (SELECT count(*)::bigint FROM a WHERE last_reviewed_at IS NULL),
    (SELECT category FROM cat),
    (SELECT c FROM cat),
    (SELECT section FROM sec),
    (SELECT c FROM sec),
    (SELECT title FROM top_v),
    (SELECT v FROM top_v),
    now();
END;
$$;
REVOKE ALL ON FUNCTION public.founder_internal_wiki_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_internal_wiki_summary() TO authenticated;

-- ============================================================================
-- RPC 2 · recent articles (50)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_internal_wiki_articles_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  slug text,
  title text,
  category text,
  section text,
  version int,
  is_published boolean,
  tags text[],
  view_count int,
  last_reviewed_at timestamptz,
  next_review_due_at date,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT a.id, a.slug, a.title, a.category, a.section, a.version, a.is_published,
         a.tags, a.view_count, a.last_reviewed_at, a.next_review_due_at, a.updated_at
  FROM public.founder_internal_wiki_articles a
  ORDER BY a.updated_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
REVOKE ALL ON FUNCTION public.founder_internal_wiki_articles_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_internal_wiki_articles_recent(int) TO authenticated;

-- ============================================================================
-- RPC 3 · articles due review (next_review_due_at <= current_date + 30d)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_internal_wiki_articles_due_review()
RETURNS TABLE (
  id uuid,
  slug text,
  title text,
  category text,
  section text,
  next_review_due_at date,
  days_until_due int,
  last_reviewed_at timestamptz,
  is_overdue boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT a.id, a.slug, a.title, a.category, a.section,
         a.next_review_due_at,
         (a.next_review_due_at - current_date)::int AS days_until_due,
         a.last_reviewed_at,
         (a.next_review_due_at < current_date) AS is_overdue
  FROM public.founder_internal_wiki_articles a
  WHERE a.next_review_due_at IS NOT NULL
    AND a.next_review_due_at <= current_date + 30
  ORDER BY a.next_review_due_at ASC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_internal_wiki_articles_due_review() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_internal_wiki_articles_due_review() TO authenticated;

-- ============================================================================
-- RPC 4 · recent revisions (30)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_internal_wiki_revisions_recent(p_limit int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  article_id uuid,
  article_title text,
  article_slug text,
  version int,
  change_summary text,
  edited_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.article_id, a.title, a.slug, r.version, r.change_summary, r.edited_at
  FROM public.founder_internal_wiki_revisions r
  LEFT JOIN public.founder_internal_wiki_articles a ON a.id = r.article_id
  ORDER BY r.edited_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;
REVOKE ALL ON FUNCTION public.founder_internal_wiki_revisions_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_internal_wiki_revisions_recent(int) TO authenticated;

-- ============================================================================
-- RPC 5 · create article
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_internal_wiki_create_article(
  p_slug text,
  p_title text,
  p_category text,
  p_section text,
  p_content_md text DEFAULT NULL,
  p_tags text[] DEFAULT ARRAY[]::text[],
  p_next_review_due_at date DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  v_uid uuid := auth.uid();
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  INSERT INTO public.founder_internal_wiki_articles
    (slug, title, category, section, content_md, owner_user_id, tags, next_review_due_at)
  VALUES (p_slug, p_title, p_category, p_section, p_content_md, v_uid, p_tags, p_next_review_due_at)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_internal_wiki_revisions
    (article_id, version, change_summary, content_md, edited_by)
  VALUES (v_id, 1, 'initial create', p_content_md, v_uid);

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_internal_wiki_create_article(text,text,text,text,text,text[],date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_internal_wiki_create_article(text,text,text,text,text,text[],date) TO authenticated;

-- ============================================================================
-- RPC 6 · update article (versions++)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_internal_wiki_update_article(
  p_article_id uuid,
  p_title text DEFAULT NULL,
  p_content_md text DEFAULT NULL,
  p_change_summary text DEFAULT NULL,
  p_tags text[] DEFAULT NULL,
  p_next_review_due_at date DEFAULT NULL
) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_new_version int;
  v_uid uuid := auth.uid();
  v_content text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.founder_internal_wiki_articles
    SET title = COALESCE(p_title, title),
        content_md = COALESCE(p_content_md, content_md),
        tags = COALESCE(p_tags, tags),
        next_review_due_at = COALESCE(p_next_review_due_at, next_review_due_at),
        version = version + 1,
        updated_at = now()
  WHERE id = p_article_id
  RETURNING version, content_md INTO v_new_version, v_content;

  IF v_new_version IS NULL THEN
    RAISE EXCEPTION 'article not found' USING ERRCODE='P0002';
  END IF;

  INSERT INTO public.founder_internal_wiki_revisions
    (article_id, version, change_summary, content_md, edited_by)
  VALUES (p_article_id, v_new_version, p_change_summary, v_content, v_uid);

  RETURN v_new_version;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_internal_wiki_update_article(uuid,text,text,text,text[],date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_internal_wiki_update_article(uuid,text,text,text,text[],date) TO authenticated;

-- ============================================================================
-- RPC 7 · publish article (sets is_published + last_reviewed_at)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_founder_internal_wiki_publish(
  p_article_id uuid,
  p_is_published boolean DEFAULT true
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_version int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  UPDATE public.founder_internal_wiki_articles
    SET is_published = p_is_published,
        last_reviewed_at = CASE WHEN p_is_published THEN now() ELSE last_reviewed_at END,
        updated_at = now()
  WHERE id = p_article_id
  RETURNING version INTO v_version;

  IF v_version IS NULL THEN
    RAISE EXCEPTION 'article not found' USING ERRCODE='P0002';
  END IF;

  INSERT INTO public.founder_internal_wiki_revisions
    (article_id, version, change_summary, edited_by)
  VALUES (
    p_article_id,
    v_version,
    CASE WHEN p_is_published THEN 'published' ELSE 'unpublished' END,
    v_uid
  );

  RETURN p_is_published;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_internal_wiki_publish(uuid,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_internal_wiki_publish(uuid,boolean) TO authenticated;

COMMIT;