BEGIN;

-- =====================================================
-- Round 1955 — Hospital Service Excellence Survey
-- =====================================================

CREATE TABLE IF NOT EXISTS public.hospital_service_excellence_surveys_r1955 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  survey_date date NOT NULL DEFAULT CURRENT_DATE,
  response_count int NOT NULL DEFAULT 0,
  avg_score numeric(4,2) NOT NULL DEFAULT 0,
  nps_score int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','in_progress','completed','closed','cancelled')),
  top_themes_md text,
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hses_r1955_hospital ON public.hospital_service_excellence_surveys_r1955(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hses_r1955_date ON public.hospital_service_excellence_surveys_r1955(survey_date DESC);
CREATE INDEX IF NOT EXISTS idx_hses_r1955_status ON public.hospital_service_excellence_surveys_r1955(status);

CREATE TABLE IF NOT EXISTS public.hospital_service_survey_action_log_r1955 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.hospital_service_excellence_surveys_r1955(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('follow_up_scheduled','issue_resolved','team_review','escalation','marketing_use')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hssal_r1955_survey ON public.hospital_service_survey_action_log_r1955(survey_id);
CREATE INDEX IF NOT EXISTS idx_hssal_r1955_taken ON public.hospital_service_survey_action_log_r1955(taken_at DESC);

ALTER TABLE public.hospital_service_excellence_surveys_r1955 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_survey_action_log_r1955 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hses_r1955 ON public.hospital_service_excellence_surveys_r1955;
CREATE POLICY founder_all_hses_r1955 ON public.hospital_service_excellence_surveys_r1955
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hssal_r1955 ON public.hospital_service_survey_action_log_r1955;
CREATE POLICY founder_all_hssal_r1955 ON public.hospital_service_survey_action_log_r1955
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================
-- RPC 1: list_surveys
-- =====================================================
CREATE OR REPLACE FUNCTION public.list_surveys_r1955()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  survey_date date,
  response_count int,
  avg_score numeric,
  nps_score int,
  status text,
  top_themes_md text,
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
  SELECT s.id, s.hospital_id, o.name, s.survey_date, s.response_count, s.avg_score, s.nps_score, s.status, s.top_themes_md, s.captured_at
  FROM public.hospital_service_excellence_surveys_r1955 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  ORDER BY s.survey_date DESC, s.captured_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================
-- RPC 2: log_survey
-- =====================================================
CREATE OR REPLACE FUNCTION public.log_survey_r1955(
  p_hospital_id uuid,
  p_survey_date date,
  p_response_count int,
  p_avg_score numeric,
  p_nps_score int,
  p_status text,
  p_top_themes_md text
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
  INSERT INTO public.hospital_service_excellence_surveys_r1955(
    hospital_id, survey_date, response_count, avg_score, nps_score, status, top_themes_md
  ) VALUES (
    p_hospital_id, COALESCE(p_survey_date, CURRENT_DATE), COALESCE(p_response_count, 0),
    COALESCE(p_avg_score, 0), COALESCE(p_nps_score, 0), COALESCE(p_status, 'sent'), p_top_themes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_survey_r1955',
    jsonb_build_object('survey_id', v_id, 'hospital_id', p_hospital_id, 'nps', p_nps_score));

  RETURN v_id;
END;
$$;

-- =====================================================
-- RPC 3: list_actions
-- =====================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1955(p_survey_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  survey_id uuid,
  hospital_name text,
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
  SELECT a.id, a.survey_id, o.name, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_service_survey_action_log_r1955 a
  LEFT JOIN public.hospital_service_excellence_surveys_r1955 s ON s.id = a.survey_id
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  WHERE p_survey_id IS NULL OR a.survey_id = p_survey_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================
-- RPC 4: log_action
-- =====================================================
CREATE OR REPLACE FUNCTION public.log_action_r1955(
  p_survey_id uuid,
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
  INSERT INTO public.hospital_service_survey_action_log_r1955(
    survey_id, action_type, by_email, notes_md
  ) VALUES (p_survey_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1955',
    jsonb_build_object('action_id', v_id, 'survey_id', p_survey_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- =====================================================
-- RPC 5: mark_status
-- =====================================================
CREATE OR REPLACE FUNCTION public.mark_status_r1955(
  p_survey_id uuid,
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
  UPDATE public.hospital_service_excellence_surveys_r1955
  SET status = p_status, updated_at = now()
  WHERE id = p_survey_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1955',
    jsonb_build_object('survey_id', p_survey_id, 'status', p_status));
END;
$$;

-- =====================================================
-- RPC 6: low_score_surveys
-- =====================================================
CREATE OR REPLACE FUNCTION public.low_score_surveys_r1955(p_threshold numeric DEFAULT 3.5)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  survey_date date,
  avg_score numeric,
  nps_score int,
  response_count int,
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
  SELECT s.id, o.name, s.survey_date, s.avg_score, s.nps_score, s.response_count, s.status
  FROM public.hospital_service_excellence_surveys_r1955 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  WHERE s.avg_score < COALESCE(p_threshold, 3.5)
  ORDER BY s.avg_score ASC, s.survey_date DESC
  LIMIT 100;
END;
$$;

-- =====================================================
-- RPC 7: recent_actions
-- =====================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r1955(p_days int DEFAULT 14)
RETURNS TABLE (
  id uuid,
  survey_id uuid,
  hospital_name text,
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
  SELECT a.id, a.survey_id, o.name, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_service_survey_action_log_r1955 a
  LEFT JOIN public.hospital_service_excellence_surveys_r1955 s ON s.id = a.survey_id
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  WHERE a.taken_at >= now() - (COALESCE(p_days, 14) || ' days')::interval
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

-- =====================================================
-- Permissions
-- =====================================================
REVOKE EXECUTE ON FUNCTION public.list_surveys_r1955() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_survey_r1955(uuid, date, int, numeric, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1955(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1955(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1955(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.low_score_surveys_r1955(numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1955(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_surveys_r1955() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_survey_r1955(uuid, date, int, numeric, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1955(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1955(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1955(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.low_score_surveys_r1955(numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1955(int) TO authenticated;

COMMIT;
