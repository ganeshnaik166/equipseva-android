-- Round 2545: founder-quarterly-team-pulse-survey
-- Tracks quarterly team pulse surveys + response themes for founder action planning.

CREATE TABLE IF NOT EXISTS public.founder_team_pulse_surveys_r2545 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  sent_at timestamptz,
  team_size int NOT NULL DEFAULT 0,
  response_count int NOT NULL DEFAULT 0,
  response_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  overall_pulse_score int NOT NULL DEFAULT 50 CHECK (overall_pulse_score BETWEEN 0 AND 100),
  top_concern_md text,
  action_plan_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','sent','in_progress','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.team_pulse_response_themes_r2545 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid NOT NULL REFERENCES public.founder_team_pulse_surveys_r2545(id) ON DELETE CASCADE,
  theme_kind text NOT NULL CHECK (theme_kind IN ('compensation','career_growth','leadership','culture','burnout','tools','recognition','clarity')),
  mentions_count int NOT NULL DEFAULT 0,
  sentiment text NOT NULL CHECK (sentiment IN ('positive','neutral','negative','mixed')),
  founder_response_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_team_pulse_surveys_r2545 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_pulse_response_themes_r2545 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_team_pulse_surveys_r2545;
CREATE POLICY founder_all ON public.founder_team_pulse_surveys_r2545
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.team_pulse_response_themes_r2545;
CREATE POLICY founder_all ON public.team_pulse_response_themes_r2545
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed surveys
INSERT INTO public.founder_team_pulse_surveys_r2545
  (id, quarter_label, sent_at, team_size, response_count, response_rate_pct, overall_pulse_score, top_concern_md, action_plan_md, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111'::uuid, 'Q1-2026', '2026-01-15 10:00:00'::timestamptz, 42, 38, 90.48, 78,
   '- Compensation review overdue\n- Career growth ladder unclear for engineers',
   '- Roll out comp band Q2\n- Publish IC ladder by week 4',
   'founder@equipseva.in', 'closed', 'Strong response rate, comp top theme'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'Q4-2025', '2025-10-12 09:30:00'::timestamptz, 36, 30, 83.33, 71,
   '- Tools/stack churn\n- Leadership clarity in remote-first',
   '- Freeze stack changes for Q1\n- Weekly leadership AMA',
   'founder@equipseva.in', 'closed', 'Tools fatigue called out'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'Q3-2025', '2025-07-08 11:00:00'::timestamptz, 28, 25, 89.29, 74,
   '- Recognition cadence\n- Burnout in support team',
   '- Monthly kudos channel live\n- Hire 2 support engineers',
   'founder@equipseva.in', 'closed', 'Support burnout flagged'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'Q2-2026', '2026-04-10 09:00:00'::timestamptz, 48, 31, 64.58, 68,
   '- Burnout post-launch\n- Career growth still murky',
   '- Mandatory week-off rotation\n- IC ladder v2 by week 6',
   'founder@equipseva.in', 'in_progress', 'Response rate dipped post-launch crunch'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'Q3-2026', NULL, 52, 0, 0, 50,
   NULL, NULL, 'founder@equipseva.in', 'planned', 'Survey planned for July week 2');

-- Seed themes
INSERT INTO public.team_pulse_response_themes_r2545
  (survey_id, theme_kind, mentions_count, sentiment, founder_response_md, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111'::uuid, 'compensation', 22, 'negative', 'Comp bands locked Q2, retro 6%', 'founder@equipseva.in', 'done', 'Top concern'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'career_growth', 18, 'mixed', 'IC ladder published week 4', 'founder@equipseva.in', 'done', 'Engineers asked for senior-staff path'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'culture', 12, 'positive', 'Keep founder Friday demo', 'founder@equipseva.in', 'done', 'Culture rated high'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'tools', 16, 'negative', 'Stack freeze Q1', 'founder@equipseva.in', 'done', 'Too many tools rolled out'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'leadership', 11, 'mixed', 'Weekly AMA live', 'founder@equipseva.in', 'done', 'Clarity in remote-first ask'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'burnout', 14, 'negative', '2 support hires landed', 'founder@equipseva.in', 'done', 'Support team flagged hardest'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'recognition', 9, 'mixed', 'Kudos channel live', 'founder@equipseva.in', 'done', 'Monthly cadence'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'burnout', 19, 'negative', 'Mandatory week-off rotation rolled out', 'founder@equipseva.in', 'in_progress', 'Post-launch crunch'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'career_growth', 13, 'negative', 'IC ladder v2 in progress', 'founder@equipseva.in', 'in_progress', 'Still murky for senior ICs'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'clarity', 8, 'mixed', 'Roadmap doc refresh week 5', 'founder@equipseva.in', 'open', 'Quarterly OKR clarity'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'recognition', 6, 'positive', 'Continue kudos cadence', 'founder@equipseva.in', 'done', 'Working well');

-- RPC 1: list_surveys_r2545
CREATE OR REPLACE FUNCTION public.list_surveys_r2545()
RETURNS SETOF public.founder_team_pulse_surveys_r2545
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_team_pulse_surveys_r2545 ORDER BY quarter_label DESC, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_surveys_r2545() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_surveys_r2545() TO authenticated;

-- RPC 2: list_response_themes_r2545
CREATE OR REPLACE FUNCTION public.list_response_themes_r2545()
RETURNS SETOF public.team_pulse_response_themes_r2545
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.team_pulse_response_themes_r2545 ORDER BY mentions_count DESC, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_response_themes_r2545() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_response_themes_r2545() TO authenticated;

-- RPC 3: quarterly_pulse_trend_r2545
CREATE OR REPLACE FUNCTION public.quarterly_pulse_trend_r2545()
RETURNS TABLE(quarter_label text, overall_pulse_score int, response_rate_pct numeric, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.quarter_label, s.overall_pulse_score, s.response_rate_pct, s.status
    FROM public.founder_team_pulse_surveys_r2545 s
    ORDER BY s.quarter_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_pulse_trend_r2545() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_pulse_trend_r2545() TO authenticated;

-- RPC 4: theme_sentiment_summary_r2545
CREATE OR REPLACE FUNCTION public.theme_sentiment_summary_r2545()
RETURNS TABLE(theme_kind text, total_mentions bigint, negative_mentions bigint, positive_mentions bigint, mixed_mentions bigint, neutral_mentions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      t.theme_kind,
      SUM(t.mentions_count)::bigint AS total_mentions,
      SUM(CASE WHEN t.sentiment = 'negative' THEN t.mentions_count ELSE 0 END)::bigint AS negative_mentions,
      SUM(CASE WHEN t.sentiment = 'positive' THEN t.mentions_count ELSE 0 END)::bigint AS positive_mentions,
      SUM(CASE WHEN t.sentiment = 'mixed' THEN t.mentions_count ELSE 0 END)::bigint AS mixed_mentions,
      SUM(CASE WHEN t.sentiment = 'neutral' THEN t.mentions_count ELSE 0 END)::bigint AS neutral_mentions
    FROM public.team_pulse_response_themes_r2545 t
    GROUP BY t.theme_kind
    ORDER BY total_mentions DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.theme_sentiment_summary_r2545() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.theme_sentiment_summary_r2545() TO authenticated;

-- RPC 5: top_concerns_focus_r2545
CREATE OR REPLACE FUNCTION public.top_concerns_focus_r2545()
RETURNS TABLE(quarter_label text, theme_kind text, mentions_count int, sentiment text, status text, founder_response_md text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.quarter_label, t.theme_kind, t.mentions_count, t.sentiment, t.status, t.founder_response_md
    FROM public.team_pulse_response_themes_r2545 t
    JOIN public.founder_team_pulse_surveys_r2545 s ON s.id = t.survey_id
    WHERE t.sentiment IN ('negative','mixed')
    ORDER BY t.mentions_count DESC, s.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_concerns_focus_r2545() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_concerns_focus_r2545() TO authenticated;

-- RPC 6: action_status_funnel_r2545
CREATE OR REPLACE FUNCTION public.action_status_funnel_r2545()
RETURNS TABLE(status text, theme_count bigint, total_mentions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.status, COUNT(*)::bigint AS theme_count, SUM(t.mentions_count)::bigint AS total_mentions
    FROM public.team_pulse_response_themes_r2545 t
    GROUP BY t.status
    ORDER BY theme_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_status_funnel_r2545() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_status_funnel_r2545() TO authenticated;

-- RPC 7: response_rate_trend_r2545
CREATE OR REPLACE FUNCTION public.response_rate_trend_r2545()
RETURNS TABLE(quarter_label text, team_size int, response_count int, response_rate_pct numeric, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.quarter_label, s.team_size, s.response_count, s.response_rate_pct, s.status
    FROM public.founder_team_pulse_surveys_r2545 s
    ORDER BY s.quarter_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.response_rate_trend_r2545() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.response_rate_trend_r2545() TO authenticated;
