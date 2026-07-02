BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_family_time_tracker_r2158 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  planned_family_hours int NOT NULL DEFAULT 0,
  actual_family_hours int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'protected' CHECK (status IN ('protected','honored','short','severely_short')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_family_action_log_r2158 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id uuid NOT NULL REFERENCES public.founder_family_time_tracker_r2158(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('protected','skipped','recovered','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_family_time_tracker_r2158 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_family_action_log_r2158 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2158_periods ON public.founder_family_time_tracker_r2158;
CREATE POLICY founder_all_r2158_periods ON public.founder_family_time_tracker_r2158
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2158_actions ON public.founder_family_action_log_r2158;
CREATE POLICY founder_all_r2158_actions ON public.founder_family_action_log_r2158
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_family_periods_r2158()
RETURNS SETOF public.founder_family_time_tracker_r2158
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_family_time_tracker_r2158 ORDER BY captured_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_family_periods_r2158() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_family_periods_r2158() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_family_period_r2158(p_label text, p_planned int, p_actual int, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_family_time_tracker_r2158(period_label, planned_family_hours, actual_family_hours, status)
  VALUES (p_label, COALESCE(p_planned,0), COALESCE(p_actual,0), COALESCE(p_status,'protected'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_family_period_r2158', jsonb_build_object('id', v_id, 'label', p_label));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_family_period_r2158(text, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_family_period_r2158(text, int, int, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_family_actions_r2158(p_period uuid)
RETURNS SETOF public.founder_family_action_log_r2158
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_family_action_log_r2158 WHERE period_id = p_period ORDER BY taken_at DESC LIMIT 500;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_family_actions_r2158(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_family_actions_r2158(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_family_action_r2158(p_period uuid, p_action text, p_email text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_family_action_log_r2158(period_id, action_type, by_email, notes_md)
  VALUES (p_period, p_action, p_email, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_family_action_r2158', jsonb_build_object('id', v_id, 'period', p_period, 'action', p_action));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_family_action_r2158(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_family_action_r2158(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_family_status_r2158(p_period uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_family_time_tracker_r2158 SET status = p_status, updated_at = now() WHERE id = p_period;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_family_status_r2158', jsonb_build_object('id', p_period, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION public.mark_family_status_r2158(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_family_status_r2158(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.short_family_periods_r2158()
RETURNS SETOF public.founder_family_time_tracker_r2158
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_family_time_tracker_r2158
    WHERE status IN ('short','severely_short') ORDER BY captured_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.short_family_periods_r2158() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.short_family_periods_r2158() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_family_actions_r2158()
RETURNS SETOF public.founder_family_action_log_r2158
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_family_action_log_r2158 ORDER BY taken_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_family_actions_r2158() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_family_actions_r2158() TO authenticated;

COMMIT;
