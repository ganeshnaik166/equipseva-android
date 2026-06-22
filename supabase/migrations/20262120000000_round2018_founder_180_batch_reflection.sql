BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_180_batch_reflection_r2018 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_label text NOT NULL,
  reflection_md text NOT NULL,
  top_wins_md text,
  top_misses_md text,
  founder_takeaways_md text,
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('published','archived')),
  written_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_180_batch_reaction_r2018 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reflection_id uuid NOT NULL REFERENCES public.founder_180_batch_reflection_r2018(id) ON DELETE CASCADE,
  reactor_email text NOT NULL,
  reactor_role text NOT NULL CHECK (reactor_role IN ('team','investor','customer','external_observer')),
  reaction_md text NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_180_batch_reflection_r2018 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_180_batch_reaction_r2018 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_reflection_r2018 ON public.founder_180_batch_reflection_r2018;
CREATE POLICY founder_all_reflection_r2018 ON public.founder_180_batch_reflection_r2018
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_reaction_r2018 ON public.founder_180_batch_reaction_r2018;
CREATE POLICY founder_all_reaction_r2018 ON public.founder_180_batch_reaction_r2018
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_reflections_r2018()
RETURNS TABLE (
  id uuid,
  milestone_label text,
  reflection_md text,
  top_wins_md text,
  top_misses_md text,
  founder_takeaways_md text,
  status text,
  written_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.milestone_label, r.reflection_md, r.top_wins_md, r.top_misses_md, r.founder_takeaways_md, r.status, r.written_at
    FROM public.founder_180_batch_reflection_r2018 r
    ORDER BY r.written_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reflection_r2018(
  p_milestone_label text,
  p_reflection_md text,
  p_top_wins_md text,
  p_top_misses_md text,
  p_founder_takeaways_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_180_batch_reflection_r2018 (milestone_label, reflection_md, top_wins_md, top_misses_md, founder_takeaways_md)
  VALUES (p_milestone_label, p_reflection_md, p_top_wins_md, p_top_misses_md, p_founder_takeaways_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reflection_r2018', jsonb_build_object('id', v_id, 'milestone_label', p_milestone_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_reactions_r2018(p_reflection_id uuid)
RETURNS TABLE (
  id uuid,
  reflection_id uuid,
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
    SELECT a.id, a.reflection_id, a.reactor_email, a.reactor_role, a.reaction_md, a.recorded_at
    FROM public.founder_180_batch_reaction_r2018 a
    WHERE a.reflection_id = p_reflection_id
    ORDER BY a.recorded_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_reaction_r2018(
  p_reflection_id uuid,
  p_reactor_email text,
  p_reactor_role text,
  p_reaction_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_180_batch_reaction_r2018 (reflection_id, reactor_email, reactor_role, reaction_md)
  VALUES (p_reflection_id, p_reactor_email, p_reactor_role, p_reaction_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reaction_r2018', jsonb_build_object('id', v_id, 'reflection_id', p_reflection_id, 'reactor_email', p_reactor_email));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2018(p_reflection_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('published','archived') THEN RAISE EXCEPTION 'invalid status'; END IF;
  UPDATE public.founder_180_batch_reflection_r2018 SET status = p_status, updated_at = now() WHERE id = p_reflection_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2018', jsonb_build_object('id', p_reflection_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_reactions_r2018()
RETURNS TABLE (
  id uuid,
  reflection_id uuid,
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
    SELECT a.id, a.reflection_id, r.milestone_label, a.reactor_email, a.reactor_role, a.reaction_md, a.recorded_at
    FROM public.founder_180_batch_reaction_r2018 a
    JOIN public.founder_180_batch_reflection_r2018 r ON r.id = a.reflection_id
    ORDER BY a.recorded_at DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_takeaways_r2018()
RETURNS TABLE (
  id uuid,
  milestone_label text,
  founder_takeaways_md text,
  written_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.milestone_label, r.founder_takeaways_md, r.written_at
    FROM public.founder_180_batch_reflection_r2018 r
    WHERE r.status = 'published' AND r.founder_takeaways_md IS NOT NULL
    ORDER BY r.written_at DESC
    LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reflections_r2018() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reflection_r2018(text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reactions_r2018(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reaction_r2018(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2018(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_reactions_r2018() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_takeaways_r2018() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reflections_r2018() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reflection_r2018(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reactions_r2018(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reaction_r2018(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2018(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_reactions_r2018() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_takeaways_r2018() TO authenticated;

COMMIT;
