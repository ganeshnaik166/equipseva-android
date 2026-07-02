BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_reflection_frequency_tracker_r2154 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_label text NOT NULL,
  reflection_sessions_count int NOT NULL DEFAULT 0,
  avg_session_minutes int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'none' CHECK (status IN ('excellent','good','sparse','none')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_reflection_action_log_r2154 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id uuid NOT NULL REFERENCES public.founder_reflection_frequency_tracker_r2154(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('session_held','skipped','extended','reviewed','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_reflection_frequency_tracker_r2154 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_reflection_action_log_r2154 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2154_periods ON public.founder_reflection_frequency_tracker_r2154;
CREATE POLICY founder_all_r2154_periods ON public.founder_reflection_frequency_tracker_r2154
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2154_actions ON public.founder_reflection_action_log_r2154;
CREATE POLICY founder_all_r2154_actions ON public.founder_reflection_action_log_r2154
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_periods_r2154()
RETURNS TABLE(id uuid, period_label text, reflection_sessions_count int, avg_session_minutes int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.period_label, p.reflection_sessions_count, p.avg_session_minutes, p.status, p.captured_at
    FROM public.founder_reflection_frequency_tracker_r2154 p
    ORDER BY p.captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_period_r2154(p_label text, p_sessions int, p_avg_minutes int, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_reflection_frequency_tracker_r2154(period_label, reflection_sessions_count, avg_session_minutes, status)
  VALUES (p_label, COALESCE(p_sessions,0), COALESCE(p_avg_minutes,0), COALESCE(p_status,'none'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_period_r2154', jsonb_build_object('id', v_id, 'period_label', p_label), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2154(p_period_id uuid)
RETURNS TABLE(id uuid, period_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.period_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_reflection_action_log_r2154 a
    WHERE a.period_id = p_period_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2154(p_period_id uuid, p_action_type text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_reflection_action_log_r2154(period_id, action_type, by_email, notes_md)
  VALUES (p_period_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2154', jsonb_build_object('id', v_id, 'period_id', p_period_id, 'action_type', p_action_type), now());
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2154(p_period_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_reflection_frequency_tracker_r2154
     SET status = p_status, updated_at = now()
   WHERE id = p_period_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2154', jsonb_build_object('id', p_period_id, 'status', p_status), now());
END;
$$;

CREATE OR REPLACE FUNCTION public.sparse_periods_r2154()
RETURNS TABLE(id uuid, period_label text, reflection_sessions_count int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.period_label, p.reflection_sessions_count, p.status, p.captured_at
    FROM public.founder_reflection_frequency_tracker_r2154 p
    WHERE p.status IN ('sparse','none')
    ORDER BY p.captured_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2154()
RETURNS TABLE(id uuid, period_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.period_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_reflection_action_log_r2154 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_periods_r2154() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_period_r2154(text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2154(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2154(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2154(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.sparse_periods_r2154() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2154() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_periods_r2154() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_period_r2154(text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2154(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2154(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2154(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sparse_periods_r2154() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2154() TO authenticated;

COMMIT;
