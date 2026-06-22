BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_compliance_checkin_schedule_r2013 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  checkin_label text NOT NULL,
  scheduled_for timestamptz NOT NULL,
  checkin_type text NOT NULL CHECK (checkin_type IN ('governance','financial','regulatory','operational','legal')),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','completed','missed','rescheduled')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_compliance_checkin_log_r2013 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.investor_compliance_checkin_schedule_r2013(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('completed','issues_raised','escalated','follow_up_required')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_compliance_checkin_schedule_r2013 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_compliance_checkin_log_r2013 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_schedule_r2013 ON public.investor_compliance_checkin_schedule_r2013;
CREATE POLICY founder_all_schedule_r2013 ON public.investor_compliance_checkin_schedule_r2013
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_log_r2013 ON public.investor_compliance_checkin_log_r2013;
CREATE POLICY founder_all_log_r2013 ON public.investor_compliance_checkin_log_r2013
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_schedules_r2013()
RETURNS SETOF public.investor_compliance_checkin_schedule_r2013
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_compliance_checkin_schedule_r2013 ORDER BY scheduled_for DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_schedule_r2013(
  p_investor_id uuid, p_label text, p_scheduled_for timestamptz, p_checkin_type text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_compliance_checkin_schedule_r2013(investor_id, checkin_label, scheduled_for, checkin_type)
  VALUES (p_investor_id, p_label, p_scheduled_for, p_checkin_type)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_schedule_r2013', jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'label', p_label));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2013()
RETURNS SETOF public.investor_compliance_checkin_log_r2013
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_compliance_checkin_log_r2013 ORDER BY taken_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2013(
  p_schedule_id uuid, p_action_type text, p_by_email text, p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_compliance_checkin_log_r2013(schedule_id, action_type, by_email, notes_md)
  VALUES (p_schedule_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2013', jsonb_build_object('id', v_id, 'schedule_id', p_schedule_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2013(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_compliance_checkin_schedule_r2013
    SET status = p_status,
        completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
        updated_at = now()
    WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2013', jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.upcoming_checkins_r2013()
RETURNS SETOF public.investor_compliance_checkin_schedule_r2013
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.investor_compliance_checkin_schedule_r2013
    WHERE status = 'scheduled' AND scheduled_for >= now()
    ORDER BY scheduled_for ASC LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2013()
RETURNS SETOF public.investor_compliance_checkin_log_r2013
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT * FROM public.investor_compliance_checkin_log_r2013
    ORDER BY taken_at DESC LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_schedules_r2013() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_schedule_r2013(uuid, text, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2013() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2013(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2013(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_checkins_r2013() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2013() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_schedules_r2013() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_schedule_r2013(uuid, text, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2013() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2013(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2013(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_checkins_r2013() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2013() TO authenticated;

COMMIT;
