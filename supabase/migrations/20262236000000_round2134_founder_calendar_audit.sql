BEGIN;

-- ============================================================================
-- Round 2134: Founder Calendar Audit
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_calendar_audit_r2134 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_label text NOT NULL,
  total_scheduled_hours numeric NOT NULL DEFAULT 0,
  productive_hours numeric NOT NULL DEFAULT 0,
  wasted_hours numeric NOT NULL DEFAULT 0,
  audit_score int NOT NULL DEFAULT 0 CHECK (audit_score >= 0 AND audit_score <= 100),
  status text NOT NULL DEFAULT 'needs_work' CHECK (status IN ('excellent','good','needs_work','poor')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_calendar_audit_action_log_r2134 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.founder_calendar_audit_r2134(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('meeting_killed','batched','delegated','moved','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_calendar_audit_r2134 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_calendar_audit_action_log_r2134 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_calendar_audit_r2134_founder_all ON public.founder_calendar_audit_r2134;
CREATE POLICY founder_calendar_audit_r2134_founder_all
  ON public.founder_calendar_audit_r2134
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_calendar_audit_action_log_r2134_founder_all ON public.founder_calendar_audit_action_log_r2134;
CREATE POLICY founder_calendar_audit_action_log_r2134_founder_all
  ON public.founder_calendar_audit_action_log_r2134
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_audits
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_calendar_audit_r2134_list_audits()
RETURNS TABLE (
  id uuid,
  week_label text,
  total_scheduled_hours numeric,
  productive_hours numeric,
  wasted_hours numeric,
  audit_score int,
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
  SELECT a.id, a.week_label, a.total_scheduled_hours, a.productive_hours,
         a.wasted_hours, a.audit_score, a.status, a.captured_at
  FROM public.founder_calendar_audit_r2134 a
  ORDER BY a.captured_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_audit
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_calendar_audit_r2134_log_audit(
  p_week_label text,
  p_total_scheduled_hours numeric,
  p_productive_hours numeric,
  p_wasted_hours numeric,
  p_audit_score int,
  p_status text
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
  INSERT INTO public.founder_calendar_audit_r2134(
    week_label, total_scheduled_hours, productive_hours, wasted_hours, audit_score, status
  ) VALUES (
    p_week_label, p_total_scheduled_hours, p_productive_hours, p_wasted_hours, p_audit_score, p_status
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_calendar_audit_r2134_log_audit',
    jsonb_build_object(
      'audit_id', v_id,
      'week_label', p_week_label,
      'audit_score', p_audit_score,
      'status', p_status
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_calendar_audit_r2134_list_actions(p_audit_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  audit_id uuid,
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
  SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.founder_calendar_audit_action_log_r2134 l
  WHERE p_audit_id IS NULL OR l.audit_id = p_audit_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_calendar_audit_r2134_log_action(
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
  INSERT INTO public.founder_calendar_audit_action_log_r2134(
    audit_id, action_type, by_email, notes_md
  ) VALUES (
    p_audit_id, p_action_type, p_by_email, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_calendar_audit_r2134_log_action',
    jsonb_build_object(
      'action_id', v_id,
      'audit_id', p_audit_id,
      'action_type', p_action_type
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_calendar_audit_r2134_mark_status(
  p_id uuid,
  p_status text
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
  UPDATE public.founder_calendar_audit_r2134
     SET status = p_status, updated_at = now()
   WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_calendar_audit_r2134_mark_status',
    jsonb_build_object('audit_id', p_id, 'status', p_status)
  );
END;
$$;

-- ============================================================================
-- RPC 6: top_weeks
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_calendar_audit_r2134_top_weeks()
RETURNS TABLE (
  id uuid,
  week_label text,
  audit_score int,
  productive_hours numeric,
  wasted_hours numeric,
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
  SELECT a.id, a.week_label, a.audit_score, a.productive_hours,
         a.wasted_hours, a.status, a.captured_at
  FROM public.founder_calendar_audit_r2134 a
  ORDER BY a.audit_score DESC, a.captured_at DESC
  LIMIT 20;
END;
$$;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_calendar_audit_r2134_recent_actions()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  week_label text,
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
  SELECT l.id, l.audit_id, a.week_label, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.founder_calendar_audit_action_log_r2134 l
  LEFT JOIN public.founder_calendar_audit_r2134 a ON a.id = l.audit_id
  ORDER BY l.taken_at DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_list_audits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_list_audits() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_log_audit(text, numeric, numeric, numeric, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_log_audit(text, numeric, numeric, numeric, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_list_actions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_list_actions(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_log_action(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_log_action(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_mark_status(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_top_weeks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_top_weeks() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_recent_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_calendar_audit_r2134_recent_actions() TO authenticated;

COMMIT;
