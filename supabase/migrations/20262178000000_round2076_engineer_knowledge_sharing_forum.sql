BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_knowledge_sharing_forum_r2076 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  post_title text NOT NULL,
  post_md text NOT NULL,
  post_category text NOT NULL CHECK (post_category IN ('tip','troubleshooting','safety','customer_story','innovation','question')),
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','draft','archived','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_forum_reaction_log_r2076 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.engineer_knowledge_sharing_forum_r2076(id) ON DELETE CASCADE,
  reactor_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reaction_type text NOT NULL CHECK (reaction_type IN ('helpful','saved','applied','escalation','correction')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_knowledge_sharing_forum_r2076 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_forum_reaction_log_r2076 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_forum_founder_r2076 ON public.engineer_knowledge_sharing_forum_r2076;
CREATE POLICY p_forum_founder_r2076 ON public.engineer_knowledge_sharing_forum_r2076
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_reaction_founder_r2076 ON public.engineer_forum_reaction_log_r2076;
CREATE POLICY p_reaction_founder_r2076 ON public.engineer_forum_reaction_log_r2076
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_posts_r2076()
RETURNS TABLE(id uuid, engineer_user_id uuid, post_title text, post_category text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT f.id, f.engineer_user_id, f.post_title, f.post_category, f.status, f.captured_at
    FROM public.engineer_knowledge_sharing_forum_r2076 f
    ORDER BY f.captured_at DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_post_r2076(
  p_engineer_user_id uuid, p_post_title text, p_post_md text, p_post_category text, p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_knowledge_sharing_forum_r2076(engineer_user_id, post_title, post_md, post_category, status)
    VALUES (p_engineer_user_id, p_post_title, p_post_md, p_post_category, COALESCE(p_status, 'published'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_post_r2076',
      jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'post_title', p_post_title, 'category', p_post_category));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_reactions_r2076(p_post_id uuid)
RETURNS TABLE(id uuid, post_id uuid, reactor_user_id uuid, reaction_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.post_id, r.reactor_user_id, r.reaction_type, r.taken_at, r.by_email, r.notes_md
    FROM public.engineer_forum_reaction_log_r2076 r
    WHERE r.post_id = p_post_id
    ORDER BY r.taken_at DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_reaction_r2076(
  p_post_id uuid, p_reactor_user_id uuid, p_reaction_type text, p_by_email text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_forum_reaction_log_r2076(post_id, reactor_user_id, reaction_type, by_email, notes_md)
    VALUES (p_post_id, p_reactor_user_id, p_reaction_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r2076',
      jsonb_build_object('id', v_id, 'post_id', p_post_id, 'reactor_user_id', p_reactor_user_id, 'reaction_type', p_reaction_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2076(p_post_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_knowledge_sharing_forum_r2076 SET status = p_status, updated_at = now() WHERE id = p_post_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2076',
      jsonb_build_object('post_id', p_post_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.top_posts_r2076()
RETURNS TABLE(post_id uuid, post_title text, post_category text, reaction_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.post_title, f.post_category, COUNT(r.id)::bigint
    FROM public.engineer_knowledge_sharing_forum_r2076 f
    LEFT JOIN public.engineer_forum_reaction_log_r2076 r ON r.post_id = f.id
    WHERE f.status = 'published'
    GROUP BY f.id, f.post_title, f.post_category
    ORDER BY COUNT(r.id) DESC
    LIMIT 50;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_reactions_r2076()
RETURNS TABLE(id uuid, post_id uuid, reactor_user_id uuid, reaction_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT r.id, r.post_id, r.reactor_user_id, r.reaction_type, r.taken_at, r.by_email
    FROM public.engineer_forum_reaction_log_r2076 r
    ORDER BY r.taken_at DESC
    LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_posts_r2076() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_post_r2076(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reactions_r2076(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reaction_r2076(uuid, uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2076(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_posts_r2076() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reactions_r2076() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_posts_r2076() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_post_r2076(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reactions_r2076(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reaction_r2076(uuid, uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2076(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_posts_r2076() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reactions_r2076() TO authenticated;

COMMIT;
