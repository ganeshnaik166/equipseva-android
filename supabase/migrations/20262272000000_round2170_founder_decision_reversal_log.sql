BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_decision_reversal_log_r2170 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  original_decision_label text NOT NULL,
  reversed_at timestamptz NOT NULL DEFAULT now(),
  reversal_reason text NOT NULL CHECK (reversal_reason IN ('new_data','changing_market','escalation','board_input','customer_feedback')),
  reversal_md text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','closed','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_reversal_action_log_r2170 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reversal_id uuid NOT NULL REFERENCES public.founder_decision_reversal_log_r2170(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reversed','explained','escalated','closed','lessons_documented')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_decision_reversal_log_r2170 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_reversal_action_log_r2170 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_reversal_r2170 ON public.founder_decision_reversal_log_r2170;
CREATE POLICY founder_all_reversal_r2170 ON public.founder_decision_reversal_log_r2170
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2170 ON public.founder_reversal_action_log_r2170;
CREATE POLICY founder_all_action_r2170 ON public.founder_reversal_action_log_r2170
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- list_reversals
DROP FUNCTION IF EXISTS public.list_reversals_r2170();
CREATE OR REPLACE FUNCTION public.list_reversals_r2170()
RETURNS TABLE (
  id uuid,
  original_decision_label text,
  reversed_at timestamptz,
  reversal_reason text,
  reversal_md text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.original_decision_label, r.reversed_at, r.reversal_reason, r.reversal_md, r.status, r.captured_at
    FROM public.founder_decision_reversal_log_r2170 r
    ORDER BY r.reversed_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_reversals_r2170() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reversals_r2170() TO authenticated;

-- log_reversal
DROP FUNCTION IF EXISTS public.log_reversal_r2170(text, text, text);
CREATE OR REPLACE FUNCTION public.log_reversal_r2170(p_label text, p_reason text, p_md text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_decision_reversal_log_r2170(original_decision_label, reversal_reason, reversal_md)
  VALUES (p_label, p_reason, p_md)
  RETURNING id INTO new_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reversal_r2170', jsonb_build_object('id', new_id, 'label', p_label, 'reason', p_reason));
  RETURN new_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_reversal_r2170(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_reversal_r2170(text, text, text) TO authenticated;

-- list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2170();
CREATE OR REPLACE FUNCTION public.list_actions_r2170()
RETURNS TABLE (
  id uuid,
  reversal_id uuid,
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
    SELECT a.id, a.reversal_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.founder_reversal_action_log_r2170 a
    ORDER BY a.taken_at DESC
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2170() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2170() TO authenticated;

-- log_action
DROP FUNCTION IF EXISTS public.log_action_r2170(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2170(p_reversal_id uuid, p_action_type text, p_by_email text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_reversal_action_log_r2170(reversal_id, action_type, by_email, notes_md)
  VALUES (p_reversal_id, p_action_type, p_by_email, p_notes)
  RETURNING id INTO new_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2170', jsonb_build_object('id', new_id, 'reversal_id', p_reversal_id, 'action_type', p_action_type));
  RETURN new_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2170(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2170(uuid, text, text, text) TO authenticated;

-- mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2170(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2170(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_decision_reversal_log_r2170
     SET status = p_status, updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2170', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2170(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2170(uuid, text) TO authenticated;

-- recent_reversals
DROP FUNCTION IF EXISTS public.recent_reversals_r2170();
CREATE OR REPLACE FUNCTION public.recent_reversals_r2170()
RETURNS TABLE (
  id uuid,
  original_decision_label text,
  reversal_reason text,
  status text,
  reversed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.original_decision_label, r.reversal_reason, r.status, r.reversed_at
    FROM public.founder_decision_reversal_log_r2170 r
    WHERE r.reversed_at >= now() - interval '30 days'
    ORDER BY r.reversed_at DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_reversals_r2170() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_reversals_r2170() TO authenticated;

-- recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2170();
CREATE OR REPLACE FUNCTION public.recent_actions_r2170()
RETURNS TABLE (
  id uuid,
  reversal_id uuid,
  action_type text,
  by_email text,
  taken_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.reversal_id, a.action_type, a.by_email, a.taken_at
    FROM public.founder_reversal_action_log_r2170 a
    WHERE a.taken_at >= now() - interval '30 days'
    ORDER BY a.taken_at DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2170() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2170() TO authenticated;

COMMIT;
