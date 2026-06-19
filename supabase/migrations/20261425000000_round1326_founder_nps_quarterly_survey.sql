BEGIN;
-- r1326 — Hospital NPS quarterly survey infra.
-- Two tables (founder_nps_surveys + founder_nps_responses) + 3 write RPCs
-- (create_quarter, record_response, close_quarter) + 2 read RPCs
-- (founder_nps_quarterly_summary 15-KPI, founder_nps_responses_recent).
-- Send mechanism is offline-driven (email + SMS); responses logged via RPC.

-- ============================================================================
-- 1. Tables
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_nps_surveys (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label           text NOT NULL UNIQUE,
  period_start            date NOT NULL,
  period_end              date NOT NULL,
  status                  text NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','sent','collecting','closed','published')),
  target_recipient_count  int  NOT NULL DEFAULT 0,
  sent_count              int  NOT NULL DEFAULT 0,
  response_count          int  NOT NULL DEFAULT 0,
  promoter_count          int  NOT NULL DEFAULT 0,
  passive_count           int  NOT NULL DEFAULT 0,
  detractor_count         int  NOT NULL DEFAULT 0,
  nps_score               numeric,
  sent_at                 timestamptz,
  closed_at               timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_nps_responses (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id               uuid NOT NULL REFERENCES public.founder_nps_surveys(id) ON DELETE CASCADE,
  hospital_org_id         uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  respondent_name         text,
  respondent_role         text,
  score                   int  NOT NULL CHECK (score >= 0 AND score <= 10),
  category                text GENERATED ALWAYS AS (
    CASE WHEN score >= 9 THEN 'promoter'
         WHEN score >= 7 THEN 'passive'
         ELSE 'detractor' END
  ) STORED,
  qualitative_feedback    text,
  responded_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (survey_id, hospital_org_id)
);

CREATE INDEX IF NOT EXISTS idx_founder_nps_surveys_period
  ON public.founder_nps_surveys(period_start DESC);
CREATE INDEX IF NOT EXISTS idx_founder_nps_responses_survey
  ON public.founder_nps_responses(survey_id, responded_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_nps_responses_org
  ON public.founder_nps_responses(hospital_org_id, responded_at DESC);

ALTER TABLE public.founder_nps_surveys   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_nps_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_select_nps_surveys   ON public.founder_nps_surveys;
DROP POLICY IF EXISTS founder_only_select_nps_responses ON public.founder_nps_responses;
CREATE POLICY founder_only_select_nps_surveys   ON public.founder_nps_surveys
  FOR SELECT USING (public.is_founder());
CREATE POLICY founder_only_select_nps_responses ON public.founder_nps_responses
  FOR SELECT USING (public.is_founder());

REVOKE ALL ON public.founder_nps_surveys   FROM PUBLIC, anon;
REVOKE ALL ON public.founder_nps_responses FROM PUBLIC, anon;
GRANT SELECT ON public.founder_nps_surveys   TO authenticated;
GRANT SELECT ON public.founder_nps_responses TO authenticated;

-- ============================================================================
-- 2. RPC — quarterly summary (15 KPIs)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_nps_quarterly_summary();
CREATE OR REPLACE FUNCTION public.founder_nps_quarterly_summary()
RETURNS TABLE (
  latest_quarter_label                  text,
  latest_nps_score                      numeric,
  latest_response_count                 int,
  latest_promoter_pct                   numeric,
  latest_detractor_pct                  numeric,
  response_rate_pct                     numeric,
  prior_quarter_nps                     numeric,
  nps_delta_qoq                         numeric,
  all_time_promoter_count               int,
  all_time_detractor_count              int,
  surveys_sent_count                    int,
  surveys_closed_count                  int,
  hospitals_promoted_to_promoter_this_q int,
  hospitals_demoted_to_detractor_this_q int,
  median_score                          numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_latest_id uuid;
  v_prior_id  uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT id INTO v_latest_id
  FROM public.founder_nps_surveys
  ORDER BY period_start DESC LIMIT 1;

  SELECT id INTO v_prior_id
  FROM public.founder_nps_surveys
  WHERE period_start < (SELECT period_start FROM public.founder_nps_surveys WHERE id = v_latest_id)
  ORDER BY period_start DESC LIMIT 1;

  RETURN QUERY
  WITH latest AS (
    SELECT s.* FROM public.founder_nps_surveys s WHERE s.id = v_latest_id
  ),
  prior AS (
    SELECT s.* FROM public.founder_nps_surveys s WHERE s.id = v_prior_id
  ),
  latest_resp AS (
    SELECT r.* FROM public.founder_nps_responses r WHERE r.survey_id = v_latest_id
  ),
  prior_resp AS (
    SELECT r.hospital_org_id, r.category::text AS cat
    FROM public.founder_nps_responses r WHERE r.survey_id = v_prior_id
  ),
  cur_resp AS (
    SELECT r.hospital_org_id, r.category::text AS cat
    FROM public.founder_nps_responses r WHERE r.survey_id = v_latest_id
  ),
  promoted AS (
    SELECT c.hospital_org_id FROM cur_resp c
    JOIN prior_resp p ON p.hospital_org_id = c.hospital_org_id
    WHERE c.cat = 'promoter' AND p.cat <> 'promoter'
  ),
  demoted AS (
    SELECT c.hospital_org_id FROM cur_resp c
    JOIN prior_resp p ON p.hospital_org_id = c.hospital_org_id
    WHERE c.cat = 'detractor' AND p.cat <> 'detractor'
  )
  SELECT
    COALESCE((SELECT quarter_label FROM latest), 'n/a')::text,
    COALESCE((SELECT nps_score FROM latest), 0)::numeric,
    COALESCE((SELECT response_count FROM latest), 0)::int,
    CASE WHEN COALESCE((SELECT response_count FROM latest), 0) > 0
         THEN ROUND(100.0 * (SELECT promoter_count FROM latest)::numeric
                          / (SELECT response_count FROM latest)::numeric, 1)
         ELSE 0 END,
    CASE WHEN COALESCE((SELECT response_count FROM latest), 0) > 0
         THEN ROUND(100.0 * (SELECT detractor_count FROM latest)::numeric
                          / (SELECT response_count FROM latest)::numeric, 1)
         ELSE 0 END,
    CASE WHEN COALESCE((SELECT sent_count FROM latest), 0) > 0
         THEN ROUND(100.0 * (SELECT response_count FROM latest)::numeric
                          / (SELECT sent_count FROM latest)::numeric, 1)
         ELSE 0 END,
    COALESCE((SELECT nps_score FROM prior), 0)::numeric,
    (COALESCE((SELECT nps_score FROM latest), 0) - COALESCE((SELECT nps_score FROM prior), 0))::numeric,
    COALESCE((SELECT COUNT(*) FROM public.founder_nps_responses WHERE category = 'promoter'), 0)::int,
    COALESCE((SELECT COUNT(*) FROM public.founder_nps_responses WHERE category = 'detractor'), 0)::int,
    COALESCE((SELECT COUNT(*) FROM public.founder_nps_surveys WHERE status IN ('sent','collecting','closed','published')), 0)::int,
    COALESCE((SELECT COUNT(*) FROM public.founder_nps_surveys WHERE status IN ('closed','published')), 0)::int,
    (SELECT COUNT(*) FROM promoted)::int,
    (SELECT COUNT(*) FROM demoted)::int,
    COALESCE((SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score::numeric) FROM latest_resp), 0)::numeric;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_nps_quarterly_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_nps_quarterly_summary() TO authenticated;

-- ============================================================================
-- 3. RPC — recent responses (top N)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_nps_responses_recent(uuid, int);
CREATE OR REPLACE FUNCTION public.founder_nps_responses_recent(
  p_survey_id uuid DEFAULT NULL,
  p_limit     int  DEFAULT 50
)
RETURNS TABLE (
  id                   uuid,
  survey_id            uuid,
  quarter_label        text,
  hospital_org_id      uuid,
  hospital_name        text,
  respondent_name      text,
  respondent_role      text,
  score                int,
  category             text,
  qualitative_feedback text,
  responded_at         timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_survey_id uuid := p_survey_id;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  IF v_survey_id IS NULL THEN
    SELECT s.id INTO v_survey_id
    FROM public.founder_nps_surveys s
    ORDER BY s.period_start DESC LIMIT 1;
  END IF;

  RETURN QUERY
  SELECT r.id, r.survey_id, s.quarter_label, r.hospital_org_id,
         COALESCE(o.name, '(unknown)')::text,
         r.respondent_name, r.respondent_role,
         r.score, r.category::text, r.qualitative_feedback, r.responded_at
  FROM public.founder_nps_responses r
  JOIN public.founder_nps_surveys s ON s.id = r.survey_id
  LEFT JOIN public.organizations  o ON o.id = r.hospital_org_id
  WHERE (v_survey_id IS NULL OR r.survey_id = v_survey_id)
  ORDER BY r.responded_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_nps_responses_recent(uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_nps_responses_recent(uuid, int) TO authenticated;

-- ============================================================================
-- 4. RPC — create quarter (draft)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_nps_create_quarter(text, date, date);
CREATE OR REPLACE FUNCTION public.log_founder_nps_create_quarter(
  p_quarter_label text,
  p_period_start  date,
  p_period_end    date
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_quarter_label IS NULL OR length(trim(p_quarter_label)) = 0 THEN
    RAISE EXCEPTION 'quarter_label required';
  END IF;
  IF p_period_end < p_period_start THEN
    RAISE EXCEPTION 'period_end must be >= period_start';
  END IF;

  INSERT INTO public.founder_nps_surveys (quarter_label, period_start, period_end, status)
  VALUES (p_quarter_label, p_period_start, p_period_end, 'draft')
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_nps_create_quarter(text, date, date) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_nps_create_quarter(text, date, date) TO authenticated;

-- ============================================================================
-- 5. RPC — record response (used by hospital UI)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_nps_record_response(uuid, uuid, int, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_nps_record_response(
  p_survey_id      uuid,
  p_org_id         uuid,
  p_score          int,
  p_feedback       text,
  p_respondent_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_score < 0 OR p_score > 10 THEN
    RAISE EXCEPTION 'score must be 0..10';
  END IF;

  INSERT INTO public.founder_nps_responses
    (survey_id, hospital_org_id, score, qualitative_feedback, respondent_name)
  VALUES (p_survey_id, p_org_id, p_score, p_feedback, p_respondent_name)
  ON CONFLICT (survey_id, hospital_org_id)
  DO UPDATE SET score = EXCLUDED.score,
                qualitative_feedback = EXCLUDED.qualitative_feedback,
                respondent_name = EXCLUDED.respondent_name,
                responded_at = now()
  RETURNING id INTO v_id;

  UPDATE public.founder_nps_surveys s
  SET response_count  = (SELECT COUNT(*) FROM public.founder_nps_responses WHERE survey_id = s.id),
      promoter_count  = (SELECT COUNT(*) FROM public.founder_nps_responses WHERE survey_id = s.id AND category = 'promoter'),
      passive_count   = (SELECT COUNT(*) FROM public.founder_nps_responses WHERE survey_id = s.id AND category = 'passive'),
      detractor_count = (SELECT COUNT(*) FROM public.founder_nps_responses WHERE survey_id = s.id AND category = 'detractor'),
      status          = CASE WHEN s.status = 'draft' THEN 'collecting' ELSE s.status END
  WHERE s.id = p_survey_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_nps_record_response(uuid, uuid, int, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_nps_record_response(uuid, uuid, int, text, text) TO authenticated;

-- ============================================================================
-- 6. RPC — close quarter (recompute nps_score + status='closed')
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_nps_close_quarter(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_nps_close_quarter(p_survey_id uuid)
RETURNS numeric
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_prom  int;
  v_det   int;
  v_nps   numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT COUNT(*),
         COUNT(*) FILTER (WHERE category = 'promoter'),
         COUNT(*) FILTER (WHERE category = 'detractor')
  INTO v_total, v_prom, v_det
  FROM public.founder_nps_responses
  WHERE survey_id = p_survey_id;

  IF v_total = 0 THEN
    v_nps := 0;
  ELSE
    v_nps := ROUND(100.0 * (v_prom - v_det)::numeric / v_total::numeric, 1);
  END IF;

  UPDATE public.founder_nps_surveys
  SET nps_score = v_nps,
      response_count = v_total,
      promoter_count = v_prom,
      detractor_count = v_det,
      passive_count = v_total - v_prom - v_det,
      status = 'closed',
      closed_at = now()
  WHERE id = p_survey_id;

  RETURN v_nps;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_nps_close_quarter(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_nps_close_quarter(uuid) TO authenticated;

COMMIT;