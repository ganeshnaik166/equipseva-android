BEGIN;
-- round1420: engineer mental health + wellness pulse tracker
-- 2 tables + 7 RPCs (founder-gated)

CREATE TABLE IF NOT EXISTS public.engineer_mental_health_pulse_surveys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_label text NOT NULL UNIQUE,
  kind text NOT NULL CHECK (kind IN ('monthly_wellness','quarterly_pulse','onboarding','offboarding','crisis_followup','ad_hoc')),
  period_start date NOT NULL,
  period_end date NOT NULL,
  target_count int NOT NULL DEFAULT 0,
  sent_count int NOT NULL DEFAULT 0,
  response_count int NOT NULL DEFAULT 0,
  avg_wellness_score numeric(4,2),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','collecting','closed')),
  sent_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emhp_surveys_kind ON public.engineer_mental_health_pulse_surveys(kind);
CREATE INDEX IF NOT EXISTS idx_emhp_surveys_status ON public.engineer_mental_health_pulse_surveys(status);
CREATE INDEX IF NOT EXISTS idx_emhp_surveys_created ON public.engineer_mental_health_pulse_surveys(created_at DESC);

CREATE TABLE IF NOT EXISTS public.engineer_mental_health_pulse_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.engineer_mental_health_pulse_surveys(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  wellness_score int NOT NULL CHECK (wellness_score BETWEEN 1 AND 10),
  stress_score int NOT NULL CHECK (stress_score BETWEEN 1 AND 10),
  burnout_risk_band text GENERATED ALWAYS AS (
    CASE
      WHEN wellness_score <= 3 OR stress_score >= 8 THEN 'high'
      WHEN wellness_score <= 5 OR stress_score >= 6 THEN 'medium'
      ELSE 'low'
    END
  ) STORED,
  top_stressor text,
  top_positive text,
  would_recommend boolean,
  qualitative_feedback text,
  responded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(survey_id, engineer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_emhp_resp_survey ON public.engineer_mental_health_pulse_responses(survey_id);
CREATE INDEX IF NOT EXISTS idx_emhp_resp_engineer ON public.engineer_mental_health_pulse_responses(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_emhp_resp_band ON public.engineer_mental_health_pulse_responses(burnout_risk_band);
CREATE INDEX IF NOT EXISTS idx_emhp_resp_responded ON public.engineer_mental_health_pulse_responses(responded_at DESC);

ALTER TABLE public.engineer_mental_health_pulse_surveys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_mental_health_pulse_responses ENABLE ROW LEVEL SECURITY;

-- RPC 1: summary (16 KPIs)
CREATE OR REPLACE FUNCTION public.founder_engineer_mental_health_summary()
RETURNS TABLE (
  total_surveys bigint,
  draft_surveys bigint,
  sent_surveys bigint,
  collecting_surveys bigint,
  closed_surveys bigint,
  total_responses bigint,
  unique_respondents bigint,
  avg_wellness_score numeric,
  avg_stress_score numeric,
  high_risk_count bigint,
  medium_risk_count bigint,
  low_risk_count bigint,
  high_risk_pct numeric,
  would_recommend_pct numeric,
  responses_last_30d bigint,
  latest_survey_label text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH s AS (SELECT * FROM public.engineer_mental_health_pulse_surveys),
       r AS (SELECT * FROM public.engineer_mental_health_pulse_responses)
  SELECT
    (SELECT COUNT(*) FROM s)::bigint,
    (SELECT COUNT(*) FROM s WHERE status = 'draft')::bigint,
    (SELECT COUNT(*) FROM s WHERE status = 'sent')::bigint,
    (SELECT COUNT(*) FROM s WHERE status = 'collecting')::bigint,
    (SELECT COUNT(*) FROM s WHERE status = 'closed')::bigint,
    (SELECT COUNT(*) FROM r)::bigint,
    (SELECT COUNT(DISTINCT engineer_user_id) FROM r)::bigint,
    ROUND((SELECT AVG(wellness_score) FROM r), 2),
    ROUND((SELECT AVG(stress_score) FROM r), 2),
    (SELECT COUNT(*) FROM r WHERE burnout_risk_band = 'high')::bigint,
    (SELECT COUNT(*) FROM r WHERE burnout_risk_band = 'medium')::bigint,
    (SELECT COUNT(*) FROM r WHERE burnout_risk_band = 'low')::bigint,
    CASE WHEN (SELECT COUNT(*) FROM r) = 0 THEN 0
         ELSE ROUND(100.0 * (SELECT COUNT(*) FROM r WHERE burnout_risk_band = 'high') / (SELECT COUNT(*) FROM r), 2)
    END,
    CASE WHEN (SELECT COUNT(*) FROM r WHERE would_recommend IS NOT NULL) = 0 THEN 0
         ELSE ROUND(100.0 * (SELECT COUNT(*) FROM r WHERE would_recommend = true)
                    / (SELECT COUNT(*) FROM r WHERE would_recommend IS NOT NULL), 2)
    END,
    (SELECT COUNT(*) FROM r WHERE responded_at >= now() - interval '30 days')::bigint,
    (SELECT survey_label FROM s ORDER BY created_at DESC LIMIT 1);
END;
$$;

-- RPC 2: recent responses
CREATE OR REPLACE FUNCTION public.founder_engineer_mental_health_responses_recent()
RETURNS TABLE (
  id uuid,
  survey_id uuid,
  survey_label text,
  engineer_user_id uuid,
  wellness_score int,
  stress_score int,
  burnout_risk_band text,
  top_stressor text,
  top_positive text,
  would_recommend boolean,
  qualitative_feedback text,
  responded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT r.id, r.survey_id, s.survey_label, r.engineer_user_id,
         r.wellness_score, r.stress_score, r.burnout_risk_band,
         r.top_stressor, r.top_positive, r.would_recommend,
         r.qualitative_feedback, r.responded_at
  FROM public.engineer_mental_health_pulse_responses r
  JOIN public.engineer_mental_health_pulse_surveys s ON s.id = r.survey_id
  ORDER BY r.responded_at DESC
  LIMIT 100;
END;
$$;

-- RPC 3: recent surveys
CREATE OR REPLACE FUNCTION public.founder_engineer_mental_health_surveys_recent()
RETURNS TABLE (
  id uuid,
  survey_label text,
  kind text,
  period_start date,
  period_end date,
  target_count int,
  sent_count int,
  response_count int,
  avg_wellness_score numeric,
  status text,
  sent_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.id, s.survey_label, s.kind, s.period_start, s.period_end,
         s.target_count, s.sent_count, s.response_count, s.avg_wellness_score,
         s.status, s.sent_at, s.closed_at, s.created_at
  FROM public.engineer_mental_health_pulse_surveys s
  ORDER BY s.created_at DESC
  LIMIT 50;
END;
$$;

-- RPC 4: at-risk engineers (latest high-band response per engineer)
CREATE OR REPLACE FUNCTION public.founder_engineer_mental_health_at_risk_engineers()
RETURNS TABLE (
  engineer_user_id uuid,
  wellness_score int,
  stress_score int,
  burnout_risk_band text,
  top_stressor text,
  responded_at timestamptz,
  survey_label text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT DISTINCT ON (r.engineer_user_id)
    r.engineer_user_id, r.wellness_score, r.stress_score, r.burnout_risk_band,
    r.top_stressor, r.responded_at, s.survey_label
  FROM public.engineer_mental_health_pulse_responses r
  JOIN public.engineer_mental_health_pulse_surveys s ON s.id = r.survey_id
  WHERE r.burnout_risk_band = 'high'
  ORDER BY r.engineer_user_id, r.responded_at DESC
  LIMIT 100;
END;
$$;

-- RPC 5: log create survey
CREATE OR REPLACE FUNCTION public.log_founder_emhp_create_survey(
  p_survey_label text,
  p_kind text,
  p_period_start date,
  p_period_end date,
  p_target_count int
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.engineer_mental_health_pulse_surveys
    (survey_label, kind, period_start, period_end, target_count)
  VALUES (p_survey_label, p_kind, p_period_start, p_period_end, COALESCE(p_target_count, 0))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 6: log record response
CREATE OR REPLACE FUNCTION public.log_founder_emhp_record_response(
  p_survey_id uuid,
  p_engineer_user_id uuid,
  p_wellness_score int,
  p_stress_score int,
  p_top_stressor text,
  p_top_positive text,
  p_would_recommend boolean,
  p_qualitative_feedback text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.engineer_mental_health_pulse_responses
    (survey_id, engineer_user_id, wellness_score, stress_score,
     top_stressor, top_positive, would_recommend, qualitative_feedback)
  VALUES (p_survey_id, p_engineer_user_id, p_wellness_score, p_stress_score,
          p_top_stressor, p_top_positive, p_would_recommend, p_qualitative_feedback)
  RETURNING id INTO v_id;
  UPDATE public.engineer_mental_health_pulse_surveys
     SET response_count = response_count + 1,
         avg_wellness_score = (
           SELECT ROUND(AVG(wellness_score)::numeric, 2)
           FROM public.engineer_mental_health_pulse_responses
           WHERE survey_id = p_survey_id
         ),
         status = CASE WHEN status = 'sent' THEN 'collecting' ELSE status END
   WHERE id = p_survey_id;
  RETURN v_id;
END;
$$;

-- RPC 7: log close survey
CREATE OR REPLACE FUNCTION public.log_founder_emhp_close_survey(
  p_survey_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  UPDATE public.engineer_mental_health_pulse_surveys
     SET status = 'closed', closed_at = COALESCE(closed_at, now())
   WHERE id = p_survey_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.founder_engineer_mental_health_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_engineer_mental_health_responses_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_engineer_mental_health_surveys_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_engineer_mental_health_at_risk_engineers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_emhp_create_survey(text, text, date, date, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_emhp_record_response(uuid, uuid, int, int, text, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_emhp_close_survey(uuid) TO authenticated;
COMMIT;
