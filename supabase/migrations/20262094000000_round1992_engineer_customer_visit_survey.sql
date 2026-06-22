BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_visit_surveys_r1992 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  repair_job_id uuid,
  survey_response_md text,
  survey_score int CHECK (survey_score BETWEEN 1 AND 5),
  response_text_md text,
  sentiment text CHECK (sentiment IN ('very_positive','positive','neutral','negative','very_negative')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','follow_up_needed','escalated','resolved')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ecvs_r1992_engineer ON public.engineer_customer_visit_surveys_r1992(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ecvs_r1992_hospital ON public.engineer_customer_visit_surveys_r1992(hospital_id);
CREATE INDEX IF NOT EXISTS idx_ecvs_r1992_captured ON public.engineer_customer_visit_surveys_r1992(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_visit_survey_action_log_r1992 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.engineer_customer_visit_surveys_r1992(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('follow_up_sent','coached','escalated','positive_share','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_evsal_r1992_survey ON public.engineer_visit_survey_action_log_r1992(survey_id);
CREATE INDEX IF NOT EXISTS idx_evsal_r1992_taken ON public.engineer_visit_survey_action_log_r1992(taken_at DESC);

ALTER TABLE public.engineer_customer_visit_surveys_r1992 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_visit_survey_action_log_r1992 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ecvs_r1992 ON public.engineer_customer_visit_surveys_r1992;
CREATE POLICY founder_all_ecvs_r1992 ON public.engineer_customer_visit_surveys_r1992
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_evsal_r1992 ON public.engineer_visit_survey_action_log_r1992;
CREATE POLICY founder_all_evsal_r1992 ON public.engineer_visit_survey_action_log_r1992
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_surveys
DROP FUNCTION IF EXISTS public.r1992_list_surveys();
CREATE OR REPLACE FUNCTION public.r1992_list_surveys()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  hospital_id uuid,
  hospital_name text,
  repair_job_id uuid,
  survey_score int,
  sentiment text,
  status text,
  response_text_md text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, p.full_name, s.hospital_id, o.name,
         s.repair_job_id, s.survey_score, s.sentiment, s.status,
         s.response_text_md, s.captured_at
  FROM public.engineer_customer_visit_surveys_r1992 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  ORDER BY s.captured_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1992_list_surveys() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1992_list_surveys() TO authenticated;

-- RPC 2: log_survey
DROP FUNCTION IF EXISTS public.r1992_log_survey(uuid, uuid, uuid, text, int, text, text);
CREATE OR REPLACE FUNCTION public.r1992_log_survey(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_repair_job_id uuid,
  p_survey_response_md text,
  p_survey_score int,
  p_response_text_md text,
  p_sentiment text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_visit_surveys_r1992
    (engineer_user_id, hospital_id, repair_job_id, survey_response_md, survey_score, response_text_md, sentiment)
  VALUES (p_engineer_user_id, p_hospital_id, p_repair_job_id, p_survey_response_md, p_survey_score, p_response_text_md, p_sentiment)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1992_log_survey',
          jsonb_build_object('survey_id', v_id, 'engineer_user_id', p_engineer_user_id, 'score', p_survey_score));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1992_log_survey(uuid, uuid, uuid, text, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1992_log_survey(uuid, uuid, uuid, text, int, text, text) TO authenticated;

-- RPC 3: list_actions
DROP FUNCTION IF EXISTS public.r1992_list_actions();
CREATE OR REPLACE FUNCTION public.r1992_list_actions()
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.survey_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_visit_survey_action_log_r1992 a
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1992_list_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1992_list_actions() TO authenticated;

-- RPC 4: log_action
DROP FUNCTION IF EXISTS public.r1992_log_action(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.r1992_log_action(
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
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_visit_survey_action_log_r1992
    (survey_id, action_type, by_email, notes_md)
  VALUES (p_survey_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1992_log_action',
          jsonb_build_object('action_id', v_id, 'survey_id', p_survey_id, 'type', p_action_type));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1992_log_action(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1992_log_action(uuid, text, text, text) TO authenticated;

-- RPC 5: mark_status
DROP FUNCTION IF EXISTS public.r1992_mark_status(uuid, text);
CREATE OR REPLACE FUNCTION public.r1992_mark_status(p_survey_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_visit_surveys_r1992
  SET status = p_status, updated_at = now()
  WHERE id = p_survey_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1992_mark_status',
          jsonb_build_object('survey_id', p_survey_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1992_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1992_mark_status(uuid, text) TO authenticated;

-- RPC 6: low_scores
DROP FUNCTION IF EXISTS public.r1992_low_scores();
CREATE OR REPLACE FUNCTION public.r1992_low_scores()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_name text,
  hospital_name text,
  survey_score int,
  sentiment text,
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
  SELECT s.id, s.engineer_user_id, p.full_name, o.name,
         s.survey_score, s.sentiment, s.status, s.captured_at
  FROM public.engineer_customer_visit_surveys_r1992 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  WHERE s.survey_score IS NOT NULL AND s.survey_score <= 2
  ORDER BY s.captured_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1992_low_scores() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1992_low_scores() TO authenticated;

-- RPC 7: recent_actions
DROP FUNCTION IF EXISTS public.r1992_recent_actions();
CREATE OR REPLACE FUNCTION public.r1992_recent_actions()
RETURNS TABLE (
  id uuid,
  survey_id uuid,
  engineer_name text,
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
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.survey_id, p.full_name, o.name,
         a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_visit_survey_action_log_r1992 a
  LEFT JOIN public.engineer_customer_visit_surveys_r1992 s ON s.id = a.survey_id
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = s.hospital_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r1992_recent_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r1992_recent_actions() TO authenticated;

COMMIT;
