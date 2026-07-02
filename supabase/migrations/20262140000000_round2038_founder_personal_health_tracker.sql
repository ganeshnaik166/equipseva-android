BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_personal_health_tracker_r2038 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  sleep_hours_avg numeric NOT NULL DEFAULT 0,
  exercise_sessions_count int NOT NULL DEFAULT 0,
  stress_score int NOT NULL DEFAULT 0,
  energy_score int NOT NULL DEFAULT 0,
  mood_score int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'balanced' CHECK (status IN ('thriving','balanced','stressed','exhausted')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_health_intervention_log_r2038 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  health_id uuid NOT NULL REFERENCES public.founder_personal_health_tracker_r2038(id) ON DELETE CASCADE,
  intervention_type text NOT NULL CHECK (intervention_type IN ('sleep_priority','exercise_added','meditation','therapy','medical','coaching')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_personal_health_tracker_r2038 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_health_intervention_log_r2038 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_health_r2038 ON public.founder_personal_health_tracker_r2038;
CREATE POLICY founder_all_health_r2038 ON public.founder_personal_health_tracker_r2038
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_interv_r2038 ON public.founder_health_intervention_log_r2038;
CREATE POLICY founder_all_interv_r2038 ON public.founder_health_intervention_log_r2038
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_health_r2038()
RETURNS SETOF public.founder_personal_health_tracker_r2038
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_personal_health_tracker_r2038 ORDER BY captured_at DESC LIMIT 200;
END;$$;

CREATE OR REPLACE FUNCTION public.log_health_r2038(
  p_period_label text,
  p_sleep numeric,
  p_exercise int,
  p_stress int,
  p_energy int,
  p_mood int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_personal_health_tracker_r2038(period_label, sleep_hours_avg, exercise_sessions_count, stress_score, energy_score, mood_score, status)
  VALUES (p_period_label, p_sleep, p_exercise, p_stress, p_energy, p_mood, COALESCE(p_status,'balanced'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_health_r2038', jsonb_build_object('id', v_id, 'period', p_period_label));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.list_interventions_r2038()
RETURNS SETOF public.founder_health_intervention_log_r2038
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_health_intervention_log_r2038 ORDER BY taken_at DESC LIMIT 400;
END;$$;

CREATE OR REPLACE FUNCTION public.log_intervention_r2038(
  p_health_id uuid,
  p_type text,
  p_email text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_health_intervention_log_r2038(health_id, intervention_type, by_email, notes_md)
  VALUES (p_health_id, p_type, p_email, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_intervention_r2038', jsonb_build_object('id', v_id, 'type', p_type));
  RETURN v_id;
END;$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2038(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_personal_health_tracker_r2038 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2038', jsonb_build_object('id', p_id, 'status', p_status));
END;$$;

CREATE OR REPLACE FUNCTION public.current_health_r2038()
RETURNS SETOF public.founder_personal_health_tracker_r2038
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_personal_health_tracker_r2038 ORDER BY captured_at DESC LIMIT 1;
END;$$;

CREATE OR REPLACE FUNCTION public.recent_interventions_r2038()
RETURNS SETOF public.founder_health_intervention_log_r2038
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_health_intervention_log_r2038 WHERE taken_at > now() - interval '30 days' ORDER BY taken_at DESC LIMIT 50;
END;$$;

REVOKE EXECUTE ON FUNCTION public.list_health_r2038() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_health_r2038(text, numeric, int, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_interventions_r2038() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_intervention_r2038(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2038(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_health_r2038() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_interventions_r2038() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_health_r2038() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_health_r2038(text, numeric, int, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_interventions_r2038() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_intervention_r2038(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2038(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_health_r2038() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_interventions_r2038() TO authenticated;

COMMIT;
