BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_weekly_okr_dashboard_r1814 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  total_okrs int NOT NULL DEFAULT 0,
  on_track int NOT NULL DEFAULT 0,
  at_risk int NOT NULL DEFAULT 0,
  missed int NOT NULL DEFAULT 0,
  completed int NOT NULL DEFAULT 0,
  week_score numeric(5,2) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_weekly_okr_highlights_r1814 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL REFERENCES public.founder_weekly_okr_dashboard_r1814(week_start) ON DELETE CASCADE,
  highlight_type text NOT NULL CHECK (highlight_type IN ('win','loss','learning','next_focus')),
  highlight_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_weekly_okr_dashboard_r1814 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_weekly_okr_highlights_r1814 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_dashboard_r1814 ON public.founder_weekly_okr_dashboard_r1814;
CREATE POLICY founder_all_dashboard_r1814 ON public.founder_weekly_okr_dashboard_r1814
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_highlights_r1814 ON public.founder_weekly_okr_highlights_r1814;
CREATE POLICY founder_all_highlights_r1814 ON public.founder_weekly_okr_highlights_r1814
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_weeks_r1814()
RETURNS TABLE (week_start date, total_okrs int, on_track int, at_risk int, missed int, completed int, week_score numeric, recorded_at timestamptz, founder_note text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.week_start, d.total_okrs, d.on_track, d.at_risk, d.missed, d.completed, d.week_score, d.recorded_at, d.founder_note
  FROM public.founder_weekly_okr_dashboard_r1814 d
  ORDER BY d.week_start DESC
  LIMIT 52;
END $$;

CREATE OR REPLACE FUNCTION public.record_week_r1814(
  p_week_start date,
  p_total_okrs int,
  p_on_track int,
  p_at_risk int,
  p_missed int,
  p_completed int,
  p_week_score numeric,
  p_founder_note text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_weekly_okr_dashboard_r1814 (week_start, total_okrs, on_track, at_risk, missed, completed, week_score, founder_note)
  VALUES (p_week_start, p_total_okrs, p_on_track, p_at_risk, p_missed, p_completed, p_week_score, p_founder_note)
  ON CONFLICT (week_start) DO UPDATE SET
    total_okrs = EXCLUDED.total_okrs,
    on_track = EXCLUDED.on_track,
    at_risk = EXCLUDED.at_risk,
    missed = EXCLUDED.missed,
    completed = EXCLUDED.completed,
    week_score = EXCLUDED.week_score,
    founder_note = EXCLUDED.founder_note,
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_week_r1814',
    jsonb_build_object('week_start', p_week_start, 'week_score', p_week_score, 'total_okrs', p_total_okrs));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_highlights_r1814(p_week_start date)
RETURNS TABLE (id uuid, highlight_type text, highlight_text text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.highlight_type, h.highlight_text, h.created_at
  FROM public.founder_weekly_okr_highlights_r1814 h
  WHERE h.week_start = p_week_start
  ORDER BY h.created_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.add_highlight_r1814(
  p_week_start date,
  p_highlight_type text,
  p_highlight_text text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_highlight_type NOT IN ('win','loss','learning','next_focus') THEN
    RAISE EXCEPTION 'invalid highlight_type';
  END IF;
  INSERT INTO public.founder_weekly_okr_highlights_r1814 (week_start, highlight_type, highlight_text)
  VALUES (p_week_start, p_highlight_type, p_highlight_text)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_highlight_r1814',
    jsonb_build_object('week_start', p_week_start, 'highlight_type', p_highlight_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.week_score_trend_r1814()
RETURNS TABLE (week_start date, week_score numeric, total_okrs int, completed int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.week_start, d.week_score, d.total_okrs, d.completed
  FROM public.founder_weekly_okr_dashboard_r1814 d
  ORDER BY d.week_start DESC
  LIMIT 12;
END $$;

CREATE OR REPLACE FUNCTION public.biggest_wins_r1814()
RETURNS TABLE (week_start date, highlight_text text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.week_start, h.highlight_text, h.created_at
  FROM public.founder_weekly_okr_highlights_r1814 h
  WHERE h.highlight_type = 'win'
  ORDER BY h.created_at DESC
  LIMIT 20;
END $$;

CREATE OR REPLACE FUNCTION public.biggest_losses_r1814()
RETURNS TABLE (week_start date, highlight_text text, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.week_start, h.highlight_text, h.created_at
  FROM public.founder_weekly_okr_highlights_r1814 h
  WHERE h.highlight_type = 'loss'
  ORDER BY h.created_at DESC
  LIMIT 20;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_weeks_r1814() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_week_r1814(date,int,int,int,int,int,numeric,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_highlights_r1814(date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_highlight_r1814(date,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.week_score_trend_r1814() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.biggest_wins_r1814() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.biggest_losses_r1814() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_weeks_r1814() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_week_r1814(date,int,int,int,int,int,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_highlights_r1814(date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_highlight_r1814(date,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.week_score_trend_r1814() TO authenticated;
GRANT EXECUTE ON FUNCTION public.biggest_wins_r1814() TO authenticated;
GRANT EXECUTE ON FUNCTION public.biggest_losses_r1814() TO authenticated;

COMMIT;