BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_off_hours_engagement_r2150 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  off_hour_calls int NOT NULL DEFAULT 0,
  off_hour_emails int NOT NULL DEFAULT 0,
  off_hour_emergencies int NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('minimal','elevated','heavy','concerning')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_off_hours_action_log_r2150 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id uuid NOT NULL REFERENCES public.founder_off_hours_engagement_r2150(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('policy_set','escalated','recovery_taken','closed','concern_raised')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_off_hours_engagement_r2150 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_off_hours_action_log_r2150 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_engagement_r2150 ON public.founder_off_hours_engagement_r2150;
CREATE POLICY founder_all_engagement_r2150 ON public.founder_off_hours_engagement_r2150
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2150 ON public.founder_off_hours_action_log_r2150;
CREATE POLICY founder_all_action_log_r2150 ON public.founder_off_hours_action_log_r2150
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_off_hours_periods_r2150()
RETURNS TABLE (id uuid, period_label text, off_hour_calls int, off_hour_emails int, off_hour_emergencies int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.period_label, p.off_hour_calls, p.off_hour_emails, p.off_hour_emergencies, p.status, p.captured_at
  FROM public.founder_off_hours_engagement_r2150 p
  ORDER BY p.captured_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_off_hours_period_r2150(
  p_period_label text,
  p_calls int,
  p_emails int,
  p_emergencies int,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_off_hours_engagement_r2150(period_label, off_hour_calls, off_hour_emails, off_hour_emergencies, status)
  VALUES (p_period_label, COALESCE(p_calls,0), COALESCE(p_emails,0), COALESCE(p_emergencies,0), p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_off_hours_period_r2150',
          jsonb_build_object('id', v_id, 'period_label', p_period_label, 'status', p_status));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_off_hours_actions_r2150(p_period_id uuid)
RETURNS TABLE (id uuid, period_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.period_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_off_hours_action_log_r2150 a
  WHERE a.period_id = p_period_id
  ORDER BY a.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_off_hours_action_r2150(
  p_period_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_off_hours_action_log_r2150(period_id, action_type, by_email, notes_md)
  VALUES (p_period_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_off_hours_action_r2150',
          jsonb_build_object('id', v_id, 'period_id', p_period_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_off_hours_status_r2150(
  p_period_id uuid,
  p_status text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_off_hours_engagement_r2150
     SET status = p_status, updated_at = now()
   WHERE id = p_period_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_off_hours_status_r2150',
          jsonb_build_object('id', p_period_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.heavy_off_hours_periods_r2150()
RETURNS TABLE (id uuid, period_label text, off_hour_calls int, off_hour_emails int, off_hour_emergencies int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.period_label, p.off_hour_calls, p.off_hour_emails, p.off_hour_emergencies, p.status, p.captured_at
  FROM public.founder_off_hours_engagement_r2150 p
  WHERE p.status IN ('heavy','concerning')
  ORDER BY p.captured_at DESC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_off_hours_actions_r2150()
RETURNS TABLE (id uuid, period_id uuid, period_label text, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.period_id, p.period_label, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_off_hours_action_log_r2150 a
  JOIN public.founder_off_hours_engagement_r2150 p ON p.id = a.period_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_off_hours_periods_r2150() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_off_hours_period_r2150(text, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_off_hours_actions_r2150(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_off_hours_action_r2150(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_off_hours_status_r2150(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.heavy_off_hours_periods_r2150() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_off_hours_actions_r2150() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_off_hours_periods_r2150() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_off_hours_period_r2150(text, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_off_hours_actions_r2150(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_off_hours_action_r2150(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_off_hours_status_r2150(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.heavy_off_hours_periods_r2150() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_off_hours_actions_r2150() TO authenticated;

COMMIT;
