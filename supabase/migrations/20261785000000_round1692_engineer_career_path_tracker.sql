BEGIN;

-- =========================================================================
-- Round 1692: Engineer Career Path Tracker
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_career_paths_r1692 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL,
  target_role text NOT NULL,
  target_date date,
  plan_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','paused','achieved','dropped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_career_milestones_r1692 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  path_id uuid NOT NULL REFERENCES public.engineer_career_paths_r1692(id) ON DELETE CASCADE,
  milestone_text text NOT NULL,
  due_date date,
  completed_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','missed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_career_paths_r1692_eng ON public.engineer_career_paths_r1692(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_career_paths_r1692_status ON public.engineer_career_paths_r1692(status);
CREATE INDEX IF NOT EXISTS idx_career_paths_r1692_target ON public.engineer_career_paths_r1692(target_date);
CREATE INDEX IF NOT EXISTS idx_career_milestones_r1692_path ON public.engineer_career_milestones_r1692(path_id);
CREATE INDEX IF NOT EXISTS idx_career_milestones_r1692_due ON public.engineer_career_milestones_r1692(due_date);
CREATE INDEX IF NOT EXISTS idx_career_milestones_r1692_status ON public.engineer_career_milestones_r1692(status);

ALTER TABLE public.engineer_career_paths_r1692 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_career_milestones_r1692 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_career_paths_r1692 ON public.engineer_career_paths_r1692;
CREATE POLICY founder_all_career_paths_r1692 ON public.engineer_career_paths_r1692
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_career_milestones_r1692 ON public.engineer_career_milestones_r1692;
CREATE POLICY founder_all_career_milestones_r1692 ON public.engineer_career_milestones_r1692
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_paths_r1692
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_paths_r1692()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  target_role text,
  target_date date,
  status text,
  days_to_target int,
  milestones_total int,
  milestones_done int,
  milestones_missed int,
  progress_pct numeric,
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
    p.engineer_user_id,
    pr.email AS engineer_email,
    p.target_role,
    p.target_date,
    p.status,
    CASE WHEN p.target_date IS NOT NULL THEN (p.target_date - CURRENT_DATE)::int ELSE NULL END AS days_to_target,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id) AS milestones_total,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'done') AS milestones_done,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'missed') AS milestones_missed,
    CASE
      WHEN (SELECT COUNT(*) FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id) > 0
      THEN ROUND(((SELECT COUNT(*) FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'done')::numeric /
                  (SELECT COUNT(*) FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id)) * 100, 1)
      ELSE 0
    END AS progress_pct,
    p.created_at
  FROM public.engineer_career_paths_r1692 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  ORDER BY p.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_paths_r1692() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_paths_r1692() TO authenticated;

-- =========================================================================
-- RPC 2: set_path_r1692
-- =========================================================================
CREATE OR REPLACE FUNCTION public.set_path_r1692(
  p_engineer_user_id uuid,
  p_target_role text,
  p_target_date date,
  p_plan_md text,
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
  IF p_status IS NOT NULL AND p_status NOT IN ('active','paused','achieved','dropped') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  INSERT INTO public.engineer_career_paths_r1692(engineer_user_id, target_role, target_date, plan_md, status)
  VALUES (p_engineer_user_id, p_target_role, p_target_date, COALESCE(p_plan_md, ''), COALESCE(p_status, 'active'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'set_path_r1692',
          jsonb_build_object('path_id', v_id, 'engineer_user_id', p_engineer_user_id, 'target_role', p_target_role, 'status', COALESCE(p_status, 'active')));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_path_r1692(uuid, text, date, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_path_r1692(uuid, text, date, text, text) TO authenticated;

-- =========================================================================
-- RPC 3: list_milestones_r1692
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_milestones_r1692(p_path_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  path_id uuid,
  target_role text,
  engineer_user_id uuid,
  milestone_text text,
  due_date date,
  completed_at timestamptz,
  status text,
  days_to_due int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    m.id,
    m.path_id,
    p.target_role,
    p.engineer_user_id,
    m.milestone_text,
    m.due_date,
    m.completed_at,
    m.status,
    CASE WHEN m.due_date IS NOT NULL THEN (m.due_date - CURRENT_DATE)::int ELSE NULL END AS days_to_due
  FROM public.engineer_career_milestones_r1692 m
  JOIN public.engineer_career_paths_r1692 p ON p.id = m.path_id
  WHERE p_path_id IS NULL OR m.path_id = p_path_id
  ORDER BY COALESCE(m.due_date, CURRENT_DATE + interval '999 days') ASC, m.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_milestones_r1692(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_milestones_r1692(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: add_milestone_r1692
-- =========================================================================
CREATE OR REPLACE FUNCTION public.add_milestone_r1692(
  p_path_id uuid,
  p_milestone_text text,
  p_due_date date
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

  INSERT INTO public.engineer_career_milestones_r1692(path_id, milestone_text, due_date, status)
  VALUES (p_path_id, p_milestone_text, p_due_date, 'pending')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_milestone_r1692',
          jsonb_build_object('milestone_id', v_id, 'path_id', p_path_id, 'milestone_text', p_milestone_text, 'due_date', p_due_date));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_milestone_r1692(uuid, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_milestone_r1692(uuid, text, date) TO authenticated;

-- =========================================================================
-- RPC 5: complete_milestone_r1692
-- =========================================================================
CREATE OR REPLACE FUNCTION public.complete_milestone_r1692(
  p_milestone_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','done','missed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.engineer_career_milestones_r1692
  SET status = p_status,
      completed_at = CASE WHEN p_status = 'done' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_milestone_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_milestone_r1692',
          jsonb_build_object('milestone_id', p_milestone_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.complete_milestone_r1692(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_milestone_r1692(uuid, text) TO authenticated;

-- =========================================================================
-- RPC 6: paths_in_jeopardy_r1692
-- =========================================================================
CREATE OR REPLACE FUNCTION public.paths_in_jeopardy_r1692()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  target_role text,
  target_date date,
  days_to_target int,
  milestones_total int,
  milestones_done int,
  milestones_overdue int,
  progress_pct numeric,
  jeopardy_reason text
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
    p.engineer_user_id,
    pr.email AS engineer_email,
    p.target_role,
    p.target_date,
    CASE WHEN p.target_date IS NOT NULL THEN (p.target_date - CURRENT_DATE)::int ELSE NULL END AS days_to_target,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id) AS milestones_total,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'done') AS milestones_done,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'pending' AND m.due_date < CURRENT_DATE) AS milestones_overdue,
    CASE
      WHEN (SELECT COUNT(*) FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id) > 0
      THEN ROUND(((SELECT COUNT(*) FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'done')::numeric /
                  (SELECT COUNT(*) FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id)) * 100, 1)
      ELSE 0
    END AS progress_pct,
    CASE
      WHEN p.target_date IS NOT NULL AND p.target_date < CURRENT_DATE THEN 'target date passed'
      WHEN (SELECT COUNT(*) FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'pending' AND m.due_date < CURRENT_DATE) > 0 THEN 'milestones overdue'
      WHEN p.target_date IS NOT NULL AND (p.target_date - CURRENT_DATE) < 30 THEN 'target within 30 days'
      ELSE 'low progress'
    END AS jeopardy_reason
  FROM public.engineer_career_paths_r1692 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.status = 'active'
    AND (
      (p.target_date IS NOT NULL AND p.target_date < CURRENT_DATE + interval '30 days')
      OR EXISTS (SELECT 1 FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'pending' AND m.due_date < CURRENT_DATE)
    )
  ORDER BY p.target_date ASC NULLS LAST
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.paths_in_jeopardy_r1692() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.paths_in_jeopardy_r1692() TO authenticated;

-- =========================================================================
-- RPC 7: achievers_recent_r1692
-- =========================================================================
CREATE OR REPLACE FUNCTION public.achievers_recent_r1692()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  target_role text,
  target_date date,
  achieved_at timestamptz,
  milestones_total int,
  milestones_done int
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
    p.engineer_user_id,
    pr.email AS engineer_email,
    p.target_role,
    p.target_date,
    p.updated_at AS achieved_at,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id) AS milestones_total,
    (SELECT (COUNT(*))::int FROM public.engineer_career_milestones_r1692 m WHERE m.path_id = p.id AND m.status = 'done') AS milestones_done
  FROM public.engineer_career_paths_r1692 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.status = 'achieved'
    AND p.updated_at >= now() - interval '180 days'
  ORDER BY p.updated_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.achievers_recent_r1692() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.achievers_recent_r1692() TO authenticated;

COMMIT;