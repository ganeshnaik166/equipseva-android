BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_reporting_compliance_log_r2125 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  report_label text NOT NULL,
  report_type text NOT NULL CHECK (report_type IN ('monthly','quarterly','annual','audit','incident')),
  due_date date NOT NULL,
  sent_date date,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','overdue','exempted')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ircl_r2125_investor ON public.investor_reporting_compliance_log_r2125(investor_id);
CREATE INDEX IF NOT EXISTS idx_ircl_r2125_due ON public.investor_reporting_compliance_log_r2125(due_date DESC);
CREATE INDEX IF NOT EXISTS idx_ircl_r2125_status ON public.investor_reporting_compliance_log_r2125(status);

CREATE TABLE IF NOT EXISTS public.investor_compliance_action_log_r2125 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.investor_reporting_compliance_log_r2125(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('drafted','sent','escalated','exempted','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ical_r2125_report ON public.investor_compliance_action_log_r2125(report_id);
CREATE INDEX IF NOT EXISTS idx_ical_r2125_taken ON public.investor_compliance_action_log_r2125(taken_at DESC);

ALTER TABLE public.investor_reporting_compliance_log_r2125 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_compliance_action_log_r2125 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ircl_r2125_founder_all ON public.investor_reporting_compliance_log_r2125;
CREATE POLICY ircl_r2125_founder_all ON public.investor_reporting_compliance_log_r2125
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ical_r2125_founder_all ON public.investor_compliance_action_log_r2125;
CREATE POLICY ical_r2125_founder_all ON public.investor_compliance_action_log_r2125
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_reports
CREATE OR REPLACE FUNCTION public.list_investor_reports_r2125(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  report_label text,
  report_type text,
  due_date date,
  sent_date date,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.investor_id, r.report_label, r.report_type, r.due_date, r.sent_date, r.status, r.captured_at
  FROM public.investor_reporting_compliance_log_r2125 r
  ORDER BY r.due_date DESC NULLS LAST, r.captured_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 2: log_report
CREATE OR REPLACE FUNCTION public.log_investor_report_r2125(
  p_investor_id uuid,
  p_report_label text,
  p_report_type text,
  p_due_date date,
  p_sent_date date DEFAULT NULL,
  p_status text DEFAULT 'pending'
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
  INSERT INTO public.investor_reporting_compliance_log_r2125(investor_id, report_label, report_type, due_date, sent_date, status)
  VALUES (p_investor_id, p_report_label, p_report_type, p_due_date, p_sent_date, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_investor_report_r2125',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'report_label', p_report_label, 'report_type', p_report_type, 'due_date', p_due_date, 'status', p_status)
  );
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
CREATE OR REPLACE FUNCTION public.list_investor_compliance_actions_r2125(p_report_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  report_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.report_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_compliance_action_log_r2125 a
  WHERE p_report_id IS NULL OR a.report_id = p_report_id
  ORDER BY a.taken_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 4: log_action
CREATE OR REPLACE FUNCTION public.log_investor_compliance_action_r2125(
  p_report_id uuid,
  p_action_type text,
  p_by_email text DEFAULT NULL,
  p_notes_md text DEFAULT NULL
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
  INSERT INTO public.investor_compliance_action_log_r2125(report_id, action_type, by_email, notes_md)
  VALUES (p_report_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_investor_compliance_action_r2125',
    jsonb_build_object('id', v_id, 'report_id', p_report_id, 'action_type', p_action_type, 'by_email', p_by_email)
  );
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_investor_report_status_r2125(
  p_report_id uuid,
  p_status text,
  p_sent_date date DEFAULT NULL
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
  UPDATE public.investor_reporting_compliance_log_r2125
  SET status = p_status,
      sent_date = COALESCE(p_sent_date, sent_date),
      updated_at = now()
  WHERE id = p_report_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_investor_report_status_r2125',
    jsonb_build_object('report_id', p_report_id, 'status', p_status, 'sent_date', p_sent_date)
  );
END;
$$;

-- RPC 6: overdue
CREATE OR REPLACE FUNCTION public.overdue_investor_reports_r2125()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  report_label text,
  report_type text,
  due_date date,
  days_overdue int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.investor_id, r.report_label, r.report_type, r.due_date,
         (CURRENT_DATE - r.due_date)::int AS days_overdue,
         r.status
  FROM public.investor_reporting_compliance_log_r2125 r
  WHERE r.status IN ('pending','overdue')
    AND r.due_date < CURRENT_DATE
  ORDER BY r.due_date ASC
  LIMIT 200;
END;
$$;

-- RPC 7: recent_actions
CREATE OR REPLACE FUNCTION public.recent_investor_compliance_actions_r2125(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  report_id uuid,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.report_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_compliance_action_log_r2125 a
  ORDER BY a.taken_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_investor_reports_r2125(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_report_r2125(uuid, text, text, date, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_compliance_actions_r2125(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_investor_compliance_action_r2125(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_investor_report_status_r2125(uuid, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_investor_reports_r2125() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_investor_compliance_actions_r2125(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_reports_r2125(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_report_r2125(uuid, text, text, date, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_compliance_actions_r2125(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_investor_compliance_action_r2125(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_investor_report_status_r2125(uuid, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_investor_reports_r2125() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_investor_compliance_actions_r2125(int) TO authenticated;

COMMIT;
