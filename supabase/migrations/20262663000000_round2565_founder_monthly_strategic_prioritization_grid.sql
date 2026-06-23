-- Round 2565: Founder monthly strategic prioritization grid
-- Tables: founder_priority_grid_r2565, grid_decision_review_r2565
-- 7 RPCs for grid analytics, ICE scoring, kill pipeline, leverage

BEGIN;

-- ============================================================
-- TABLE 1: founder_priority_grid_r2565
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_priority_grid_r2565 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  priority_title text NOT NULL,
  ice_score int NOT NULL CHECK (ice_score >= 0 AND ice_score <= 1000),
  effort_hours int NOT NULL CHECK (effort_hours >= 0),
  leverage_score int NOT NULL CHECK (leverage_score >= 0 AND leverage_score <= 100),
  kind text NOT NULL CHECK (kind IN ('kill','ship','delegate','explore')),
  decision_kind text NOT NULL CHECK (decision_kind IN ('act','pause','dropped')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_priority_grid_r2565 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.founder_priority_grid_r2565;
CREATE POLICY founder_all ON public.founder_priority_grid_r2565
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- TABLE 2: grid_decision_review_r2565
-- ============================================================
CREATE TABLE IF NOT EXISTS public.grid_decision_review_r2565 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grid_id uuid NOT NULL REFERENCES public.founder_priority_grid_r2565(id) ON DELETE CASCADE,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  review_kind text NOT NULL CHECK (review_kind IN ('go_no_go','refresh','dropped_review','promoted')),
  outcome_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.grid_decision_review_r2565 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.grid_decision_review_r2565;
CREATE POLICY founder_all ON public.grid_decision_review_r2565
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- SEED DATA
-- ============================================================
INSERT INTO public.founder_priority_grid_r2565
  (month_label, priority_title, ice_score, effort_hours, leverage_score, kind, decision_kind, owner_email, status, notes)
VALUES
  ('2026-06', 'Ship AMC payment-first flow', 850, 40, 90, 'ship', 'act', 'founder@equipseva.in', 'done', 'Highest ICE - revenue critical'),
  ('2026-06', 'Kill engineer onboarding email funnel', 320, 8, 30, 'kill', 'dropped', 'founder@equipseva.in', 'dropped', 'Low ROI vs WhatsApp'),
  ('2026-06', 'Delegate hospital chain demo deck', 600, 16, 60, 'delegate', 'act', 'cofounder@equipseva.in', 'in_progress', 'Cofounder owns'),
  ('2026-06', 'Explore data-bridge for legacy gear', 480, 24, 70, 'explore', 'pause', 'founder@equipseva.in', 'open', 'Needs partner conversation'),
  ('2026-05', 'Ship Cashfree payouts at scale', 920, 60, 95, 'ship', 'act', 'founder@equipseva.in', 'done', 'Top leverage move May');

WITH g AS (
  SELECT id FROM public.founder_priority_grid_r2565 WHERE priority_title = 'Ship AMC payment-first flow' LIMIT 1
)
INSERT INTO public.grid_decision_review_r2565 (grid_id, review_kind, outcome_md, owner_email, notes)
SELECT g.id, 'go_no_go', '**Go** - shipped in r477', 'founder@equipseva.in', 'Reviewed end of June' FROM g;

WITH g AS (
  SELECT id FROM public.founder_priority_grid_r2565 WHERE priority_title = 'Kill engineer onboarding email funnel' LIMIT 1
)
INSERT INTO public.grid_decision_review_r2565 (grid_id, review_kind, outcome_md, owner_email, notes)
SELECT g.id, 'dropped_review', '**Dropped** - WhatsApp wins on activation', 'founder@equipseva.in', 'No regrets' FROM g;

WITH g AS (
  SELECT id FROM public.founder_priority_grid_r2565 WHERE priority_title = 'Delegate hospital chain demo deck' LIMIT 1
)
INSERT INTO public.grid_decision_review_r2565 (grid_id, review_kind, outcome_md, owner_email, notes)
SELECT g.id, 'promoted', 'Cofounder taking lead on chain pitches', 'cofounder@equipseva.in', 'Frees founder cycles' FROM g;

-- ============================================================
-- RPC 1: list_grid_r2565
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_grid_r2565()
RETURNS TABLE (
  id uuid,
  month_label text,
  priority_title text,
  ice_score int,
  effort_hours int,
  leverage_score int,
  kind text,
  decision_kind text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.id, g.month_label, g.priority_title, g.ice_score, g.effort_hours,
           g.leverage_score, g.kind, g.decision_kind, g.owner_email, g.status,
           g.notes, g.created_at
    FROM public.founder_priority_grid_r2565 g
    ORDER BY g.month_label DESC, g.ice_score DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_grid_r2565() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_grid_r2565() TO authenticated;

-- ============================================================
-- RPC 2: list_decision_reviews_r2565
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_decision_reviews_r2565()
RETURNS TABLE (
  id uuid,
  grid_id uuid,
  priority_title text,
  month_label text,
  reviewed_at timestamptz,
  review_kind text,
  outcome_md text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.grid_id, g.priority_title, g.month_label,
           r.reviewed_at, r.review_kind, r.outcome_md, r.owner_email, r.notes
    FROM public.grid_decision_review_r2565 r
    JOIN public.founder_priority_grid_r2565 g ON g.id = r.grid_id
    ORDER BY r.reviewed_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_decision_reviews_r2565() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decision_reviews_r2565() TO authenticated;

-- ============================================================
-- RPC 3: top_ice_priorities_r2565
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_ice_priorities_r2565()
RETURNS TABLE (
  priority_title text,
  month_label text,
  ice_score int,
  effort_hours int,
  leverage_score int,
  kind text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.priority_title, g.month_label, g.ice_score, g.effort_hours,
           g.leverage_score, g.kind, g.status
    FROM public.founder_priority_grid_r2565 g
    ORDER BY g.ice_score DESC NULLS LAST
    LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_ice_priorities_r2565() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_ice_priorities_r2565() TO authenticated;

-- ============================================================
-- RPC 4: kind_distribution_r2565
-- ============================================================
CREATE OR REPLACE FUNCTION public.kind_distribution_r2565()
RETURNS TABLE (
  kind text,
  cnt bigint,
  avg_ice numeric,
  avg_leverage numeric,
  total_effort_hours bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.kind,
           COUNT(*)::bigint AS cnt,
           ROUND(AVG(g.ice_score)::numeric, 1) AS avg_ice,
           ROUND(AVG(g.leverage_score)::numeric, 1) AS avg_leverage,
           SUM(g.effort_hours)::bigint AS total_effort_hours
    FROM public.founder_priority_grid_r2565 g
    GROUP BY g.kind
    ORDER BY cnt DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_distribution_r2565() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_distribution_r2565() TO authenticated;

-- ============================================================
-- RPC 5: kill_pipeline_r2565
-- ============================================================
CREATE OR REPLACE FUNCTION public.kill_pipeline_r2565()
RETURNS TABLE (
  priority_title text,
  month_label text,
  ice_score int,
  effort_hours int,
  decision_kind text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.priority_title, g.month_label, g.ice_score, g.effort_hours,
           g.decision_kind, g.status, g.notes
    FROM public.founder_priority_grid_r2565 g
    WHERE g.kind = 'kill' OR g.status = 'dropped' OR g.decision_kind = 'dropped'
    ORDER BY g.month_label DESC NULLS LAST, g.ice_score DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kill_pipeline_r2565() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kill_pipeline_r2565() TO authenticated;

-- ============================================================
-- RPC 6: monthly_grid_trend_r2565
-- ============================================================
CREATE OR REPLACE FUNCTION public.monthly_grid_trend_r2565()
RETURNS TABLE (
  month_label text,
  total_items bigint,
  ship_count bigint,
  kill_count bigint,
  delegate_count bigint,
  explore_count bigint,
  avg_ice numeric,
  total_effort_hours bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT g.month_label,
           COUNT(*)::bigint AS total_items,
           COUNT(*) FILTER (WHERE g.kind = 'ship')::bigint AS ship_count,
           COUNT(*) FILTER (WHERE g.kind = 'kill')::bigint AS kill_count,
           COUNT(*) FILTER (WHERE g.kind = 'delegate')::bigint AS delegate_count,
           COUNT(*) FILTER (WHERE g.kind = 'explore')::bigint AS explore_count,
           ROUND(AVG(g.ice_score)::numeric, 1) AS avg_ice,
           SUM(g.effort_hours)::bigint AS total_effort_hours
    FROM public.founder_priority_grid_r2565 g
    GROUP BY g.month_label
    ORDER BY g.month_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_grid_trend_r2565() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_grid_trend_r2565() TO authenticated;

-- ============================================================
-- RPC 7: leverage_score_summary_r2565
-- ============================================================
CREATE OR REPLACE FUNCTION public.leverage_score_summary_r2565()
RETURNS TABLE (
  leverage_band text,
  cnt bigint,
  avg_ice numeric,
  avg_effort_hours numeric,
  ship_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN g.leverage_score >= 80 THEN 'high (80-100)'
        WHEN g.leverage_score >= 50 THEN 'mid (50-79)'
        ELSE 'low (0-49)'
      END AS leverage_band,
      COUNT(*)::bigint AS cnt,
      ROUND(AVG(g.ice_score)::numeric, 1) AS avg_ice,
      ROUND(AVG(g.effort_hours)::numeric, 1) AS avg_effort_hours,
      COUNT(*) FILTER (WHERE g.kind = 'ship')::bigint AS ship_count
    FROM public.founder_priority_grid_r2565 g
    GROUP BY leverage_band
    ORDER BY cnt DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.leverage_score_summary_r2565() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leverage_score_summary_r2565() TO authenticated;

