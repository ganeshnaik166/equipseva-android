BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_watchlist_alert_system_r2137 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  alert_type text NOT NULL CHECK (alert_type IN ('engagement_drop','concern_raised','competing_investment','policy_change','positive_signal')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','acknowledged','resolved','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_alert_action_log_r2137 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id uuid NOT NULL REFERENCES public.investor_watchlist_alert_system_r2137(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('acknowledged','intervention','escalated','resolved','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_watchlist_alert_system_r2137 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_alert_action_log_r2137 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_iwas_r2137 ON public.investor_watchlist_alert_system_r2137;
CREATE POLICY founder_all_iwas_r2137 ON public.investor_watchlist_alert_system_r2137
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_iaal_r2137 ON public.investor_alert_action_log_r2137;
CREATE POLICY founder_all_iaal_r2137 ON public.investor_alert_action_log_r2137
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.iwas_list_alerts_r2137()
RETURNS TABLE (id uuid, investor_id uuid, alert_type text, severity text, status text, captured_at timestamptz, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.investor_id, a.alert_type, a.severity, a.status, a.captured_at, a.notes_md
    FROM public.investor_watchlist_alert_system_r2137 a
    ORDER BY a.captured_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.iwas_log_alert_r2137(
  p_investor_id uuid, p_alert_type text, p_severity text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_watchlist_alert_system_r2137(investor_id, alert_type, severity, notes_md)
  VALUES (p_investor_id, p_alert_type, p_severity, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'iwas_log_alert_r2137',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'alert_type', p_alert_type, 'severity', p_severity));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.iwas_list_actions_r2137(p_alert_id uuid)
RETURNS TABLE (id uuid, alert_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.alert_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.investor_alert_action_log_r2137 a
    WHERE (p_alert_id IS NULL OR a.alert_id = p_alert_id)
    ORDER BY a.taken_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.iwas_log_action_r2137(
  p_alert_id uuid, p_action_type text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.investor_alert_action_log_r2137(alert_id, action_type, by_email, notes_md)
  VALUES (p_alert_id, p_action_type, v_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'iwas_log_action_r2137',
    jsonb_build_object('id', v_id, 'alert_id', p_alert_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.iwas_mark_status_r2137(p_alert_id uuid, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_watchlist_alert_system_r2137
    SET status = p_status, updated_at = now()
    WHERE id = p_alert_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'iwas_mark_status_r2137',
    jsonb_build_object('alert_id', p_alert_id, 'status', p_status));
  RETURN p_alert_id;
END; $$;

CREATE OR REPLACE FUNCTION public.iwas_critical_alerts_r2137()
RETURNS TABLE (id uuid, investor_id uuid, alert_type text, severity text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.investor_id, a.alert_type, a.severity, a.status, a.captured_at
    FROM public.investor_watchlist_alert_system_r2137 a
    WHERE a.severity IN ('high','critical') AND a.status IN ('active','escalated')
    ORDER BY a.captured_at DESC LIMIT 100;
END; $$;

CREATE OR REPLACE FUNCTION public.iwas_recent_actions_r2137()
RETURNS TABLE (id uuid, alert_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.alert_id, a.action_type, a.taken_at, a.by_email
    FROM public.investor_alert_action_log_r2137 a
    ORDER BY a.taken_at DESC LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.iwas_list_alerts_r2137() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.iwas_log_alert_r2137(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.iwas_list_actions_r2137(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.iwas_log_action_r2137(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.iwas_mark_status_r2137(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.iwas_critical_alerts_r2137() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.iwas_recent_actions_r2137() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.iwas_list_alerts_r2137() TO authenticated;
GRANT EXECUTE ON FUNCTION public.iwas_log_alert_r2137(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.iwas_list_actions_r2137(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.iwas_log_action_r2137(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.iwas_mark_status_r2137(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.iwas_critical_alerts_r2137() TO authenticated;
GRANT EXECUTE ON FUNCTION public.iwas_recent_actions_r2137() TO authenticated;

COMMIT;
