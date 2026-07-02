BEGIN;

-- Engineer Cross-Training Roadmap (r1912)

CREATE TABLE IF NOT EXISTS public.engineer_cross_training_roadmap_r1912 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  target_skill text NOT NULL,
  baseline_level text NOT NULL CHECK (baseline_level IN ('none','beginner','intermediate','advanced','expert')),
  current_level text NOT NULL CHECK (current_level IN ('none','beginner','intermediate','advanced','expert')),
  target_completion_date date,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','blocked','completed','abandoned')),
  started_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_training_milestone_log_r1912 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  roadmap_id uuid NOT NULL REFERENCES public.engineer_cross_training_roadmap_r1912(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('assessment','practical','certification','peer_review')),
  milestone_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  score int,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_cross_training_roadmap_r1912 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_training_milestone_log_r1912 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1912_roadmap ON public.engineer_cross_training_roadmap_r1912;
CREATE POLICY founder_all_r1912_roadmap ON public.engineer_cross_training_roadmap_r1912
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1912_milestone ON public.engineer_training_milestone_log_r1912;
CREATE POLICY founder_all_r1912_milestone ON public.engineer_training_milestone_log_r1912
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_roadmaps
CREATE OR REPLACE FUNCTION public.list_roadmaps_r1912()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  target_skill text,
  baseline_level text,
  current_level text,
  target_completion_date date,
  status text,
  started_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, p.email::text, r.target_skill,
         r.baseline_level, r.current_level, r.target_completion_date,
         r.status, r.started_at, r.created_at
  FROM public.engineer_cross_training_roadmap_r1912 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY r.created_at DESC
  LIMIT 200;
END $$;

-- RPC 2: log_roadmap
CREATE OR REPLACE FUNCTION public.log_roadmap_r1912(
  p_engineer_user_id uuid,
  p_target_skill text,
  p_baseline_level text,
  p_current_level text,
  p_target_completion_date date,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_cross_training_roadmap_r1912
    (engineer_user_id, target_skill, baseline_level, current_level, target_completion_date, status, started_at)
  VALUES
    (p_engineer_user_id, p_target_skill, p_baseline_level, p_current_level, p_target_completion_date, p_status,
     CASE WHEN p_status = 'in_progress' THEN now() ELSE NULL END)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_roadmap_r1912',
    jsonb_build_object('roadmap_id', v_id, 'engineer_user_id', p_engineer_user_id, 'target_skill', p_target_skill));
  RETURN v_id;
END $$;

-- RPC 3: list_milestones
CREATE OR REPLACE FUNCTION public.list_milestones_r1912(p_roadmap_id uuid)
RETURNS TABLE (
  id uuid,
  roadmap_id uuid,
  milestone_type text,
  milestone_at timestamptz,
  by_email text,
  score int,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.roadmap_id, m.milestone_type, m.milestone_at, m.by_email, m.score, m.notes_md
  FROM public.engineer_training_milestone_log_r1912 m
  WHERE m.roadmap_id = p_roadmap_id
  ORDER BY m.milestone_at DESC
  LIMIT 200;
END $$;

-- RPC 4: log_milestone
CREATE OR REPLACE FUNCTION public.log_milestone_r1912(
  p_roadmap_id uuid,
  p_milestone_type text,
  p_by_email text,
  p_score int,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_training_milestone_log_r1912
    (roadmap_id, milestone_type, by_email, score, notes_md)
  VALUES
    (p_roadmap_id, p_milestone_type, p_by_email, p_score, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_milestone_r1912',
    jsonb_build_object('milestone_id', v_id, 'roadmap_id', p_roadmap_id, 'type', p_milestone_type, 'score', p_score));
  RETURN v_id;
END $$;

-- RPC 5: mark_completed
CREATE OR REPLACE FUNCTION public.mark_completed_r1912(p_roadmap_id uuid, p_final_level text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_cross_training_roadmap_r1912
     SET status = 'completed',
         current_level = p_final_level,
         updated_at = now()
   WHERE id = p_roadmap_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_completed_r1912',
    jsonb_build_object('roadmap_id', p_roadmap_id, 'final_level', p_final_level));
END $$;

-- RPC 6: engineers_blocked
CREATE OR REPLACE FUNCTION public.engineers_blocked_r1912()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  blocked_count int,
  in_progress_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.engineer_user_id,
         p.email::text,
         (COUNT(*) FILTER (WHERE r.status = 'blocked'))::int AS blocked_count,
         (COUNT(*) FILTER (WHERE r.status = 'in_progress'))::int AS in_progress_count
  FROM public.engineer_cross_training_roadmap_r1912 r
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  GROUP BY r.engineer_user_id, p.email
  HAVING (COUNT(*) FILTER (WHERE r.status = 'blocked'))::int > 0
  ORDER BY blocked_count DESC
  LIMIT 100;
END $$;

-- RPC 7: recent_milestones
CREATE OR REPLACE FUNCTION public.recent_milestones_r1912()
RETURNS TABLE (
  id uuid,
  roadmap_id uuid,
  engineer_email text,
  target_skill text,
  milestone_type text,
  milestone_at timestamptz,
  score int,
  by_email text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.roadmap_id, p.email::text, r.target_skill,
         m.milestone_type, m.milestone_at, m.score, m.by_email
  FROM public.engineer_training_milestone_log_r1912 m
  JOIN public.engineer_cross_training_roadmap_r1912 r ON r.id = m.roadmap_id
  LEFT JOIN public.profiles p ON p.id = r.engineer_user_id
  ORDER BY m.milestone_at DESC
  LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_roadmaps_r1912() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_roadmap_r1912(uuid, text, text, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_milestones_r1912(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_milestone_r1912(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_completed_r1912(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.engineers_blocked_r1912() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_milestones_r1912() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_roadmaps_r1912() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_roadmap_r1912(uuid, text, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_milestones_r1912(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_milestone_r1912(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_completed_r1912(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.engineers_blocked_r1912() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_milestones_r1912() TO authenticated;

COMMIT;
