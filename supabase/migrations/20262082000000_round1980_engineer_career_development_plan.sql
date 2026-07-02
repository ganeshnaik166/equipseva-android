BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_career_dev_plans_r1980 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  career_track text NOT NULL CHECK (career_track IN ('tech_lead','specialty_master','regional_supervisor','customer_lead','exit_to_other')),
  target_role text NOT NULL,
  target_completion_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','on_hold','completed','abandoned')),
  started_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_career_milestone_log_r1980 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.engineer_career_dev_plans_r1980(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('skill_acquired','cert_earned','leadership_role','customer_recognition','exit_planned')),
  milestone_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_career_plans_r1980_engineer ON public.engineer_career_dev_plans_r1980(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_career_plans_r1980_track ON public.engineer_career_dev_plans_r1980(career_track);
CREATE INDEX IF NOT EXISTS idx_career_plans_r1980_status ON public.engineer_career_dev_plans_r1980(status);
CREATE INDEX IF NOT EXISTS idx_career_ms_r1980_plan ON public.engineer_career_milestone_log_r1980(plan_id);
CREATE INDEX IF NOT EXISTS idx_career_ms_r1980_at ON public.engineer_career_milestone_log_r1980(milestone_at DESC);

ALTER TABLE public.engineer_career_dev_plans_r1980 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_career_milestone_log_r1980 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_career_plans_r1980_founder ON public.engineer_career_dev_plans_r1980;
CREATE POLICY p_career_plans_r1980_founder ON public.engineer_career_dev_plans_r1980
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_career_ms_r1980_founder ON public.engineer_career_milestone_log_r1980;
CREATE POLICY p_career_ms_r1980_founder ON public.engineer_career_milestone_log_r1980
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_career_plans_r1980()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  career_track text,
  target_role text,
  target_completion_date date,
  status text,
  started_at timestamptz
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
  SELECT p.id, p.engineer_user_id, pr.email, p.career_track, p.target_role,
         p.target_completion_date, p.status, p.started_at
  FROM public.engineer_career_dev_plans_r1980 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  ORDER BY p.started_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_career_plan_r1980(
  p_engineer_user_id uuid,
  p_career_track text,
  p_target_role text,
  p_target_completion_date date
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
  INSERT INTO public.engineer_career_dev_plans_r1980(engineer_user_id, career_track, target_role, target_completion_date)
  VALUES (p_engineer_user_id, p_career_track, p_target_role, p_target_completion_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_career_plan_r1980',
          jsonb_build_object('plan_id', v_id, 'engineer_user_id', p_engineer_user_id, 'track', p_career_track));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_career_milestones_r1980(p_plan_id uuid)
RETURNS TABLE (
  id uuid,
  plan_id uuid,
  milestone_type text,
  milestone_at timestamptz,
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
  SELECT m.id, m.plan_id, m.milestone_type, m.milestone_at, m.by_email, m.notes_md
  FROM public.engineer_career_milestone_log_r1980 m
  WHERE m.plan_id = p_plan_id
  ORDER BY m.milestone_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_career_milestone_r1980(
  p_plan_id uuid,
  p_milestone_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.engineer_career_milestone_log_r1980(plan_id, milestone_type, by_email, notes_md)
  VALUES (p_plan_id, p_milestone_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_career_milestone_r1980',
          jsonb_build_object('milestone_id', v_id, 'plan_id', p_plan_id, 'type', p_milestone_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_career_plan_status_r1980(
  p_plan_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.engineer_career_dev_plans_r1980
     SET status = p_status, updated_at = now()
   WHERE id = p_plan_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_career_plan_status_r1980',
          jsonb_build_object('plan_id', p_plan_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.career_plans_by_track_r1980()
RETURNS TABLE (
  career_track text,
  total bigint,
  active_count bigint,
  completed_count bigint
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
  SELECT p.career_track,
         COUNT(*)::bigint AS total,
         COUNT(*) FILTER (WHERE p.status = 'active')::bigint AS active_count,
         COUNT(*) FILTER (WHERE p.status = 'completed')::bigint AS completed_count
  FROM public.engineer_career_dev_plans_r1980 p
  GROUP BY p.career_track
  ORDER BY total DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_career_milestones_r1980()
RETURNS TABLE (
  id uuid,
  plan_id uuid,
  engineer_email text,
  career_track text,
  milestone_type text,
  milestone_at timestamptz,
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
  SELECT m.id, m.plan_id, pr.email, p.career_track, m.milestone_type, m.milestone_at, m.notes_md
  FROM public.engineer_career_milestone_log_r1980 m
  JOIN public.engineer_career_dev_plans_r1980 p ON p.id = m.plan_id
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  ORDER BY m.milestone_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_career_plans_r1980() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_career_plan_r1980(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_career_milestones_r1980(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_career_milestone_r1980(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_career_plan_status_r1980(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.career_plans_by_track_r1980() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_career_milestones_r1980() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_career_plans_r1980() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_career_plan_r1980(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_career_milestones_r1980(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_career_milestone_r1980(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_career_plan_status_r1980(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.career_plans_by_track_r1980() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_career_milestones_r1980() TO authenticated;

COMMIT;
