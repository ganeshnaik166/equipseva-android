BEGIN;
-- Round 1385: Founder Weekly Review Template — written weekly review template + log
-- Provides structured weekly self-review (wins/misses/blockers/priorities/ratings) for the founder
-- to journal each week, finalize, and share. Surfaces KPIs and 12-week trend.



-- ============================================================================
-- TABLE: founder_weekly_reviews
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_weekly_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_label text NOT NULL UNIQUE,
  week_start_date date NOT NULL,
  week_end_date date NOT NULL,
  status text DEFAULT 'draft' CHECK (status IN ('draft','final','shared')),
  top_3_wins text,
  top_3_misses text,
  biggest_blocker text,
  next_week_priority_1 text,
  next_week_priority_2 text,
  next_week_priority_3 text,
  mood_self_rating int CHECK (mood_self_rating >= 1 AND mood_self_rating <= 10),
  confidence_self_rating int CHECK (confidence_self_rating >= 1 AND confidence_self_rating <= 10),
  energy_self_rating int CHECK (energy_self_rating >= 1 AND energy_self_rating <= 10),
  one_decision_committed text,
  written_by uuid REFERENCES auth.users(id),
  written_at timestamptz,
  shared_at timestamptz,
  notes text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_weekly_reviews_week_start
  ON public.founder_weekly_reviews (week_start_date DESC);

CREATE INDEX IF NOT EXISTS idx_founder_weekly_reviews_status
  ON public.founder_weekly_reviews (status);

ALTER TABLE public.founder_weekly_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_weekly_reviews_founder_all ON public.founder_weekly_reviews;
CREATE POLICY founder_weekly_reviews_founder_all
  ON public.founder_weekly_reviews
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: founder_weekly_review_template_summary — 14 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_weekly_review_template_summary();

CREATE OR REPLACE FUNCTION public.founder_weekly_review_template_summary()
RETURNS TABLE (
  total_reviews_written bigint,
  reviews_last_4w bigint,
  reviews_last_12w bigint,
  days_since_last_review int,
  latest_week_label text,
  latest_mood int,
  latest_confidence int,
  latest_energy int,
  avg_mood_last_4w numeric,
  avg_confidence_last_4w numeric,
  mood_trend_4w text,
  final_status_count bigint,
  shared_status_count bigint,
  generated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_recent_avg numeric;
  v_older_avg numeric;
  v_trend text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT AVG(mood_self_rating)::numeric
    INTO v_recent_avg
  FROM public.founder_weekly_reviews
  WHERE week_start_date >= (CURRENT_DATE - INTERVAL '2 weeks')::date;

  SELECT AVG(mood_self_rating)::numeric
    INTO v_older_avg
  FROM public.founder_weekly_reviews
  WHERE week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks')::date
    AND week_start_date <  (CURRENT_DATE - INTERVAL '2 weeks')::date;

  IF v_recent_avg IS NULL OR v_older_avg IS NULL THEN
    v_trend := 'stable';
  ELSIF v_recent_avg > v_older_avg + 0.5 THEN
    v_trend := 'improving';
  ELSIF v_recent_avg < v_older_avg - 0.5 THEN
    v_trend := 'declining';
  ELSE
    v_trend := 'stable';
  END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT week_label, mood_self_rating, confidence_self_rating, energy_self_rating, week_start_date
    FROM public.founder_weekly_reviews
    ORDER BY week_start_date DESC
    LIMIT 1
  )
  SELECT
    (SELECT COUNT(*) FROM public.founder_weekly_reviews)::bigint AS total_reviews_written,
    (SELECT COUNT(*) FROM public.founder_weekly_reviews
       WHERE week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks')::date)::bigint AS reviews_last_4w,
    (SELECT COUNT(*) FROM public.founder_weekly_reviews
       WHERE week_start_date >= (CURRENT_DATE - INTERVAL '12 weeks')::date)::bigint AS reviews_last_12w,
    COALESCE((SELECT (CURRENT_DATE - MAX(week_end_date))::int FROM public.founder_weekly_reviews), 9999) AS days_since_last_review,
    (SELECT week_label FROM latest) AS latest_week_label,
    (SELECT mood_self_rating FROM latest) AS latest_mood,
    (SELECT confidence_self_rating FROM latest) AS latest_confidence,
    (SELECT energy_self_rating FROM latest) AS latest_energy,
    COALESCE((SELECT AVG(mood_self_rating)::numeric FROM public.founder_weekly_reviews
       WHERE week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks')::date), 0)::numeric AS avg_mood_last_4w,
    COALESCE((SELECT AVG(confidence_self_rating)::numeric FROM public.founder_weekly_reviews
       WHERE week_start_date >= (CURRENT_DATE - INTERVAL '4 weeks')::date), 0)::numeric AS avg_confidence_last_4w,
    v_trend AS mood_trend_4w,
    (SELECT COUNT(*) FROM public.founder_weekly_reviews WHERE status = 'final')::bigint AS final_status_count,
    (SELECT COUNT(*) FROM public.founder_weekly_reviews WHERE status = 'shared')::bigint AS shared_status_count,
    now() AS generated_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_weekly_review_template_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_weekly_review_template_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_weekly_reviews_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_weekly_reviews_recent(int);

CREATE OR REPLACE FUNCTION public.founder_weekly_reviews_recent(p_limit int DEFAULT 12)
RETURNS TABLE (
  id uuid,
  week_label text,
  week_start_date date,
  week_end_date date,
  status text,
  top_3_wins text,
  top_3_misses text,
  biggest_blocker text,
  next_week_priority_1 text,
  next_week_priority_2 text,
  next_week_priority_3 text,
  mood_self_rating int,
  confidence_self_rating int,
  energy_self_rating int,
  one_decision_committed text,
  written_at timestamptz,
  shared_at timestamptz,
  notes text
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
  SELECT
    r.id, r.week_label, r.week_start_date, r.week_end_date, r.status,
    r.top_3_wins, r.top_3_misses, r.biggest_blocker,
    r.next_week_priority_1, r.next_week_priority_2, r.next_week_priority_3,
    r.mood_self_rating, r.confidence_self_rating, r.energy_self_rating,
    r.one_decision_committed, r.written_at, r.shared_at, r.notes
  FROM public.founder_weekly_reviews r
  ORDER BY r.week_start_date DESC
  LIMIT GREATEST(1, LEAST(p_limit, 52));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_weekly_reviews_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_weekly_reviews_recent(int) TO authenticated;

-- ============================================================================
-- RPC: log_founder_weekly_review_record — upsert a draft
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_weekly_review_record(text, date, date, text, text, text, text, text, text, int, int, int, text, text);

CREATE OR REPLACE FUNCTION public.log_founder_weekly_review_record(
  p_week_label text,
  p_week_start_date date,
  p_week_end_date date,
  p_top_3_wins text,
  p_top_3_misses text,
  p_biggest_blocker text,
  p_next_week_priority_1 text,
  p_next_week_priority_2 text,
  p_next_week_priority_3 text,
  p_mood_self_rating int,
  p_confidence_self_rating int,
  p_energy_self_rating int,
  p_one_decision_committed text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_uid uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  v_uid := auth.uid();

  INSERT INTO public.founder_weekly_reviews (
    week_label, week_start_date, week_end_date, status,
    top_3_wins, top_3_misses, biggest_blocker,
    next_week_priority_1, next_week_priority_2, next_week_priority_3,
    mood_self_rating, confidence_self_rating, energy_self_rating,
    one_decision_committed, notes, written_by, written_at
  ) VALUES (
    p_week_label, p_week_start_date, p_week_end_date, 'draft',
    p_top_3_wins, p_top_3_misses, p_biggest_blocker,
    p_next_week_priority_1, p_next_week_priority_2, p_next_week_priority_3,
    p_mood_self_rating, p_confidence_self_rating, p_energy_self_rating,
    p_one_decision_committed, p_notes, v_uid, now()
  )
  ON CONFLICT (week_label) DO UPDATE SET
    week_start_date = EXCLUDED.week_start_date,
    week_end_date = EXCLUDED.week_end_date,
    top_3_wins = EXCLUDED.top_3_wins,
    top_3_misses = EXCLUDED.top_3_misses,
    biggest_blocker = EXCLUDED.biggest_blocker,
    next_week_priority_1 = EXCLUDED.next_week_priority_1,
    next_week_priority_2 = EXCLUDED.next_week_priority_2,
    next_week_priority_3 = EXCLUDED.next_week_priority_3,
    mood_self_rating = EXCLUDED.mood_self_rating,
    confidence_self_rating = EXCLUDED.confidence_self_rating,
    energy_self_rating = EXCLUDED.energy_self_rating,
    one_decision_committed = EXCLUDED.one_decision_committed,
    notes = EXCLUDED.notes,
    written_by = EXCLUDED.written_by,
    written_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_weekly_review_record(text, date, date, text, text, text, text, text, text, int, int, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_weekly_review_record(text, date, date, text, text, text, text, text, text, int, int, int, text, text) TO authenticated;

-- ============================================================================
-- RPC: log_founder_weekly_review_finalize
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_weekly_review_finalize(uuid);

CREATE OR REPLACE FUNCTION public.log_founder_weekly_review_finalize(p_id uuid)
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

  UPDATE public.founder_weekly_reviews
     SET status = 'final'
   WHERE id = p_id
     AND status IN ('draft','final')
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'review not found or already shared' USING ERRCODE = 'P0002';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_weekly_review_finalize(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_weekly_review_finalize(uuid) TO authenticated;

-- ============================================================================
-- RPC: log_founder_weekly_review_share
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_weekly_review_share(uuid);

CREATE OR REPLACE FUNCTION public.log_founder_weekly_review_share(p_id uuid)
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

  UPDATE public.founder_weekly_reviews
     SET status = 'shared',
         shared_at = now()
   WHERE id = p_id
     AND status IN ('final','shared')
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'review not finalized yet' USING ERRCODE = 'P0002';
  END IF;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_weekly_review_share(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_weekly_review_share(uuid) TO authenticated;

COMMIT;