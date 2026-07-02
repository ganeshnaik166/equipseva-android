BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_vision_memos_r1682 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text UNIQUE NOT NULL,
  headline text NOT NULL,
  body_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_vision_memo_feedback_r1682 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_vision_memos_r1682(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  feedback_md text NOT NULL DEFAULT '',
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative')),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fvm_r1682_status ON public.founder_vision_memos_r1682(status);
CREATE INDEX IF NOT EXISTS idx_fvmf_r1682_memo ON public.founder_vision_memo_feedback_r1682(memo_id);

ALTER TABLE public.founder_vision_memos_r1682 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_vision_memo_feedback_r1682 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fvm_r1682_founder_all ON public.founder_vision_memos_r1682;
CREATE POLICY fvm_r1682_founder_all ON public.founder_vision_memos_r1682
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fvmf_r1682_founder_all ON public.founder_vision_memo_feedback_r1682;
CREATE POLICY fvmf_r1682_founder_all ON public.founder_vision_memo_feedback_r1682
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1) list_memos
CREATE OR REPLACE FUNCTION public.r1682_list_memos()
RETURNS TABLE (
  id uuid,
  quarter text,
  headline text,
  status text,
  published_at timestamptz,
  feedback_count int,
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
  SELECT
    m.id,
    m.quarter,
    m.headline,
    m.status,
    m.published_at,
    (SELECT COUNT(*) FROM public.founder_vision_memo_feedback_r1682 f WHERE f.memo_id = m.id)::int AS feedback_count,
    m.created_at
  FROM public.founder_vision_memos_r1682 m
  ORDER BY m.created_at DESC;
END;
$$;

-- 2) draft_memo
CREATE OR REPLACE FUNCTION public.r1682_draft_memo(
  p_quarter text,
  p_headline text,
  p_body_md text
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
  INSERT INTO public.founder_vision_memos_r1682(quarter, headline, body_md, status)
  VALUES (p_quarter, p_headline, COALESCE(p_body_md,''), 'draft')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1682_draft_memo',
    jsonb_build_object('memo_id', v_id, 'quarter', p_quarter, 'headline', p_headline));

  RETURN v_id;
END;
$$;

-- 3) publish_memo
CREATE OR REPLACE FUNCTION public.r1682_publish_memo(p_memo_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_vision_memos_r1682
     SET status='published', published_at = now(), updated_at = now()
   WHERE id = p_memo_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1682_publish_memo',
    jsonb_build_object('memo_id', p_memo_id));
END;
$$;

-- 4) archive_memo
CREATE OR REPLACE FUNCTION public.r1682_archive_memo(p_memo_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_vision_memos_r1682
     SET status='archived', updated_at = now()
   WHERE id = p_memo_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1682_archive_memo',
    jsonb_build_object('memo_id', p_memo_id));
END;
$$;

-- 5) list_feedback
CREATE OR REPLACE FUNCTION public.r1682_list_feedback(p_memo_id uuid)
RETURNS TABLE (
  id uuid,
  memo_id uuid,
  reviewer_email text,
  feedback_md text,
  sentiment text,
  submitted_at timestamptz
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
  SELECT f.id, f.memo_id, f.reviewer_email, f.feedback_md, f.sentiment, f.submitted_at
    FROM public.founder_vision_memo_feedback_r1682 f
   WHERE (p_memo_id IS NULL OR f.memo_id = p_memo_id)
   ORDER BY f.submitted_at DESC;
END;
$$;

-- 6) record_feedback
CREATE OR REPLACE FUNCTION public.r1682_record_feedback(
  p_memo_id uuid,
  p_reviewer_email text,
  p_feedback_md text,
  p_sentiment text
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
  INSERT INTO public.founder_vision_memo_feedback_r1682(memo_id, reviewer_email, feedback_md, sentiment)
  VALUES (p_memo_id, p_reviewer_email, COALESCE(p_feedback_md,''), p_sentiment)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1682_record_feedback',
    jsonb_build_object('feedback_id', v_id, 'memo_id', p_memo_id, 'sentiment', p_sentiment));

  RETURN v_id;
END;
$$;

-- 7) feedback_summary_per_memo
CREATE OR REPLACE FUNCTION public.r1682_feedback_summary_per_memo()
RETURNS TABLE (
  memo_id uuid,
  quarter text,
  headline text,
  status text,
  total_feedback int,
  positive_count int,
  neutral_count int,
  negative_count int
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
    m.id AS memo_id,
    m.quarter,
    m.headline,
    m.status,
    (COUNT(f.id))::int AS total_feedback,
    (COUNT(*) FILTER (WHERE f.sentiment='positive'))::int AS positive_count,
    (COUNT(*) FILTER (WHERE f.sentiment='neutral'))::int AS neutral_count,
    (COUNT(*) FILTER (WHERE f.sentiment='negative'))::int AS negative_count
  FROM public.founder_vision_memos_r1682 m
  LEFT JOIN public.founder_vision_memo_feedback_r1682 f ON f.memo_id = m.id
  GROUP BY m.id, m.quarter, m.headline, m.status
  ORDER BY m.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1682_list_memos() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1682_draft_memo(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1682_publish_memo(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1682_archive_memo(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1682_list_feedback(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1682_record_feedback(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1682_feedback_summary_per_memo() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1682_list_memos() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1682_draft_memo(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1682_publish_memo(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1682_archive_memo(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1682_list_feedback(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1682_record_feedback(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1682_feedback_summary_per_memo() TO authenticated;

COMMIT;