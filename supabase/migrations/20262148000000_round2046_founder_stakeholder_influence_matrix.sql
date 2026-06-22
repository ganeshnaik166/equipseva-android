BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_stakeholder_influence_matrix_r2046 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stakeholder_name text NOT NULL,
  stakeholder_type text NOT NULL CHECK (stakeholder_type IN ('investor','board','customer','team','regulator','partner')),
  influence_level int NOT NULL CHECK (influence_level BETWEEN 1 AND 10),
  interest_level int NOT NULL CHECK (interest_level BETWEEN 1 AND 10),
  current_attitude text NOT NULL CHECK (current_attitude IN ('supportive','neutral','concerned','blocking')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dormant','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_stakeholder_action_log_r2046 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stakeholder_id uuid NOT NULL REFERENCES public.founder_stakeholder_influence_matrix_r2046(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engagement_held','concern_addressed','escalated','lost','win_back')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_stakeholder_influence_matrix_r2046 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_stakeholder_action_log_r2046 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_matrix_r2046 ON public.founder_stakeholder_influence_matrix_r2046;
CREATE POLICY founder_all_matrix_r2046 ON public.founder_stakeholder_influence_matrix_r2046
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2046 ON public.founder_stakeholder_action_log_r2046;
CREATE POLICY founder_all_action_r2046 ON public.founder_stakeholder_action_log_r2046
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_stakeholders_r2046()
RETURNS TABLE (
  id uuid,
  stakeholder_name text,
  stakeholder_type text,
  influence_level int,
  interest_level int,
  current_attitude text,
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
  SELECT m.id, m.stakeholder_name, m.stakeholder_type, m.influence_level,
         m.interest_level, m.current_attitude, m.status, m.captured_at
  FROM public.founder_stakeholder_influence_matrix_r2046 m
  ORDER BY m.influence_level DESC, m.captured_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_stakeholder_r2046(
  p_name text,
  p_type text,
  p_influence int,
  p_interest int,
  p_attitude text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_stakeholder_influence_matrix_r2046(
    stakeholder_name, stakeholder_type, influence_level, interest_level, current_attitude
  ) VALUES (p_name, p_type, p_influence, p_interest, p_attitude)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_stakeholder_r2046',
          jsonb_build_object('id', v_id, 'name', p_name, 'type', p_type, 'influence', p_influence));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2046(p_stakeholder_id uuid)
RETURNS TABLE (
  id uuid,
  stakeholder_id uuid,
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
  SELECT a.id, a.stakeholder_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_stakeholder_action_log_r2046 a
  WHERE a.stakeholder_id = p_stakeholder_id
  ORDER BY a.taken_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2046(
  p_stakeholder_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_stakeholder_action_log_r2046(stakeholder_id, action_type, by_email, notes_md)
  VALUES (p_stakeholder_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2046',
          jsonb_build_object('id', v_id, 'stakeholder_id', p_stakeholder_id, 'action', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2046(
  p_stakeholder_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_stakeholder_influence_matrix_r2046
     SET status = p_status, updated_at = now()
   WHERE id = p_stakeholder_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2046',
          jsonb_build_object('id', p_stakeholder_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.high_influence_r2046()
RETURNS TABLE (
  id uuid,
  stakeholder_name text,
  stakeholder_type text,
  influence_level int,
  interest_level int,
  current_attitude text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.stakeholder_name, m.stakeholder_type, m.influence_level,
         m.interest_level, m.current_attitude, m.status
  FROM public.founder_stakeholder_influence_matrix_r2046 m
  WHERE m.influence_level >= 7 AND m.status = 'active'
  ORDER BY m.influence_level DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2046()
RETURNS TABLE (
  id uuid,
  stakeholder_id uuid,
  stakeholder_name text,
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
  SELECT a.id, a.stakeholder_id, m.stakeholder_name, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_stakeholder_action_log_r2046 a
  LEFT JOIN public.founder_stakeholder_influence_matrix_r2046 m ON m.id = a.stakeholder_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_stakeholders_r2046() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_stakeholder_r2046(text, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2046(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2046(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2046(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_influence_r2046() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2046() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_stakeholders_r2046() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_stakeholder_r2046(text, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2046(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2046(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2046(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_influence_r2046() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2046() TO authenticated;

COMMIT;
