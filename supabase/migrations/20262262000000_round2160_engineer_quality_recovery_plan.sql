BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.engineer_quality_recovery_plan_r2160 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  recovery_focus text NOT NULL CHECK (recovery_focus IN ('work_quality','safety','customer_handling','documentation')),
  plan_md text NOT NULL,
  target_completion_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','recovering','completed','abandoned','exited')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_recovery_milestone_log_r2160 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.engineer_quality_recovery_plan_r2160(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('assessment','coaching','practice','improvement_demonstrated','recovery_completed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_quality_recovery_plan_r2160 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_recovery_milestone_log_r2160 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_all_plan_r2160 ON public.engineer_quality_recovery_plan_r2160;
CREATE POLICY p_founder_all_plan_r2160 ON public.engineer_quality_recovery_plan_r2160
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_all_milestone_r2160 ON public.engineer_recovery_milestone_log_r2160;
CREATE POLICY p_founder_all_milestone_r2160 ON public.engineer_recovery_milestone_log_r2160
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_plans
CREATE OR REPLACE FUNCTION public.list_recovery_plans_r2160()
RETURNS SETOF public.engineer_quality_recovery_plan_r2160
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_quality_recovery_plan_r2160 ORDER BY captured_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_plans_r2160() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_plans_r2160() TO authenticated;

-- RPC 2: log_plan
CREATE OR REPLACE FUNCTION public.log_recovery_plan_r2160(
  p_engineer_user_id uuid,
  p_recovery_focus text,
  p_plan_md text,
  p_target_completion_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_quality_recovery_plan_r2160(engineer_user_id, recovery_focus, plan_md, target_completion_date)
  VALUES (p_engineer_user_id, p_recovery_focus, p_plan_md, p_target_completion_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_recovery_plan_r2160', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'recovery_focus', p_recovery_focus));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_recovery_plan_r2160(uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_recovery_plan_r2160(uuid, text, text, date) TO authenticated;

-- RPC 3: list_milestones
CREATE OR REPLACE FUNCTION public.list_recovery_milestones_r2160(p_plan_id uuid)
RETURNS SETOF public.engineer_recovery_milestone_log_r2160
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_recovery_milestone_log_r2160 WHERE plan_id = p_plan_id ORDER BY taken_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_milestones_r2160(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_milestones_r2160(uuid) TO authenticated;

-- RPC 4: log_milestone
CREATE OR REPLACE FUNCTION public.log_recovery_milestone_r2160(
  p_plan_id uuid,
  p_milestone_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_recovery_milestone_log_r2160(plan_id, milestone_type, by_email, notes_md)
  VALUES (p_plan_id, p_milestone_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_recovery_milestone_r2160', jsonb_build_object('id', v_id, 'plan_id', p_plan_id, 'milestone_type', p_milestone_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_recovery_milestone_r2160(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_recovery_milestone_r2160(uuid, text, text) TO authenticated;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_recovery_status_r2160(p_plan_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_quality_recovery_plan_r2160 SET status = p_status, updated_at = now() WHERE id = p_plan_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_recovery_status_r2160', jsonb_build_object('plan_id', p_plan_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_recovery_status_r2160(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_recovery_status_r2160(uuid, text) TO authenticated;

-- RPC 6: active_plans
CREATE OR REPLACE FUNCTION public.active_recovery_plans_r2160()
RETURNS SETOF public.engineer_quality_recovery_plan_r2160
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_quality_recovery_plan_r2160 WHERE status IN ('active','recovering') ORDER BY captured_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.active_recovery_plans_r2160() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_recovery_plans_r2160() TO authenticated;

-- RPC 7: recent_milestones
CREATE OR REPLACE FUNCTION public.recent_recovery_milestones_r2160()
RETURNS SETOF public.engineer_recovery_milestone_log_r2160
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_recovery_milestone_log_r2160 ORDER BY taken_at DESC LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_recovery_milestones_r2160() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_recovery_milestones_r2160() TO authenticated;

COMMIT;
