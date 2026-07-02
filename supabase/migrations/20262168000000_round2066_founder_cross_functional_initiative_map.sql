BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_cross_functional_initiative_map_r2066 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  initiative_label text NOT NULL,
  initiative_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planning' CHECK (status IN ('planning','active','blocked','completed','abandoned')),
  expected_completion_date date,
  total_budget_rupees bigint,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_initiative_action_log_r2066 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  initiative_id uuid NOT NULL REFERENCES public.founder_cross_functional_initiative_map_r2066(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('kicked_off','blocker_identified','milestone_hit','escalated','completed','abandoned')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_cross_functional_initiative_map_r2066 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_initiative_action_log_r2066 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_initiative_r2066 ON public.founder_cross_functional_initiative_map_r2066;
CREATE POLICY founder_all_initiative_r2066 ON public.founder_cross_functional_initiative_map_r2066
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2066 ON public.founder_initiative_action_log_r2066;
CREATE POLICY founder_all_action_r2066 ON public.founder_initiative_action_log_r2066
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_initiatives
CREATE OR REPLACE FUNCTION public.list_initiatives_r2066()
RETURNS TABLE (
  id uuid,
  initiative_label text,
  owner_email text,
  status text,
  expected_completion_date date,
  total_budget_rupees bigint,
  captured_at timestamptz
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
  SELECT i.id, i.initiative_label, i.owner_email, i.status,
         i.expected_completion_date, i.total_budget_rupees, i.captured_at
  FROM public.founder_cross_functional_initiative_map_r2066 i
  ORDER BY i.captured_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_initiative
CREATE OR REPLACE FUNCTION public.log_initiative_r2066(
  p_label text,
  p_md text,
  p_owner text,
  p_status text,
  p_expected date,
  p_budget bigint
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
  INSERT INTO public.founder_cross_functional_initiative_map_r2066(
    initiative_label, initiative_md, owner_email, status, expected_completion_date, total_budget_rupees
  ) VALUES (
    p_label, p_md, p_owner, COALESCE(p_status,'planning'), p_expected, p_budget
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_initiative_r2066',
          jsonb_build_object('id', v_id, 'label', p_label, 'status', p_status));
  RETURN v_id;
END;
$$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2066(p_initiative uuid)
RETURNS TABLE (
  id uuid,
  initiative_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.initiative_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_initiative_action_log_r2066 a
  WHERE a.initiative_id = p_initiative
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r2066(
  p_initiative uuid,
  p_action_type text,
  p_by_email text,
  p_notes text
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
  INSERT INTO public.founder_initiative_action_log_r2066(initiative_id, action_type, by_email, notes_md)
  VALUES (p_initiative, p_action_type, p_by_email, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2066',
          jsonb_build_object('id', v_id, 'initiative_id', p_initiative, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2066(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.founder_cross_functional_initiative_map_r2066
  SET status = p_status, updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2066',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- 6. active_initiatives
CREATE OR REPLACE FUNCTION public.active_initiatives_r2066()
RETURNS TABLE (
  id uuid,
  initiative_label text,
  owner_email text,
  status text,
  expected_completion_date date,
  total_budget_rupees bigint
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
  SELECT i.id, i.initiative_label, i.owner_email, i.status,
         i.expected_completion_date, i.total_budget_rupees
  FROM public.founder_cross_functional_initiative_map_r2066 i
  WHERE i.status IN ('planning','active','blocked')
  ORDER BY i.expected_completion_date NULLS LAST
  LIMIT 200;
END;
$$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2066()
RETURNS TABLE (
  id uuid,
  initiative_id uuid,
  initiative_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
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
  SELECT a.id, a.initiative_id, i.initiative_label, a.action_type, a.taken_at, a.by_email
  FROM public.founder_initiative_action_log_r2066 a
  JOIN public.founder_cross_functional_initiative_map_r2066 i ON i.id = a.initiative_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_initiatives_r2066() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_initiative_r2066(text, text, text, text, date, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2066(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2066(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2066(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_initiatives_r2066() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2066() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_initiatives_r2066() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_initiative_r2066(text, text, text, text, date, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2066(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2066(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2066(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_initiatives_r2066() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2066() TO authenticated;

COMMIT;
