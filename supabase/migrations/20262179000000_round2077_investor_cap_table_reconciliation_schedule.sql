BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_reconciliation_schedule_r2077 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scheduled_date date NOT NULL,
  reconciliation_type text NOT NULL CHECK (reconciliation_type IN ('monthly','quarterly','annual','incident','triggered')),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','escalated','superseded')),
  completed_at timestamptz,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_reconciliation_action_log_r2077 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.investor_cap_table_reconciliation_schedule_r2077(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('started','completed','issues_found','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_reconciliation_schedule_r2077 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_reconciliation_action_log_r2077 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_sched_r2077 ON public.investor_cap_table_reconciliation_schedule_r2077;
CREATE POLICY founder_all_sched_r2077 ON public.investor_cap_table_reconciliation_schedule_r2077
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_act_r2077 ON public.investor_reconciliation_action_log_r2077;
CREATE POLICY founder_all_act_r2077 ON public.investor_reconciliation_action_log_r2077
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_schedules_r2077()
RETURNS TABLE(id uuid, scheduled_date date, reconciliation_type text, status text, completed_at timestamptz, notes_md text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.scheduled_date, s.reconciliation_type, s.status, s.completed_at, s.notes_md, s.created_at
    FROM public.investor_cap_table_reconciliation_schedule_r2077 s
    ORDER BY s.scheduled_date DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_schedule_r2077(p_scheduled_date date, p_reconciliation_type text, p_notes_md text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_reconciliation_schedule_r2077(scheduled_date, reconciliation_type, notes_md)
    VALUES (p_scheduled_date, p_reconciliation_type, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_schedule_r2077', jsonb_build_object('id', v_id, 'scheduled_date', p_scheduled_date, 'reconciliation_type', p_reconciliation_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2077(p_schedule_id uuid)
RETURNS TABLE(id uuid, schedule_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.schedule_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_reconciliation_action_log_r2077 a
    WHERE a.schedule_id = p_schedule_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2077(p_schedule_id uuid, p_action_type text, p_by_email text DEFAULT NULL, p_notes_md text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_reconciliation_action_log_r2077(schedule_id, action_type, by_email, notes_md)
    VALUES (p_schedule_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2077', jsonb_build_object('id', v_id, 'schedule_id', p_schedule_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2077(p_schedule_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_reconciliation_schedule_r2077
    SET status = p_status,
        completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
        updated_at = now()
    WHERE id = p_schedule_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2077', jsonb_build_object('schedule_id', p_schedule_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.upcoming_r2077()
RETURNS TABLE(id uuid, scheduled_date date, reconciliation_type text, status text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.scheduled_date, s.reconciliation_type, s.status, s.notes_md
    FROM public.investor_cap_table_reconciliation_schedule_r2077 s
    WHERE s.scheduled_date >= CURRENT_DATE
      AND s.status IN ('scheduled','in_progress')
    ORDER BY s.scheduled_date ASC
    LIMIT 50;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2077()
RETURNS TABLE(id uuid, schedule_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.schedule_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_reconciliation_action_log_r2077 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_schedules_r2077() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_schedule_r2077(date, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2077(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2077(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2077(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_r2077() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2077() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_schedules_r2077() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_schedule_r2077(date, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2077(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2077(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2077(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_r2077() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2077() TO authenticated;

COMMIT;
