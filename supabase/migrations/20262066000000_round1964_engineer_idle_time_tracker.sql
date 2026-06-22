BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_idle_time_tracker_r1964 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  idle_start_at timestamptz NOT NULL DEFAULT now(),
  idle_end_at timestamptz,
  idle_duration_minutes int,
  idle_reason text NOT NULL CHECK (idle_reason IN ('between_jobs','no_assignments','sick','training','personal_leave','transport')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed','disputed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_idle_action_log_r1964 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idle_id uuid NOT NULL REFERENCES public.engineer_idle_time_tracker_r1964(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('job_assigned','break_taken','training_started','leave_requested','transport_resolved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eitt_r1964_engineer ON public.engineer_idle_time_tracker_r1964(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eitt_r1964_status ON public.engineer_idle_time_tracker_r1964(status);
CREATE INDEX IF NOT EXISTS idx_eitt_r1964_start ON public.engineer_idle_time_tracker_r1964(idle_start_at DESC);
CREATE INDEX IF NOT EXISTS idx_eial_r1964_idle ON public.engineer_idle_action_log_r1964(idle_id);
CREATE INDEX IF NOT EXISTS idx_eial_r1964_taken ON public.engineer_idle_action_log_r1964(taken_at DESC);

ALTER TABLE public.engineer_idle_time_tracker_r1964 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_idle_action_log_r1964 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eitt_r1964_founder_all ON public.engineer_idle_time_tracker_r1964;
CREATE POLICY eitt_r1964_founder_all ON public.engineer_idle_time_tracker_r1964
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS eial_r1964_founder_all ON public.engineer_idle_action_log_r1964;
CREATE POLICY eial_r1964_founder_all ON public.engineer_idle_action_log_r1964
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_idles_r1964(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, engineer_user_id uuid, idle_start_at timestamptz, idle_end_at timestamptz, idle_duration_minutes int, idle_reason text, status text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_user_id, t.idle_start_at, t.idle_end_at, t.idle_duration_minutes, t.idle_reason, t.status, t.created_at
  FROM public.engineer_idle_time_tracker_r1964 t
  ORDER BY t.idle_start_at DESC
  LIMIT COALESCE(p_limit, 100);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_idle_r1964(p_engineer uuid, p_reason text, p_start timestamptz DEFAULT now())
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_idle_time_tracker_r1964(engineer_user_id, idle_reason, idle_start_at)
  VALUES (p_engineer, p_reason, p_start)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_idle_r1964', jsonb_build_object('id', v_id, 'engineer', p_engineer, 'reason', p_reason));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1964(p_idle uuid)
RETURNS TABLE(id uuid, idle_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.idle_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_idle_action_log_r1964 a
  WHERE a.idle_id = p_idle
  ORDER BY a.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1964(p_idle uuid, p_action text, p_email text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_idle_action_log_r1964(idle_id, action_type, by_email, notes_md)
  VALUES (p_idle, p_action, p_email, p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1964', jsonb_build_object('id', v_id, 'idle', p_idle, 'action', p_action));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1964(p_idle uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_idle_time_tracker_r1964
  SET status = p_status,
      idle_end_at = CASE WHEN p_status = 'closed' THEN COALESCE(idle_end_at, now()) ELSE idle_end_at END,
      idle_duration_minutes = CASE WHEN p_status = 'closed' THEN EXTRACT(EPOCH FROM (COALESCE(idle_end_at, now()) - idle_start_at))::int / 60 ELSE idle_duration_minutes END,
      updated_at = now()
  WHERE id = p_idle;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1964', jsonb_build_object('id', p_idle, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.current_idles_r1964()
RETURNS TABLE(id uuid, engineer_user_id uuid, idle_start_at timestamptz, idle_reason text, minutes_idle int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_user_id, t.idle_start_at, t.idle_reason,
         (EXTRACT(EPOCH FROM (now() - t.idle_start_at))::int / 60)
  FROM public.engineer_idle_time_tracker_r1964 t
  WHERE t.status = 'active'
  ORDER BY t.idle_start_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1964(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, idle_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.idle_id, a.action_type, a.taken_at, a.by_email
  FROM public.engineer_idle_action_log_r1964 a
  ORDER BY a.taken_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_idles_r1964(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_idle_r1964(uuid, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1964(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1964(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1964(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_idles_r1964() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1964(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_idles_r1964(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_idle_r1964(uuid, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1964(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1964(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1964(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_idles_r1964() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1964(int) TO authenticated;

COMMIT;
