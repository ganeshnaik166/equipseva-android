BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_tool_calibration_schedule_r2128 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tool_label text NOT NULL,
  last_calibration_at timestamptz,
  next_calibration_due_at timestamptz,
  status text NOT NULL CHECK (status IN ('current','due_soon','overdue','calibrating','retired')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_calibration_action_log_r2128 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.engineer_tool_calibration_schedule_r2128(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('calibrated','scheduled','overdue','retired','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  cost_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_tool_calibration_schedule_r2128 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_calibration_action_log_r2128 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_schedule_r2128 ON public.engineer_tool_calibration_schedule_r2128;
CREATE POLICY founder_all_schedule_r2128 ON public.engineer_tool_calibration_schedule_r2128
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2128 ON public.engineer_calibration_action_log_r2128;
CREATE POLICY founder_all_action_log_r2128 ON public.engineer_calibration_action_log_r2128
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_schedules
CREATE OR REPLACE FUNCTION public.list_schedules_r2128()
RETURNS TABLE(id uuid, engineer_user_id uuid, tool_label text, last_calibration_at timestamptz, next_calibration_due_at timestamptz, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, s.tool_label, s.last_calibration_at, s.next_calibration_due_at, s.status, s.captured_at
  FROM public.engineer_tool_calibration_schedule_r2128 s
  ORDER BY s.next_calibration_due_at ASC NULLS LAST
  LIMIT 200;
END; $$;

-- 2. log_schedule
CREATE OR REPLACE FUNCTION public.log_schedule_r2128(p_engineer_user_id uuid, p_tool_label text, p_last_calibration_at timestamptz, p_next_calibration_due_at timestamptz, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_tool_calibration_schedule_r2128(engineer_user_id, tool_label, last_calibration_at, next_calibration_due_at, status)
  VALUES (p_engineer_user_id, p_tool_label, p_last_calibration_at, p_next_calibration_due_at, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_schedule_r2128', jsonb_build_object('id', v_id, 'tool_label', p_tool_label, 'status', p_status));
  RETURN v_id;
END; $$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_actions_r2128(p_schedule_id uuid)
RETURNS TABLE(id uuid, schedule_id uuid, action_type text, taken_at timestamptz, by_email text, cost_rupees bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.schedule_id, a.action_type, a.taken_at, a.by_email, a.cost_rupees, a.notes_md
  FROM public.engineer_calibration_action_log_r2128 a
  WHERE a.schedule_id = p_schedule_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END; $$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_action_r2128(p_schedule_id uuid, p_action_type text, p_by_email text, p_cost_rupees bigint, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_calibration_action_log_r2128(schedule_id, action_type, by_email, cost_rupees, notes_md)
  VALUES (p_schedule_id, p_action_type, p_by_email, p_cost_rupees, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2128', jsonb_build_object('id', v_id, 'schedule_id', p_schedule_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r2128(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_tool_calibration_schedule_r2128
  SET status = p_status, updated_at = now()
  WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2128', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

-- 6. due_soon
CREATE OR REPLACE FUNCTION public.due_soon_r2128()
RETURNS TABLE(id uuid, engineer_user_id uuid, tool_label text, next_calibration_due_at timestamptz, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, s.tool_label, s.next_calibration_due_at, s.status
  FROM public.engineer_tool_calibration_schedule_r2128 s
  WHERE s.status IN ('due_soon','overdue')
  ORDER BY s.next_calibration_due_at ASC NULLS LAST
  LIMIT 100;
END; $$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2128()
RETURNS TABLE(id uuid, schedule_id uuid, action_type text, taken_at timestamptz, by_email text, cost_rupees bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.schedule_id, a.action_type, a.taken_at, a.by_email, a.cost_rupees
  FROM public.engineer_calibration_action_log_r2128 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_schedules_r2128() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_schedule_r2128(uuid, text, timestamptz, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2128(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2128(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2128(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.due_soon_r2128() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2128() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_schedules_r2128() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_schedule_r2128(uuid, text, timestamptz, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2128(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2128(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2128(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.due_soon_r2128() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2128() TO authenticated;

COMMIT;
