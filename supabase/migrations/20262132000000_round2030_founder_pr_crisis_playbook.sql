BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_pr_crisis_playbook_r2030 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  crisis_label text NOT NULL,
  crisis_severity text NOT NULL CHECK (crisis_severity IN ('minor','moderate','major','critical')),
  crisis_category text NOT NULL CHECK (crisis_category IN ('customer_complaint','employee_misconduct','data_breach','regulatory','legal','competitive_attack')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','contained','resolved','escalated')),
  resolution_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_pr_crisis_action_log_r2030 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  crisis_id uuid NOT NULL REFERENCES public.founder_pr_crisis_playbook_r2030(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('statement_drafted','spokesperson_briefed','customer_call','legal_notified','board_notified','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_pr_crisis_playbook_r2030 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_pr_crisis_action_log_r2030 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_crisis_r2030 ON public.founder_pr_crisis_playbook_r2030;
CREATE POLICY founder_all_crisis_r2030 ON public.founder_pr_crisis_playbook_r2030
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2030 ON public.founder_pr_crisis_action_log_r2030;
CREATE POLICY founder_all_action_r2030 ON public.founder_pr_crisis_action_log_r2030
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_crises
DROP FUNCTION IF EXISTS public.list_crises_r2030();
CREATE OR REPLACE FUNCTION public.list_crises_r2030()
RETURNS TABLE (
  id uuid,
  crisis_label text,
  crisis_severity text,
  crisis_category text,
  status text,
  opened_at timestamptz,
  closed_at timestamptz,
  resolution_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.crisis_label, c.crisis_severity, c.crisis_category, c.status, c.opened_at, c.closed_at, c.resolution_md
    FROM public.founder_pr_crisis_playbook_r2030 c
    ORDER BY c.opened_at DESC
    LIMIT 200;
END;
$$;

-- RPC 2: log_crisis
DROP FUNCTION IF EXISTS public.log_crisis_r2030(text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_crisis_r2030(
  p_label text,
  p_severity text,
  p_category text,
  p_resolution text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_pr_crisis_playbook_r2030 (crisis_label, crisis_severity, crisis_category, resolution_md)
  VALUES (p_label, p_severity, p_category, p_resolution)
  RETURNING id INTO new_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_crisis_r2030', jsonb_build_object('id', new_id, 'label', p_label, 'severity', p_severity));
  RETURN new_id;
END;
$$;

-- RPC 3: list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2030(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2030(p_crisis_id uuid)
RETURNS TABLE (
  id uuid,
  crisis_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.crisis_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_pr_crisis_action_log_r2030 a
    WHERE a.crisis_id = p_crisis_id
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;

-- RPC 4: log_action
DROP FUNCTION IF EXISTS public.log_action_r2030(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2030(
  p_crisis_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_pr_crisis_action_log_r2030 (crisis_id, action_type, by_email, notes_md)
  VALUES (p_crisis_id, p_action_type, p_by_email, p_notes)
  RETURNING id INTO new_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2030', jsonb_build_object('id', new_id, 'crisis_id', p_crisis_id, 'action_type', p_action_type));
  RETURN new_id;
END;
$$;

-- RPC 5: mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2030(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2030(
  p_crisis_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_pr_crisis_playbook_r2030
  SET status = p_status,
      closed_at = CASE WHEN p_status IN ('resolved','contained') THEN now() ELSE closed_at END,
      updated_at = now()
  WHERE id = p_crisis_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2030', jsonb_build_object('id', p_crisis_id, 'status', p_status));
END;
$$;

-- RPC 6: active_crises
DROP FUNCTION IF EXISTS public.active_crises_r2030();
CREATE OR REPLACE FUNCTION public.active_crises_r2030()
RETURNS TABLE (
  id uuid,
  crisis_label text,
  crisis_severity text,
  crisis_category text,
  opened_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.crisis_label, c.crisis_severity, c.crisis_category, c.opened_at, c.status
    FROM public.founder_pr_crisis_playbook_r2030 c
    WHERE c.status IN ('open','escalated')
    ORDER BY
      CASE c.crisis_severity
        WHEN 'critical' THEN 1
        WHEN 'major' THEN 2
        WHEN 'moderate' THEN 3
        WHEN 'minor' THEN 4
        ELSE 5
      END,
      c.opened_at DESC
    LIMIT 100;
END;
$$;

-- RPC 7: recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2030();
CREATE OR REPLACE FUNCTION public.recent_actions_r2030()
RETURNS TABLE (
  id uuid,
  crisis_id uuid,
  crisis_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.crisis_id, c.crisis_label, a.action_type, a.taken_at, a.by_email
    FROM public.founder_pr_crisis_action_log_r2030 a
    LEFT JOIN public.founder_pr_crisis_playbook_r2030 c ON c.id = a.crisis_id
    ORDER BY a.taken_at DESC
    LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_crises_r2030() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_crisis_r2030(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2030(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2030(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2030(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_crises_r2030() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2030() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_crises_r2030() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_crisis_r2030(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2030(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2030(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2030(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_crises_r2030() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2030() TO authenticated;

COMMIT;
