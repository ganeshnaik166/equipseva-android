BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_cap_table_conversion_trigger_r2193 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trigger_event_label text NOT NULL,
  trigger_at timestamptz NOT NULL DEFAULT now(),
  total_converted_shares bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'triggered' CHECK (status IN ('triggered','in_progress','completed','disputed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_conversion_action_log_r2193 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trigger_id uuid NOT NULL REFERENCES public.investor_cap_table_conversion_trigger_r2193(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('triggered','converted','disputed','closed','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  shares_count bigint NOT NULL DEFAULT 0,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_cap_table_conversion_trigger_r2193 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_conversion_action_log_r2193 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_trigger_r2193 ON public.investor_cap_table_conversion_trigger_r2193;
CREATE POLICY founder_all_trigger_r2193 ON public.investor_cap_table_conversion_trigger_r2193
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2193 ON public.investor_conversion_action_log_r2193;
CREATE POLICY founder_all_action_r2193 ON public.investor_conversion_action_log_r2193
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_trigger_r2193_at ON public.investor_cap_table_conversion_trigger_r2193(trigger_at DESC);
CREATE INDEX IF NOT EXISTS idx_action_r2193_trigger ON public.investor_conversion_action_log_r2193(trigger_id, taken_at DESC);

DROP FUNCTION IF EXISTS public.list_triggers_r2193();
CREATE FUNCTION public.list_triggers_r2193()
RETURNS TABLE(id uuid, trigger_event_label text, trigger_at timestamptz, total_converted_shares bigint, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.trigger_event_label, t.trigger_at, t.total_converted_shares, t.status, t.captured_at
  FROM public.investor_cap_table_conversion_trigger_r2193 t ORDER BY t.trigger_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_triggers_r2193() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_triggers_r2193() TO authenticated;

DROP FUNCTION IF EXISTS public.log_trigger_r2193(text, bigint, text);
CREATE FUNCTION public.log_trigger_r2193(p_label text, p_shares bigint, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_cap_table_conversion_trigger_r2193(trigger_event_label, total_converted_shares, status)
  VALUES (p_label, COALESCE(p_shares,0), COALESCE(p_status,'triggered')) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_trigger_r2193', jsonb_build_object('id', v_id, 'label', p_label));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_trigger_r2193(text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_trigger_r2193(text, bigint, text) TO authenticated;

DROP FUNCTION IF EXISTS public.list_actions_r2193(uuid);
CREATE FUNCTION public.list_actions_r2193(p_trigger uuid)
RETURNS TABLE(id uuid, trigger_id uuid, action_type text, taken_at timestamptz, by_email text, shares_count bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.trigger_id, a.action_type, a.taken_at, a.by_email, a.shares_count, a.notes_md
  FROM public.investor_conversion_action_log_r2193 a WHERE a.trigger_id = p_trigger ORDER BY a.taken_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2193(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2193(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_action_r2193(uuid, text, bigint, text);
CREATE FUNCTION public.log_action_r2193(p_trigger uuid, p_type text, p_shares bigint, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_conversion_action_log_r2193(trigger_id, action_type, by_email, shares_count, notes_md)
  VALUES (p_trigger, p_type, (auth.jwt()->>'email'), COALESCE(p_shares,0), p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2193', jsonb_build_object('id', v_id, 'trigger', p_trigger, 'type', p_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2193(uuid, text, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2193(uuid, text, bigint, text) TO authenticated;

DROP FUNCTION IF EXISTS public.mark_status_r2193(uuid, text);
CREATE FUNCTION public.mark_status_r2193(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_cap_table_conversion_trigger_r2193 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2193', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2193(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2193(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.recent_triggers_r2193();
CREATE FUNCTION public.recent_triggers_r2193()
RETURNS TABLE(id uuid, trigger_event_label text, trigger_at timestamptz, total_converted_shares bigint, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.trigger_event_label, t.trigger_at, t.total_converted_shares, t.status
  FROM public.investor_cap_table_conversion_trigger_r2193 t
  WHERE t.trigger_at > now() - interval '90 days' ORDER BY t.trigger_at DESC LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_triggers_r2193() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_triggers_r2193() TO authenticated;

DROP FUNCTION IF EXISTS public.recent_actions_r2193();
CREATE FUNCTION public.recent_actions_r2193()
RETURNS TABLE(id uuid, trigger_id uuid, action_type text, taken_at timestamptz, by_email text, shares_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.trigger_id, a.action_type, a.taken_at, a.by_email, a.shares_count
  FROM public.investor_conversion_action_log_r2193 a
  WHERE a.taken_at > now() - interval '60 days' ORDER BY a.taken_at DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2193() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2193() TO authenticated;

COMMIT;
