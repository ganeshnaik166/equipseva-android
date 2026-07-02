BEGIN;

-- ============================================================================
-- Round 1781 — Investor Reporting Calendar
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_reporting_calendar_r1781 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type text NOT NULL CHECK (report_type IN ('monthly_update','quarterly','annual','board_pack','special_ask')),
  fiscal_year int NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','in_progress','sent','late','cancelled')),
  owner_email text,
  distribution_list_email text[] NOT NULL DEFAULT '{}',
  notes text,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_reporting_deliverables_r1781 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  calendar_id uuid NOT NULL REFERENCES public.investor_reporting_calendar_r1781(id) ON DELETE CASCADE,
  deliverable_name text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','skipped')),
  completed_at timestamptz,
  delegate_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irc_r1781_due ON public.investor_reporting_calendar_r1781(due_date);
CREATE INDEX IF NOT EXISTS idx_irc_r1781_status ON public.investor_reporting_calendar_r1781(status);
CREATE INDEX IF NOT EXISTS idx_ird_r1781_cal ON public.investor_reporting_deliverables_r1781(calendar_id);

ALTER TABLE public.investor_reporting_calendar_r1781 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_reporting_deliverables_r1781 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS irc_r1781_founder ON public.investor_reporting_calendar_r1781;
CREATE POLICY irc_r1781_founder ON public.investor_reporting_calendar_r1781
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ird_r1781_founder ON public.investor_reporting_deliverables_r1781;
CREATE POLICY ird_r1781_founder ON public.investor_reporting_deliverables_r1781
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_calendar
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_calendar_r1781()
RETURNS TABLE (
  id uuid,
  report_type text,
  fiscal_year int,
  due_date date,
  status text,
  owner_email text,
  distribution_count int,
  days_until int,
  sent_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.report_type,
    c.fiscal_year,
    c.due_date,
    c.status,
    c.owner_email,
    COALESCE(array_length(c.distribution_list_email, 1), 0)::int AS distribution_count,
    (c.due_date - CURRENT_DATE)::int AS days_until,
    c.sent_at
  FROM public.investor_reporting_calendar_r1781 c
  ORDER BY c.due_date ASC;
END;
$$;

-- ============================================================================
-- RPC 2: schedule_report
-- ============================================================================
CREATE OR REPLACE FUNCTION public.schedule_report_r1781(
  p_report_type text,
  p_fiscal_year int,
  p_due_date date,
  p_owner_email text,
  p_distribution text[]
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_reporting_calendar_r1781
    (report_type, fiscal_year, due_date, owner_email, distribution_list_email)
  VALUES
    (p_report_type, p_fiscal_year, p_due_date, p_owner_email, COALESCE(p_distribution, '{}'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'schedule_report_r1781',
    jsonb_build_object('id', v_id, 'report_type', p_report_type, 'due_date', p_due_date));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_deliverables
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_deliverables_r1781(p_calendar_id uuid)
RETURNS TABLE (
  id uuid,
  calendar_id uuid,
  deliverable_name text,
  status text,
  completed_at timestamptz,
  delegate_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.calendar_id, d.deliverable_name, d.status, d.completed_at, d.delegate_email
  FROM public.investor_reporting_deliverables_r1781 d
  WHERE d.calendar_id = p_calendar_id
  ORDER BY d.created_at ASC;
END;
$$;

-- ============================================================================
-- RPC 4: complete_deliverable
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_deliverable_r1781(p_deliverable_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_reporting_deliverables_r1781
  SET status = 'done', completed_at = now(), updated_at = now()
  WHERE id = p_deliverable_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'complete_deliverable_r1781',
    jsonb_build_object('id', p_deliverable_id));
END;
$$;

-- ============================================================================
-- RPC 5: mark_sent
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_sent_r1781(p_calendar_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_reporting_calendar_r1781
  SET status = 'sent', sent_at = now(), updated_at = now()
  WHERE id = p_calendar_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_sent_r1781',
    jsonb_build_object('id', p_calendar_id));
END;
$$;

-- ============================================================================
-- RPC 6: upcoming_reports
-- ============================================================================
CREATE OR REPLACE FUNCTION public.upcoming_reports_r1781()
RETURNS TABLE (
  id uuid,
  report_type text,
  due_date date,
  days_until int,
  owner_email text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.report_type, c.due_date, (c.due_date - CURRENT_DATE)::int AS days_until,
    c.owner_email, c.status
  FROM public.investor_reporting_calendar_r1781 c
  WHERE c.due_date >= CURRENT_DATE
    AND c.status IN ('upcoming','in_progress')
  ORDER BY c.due_date ASC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- RPC 7: late_reports
-- ============================================================================
CREATE OR REPLACE FUNCTION public.late_reports_r1781()
RETURNS TABLE (
  id uuid,
  report_type text,
  due_date date,
  days_late int,
  owner_email text,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.report_type, c.due_date, (CURRENT_DATE - c.due_date)::int AS days_late,
    c.owner_email, c.status
  FROM public.investor_reporting_calendar_r1781 c
  WHERE c.due_date < CURRENT_DATE
    AND c.status NOT IN ('sent','cancelled')
  ORDER BY c.due_date ASC;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_calendar_r1781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_calendar_r1781() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.schedule_report_r1781(text,int,date,text,text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.schedule_report_r1781(text,int,date,text,text[]) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_deliverables_r1781(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_deliverables_r1781(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.complete_deliverable_r1781(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_deliverable_r1781(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_sent_r1781(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_sent_r1781(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.upcoming_reports_r1781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upcoming_reports_r1781() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.late_reports_r1781() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.late_reports_r1781() TO authenticated;

COMMIT;