BEGIN;

-- ============================================================================
-- Round 1878: Founder Memo Library
-- Bezos-style internal narrative memos library
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_memo_library_r1878 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_title text NOT NULL,
  memo_category text NOT NULL CHECK (memo_category IN ('strategy','operations','people','process','customer','financial')),
  memo_md text NOT NULL,
  drafted_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','under_review','published','archived')),
  reading_time_minutes int NOT NULL DEFAULT 5,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_memo_reviews_r1878 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_memo_library_r1878(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('looks_good','needs_revision','critical_concern')),
  decision_note text,
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_memo_lib_r1878_status ON public.founder_memo_library_r1878(status);
CREATE INDEX IF NOT EXISTS idx_memo_lib_r1878_category ON public.founder_memo_library_r1878(memo_category);
CREATE INDEX IF NOT EXISTS idx_memo_lib_r1878_drafted_at ON public.founder_memo_library_r1878(drafted_at DESC);
CREATE INDEX IF NOT EXISTS idx_memo_reviews_r1878_memo_id ON public.founder_memo_reviews_r1878(memo_id);
CREATE INDEX IF NOT EXISTS idx_memo_reviews_r1878_at ON public.founder_memo_reviews_r1878(at DESC);

ALTER TABLE public.founder_memo_library_r1878 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_memo_reviews_r1878 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_memo_lib_r1878 ON public.founder_memo_library_r1878;
CREATE POLICY founder_only_memo_lib_r1878 ON public.founder_memo_library_r1878
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_memo_reviews_r1878 ON public.founder_memo_reviews_r1878;
CREATE POLICY founder_only_memo_reviews_r1878 ON public.founder_memo_reviews_r1878
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_memos
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_memos_r1878();
CREATE OR REPLACE FUNCTION public.list_memos_r1878()
RETURNS TABLE (
  id uuid,
  memo_title text,
  memo_category text,
  status text,
  reading_time_minutes int,
  drafted_at timestamptz,
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
  SELECT m.id, m.memo_title, m.memo_category, m.status, m.reading_time_minutes, m.drafted_at, m.published_at
  FROM public.founder_memo_library_r1878 m
  ORDER BY m.drafted_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: draft_memo
-- ============================================================================
DROP FUNCTION IF EXISTS public.draft_memo_r1878(text, text, text, int);
CREATE OR REPLACE FUNCTION public.draft_memo_r1878(
  p_title text,
  p_category text,
  p_md text,
  p_reading_time int
)
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
  INSERT INTO public.founder_memo_library_r1878(memo_title, memo_category, memo_md, reading_time_minutes, status)
  VALUES (p_title, p_category, p_md, COALESCE(p_reading_time, 5), 'draft')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'draft_memo_r1878',
    jsonb_build_object('memo_id', v_id, 'title', p_title, 'category', p_category));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_reviews
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_reviews_r1878(uuid);
CREATE OR REPLACE FUNCTION public.list_reviews_r1878(p_memo_id uuid)
RETURNS TABLE (
  id uuid,
  memo_id uuid,
  reviewer_email text,
  decision text,
  decision_note text,
  at timestamptz
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
  SELECT r.id, r.memo_id, r.reviewer_email, r.decision, r.decision_note, r.at
  FROM public.founder_memo_reviews_r1878 r
  WHERE (p_memo_id IS NULL OR r.memo_id = p_memo_id)
  ORDER BY r.at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: add_review
-- ============================================================================
DROP FUNCTION IF EXISTS public.add_review_r1878(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.add_review_r1878(
  p_memo_id uuid,
  p_reviewer_email text,
  p_decision text,
  p_decision_note text
)
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
  INSERT INTO public.founder_memo_reviews_r1878(memo_id, reviewer_email, decision, decision_note)
  VALUES (p_memo_id, p_reviewer_email, p_decision, p_decision_note)
  RETURNING id INTO v_id;

  UPDATE public.founder_memo_library_r1878
     SET status = 'under_review', updated_at = now()
   WHERE id = p_memo_id AND status = 'draft';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_review_r1878',
    jsonb_build_object('review_id', v_id, 'memo_id', p_memo_id, 'decision', p_decision));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: publish_memo
-- ============================================================================
DROP FUNCTION IF EXISTS public.publish_memo_r1878(uuid);
CREATE OR REPLACE FUNCTION public.publish_memo_r1878(p_memo_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_memo_library_r1878
     SET status = 'published', published_at = now(), updated_at = now()
   WHERE id = p_memo_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'publish_memo_r1878',
    jsonb_build_object('memo_id', p_memo_id));
END;
$$;

-- ============================================================================
-- RPC 6: top_categories
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_categories_r1878();
CREATE OR REPLACE FUNCTION public.top_categories_r1878()
RETURNS TABLE (
  memo_category text,
  memo_count int,
  published_count int,
  avg_reading_time numeric
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
    m.memo_category,
    COUNT(*)::int AS memo_count,
    (COUNT(*) FILTER (WHERE m.status = 'published'))::int AS published_count,
    ROUND(AVG(m.reading_time_minutes)::numeric, 1) AS avg_reading_time
  FROM public.founder_memo_library_r1878 m
  GROUP BY m.memo_category
  ORDER BY memo_count DESC;
END;
$$;

-- ============================================================================
-- RPC 7: recent_published
-- ============================================================================
DROP FUNCTION IF EXISTS public.recent_published_r1878();
CREATE OR REPLACE FUNCTION public.recent_published_r1878()
RETURNS TABLE (
  id uuid,
  memo_title text,
  memo_category text,
  reading_time_minutes int,
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
  SELECT m.id, m.memo_title, m.memo_category, m.reading_time_minutes, m.published_at
  FROM public.founder_memo_library_r1878 m
  WHERE m.status = 'published' AND m.published_at IS NOT NULL
  ORDER BY m.published_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- REVOKE + GRANT
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_memos_r1878() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_memo_r1878(text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r1878(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_review_r1878(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_memo_r1878(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_categories_r1878() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_published_r1878() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_memos_r1878() TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_memo_r1878(text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1878(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_review_r1878(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_memo_r1878(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_categories_r1878() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_published_r1878() TO authenticated;

COMMIT;