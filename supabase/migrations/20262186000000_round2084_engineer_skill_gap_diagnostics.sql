BEGIN;

-- =========================================================================
-- round 2084 — engineer skill gap diagnostics
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.engineer_skill_gap_diagnostics_r2084 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  skill_area text NOT NULL CHECK (skill_area IN ('imaging','ventilator','customer_handling','safety','business','leadership')),
  gap_severity text NOT NULL CHECK (gap_severity IN ('none','minor','moderate','major','critical')),
  prescribed_training_md text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','training_assigned','closed','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_skill_gap_diag_r2084_engineer
  ON public.engineer_skill_gap_diagnostics_r2084 (engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_skill_gap_diag_r2084_status
  ON public.engineer_skill_gap_diagnostics_r2084 (status);
CREATE INDEX IF NOT EXISTS idx_eng_skill_gap_diag_r2084_severity
  ON public.engineer_skill_gap_diagnostics_r2084 (gap_severity);
CREATE INDEX IF NOT EXISTS idx_eng_skill_gap_diag_r2084_captured
  ON public.engineer_skill_gap_diagnostics_r2084 (captured_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_skill_gap_resolution_log_r2084 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  diagnostic_id uuid NOT NULL REFERENCES public.engineer_skill_gap_diagnostics_r2084(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('training_assigned','training_completed','closed','escalated','recurrence')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_skill_gap_res_r2084_diag
  ON public.engineer_skill_gap_resolution_log_r2084 (diagnostic_id);
CREATE INDEX IF NOT EXISTS idx_eng_skill_gap_res_r2084_taken
  ON public.engineer_skill_gap_resolution_log_r2084 (taken_at DESC);

ALTER TABLE public.engineer_skill_gap_diagnostics_r2084 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_skill_gap_resolution_log_r2084 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_eng_skill_gap_diag_r2084_founder ON public.engineer_skill_gap_diagnostics_r2084;
CREATE POLICY p_eng_skill_gap_diag_r2084_founder
  ON public.engineer_skill_gap_diagnostics_r2084
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_eng_skill_gap_res_r2084_founder ON public.engineer_skill_gap_resolution_log_r2084;
CREATE POLICY p_eng_skill_gap_res_r2084_founder
  ON public.engineer_skill_gap_resolution_log_r2084
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- 7 RPCs
-- =========================================================================

CREATE OR REPLACE FUNCTION public.list_skill_gap_diagnostics_r2084()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  skill_area text,
  gap_severity text,
  prescribed_training_md text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_user_id, d.skill_area, d.gap_severity, d.prescribed_training_md, d.status, d.captured_at
  FROM public.engineer_skill_gap_diagnostics_r2084 d
  ORDER BY d.captured_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_skill_gap_diagnostic_r2084(
  p_engineer_user_id uuid,
  p_skill_area text,
  p_gap_severity text,
  p_prescribed_training_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_skill_gap_diagnostics_r2084(engineer_user_id, skill_area, gap_severity, prescribed_training_md)
  VALUES (p_engineer_user_id, p_skill_area, p_gap_severity, p_prescribed_training_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_skill_gap_diagnostic_r2084',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'skill_area', p_skill_area, 'gap_severity', p_gap_severity));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_skill_gap_resolutions_r2084(p_diagnostic_id uuid)
RETURNS TABLE (
  id uuid,
  diagnostic_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.diagnostic_id, r.action_type, r.taken_at, r.by_email, r.notes_md
  FROM public.engineer_skill_gap_resolution_log_r2084 r
  WHERE r.diagnostic_id = p_diagnostic_id
  ORDER BY r.taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_skill_gap_resolution_r2084(
  p_diagnostic_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_skill_gap_resolution_log_r2084(diagnostic_id, action_type, by_email, notes_md)
  VALUES (p_diagnostic_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_skill_gap_resolution_r2084',
    jsonb_build_object('id', v_id, 'diagnostic_id', p_diagnostic_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_skill_gap_status_r2084(
  p_diagnostic_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','training_assigned','closed','escalated') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.engineer_skill_gap_diagnostics_r2084
  SET status = p_status, updated_at = now()
  WHERE id = p_diagnostic_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_skill_gap_status_r2084',
    jsonb_build_object('id', p_diagnostic_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.critical_skill_gaps_r2084()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  skill_area text,
  gap_severity text,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_user_id, d.skill_area, d.gap_severity, d.status, d.captured_at
  FROM public.engineer_skill_gap_diagnostics_r2084 d
  WHERE d.gap_severity IN ('major','critical')
    AND d.status IN ('open','training_assigned','escalated')
  ORDER BY
    CASE d.gap_severity WHEN 'critical' THEN 1 WHEN 'major' THEN 2 ELSE 3 END,
    d.captured_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_skill_gap_resolutions_r2084()
RETURNS TABLE (
  id uuid,
  diagnostic_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.diagnostic_id, r.action_type, r.taken_at, r.by_email, r.notes_md
  FROM public.engineer_skill_gap_resolution_log_r2084 r
  ORDER BY r.taken_at DESC
  LIMIT 200;
END;
$$;

-- =========================================================================
-- grants
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_skill_gap_diagnostics_r2084() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_skill_gap_diagnostics_r2084() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_skill_gap_diagnostic_r2084(uuid, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_skill_gap_diagnostic_r2084(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_skill_gap_resolutions_r2084(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_skill_gap_resolutions_r2084(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_skill_gap_resolution_r2084(uuid, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_skill_gap_resolution_r2084(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_skill_gap_status_r2084(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.mark_skill_gap_status_r2084(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.critical_skill_gaps_r2084() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.critical_skill_gaps_r2084() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_skill_gap_resolutions_r2084() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.recent_skill_gap_resolutions_r2084() TO authenticated;

COMMIT;
