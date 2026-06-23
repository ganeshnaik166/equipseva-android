-- Round 2481: founder-board-pack-quality-scorer
-- Tables: founder_board_pack_scores_r2481, board_pack_section_quality_r2481

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_board_pack_scores_r2481 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  sections_delivered int NOT NULL DEFAULT 0 CHECK (sections_delivered >= 0),
  sections_planned int NOT NULL DEFAULT 0 CHECK (sections_planned >= 0),
  data_freshness_pct int NOT NULL DEFAULT 0 CHECK (data_freshness_pct BETWEEN 0 AND 100),
  narrative_quality_score int NOT NULL DEFAULT 0 CHECK (narrative_quality_score BETWEEN 0 AND 100),
  investor_feedback_md text,
  iteration_count int NOT NULL DEFAULT 0 CHECK (iteration_count >= 0),
  founder_self_rating int NOT NULL DEFAULT 0 CHECK (founder_self_rating BETWEEN 0 AND 10),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','sent','closed')),
  sent_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.board_pack_section_quality_r2481 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id uuid NOT NULL REFERENCES public.founder_board_pack_scores_r2481(id) ON DELETE CASCADE,
  section_kind text NOT NULL CHECK (section_kind IN ('business_metrics','financials','customers','team','risks','asks','strategy')),
  data_freshness_pct int NOT NULL DEFAULT 0 CHECK (data_freshness_pct BETWEEN 0 AND 100),
  narrative_score int NOT NULL DEFAULT 0 CHECK (narrative_score BETWEEN 0 AND 100),
  top_omission text,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','skipped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_board_pack_scores_r2481 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_pack_section_quality_r2481 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_board_pack_scores_r2481;
CREATE POLICY founder_all ON public.founder_board_pack_scores_r2481
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.board_pack_section_quality_r2481;
CREATE POLICY founder_all ON public.board_pack_section_quality_r2481
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed packs
INSERT INTO public.founder_board_pack_scores_r2481
  (id, quarter_label, sections_delivered, sections_planned, data_freshness_pct, narrative_quality_score, investor_feedback_md, iteration_count, founder_self_rating, status, sent_at, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111'::uuid, 'Q2-2026', 7, 7, 92, 88, 'Strong metrics, ask slide clearer this time', 3, 8, 'sent', '2026-06-15T10:00:00Z'::timestamptz, 'Best pack so far'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'Q1-2026', 6, 7, 78, 72, 'Risks section thin; want more on burn runway', 4, 6, 'closed', '2026-03-18T09:30:00Z'::timestamptz, 'Investors flagged team slide'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'Q3-2026', 4, 7, 60, 55, NULL, 1, 5, 'draft', NULL, 'Early draft; financials still rolling up'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'Q4-2025', 7, 7, 85, 80, 'Asks list well-prioritized', 5, 7, 'final', '2025-12-20T11:00:00Z'::timestamptz, 'Solid close-out');

-- Seed sections
INSERT INTO public.board_pack_section_quality_r2481
  (pack_id, section_kind, data_freshness_pct, narrative_score, top_omission, owner_email, status, notes)
VALUES
  ('11111111-1111-1111-1111-111111111111'::uuid, 'business_metrics', 95, 90, NULL, 'founder@equipseva.in', 'final', 'MRR + churn + LTV'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'financials', 90, 85, 'no cash burn waterfall', 'cfo@equipseva.in', 'final', 'Cash + runway'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'customers', 92, 88, NULL, 'sales@equipseva.in', 'final', 'Logos + NPS'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'team', 88, 82, 'no org chart', 'people@equipseva.in', 'final', 'Hires + open roles'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'risks', 90, 80, NULL, 'founder@equipseva.in', 'final', 'Top 5 risks'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'asks', 95, 92, NULL, 'founder@equipseva.in', 'final', '3 specific asks'),
  ('11111111-1111-1111-1111-111111111111'::uuid, 'strategy', 92, 90, NULL, 'founder@equipseva.in', 'final', 'Next 2 quarters'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'business_metrics', 80, 75, 'missing cohort retention', 'founder@equipseva.in', 'final', 'Metrics ok'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'financials', 75, 70, 'no burn runway chart', 'cfo@equipseva.in', 'final', 'Financials thin'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'risks', 60, 55, 'top 3 risks missing mitigation owners', 'founder@equipseva.in', 'final', 'Needs work'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'team', 70, 65, 'no hiring plan', 'people@equipseva.in', 'final', 'Team slide weak'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'business_metrics', 65, 60, 'churn data stale by 30 days', 'founder@equipseva.in', 'draft', 'WIP'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'financials', 55, 50, 'not rolled up yet', 'cfo@equipseva.in', 'draft', 'Q3 close pending'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'business_metrics', 90, 85, NULL, 'founder@equipseva.in', 'final', 'Solid'),
  ('44444444-4444-4444-4444-444444444444'::uuid, 'asks', 85, 80, NULL, 'founder@equipseva.in', 'final', '4 asks');

-- RPC 1: list pack scores
CREATE OR REPLACE FUNCTION public.list_pack_scores_r2481()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  sections_delivered int,
  sections_planned int,
  data_freshness_pct int,
  narrative_quality_score int,
  iteration_count int,
  founder_self_rating int,
  status text,
  sent_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.quarter_label, p.sections_delivered, p.sections_planned,
           p.data_freshness_pct, p.narrative_quality_score, p.iteration_count,
           p.founder_self_rating, p.status, p.sent_at, p.notes
    FROM public.founder_board_pack_scores_r2481 p
    ORDER BY p.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_pack_scores_r2481() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pack_scores_r2481() TO authenticated;

-- RPC 2: list section quality
CREATE OR REPLACE FUNCTION public.list_section_quality_r2481()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  section_kind text,
  data_freshness_pct int,
  narrative_score int,
  top_omission text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, p.quarter_label, s.section_kind, s.data_freshness_pct, s.narrative_score,
           s.top_omission, s.owner_email, s.status, s.notes
    FROM public.board_pack_section_quality_r2481 s
    JOIN public.founder_board_pack_scores_r2481 p ON p.id = s.pack_id
    ORDER BY p.created_at DESC, s.section_kind;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_section_quality_r2481() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_section_quality_r2481() TO authenticated;

-- RPC 3: top omissions
CREATE OR REPLACE FUNCTION public.top_omissions_r2481()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  section_kind text,
  top_omission text,
  data_freshness_pct int,
  narrative_score int,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, p.quarter_label, s.section_kind, s.top_omission,
           s.data_freshness_pct, s.narrative_score, s.owner_email
    FROM public.board_pack_section_quality_r2481 s
    JOIN public.founder_board_pack_scores_r2481 p ON p.id = s.pack_id
    WHERE s.top_omission IS NOT NULL AND length(trim(s.top_omission)) > 0
    ORDER BY s.narrative_score ASC, s.data_freshness_pct ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_omissions_r2481() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_omissions_r2481() TO authenticated;

-- RPC 4: quarterly quality trend
CREATE OR REPLACE FUNCTION public.quarterly_quality_trend_r2481()
RETURNS TABLE (
  quarter_label text,
  avg_freshness numeric,
  avg_narrative numeric,
  sections_delivered int,
  sections_planned int,
  delivery_pct numeric,
  iteration_count int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.quarter_label,
           ROUND(AVG(p.data_freshness_pct)::numeric, 1) AS avg_freshness,
           ROUND(AVG(p.narrative_quality_score)::numeric, 1) AS avg_narrative,
           p.sections_delivered,
           p.sections_planned,
           CASE WHEN p.sections_planned = 0 THEN 0::numeric
                ELSE ROUND((p.sections_delivered::numeric / p.sections_planned::numeric) * 100, 1) END AS delivery_pct,
           p.iteration_count,
           p.status
    FROM public.founder_board_pack_scores_r2481 p
    GROUP BY p.quarter_label, p.sections_delivered, p.sections_planned, p.iteration_count, p.status, p.created_at
    ORDER BY p.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_quality_trend_r2481() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_quality_trend_r2481() TO authenticated;

-- RPC 5: section kind breakdown
CREATE OR REPLACE FUNCTION public.section_kind_breakdown_r2481()
RETURNS TABLE (
  section_kind text,
  section_count bigint,
  avg_freshness numeric,
  avg_narrative numeric,
  omissions_flagged bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.section_kind,
           COUNT(*)::bigint AS section_count,
           ROUND(AVG(s.data_freshness_pct)::numeric, 1) AS avg_freshness,
           ROUND(AVG(s.narrative_score)::numeric, 1) AS avg_narrative,
           COUNT(*) FILTER (WHERE s.top_omission IS NOT NULL AND length(trim(s.top_omission)) > 0)::bigint AS omissions_flagged
    FROM public.board_pack_section_quality_r2481 s
    GROUP BY s.section_kind
    ORDER BY avg_narrative ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.section_kind_breakdown_r2481() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.section_kind_breakdown_r2481() TO authenticated;

-- RPC 6: iteration velocity
CREATE OR REPLACE FUNCTION public.iteration_velocity_r2481()
RETURNS TABLE (
  quarter_label text,
  iteration_count int,
  narrative_quality_score int,
  data_freshness_pct int,
  founder_self_rating int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.quarter_label, p.iteration_count, p.narrative_quality_score,
           p.data_freshness_pct, p.founder_self_rating, p.status
    FROM public.founder_board_pack_scores_r2481 p
    ORDER BY p.iteration_count DESC, p.narrative_quality_score DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.iteration_velocity_r2481() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.iteration_velocity_r2481() TO authenticated;

-- RPC 7: founder pulse summary
CREATE OR REPLACE FUNCTION public.founder_pulse_summary_r2481()
RETURNS TABLE (
  total_packs bigint,
  sent_or_final bigint,
  draft_packs bigint,
  avg_freshness numeric,
  avg_narrative numeric,
  avg_iterations numeric,
  total_omissions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint AS total_packs,
           COUNT(*) FILTER (WHERE p.status IN ('sent','final','closed'))::bigint AS sent_or_final,
           COUNT(*) FILTER (WHERE p.status = 'draft')::bigint AS draft_packs,
           ROUND(AVG(p.data_freshness_pct)::numeric, 1) AS avg_freshness,
           ROUND(AVG(p.narrative_quality_score)::numeric, 1) AS avg_narrative,
           ROUND(AVG(p.iteration_count)::numeric, 1) AS avg_iterations,
           (SELECT COUNT(*)::bigint FROM public.board_pack_section_quality_r2481 s
             WHERE s.top_omission IS NOT NULL AND length(trim(s.top_omission)) > 0) AS total_omissions
    FROM public.founder_board_pack_scores_r2481 p;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2481() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2481() TO authenticated;

