BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_220_batch_milestone_memo_r2178 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  written_at timestamptz NOT NULL DEFAULT now(),
  summary_md text NOT NULL DEFAULT '',
  top_lessons_md text NOT NULL DEFAULT '',
  next_500_plan_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_220_reaction_log_r2178 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id uuid NOT NULL REFERENCES public.founder_220_batch_milestone_memo_r2178(id) ON DELETE CASCADE,
  reactor_email text NOT NULL,
  reactor_role text NOT NULL CHECK (reactor_role IN ('team','investor','customer','external_observer','founder_self')),
  reaction_md text NOT NULL DEFAULT '',
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_220_batch_milestone_memo_r2178 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_220_reaction_log_r2178 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_memo_r2178 ON public.founder_220_batch_milestone_memo_r2178;
CREATE POLICY founder_all_memo_r2178 ON public.founder_220_batch_milestone_memo_r2178
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_reaction_r2178 ON public.founder_220_reaction_log_r2178;
CREATE POLICY founder_all_reaction_r2178 ON public.founder_220_reaction_log_r2178
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- list_memos
DROP FUNCTION IF EXISTS public.list_memos_r2178();
CREATE OR REPLACE FUNCTION public.list_memos_r2178()
RETURNS TABLE(id uuid, milestone_label text, written_at timestamptz, summary_md text, top_lessons_md text, next_500_plan_md text, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.milestone_label, m.written_at, m.summary_md, m.top_lessons_md, m.next_500_plan_md, m.status
    FROM public.founder_220_batch_milestone_memo_r2178 m
    ORDER BY m.written_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_memos_r2178() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_memos_r2178() TO authenticated;

-- log_memo
DROP FUNCTION IF EXISTS public.log_memo_r2178(text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_memo_r2178(p_label text, p_summary text, p_lessons text, p_next text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_220_batch_milestone_memo_r2178(milestone_label, summary_md, top_lessons_md, next_500_plan_md)
  VALUES (p_label, COALESCE(p_summary,''), COALESCE(p_lessons,''), COALESCE(p_next,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_memo_r2178', jsonb_build_object('id', v_id, 'label', p_label));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_memo_r2178(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_memo_r2178(text, text, text, text) TO authenticated;

-- list_reactions
DROP FUNCTION IF EXISTS public.list_reactions_r2178(uuid);
CREATE OR REPLACE FUNCTION public.list_reactions_r2178(p_memo_id uuid)
RETURNS TABLE(id uuid, memo_id uuid, reactor_email text, reactor_role text, reaction_md text, recorded_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.memo_id, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
    FROM public.founder_220_reaction_log_r2178 r
    WHERE r.memo_id = p_memo_id
    ORDER BY r.recorded_at DESC
    LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_reactions_r2178(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reactions_r2178(uuid) TO authenticated;

-- log_reaction
DROP FUNCTION IF EXISTS public.log_reaction_r2178(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_reaction_r2178(p_memo_id uuid, p_email text, p_role text, p_md text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_220_reaction_log_r2178(memo_id, reactor_email, reactor_role, reaction_md)
  VALUES (p_memo_id, p_email, p_role, COALESCE(p_md,''))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r2178', jsonb_build_object('id', v_id, 'memo_id', p_memo_id, 'role', p_role));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_reaction_r2178(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_reaction_r2178(uuid, text, text, text) TO authenticated;

-- mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2178(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2178(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('published','archived') THEN RAISE EXCEPTION 'bad status'; END IF;
  UPDATE public.founder_220_batch_milestone_memo_r2178 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2178', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2178(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2178(uuid, text) TO authenticated;

-- recent_reactions
DROP FUNCTION IF EXISTS public.recent_reactions_r2178();
CREATE OR REPLACE FUNCTION public.recent_reactions_r2178()
RETURNS TABLE(id uuid, memo_id uuid, reactor_email text, reactor_role text, reaction_md text, recorded_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.memo_id, r.reactor_email, r.reactor_role, r.reaction_md, r.recorded_at
    FROM public.founder_220_reaction_log_r2178 r
    ORDER BY r.recorded_at DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_reactions_r2178() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_reactions_r2178() TO authenticated;

-- top_reactions (by role)
DROP FUNCTION IF EXISTS public.top_reactions_r2178();
CREATE OR REPLACE FUNCTION public.top_reactions_r2178()
RETURNS TABLE(reactor_role text, reaction_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.reactor_role, COUNT(*)::bigint AS reaction_count
    FROM public.founder_220_reaction_log_r2178 r
    GROUP BY r.reactor_role
    ORDER BY reaction_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_reactions_r2178() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reactions_r2178() TO authenticated;

COMMIT;
