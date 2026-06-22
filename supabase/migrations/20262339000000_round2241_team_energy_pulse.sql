-- Round 2241: Founder team-energy pulse
-- Weekly team energy/satisfaction surveys with themes (workload, recognition, growth, manager) and trend

BEGIN;

-- ============================================================================
-- TABLE 1: team_energy_pulse_surveys_r2241
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.team_energy_pulse_surveys_r2241 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  respondent_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  respondent_role text NOT NULL CHECK (respondent_role IN ('engineer','ops','support','sales','admin','founder')),
  week_start_date date NOT NULL,
  energy_score int NOT NULL CHECK (energy_score BETWEEN 1 AND 10),
  satisfaction_score int NOT NULL CHECK (satisfaction_score BETWEEN 1 AND 10),
  workload_score int NOT NULL CHECK (workload_score BETWEEN 1 AND 10),
  recognition_score int NOT NULL CHECK (recognition_score BETWEEN 1 AND 10),
  growth_score int NOT NULL CHECK (growth_score BETWEEN 1 AND 10),
  manager_score int NOT NULL CHECK (manager_score BETWEEN 1 AND 10),
  free_text_comment text,
  is_anonymous boolean NOT NULL DEFAULT true,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tep_surveys_r2241_week ON public.team_energy_pulse_surveys_r2241 (week_start_date DESC);
CREATE INDEX IF NOT EXISTS idx_tep_surveys_r2241_role ON public.team_energy_pulse_surveys_r2241 (respondent_role);

ALTER TABLE public.team_energy_pulse_surveys_r2241 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.team_energy_pulse_surveys_r2241;
CREATE POLICY founder_all ON public.team_energy_pulse_surveys_r2241
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: team_energy_pulse_themes_r2241
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.team_energy_pulse_themes_r2241 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid REFERENCES public.team_energy_pulse_surveys_r2241(id) ON DELETE CASCADE,
  theme text NOT NULL CHECK (theme IN ('workload','recognition','growth','manager','tooling','communication','compensation','culture')),
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative')),
  weight numeric(4,2) NOT NULL DEFAULT 1.0 CHECK (weight >= 0 AND weight <= 5),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tep_themes_r2241_survey ON public.team_energy_pulse_themes_r2241 (survey_id);
CREATE INDEX IF NOT EXISTS idx_tep_themes_r2241_theme ON public.team_energy_pulse_themes_r2241 (theme);

ALTER TABLE public.team_energy_pulse_themes_r2241 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.team_energy_pulse_themes_r2241;
CREATE POLICY founder_all ON public.team_energy_pulse_themes_r2241
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: Latest week summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tep_latest_week_r2241();
CREATE OR REPLACE FUNCTION public.founder_tep_latest_week_r2241()
RETURNS TABLE (
  week_start_date date,
  responses int,
  avg_energy numeric,
  avg_satisfaction numeric,
  avg_workload numeric,
  avg_recognition numeric,
  avg_growth numeric,
  avg_manager numeric
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
    s.week_start_date,
    (COUNT(*))::int AS responses,
    ROUND(AVG(s.energy_score)::numeric, 2),
    ROUND(AVG(s.satisfaction_score)::numeric, 2),
    ROUND(AVG(s.workload_score)::numeric, 2),
    ROUND(AVG(s.recognition_score)::numeric, 2),
    ROUND(AVG(s.growth_score)::numeric, 2),
    ROUND(AVG(s.manager_score)::numeric, 2)
  FROM public.team_energy_pulse_surveys_r2241 s
  WHERE s.week_start_date = (SELECT MAX(week_start_date) FROM public.team_energy_pulse_surveys_r2241)
  GROUP BY s.week_start_date;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_tep_latest_week_r2241() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tep_latest_week_r2241() TO authenticated;

-- ============================================================================
-- RPC 2: Trend over last 12 weeks
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tep_trend_r2241();
CREATE OR REPLACE FUNCTION public.founder_tep_trend_r2241()
RETURNS TABLE (
  week_start_date date,
  responses int,
  avg_energy numeric,
  avg_satisfaction numeric
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
    s.week_start_date,
    (COUNT(*))::int,
    ROUND(AVG(s.energy_score)::numeric, 2),
    ROUND(AVG(s.satisfaction_score)::numeric, 2)
  FROM public.team_energy_pulse_surveys_r2241 s
  WHERE s.week_start_date >= (CURRENT_DATE - INTERVAL '12 weeks')
  GROUP BY s.week_start_date
  ORDER BY s.week_start_date DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_tep_trend_r2241() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tep_trend_r2241() TO authenticated;

-- ============================================================================
-- RPC 3: By-role breakdown for latest week
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tep_by_role_r2241();
CREATE OR REPLACE FUNCTION public.founder_tep_by_role_r2241()
RETURNS TABLE (
  respondent_role text,
  responses int,
  avg_energy numeric,
  avg_satisfaction numeric,
  avg_workload numeric
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
    s.respondent_role,
    (COUNT(*))::int,
    ROUND(AVG(s.energy_score)::numeric, 2),
    ROUND(AVG(s.satisfaction_score)::numeric, 2),
    ROUND(AVG(s.workload_score)::numeric, 2)
  FROM public.team_energy_pulse_surveys_r2241 s
  WHERE s.week_start_date = (SELECT MAX(week_start_date) FROM public.team_energy_pulse_surveys_r2241)
  GROUP BY s.respondent_role
  ORDER BY (COUNT(*))::int DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_tep_by_role_r2241() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tep_by_role_r2241() TO authenticated;

-- ============================================================================
-- RPC 4: Theme sentiment distribution
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tep_theme_sentiment_r2241();
CREATE OR REPLACE FUNCTION public.founder_tep_theme_sentiment_r2241()
RETURNS TABLE (
  theme text,
  total_mentions int,
  positive_count int,
  neutral_count int,
  negative_count int,
  net_score numeric
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
    t.theme,
    (COUNT(*))::int AS total_mentions,
    (COUNT(*) FILTER (WHERE t.sentiment = 'positive'))::int,
    (COUNT(*) FILTER (WHERE t.sentiment = 'neutral'))::int,
    (COUNT(*) FILTER (WHERE t.sentiment = 'negative'))::int,
    ROUND(
      ((COUNT(*) FILTER (WHERE t.sentiment = 'positive'))::numeric
        - (COUNT(*) FILTER (WHERE t.sentiment = 'negative'))::numeric)
      / NULLIF(COUNT(*), 0)::numeric * 100,
      1
    ) AS net_score
  FROM public.team_energy_pulse_themes_r2241 t
  JOIN public.team_energy_pulse_surveys_r2241 s ON s.id = t.survey_id
  WHERE s.week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks')
  GROUP BY t.theme
  ORDER BY total_mentions DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_tep_theme_sentiment_r2241() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tep_theme_sentiment_r2241() TO authenticated;

-- ============================================================================
-- RPC 5: Recent responses list
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tep_recent_responses_r2241();
CREATE OR REPLACE FUNCTION public.founder_tep_recent_responses_r2241()
RETURNS TABLE (
  id uuid,
  respondent_role text,
  week_start_date date,
  energy_score int,
  satisfaction_score int,
  free_text_comment text,
  is_anonymous boolean,
  submitted_at timestamptz
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
    s.id,
    s.respondent_role,
    s.week_start_date,
    s.energy_score,
    s.satisfaction_score,
    s.free_text_comment,
    s.is_anonymous,
    s.submitted_at
  FROM public.team_energy_pulse_surveys_r2241 s
  ORDER BY s.submitted_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_tep_recent_responses_r2241() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tep_recent_responses_r2241() TO authenticated;

-- ============================================================================
-- RPC 6: Negative theme flags (early warning)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tep_negative_flags_r2241();
CREATE OR REPLACE FUNCTION public.founder_tep_negative_flags_r2241()
RETURNS TABLE (
  theme text,
  recent_negative_count int,
  total_recent_mentions int,
  pct_negative numeric,
  latest_note text
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
    t.theme,
    (COUNT(*) FILTER (WHERE t.sentiment = 'negative'))::int,
    (COUNT(*))::int,
    ROUND(
      (COUNT(*) FILTER (WHERE t.sentiment = 'negative'))::numeric
      / NULLIF(COUNT(*), 0)::numeric * 100,
      1
    ),
    (
      SELECT t2.note FROM public.team_energy_pulse_themes_r2241 t2
      WHERE t2.theme = t.theme AND t2.sentiment = 'negative' AND t2.note IS NOT NULL
      ORDER BY t2.created_at DESC LIMIT 1
    )
  FROM public.team_energy_pulse_themes_r2241 t
  JOIN public.team_energy_pulse_surveys_r2241 s ON s.id = t.survey_id
  WHERE s.week_start_date >= (CURRENT_DATE - INTERVAL '2 weeks')
  GROUP BY t.theme
  HAVING (COUNT(*) FILTER (WHERE t.sentiment = 'negative'))::int >= 2
  ORDER BY (COUNT(*) FILTER (WHERE t.sentiment = 'negative'))::int DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_tep_negative_flags_r2241() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tep_negative_flags_r2241() TO authenticated;

-- ============================================================================
-- RPC 7: KPI summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_tep_kpis_r2241();
CREATE OR REPLACE FUNCTION public.founder_tep_kpis_r2241()
RETURNS TABLE (
  total_surveys int,
  surveys_last_4w int,
  unique_respondents int,
  avg_energy_4w numeric,
  avg_satisfaction_4w numeric,
  pct_anonymous int,
  themes_tracked int
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
    (SELECT COUNT(*) FROM public.team_energy_pulse_surveys_r2241)::int,
    (SELECT COUNT(*) FROM public.team_energy_pulse_surveys_r2241
       WHERE week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks'))::int,
    (SELECT COUNT(DISTINCT respondent_user_id) FROM public.team_energy_pulse_surveys_r2241
       WHERE respondent_user_id IS NOT NULL)::int,
    COALESCE((SELECT ROUND(AVG(energy_score)::numeric, 2) FROM public.team_energy_pulse_surveys_r2241
       WHERE week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks')), 0)::numeric,
    COALESCE((SELECT ROUND(AVG(satisfaction_score)::numeric, 2) FROM public.team_energy_pulse_surveys_r2241
       WHERE week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks')), 0)::numeric,
    COALESCE((
      SELECT (COUNT(*) FILTER (WHERE is_anonymous) * 100 / NULLIF(COUNT(*), 0))::int
      FROM public.team_energy_pulse_surveys_r2241
    ), 0),
    (SELECT COUNT(DISTINCT theme) FROM public.team_energy_pulse_themes_r2241)::int;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_tep_kpis_r2241() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_tep_kpis_r2241() TO authenticated;

COMMIT;
