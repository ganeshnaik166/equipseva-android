BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_qbr_sessions_r2215 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  quarter_label text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  conducted_at timestamptz,
  attendee_count int NOT NULL DEFAULT 0,
  agenda_total int NOT NULL DEFAULT 0,
  agenda_completed int NOT NULL DEFAULT 0,
  action_items_total int NOT NULL DEFAULT 0,
  action_items_closed int NOT NULL DEFAULT 0,
  completion_pct numeric(5,2) NOT NULL DEFAULT 0,
  csat_score numeric(3,1),
  status text NOT NULL DEFAULT 'scheduled',
  notes text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_qbr_action_items_r2215 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qbr_session_id uuid REFERENCES public.hospital_qbr_sessions_r2215(id) ON DELETE CASCADE,
  agenda_item text NOT NULL,
  owner_email text,
  due_date date,
  priority text NOT NULL DEFAULT 'medium',
  status text NOT NULL DEFAULT 'open',
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_qbr_sessions_r2215 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_qbr_action_items_r2215 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_qbr_sessions_r2215;
CREATE POLICY founder_all ON public.hospital_qbr_sessions_r2215
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_qbr_action_items_r2215;
CREATE POLICY founder_all ON public.hospital_qbr_action_items_r2215
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_qbr_sessions_r2215_scheduled ON public.hospital_qbr_sessions_r2215(scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_qbr_sessions_r2215_status ON public.hospital_qbr_sessions_r2215(status);
CREATE INDEX IF NOT EXISTS idx_qbr_actions_r2215_session ON public.hospital_qbr_action_items_r2215(qbr_session_id);
CREATE INDEX IF NOT EXISTS idx_qbr_actions_r2215_status ON public.hospital_qbr_action_items_r2215(status);

CREATE OR REPLACE FUNCTION public.list_hospital_qbr_sessions_r2215(
  p_limit int DEFAULT 100
) RETURNS TABLE (
  id uuid,
  hospital_name text,
  quarter_label text,
  scheduled_at timestamptz,
  conducted_at timestamptz,
  attendee_count int,
  agenda_total int,
  agenda_completed int,
  action_items_total int,
  action_items_closed int,
  completion_pct numeric,
  csat_score numeric,
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_name, s.quarter_label, s.scheduled_at, s.conducted_at,
         s.attendee_count, s.agenda_total, s.agenda_completed,
         s.action_items_total, s.action_items_closed,
         s.completion_pct, s.csat_score, s.status
  FROM public.hospital_qbr_sessions_r2215 s
  ORDER BY s.scheduled_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_hospital_qbr_r2215(
  p_limit int DEFAULT 50
) RETURNS TABLE (
  id uuid,
  qbr_session_id uuid,
  agenda_item text,
  owner_email text,
  due_date date,
  priority text,
  status text,
  closed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.qbr_session_id, a.agenda_item, a.owner_email,
         a.due_date, a.priority, a.status, a.closed_at, a.created_at
  FROM public.hospital_qbr_action_items_r2215 a
  ORDER BY a.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

CREATE OR REPLACE FUNCTION public.top_hospital_qbr_completion_r2215(
  p_limit int DEFAULT 10
) RETURNS TABLE (
  hospital_name text,
  sessions_total int,
  avg_completion_pct numeric,
  avg_csat numeric,
  last_scheduled timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.hospital_name,
         COUNT(*)::int AS sessions_total,
         ROUND(AVG(s.completion_pct), 2) AS avg_completion_pct,
         ROUND(AVG(s.csat_score), 2) AS avg_csat,
         MAX(s.scheduled_at) AS last_scheduled
  FROM public.hospital_qbr_sessions_r2215 s
  GROUP BY s.hospital_name
  ORDER BY avg_completion_pct DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(p_limit, 100));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_hospital_qbr_session_r2215(
  p_hospital_org_id uuid,
  p_hospital_name text,
  p_quarter_label text,
  p_scheduled_at timestamptz,
  p_agenda_total int,
  p_action_items_total int
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_qbr_sessions_r2215(
    hospital_org_id, hospital_name, quarter_label, scheduled_at,
    agenda_total, action_items_total, created_by
  ) VALUES (
    p_hospital_org_id, p_hospital_name, p_quarter_label, p_scheduled_at,
    COALESCE(p_agenda_total, 0), COALESCE(p_action_items_total, 0), auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2215_log_qbr_session',
          jsonb_build_object('id', v_id, 'hospital', p_hospital_name, 'quarter', p_quarter_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_hospital_qbr_item_r2215(
  p_qbr_session_id uuid,
  p_agenda_item text,
  p_owner_email text,
  p_due_date date,
  p_priority text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_qbr_action_items_r2215(
    qbr_session_id, agenda_item, owner_email, due_date, priority
  ) VALUES (
    p_qbr_session_id, p_agenda_item, p_owner_email, p_due_date,
    COALESCE(p_priority, 'medium')
  ) RETURNING id INTO v_id;

  UPDATE public.hospital_qbr_sessions_r2215
  SET action_items_total = action_items_total + 1, updated_at = now()
  WHERE id = p_qbr_session_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2215_log_action_item',
          jsonb_build_object('id', v_id, 'session', p_qbr_session_id, 'item', p_agenda_item));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_hospital_qbr_r2215(
  p_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_qbr_sessions_r2215
  SET status = p_status,
      conducted_at = CASE WHEN p_status = 'completed' THEN now() ELSE conducted_at END,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2215_mark_status',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_hospital_qbr_r2215()
RETURNS TABLE (
  sessions_total int,
  sessions_scheduled int,
  sessions_completed int,
  sessions_overdue int,
  avg_completion_pct numeric,
  avg_csat numeric,
  action_items_open int,
  action_items_closed int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.hospital_qbr_sessions_r2215)::int,
    (SELECT COUNT(*) FILTER (WHERE status = 'scheduled') FROM public.hospital_qbr_sessions_r2215)::int,
    (SELECT COUNT(*) FILTER (WHERE status = 'completed') FROM public.hospital_qbr_sessions_r2215)::int,
    (SELECT COUNT(*) FILTER (WHERE status = 'scheduled' AND scheduled_at < now()) FROM public.hospital_qbr_sessions_r2215)::int,
    (SELECT ROUND(AVG(completion_pct), 2) FROM public.hospital_qbr_sessions_r2215),
    (SELECT ROUND(AVG(csat_score), 2) FROM public.hospital_qbr_sessions_r2215 WHERE csat_score IS NOT NULL),
    (SELECT COUNT(*) FILTER (WHERE status = 'open') FROM public.hospital_qbr_action_items_r2215)::int,
    (SELECT COUNT(*) FILTER (WHERE status = 'closed') FROM public.hospital_qbr_action_items_r2215)::int;
END;
$$;

REVOKE ALL ON FUNCTION public.list_hospital_qbr_sessions_r2215(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_hospital_qbr_r2215(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_hospital_qbr_completion_r2215(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_hospital_qbr_session_r2215(uuid, text, text, timestamptz, int, int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_hospital_qbr_item_r2215(uuid, text, text, date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_hospital_qbr_r2215(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_hospital_qbr_r2215() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_hospital_qbr_sessions_r2215(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_hospital_qbr_r2215(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_hospital_qbr_completion_r2215(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_hospital_qbr_session_r2215(uuid, text, text, timestamptz, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_hospital_qbr_item_r2215(uuid, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_hospital_qbr_r2215(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_hospital_qbr_r2215() TO authenticated;

COMMIT;
