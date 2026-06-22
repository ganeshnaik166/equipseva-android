BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_annual_report_schedule_r2081 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fy_year text NOT NULL,
  scheduled_send_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('planned','drafting','under_review','sent','cancelled')),
  sent_at timestamptz,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_annual_report_action_log_r2081 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.investor_annual_report_schedule_r2081(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('drafting_started','under_review','sent','acknowledged','disputed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_annual_report_schedule_r2081 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_annual_report_action_log_r2081 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_iars_r2081 ON public.investor_annual_report_schedule_r2081;
CREATE POLICY founder_all_iars_r2081 ON public.investor_annual_report_schedule_r2081
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_iaral_r2081 ON public.investor_annual_report_action_log_r2081;
CREATE POLICY founder_all_iaral_r2081 ON public.investor_annual_report_action_log_r2081
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_investor_annual_report_schedules_r2081()
RETURNS SETOF public.investor_annual_report_schedule_r2081
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.investor_annual_report_schedule_r2081 ORDER BY scheduled_send_date DESC, created_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_investor_annual_report_schedule_r2081(
  p_fy_year text,
  p_scheduled_send_date date,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_annual_report_schedule_r2081(fy_year, scheduled_send_date, status)
  VALUES (p_fy_year, p_scheduled_send_date, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_annual_report_schedule_r2081',
    jsonb_build_object('id', v_id, 'fy_year', p_fy_year, 'status', p_status));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_investor_annual_report_actions_r2081(p_report_id uuid)
RETURNS SETOF public.investor_annual_report_action_log_r2081
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.investor_annual_report_action_log_r2081
    WHERE report_id = p_report_id
    ORDER BY taken_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_investor_annual_report_action_r2081(
  p_report_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_annual_report_action_log_r2081(report_id, action_type, by_email, notes_md)
  VALUES (p_report_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_investor_annual_report_action_r2081',
    jsonb_build_object('id', v_id, 'report_id', p_report_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_investor_annual_report_status_r2081(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_annual_report_schedule_r2081
  SET status = p_status,
      sent_at = CASE WHEN p_status = 'sent' THEN now() ELSE sent_at END,
      updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_investor_annual_report_status_r2081',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.due_soon_investor_annual_reports_r2081()
RETURNS SETOF public.investor_annual_report_schedule_r2081
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.investor_annual_report_schedule_r2081
    WHERE status IN ('planned','drafting','under_review')
      AND scheduled_send_date <= (current_date + interval '30 days')
    ORDER BY scheduled_send_date ASC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_investor_annual_report_actions_r2081()
RETURNS SETOF public.investor_annual_report_action_log_r2081
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY SELECT * FROM public.investor_annual_report_action_log_r2081
    ORDER BY taken_at DESC LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_investor_annual_report_schedules_r2081() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_annual_report_schedule_r2081(text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_annual_report_actions_r2081(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_annual_report_action_r2081(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_investor_annual_report_status_r2081(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.due_soon_investor_annual_reports_r2081() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_investor_annual_report_actions_r2081() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_annual_report_schedules_r2081() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_annual_report_schedule_r2081(text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_annual_report_actions_r2081(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_annual_report_action_r2081(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_investor_annual_report_status_r2081(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.due_soon_investor_annual_reports_r2081() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_investor_annual_report_actions_r2081() TO authenticated;

COMMIT;
