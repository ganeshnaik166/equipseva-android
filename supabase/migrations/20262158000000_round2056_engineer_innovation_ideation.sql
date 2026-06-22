BEGIN;

-- =====================================================================
-- Round 2056 — Engineer Innovation Ideation
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.engineer_innovation_ideation_r2056 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  idea_label text NOT NULL,
  idea_md text NOT NULL DEFAULT '',
  idea_category text NOT NULL CHECK (idea_category IN ('process_improvement','tool_innovation','safety_improvement','customer_experience','cost_reduction')),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','under_review','adopted','declined','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_innovation_ideation_r2056_engineer_idx
  ON public.engineer_innovation_ideation_r2056(engineer_user_id);
CREATE INDEX IF NOT EXISTS engineer_innovation_ideation_r2056_status_idx
  ON public.engineer_innovation_ideation_r2056(status);
CREATE INDEX IF NOT EXISTS engineer_innovation_ideation_r2056_captured_idx
  ON public.engineer_innovation_ideation_r2056(captured_at DESC);

ALTER TABLE public.engineer_innovation_ideation_r2056 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_innovation_ideation_r2056_founder_all ON public.engineer_innovation_ideation_r2056;
CREATE POLICY engineer_innovation_ideation_r2056_founder_all
  ON public.engineer_innovation_ideation_r2056
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.engineer_innovation_action_log_r2056 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idea_id uuid NOT NULL REFERENCES public.engineer_innovation_ideation_r2056(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reviewed','adopted','piloted','declined','bonused','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_innovation_action_log_r2056_idea_idx
  ON public.engineer_innovation_action_log_r2056(idea_id);
CREATE INDEX IF NOT EXISTS engineer_innovation_action_log_r2056_taken_idx
  ON public.engineer_innovation_action_log_r2056(taken_at DESC);

ALTER TABLE public.engineer_innovation_action_log_r2056 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_innovation_action_log_r2056_founder_all ON public.engineer_innovation_action_log_r2056;
CREATE POLICY engineer_innovation_action_log_r2056_founder_all
  ON public.engineer_innovation_action_log_r2056
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- =====================================================================
-- RPCs
-- =====================================================================

-- 1. list_ideas
CREATE OR REPLACE FUNCTION public.list_innovation_ideas_r2056()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  idea_label text,
  idea_category text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id, p.email, i.idea_label, i.idea_category, i.status, i.captured_at
  FROM public.engineer_innovation_ideation_r2056 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
  ORDER BY i.captured_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_idea
CREATE OR REPLACE FUNCTION public.log_innovation_idea_r2056(
  p_engineer_user_id uuid,
  p_idea_label text,
  p_idea_md text,
  p_idea_category text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_innovation_ideation_r2056(engineer_user_id, idea_label, idea_md, idea_category)
  VALUES (p_engineer_user_id, p_idea_label, COALESCE(p_idea_md,''), p_idea_category)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_innovation_idea_r2056',
    jsonb_build_object('idea_id', v_id, 'engineer', p_engineer_user_id, 'category', p_idea_category));

  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_innovation_actions_r2056(p_idea_id uuid)
RETURNS TABLE(
  id uuid,
  idea_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.idea_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_innovation_action_log_r2056 a
  WHERE a.idea_id = p_idea_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_innovation_action_r2056(
  p_idea_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_innovation_action_log_r2056(idea_id, action_type, by_email, notes_md)
  VALUES (p_idea_id, p_action_type, p_by_email, COALESCE(p_notes_md,''))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_innovation_action_r2056',
    jsonb_build_object('action_id', v_id, 'idea_id', p_idea_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_innovation_status_r2056(
  p_idea_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_innovation_ideation_r2056
    SET status = p_status, updated_at = now()
    WHERE id = p_idea_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_innovation_status_r2056',
    jsonb_build_object('idea_id', p_idea_id, 'status', p_status));
END;
$$;

-- 6. adopted_ideas
CREATE OR REPLACE FUNCTION public.adopted_innovation_ideas_r2056()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  idea_label text,
  idea_category text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id, p.email, i.idea_label, i.idea_category, i.captured_at
  FROM public.engineer_innovation_ideation_r2056 i
  LEFT JOIN public.profiles p ON p.id = i.engineer_user_id
  WHERE i.status = 'adopted'
  ORDER BY i.captured_at DESC
  LIMIT 100;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_innovation_actions_r2056()
RETURNS TABLE(
  id uuid,
  idea_id uuid,
  idea_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.idea_id, i.idea_label, a.action_type, a.taken_at, a.by_email
  FROM public.engineer_innovation_action_log_r2056 a
  LEFT JOIN public.engineer_innovation_ideation_r2056 i ON i.id = a.idea_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

-- =====================================================================
-- GRANTS
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_innovation_ideas_r2056() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_innovation_idea_r2056(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_innovation_actions_r2056(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_innovation_action_r2056(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_innovation_status_r2056(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.adopted_innovation_ideas_r2056() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_innovation_actions_r2056() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_innovation_ideas_r2056() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_innovation_idea_r2056(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_innovation_actions_r2056(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_innovation_action_r2056(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_innovation_status_r2056(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adopted_innovation_ideas_r2056() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_innovation_actions_r2056() TO authenticated;

COMMIT;
