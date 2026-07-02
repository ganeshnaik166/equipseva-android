BEGIN;

-- ============================================================================
-- Round 1702: Founder Side-Project Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_side_projects_r1702 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description_md text,
  started_on date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','shipped','killed')),
  weekly_hours_estimate int NOT NULL DEFAULT 0 CHECK (weekly_hours_estimate >= 0),
  lesson_md text,
  killed_on date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_side_project_milestones_r1702 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES public.founder_side_projects_r1702(id) ON DELETE CASCADE,
  milestone_text text NOT NULL,
  hit_on date,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','hit','missed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsp_r1702_status ON public.founder_side_projects_r1702(status);
CREATE INDEX IF NOT EXISTS idx_fspm_r1702_project ON public.founder_side_project_milestones_r1702(project_id);

ALTER TABLE public.founder_side_projects_r1702 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_side_project_milestones_r1702 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fsp_r1702_founder ON public.founder_side_projects_r1702;
CREATE POLICY p_fsp_r1702_founder ON public.founder_side_projects_r1702
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_fspm_r1702_founder ON public.founder_side_project_milestones_r1702;
CREATE POLICY p_fspm_r1702_founder ON public.founder_side_project_milestones_r1702
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_projects
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_side_projects_r1702()
RETURNS TABLE (
  id uuid,
  name text,
  description_md text,
  started_on date,
  status text,
  weekly_hours_estimate int,
  lesson_md text,
  killed_on date,
  milestone_count int,
  hit_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.name,
    p.description_md,
    p.started_on,
    p.status,
    p.weekly_hours_estimate,
    p.lesson_md,
    p.killed_on,
    (SELECT (COUNT(*))::int FROM public.founder_side_project_milestones_r1702 m WHERE m.project_id = p.id),
    (SELECT (COUNT(*))::int FROM public.founder_side_project_milestones_r1702 m WHERE m.project_id = p.id AND m.status = 'hit'),
    p.created_at
  FROM public.founder_side_projects_r1702 p
  ORDER BY p.created_at DESC;
END;
$$;

-- ============================================================================
-- RPC 2: add_project
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_side_project_r1702(
  p_name text,
  p_description_md text,
  p_started_on date,
  p_weekly_hours_estimate int
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
  INSERT INTO public.founder_side_projects_r1702(name, description_md, started_on, weekly_hours_estimate)
  VALUES (p_name, p_description_md, COALESCE(p_started_on, CURRENT_DATE), COALESCE(p_weekly_hours_estimate, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_side_project_r1702',
    jsonb_build_object('id', v_id, 'name', p_name, 'weekly_hours', p_weekly_hours_estimate));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: update_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_side_project_status_r1702(
  p_id uuid,
  p_status text,
  p_lesson_md text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active','paused','shipped','killed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.founder_side_projects_r1702
  SET status = p_status,
      lesson_md = COALESCE(p_lesson_md, lesson_md),
      killed_on = CASE WHEN p_status = 'killed' THEN CURRENT_DATE ELSE killed_on END,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_side_project_status_r1702',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 4: list_milestones
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_side_project_milestones_r1702(
  p_project_id uuid
)
RETURNS TABLE (
  id uuid,
  project_id uuid,
  milestone_text text,
  hit_on date,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.project_id, m.milestone_text, m.hit_on, m.status, m.created_at
  FROM public.founder_side_project_milestones_r1702 m
  WHERE (p_project_id IS NULL OR m.project_id = p_project_id)
  ORDER BY m.created_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 5: add_milestone
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_side_project_milestone_r1702(
  p_project_id uuid,
  p_milestone_text text
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
  INSERT INTO public.founder_side_project_milestones_r1702(project_id, milestone_text)
  VALUES (p_project_id, p_milestone_text)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_side_project_milestone_r1702',
    jsonb_build_object('id', v_id, 'project_id', p_project_id, 'text', p_milestone_text));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 6: hit_milestone
-- ============================================================================
CREATE OR REPLACE FUNCTION public.hit_side_project_milestone_r1702(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('planned','hit','missed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.founder_side_project_milestones_r1702
  SET status = p_status,
      hit_on = CASE WHEN p_status = 'hit' THEN CURRENT_DATE ELSE hit_on END,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hit_side_project_milestone_r1702',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 7: project_summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.side_project_summary_r1702()
RETURNS TABLE (
  total_projects int,
  active_projects int,
  paused_projects int,
  shipped_projects int,
  killed_projects int,
  total_weekly_hours int,
  total_milestones int,
  hit_milestones int,
  missed_milestones int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(*))::int FROM public.founder_side_projects_r1702),
    (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.founder_side_projects_r1702),
    (SELECT (COUNT(*) FILTER (WHERE status = 'paused'))::int FROM public.founder_side_projects_r1702),
    (SELECT (COUNT(*) FILTER (WHERE status = 'shipped'))::int FROM public.founder_side_projects_r1702),
    (SELECT (COUNT(*) FILTER (WHERE status = 'killed'))::int FROM public.founder_side_projects_r1702),
    (SELECT COALESCE(SUM(weekly_hours_estimate), 0)::int FROM public.founder_side_projects_r1702 WHERE status IN ('active','paused')),
    (SELECT (COUNT(*))::int FROM public.founder_side_project_milestones_r1702),
    (SELECT (COUNT(*) FILTER (WHERE status = 'hit'))::int FROM public.founder_side_project_milestones_r1702),
    (SELECT (COUNT(*) FILTER (WHERE status = 'missed'))::int FROM public.founder_side_project_milestones_r1702);
END;
$$;

-- ============================================================================
-- REVOKE + GRANT
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_side_projects_r1702() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_side_project_r1702(text, text, date, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_side_project_status_r1702(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_side_project_milestones_r1702(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_side_project_milestone_r1702(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.hit_side_project_milestone_r1702(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.side_project_summary_r1702() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_side_projects_r1702() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_side_project_r1702(text, text, date, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_side_project_status_r1702(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_side_project_milestones_r1702(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_side_project_milestone_r1702(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hit_side_project_milestone_r1702(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.side_project_summary_r1702() TO authenticated;

COMMIT;