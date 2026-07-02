BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_quality_improvement_plan_v2_r2184 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id),
  improvement_focus text NOT NULL CHECK (improvement_focus IN ('safety','quality','customer','teamwork','documentation')),
  baseline_score int NOT NULL,
  target_score int NOT NULL,
  current_score int NOT NULL,
  status text NOT NULL CHECK (status IN ('active','improving','blocked','completed','abandoned')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_qip_v2_milestone_log_r2184 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES public.engineer_quality_improvement_plan_v2_r2184(id) ON DELETE CASCADE,
  milestone_type text NOT NULL CHECK (milestone_type IN ('assessment','training_completed','practice','improvement_shown','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  score int,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_quality_improvement_plan_v2_r2184 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_qip_v2_milestone_log_r2184 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS qip_v2_r2184_founder_all ON public.engineer_quality_improvement_plan_v2_r2184;
CREATE POLICY qip_v2_r2184_founder_all ON public.engineer_quality_improvement_plan_v2_r2184
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS qip_v2_milestone_r2184_founder_all ON public.engineer_qip_v2_milestone_log_r2184;
CREATE POLICY qip_v2_milestone_r2184_founder_all ON public.engineer_qip_v2_milestone_log_r2184
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP FUNCTION IF EXISTS public.list_qip_v2_plans_r2184();
CREATE FUNCTION public.list_qip_v2_plans_r2184()
RETURNS TABLE(id uuid, engineer_user_id uuid, improvement_focus text, baseline_score int, target_score int, current_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.engineer_user_id, p.improvement_focus, p.baseline_score, p.target_score, p.current_score, p.status, p.captured_at
    FROM public.engineer_quality_improvement_plan_v2_r2184 p ORDER BY p.captured_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_qip_v2_plans_r2184() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_qip_v2_plans_r2184() TO authenticated;

DROP FUNCTION IF EXISTS public.log_qip_v2_plan_r2184(uuid, text, int, int, int, text);
CREATE FUNCTION public.log_qip_v2_plan_r2184(p_engineer_user_id uuid, p_focus text, p_baseline int, p_target int, p_current int, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_quality_improvement_plan_v2_r2184(engineer_user_id, improvement_focus, baseline_score, target_score, current_score, status)
    VALUES (p_engineer_user_id, p_focus, p_baseline, p_target, p_current, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_qip_v2_plan_r2184', jsonb_build_object('id', v_id, 'engineer', p_engineer_user_id, 'focus', p_focus));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_qip_v2_plan_r2184(uuid, text, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_qip_v2_plan_r2184(uuid, text, int, int, int, text) TO authenticated;

DROP FUNCTION IF EXISTS public.list_qip_v2_milestones_r2184(uuid);
CREATE FUNCTION public.list_qip_v2_milestones_r2184(p_plan_id uuid)
RETURNS TABLE(id uuid, plan_id uuid, milestone_type text, taken_at timestamptz, by_email text, score int, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.id, m.plan_id, m.milestone_type, m.taken_at, m.by_email, m.score, m.notes_md
    FROM public.engineer_qip_v2_milestone_log_r2184 m WHERE m.plan_id = p_plan_id ORDER BY m.taken_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_qip_v2_milestones_r2184(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_qip_v2_milestones_r2184(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_qip_v2_milestone_r2184(uuid, text, int, text);
CREATE FUNCTION public.log_qip_v2_milestone_r2184(p_plan_id uuid, p_type text, p_score int, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_qip_v2_milestone_log_r2184(plan_id, milestone_type, by_email, score, notes_md)
    VALUES (p_plan_id, p_type, (auth.jwt()->>'email'), p_score, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_qip_v2_milestone_r2184', jsonb_build_object('id', v_id, 'plan_id', p_plan_id, 'type', p_type));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_qip_v2_milestone_r2184(uuid, text, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_qip_v2_milestone_r2184(uuid, text, int, text) TO authenticated;

DROP FUNCTION IF EXISTS public.mark_qip_v2_status_r2184(uuid, text);
CREATE FUNCTION public.mark_qip_v2_status_r2184(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_quality_improvement_plan_v2_r2184 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_qip_v2_status_r2184', jsonb_build_object('id', p_id, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION public.mark_qip_v2_status_r2184(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_qip_v2_status_r2184(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.active_qip_v2_plans_r2184();
CREATE FUNCTION public.active_qip_v2_plans_r2184()
RETURNS TABLE(id uuid, engineer_user_id uuid, improvement_focus text, current_score int, target_score int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.engineer_user_id, p.improvement_focus, p.current_score, p.target_score, p.status, p.captured_at
    FROM public.engineer_quality_improvement_plan_v2_r2184 p
    WHERE p.status IN ('active','improving','blocked') ORDER BY p.captured_at DESC LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.active_qip_v2_plans_r2184() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.active_qip_v2_plans_r2184() TO authenticated;

DROP FUNCTION IF EXISTS public.recent_qip_v2_milestones_r2184();
CREATE FUNCTION public.recent_qip_v2_milestones_r2184()
RETURNS TABLE(id uuid, plan_id uuid, milestone_type text, taken_at timestamptz, by_email text, score int, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT m.id, m.plan_id, m.milestone_type, m.taken_at, m.by_email, m.score, m.notes_md
    FROM public.engineer_qip_v2_milestone_log_r2184 m ORDER BY m.taken_at DESC LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_qip_v2_milestones_r2184() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_qip_v2_milestones_r2184() TO authenticated;

COMMIT;
