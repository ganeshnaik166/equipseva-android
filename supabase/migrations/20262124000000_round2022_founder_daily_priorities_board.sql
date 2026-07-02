BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_daily_priorities_r2022 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  priority_label text NOT NULL,
  priority_md text,
  priority_level text NOT NULL CHECK (priority_level IN ('critical','high','medium','low')),
  scheduled_for date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','blocked','abandoned')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_priority_action_log_r2022 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  priority_id uuid NOT NULL REFERENCES public.founder_daily_priorities_r2022(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('started','blocked','completed','cancelled','escalated','extended')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_daily_priorities_r2022 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_priority_action_log_r2022 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_priorities_r2022 ON public.founder_daily_priorities_r2022;
CREATE POLICY founder_all_priorities_r2022 ON public.founder_daily_priorities_r2022
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2022 ON public.founder_priority_action_log_r2022;
CREATE POLICY founder_all_actions_r2022 ON public.founder_priority_action_log_r2022
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_priorities_r2022()
RETURNS TABLE (id uuid, priority_label text, priority_level text, scheduled_for date, status text, completed_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.priority_label, p.priority_level, p.scheduled_for, p.status, p.completed_at, p.created_at
    FROM public.founder_daily_priorities_r2022 p
    ORDER BY p.scheduled_for DESC, p.created_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_priority_r2022(
  p_label text, p_md text, p_level text, p_scheduled_for date
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_daily_priorities_r2022(priority_label, priority_md, priority_level, scheduled_for)
  VALUES (p_label, p_md, p_level, COALESCE(p_scheduled_for, CURRENT_DATE))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_priority_r2022', jsonb_build_object('id', v_id, 'label', p_label, 'level', p_level));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2022(p_priority_id uuid)
RETURNS TABLE (id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_priority_action_log_r2022 a
    WHERE a.priority_id = p_priority_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2022(
  p_priority_id uuid, p_action_type text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_priority_action_log_r2022(priority_id, action_type, by_email, notes_md)
  VALUES (p_priority_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2022', jsonb_build_object('id', v_id, 'priority_id', p_priority_id, 'action', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2022(p_priority_id uuid, p_status text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_daily_priorities_r2022
     SET status = p_status,
         completed_at = CASE WHEN p_status = 'completed' THEN now() ELSE completed_at END,
         updated_at = now()
   WHERE id = p_priority_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2022', jsonb_build_object('id', p_priority_id, 'status', p_status));
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.today_priorities_r2022()
RETURNS TABLE (id uuid, priority_label text, priority_level text, status text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.priority_label, p.priority_level, p.status, p.created_at
    FROM public.founder_daily_priorities_r2022 p
    WHERE p.scheduled_for = CURRENT_DATE
    ORDER BY
      CASE p.priority_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
      p.created_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2022()
RETURNS TABLE (id uuid, priority_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.priority_id, a.action_type, a.taken_at, a.by_email
    FROM public.founder_priority_action_log_r2022 a
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_priorities_r2022() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_priority_r2022(text, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2022(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2022(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2022(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.today_priorities_r2022() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2022() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_priorities_r2022() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_priority_r2022(text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2022(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2022(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2022(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.today_priorities_r2022() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2022() TO authenticated;

COMMIT;
