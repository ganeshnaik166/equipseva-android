BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_side_letter_compliance_r1941 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  side_letter_label text NOT NULL,
  obligation_md text NOT NULL,
  obligation_type text NOT NULL CHECK (obligation_type IN ('reporting','governance','financial','operational','info_rights')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','met','overdue','escalated')),
  due_date date,
  met_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_side_letter_compliance_log_r1941 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compliance_id uuid NOT NULL REFERENCES public.investor_side_letter_compliance_r1941(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('obligation_met','reminder_sent','extension_requested','escalation','non_compliance')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_side_letter_compliance_r1941 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_side_letter_compliance_log_r1941 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS r1941_compliance_founder ON public.investor_side_letter_compliance_r1941;
CREATE POLICY r1941_compliance_founder ON public.investor_side_letter_compliance_r1941
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS r1941_compliance_log_founder ON public.investor_side_letter_compliance_log_r1941;
CREATE POLICY r1941_compliance_log_founder ON public.investor_side_letter_compliance_log_r1941
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_obligations_r1941()
RETURNS TABLE(id uuid, investor_id uuid, side_letter_label text, obligation_md text, obligation_type text, status text, due_date date, met_at timestamptz, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT c.id, c.investor_id, c.side_letter_label, c.obligation_md, c.obligation_type, c.status, c.due_date, c.met_at, c.created_at
    FROM public.investor_side_letter_compliance_r1941 c
    ORDER BY (c.due_date IS NULL), c.due_date ASC, c.created_at DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_obligation_r1941(
  p_investor_id uuid, p_side_letter_label text, p_obligation_md text, p_obligation_type text, p_due_date date
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_side_letter_compliance_r1941(investor_id, side_letter_label, obligation_md, obligation_type, due_date)
    VALUES (p_investor_id, p_side_letter_label, p_obligation_md, p_obligation_type, p_due_date)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_obligation_r1941',
      jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'label', p_side_letter_label, 'type', p_obligation_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r1941(p_compliance_id uuid)
RETURNS TABLE(id uuid, compliance_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.compliance_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.investor_side_letter_compliance_log_r1941 l
    WHERE l.compliance_id = p_compliance_id
    ORDER BY l.taken_at DESC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r1941(
  p_compliance_id uuid, p_action_type text, p_by_email text, p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_side_letter_compliance_log_r1941(compliance_id, action_type, by_email, notes_md)
    VALUES (p_compliance_id, p_action_type, p_by_email, p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1941',
      jsonb_build_object('id', v_id, 'compliance_id', p_compliance_id, 'action', p_action_type));
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r1941(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_side_letter_compliance_r1941
    SET status = p_status,
        met_at = CASE WHEN p_status = 'met' THEN now() ELSE met_at END,
        updated_at = now()
    WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1941',
      jsonb_build_object('id', p_id, 'status', p_status));
END; $$;

CREATE OR REPLACE FUNCTION public.overdue_obligations_r1941()
RETURNS TABLE(id uuid, investor_id uuid, side_letter_label text, obligation_type text, status text, due_date date, days_overdue int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT c.id, c.investor_id, c.side_letter_label, c.obligation_type, c.status, c.due_date,
      (current_date - c.due_date)::int AS days_overdue
    FROM public.investor_side_letter_compliance_r1941 c
    WHERE c.status NOT IN ('met') AND c.due_date IS NOT NULL AND c.due_date < current_date
    ORDER BY c.due_date ASC
    LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1941()
RETURNS TABLE(id uuid, compliance_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.compliance_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.investor_side_letter_compliance_log_r1941 l
    ORDER BY l.taken_at DESC
    LIMIT 100;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_obligations_r1941() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_obligation_r1941(uuid, text, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1941(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1941(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1941(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_obligations_r1941() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1941() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_obligations_r1941() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_obligation_r1941(uuid, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1941(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1941(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1941(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_obligations_r1941() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1941() TO authenticated;

COMMIT;
