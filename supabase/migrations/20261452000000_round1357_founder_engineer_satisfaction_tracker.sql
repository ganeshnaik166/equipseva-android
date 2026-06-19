BEGIN;
-- round1357 — Founder engineer satisfaction tracker
-- Engineer NPS / CSAT pulse-survey ledger. Surveys + responses + 15-KPI summary.
-- All RPCs founder-gated. LANGUAGE plpgsql STABLE SECURITY DEFINER, search_path locked.

-- 1. Pulse surveys (one row per campaign)
CREATE TABLE IF NOT EXISTS public.founder_engineer_pulse_surveys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_label text UNIQUE NOT NULL,
  kind text NOT NULL DEFAULT 'monthly_pulse' CHECK (kind IN (
    'monthly_pulse','quarterly_nps','tier_promo_survey','offboarding','ad_hoc'
  )),
  period_start date,
  period_end date,
  target_recipient_count int NOT NULL DEFAULT 0,
  sent_count int NOT NULL DEFAULT 0,
  response_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN (
    'draft','sent','collecting','closed'
  )),
  nps_score numeric,
  csat_score numeric,
  sent_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS founder_engineer_pulse_surveys_status_idx
  ON public.founder_engineer_pulse_surveys (status, created_at DESC);
CREATE INDEX IF NOT EXISTS founder_engineer_pulse_surveys_kind_idx
  ON public.founder_engineer_pulse_surveys (kind, created_at DESC);

ALTER TABLE public.founder_engineer_pulse_surveys ENABLE ROW LEVEL SECURITY;

-- 2. Pulse responses (one row per engineer per survey)
CREATE TABLE IF NOT EXISTS public.founder_engineer_pulse_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.founder_engineer_pulse_surveys(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nps_score int CHECK (nps_score >= 0 AND nps_score <= 10),
  csat_score int CHECK (csat_score >= 1 AND csat_score <= 5),
  top_friction text,
  top_motivator text,
  suggested_improvement text,
  qualitative_feedback text,
  would_recommend boolean,
  category text GENERATED ALWAYS AS (
    CASE
      WHEN nps_score >= 9 THEN 'promoter'
      WHEN nps_score >= 7 THEN 'passive'
      WHEN nps_score IS NOT NULL THEN 'detractor'
      ELSE NULL
    END
  ) STORED,
  responded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (survey_id, engineer_user_id)
);

CREATE INDEX IF NOT EXISTS founder_engineer_pulse_responses_survey_idx
  ON public.founder_engineer_pulse_responses (survey_id, responded_at DESC);
CREATE INDEX IF NOT EXISTS founder_engineer_pulse_responses_engineer_idx
  ON public.founder_engineer_pulse_responses (engineer_user_id, responded_at DESC);
CREATE INDEX IF NOT EXISTS founder_engineer_pulse_responses_category_idx
  ON public.founder_engineer_pulse_responses (category);

ALTER TABLE public.founder_engineer_pulse_responses ENABLE ROW LEVEL SECURITY;

-- 3. Summary RPC — 15 KPIs
DROP FUNCTION IF EXISTS public.founder_engineer_satisfaction_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_satisfaction_summary()
RETURNS TABLE (
  latest_survey_label                   text,
  latest_nps                            numeric,
  latest_csat                           numeric,
  latest_response_rate_pct              numeric,
  latest_promoter_pct                   numeric,
  latest_detractor_pct                  numeric,
  all_time_response_count               bigint,
  surveys_sent_count                    bigint,
  surveys_closed_count                  bigint,
  qoq_nps_delta                         numeric,
  top_friction_category                 text,
  top_motivator_category                text,
  engineers_consistently_detractor_30d  bigint,
  last_survey_at                        timestamptz,
  days_since_last_survey                int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_latest_id uuid;
  v_latest_target int;
  v_latest_responses bigint;
  v_latest_promoters bigint;
  v_latest_detractors bigint;
  v_prev_nps numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT id, survey_label, nps_score, csat_score, target_recipient_count, sent_at
    INTO v_latest_id, latest_survey_label, latest_nps, latest_csat, v_latest_target, last_survey_at
    FROM public.founder_engineer_pulse_surveys
    WHERE status IN ('sent','collecting','closed')
    ORDER BY COALESCE(sent_at, created_at) DESC
    LIMIT 1;

  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE category = 'promoter'),
         COUNT(*) FILTER (WHERE category = 'detractor')
    INTO v_latest_responses, v_latest_promoters, v_latest_detractors
    FROM public.founder_engineer_pulse_responses
    WHERE survey_id = v_latest_id;

  latest_response_rate_pct := CASE
    WHEN v_latest_target > 0 THEN ROUND((v_latest_responses::numeric / v_latest_target) * 100, 1)
    ELSE NULL END;
  latest_promoter_pct := CASE
    WHEN v_latest_responses > 0 THEN ROUND((v_latest_promoters::numeric / v_latest_responses) * 100, 1)
    ELSE NULL END;
  latest_detractor_pct := CASE
    WHEN v_latest_responses > 0 THEN ROUND((v_latest_detractors::numeric / v_latest_responses) * 100, 1)
    ELSE NULL END;

  SELECT COUNT(*) INTO all_time_response_count FROM public.founder_engineer_pulse_responses;
  SELECT COUNT(*) FILTER (WHERE status IN ('sent','collecting','closed')),
         COUNT(*) FILTER (WHERE status = 'closed')
    INTO surveys_sent_count, surveys_closed_count
    FROM public.founder_engineer_pulse_surveys;

  SELECT nps_score INTO v_prev_nps
    FROM public.founder_engineer_pulse_surveys
    WHERE status IN ('sent','collecting','closed') AND id <> COALESCE(v_latest_id, '00000000-0000-0000-0000-000000000000'::uuid)
    ORDER BY COALESCE(sent_at, created_at) DESC
    LIMIT 1;
  qoq_nps_delta := CASE
    WHEN latest_nps IS NOT NULL AND v_prev_nps IS NOT NULL THEN ROUND(latest_nps - v_prev_nps, 1)
    ELSE NULL END;

  SELECT top_friction INTO top_friction_category
    FROM public.founder_engineer_pulse_responses
    WHERE top_friction IS NOT NULL AND top_friction <> ''
    GROUP BY top_friction
    ORDER BY COUNT(*) DESC
    LIMIT 1;

  SELECT top_motivator INTO top_motivator_category
    FROM public.founder_engineer_pulse_responses
    WHERE top_motivator IS NOT NULL AND top_motivator <> ''
    GROUP BY top_motivator
    ORDER BY COUNT(*) DESC
    LIMIT 1;

  SELECT COUNT(*) INTO engineers_consistently_detractor_30d
    FROM (
      SELECT engineer_user_id
        FROM public.founder_engineer_pulse_responses
        WHERE responded_at >= now() - INTERVAL '30 days' AND category = 'detractor'
        GROUP BY engineer_user_id
        HAVING COUNT(*) >= 2
    ) sub;

  days_since_last_survey := CASE
    WHEN last_survey_at IS NOT NULL THEN EXTRACT(DAY FROM (now() - last_survey_at))::int
    ELSE NULL END;

  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_satisfaction_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_satisfaction_summary() TO authenticated;

-- 4. Responses recent
DROP FUNCTION IF EXISTS public.founder_engineer_pulse_responses_recent(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_engineer_pulse_responses_recent(
  p_survey_id uuid DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id                    uuid,
  survey_id             uuid,
  survey_label          text,
  engineer_user_id      uuid,
  nps_score             int,
  csat_score            int,
  category              text,
  top_friction          text,
  top_motivator         text,
  suggested_improvement text,
  would_recommend       boolean,
  responded_at          timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT r.id, r.survey_id, s.survey_label, r.engineer_user_id, r.nps_score, r.csat_score,
         r.category, r.top_friction, r.top_motivator, r.suggested_improvement,
         r.would_recommend, r.responded_at
    FROM public.founder_engineer_pulse_responses r
    JOIN public.founder_engineer_pulse_surveys s ON s.id = r.survey_id
    WHERE (p_survey_id IS NULL OR r.survey_id = p_survey_id)
    ORDER BY r.responded_at DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_pulse_responses_recent(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_pulse_responses_recent(uuid, int) TO authenticated;

-- 5. Surveys recent
DROP FUNCTION IF EXISTS public.founder_engineer_pulse_surveys_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_pulse_surveys_recent(p_limit int DEFAULT 20)
RETURNS TABLE (
  id                     uuid,
  survey_label           text,
  kind                   text,
  status                 text,
  period_start           date,
  period_end             date,
  target_recipient_count int,
  sent_count             int,
  response_count         int,
  response_rate_pct      numeric,
  nps_score              numeric,
  csat_score             numeric,
  sent_at                timestamptz,
  closed_at              timestamptz,
  created_at             timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT s.id, s.survey_label, s.kind, s.status, s.period_start, s.period_end,
         s.target_recipient_count, s.sent_count, s.response_count,
         CASE WHEN s.target_recipient_count > 0
              THEN ROUND((s.response_count::numeric / s.target_recipient_count) * 100, 1)
              ELSE NULL END,
         s.nps_score, s.csat_score, s.sent_at, s.closed_at, s.created_at
    FROM public.founder_engineer_pulse_surveys s
    ORDER BY s.created_at DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 20));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_pulse_surveys_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_pulse_surveys_recent(int) TO authenticated;

-- 6. Log: create survey
DROP FUNCTION IF EXISTS public.log_founder_engineer_pulse_create_survey(text, text, date, date, int);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_pulse_create_survey(
  p_survey_label text,
  p_kind text DEFAULT 'monthly_pulse',
  p_period_start date DEFAULT NULL,
  p_period_end date DEFAULT NULL,
  p_target_recipient_count int DEFAULT 0
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
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_engineer_pulse_surveys (
    survey_label, kind, period_start, period_end, target_recipient_count
  ) VALUES (
    p_survey_label, COALESCE(p_kind,'monthly_pulse'), p_period_start, p_period_end, COALESCE(p_target_recipient_count,0)
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_pulse_create_survey(text, text, date, date, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_engineer_pulse_create_survey(text, text, date, date, int) TO authenticated;

-- 7. Log: record response
DROP FUNCTION IF EXISTS public.log_founder_engineer_pulse_record_response(uuid, uuid, int, int, text, text, text, text, boolean);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_pulse_record_response(
  p_survey_id uuid,
  p_engineer_user_id uuid,
  p_nps_score int DEFAULT NULL,
  p_csat_score int DEFAULT NULL,
  p_top_friction text DEFAULT NULL,
  p_top_motivator text DEFAULT NULL,
  p_suggested_improvement text DEFAULT NULL,
  p_qualitative_feedback text DEFAULT NULL,
  p_would_recommend boolean DEFAULT NULL
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
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_engineer_pulse_responses (
    survey_id, engineer_user_id, nps_score, csat_score,
    top_friction, top_motivator, suggested_improvement, qualitative_feedback, would_recommend
  ) VALUES (
    p_survey_id, p_engineer_user_id, p_nps_score, p_csat_score,
    p_top_friction, p_top_motivator, p_suggested_improvement, p_qualitative_feedback, p_would_recommend
  )
  ON CONFLICT (survey_id, engineer_user_id) DO UPDATE
    SET nps_score = EXCLUDED.nps_score,
        csat_score = EXCLUDED.csat_score,
        top_friction = EXCLUDED.top_friction,
        top_motivator = EXCLUDED.top_motivator,
        suggested_improvement = EXCLUDED.suggested_improvement,
        qualitative_feedback = EXCLUDED.qualitative_feedback,
        would_recommend = EXCLUDED.would_recommend,
        responded_at = now()
  RETURNING id INTO v_id;

  UPDATE public.founder_engineer_pulse_surveys s
     SET response_count = (
           SELECT COUNT(*) FROM public.founder_engineer_pulse_responses WHERE survey_id = s.id
         ),
         nps_score = (
           SELECT ROUND(
             (COUNT(*) FILTER (WHERE category = 'promoter')::numeric
              - COUNT(*) FILTER (WHERE category = 'detractor')::numeric)
              / NULLIF(COUNT(*) FILTER (WHERE nps_score IS NOT NULL), 0) * 100, 1)
             FROM public.founder_engineer_pulse_responses WHERE survey_id = s.id
         ),
         csat_score = (
           SELECT ROUND(AVG(csat_score)::numeric, 2)
             FROM public.founder_engineer_pulse_responses WHERE survey_id = s.id
         ),
         status = CASE WHEN s.status = 'draft' THEN 'collecting' ELSE s.status END
   WHERE s.id = p_survey_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_pulse_record_response(uuid, uuid, int, int, text, text, text, text, boolean) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_engineer_pulse_record_response(uuid, uuid, int, int, text, text, text, text, boolean) TO authenticated;

-- 8. Log: close survey
DROP FUNCTION IF EXISTS public.log_founder_engineer_pulse_close_survey(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_pulse_close_survey(p_survey_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.founder_engineer_pulse_surveys
     SET status = 'closed', closed_at = now()
   WHERE id = p_survey_id;
  RETURN p_survey_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_pulse_close_survey(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_engineer_pulse_close_survey(uuid) TO authenticated;

COMMIT;