BEGIN;

-- ============================================================================
-- Round 1981 — Investor Audit Trail Compliance
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_audit_trail_compliance_r1981 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  audit_label text NOT NULL,
  audit_type text NOT NULL CHECK (audit_type IN ('financial','operational','regulatory','governance','security')),
  fy_year text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  deadline_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','complete','escalated','extended','missed')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iatc_r1981_status ON public.investor_audit_trail_compliance_r1981(status);
CREATE INDEX IF NOT EXISTS idx_iatc_r1981_deadline ON public.investor_audit_trail_compliance_r1981(deadline_date);
CREATE INDEX IF NOT EXISTS idx_iatc_r1981_investor ON public.investor_audit_trail_compliance_r1981(investor_id);

CREATE TABLE IF NOT EXISTS public.investor_audit_trail_log_r1981 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.investor_audit_trail_compliance_r1981(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('info_requested','info_provided','clarification','audit_session_completed','follow_up_required')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iatl_r1981_audit ON public.investor_audit_trail_log_r1981(audit_id);
CREATE INDEX IF NOT EXISTS idx_iatl_r1981_taken ON public.investor_audit_trail_log_r1981(taken_at DESC);

ALTER TABLE public.investor_audit_trail_compliance_r1981 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_audit_trail_log_r1981 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iatc_r1981_founder_all ON public.investor_audit_trail_compliance_r1981;
CREATE POLICY iatc_r1981_founder_all ON public.investor_audit_trail_compliance_r1981
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS iatl_r1981_founder_all ON public.investor_audit_trail_log_r1981;
CREATE POLICY iatl_r1981_founder_all ON public.investor_audit_trail_log_r1981
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.list_audits_r1981();
CREATE OR REPLACE FUNCTION public.list_audits_r1981()
RETURNS TABLE(
  id uuid,
  investor_email text,
  audit_label text,
  audit_type text,
  fy_year text,
  requested_at timestamptz,
  deadline_date date,
  status text,
  completed_at timestamptz,
  days_to_deadline int
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
  SELECT
    a.id,
    p.email::text,
    a.audit_label,
    a.audit_type,
    a.fy_year,
    a.requested_at,
    a.deadline_date,
    a.status,
    a.completed_at,
    CASE WHEN a.deadline_date IS NOT NULL THEN (a.deadline_date - CURRENT_DATE)::int ELSE NULL END
  FROM public.investor_audit_trail_compliance_r1981 a
  LEFT JOIN public.profiles p ON p.id = a.investor_id
  ORDER BY a.requested_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_audit_r1981(uuid, text, text, text, date);
CREATE OR REPLACE FUNCTION public.log_audit_r1981(
  p_investor_id uuid,
  p_audit_label text,
  p_audit_type text,
  p_fy_year text,
  p_deadline_date date
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
  INSERT INTO public.investor_audit_trail_compliance_r1981(
    investor_id, audit_label, audit_type, fy_year, deadline_date
  ) VALUES (
    p_investor_id, p_audit_label, p_audit_type, p_fy_year, p_deadline_date
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_audit_r1981',
    jsonb_build_object('audit_id', v_id, 'label', p_audit_label, 'type', p_audit_type, 'fy', p_fy_year)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_actions_r1981(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r1981(p_audit_id uuid)
RETURNS TABLE(
  id uuid,
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
  SELECT l.id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.investor_audit_trail_log_r1981 l
  WHERE l.audit_id = p_audit_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_action_r1981(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r1981(
  p_audit_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.investor_audit_trail_log_r1981(
    audit_id, action_type, by_email, notes_md
  ) VALUES (
    p_audit_id, p_action_type, p_by_email, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_action_r1981',
    jsonb_build_object('audit_id', p_audit_id, 'action_type', p_action_type)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_status_r1981(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r1981(p_audit_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('open','in_progress','complete','escalated','extended','missed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;
  UPDATE public.investor_audit_trail_compliance_r1981
  SET status = p_status,
      completed_at = CASE WHEN p_status = 'complete' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_audit_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r1981',
    jsonb_build_object('audit_id', p_audit_id, 'status', p_status)
  );
END;
$$;

DROP FUNCTION IF EXISTS public.overdue_audits_r1981();
CREATE OR REPLACE FUNCTION public.overdue_audits_r1981()
RETURNS TABLE(
  id uuid,
  audit_label text,
  audit_type text,
  fy_year text,
  deadline_date date,
  status text,
  days_overdue int
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
  SELECT
    a.id,
    a.audit_label,
    a.audit_type,
    a.fy_year,
    a.deadline_date,
    a.status,
    (CURRENT_DATE - a.deadline_date)::int
  FROM public.investor_audit_trail_compliance_r1981 a
  WHERE a.deadline_date IS NOT NULL
    AND a.deadline_date < CURRENT_DATE
    AND a.status NOT IN ('complete','extended')
  ORDER BY a.deadline_date ASC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.recent_actions_r1981();
CREATE OR REPLACE FUNCTION public.recent_actions_r1981()
RETURNS TABLE(
  id uuid,
  audit_id uuid,
  audit_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
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
  SELECT
    l.id,
    l.audit_id,
    a.audit_label,
    l.action_type,
    l.taken_at,
    l.by_email
  FROM public.investor_audit_trail_log_r1981 l
  JOIN public.investor_audit_trail_compliance_r1981 a ON a.id = l.audit_id
  ORDER BY l.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_audits_r1981() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_audit_r1981(uuid, text, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1981(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1981(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1981(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_audits_r1981() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1981() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audits_r1981() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_audit_r1981(uuid, text, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1981(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1981(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1981(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_audits_r1981() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1981() TO authenticated;

COMMIT;
