BEGIN;

-- ============================================================================
-- Round 2152 — Engineer Self-Assessment Survey
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_self_assessment_survey_r2152 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  survey_period text NOT NULL,
  satisfaction_score int NOT NULL CHECK (satisfaction_score BETWEEN 1 AND 10),
  growth_areas_md text,
  blockers_md text,
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','follow_up_needed','escalated','closed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eas_survey_r2152_engineer ON public.engineer_self_assessment_survey_r2152(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eas_survey_r2152_status ON public.engineer_self_assessment_survey_r2152(status);
CREATE INDEX IF NOT EXISTS idx_eas_survey_r2152_captured_at ON public.engineer_self_assessment_survey_r2152(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_self_assessment_action_log_r2152 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.engineer_self_assessment_survey_r2152(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coached','promoted','recognized','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eas_action_r2152_survey ON public.engineer_self_assessment_action_log_r2152(survey_id);
CREATE INDEX IF NOT EXISTS idx_eas_action_r2152_taken_at ON public.engineer_self_assessment_action_log_r2152(taken_at DESC);

ALTER TABLE public.engineer_self_assessment_survey_r2152 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_self_assessment_action_log_r2152 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eas_survey_r2152 ON public.engineer_self_assessment_survey_r2152;
CREATE POLICY founder_all_eas_survey_r2152 ON public.engineer_self_assessment_survey_r2152
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eas_action_r2152 ON public.engineer_self_assessment_action_log_r2152;
CREATE POLICY founder_all_eas_action_r2152 ON public.engineer_self_assessment_action_log_r2152
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.list_surveys_r2152();
CREATE OR REPLACE FUNCTION public.list_surveys_r2152()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  survey_period text,
  satisfaction_score int,
  growth_areas_md text,
  blockers_md text,
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
  SELECT s.id, s.engineer_user_id, s.survey_period, s.satisfaction_score,
         s.growth_areas_md, s.blockers_md, s.status, s.captured_at
  FROM public.engineer_self_assessment_survey_r2152 s
  ORDER BY s.captured_at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_survey_r2152(uuid, text, int, text, text);
CREATE OR REPLACE FUNCTION public.log_survey_r2152(
  p_engineer_user_id uuid,
  p_survey_period text,
  p_satisfaction_score int,
  p_growth_areas_md text,
  p_blockers_md text
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

  INSERT INTO public.engineer_self_assessment_survey_r2152
    (engineer_user_id, survey_period, satisfaction_score, growth_areas_md, blockers_md)
  VALUES
    (p_engineer_user_id, p_survey_period, p_satisfaction_score, p_growth_areas_md, p_blockers_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_survey_r2152',
    jsonb_build_object('survey_id', v_id, 'engineer_user_id', p_engineer_user_id, 'score', p_satisfaction_score)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_actions_r2152(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2152(p_survey_id uuid)
RETURNS TABLE (
  id uuid,
  survey_id uuid,
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
  SELECT a.id, a.survey_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_self_assessment_action_log_r2152 a
  WHERE a.survey_id = p_survey_id
  ORDER BY a.taken_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.log_action_r2152(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2152(
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

  INSERT INTO public.engineer_self_assessment_action_log_r2152
    (survey_id, action_type, by_email, notes_md)
  VALUES
    (p_survey_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'log_action_r2152',
    jsonb_build_object('action_id', v_id, 'survey_id', p_survey_id, 'action_type', p_action_type)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.mark_status_r2152(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2152(p_survey_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('captured','follow_up_needed','escalated','closed') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.engineer_self_assessment_survey_r2152
  SET status = p_status,
      updated_at = now()
  WHERE id = p_survey_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt() ->> 'email'),
    'mark_status_r2152',
    jsonb_build_object('survey_id', p_survey_id, 'status', p_status)
  );
END;
$$;

DROP FUNCTION IF EXISTS public.low_scores_r2152();
CREATE OR REPLACE FUNCTION public.low_scores_r2152()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  survey_period text,
  satisfaction_score int,
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
  SELECT s.id, s.engineer_user_id, s.survey_period, s.satisfaction_score, s.status, s.captured_at
  FROM public.engineer_self_assessment_survey_r2152 s
  WHERE s.satisfaction_score <= 5
  ORDER BY s.satisfaction_score ASC, s.captured_at DESC
  LIMIT 100;
END;
$$;

DROP FUNCTION IF EXISTS public.recent_actions_r2152();
CREATE OR REPLACE FUNCTION public.recent_actions_r2152()
RETURNS TABLE (
  id uuid,
  survey_id uuid,
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
  SELECT a.id, a.survey_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_self_assessment_action_log_r2152 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_surveys_r2152() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_surveys_r2152() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_survey_r2152(uuid, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_survey_r2152(uuid, text, int, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_actions_r2152(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2152(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.log_action_r2152(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2152(uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.mark_status_r2152(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2152(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.low_scores_r2152() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.low_scores_r2152() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r2152() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2152() TO authenticated;

COMMIT;
