-- Round 2541: founder-quarterly-board-deck-narrative-arc
-- Tracks quarterly board deck narratives + arc evolution across quarters.

CREATE TABLE IF NOT EXISTS public.founder_quarterly_narratives_r2541 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  narrative_theme text NOT NULL,
  top_wins_md text,
  top_misses_md text,
  asks_md text,
  confidence_score int NOT NULL DEFAULT 50 CHECK (confidence_score BETWEEN 0 AND 100),
  consistency_with_prior_quarter int NOT NULL DEFAULT 50 CHECK (consistency_with_prior_quarter BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','sent','closed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.narrative_arc_evolution_r2541 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  prior_quarter_label text,
  theme_continuity_kind text NOT NULL CHECK (theme_continuity_kind IN ('extends','pivots','contradicts','new_thread')),
  change_summary_md text,
  founder_confidence_delta_pct int NOT NULL DEFAULT 0,
  board_received_kind text NOT NULL CHECK (board_received_kind IN ('aligned','concerned','aligned_with_question','diverged')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_narratives_r2541 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.narrative_arc_evolution_r2541 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_quarterly_narratives_r2541;
CREATE POLICY founder_all ON public.founder_quarterly_narratives_r2541
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.narrative_arc_evolution_r2541;
CREATE POLICY founder_all ON public.narrative_arc_evolution_r2541
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.founder_quarterly_narratives_r2541
  (quarter_label, narrative_theme, top_wins_md, top_misses_md, asks_md, confidence_score, consistency_with_prior_quarter, owner_email, status, notes)
VALUES
  ('Q1-2026','From founder-led to repeatable engine','- 458 ships v0.4 day 5\n- AMC churn down 12%','- Cashfree KYC slip 2 weeks\n- Engineer rotation gap','- Bridge 1.5Cr at 18Cr cap\n- 2 senior eng hires',78,72,'founder@equipseva.in','final','Strong wins narrative, miss on payouts'),
  ('Q4-2025','Dental vertical wedge proven','- 12 dental chains signed\n- NABH cert ladder live','- Repair-job SLA breach 8%\n- Code-Red over-fired','- Vertical-2 ICP greenlight',71,65,'founder@equipseva.in','sent','Picked dental over multi-vertical'),
  ('Q3-2025','Repair-marketplace defensible moat','- 240 engineers onboarded\n- Supervised training live','- AMC payment-first delayed','- Marketplace liquidity playbook',64,58,'founder@equipseva.in','closed','Vertical pivot seed planted'),
  ('Q2-2026','Hospital chain land + expand','- 3 chain CFO budget cycles aligned\n- Procurement policy parser live','- Tier-1 home install drop-off','- Chain BD 3-headcount',82,76,'founder@equipseva.in','draft','In progress, board read week 5');

INSERT INTO public.narrative_arc_evolution_r2541
  (quarter_label, prior_quarter_label, theme_continuity_kind, change_summary_md, founder_confidence_delta_pct, board_received_kind, notes)
VALUES
  ('Q4-2025','Q3-2025','pivots','Pivoted from multi-vertical to dental wedge after ICP data',7,'aligned_with_question','Board asked about Tier-2 timing'),
  ('Q1-2026','Q4-2025','extends','Repeatable engine extends dental wedge into chain land+expand',7,'aligned','Strong confidence vote'),
  ('Q2-2026','Q1-2026','extends','Chain BD becomes the repeatable engine, not founder-led',4,'aligned','Pre-read sent week 5'),
  ('Q3-2025','Q2-2025','new_thread','Marketplace moat thesis introduced fresh',-3,'concerned','First mention of engineer rotation risk');

-- RPC 1: list_narratives_r2541
CREATE OR REPLACE FUNCTION public.list_narratives_r2541()
RETURNS SETOF public.founder_quarterly_narratives_r2541
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.founder_quarterly_narratives_r2541 ORDER BY quarter_label DESC, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_narratives_r2541() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_narratives_r2541() TO authenticated;

-- RPC 2: list_arc_evolution_r2541
CREATE OR REPLACE FUNCTION public.list_arc_evolution_r2541()
RETURNS SETOF public.narrative_arc_evolution_r2541
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.narrative_arc_evolution_r2541 ORDER BY quarter_label DESC, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_arc_evolution_r2541() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_arc_evolution_r2541() TO authenticated;

-- RPC 3: quarterly_confidence_trend_r2541
CREATE OR REPLACE FUNCTION public.quarterly_confidence_trend_r2541()
RETURNS TABLE(quarter_label text, confidence_score int, consistency_with_prior_quarter int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT n.quarter_label, n.confidence_score, n.consistency_with_prior_quarter, n.status
    FROM public.founder_quarterly_narratives_r2541 n
    ORDER BY n.quarter_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_confidence_trend_r2541() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_confidence_trend_r2541() TO authenticated;

-- RPC 4: narrative_theme_breakdown_r2541
CREATE OR REPLACE FUNCTION public.narrative_theme_breakdown_r2541()
RETURNS TABLE(narrative_theme text, narrative_count bigint, avg_confidence numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT n.narrative_theme, COUNT(*)::bigint AS narrative_count, ROUND(AVG(n.confidence_score)::numeric, 2) AS avg_confidence
    FROM public.founder_quarterly_narratives_r2541 n
    GROUP BY n.narrative_theme
    ORDER BY narrative_count DESC, avg_confidence DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.narrative_theme_breakdown_r2541() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.narrative_theme_breakdown_r2541() TO authenticated;

-- RPC 5: pivot_focus_r2541
CREATE OR REPLACE FUNCTION public.pivot_focus_r2541()
RETURNS TABLE(quarter_label text, prior_quarter_label text, theme_continuity_kind text, change_summary_md text, founder_confidence_delta_pct int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.quarter_label, e.prior_quarter_label, e.theme_continuity_kind, e.change_summary_md, e.founder_confidence_delta_pct
    FROM public.narrative_arc_evolution_r2541 e
    WHERE e.theme_continuity_kind IN ('pivots','contradicts','new_thread')
    ORDER BY e.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.pivot_focus_r2541() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pivot_focus_r2541() TO authenticated;

-- RPC 6: board_alignment_summary_r2541
CREATE OR REPLACE FUNCTION public.board_alignment_summary_r2541()
RETURNS TABLE(board_received_kind text, evolution_count bigint, avg_confidence_delta numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.board_received_kind, COUNT(*)::bigint AS evolution_count, ROUND(AVG(e.founder_confidence_delta_pct)::numeric, 2) AS avg_confidence_delta
    FROM public.narrative_arc_evolution_r2541 e
    GROUP BY e.board_received_kind
    ORDER BY evolution_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.board_alignment_summary_r2541() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.board_alignment_summary_r2541() TO authenticated;

-- RPC 7: consistency_score_distribution_r2541
CREATE OR REPLACE FUNCTION public.consistency_score_distribution_r2541()
RETURNS TABLE(consistency_band text, narrative_count bigint, avg_confidence numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      CASE
        WHEN n.consistency_with_prior_quarter >= 80 THEN '80-100 high'
        WHEN n.consistency_with_prior_quarter >= 60 THEN '60-79 medium'
        WHEN n.consistency_with_prior_quarter >= 40 THEN '40-59 low'
        ELSE '0-39 pivot'
      END AS consistency_band,
      COUNT(*)::bigint AS narrative_count,
      ROUND(AVG(n.confidence_score)::numeric, 2) AS avg_confidence
    FROM public.founder_quarterly_narratives_r2541 n
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.consistency_score_distribution_r2541() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.consistency_score_distribution_r2541() TO authenticated;
