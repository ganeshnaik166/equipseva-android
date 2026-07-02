BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_quote_highlights_r2325 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  captured_at timestamptz NOT NULL DEFAULT now(),
  week_starting date NOT NULL,
  investor_name text NOT NULL,
  investor_firm text,
  investor_stage text NOT NULL CHECK (investor_stage IN ('angel','pre_seed','seed','series_a','series_b','growth','strategic')),
  conversation_channel text NOT NULL CHECK (conversation_channel IN ('call','email','meeting','dm','warm_intro','pitch','dd_call')),
  quote_text text NOT NULL,
  quote_context text,
  theme text NOT NULL CHECK (theme IN ('moat','unit_economics','team','market_size','traction','competition','timing','risk','pricing','distribution','regulation','ai_thesis','exit','founder_quality','product')),
  sentiment text NOT NULL CHECK (sentiment IN ('signal_strong','signal_mild','neutral','concern_mild','concern_strong','red_flag')),
  worth_remembering_score int NOT NULL CHECK (worth_remembering_score BETWEEN 1 AND 5),
  founder_learning text NOT NULL,
  action_implication text,
  shareable_externally boolean NOT NULL DEFAULT false,
  pinned_to_board_deck boolean NOT NULL DEFAULT false,
  captured_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_quote_weekly_themes_r2325 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_starting date NOT NULL,
  theme text NOT NULL,
  recurrence_count int NOT NULL DEFAULT 1,
  net_sentiment_score numeric(4,2) NOT NULL DEFAULT 0,
  founder_synthesis text,
  changed_thinking boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (week_starting, theme)
);

CREATE INDEX IF NOT EXISTS idx_iqh_r2325_week ON public.investor_quote_highlights_r2325(week_starting DESC, worth_remembering_score DESC);
CREATE INDEX IF NOT EXISTS idx_iqh_r2325_theme ON public.investor_quote_highlights_r2325(theme, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_iqh_r2325_sentiment ON public.investor_quote_highlights_r2325(sentiment, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_iqwt_r2325_week ON public.investor_quote_weekly_themes_r2325(week_starting DESC);

ALTER TABLE public.investor_quote_highlights_r2325 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_quote_weekly_themes_r2325 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_quote_highlights_r2325;
CREATE POLICY founder_all ON public.investor_quote_highlights_r2325
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.investor_quote_weekly_themes_r2325;
CREATE POLICY founder_all ON public.investor_quote_weekly_themes_r2325
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list weekly reel
CREATE OR REPLACE FUNCTION public.fn_iqh_r2325_weekly_reel(p_week_starting date DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  captured_at timestamptz,
  investor_name text,
  investor_firm text,
  investor_stage text,
  quote_text text,
  theme text,
  sentiment text,
  worth_remembering_score int,
  founder_learning text,
  pinned_to_board_deck boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_week date := COALESCE(p_week_starting, date_trunc('week', now())::date);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.captured_at, h.investor_name, h.investor_firm, h.investor_stage,
           h.quote_text, h.theme, h.sentiment, h.worth_remembering_score,
           h.founder_learning, h.pinned_to_board_deck
    FROM public.investor_quote_highlights_r2325 h
    WHERE h.week_starting = v_week
    ORDER BY h.worth_remembering_score DESC, h.captured_at DESC;
END $$;

-- RPC 2: theme rollup
CREATE OR REPLACE FUNCTION public.fn_iqh_r2325_theme_rollup(p_week_starting date DEFAULT NULL)
RETURNS TABLE (
  theme text,
  quote_count int,
  avg_score numeric,
  positive_count int,
  concern_count int,
  pinned_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_week date := COALESCE(p_week_starting, date_trunc('week', now())::date);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.theme,
           COUNT(*)::int,
           ROUND(AVG(h.worth_remembering_score)::numeric, 2),
           COUNT(*) FILTER (WHERE h.sentiment IN ('signal_strong','signal_mild'))::int,
           COUNT(*) FILTER (WHERE h.sentiment IN ('concern_mild','concern_strong','red_flag'))::int,
           COUNT(*) FILTER (WHERE h.pinned_to_board_deck)::int
    FROM public.investor_quote_highlights_r2325 h
    WHERE h.week_starting = v_week
    GROUP BY h.theme
    ORDER BY COUNT(*) DESC;
END $$;

-- RPC 3: top quotes all-time
CREATE OR REPLACE FUNCTION public.fn_iqh_r2325_top_quotes(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  captured_at timestamptz,
  investor_name text,
  quote_text text,
  theme text,
  worth_remembering_score int,
  founder_learning text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.captured_at, h.investor_name, h.quote_text, h.theme,
           h.worth_remembering_score, h.founder_learning
    FROM public.investor_quote_highlights_r2325 h
    WHERE h.worth_remembering_score >= 4
    ORDER BY h.worth_remembering_score DESC, h.captured_at DESC
    LIMIT GREATEST(1, LEAST(p_limit, 100));
END $$;

-- RPC 4: sentiment trend by week
CREATE OR REPLACE FUNCTION public.fn_iqh_r2325_sentiment_trend(p_weeks int DEFAULT 8)
RETURNS TABLE (
  week_starting date,
  total_quotes int,
  signal_count int,
  concern_count int,
  net_score numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.week_starting,
           COUNT(*)::int,
           COUNT(*) FILTER (WHERE h.sentiment IN ('signal_strong','signal_mild'))::int,
           COUNT(*) FILTER (WHERE h.sentiment IN ('concern_mild','concern_strong','red_flag'))::int,
           ROUND((
             COUNT(*) FILTER (WHERE h.sentiment = 'signal_strong')::numeric * 2
             + COUNT(*) FILTER (WHERE h.sentiment = 'signal_mild')::numeric
             - COUNT(*) FILTER (WHERE h.sentiment = 'concern_mild')::numeric
             - COUNT(*) FILTER (WHERE h.sentiment = 'concern_strong')::numeric * 2
             - COUNT(*) FILTER (WHERE h.sentiment = 'red_flag')::numeric * 3
           ) / GREATEST(COUNT(*),1)::numeric, 2)
    FROM public.investor_quote_highlights_r2325 h
    WHERE h.week_starting >= (date_trunc('week', now())::date - (GREATEST(1, LEAST(p_weeks, 52)) || ' weeks')::interval)
    GROUP BY h.week_starting
    ORDER BY h.week_starting DESC;
END $$;

-- RPC 5: pinned for board deck
CREATE OR REPLACE FUNCTION public.fn_iqh_r2325_board_pinned()
RETURNS TABLE (
  id uuid,
  captured_at timestamptz,
  investor_name text,
  investor_firm text,
  quote_text text,
  theme text,
  founder_learning text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.captured_at, h.investor_name, h.investor_firm, h.quote_text, h.theme, h.founder_learning
    FROM public.investor_quote_highlights_r2325 h
    WHERE h.pinned_to_board_deck = true
    ORDER BY h.captured_at DESC;
END $$;

-- RPC 6: stage breakdown
CREATE OR REPLACE FUNCTION public.fn_iqh_r2325_stage_breakdown()
RETURNS TABLE (
  investor_stage text,
  quote_count int,
  avg_score numeric,
  unique_investors int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.investor_stage,
           COUNT(*)::int,
           ROUND(AVG(h.worth_remembering_score)::numeric, 2),
           COUNT(DISTINCT h.investor_name)::int
    FROM public.investor_quote_highlights_r2325 h
    GROUP BY h.investor_stage
    ORDER BY COUNT(*) DESC;
END $$;

-- RPC 7: changed-thinking quotes
CREATE OR REPLACE FUNCTION public.fn_iqh_r2325_changed_thinking()
RETURNS TABLE (
  id uuid,
  captured_at timestamptz,
  investor_name text,
  quote_text text,
  founder_learning text,
  action_implication text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT h.id, h.captured_at, h.investor_name, h.quote_text, h.founder_learning, h.action_implication
    FROM public.investor_quote_highlights_r2325 h
    WHERE h.action_implication IS NOT NULL AND length(h.action_implication) > 0
    ORDER BY h.worth_remembering_score DESC, h.captured_at DESC
    LIMIT 50;
END $$;

REVOKE ALL ON FUNCTION public.fn_iqh_r2325_weekly_reel(date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_iqh_r2325_theme_rollup(date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_iqh_r2325_top_quotes(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_iqh_r2325_sentiment_trend(int) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_iqh_r2325_board_pinned() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_iqh_r2325_stage_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_iqh_r2325_changed_thinking() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fn_iqh_r2325_weekly_reel(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_iqh_r2325_theme_rollup(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_iqh_r2325_top_quotes(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_iqh_r2325_sentiment_trend(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_iqh_r2325_board_pinned() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_iqh_r2325_stage_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_iqh_r2325_changed_thinking() TO authenticated;

COMMIT;
