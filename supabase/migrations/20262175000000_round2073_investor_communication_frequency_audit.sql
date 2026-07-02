BEGIN;

-- ============================================================================
-- Round 2073 — Investor Communication Frequency Audit
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_communication_frequency_audit_r2073 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  audit_period_label text NOT NULL,
  communications_count int NOT NULL DEFAULT 0,
  avg_days_between_touches numeric(10,2),
  status text NOT NULL DEFAULT 'sufficient'
    CHECK (status IN ('sufficient','inadequate','excellent','needs_recalibration')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icfa_r2073_investor
  ON public.investor_communication_frequency_audit_r2073(investor_id);
CREATE INDEX IF NOT EXISTS idx_icfa_r2073_status
  ON public.investor_communication_frequency_audit_r2073(status);
CREATE INDEX IF NOT EXISTS idx_icfa_r2073_captured
  ON public.investor_communication_frequency_audit_r2073(captured_at DESC);

ALTER TABLE public.investor_communication_frequency_audit_r2073 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS icfa_r2073_founder_all ON public.investor_communication_frequency_audit_r2073;
CREATE POLICY icfa_r2073_founder_all ON public.investor_communication_frequency_audit_r2073
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_frequency_action_log_r2073 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.investor_communication_frequency_audit_r2073(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('increased_frequency','decreased_frequency','escalation','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ifal_r2073_audit
  ON public.investor_frequency_action_log_r2073(audit_id);
CREATE INDEX IF NOT EXISTS idx_ifal_r2073_taken
  ON public.investor_frequency_action_log_r2073(taken_at DESC);

ALTER TABLE public.investor_frequency_action_log_r2073 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ifal_r2073_founder_all ON public.investor_frequency_action_log_r2073;
CREATE POLICY ifal_r2073_founder_all ON public.investor_frequency_action_log_r2073
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_audits
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_investor_freq_audits_r2073()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  audit_period_label text,
  communications_count int,
  avg_days_between_touches numeric,
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
    SELECT a.id, a.investor_id, a.audit_period_label, a.communications_count,
           a.avg_days_between_touches, a.status, a.captured_at
    FROM public.investor_communication_frequency_audit_r2073 a
    ORDER BY a.captured_at DESC
    LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_audit
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_investor_freq_audit_r2073(
  p_investor_id uuid,
  p_audit_period_label text,
  p_communications_count int,
  p_avg_days numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_communication_frequency_audit_r2073
    (investor_id, audit_period_label, communications_count, avg_days_between_touches, status)
  VALUES (p_investor_id, p_audit_period_label, p_communications_count, p_avg_days, p_status)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'log_investor_freq_audit_r2073',
          jsonb_build_object('audit_id', v_id, 'investor_id', p_investor_id, 'status', p_status));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_investor_freq_actions_r2073(p_audit_id uuid)
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.investor_frequency_action_log_r2073 l
    WHERE l.audit_id = p_audit_id
    ORDER BY l.taken_at DESC;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_investor_freq_action_r2073(
  p_audit_id uuid,
  p_action_type text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.investor_frequency_action_log_r2073
    (audit_id, action_type, by_email, notes_md)
  VALUES (p_audit_id, p_action_type, v_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email,
          'log_investor_freq_action_r2073',
          jsonb_build_object('action_id', v_id, 'audit_id', p_audit_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_investor_freq_status_r2073(
  p_audit_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_communication_frequency_audit_r2073
  SET status = p_status, updated_at = now()
  WHERE id = p_audit_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'mark_investor_freq_status_r2073',
          jsonb_build_object('audit_id', p_audit_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: inadequate_freq
-- ============================================================================
CREATE OR REPLACE FUNCTION public.inadequate_investor_freq_r2073()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  audit_period_label text,
  communications_count int,
  avg_days_between_touches numeric,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.investor_id, a.audit_period_label, a.communications_count,
           a.avg_days_between_touches, a.captured_at
    FROM public.investor_communication_frequency_audit_r2073 a
    WHERE a.status IN ('inadequate','needs_recalibration')
    ORDER BY a.captured_at DESC
    LIMIT 100;
END;
$$;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_investor_freq_actions_r2073()
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.investor_frequency_action_log_r2073 l
    ORDER BY l.taken_at DESC
    LIMIT 100;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_investor_freq_audits_r2073() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_freq_audits_r2073() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_freq_audit_r2073(uuid, text, int, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_freq_audit_r2073(uuid, text, int, numeric, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_investor_freq_actions_r2073(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_investor_freq_actions_r2073(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_investor_freq_action_r2073(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_investor_freq_action_r2073(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_investor_freq_status_r2073(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_investor_freq_status_r2073(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.inadequate_investor_freq_r2073() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.inadequate_investor_freq_r2073() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_investor_freq_actions_r2073() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_investor_freq_actions_r2073() TO authenticated;

COMMIT;
