BEGIN;

-- ============================================================================
-- Round 2054 — Founder Pitch Refinement Cycle
-- Track pitch refinement iterations and qualitative signals from investor convos
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_pitch_refinement_cycle_r2054 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pitch_version_label text NOT NULL,
  key_changes_md text,
  audience_segment text NOT NULL CHECK (audience_segment IN ('angel','seed','series_a','strategic','family_office','general')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','superseded','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_pitch_signal_log_r2054 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id uuid NOT NULL REFERENCES public.founder_pitch_refinement_cycle_r2054(id) ON DELETE CASCADE,
  signal_type text NOT NULL CHECK (signal_type IN ('positive_reaction','concern_raised','strong_question','skepticism','closed_deal')),
  signal_md text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_pitch_refinement_cycle_r2054 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_pitch_signal_log_r2054 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cycle_r2054 ON public.founder_pitch_refinement_cycle_r2054;
CREATE POLICY founder_all_cycle_r2054 ON public.founder_pitch_refinement_cycle_r2054
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_signal_r2054 ON public.founder_pitch_signal_log_r2054;
CREATE POLICY founder_all_signal_r2054 ON public.founder_pitch_signal_log_r2054
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_versions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_pitch_list_versions_r2054()
RETURNS TABLE (
  id uuid,
  pitch_version_label text,
  audience_segment text,
  status text,
  key_changes_md text,
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
  SELECT v.id, v.pitch_version_label, v.audience_segment, v.status, v.key_changes_md, v.captured_at
  FROM public.founder_pitch_refinement_cycle_r2054 v
  ORDER BY v.captured_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_version
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_pitch_log_version_r2054(
  p_label text,
  p_key_changes_md text,
  p_audience text
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

  INSERT INTO public.founder_pitch_refinement_cycle_r2054(
    pitch_version_label, key_changes_md, audience_segment, status
  )
  VALUES (p_label, p_key_changes_md, p_audience, 'active')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_pitch_log_version_r2054',
    jsonb_build_object('id', v_id, 'label', p_label, 'audience', p_audience)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_signals
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_pitch_list_signals_r2054()
RETURNS TABLE (
  id uuid,
  version_id uuid,
  pitch_version_label text,
  signal_type text,
  signal_md text,
  recorded_at timestamptz,
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
  SELECT s.id, s.version_id, v.pitch_version_label, s.signal_type, s.signal_md, s.recorded_at, s.by_email
  FROM public.founder_pitch_signal_log_r2054 s
  LEFT JOIN public.founder_pitch_refinement_cycle_r2054 v ON v.id = s.version_id
  ORDER BY s.recorded_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_signal
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_pitch_log_signal_r2054(
  p_version_id uuid,
  p_signal_type text,
  p_signal_md text,
  p_by_email text
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

  INSERT INTO public.founder_pitch_signal_log_r2054(
    version_id, signal_type, signal_md, by_email
  )
  VALUES (p_version_id, p_signal_type, p_signal_md, p_by_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_pitch_log_signal_r2054',
    jsonb_build_object('id', v_id, 'version_id', p_version_id, 'signal_type', p_signal_type)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_pitch_mark_status_r2054(
  p_version_id uuid,
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

  UPDATE public.founder_pitch_refinement_cycle_r2054
  SET status = p_status, updated_at = now()
  WHERE id = p_version_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_pitch_mark_status_r2054',
    jsonb_build_object('id', p_version_id, 'status', p_status)
  );
END;
$$;

-- ============================================================================
-- RPC 6: current_pitch
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_pitch_current_pitch_r2054()
RETURNS TABLE (
  id uuid,
  pitch_version_label text,
  audience_segment text,
  status text,
  key_changes_md text,
  captured_at timestamptz,
  signal_count bigint
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
  SELECT v.id, v.pitch_version_label, v.audience_segment, v.status, v.key_changes_md, v.captured_at,
         (SELECT COUNT(*) FROM public.founder_pitch_signal_log_r2054 s WHERE s.version_id = v.id)
  FROM public.founder_pitch_refinement_cycle_r2054 v
  WHERE v.status = 'active'
  ORDER BY v.captured_at DESC
  LIMIT 5;
END;
$$;

-- ============================================================================
-- RPC 7: recent_signals
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_pitch_recent_signals_r2054()
RETURNS TABLE (
  signal_type text,
  signal_count bigint,
  latest_signal timestamptz
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
  SELECT s.signal_type,
         COUNT(*)::bigint,
         MAX(s.recorded_at)
  FROM public.founder_pitch_signal_log_r2054 s
  WHERE s.recorded_at > now() - interval '90 days'
  GROUP BY s.signal_type
  ORDER BY COUNT(*) DESC;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.founder_pitch_list_versions_r2054() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_pitch_log_version_r2054(text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_pitch_list_signals_r2054() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_pitch_log_signal_r2054(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_pitch_mark_status_r2054(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_pitch_current_pitch_r2054() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_pitch_recent_signals_r2054() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_pitch_list_versions_r2054() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pitch_log_version_r2054(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pitch_list_signals_r2054() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pitch_log_signal_r2054(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pitch_mark_status_r2054(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pitch_current_pitch_r2054() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_pitch_recent_signals_r2054() TO authenticated;

COMMIT;
