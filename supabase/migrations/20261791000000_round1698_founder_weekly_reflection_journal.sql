BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.founder_weekly_journals_r1698 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL UNIQUE,
  wins_md text,
  losses_md text,
  learnings_md text,
  next_focus_md text,
  mood_rating int CHECK (mood_rating BETWEEN 1 AND 5),
  gratitude_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_weekly_journal_tags_r1698 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_id uuid NOT NULL REFERENCES public.founder_weekly_journals_r1698(id) ON DELETE CASCADE,
  tag text NOT NULL,
  weight int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwj_r1698_week ON public.founder_weekly_journals_r1698(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_fwjt_r1698_journal ON public.founder_weekly_journal_tags_r1698(journal_id);
CREATE INDEX IF NOT EXISTS idx_fwjt_r1698_tag ON public.founder_weekly_journal_tags_r1698(tag);

-- RLS
ALTER TABLE public.founder_weekly_journals_r1698 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_weekly_journal_tags_r1698 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fwj_r1698_founder_all ON public.founder_weekly_journals_r1698;
CREATE POLICY fwj_r1698_founder_all ON public.founder_weekly_journals_r1698
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fwjt_r1698_founder_all ON public.founder_weekly_journal_tags_r1698;
CREATE POLICY fwjt_r1698_founder_all ON public.founder_weekly_journal_tags_r1698
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPCs

-- 1. list_journals
CREATE OR REPLACE FUNCTION public.list_journals_r1698()
RETURNS TABLE(
  id uuid,
  week_start date,
  wins_md text,
  losses_md text,
  learnings_md text,
  next_focus_md text,
  mood_rating int,
  gratitude_md text,
  tag_count int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, j.week_start, j.wins_md, j.losses_md, j.learnings_md, j.next_focus_md,
         j.mood_rating, j.gratitude_md,
         (SELECT (COUNT(*))::int FROM public.founder_weekly_journal_tags_r1698 t WHERE t.journal_id = j.id) AS tag_count,
         j.created_at
  FROM public.founder_weekly_journals_r1698 j
  ORDER BY j.week_start DESC
  LIMIT 200;
END;
$$;

-- 2. record_journal
CREATE OR REPLACE FUNCTION public.record_journal_r1698(
  p_week_start date,
  p_wins_md text,
  p_losses_md text,
  p_learnings_md text,
  p_next_focus_md text,
  p_mood_rating int,
  p_gratitude_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_weekly_journals_r1698(
    week_start, wins_md, losses_md, learnings_md, next_focus_md, mood_rating, gratitude_md
  ) VALUES (
    p_week_start, p_wins_md, p_losses_md, p_learnings_md, p_next_focus_md, p_mood_rating, p_gratitude_md
  )
  ON CONFLICT (week_start) DO UPDATE
    SET wins_md = EXCLUDED.wins_md,
        losses_md = EXCLUDED.losses_md,
        learnings_md = EXCLUDED.learnings_md,
        next_focus_md = EXCLUDED.next_focus_md,
        mood_rating = EXCLUDED.mood_rating,
        gratitude_md = EXCLUDED.gratitude_md,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_journal_r1698',
          jsonb_build_object('journal_id', v_id, 'week_start', p_week_start, 'mood', p_mood_rating));

  RETURN v_id;
END;
$$;

-- 3. list_tags
CREATE OR REPLACE FUNCTION public.list_tags_r1698(p_journal_id uuid DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  journal_id uuid,
  week_start date,
  tag text,
  weight int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.journal_id, j.week_start, t.tag, t.weight, t.created_at
  FROM public.founder_weekly_journal_tags_r1698 t
  JOIN public.founder_weekly_journals_r1698 j ON j.id = t.journal_id
  WHERE p_journal_id IS NULL OR t.journal_id = p_journal_id
  ORDER BY j.week_start DESC, t.weight DESC
  LIMIT 500;
END;
$$;

-- 4. add_tag
CREATE OR REPLACE FUNCTION public.add_tag_r1698(
  p_journal_id uuid,
  p_tag text,
  p_weight int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_weekly_journal_tags_r1698(journal_id, tag, weight)
  VALUES (p_journal_id, lower(trim(p_tag)), COALESCE(p_weight, 1))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_tag_r1698',
          jsonb_build_object('tag_id', v_id, 'journal_id', p_journal_id, 'tag', p_tag));

  RETURN v_id;
END;
$$;

-- 5. tag_frequency
CREATE OR REPLACE FUNCTION public.tag_frequency_r1698()
RETURNS TABLE(
  tag text,
  occurrences int,
  total_weight int,
  last_seen date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.tag,
         (COUNT(*))::int AS occurrences,
         (SUM(t.weight))::int AS total_weight,
         MAX(j.week_start) AS last_seen
  FROM public.founder_weekly_journal_tags_r1698 t
  JOIN public.founder_weekly_journals_r1698 j ON j.id = t.journal_id
  GROUP BY t.tag
  ORDER BY occurrences DESC, total_weight DESC
  LIMIT 100;
END;
$$;

-- 6. recent_themes
CREATE OR REPLACE FUNCTION public.recent_themes_r1698(p_weeks int DEFAULT 8)
RETURNS TABLE(
  tag text,
  recent_occurrences int,
  recent_weight int,
  first_week date,
  last_week date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.tag,
         (COUNT(*))::int AS recent_occurrences,
         (SUM(t.weight))::int AS recent_weight,
         MIN(j.week_start) AS first_week,
         MAX(j.week_start) AS last_week
  FROM public.founder_weekly_journal_tags_r1698 t
  JOIN public.founder_weekly_journals_r1698 j ON j.id = t.journal_id
  WHERE j.week_start >= (CURRENT_DATE - (COALESCE(p_weeks, 8) * 7))
  GROUP BY t.tag
  ORDER BY recent_occurrences DESC, recent_weight DESC
  LIMIT 50;
END;
$$;

-- 7. mood_trend
CREATE OR REPLACE FUNCTION public.mood_trend_r1698(p_weeks int DEFAULT 26)
RETURNS TABLE(
  week_start date,
  mood_rating int,
  rolling_avg numeric,
  has_entry boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.week_start,
         j.mood_rating,
         ROUND(AVG(j.mood_rating) OVER (ORDER BY j.week_start ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) AS rolling_avg,
         (j.mood_rating IS NOT NULL) AS has_entry
  FROM public.founder_weekly_journals_r1698 j
  WHERE j.week_start >= (CURRENT_DATE - (COALESCE(p_weeks, 26) * 7))
  ORDER BY j.week_start DESC;
END;
$$;

-- Permissions
REVOKE EXECUTE ON FUNCTION public.list_journals_r1698() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_journal_r1698(date, text, text, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_tags_r1698(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_tag_r1698(uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.tag_frequency_r1698() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_themes_r1698(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mood_trend_r1698(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_journals_r1698() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_journal_r1698(date, text, text, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_tags_r1698(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_tag_r1698(uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tag_frequency_r1698() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_themes_r1698(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mood_trend_r1698(int) TO authenticated;

COMMIT;