BEGIN;

-- ============================================================================
-- Round 2118 — Founder Hire-Manage-Coach Cycle
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_hire_manage_coach_cycle_r2118 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  direct_report_name text NOT NULL,
  role_label text NOT NULL,
  hired_at timestamptz,
  current_cycle_phase text NOT NULL CHECK (current_cycle_phase IN ('onboarding','established','coaching','at_risk','exit_planning','departed')),
  last_review_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','departed','promoted_out','on_leave')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_coaching_session_log_r2118 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.founder_hire_manage_coach_cycle_r2118(id) ON DELETE CASCADE,
  session_type text NOT NULL CHECK (session_type IN ('1on1','check_in','feedback','coaching','exit_interview')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_hire_manage_coach_cycle_r2118 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_coaching_session_log_r2118 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cycle_r2118 ON public.founder_hire_manage_coach_cycle_r2118;
CREATE POLICY founder_all_cycle_r2118 ON public.founder_hire_manage_coach_cycle_r2118
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_sessions_r2118 ON public.founder_coaching_session_log_r2118;
CREATE POLICY founder_all_sessions_r2118 ON public.founder_coaching_session_log_r2118
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1 — list_reports
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_reports_r2118()
RETURNS TABLE(
  id uuid,
  direct_report_name text,
  role_label text,
  hired_at timestamptz,
  current_cycle_phase text,
  last_review_at timestamptz,
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
    SELECT r.id, r.direct_report_name, r.role_label, r.hired_at,
           r.current_cycle_phase, r.last_review_at, r.status, r.captured_at
    FROM public.founder_hire_manage_coach_cycle_r2118 r
    ORDER BY r.captured_at DESC
    LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2 — log_report (insert new direct report)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_report_r2118(
  p_name text,
  p_role text,
  p_hired_at timestamptz,
  p_phase text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.founder_hire_manage_coach_cycle_r2118(
    direct_report_name, role_label, hired_at, current_cycle_phase, status
  ) VALUES (
    p_name, p_role, p_hired_at, COALESCE(p_phase,'onboarding'), COALESCE(p_status,'active')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_report_r2118',
    jsonb_build_object('id', v_id, 'name', p_name, 'role', p_role, 'phase', p_phase)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3 — list_sessions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_sessions_r2118(p_report_id uuid)
RETURNS TABLE(
  id uuid,
  report_id uuid,
  session_type text,
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
    SELECT s.id, s.report_id, s.session_type, s.taken_at, s.by_email, s.notes_md
    FROM public.founder_coaching_session_log_r2118 s
    WHERE s.report_id = p_report_id
    ORDER BY s.taken_at DESC
    LIMIT 100;
END;
$$;

-- ============================================================================
-- RPC 4 — log_session
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_session_r2118(
  p_report_id uuid,
  p_session_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.founder_coaching_session_log_r2118(
    report_id, session_type, by_email, notes_md
  ) VALUES (
    p_report_id, p_session_type, v_email, p_notes_md
  ) RETURNING id INTO v_id;

  UPDATE public.founder_hire_manage_coach_cycle_r2118
     SET last_review_at = now(),
         updated_at = now()
   WHERE id = p_report_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_session_r2118',
    jsonb_build_object('id', v_id, 'report_id', p_report_id, 'session_type', p_session_type)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5 — mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2118(
  p_report_id uuid,
  p_status text,
  p_phase text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.founder_hire_manage_coach_cycle_r2118
     SET status = COALESCE(p_status, status),
         current_cycle_phase = COALESCE(p_phase, current_cycle_phase),
         updated_at = now()
   WHERE id = p_report_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r2118',
    jsonb_build_object('report_id', p_report_id, 'status', p_status, 'phase', p_phase)
  );
END;
$$;

-- ============================================================================
-- RPC 6 — at_risk (reports in at_risk or exit_planning phases)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.at_risk_r2118()
RETURNS TABLE(
  id uuid,
  direct_report_name text,
  role_label text,
  current_cycle_phase text,
  last_review_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.direct_report_name, r.role_label, r.current_cycle_phase,
           r.last_review_at, r.status
    FROM public.founder_hire_manage_coach_cycle_r2118 r
    WHERE r.current_cycle_phase IN ('at_risk','exit_planning')
      AND r.status = 'active'
    ORDER BY r.last_review_at NULLS FIRST, r.captured_at DESC
    LIMIT 100;
END;
$$;

-- ============================================================================
-- RPC 7 — recent_sessions (last 30d across all reports)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_sessions_r2118()
RETURNS TABLE(
  id uuid,
  report_id uuid,
  direct_report_name text,
  session_type text,
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
    SELECT s.id, s.report_id, r.direct_report_name, s.session_type, s.taken_at, s.by_email
    FROM public.founder_coaching_session_log_r2118 s
    JOIN public.founder_hire_manage_coach_cycle_r2118 r ON r.id = s.report_id
    WHERE s.taken_at > now() - interval '30 days'
    ORDER BY s.taken_at DESC
    LIMIT 200;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_reports_r2118() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_report_r2118(text, text, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_sessions_r2118(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_session_r2118(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2118(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.at_risk_r2118() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_sessions_r2118() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reports_r2118() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_report_r2118(text, text, timestamptz, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_sessions_r2118(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_session_r2118(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2118(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.at_risk_r2118() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_sessions_r2118() TO authenticated;

COMMIT;
