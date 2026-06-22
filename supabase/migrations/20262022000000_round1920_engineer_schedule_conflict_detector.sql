BEGIN;

-- ============================================================
-- Round 1920: Engineer Schedule Conflict Detector
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_schedule_conflicts_r1920 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conflict_window_start timestamptz NOT NULL,
  conflict_window_end timestamptz NOT NULL,
  conflict_type text NOT NULL CHECK (conflict_type IN ('double_booked','travel_unfeasible','insufficient_rest','holiday_violation')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','blocking')),
  status text NOT NULL DEFAULT 'detected' CHECK (status IN ('detected','resolved','escalated','false_positive')),
  detected_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_esc_r1920_engineer ON public.engineer_schedule_conflicts_r1920(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_esc_r1920_status ON public.engineer_schedule_conflicts_r1920(status);
CREATE INDEX IF NOT EXISTS idx_esc_r1920_severity ON public.engineer_schedule_conflicts_r1920(severity);
CREATE INDEX IF NOT EXISTS idx_esc_r1920_detected ON public.engineer_schedule_conflicts_r1920(detected_at DESC);

ALTER TABLE public.engineer_schedule_conflicts_r1920 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_esc_r1920 ON public.engineer_schedule_conflicts_r1920;
CREATE POLICY founder_all_esc_r1920 ON public.engineer_schedule_conflicts_r1920
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_conflict_resolution_log_r1920 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conflict_id uuid NOT NULL REFERENCES public.engineer_schedule_conflicts_r1920(id) ON DELETE CASCADE,
  resolution_type text NOT NULL CHECK (resolution_type IN ('rescheduled','reassigned','declined','overtime_approved','false_positive')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecrl_r1920_conflict ON public.engineer_conflict_resolution_log_r1920(conflict_id);
CREATE INDEX IF NOT EXISTS idx_ecrl_r1920_taken ON public.engineer_conflict_resolution_log_r1920(taken_at DESC);

ALTER TABLE public.engineer_conflict_resolution_log_r1920 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ecrl_r1920 ON public.engineer_conflict_resolution_log_r1920;
CREATE POLICY founder_all_ecrl_r1920 ON public.engineer_conflict_resolution_log_r1920
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_conflicts
-- ============================================================
DROP FUNCTION IF EXISTS public.list_conflicts_r1920();
CREATE OR REPLACE FUNCTION public.list_conflicts_r1920()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  conflict_window_start timestamptz,
  conflict_window_end timestamptz,
  conflict_type text,
  severity text,
  status text,
  detected_at timestamptz
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
    c.id,
    c.engineer_user_id,
    p.email,
    c.conflict_window_start,
    c.conflict_window_end,
    c.conflict_type,
    c.severity,
    c.status,
    c.detected_at
  FROM public.engineer_schedule_conflicts_r1920 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  ORDER BY c.detected_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_conflicts_r1920() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_conflicts_r1920() TO authenticated;

-- ============================================================
-- RPC 2: log_conflict
-- ============================================================
DROP FUNCTION IF EXISTS public.log_conflict_r1920(uuid, timestamptz, timestamptz, text, text);
CREATE OR REPLACE FUNCTION public.log_conflict_r1920(
  p_engineer_user_id uuid,
  p_window_start timestamptz,
  p_window_end timestamptz,
  p_conflict_type text,
  p_severity text
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

  INSERT INTO public.engineer_schedule_conflicts_r1920(
    engineer_user_id, conflict_window_start, conflict_window_end, conflict_type, severity
  ) VALUES (
    p_engineer_user_id, p_window_start, p_window_end, p_conflict_type, p_severity
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_conflict_r1920',
    jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'conflict_type', p_conflict_type, 'severity', p_severity)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_conflict_r1920(uuid, timestamptz, timestamptz, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_conflict_r1920(uuid, timestamptz, timestamptz, text, text) TO authenticated;

-- ============================================================
-- RPC 3: list_resolutions
-- ============================================================
DROP FUNCTION IF EXISTS public.list_resolutions_r1920();
CREATE OR REPLACE FUNCTION public.list_resolutions_r1920()
RETURNS TABLE (
  id uuid,
  conflict_id uuid,
  resolution_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
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
    r.id,
    r.conflict_id,
    r.resolution_type,
    r.taken_at,
    r.by_email,
    r.outcome_md
  FROM public.engineer_conflict_resolution_log_r1920 r
  ORDER BY r.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_resolutions_r1920() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_resolutions_r1920() TO authenticated;

-- ============================================================
-- RPC 4: log_resolution
-- ============================================================
DROP FUNCTION IF EXISTS public.log_resolution_r1920(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_resolution_r1920(
  p_conflict_id uuid,
  p_resolution_type text,
  p_by_email text,
  p_outcome_md text
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

  INSERT INTO public.engineer_conflict_resolution_log_r1920(
    conflict_id, resolution_type, by_email, outcome_md
  ) VALUES (
    p_conflict_id, p_resolution_type, p_by_email, p_outcome_md
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_resolution_r1920',
    jsonb_build_object('id', v_id, 'conflict_id', p_conflict_id, 'resolution_type', p_resolution_type)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_resolution_r1920(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_resolution_r1920(uuid, text, text, text) TO authenticated;

-- ============================================================
-- RPC 5: mark_resolved
-- ============================================================
DROP FUNCTION IF EXISTS public.mark_resolved_r1920(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_resolved_r1920(
  p_conflict_id uuid,
  p_new_status text
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

  UPDATE public.engineer_schedule_conflicts_r1920
     SET status = p_new_status,
         updated_at = now()
   WHERE id = p_conflict_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_resolved_r1920',
    jsonb_build_object('conflict_id', p_conflict_id, 'new_status', p_new_status)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_resolved_r1920(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_resolved_r1920(uuid, text) TO authenticated;

-- ============================================================
-- RPC 6: blocking_conflicts
-- ============================================================
DROP FUNCTION IF EXISTS public.blocking_conflicts_r1920();
CREATE OR REPLACE FUNCTION public.blocking_conflicts_r1920()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  conflict_window_start timestamptz,
  conflict_window_end timestamptz,
  conflict_type text,
  detected_at timestamptz
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
    c.id,
    c.engineer_user_id,
    p.email,
    c.conflict_window_start,
    c.conflict_window_end,
    c.conflict_type,
    c.detected_at
  FROM public.engineer_schedule_conflicts_r1920 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.severity = 'blocking'
    AND c.status IN ('detected','escalated')
  ORDER BY c.detected_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.blocking_conflicts_r1920() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocking_conflicts_r1920() TO authenticated;

-- ============================================================
-- RPC 7: recent_resolutions
-- ============================================================
DROP FUNCTION IF EXISTS public.recent_resolutions_r1920();
CREATE OR REPLACE FUNCTION public.recent_resolutions_r1920()
RETURNS TABLE (
  id uuid,
  conflict_id uuid,
  resolution_type text,
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
    r.id,
    r.conflict_id,
    r.resolution_type,
    r.taken_at,
    r.by_email
  FROM public.engineer_conflict_resolution_log_r1920 r
  WHERE r.taken_at >= now() - interval '14 days'
  ORDER BY r.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_resolutions_r1920() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_resolutions_r1920() TO authenticated;

COMMIT;
