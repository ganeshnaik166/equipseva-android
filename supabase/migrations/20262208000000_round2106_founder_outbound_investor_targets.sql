BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_outbound_investor_targets_r2106 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_name text NOT NULL,
  target_segment text NOT NULL CHECK (target_segment IN ('vc_growth','vc_seed','strategic','angel','family_office','sovereign')),
  priority text NOT NULL CHECK (priority IN ('critical','high','medium','low')),
  status text NOT NULL DEFAULT 'researching' CHECK (status IN ('researching','outbound','engaged','closed','lost')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_outbound_action_log_r2106 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES public.founder_outbound_investor_targets_r2106(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('researched','contacted','meeting_set','passed','closed','lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_outbound_investor_targets_r2106 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_outbound_action_log_r2106 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_targets_r2106 ON public.founder_outbound_investor_targets_r2106;
CREATE POLICY founder_all_targets_r2106 ON public.founder_outbound_investor_targets_r2106
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2106 ON public.founder_outbound_action_log_r2106;
CREATE POLICY founder_all_actions_r2106 ON public.founder_outbound_action_log_r2106
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1. list_targets
CREATE OR REPLACE FUNCTION public.list_outbound_targets_r2106()
RETURNS TABLE(id uuid, target_name text, target_segment text, priority text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.target_name, t.target_segment, t.priority, t.status, t.captured_at
    FROM public.founder_outbound_investor_targets_r2106 t
    ORDER BY CASE t.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END, t.captured_at DESC
    LIMIT 200;
END $$;

-- 2. log_target
CREATE OR REPLACE FUNCTION public.log_outbound_target_r2106(p_name text, p_segment text, p_priority text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_outbound_investor_targets_r2106(target_name, target_segment, priority)
    VALUES (p_name, p_segment, p_priority) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_outbound_target_r2106',
      jsonb_build_object('id', v_id, 'name', p_name, 'segment', p_segment, 'priority', p_priority));
  RETURN v_id;
END $$;

-- 3. list_actions
CREATE OR REPLACE FUNCTION public.list_outbound_actions_r2106(p_target uuid)
RETURNS TABLE(id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_outbound_action_log_r2106 a
    WHERE a.target_id = p_target
    ORDER BY a.taken_at DESC
    LIMIT 100;
END $$;

-- 4. log_action
CREATE OR REPLACE FUNCTION public.log_outbound_action_r2106(p_target uuid, p_action text, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.founder_outbound_action_log_r2106(target_id, action_type, by_email, notes_md)
    VALUES (p_target, p_action, v_email, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), v_email, 'log_outbound_action_r2106',
      jsonb_build_object('action_id', v_id, 'target_id', p_target, 'action', p_action));
  RETURN v_id;
END $$;

-- 5. mark_status
CREATE OR REPLACE FUNCTION public.mark_outbound_status_r2106(p_target uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_outbound_investor_targets_r2106 SET status = p_status, updated_at = now() WHERE id = p_target;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_outbound_status_r2106',
      jsonb_build_object('target_id', p_target, 'status', p_status));
END $$;

-- 6. critical_targets
CREATE OR REPLACE FUNCTION public.critical_outbound_targets_r2106()
RETURNS TABLE(id uuid, target_name text, target_segment text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.target_name, t.target_segment, t.status, t.captured_at
    FROM public.founder_outbound_investor_targets_r2106 t
    WHERE t.priority = 'critical' AND t.status NOT IN ('closed','lost')
    ORDER BY t.captured_at DESC
    LIMIT 100;
END $$;

-- 7. recent_actions
CREATE OR REPLACE FUNCTION public.recent_outbound_actions_r2106()
RETURNS TABLE(action_id uuid, target_name text, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, t.target_name, a.action_type, a.taken_at, a.by_email
    FROM public.founder_outbound_action_log_r2106 a
    JOIN public.founder_outbound_investor_targets_r2106 t ON t.id = a.target_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_outbound_targets_r2106() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_outbound_target_r2106(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_outbound_actions_r2106(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_outbound_action_r2106(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_outbound_status_r2106(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_outbound_targets_r2106() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_outbound_actions_r2106() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_outbound_targets_r2106() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_outbound_target_r2106(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_outbound_actions_r2106(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_outbound_action_r2106(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_outbound_status_r2106(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_outbound_targets_r2106() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_outbound_actions_r2106() TO authenticated;

COMMIT;
