BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_one_on_one_sessions_r2221 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  report_name text NOT NULL,
  report_role text,
  scheduled_at timestamptz NOT NULL,
  duration_minutes int NOT NULL DEFAULT 30,
  cadence text NOT NULL DEFAULT 'weekly' CHECK (cadence IN ('weekly','biweekly','monthly','adhoc')),
  agenda text,
  notes text,
  mood text CHECK (mood IS NULL OR mood IN ('green','amber','red')),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','completed','rescheduled','cancelled','no_show')),
  completed_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_one_on_one_action_items_r2221 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES public.founder_one_on_one_sessions_r2221(id) ON DELETE CASCADE,
  report_name text NOT NULL,
  action_text text NOT NULL,
  owner text NOT NULL DEFAULT 'report' CHECK (owner IN ('report','founder','shared')),
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped','carried_over')),
  carried_over_count int NOT NULL DEFAULT 0,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_one_on_one_sessions_r2221 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_one_on_one_action_items_r2221 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_one_on_one_sessions_r2221;
CREATE POLICY founder_all ON public.founder_one_on_one_sessions_r2221
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_one_on_one_action_items_r2221;
CREATE POLICY founder_all ON public.founder_one_on_one_action_items_r2221
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_one_on_one_sessions_r2221()
RETURNS TABLE(
  id uuid,
  report_name text,
  report_role text,
  scheduled_at timestamptz,
  duration_minutes int,
  cadence text,
  status text,
  mood text,
  agenda text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.report_name, s.report_role, s.scheduled_at, s.duration_minutes,
         s.cadence, s.status, s.mood, s.agenda
  FROM public.founder_one_on_one_sessions_r2221 s
  ORDER BY s.scheduled_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_one_on_one_r2221()
RETURNS TABLE(
  id uuid,
  report_name text,
  action_text text,
  owner text,
  due_date date,
  status text,
  carried_over_count int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.report_name, a.action_text, a.owner, a.due_date, a.status,
         a.carried_over_count, a.created_at
  FROM public.founder_one_on_one_action_items_r2221 a
  ORDER BY a.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_one_on_one_reports_r2221()
RETURNS TABLE(
  report_name text,
  sessions_count int,
  completed_count int,
  open_actions int,
  last_session timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.report_name,
         (COUNT(*))::int AS sessions_count,
         (COUNT(*) FILTER (WHERE s.status = 'completed'))::int AS completed_count,
         COALESCE((
           SELECT (COUNT(*) FILTER (WHERE a.status IN ('open','in_progress')))::int
           FROM public.founder_one_on_one_action_items_r2221 a
           WHERE a.report_name = s.report_name
         ), 0) AS open_actions,
         MAX(s.scheduled_at) AS last_session
  FROM public.founder_one_on_one_sessions_r2221 s
  GROUP BY s.report_name
  ORDER BY sessions_count DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_one_on_one_session_r2221(
  p_report_name text,
  p_report_role text,
  p_scheduled_at timestamptz,
  p_cadence text,
  p_agenda text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_one_on_one_sessions_r2221(report_name, report_role, scheduled_at, cadence, agenda, created_by)
  VALUES (p_report_name, p_report_role, p_scheduled_at, COALESCE(p_cadence,'weekly'), p_agenda, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2221_schedule',
          jsonb_build_object('session_id', v_id, 'report', p_report_name, 'when', p_scheduled_at));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_one_on_one_r2221(
  p_session_id uuid,
  p_report_name text,
  p_action_text text,
  p_owner text,
  p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_one_on_one_action_items_r2221(session_id, report_name, action_text, owner, due_date)
  VALUES (p_session_id, p_report_name, p_action_text, COALESCE(p_owner,'report'), p_due_date)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2221_log_action',
          jsonb_build_object('action_id', v_id, 'report', p_report_name));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_one_on_one_r2221(
  p_session_id uuid,
  p_status text,
  p_mood text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_one_on_one_sessions_r2221
     SET status = p_status,
         mood = p_mood,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at = now()
   WHERE id = p_session_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2221_mark_status',
          jsonb_build_object('session_id', p_session_id, 'status', p_status, 'mood', p_mood));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_one_on_one_r2221()
RETURNS TABLE(
  total_sessions int,
  scheduled_upcoming int,
  completed_last_30 int,
  no_show_last_30 int,
  open_actions int,
  carried_over_actions int,
  unique_reports int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT (COUNT(*))::int FROM public.founder_one_on_one_sessions_r2221),
    (SELECT (COUNT(*) FILTER (WHERE status='scheduled' AND scheduled_at >= now()))::int FROM public.founder_one_on_one_sessions_r2221),
    (SELECT (COUNT(*) FILTER (WHERE status='completed' AND completed_at >= now() - interval '30 days'))::int FROM public.founder_one_on_one_sessions_r2221),
    (SELECT (COUNT(*) FILTER (WHERE status='no_show' AND scheduled_at >= now() - interval '30 days'))::int FROM public.founder_one_on_one_sessions_r2221),
    (SELECT (COUNT(*) FILTER (WHERE status IN ('open','in_progress')))::int FROM public.founder_one_on_one_action_items_r2221),
    (SELECT (COUNT(*) FILTER (WHERE carried_over_count > 0))::int FROM public.founder_one_on_one_action_items_r2221),
    (SELECT (COUNT(DISTINCT report_name))::int FROM public.founder_one_on_one_sessions_r2221);
END;
$$;

REVOKE ALL ON FUNCTION public.list_one_on_one_sessions_r2221() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_one_on_one_r2221() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_one_on_one_reports_r2221() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_one_on_one_session_r2221(text, text, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_one_on_one_r2221(uuid, text, text, text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_one_on_one_r2221(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_one_on_one_r2221() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_one_on_one_sessions_r2221() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_one_on_one_r2221() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_one_on_one_reports_r2221() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_one_on_one_session_r2221(text, text, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_one_on_one_r2221(uuid, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_one_on_one_r2221(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_one_on_one_r2221() TO authenticated;

COMMIT;
