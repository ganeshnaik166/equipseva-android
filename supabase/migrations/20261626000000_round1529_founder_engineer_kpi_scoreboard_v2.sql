BEGIN;

-- =====================================================================
-- Round r1529 — Founder Engineer KPI Scoreboard v2
-- Per-engineer composite KPI score (NPS + acceptance + completion + tier
-- + retention); rank + percentile; founder review for bottom 10%.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table: founder_engineer_kpi_snapshots_v2
-- Daily snapshot of composite KPI per engineer.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_engineer_kpi_snapshots_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date   date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  engineer_id     uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  -- Component scores (each 0..100)
  nps_score          numeric(6,2) NOT NULL DEFAULT 0,
  acceptance_score   numeric(6,2) NOT NULL DEFAULT 0,
  completion_score   numeric(6,2) NOT NULL DEFAULT 0,
  tier_score         numeric(6,2) NOT NULL DEFAULT 0,
  retention_score    numeric(6,2) NOT NULL DEFAULT 0,
  -- Composite 0..100 (weighted)
  composite_score    numeric(6,2) NOT NULL DEFAULT 0,
  -- Rank + percentile across the snapshot cohort
  rank_overall       integer,
  percentile         numeric(6,2),
  cohort_size        integer NOT NULL DEFAULT 0,
  -- Underlying raw counts (audit trail)
  raw_jobs_total     integer NOT NULL DEFAULT 0,
  raw_jobs_completed integer NOT NULL DEFAULT 0,
  raw_jobs_offered   integer NOT NULL DEFAULT 0,
  raw_jobs_accepted  integer NOT NULL DEFAULT 0,
  raw_avg_rating     numeric(4,2),
  notes              text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (snapshot_date, engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_fekpi_v2_date
  ON public.founder_engineer_kpi_snapshots_v2 (snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_fekpi_v2_engineer
  ON public.founder_engineer_kpi_snapshots_v2 (engineer_id, snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_fekpi_v2_composite
  ON public.founder_engineer_kpi_snapshots_v2 (snapshot_date DESC, composite_score DESC);

ALTER TABLE public.founder_engineer_kpi_snapshots_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fekpi_v2_founder_all ON public.founder_engineer_kpi_snapshots_v2;
CREATE POLICY p_fekpi_v2_founder_all
  ON public.founder_engineer_kpi_snapshots_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_engineer_kpi_snapshots_v2 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.founder_engineer_kpi_snapshots_v2 TO authenticated;

-- ---------------------------------------------------------------------
-- Table: founder_engineer_kpi_reviews_v2
-- Founder review notes for bottom-10% engineers.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_engineer_kpi_reviews_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id     uuid REFERENCES public.founder_engineer_kpi_snapshots_v2(id) ON DELETE SET NULL,
  engineer_id     uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  review_date     date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  review_status   text NOT NULL DEFAULT 'open'
                    CHECK (review_status IN ('open','in_progress','coaching','suspended','cleared')),
  composite_at_review numeric(6,2),
  percentile_at_review numeric(6,2),
  action_taken    text,
  founder_notes   text,
  reviewed_by     uuid,
  reviewed_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fekpi_rev_v2_engineer
  ON public.founder_engineer_kpi_reviews_v2 (engineer_id, review_date DESC);
CREATE INDEX IF NOT EXISTS idx_fekpi_rev_v2_status
  ON public.founder_engineer_kpi_reviews_v2 (review_status, review_date DESC);

ALTER TABLE public.founder_engineer_kpi_reviews_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fekpi_rev_v2_founder_all ON public.founder_engineer_kpi_reviews_v2;
CREATE POLICY p_fekpi_rev_v2_founder_all
  ON public.founder_engineer_kpi_reviews_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.founder_engineer_kpi_reviews_v2 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.founder_engineer_kpi_reviews_v2 TO authenticated;

-- ---------------------------------------------------------------------
-- Helpers: log_founder_*
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_founder_engineer_kpi_snapshot_v2(
  p_snapshot_id uuid,
  p_engineer_id uuid,
  p_composite numeric,
  p_rank integer,
  p_percentile numeric
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'engineer_kpi_v2.snapshot',
    jsonb_build_object(
      'snapshot_id', p_snapshot_id,
      'engineer_id', p_engineer_id,
      'composite', p_composite,
      'rank', p_rank,
      'percentile', p_percentile
    )
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_kpi_snapshot_v2(uuid, uuid, numeric, integer, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_kpi_snapshot_v2(uuid, uuid, numeric, integer, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_engineer_kpi_review_open_v2(
  p_review_id uuid,
  p_engineer_id uuid,
  p_composite numeric
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'engineer_kpi_v2.review_open',
    jsonb_build_object(
      'review_id', p_review_id,
      'engineer_id', p_engineer_id,
      'composite', p_composite
    )
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_kpi_review_open_v2(uuid, uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_kpi_review_open_v2(uuid, uuid, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_engineer_kpi_review_resolve_v2(
  p_review_id uuid,
  p_status text,
  p_action text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'engineer_kpi_v2.review_resolve',
    jsonb_build_object(
      'review_id', p_review_id,
      'status', p_status,
      'action', p_action
    )
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_kpi_review_resolve_v2(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_kpi_review_resolve_v2(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_engineer_kpi_rebuild_v2(
  p_cohort_size integer,
  p_avg_composite numeric
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'engineer_kpi_v2.rebuild',
    jsonb_build_object(
      'cohort_size', p_cohort_size,
      'avg_composite', p_avg_composite
    )
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_kpi_rebuild_v2(integer, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_kpi_rebuild_v2(integer, numeric) TO authenticated;

-- ---------------------------------------------------------------------
-- RPCs (read = STABLE, write = VOLATILE)
-- ---------------------------------------------------------------------

-- 1) Latest snapshot summary (cohort size, avg, min, max)
CREATE OR REPLACE FUNCTION public.founder_engineer_kpi_v2_summary()
RETURNS TABLE (
  snapshot_date date,
  cohort_size integer,
  avg_composite numeric,
  min_composite numeric,
  max_composite numeric,
  median_composite numeric,
  bottom_decile_threshold numeric,
  top_decile_threshold numeric,
  reviews_open integer,
  reviews_total integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT MAX(s.snapshot_date) AS d
    FROM public.founder_engineer_kpi_snapshots_v2 s
  ),
  rows AS (
    SELECT s.* FROM public.founder_engineer_kpi_snapshots_v2 s, latest l
    WHERE s.snapshot_date = l.d
  )
  SELECT
    (SELECT d FROM latest)::date,
    COALESCE((SELECT COUNT(*)::integer FROM rows), 0),
    COALESCE((SELECT AVG(composite_score) FROM rows), 0)::numeric,
    COALESCE((SELECT MIN(composite_score) FROM rows), 0)::numeric,
    COALESCE((SELECT MAX(composite_score) FROM rows), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY composite_score) FROM rows), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.10) WITHIN GROUP (ORDER BY composite_score) FROM rows), 0)::numeric,
    COALESCE((SELECT percentile_cont(0.90) WITHIN GROUP (ORDER BY composite_score) FROM rows), 0)::numeric,
    COALESCE((SELECT COUNT(*)::integer FROM public.founder_engineer_kpi_reviews_v2 WHERE review_status IN ('open','in_progress')), 0),
    COALESCE((SELECT COUNT(*)::integer FROM public.founder_engineer_kpi_reviews_v2), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_summary() TO authenticated;

-- 2) Top 25 engineers by composite
CREATE OR REPLACE FUNCTION public.founder_engineer_kpi_v2_leaderboard(p_limit integer DEFAULT 25)
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_user_id uuid,
  composite_score numeric,
  rank_overall integer,
  percentile numeric,
  nps_score numeric,
  acceptance_score numeric,
  completion_score numeric,
  tier_score numeric,
  retention_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT MAX(s.snapshot_date) AS d FROM public.founder_engineer_kpi_snapshots_v2 s
  )
  SELECT s.id, s.engineer_id, s.engineer_user_id, s.composite_score,
         s.rank_overall, s.percentile,
         s.nps_score, s.acceptance_score, s.completion_score, s.tier_score, s.retention_score
  FROM public.founder_engineer_kpi_snapshots_v2 s, latest l
  WHERE s.snapshot_date = l.d
  ORDER BY s.composite_score DESC NULLS LAST
  LIMIT GREATEST(COALESCE(p_limit, 25), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_leaderboard(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_leaderboard(integer) TO authenticated;

-- 3) Bottom decile (review candidates)
CREATE OR REPLACE FUNCTION public.founder_engineer_kpi_v2_bottom_decile()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_user_id uuid,
  composite_score numeric,
  rank_overall integer,
  percentile numeric,
  raw_jobs_total integer,
  raw_avg_rating numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT MAX(s.snapshot_date) AS d FROM public.founder_engineer_kpi_snapshots_v2 s
  )
  SELECT s.id, s.engineer_id, s.engineer_user_id, s.composite_score,
         s.rank_overall, s.percentile, s.raw_jobs_total, s.raw_avg_rating
  FROM public.founder_engineer_kpi_snapshots_v2 s, latest l
  WHERE s.snapshot_date = l.d
    AND s.percentile IS NOT NULL
    AND s.percentile <= 10.0
  ORDER BY s.composite_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_bottom_decile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_bottom_decile() TO authenticated;

-- 4) Tier distribution across latest snapshot
CREATE OR REPLACE FUNCTION public.founder_engineer_kpi_v2_tier_distribution()
RETURNS TABLE (
  tier text,
  engineer_count integer,
  avg_composite numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT MAX(s.snapshot_date) AS d FROM public.founder_engineer_kpi_snapshots_v2 s
  )
  SELECT COALESCE(e.cached_highest_tier, 'none')::text AS tier,
         COUNT(*)::integer,
         AVG(s.composite_score)::numeric
  FROM public.founder_engineer_kpi_snapshots_v2 s
  JOIN public.engineers e ON e.id = s.engineer_id
  JOIN latest l ON s.snapshot_date = l.d
  GROUP BY COALESCE(e.cached_highest_tier, 'none')
  ORDER BY AVG(s.composite_score) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_tier_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_tier_distribution() TO authenticated;

-- 5) Trend — average composite by snapshot date (last 30 dates)
CREATE OR REPLACE FUNCTION public.founder_engineer_kpi_v2_trend()
RETURNS TABLE (
  snapshot_date date,
  cohort_size integer,
  avg_composite numeric,
  median_composite numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT s.snapshot_date,
         COUNT(*)::integer,
         AVG(s.composite_score)::numeric,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY s.composite_score)::numeric
  FROM public.founder_engineer_kpi_snapshots_v2 s
  GROUP BY s.snapshot_date
  ORDER BY s.snapshot_date DESC
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_trend() TO authenticated;

-- 6) Open reviews list
CREATE OR REPLACE FUNCTION public.founder_engineer_kpi_v2_open_reviews()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  review_date date,
  review_status text,
  composite_at_review numeric,
  percentile_at_review numeric,
  action_taken text,
  founder_notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_id, r.review_date, r.review_status,
         r.composite_at_review, r.percentile_at_review,
         r.action_taken, r.founder_notes, r.created_at
  FROM public.founder_engineer_kpi_reviews_v2 r
  WHERE r.review_status IN ('open','in_progress','coaching')
  ORDER BY r.review_date DESC, r.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_open_reviews() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_open_reviews() TO authenticated;

-- 7) Component breakdown averages (NPS, acceptance, completion, tier, retention)
CREATE OR REPLACE FUNCTION public.founder_engineer_kpi_v2_component_breakdown()
RETURNS TABLE (
  component text,
  avg_score numeric,
  min_score numeric,
  max_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT MAX(s.snapshot_date) AS d FROM public.founder_engineer_kpi_snapshots_v2 s
  ),
  rows AS (
    SELECT s.* FROM public.founder_engineer_kpi_snapshots_v2 s, latest l
    WHERE s.snapshot_date = l.d
  )
  SELECT 'nps'::text, COALESCE(AVG(nps_score),0)::numeric, COALESCE(MIN(nps_score),0)::numeric, COALESCE(MAX(nps_score),0)::numeric FROM rows
  UNION ALL
  SELECT 'acceptance', COALESCE(AVG(acceptance_score),0), COALESCE(MIN(acceptance_score),0), COALESCE(MAX(acceptance_score),0) FROM rows
  UNION ALL
  SELECT 'completion', COALESCE(AVG(completion_score),0), COALESCE(MIN(completion_score),0), COALESCE(MAX(completion_score),0) FROM rows
  UNION ALL
  SELECT 'tier', COALESCE(AVG(tier_score),0), COALESCE(MIN(tier_score),0), COALESCE(MAX(tier_score),0) FROM rows
  UNION ALL
  SELECT 'retention', COALESCE(AVG(retention_score),0), COALESCE(MIN(retention_score),0), COALESCE(MAX(retention_score),0) FROM rows;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_component_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_kpi_v2_component_breakdown() TO authenticated;

COMMIT;