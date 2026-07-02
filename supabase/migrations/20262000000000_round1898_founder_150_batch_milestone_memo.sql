BEGIN;

-- =========================================================================
-- Round 1898: Founder 150-Batch Milestone Memo
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_150_batch_memo_r1898 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL DEFAULT '',
  top_lessons_md text NOT NULL DEFAULT '',
  top_patterns_md text NOT NULL DEFAULT '',
  founder_note_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_150_batch_reactions_r1898 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_150_batch_memo_r1898(id) ON DELETE CASCADE,
  reactor_email text NOT NULL,
  reactor_role text NOT NULL CHECK (reactor_role IN ('team','investor','customer','external_observer')),
  reaction_md text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_f150_memo_r1898_status ON public.founder_150_batch_memo_r1898(status, written_at DESC);
CREATE INDEX IF NOT EXISTS idx_f150_react_r1898_memo ON public.founder_150_batch_reactions_r1898(memo_id, recorded_at DESC);

ALTER TABLE public.founder_150_batch_memo_r1898 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_150_batch_reactions_r1898 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS f150_memo_r1898_founder_all ON public.founder_150_batch_memo_r1898;
CREATE POLICY f150_memo_r1898_founder_all ON public.founder_150_batch_memo_r1898
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS f150_react_r1898_founder_all ON public.founder_150_batch_reactions_r1898;
CREATE POLICY f150_react_r1898_founder_all ON public.founder_150_batch_reactions_r1898
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS public.list_memos_r1898();
CREATE OR REPLACE FUNCTION public.list_memos_r1898()
RETURNS TABLE (
  id uuid,
  milestone_label text,
  written_at timestamptz,
  status text,
  summary_md text,
  reaction_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.milestone_label, m.written_at, m.status, m.summary_md,
    (SELECT COUNT(*) FROM public.founder_150_batch_reactions_r1898 r WHERE r.memo_id = m.id)::int
  FROM public.founder_150_batch_memo_r1898 m
  ORDER BY m.written_at DESC
  LIMIT 100;
END;
$$;

DROP FUNCTION IF EXISTS public.draft_memo_r1898(text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.draft_memo_r1898(
  p_label text,
  p_summary text,
  p_lessons text,
  p_patterns text,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_150_batch_memo_r1898(milestone_label, summary_md, top_lessons_md, top_patterns_md, founder_note_md, status)
  VALUES (p_label, COALESCE(p_summary,''), COALESCE(p_lessons,''), COALESCE(p_patterns,''), COALESCE(p_note,''), 'published')
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'draft_memo_r1898', jsonb_build_object('memo_id', v_id, 'label', p_label));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_reactions_r1898(uuid);
CREATE OR REPLACE FUNCTION public.list_reactions_r1898(p_memo_id uuid)
RETURNS TABLE (
  id uuid,
  reactor_email text,
  reactor_role text,
  reaction_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
  FROM public.founder_150_batch_reactions_r1898 r
  WHERE r.memo_id = p_memo_id
  ORDER BY r.recorded_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.add_reaction_r1898(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.add_reaction_r1898(
  p_memo_id uuid,
  p_email text,
  p_role text,
  p_reaction text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_150_batch_reactions_r1898(memo_id, reactor_email, reactor_role, reaction_md)
  VALUES (p_memo_id, p_email, p_role, COALESCE(p_reaction,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_reaction_r1898', jsonb_build_object('memo_id', p_memo_id, 'reactor', p_email, 'role', p_role));
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.publish_memo_r1898(uuid);
CREATE OR REPLACE FUNCTION public.publish_memo_r1898(p_memo_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_150_batch_memo_r1898
  SET status = 'published', updated_at = now()
  WHERE id = p_memo_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'publish_memo_r1898', jsonb_build_object('memo_id', p_memo_id));
END;
$$;

DROP FUNCTION IF EXISTS public.recent_reactions_r1898();
CREATE OR REPLACE FUNCTION public.recent_reactions_r1898()
RETURNS TABLE (
  id uuid,
  memo_id uuid,
  milestone_label text,
  reactor_email text,
  reactor_role text,
  reaction_md text,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.memo_id, m.milestone_label, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
  FROM public.founder_150_batch_reactions_r1898 r
  JOIN public.founder_150_batch_memo_r1898 m ON m.id = r.memo_id
  ORDER BY r.recorded_at DESC
  LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS public.top_lessons_r1898();
CREATE OR REPLACE FUNCTION public.top_lessons_r1898()
RETURNS TABLE (
  id uuid,
  milestone_label text,
  written_at timestamptz,
  top_lessons_md text,
  top_patterns_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.milestone_label, m.written_at, m.top_lessons_md, m.top_patterns_md
  FROM public.founder_150_batch_memo_r1898 m
  WHERE m.status = 'published'
  ORDER BY m.written_at DESC
  LIMIT 20;
END;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_memos_r1898() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_memo_r1898(text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reactions_r1898(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_reaction_r1898(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.publish_memo_r1898(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reactions_r1898() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_lessons_r1898() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_memos_r1898() TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_memo_r1898(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reactions_r1898(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_reaction_r1898(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_memo_r1898(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reactions_r1898() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_lessons_r1898() TO authenticated;

COMMIT;
