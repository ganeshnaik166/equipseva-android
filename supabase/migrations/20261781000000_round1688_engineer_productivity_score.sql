BEGIN;

-- ============================================================
-- Round 1688: Engineer Productivity Score
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_productivity_scores_r1688 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score_window text NOT NULL CHECK (score_window IN ('week','month','quarter')),
  window_start date NOT NULL,
  jobs_completed int NOT NULL DEFAULT 0,
  avg_rating numeric(4,2) NOT NULL DEFAULT 0,
  hours_logged numeric(8,2) NOT NULL DEFAULT 0,
  km_traveled int NOT NULL DEFAULT 0,
  productivity_score numeric(6,2) NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, score_window, window_start)
);

CREATE INDEX IF NOT EXISTS idx_eps_r1688_engineer ON public.engineer_productivity_scores_r1688(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eps_r1688_window ON public.engineer_productivity_scores_r1688(score_window, window_start DESC);
CREATE INDEX IF NOT EXISTS idx_eps_r1688_score ON public.engineer_productivity_scores_r1688(productivity_score DESC);

CREATE TABLE IF NOT EXISTS public.engineer_productivity_review_notes_r1688 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score_id uuid NOT NULL REFERENCES public.engineer_productivity_scores_r1688(id) ON DELETE CASCADE,
  founder_note_md text NOT NULL,
  action text NOT NULL CHECK (action IN ('coach','promote','PIP','keep')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eprn_r1688_score ON public.engineer_productivity_review_notes_r1688(score_id);
CREATE INDEX IF NOT EXISTS idx_eprn_r1688_action ON public.engineer_productivity_review_notes_r1688(action);

ALTER TABLE public.engineer_productivity_scores_r1688 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_productivity_review_notes_r1688 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eps_r1688 ON public.engineer_productivity_scores_r1688;
CREATE POLICY founder_all_eps_r1688 ON public.engineer_productivity_scores_r1688
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_eprn_r1688 ON public.engineer_productivity_review_notes_r1688;
CREATE POLICY founder_all_eprn_r1688 ON public.engineer_productivity_review_notes_r1688
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_scores
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_scores_r1688(
  p_window text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  score_window text,
  window_start date,
  jobs_completed int,
  avg_rating numeric,
  hours_logged numeric,
  km_traveled int,
  productivity_score numeric,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.engineer_user_id, p.email::text, s.score_window, s.window_start,
         s.jobs_completed, s.avg_rating, s.hours_logged, s.km_traveled,
         s.productivity_score, s.recorded_at
  FROM public.engineer_productivity_scores_r1688 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE (p_window IS NULL OR s.score_window = p_window)
  ORDER BY s.productivity_score DESC, s.recorded_at DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- RPC 2: compute_window
-- ============================================================
CREATE OR REPLACE FUNCTION public.compute_window_r1688(
  p_engineer_user_id uuid,
  p_window text,
  p_window_start date
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_end date;
  v_jobs int;
  v_rating numeric;
  v_hours numeric;
  v_km int;
  v_score numeric;
  v_id uuid;
  v_engineer_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_window_end := CASE p_window
    WHEN 'week' THEN p_window_start + INTERVAL '7 days'
    WHEN 'month' THEN p_window_start + INTERVAL '1 month'
    WHEN 'quarter' THEN p_window_start + INTERVAL '3 months'
    ELSE p_window_start + INTERVAL '1 month'
  END;

  SELECT e.id INTO v_engineer_id FROM public.engineers e WHERE e.user_id = p_engineer_user_id LIMIT 1;

  SELECT (COUNT(*))::int,
         COALESCE(AVG(hospital_rating), 0)::numeric
    INTO v_jobs, v_rating
    FROM public.repair_jobs
    WHERE engineer_id = v_engineer_id
      AND status = 'completed'
      AND completed_at >= p_window_start
      AND completed_at < v_window_end;

  v_hours := v_jobs * 2.0;
  v_km := v_jobs * 15;
  v_score := (v_jobs * 10.0) + (v_rating * 5.0) - (v_km * 0.05);

  INSERT INTO public.engineer_productivity_scores_r1688(
    engineer_user_id, score_window, window_start, jobs_completed,
    avg_rating, hours_logged, km_traveled, productivity_score
  ) VALUES (
    p_engineer_user_id, p_window, p_window_start, v_jobs,
    v_rating, v_hours, v_km, v_score
  )
  ON CONFLICT (engineer_user_id, score_window, window_start) DO UPDATE
    SET jobs_completed = EXCLUDED.jobs_completed,
        avg_rating = EXCLUDED.avg_rating,
        hours_logged = EXCLUDED.hours_logged,
        km_traveled = EXCLUDED.km_traveled,
        productivity_score = EXCLUDED.productivity_score,
        recorded_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'compute_window_r1688',
          jsonb_build_object('score_id', v_id, 'engineer_user_id', p_engineer_user_id,
                             'window', p_window, 'score', v_score));

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_notes
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_notes_r1688(
  p_score_id uuid DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  score_id uuid,
  founder_note_md text,
  action text,
  decided_at timestamptz,
  engineer_user_id uuid,
  productivity_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.score_id, n.founder_note_md, n.action, n.decided_at,
         s.engineer_user_id, s.productivity_score
  FROM public.engineer_productivity_review_notes_r1688 n
  JOIN public.engineer_productivity_scores_r1688 s ON s.id = n.score_id
  WHERE (p_score_id IS NULL OR n.score_id = p_score_id)
  ORDER BY n.decided_at DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- RPC 4: record_note
-- ============================================================
CREATE OR REPLACE FUNCTION public.record_note_r1688(
  p_score_id uuid,
  p_founder_note_md text,
  p_action text
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

  INSERT INTO public.engineer_productivity_review_notes_r1688(score_id, founder_note_md, action)
  VALUES (p_score_id, p_founder_note_md, p_action)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_note_r1688',
          jsonb_build_object('note_id', v_id, 'score_id', p_score_id, 'action', p_action));

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: top_performers
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_performers_r1688(
  p_window text DEFAULT 'month',
  p_limit int DEFAULT 10
)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  productivity_score numeric,
  jobs_completed int,
  avg_rating numeric,
  window_start date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_user_id, p.email::text, s.productivity_score,
         s.jobs_completed, s.avg_rating, s.window_start
  FROM public.engineer_productivity_scores_r1688 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.score_window = p_window
  ORDER BY s.productivity_score DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- RPC 6: bottom_performers
-- ============================================================
CREATE OR REPLACE FUNCTION public.bottom_performers_r1688(
  p_window text DEFAULT 'month',
  p_limit int DEFAULT 10
)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  productivity_score numeric,
  jobs_completed int,
  avg_rating numeric,
  window_start date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_user_id, p.email::text, s.productivity_score,
         s.jobs_completed, s.avg_rating, s.window_start
  FROM public.engineer_productivity_scores_r1688 s
  LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
  WHERE s.score_window = p_window
  ORDER BY s.productivity_score ASC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- RPC 7: score_trend_per_engineer
-- ============================================================
CREATE OR REPLACE FUNCTION public.score_trend_per_engineer_r1688(
  p_engineer_user_id uuid,
  p_window text DEFAULT 'month',
  p_limit int DEFAULT 12
)
RETURNS TABLE (
  window_start date,
  productivity_score numeric,
  jobs_completed int,
  avg_rating numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.window_start, s.productivity_score, s.jobs_completed, s.avg_rating
  FROM public.engineer_productivity_scores_r1688 s
  WHERE s.engineer_user_id = p_engineer_user_id
    AND s.score_window = p_window
  ORDER BY s.window_start DESC
  LIMIT p_limit;
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_scores_r1688(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_scores_r1688(text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.compute_window_r1688(uuid, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compute_window_r1688(uuid, text, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_notes_r1688(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_notes_r1688(uuid, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.record_note_r1688(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_note_r1688(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.top_performers_r1688(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_performers_r1688(text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.bottom_performers_r1688(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bottom_performers_r1688(text, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.score_trend_per_engineer_r1688(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.score_trend_per_engineer_r1688(uuid, text, int) TO authenticated;

COMMIT;