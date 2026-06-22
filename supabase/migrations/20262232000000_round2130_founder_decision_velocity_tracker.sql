BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_decision_velocity_tracker_r2130 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_label text NOT NULL,
  decisions_made int NOT NULL DEFAULT 0,
  avg_decision_hours numeric NOT NULL DEFAULT 0,
  fastest_decision_hours numeric NOT NULL DEFAULT 0,
  slowest_decision_hours numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('fast','normal','slow','concerning')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_velocity_action_log_r2130 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  velocity_id uuid NOT NULL REFERENCES public.founder_decision_velocity_tracker_r2130(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','coached','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_decision_velocity_tracker_r2130 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_velocity_action_log_r2130 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_velocity_r2130 ON public.founder_decision_velocity_tracker_r2130;
CREATE POLICY founder_all_velocity_r2130 ON public.founder_decision_velocity_tracker_r2130
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_velocity_actions_r2130 ON public.founder_velocity_action_log_r2130;
CREATE POLICY founder_all_velocity_actions_r2130 ON public.founder_velocity_action_log_r2130
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_velocities_r2130()
RETURNS SETOF public.founder_decision_velocity_tracker_r2130
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_decision_velocity_tracker_r2130 ORDER BY captured_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_velocity_r2130(
  p_week_label text,
  p_decisions_made int,
  p_avg_decision_hours numeric,
  p_fastest_decision_hours numeric,
  p_slowest_decision_hours numeric,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_decision_velocity_tracker_r2130(week_label, decisions_made, avg_decision_hours, fastest_decision_hours, slowest_decision_hours, status)
  VALUES (p_week_label, p_decisions_made, p_avg_decision_hours, p_fastest_decision_hours, p_slowest_decision_hours, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_velocity_r2130', jsonb_build_object('id', v_id, 'week_label', p_week_label));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_velocity_actions_r2130(p_velocity_id uuid)
RETURNS SETOF public.founder_velocity_action_log_r2130
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_velocity_action_log_r2130 WHERE velocity_id = p_velocity_id ORDER BY taken_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.log_velocity_action_r2130(
  p_velocity_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_velocity_action_log_r2130(velocity_id, action_type, by_email, notes_md)
  VALUES (p_velocity_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_velocity_action_r2130', jsonb_build_object('id', v_id, 'velocity_id', p_velocity_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_velocity_status_r2130(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_decision_velocity_tracker_r2130 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_velocity_status_r2130', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.fast_velocity_weeks_r2130()
RETURNS SETOF public.founder_decision_velocity_tracker_r2130
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_decision_velocity_tracker_r2130 WHERE status = 'fast' ORDER BY captured_at DESC LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_velocity_actions_r2130()
RETURNS SETOF public.founder_velocity_action_log_r2130
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_velocity_action_log_r2130 ORDER BY taken_at DESC LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_velocities_r2130() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_velocity_r2130(text, int, numeric, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_velocity_actions_r2130(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_velocity_action_r2130(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_velocity_status_r2130(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fast_velocity_weeks_r2130() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_velocity_actions_r2130() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_velocities_r2130() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_velocity_r2130(text, int, numeric, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_velocity_actions_r2130(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_velocity_action_r2130(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_velocity_status_r2130(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fast_velocity_weeks_r2130() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_velocity_actions_r2130() TO authenticated;

COMMIT;
