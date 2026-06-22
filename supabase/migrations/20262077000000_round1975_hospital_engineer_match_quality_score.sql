BEGIN;

-- ============================================================================
-- Round 1975 — Hospital Engineer Match Quality Score
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_engineer_match_quality_r1975 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  match_score int NOT NULL CHECK (match_score BETWEEN 1 AND 100),
  match_factors_md text,
  total_jobs int NOT NULL DEFAULT 0,
  csat_avg numeric(4,2),
  repeat_request_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'good' CHECK (status IN ('excellent','good','fair','poor','blocked')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hemq_r1975_hospital ON public.hospital_engineer_match_quality_r1975(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hemq_r1975_engineer ON public.hospital_engineer_match_quality_r1975(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_hemq_r1975_status ON public.hospital_engineer_match_quality_r1975(status);
CREATE INDEX IF NOT EXISTS idx_hemq_r1975_score ON public.hospital_engineer_match_quality_r1975(match_score DESC);

CREATE TABLE IF NOT EXISTS public.hospital_match_action_log_r1975 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES public.hospital_engineer_match_quality_r1975(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('assignment_made','avoid_set','locked_pair','separated','recommended')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hmal_r1975_match ON public.hospital_match_action_log_r1975(match_id);
CREATE INDEX IF NOT EXISTS idx_hmal_r1975_action ON public.hospital_match_action_log_r1975(action_type);
CREATE INDEX IF NOT EXISTS idx_hmal_r1975_taken ON public.hospital_match_action_log_r1975(taken_at DESC);

ALTER TABLE public.hospital_engineer_match_quality_r1975 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_match_action_log_r1975 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hemq_r1975_founder ON public.hospital_engineer_match_quality_r1975;
CREATE POLICY hemq_r1975_founder ON public.hospital_engineer_match_quality_r1975
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hmal_r1975_founder ON public.hospital_match_action_log_r1975;
CREATE POLICY hmal_r1975_founder ON public.hospital_match_action_log_r1975
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_matches
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_matches_r1975()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  engineer_user_id uuid,
  engineer_email text,
  match_score int,
  match_factors_md text,
  total_jobs int,
  csat_avg numeric,
  repeat_request_count int,
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
  SELECT m.id, m.hospital_id, ph.email, m.engineer_user_id, pe.email,
         m.match_score, m.match_factors_md, m.total_jobs, m.csat_avg,
         m.repeat_request_count, m.status, m.captured_at
  FROM public.hospital_engineer_match_quality_r1975 m
  LEFT JOIN public.profiles ph ON ph.id = m.hospital_id
  LEFT JOIN public.profiles pe ON pe.id = m.engineer_user_id
  ORDER BY m.match_score DESC, m.captured_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_matches_r1975() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_matches_r1975() TO authenticated;

-- ============================================================================
-- RPC 2: log_match
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_match_r1975(
  p_hospital_id uuid,
  p_engineer_user_id uuid,
  p_match_score int,
  p_match_factors_md text,
  p_total_jobs int,
  p_csat_avg numeric,
  p_repeat_request_count int,
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
  INSERT INTO public.hospital_engineer_match_quality_r1975(
    hospital_id, engineer_user_id, match_score, match_factors_md,
    total_jobs, csat_avg, repeat_request_count, status
  )
  VALUES (p_hospital_id, p_engineer_user_id, p_match_score, p_match_factors_md,
          COALESCE(p_total_jobs, 0), p_csat_avg, COALESCE(p_repeat_request_count, 0),
          COALESCE(p_status, 'good'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_match_r1975',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'engineer_user_id', p_engineer_user_id, 'match_score', p_match_score));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_match_r1975(uuid, uuid, int, text, int, numeric, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_match_r1975(uuid, uuid, int, text, int, numeric, int, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1975()
RETURNS TABLE (
  id uuid,
  match_id uuid,
  hospital_email text,
  engineer_email text,
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
  SELECT a.id, a.match_id, ph.email, pe.email,
         a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_match_action_log_r1975 a
  JOIN public.hospital_engineer_match_quality_r1975 m ON m.id = a.match_id
  LEFT JOIN public.profiles ph ON ph.id = m.hospital_id
  LEFT JOIN public.profiles pe ON pe.id = m.engineer_user_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r1975() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r1975() TO authenticated;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1975(
  p_match_id uuid,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_match_action_log_r1975(match_id, action_type, by_email, notes_md)
  VALUES (p_match_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1975',
          jsonb_build_object('id', v_id, 'match_id', p_match_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r1975(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r1975(uuid, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r1975(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_engineer_match_quality_r1975
  SET status = p_status, updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1975',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_status_r1975(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r1975(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: top_matches
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_matches_r1975()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  engineer_email text,
  match_score int,
  total_jobs int,
  csat_avg numeric,
  repeat_request_count int,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, ph.email, pe.email, m.match_score, m.total_jobs,
         m.csat_avg, m.repeat_request_count, m.status
  FROM public.hospital_engineer_match_quality_r1975 m
  LEFT JOIN public.profiles ph ON ph.id = m.hospital_id
  LEFT JOIN public.profiles pe ON pe.id = m.engineer_user_id
  WHERE m.status IN ('excellent','good')
  ORDER BY m.match_score DESC
  LIMIT 25;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_matches_r1975() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_matches_r1975() TO authenticated;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r1975()
RETURNS TABLE (
  id uuid,
  match_id uuid,
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
  SELECT a.id, a.match_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_match_action_log_r1975 a
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r1975() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1975() TO authenticated;

COMMIT;
