BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_calendar_buffer_tracker_r2174 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_label text NOT NULL,
  scheduled_buffer_hours numeric NOT NULL DEFAULT 0,
  actual_buffer_hours numeric NOT NULL DEFAULT 0,
  buffer_protection_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'protected' CHECK (status IN ('protected','honored','short','none')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_buffer_action_log_r2174 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id uuid NOT NULL REFERENCES public.founder_calendar_buffer_tracker_r2174(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('meeting_killed','protected','lost','recovered','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_calendar_buffer_tracker_r2174 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_buffer_action_log_r2174 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_buffer_r2174 ON public.founder_calendar_buffer_tracker_r2174;
CREATE POLICY founder_all_buffer_r2174 ON public.founder_calendar_buffer_tracker_r2174
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_buffer_action_r2174 ON public.founder_buffer_action_log_r2174;
CREATE POLICY founder_all_buffer_action_r2174 ON public.founder_buffer_action_log_r2174
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- list_periods
CREATE OR REPLACE FUNCTION public.list_periods_r2174()
RETURNS SETOF public.founder_calendar_buffer_tracker_r2174
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_calendar_buffer_tracker_r2174 ORDER BY captured_at DESC LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_periods_r2174() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_periods_r2174() TO authenticated;

-- log_period
CREATE OR REPLACE FUNCTION public.log_period_r2174(
  p_week_label text,
  p_scheduled_buffer_hours numeric,
  p_actual_buffer_hours numeric,
  p_buffer_protection_pct numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_calendar_buffer_tracker_r2174(week_label, scheduled_buffer_hours, actual_buffer_hours, buffer_protection_pct, status)
    VALUES (p_week_label, p_scheduled_buffer_hours, p_actual_buffer_hours, p_buffer_protection_pct, p_status)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_period_r2174', jsonb_build_object('id', v_id, 'week_label', p_week_label, 'status', p_status));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_period_r2174(text, numeric, numeric, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_period_r2174(text, numeric, numeric, numeric, text) TO authenticated;

-- list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2174(p_period_id uuid)
RETURNS SETOF public.founder_buffer_action_log_r2174
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_buffer_action_log_r2174 WHERE period_id = p_period_id ORDER BY taken_at DESC LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2174(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2174(uuid) TO authenticated;

-- log_action
CREATE OR REPLACE FUNCTION public.log_action_r2174(
  p_period_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_buffer_action_log_r2174(period_id, action_type, by_email, notes_md)
    VALUES (p_period_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2174', jsonb_build_object('id', v_id, 'period_id', p_period_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2174(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2174(uuid, text, text, text) TO authenticated;

-- mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2174(p_period_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_calendar_buffer_tracker_r2174 SET status = p_status, updated_at = now() WHERE id = p_period_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2174', jsonb_build_object('id', p_period_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2174(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2174(uuid, text) TO authenticated;

-- short_periods
CREATE OR REPLACE FUNCTION public.short_periods_r2174()
RETURNS SETOF public.founder_calendar_buffer_tracker_r2174
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_calendar_buffer_tracker_r2174 WHERE status IN ('short','none') ORDER BY captured_at DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.short_periods_r2174() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.short_periods_r2174() TO authenticated;

-- recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2174()
RETURNS SETOF public.founder_buffer_action_log_r2174
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_buffer_action_log_r2174 ORDER BY taken_at DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2174() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2174() TO authenticated;

COMMIT;
