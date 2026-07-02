BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_backlog_r2043 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  total_open_jobs int NOT NULL DEFAULT 0,
  overdue_jobs int NOT NULL DEFAULT 0,
  days_oldest_open int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('normal','elevated','severe','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_backlog_r2043_hospital ON public.hospital_service_backlog_r2043(hospital_id);
CREATE INDEX IF NOT EXISTS idx_backlog_r2043_status ON public.hospital_service_backlog_r2043(status);
CREATE INDEX IF NOT EXISTS idx_backlog_r2043_captured ON public.hospital_service_backlog_r2043(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_backlog_action_log_r2043 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  backlog_id uuid NOT NULL REFERENCES public.hospital_service_backlog_r2043(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engineer_added','escalation','clearance_pushed','customer_apology','resolved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_backlog_action_r2043_backlog ON public.hospital_backlog_action_log_r2043(backlog_id);
CREATE INDEX IF NOT EXISTS idx_backlog_action_r2043_taken ON public.hospital_backlog_action_log_r2043(taken_at DESC);

ALTER TABLE public.hospital_service_backlog_r2043 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_backlog_action_log_r2043 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_backlog_r2043 ON public.hospital_service_backlog_r2043;
CREATE POLICY founder_all_backlog_r2043 ON public.hospital_service_backlog_r2043
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2043 ON public.hospital_backlog_action_log_r2043;
CREATE POLICY founder_all_action_r2043 ON public.hospital_backlog_action_log_r2043
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_backlogs_r2043()
RETURNS TABLE (id uuid, hospital_id uuid, total_open_jobs int, overdue_jobs int, days_oldest_open int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.hospital_id, b.total_open_jobs, b.overdue_jobs, b.days_oldest_open, b.status, b.captured_at
    FROM public.hospital_service_backlog_r2043 b
    ORDER BY b.captured_at DESC
    LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_backlog_r2043(
  p_hospital_id uuid, p_total_open_jobs int, p_overdue_jobs int, p_days_oldest_open int, p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_backlog_r2043(hospital_id, total_open_jobs, overdue_jobs, days_oldest_open, status)
  VALUES (p_hospital_id, p_total_open_jobs, p_overdue_jobs, p_days_oldest_open, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_backlog_r2043',
    jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'status', p_status));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2043(p_backlog_id uuid)
RETURNS TABLE (id uuid, backlog_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.backlog_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_backlog_action_log_r2043 a
    WHERE a.backlog_id = p_backlog_id
    ORDER BY a.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2043(
  p_backlog_id uuid, p_action_type text, p_by_email text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_backlog_action_log_r2043(backlog_id, action_type, by_email, notes_md)
  VALUES (p_backlog_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2043',
    jsonb_build_object('id', v_id, 'backlog_id', p_backlog_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2043(p_backlog_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_backlog_r2043 SET status = p_status, updated_at = now() WHERE id = p_backlog_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2043',
    jsonb_build_object('backlog_id', p_backlog_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.critical_backlogs_r2043()
RETURNS TABLE (id uuid, hospital_id uuid, total_open_jobs int, overdue_jobs int, days_oldest_open int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.hospital_id, b.total_open_jobs, b.overdue_jobs, b.days_oldest_open, b.status, b.captured_at
    FROM public.hospital_service_backlog_r2043 b
    WHERE b.status IN ('severe','critical')
    ORDER BY b.captured_at DESC
    LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2043()
RETURNS TABLE (id uuid, backlog_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.backlog_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_backlog_action_log_r2043 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_backlogs_r2043() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_backlog_r2043(uuid, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2043(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2043(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2043(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_backlogs_r2043() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2043() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_backlogs_r2043() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_backlog_r2043(uuid, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2043(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2043(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2043(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_backlogs_r2043() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2043() TO authenticated;

COMMIT;
