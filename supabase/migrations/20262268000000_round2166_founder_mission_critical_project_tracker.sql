BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_mission_critical_projects_r2166 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_label text NOT NULL,
  criticality text NOT NULL CHECK (criticality IN ('tier_1','tier_2','tier_3')),
  owner_email text,
  target_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','at_risk','critical','completed','abandoned')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_project_action_log_r2166 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.founder_mission_critical_projects_r2166(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('kicked_off','milestone_hit','escalated','completed','abandoned')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_mission_critical_projects_r2166 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_project_action_log_r2166 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_projects_r2166 ON public.founder_mission_critical_projects_r2166;
CREATE POLICY founder_only_projects_r2166 ON public.founder_mission_critical_projects_r2166
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_actions_r2166 ON public.founder_project_action_log_r2166;
CREATE POLICY founder_only_actions_r2166 ON public.founder_project_action_log_r2166
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_proj_r2166_status ON public.founder_mission_critical_projects_r2166(status);
CREATE INDEX IF NOT EXISTS idx_proj_r2166_crit ON public.founder_mission_critical_projects_r2166(criticality);
CREATE INDEX IF NOT EXISTS idx_actions_r2166_proj ON public.founder_project_action_log_r2166(project_id, taken_at DESC);

-- 1) list_projects
DROP FUNCTION IF EXISTS public.r2166_list_projects();
CREATE OR REPLACE FUNCTION public.r2166_list_projects()
RETURNS TABLE (
  id uuid,
  project_label text,
  criticality text,
  owner_email text,
  target_date date,
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
  SELECT p.id, p.project_label, p.criticality, p.owner_email, p.target_date, p.status, p.captured_at
  FROM public.founder_mission_critical_projects_r2166 p
  ORDER BY
    CASE p.criticality WHEN 'tier_1' THEN 1 WHEN 'tier_2' THEN 2 ELSE 3 END,
    p.captured_at DESC
  LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2166_list_projects() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2166_list_projects() TO authenticated;

-- 2) log_project
DROP FUNCTION IF EXISTS public.r2166_log_project(text, text, text, date, text);
CREATE OR REPLACE FUNCTION public.r2166_log_project(
  p_label text,
  p_criticality text,
  p_owner_email text,
  p_target_date date,
  p_status text
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
  INSERT INTO public.founder_mission_critical_projects_r2166 (project_label, criticality, owner_email, target_date, status)
  VALUES (p_label, p_criticality, p_owner_email, p_target_date, COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2166_log_project', jsonb_build_object('id', v_id, 'label', p_label, 'criticality', p_criticality));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2166_log_project(text, text, text, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2166_log_project(text, text, text, date, text) TO authenticated;

-- 3) list_actions
DROP FUNCTION IF EXISTS public.r2166_list_actions(uuid);
CREATE OR REPLACE FUNCTION public.r2166_list_actions(p_project_id uuid)
RETURNS TABLE (
  id uuid,
  project_id uuid,
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
  SELECT a.id, a.project_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_project_action_log_r2166 a
  WHERE a.project_id = p_project_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2166_list_actions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2166_list_actions(uuid) TO authenticated;

-- 4) log_action
DROP FUNCTION IF EXISTS public.r2166_log_action(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r2166_log_action(
  p_project_id uuid,
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
  INSERT INTO public.founder_project_action_log_r2166 (project_id, action_type, by_email, notes_md)
  VALUES (p_project_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2166_log_action', jsonb_build_object('id', v_id, 'project_id', p_project_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2166_log_action(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2166_log_action(uuid, text, text, text) TO authenticated;

-- 5) mark_status
DROP FUNCTION IF EXISTS public.r2166_mark_status(uuid, text);
CREATE OR REPLACE FUNCTION public.r2166_mark_status(p_project_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_mission_critical_projects_r2166
  SET status = p_status, updated_at = now()
  WHERE id = p_project_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2166_mark_status', jsonb_build_object('project_id', p_project_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2166_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2166_mark_status(uuid, text) TO authenticated;

-- 6) tier_1_critical
DROP FUNCTION IF EXISTS public.r2166_tier_1_critical();
CREATE OR REPLACE FUNCTION public.r2166_tier_1_critical()
RETURNS TABLE (
  id uuid,
  project_label text,
  owner_email text,
  status text,
  target_date date,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.project_label, p.owner_email, p.status, p.target_date, p.captured_at
  FROM public.founder_mission_critical_projects_r2166 p
  WHERE p.criticality = 'tier_1'
    AND p.status IN ('active','at_risk','critical')
  ORDER BY p.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2166_tier_1_critical() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2166_tier_1_critical() TO authenticated;

-- 7) recent_actions
DROP FUNCTION IF EXISTS public.r2166_recent_actions(integer);
CREATE OR REPLACE FUNCTION public.r2166_recent_actions(p_limit integer)
RETURNS TABLE (
  id uuid,
  project_id uuid,
  project_label text,
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
  SELECT a.id, a.project_id, p.project_label, a.action_type, a.taken_at, a.by_email
  FROM public.founder_project_action_log_r2166 a
  JOIN public.founder_mission_critical_projects_r2166 p ON p.id = a.project_id
  ORDER BY a.taken_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2166_recent_actions(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2166_recent_actions(integer) TO authenticated;

COMMIT;
