BEGIN;

-- ============================================================================
-- Round 2086 — Founder Investor Backchannel Notes
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_investor_backchannel_notes_r2086 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_label text NOT NULL,
  note_md text NOT NULL,
  sensitivity text NOT NULL DEFAULT 'internal_only'
    CHECK (sensitivity IN ('public_ok','internal_only','founder_only','highly_confidential')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','archived','superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_backchannel_action_log_r2086 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES public.founder_investor_backchannel_notes_r2086(id) ON DELETE CASCADE,
  action_type text NOT NULL
    CHECK (action_type IN ('noted','escalated','acted_on','closed','archived')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_backchannel_notes_r2086_captured ON public.founder_investor_backchannel_notes_r2086(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_backchannel_notes_r2086_status ON public.founder_investor_backchannel_notes_r2086(status);
CREATE INDEX IF NOT EXISTS idx_backchannel_notes_r2086_sensitivity ON public.founder_investor_backchannel_notes_r2086(sensitivity);
CREATE INDEX IF NOT EXISTS idx_backchannel_action_log_r2086_note ON public.founder_backchannel_action_log_r2086(note_id, taken_at DESC);

ALTER TABLE public.founder_investor_backchannel_notes_r2086 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_backchannel_action_log_r2086 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_backchannel_notes_r2086 ON public.founder_investor_backchannel_notes_r2086;
CREATE POLICY founder_all_backchannel_notes_r2086 ON public.founder_investor_backchannel_notes_r2086
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_backchannel_actions_r2086 ON public.founder_backchannel_action_log_r2086;
CREATE POLICY founder_all_backchannel_actions_r2086 ON public.founder_backchannel_action_log_r2086
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_notes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_backchannel_notes_r2086()
RETURNS TABLE (
  id uuid,
  investor_label text,
  note_md text,
  sensitivity text,
  captured_at timestamptz,
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
  SELECT n.id, n.investor_label, n.note_md, n.sensitivity, n.captured_at, n.status
  FROM public.founder_investor_backchannel_notes_r2086 n
  ORDER BY n.captured_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================================
-- RPC 2: log_note
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_backchannel_note_r2086(
  p_investor_label text,
  p_note_md text,
  p_sensitivity text DEFAULT 'internal_only'
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
  INSERT INTO public.founder_investor_backchannel_notes_r2086(investor_label, note_md, sensitivity)
  VALUES (p_investor_label, p_note_md, COALESCE(p_sensitivity, 'internal_only'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_backchannel_note_r2086',
    jsonb_build_object('id', v_id, 'investor_label', p_investor_label, 'sensitivity', p_sensitivity));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_backchannel_actions_r2086(p_note_id uuid)
RETURNS TABLE (
  id uuid,
  note_id uuid,
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
  SELECT a.id, a.note_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.founder_backchannel_action_log_r2086 a
  WHERE a.note_id = p_note_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_backchannel_action_r2086(
  p_note_id uuid,
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
  INSERT INTO public.founder_backchannel_action_log_r2086(note_id, action_type, by_email, notes_md)
  VALUES (p_note_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_backchannel_action_r2086',
    jsonb_build_object('id', v_id, 'note_id', p_note_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_backchannel_status_r2086(
  p_note_id uuid,
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
  UPDATE public.founder_investor_backchannel_notes_r2086
  SET status = p_status, updated_at = now()
  WHERE id = p_note_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_backchannel_status_r2086',
    jsonb_build_object('id', p_note_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: sensitive_notes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sensitive_backchannel_notes_r2086()
RETURNS TABLE (
  id uuid,
  investor_label text,
  sensitivity text,
  captured_at timestamptz,
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
  SELECT n.id, n.investor_label, n.sensitivity, n.captured_at, n.status
  FROM public.founder_investor_backchannel_notes_r2086 n
  WHERE n.sensitivity IN ('founder_only','highly_confidential')
    AND n.status = 'active'
  ORDER BY n.captured_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_backchannel_actions_r2086()
RETURNS TABLE (
  id uuid,
  note_id uuid,
  investor_label text,
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
  SELECT a.id, a.note_id, n.investor_label, a.action_type, a.taken_at, a.by_email
  FROM public.founder_backchannel_action_log_r2086 a
  JOIN public.founder_investor_backchannel_notes_r2086 n ON n.id = a.note_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_backchannel_notes_r2086() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_backchannel_note_r2086(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_backchannel_actions_r2086(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_backchannel_action_r2086(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_backchannel_status_r2086(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.sensitive_backchannel_notes_r2086() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_backchannel_actions_r2086() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_backchannel_notes_r2086() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_backchannel_note_r2086(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_backchannel_actions_r2086(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_backchannel_action_r2086(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_backchannel_status_r2086(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sensitive_backchannel_notes_r2086() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_backchannel_actions_r2086() TO authenticated;

COMMIT;
