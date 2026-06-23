BEGIN;

-- =========================================================================
-- r2409: Founder weekly first-principles thinking log
-- Tracks questions founder asked from first principles each week + insights
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_first_principles_weeks_r2409 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_start date NOT NULL,
  week_end date NOT NULL,
  theme text NOT NULL,
  status text NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress','reviewed','archived')),
  questions_logged int NOT NULL DEFAULT 0,
  insights_generated int NOT NULL DEFAULT 0,
  assumptions_broken int NOT NULL DEFAULT 0,
  decisions_changed int NOT NULL DEFAULT 0,
  depth_score int NOT NULL DEFAULT 0 CHECK (depth_score BETWEEN 0 AND 10),
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (founder_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_fp_weeks_r2409_start
  ON public.founder_first_principles_weeks_r2409 (week_start DESC);

CREATE TABLE IF NOT EXISTS public.founder_first_principles_entries_r2409 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_id uuid NOT NULL REFERENCES public.founder_first_principles_weeks_r2409(id) ON DELETE CASCADE,
  logged_at timestamptz NOT NULL DEFAULT now(),
  question text NOT NULL,
  domain text NOT NULL
    CHECK (domain IN ('product','market','pricing','ops','team','tech','finance','strategy')),
  assumption_challenged text,
  reasoning text,
  insight text,
  led_to_decision boolean NOT NULL DEFAULT false,
  decision_summary text,
  importance int NOT NULL DEFAULT 3 CHECK (importance BETWEEN 1 AND 5),
  follow_up_required boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_fp_entries_r2409_week
  ON public.founder_first_principles_entries_r2409 (week_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_fp_entries_r2409_domain
  ON public.founder_first_principles_entries_r2409 (domain);

ALTER TABLE public.founder_first_principles_weeks_r2409 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_first_principles_entries_r2409 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_first_principles_weeks_r2409;
CREATE POLICY founder_all ON public.founder_first_principles_weeks_r2409
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.founder_first_principles_entries_r2409;
CREATE POLICY founder_all ON public.founder_first_principles_entries_r2409
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: weeks list (recent weeks with rollups)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_fp_weeks_list_r2409(p_limit int DEFAULT 26)
RETURNS TABLE (
  id uuid,
  week_start date,
  week_end date,
  theme text,
  status text,
  questions_logged int,
  insights_generated int,
  assumptions_broken int,
  decisions_changed int,
  depth_score int,
  conversion_rate numeric,
  reviewed_at timestamptz,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      w.id,
      w.week_start,
      w.week_end,
      w.theme,
      w.status,
      w.questions_logged,
      w.insights_generated,
      w.assumptions_broken,
      w.decisions_changed,
      w.depth_score,
      CASE WHEN w.questions_logged > 0
        THEN ROUND((w.insights_generated::numeric / w.questions_logged) * 100, 1)
        ELSE 0 END AS conversion_rate,
      w.reviewed_at,
      w.notes
    FROM public.founder_first_principles_weeks_r2409 w
    ORDER BY w.week_start DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_fp_weeks_list_r2409(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fp_weeks_list_r2409(int) TO authenticated;

-- =========================================================================
-- RPC 2: entries recent (top N entries by logged_at)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_fp_entries_recent_r2409(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  logged_at timestamptz,
  week_start date,
  theme text,
  question text,
  domain text,
  assumption_challenged text,
  insight text,
  led_to_decision boolean,
  importance int,
  follow_up_required boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.id,
      e.logged_at,
      w.week_start,
      w.theme,
      e.question,
      e.domain,
      e.assumption_challenged,
      e.insight,
      e.led_to_decision,
      e.importance,
      e.follow_up_required
    FROM public.founder_first_principles_entries_r2409 e
    JOIN public.founder_first_principles_weeks_r2409 w ON w.id = e.week_id
    ORDER BY e.logged_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_fp_entries_recent_r2409(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fp_entries_recent_r2409(int) TO authenticated;

-- =========================================================================
-- RPC 3: domain rollup (which domains see most thinking)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_fp_domain_rollup_r2409(p_weeks int DEFAULT 12)
RETURNS TABLE (
  domain text,
  question_count bigint,
  insight_count bigint,
  decision_count bigint,
  avg_importance numeric,
  share_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*) INTO v_total
  FROM public.founder_first_principles_entries_r2409 e
  JOIN public.founder_first_principles_weeks_r2409 w ON w.id = e.week_id
  WHERE w.week_start >= CURRENT_DATE - (GREATEST(p_weeks,1) * 7);

  RETURN QUERY
    SELECT
      e.domain,
      COUNT(*)::bigint AS question_count,
      COUNT(*) FILTER (WHERE e.insight IS NOT NULL AND length(e.insight) > 0)::bigint AS insight_count,
      COUNT(*) FILTER (WHERE e.led_to_decision)::bigint AS decision_count,
      ROUND(AVG(e.importance)::numeric, 2) AS avg_importance,
      CASE WHEN v_total > 0
        THEN ROUND((COUNT(*)::numeric / v_total) * 100, 1)
        ELSE 0 END AS share_pct
    FROM public.founder_first_principles_entries_r2409 e
    JOIN public.founder_first_principles_weeks_r2409 w ON w.id = e.week_id
    WHERE w.week_start >= CURRENT_DATE - (GREATEST(p_weeks,1) * 7)
    GROUP BY e.domain
    ORDER BY question_count DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_fp_domain_rollup_r2409(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fp_domain_rollup_r2409(int) TO authenticated;

-- =========================================================================
-- RPC 4: top insights (importance >= 4 with insight text)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_fp_top_insights_r2409(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  logged_at timestamptz,
  week_start date,
  domain text,
  question text,
  insight text,
  decision_summary text,
  importance int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.id,
      e.logged_at,
      w.week_start,
      e.domain,
      e.question,
      e.insight,
      e.decision_summary,
      e.importance
    FROM public.founder_first_principles_entries_r2409 e
    JOIN public.founder_first_principles_weeks_r2409 w ON w.id = e.week_id
    WHERE e.importance >= 4
      AND e.insight IS NOT NULL
      AND length(e.insight) > 0
    ORDER BY e.importance DESC, e.logged_at DESC
    LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_fp_top_insights_r2409(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fp_top_insights_r2409(int) TO authenticated;

-- =========================================================================
-- RPC 5: follow-ups outstanding
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_fp_follow_ups_r2409()
RETURNS TABLE (
  id uuid,
  logged_at timestamptz,
  week_start date,
  domain text,
  question text,
  assumption_challenged text,
  age_days int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.id,
      e.logged_at,
      w.week_start,
      e.domain,
      e.question,
      e.assumption_challenged,
      GREATEST(0, (CURRENT_DATE - e.logged_at::date))::int AS age_days
    FROM public.founder_first_principles_entries_r2409 e
    JOIN public.founder_first_principles_weeks_r2409 w ON w.id = e.week_id
    WHERE e.follow_up_required = true
    ORDER BY e.logged_at ASC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_fp_follow_ups_r2409() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fp_follow_ups_r2409() TO authenticated;

-- =========================================================================
-- RPC 6: depth trend (depth_score moving line over weeks)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_fp_depth_trend_r2409(p_weeks int DEFAULT 12)
RETURNS TABLE (
  week_start date,
  theme text,
  questions_logged int,
  insights_generated int,
  depth_score int,
  rolling_avg_depth numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      w.week_start,
      w.theme,
      w.questions_logged,
      w.insights_generated,
      w.depth_score,
      ROUND(AVG(w.depth_score) OVER (
        ORDER BY w.week_start
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
      )::numeric, 2) AS rolling_avg_depth
    FROM public.founder_first_principles_weeks_r2409 w
    WHERE w.week_start >= CURRENT_DATE - (GREATEST(p_weeks,1) * 7)
    ORDER BY w.week_start DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_fp_depth_trend_r2409(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fp_depth_trend_r2409(int) TO authenticated;

-- =========================================================================
-- RPC 7: summary snapshot (single-row KPIs)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.founder_fp_summary_r2409()
RETURNS TABLE (
  total_weeks bigint,
  total_questions bigint,
  total_insights bigint,
  total_decisions bigint,
  avg_depth numeric,
  open_follow_ups bigint,
  weeks_reviewed bigint,
  insight_conversion_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM public.founder_first_principles_weeks_r2409)::bigint,
      (SELECT COUNT(*) FROM public.founder_first_principles_entries_r2409)::bigint,
      (SELECT COUNT(*) FROM public.founder_first_principles_entries_r2409
        WHERE insight IS NOT NULL AND length(insight) > 0)::bigint,
      (SELECT COUNT(*) FROM public.founder_first_principles_entries_r2409
        WHERE led_to_decision)::bigint,
      (SELECT ROUND(COALESCE(AVG(depth_score),0)::numeric, 2)
        FROM public.founder_first_principles_weeks_r2409),
      (SELECT COUNT(*) FROM public.founder_first_principles_entries_r2409
        WHERE follow_up_required)::bigint,
      (SELECT COUNT(*) FROM public.founder_first_principles_weeks_r2409
        WHERE status = 'reviewed')::bigint,
      (SELECT CASE WHEN COUNT(*) > 0
        THEN ROUND(
          (COUNT(*) FILTER (WHERE insight IS NOT NULL AND length(insight) > 0)::numeric
            / COUNT(*)) * 100, 1)
        ELSE 0 END
        FROM public.founder_first_principles_entries_r2409);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_fp_summary_r2409() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_fp_summary_r2409() TO authenticated;

COMMIT;
