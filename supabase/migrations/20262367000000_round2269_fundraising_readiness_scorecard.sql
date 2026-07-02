BEGIN;

-- ============================================================
-- r2269: Founder fundraising-readiness scorecard
-- 10-dimension readiness assessment + gap-to-ready tracking
-- ============================================================

CREATE TABLE IF NOT EXISTS public.fundraising_readiness_dimensions_r2269 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dimension_code text NOT NULL UNIQUE,
  dimension_label text NOT NULL,
  category text NOT NULL CHECK (category IN ('metrics','deck','references','financials','pipeline')),
  weight_pct numeric(5,2) NOT NULL CHECK (weight_pct >= 0 AND weight_pct <= 100),
  target_score int NOT NULL DEFAULT 100 CHECK (target_score > 0),
  current_score int NOT NULL DEFAULT 0 CHECK (current_score >= 0),
  evidence_url text,
  blocker_notes text,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  last_reviewed_at timestamptz,
  next_review_due_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fundraising_readiness_gaps_r2269 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dimension_id uuid NOT NULL REFERENCES public.fundraising_readiness_dimensions_r2269(id) ON DELETE CASCADE,
  gap_title text NOT NULL,
  gap_severity text NOT NULL CHECK (gap_severity IN ('blocker','high','medium','low')),
  effort_days int NOT NULL DEFAULT 1 CHECK (effort_days > 0),
  assignee_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  target_close_date date,
  resolved_at timestamptz,
  resolution_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_frrd_category_r2269 ON public.fundraising_readiness_dimensions_r2269 (category);
CREATE INDEX IF NOT EXISTS idx_frrg_severity_r2269 ON public.fundraising_readiness_gaps_r2269 (gap_severity) WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_frrg_dim_r2269 ON public.fundraising_readiness_gaps_r2269 (dimension_id);

ALTER TABLE public.fundraising_readiness_dimensions_r2269 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fundraising_readiness_gaps_r2269 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.fundraising_readiness_dimensions_r2269;
CREATE POLICY founder_all ON public.fundraising_readiness_dimensions_r2269
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.fundraising_readiness_gaps_r2269;
CREATE POLICY founder_all ON public.fundraising_readiness_gaps_r2269
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- Seed 10 dimensions
-- ============================================================
INSERT INTO public.fundraising_readiness_dimensions_r2269
  (dimension_code, dimension_label, category, weight_pct, target_score, current_score, blocker_notes, last_reviewed_at, next_review_due_at)
VALUES
  ('mrr_growth', 'MRR growth trajectory', 'metrics', 15.00, 100, 72, 'Need 3 consecutive months >= 15% MoM', now() - interval '5 days', now() + interval '14 days'),
  ('unit_economics', 'Unit economics (CAC/LTV)', 'metrics', 12.00, 100, 65, 'LTV:CAC currently 2.8x, target >= 3.5x', now() - interval '7 days', now() + interval '10 days'),
  ('cohort_retention', 'Cohort retention curves', 'metrics', 8.00, 100, 80, 'M6 retention 78%, M12 not yet measurable', now() - interval '3 days', now() + interval '20 days'),
  ('pitch_deck', 'Series-A pitch deck', 'deck', 10.00, 100, 55, 'Slides 8-12 (TAM/SAM/SOM) need rebuild', now() - interval '14 days', now() + interval '7 days'),
  ('demo_video', 'Demo video & product walkthrough', 'deck', 5.00, 100, 90, 'Final color-grade pending', now() - interval '2 days', now() + interval '5 days'),
  ('customer_references', 'Customer reference list (>= 5 hospitals)', 'references', 10.00, 100, 60, 'Have 3 confirmed, need 2 more', now() - interval '4 days', now() + interval '12 days'),
  ('investor_references', 'Existing-investor warm intros', 'references', 7.00, 100, 70, '2 angels confirmed, need 1 Tier-1 VC backchannel', now() - interval '6 days', now() + interval '15 days'),
  ('audited_financials', 'Audited financials (FY24+FY25)', 'financials', 12.00, 100, 40, 'FY25 audit in progress with BDO, ETA 4 weeks', now() - interval '10 days', now() + interval '28 days'),
  ('cap_table', 'Cap table + ESOP pool clarity', 'financials', 6.00, 100, 95, 'Carta sync clean', now() - interval '1 days', now() + interval '30 days'),
  ('pipeline_targets', 'Investor pipeline (>= 30 targets sourced)', 'pipeline', 15.00, 100, 50, 'Currently 18 in CRM, need 12 more Tier-1/2 VCs', now() - interval '2 days', now() + interval '7 days')
ON CONFLICT (dimension_code) DO NOTHING;

-- Seed gaps
INSERT INTO public.fundraising_readiness_gaps_r2269 (dimension_id, gap_title, gap_severity, effort_days, target_close_date)
SELECT id, 'Rebuild TAM/SAM/SOM with TRACxn + IBEF citations', 'high', 5, current_date + 7 FROM public.fundraising_readiness_dimensions_r2269 WHERE dimension_code = 'pitch_deck'
ON CONFLICT DO NOTHING;
INSERT INTO public.fundraising_readiness_gaps_r2269 (dimension_id, gap_title, gap_severity, effort_days, target_close_date)
SELECT id, 'Close BDO FY25 audit interim report', 'blocker', 21, current_date + 28 FROM public.fundraising_readiness_dimensions_r2269 WHERE dimension_code = 'audited_financials'
ON CONFLICT DO NOTHING;
INSERT INTO public.fundraising_readiness_gaps_r2269 (dimension_id, gap_title, gap_severity, effort_days, target_close_date)
SELECT id, 'Source 12 more Tier-1/2 VC targets via Signal', 'high', 7, current_date + 7 FROM public.fundraising_readiness_dimensions_r2269 WHERE dimension_code = 'pipeline_targets'
ON CONFLICT DO NOTHING;
INSERT INTO public.fundraising_readiness_gaps_r2269 (dimension_id, gap_title, gap_severity, effort_days, target_close_date)
SELECT id, 'Optimize CAC payback via channel reweight', 'medium', 14, current_date + 21 FROM public.fundraising_readiness_dimensions_r2269 WHERE dimension_code = 'unit_economics'
ON CONFLICT DO NOTHING;
INSERT INTO public.fundraising_readiness_gaps_r2269 (dimension_id, gap_title, gap_severity, effort_days, target_close_date)
SELECT id, 'Confirm 2 more hospital references (Tier-1 cities)', 'high', 10, current_date + 12 FROM public.fundraising_readiness_dimensions_r2269 WHERE dimension_code = 'customer_references'
ON CONFLICT DO NOTHING;
INSERT INTO public.fundraising_readiness_gaps_r2269 (dimension_id, gap_title, gap_severity, effort_days, target_close_date)
SELECT id, 'Lock 3 consecutive months of 15%+ MoM MRR growth', 'blocker', 60, current_date + 60 FROM public.fundraising_readiness_dimensions_r2269 WHERE dimension_code = 'mrr_growth'
ON CONFLICT DO NOTHING;

-- ============================================================
-- RPC 1: KPI overview
-- ============================================================
CREATE OR REPLACE FUNCTION public.fundraising_readiness_kpis_r2269()
RETURNS TABLE (
  overall_score numeric,
  dimensions_count int,
  ready_dimensions int,
  blocker_dimensions int,
  open_gaps int,
  blocker_gaps int,
  avg_score numeric,
  total_effort_days int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    ROUND(SUM(d.current_score * d.weight_pct / 100.0)::numeric, 2) AS overall_score,
    COUNT(*)::int AS dimensions_count,
    (COUNT(*) FILTER (WHERE d.current_score >= 90))::int AS ready_dimensions,
    (COUNT(*) FILTER (WHERE d.current_score < 60))::int AS blocker_dimensions,
    (SELECT COUNT(*) FROM public.fundraising_readiness_gaps_r2269 g WHERE g.resolved_at IS NULL)::int AS open_gaps,
    (SELECT COUNT(*) FROM public.fundraising_readiness_gaps_r2269 g WHERE g.resolved_at IS NULL AND g.gap_severity = 'blocker')::int AS blocker_gaps,
    ROUND(AVG(d.current_score)::numeric, 2) AS avg_score,
    COALESCE((SELECT SUM(effort_days) FROM public.fundraising_readiness_gaps_r2269 WHERE resolved_at IS NULL), 0)::int AS total_effort_days
  FROM public.fundraising_readiness_dimensions_r2269 d;
END;
$$;

-- ============================================================
-- RPC 2: Category breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION public.fundraising_readiness_by_category_r2269()
RETURNS TABLE (
  category text,
  dimensions_count int,
  weighted_score numeric,
  avg_score numeric,
  total_weight numeric,
  open_gaps int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.category,
    COUNT(*)::int AS dimensions_count,
    ROUND(SUM(d.current_score * d.weight_pct / 100.0)::numeric, 2) AS weighted_score,
    ROUND(AVG(d.current_score)::numeric, 2) AS avg_score,
    ROUND(SUM(d.weight_pct)::numeric, 2) AS total_weight,
    (SELECT COUNT(*) FROM public.fundraising_readiness_gaps_r2269 g
       JOIN public.fundraising_readiness_dimensions_r2269 d2 ON d2.id = g.dimension_id
       WHERE d2.category = d.category AND g.resolved_at IS NULL)::int AS open_gaps
  FROM public.fundraising_readiness_dimensions_r2269 d
  GROUP BY d.category
  ORDER BY weighted_score DESC;
END;
$$;

-- ============================================================
-- RPC 3: Dimension list with scores
-- ============================================================
CREATE OR REPLACE FUNCTION public.fundraising_readiness_dimensions_list_r2269()
RETURNS TABLE (
  dimension_code text,
  dimension_label text,
  category text,
  weight_pct numeric,
  current_score int,
  target_score int,
  gap_to_target int,
  weighted_contribution numeric,
  blocker_notes text,
  last_reviewed_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.dimension_code,
    d.dimension_label,
    d.category,
    d.weight_pct,
    d.current_score,
    d.target_score,
    (d.target_score - d.current_score) AS gap_to_target,
    ROUND((d.current_score * d.weight_pct / 100.0)::numeric, 2) AS weighted_contribution,
    d.blocker_notes,
    d.last_reviewed_at
  FROM public.fundraising_readiness_dimensions_r2269 d
  ORDER BY d.weight_pct DESC, d.current_score ASC;
END;
$$;

-- ============================================================
-- RPC 4: Open gaps by severity
-- ============================================================
CREATE OR REPLACE FUNCTION public.fundraising_readiness_open_gaps_r2269()
RETURNS TABLE (
  gap_title text,
  dimension_label text,
  category text,
  gap_severity text,
  effort_days int,
  target_close_date date,
  days_to_target int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    g.gap_title,
    d.dimension_label,
    d.category,
    g.gap_severity,
    g.effort_days,
    g.target_close_date,
    (g.target_close_date - current_date)::int AS days_to_target
  FROM public.fundraising_readiness_gaps_r2269 g
  JOIN public.fundraising_readiness_dimensions_r2269 d ON d.id = g.dimension_id
  WHERE g.resolved_at IS NULL
  ORDER BY
    CASE g.gap_severity
      WHEN 'blocker' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      ELSE 4
    END,
    g.target_close_date ASC NULLS LAST;
END;
$$;

-- ============================================================
-- RPC 5: Score histogram (for bar chart)
-- ============================================================
CREATE OR REPLACE FUNCTION public.fundraising_readiness_score_buckets_r2269()
RETURNS TABLE (
  bucket text,
  dimensions_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN d.current_score >= 90 THEN 'ready (90-100)'
      WHEN d.current_score >= 75 THEN 'close (75-89)'
      WHEN d.current_score >= 60 THEN 'moderate (60-74)'
      WHEN d.current_score >= 40 THEN 'weak (40-59)'
      ELSE 'blocker (< 40)'
    END AS bucket,
    COUNT(*)::int AS dimensions_count
  FROM public.fundraising_readiness_dimensions_r2269 d
  GROUP BY 1
  ORDER BY MIN(d.current_score) DESC;
END;
$$;

-- ============================================================
-- RPC 6: Update dimension score
-- ============================================================
CREATE OR REPLACE FUNCTION public.fundraising_readiness_update_score_r2269(
  p_dimension_code text,
  p_new_score int,
  p_blocker_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_score < 0 OR p_new_score > 100 THEN
    RAISE EXCEPTION 'score must be between 0 and 100';
  END IF;

  UPDATE public.fundraising_readiness_dimensions_r2269
  SET current_score = p_new_score,
      blocker_notes = COALESCE(p_blocker_notes, blocker_notes),
      last_reviewed_at = now(),
      next_review_due_at = now() + interval '14 days',
      updated_at = now()
  WHERE dimension_code = p_dimension_code
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'dimension % not found', p_dimension_code;
  END IF;

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 7: Resolve gap
-- ============================================================
CREATE OR REPLACE FUNCTION public.fundraising_readiness_resolve_gap_r2269(
  p_gap_id uuid,
  p_resolution_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.fundraising_readiness_gaps_r2269
  SET resolved_at = now(),
      resolution_notes = p_resolution_notes,
      updated_at = now()
  WHERE id = p_gap_id AND resolved_at IS NULL
  RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'gap not found or already resolved';
  END IF;

  RETURN v_id;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
REVOKE ALL ON FUNCTION public.fundraising_readiness_kpis_r2269() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fundraising_readiness_by_category_r2269() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fundraising_readiness_dimensions_list_r2269() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fundraising_readiness_open_gaps_r2269() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fundraising_readiness_score_buckets_r2269() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fundraising_readiness_update_score_r2269(text, int, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fundraising_readiness_resolve_gap_r2269(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fundraising_readiness_kpis_r2269() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fundraising_readiness_by_category_r2269() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fundraising_readiness_dimensions_list_r2269() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fundraising_readiness_open_gaps_r2269() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fundraising_readiness_score_buckets_r2269() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fundraising_readiness_update_score_r2269(text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fundraising_readiness_resolve_gap_r2269(uuid, text) TO authenticated;

COMMIT;
