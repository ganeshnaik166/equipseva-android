-- Round 2561: founder-quarterly-product-strategy-doc
-- Quarter × product strategy version × pivots × kill candidates × greenlight × board alignment

BEGIN;

-- ============================================================
-- Table 1: founder_quarterly_product_strategy_r2561
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_quarterly_product_strategy_r2561 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  version_label text NOT NULL,
  pivots_md text,
  kill_candidates_md text,
  greenlights_md text,
  board_alignment_score int NOT NULL DEFAULT 0 CHECK (board_alignment_score BETWEEN 0 AND 100),
  founder_self_confidence_score int NOT NULL DEFAULT 0 CHECK (founder_self_confidence_score BETWEEN 0 AND 100),
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','final','closed','superseded')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_product_strategy_r2561 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_quarterly_product_strategy_r2561;
CREATE POLICY founder_all ON public.founder_quarterly_product_strategy_r2561
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_qstrat_r2561_quarter ON public.founder_quarterly_product_strategy_r2561(quarter_label);
CREATE INDEX IF NOT EXISTS idx_qstrat_r2561_status ON public.founder_quarterly_product_strategy_r2561(status);
CREATE INDEX IF NOT EXISTS idx_qstrat_r2561_created ON public.founder_quarterly_product_strategy_r2561(created_at DESC);

-- ============================================================
-- Table 2: product_strategy_pivot_events_r2561
-- ============================================================
CREATE TABLE IF NOT EXISTS public.product_strategy_pivot_events_r2561 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  strategy_id uuid NOT NULL REFERENCES public.founder_quarterly_product_strategy_r2561(id) ON DELETE CASCADE,
  pivot_at timestamptz NOT NULL DEFAULT now(),
  pivot_kind text NOT NULL CHECK (pivot_kind IN ('killed','scoped_down','expanded','repositioned','new_thread')),
  pivot_summary_md text,
  board_response_kind text NOT NULL DEFAULT 'aligned' CHECK (board_response_kind IN ('aligned','concerned','aligned_with_question','diverged')),
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.product_strategy_pivot_events_r2561 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.product_strategy_pivot_events_r2561;
CREATE POLICY founder_all ON public.product_strategy_pivot_events_r2561
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_pivot_ev_r2561_strategy ON public.product_strategy_pivot_events_r2561(strategy_id);
CREATE INDEX IF NOT EXISTS idx_pivot_ev_r2561_at ON public.product_strategy_pivot_events_r2561(pivot_at DESC);
CREATE INDEX IF NOT EXISTS idx_pivot_ev_r2561_kind ON public.product_strategy_pivot_events_r2561(pivot_kind);

-- ============================================================
-- Seed data: 4 strategy docs, 6 pivot events
-- ============================================================
DO $seed$
DECLARE
  s1 uuid;
  s2 uuid;
  s3 uuid;
  s4 uuid;
BEGIN
  INSERT INTO public.founder_quarterly_product_strategy_r2561
    (quarter_label, version_label, pivots_md, kill_candidates_md, greenlights_md,
     board_alignment_score, founder_self_confidence_score, owner_email, status, notes)
  VALUES ('2026-Q1', 'v1.0',
          '- Pivot AMC tiering from 2 tiers to 4',
          '- Kill: standalone consumer app',
          '- Greenlight: chain bulk v1, engineer app v0.4',
          82, 78, 'founder@equipseva.in', 'closed',
          'Solid Q1 plan, executed clean.')
  RETURNING id INTO s1;

  INSERT INTO public.founder_quarterly_product_strategy_r2561
    (quarter_label, version_label, pivots_md, kill_candidates_md, greenlights_md,
     board_alignment_score, founder_self_confidence_score, owner_email, status, notes)
  VALUES ('2026-Q2', 'v1.0',
          '- Pivot toward hospital chain accounts over single-hospital',
          '- Kill: paid acquisition channel',
          '- Greenlight: v0.5 founder console, GST filing, AMC churn workflow',
          88, 84, 'founder@equipseva.in', 'final',
          'Q2 plan locked, board signed off.')
  RETURNING id INTO s2;

  INSERT INTO public.founder_quarterly_product_strategy_r2561
    (quarter_label, version_label, pivots_md, kill_candidates_md, greenlights_md,
     board_alignment_score, founder_self_confidence_score, owner_email, status, notes)
  VALUES ('2026-Q2', 'v1.1',
          '- Pivot: add Tier-1 home expansion ahead of schedule',
          '- Kill: deferred international pilot',
          '- Greenlight: morning digest, weekly board pack',
          74, 70, 'founder@equipseva.in', 'superseded',
          'Mid-quarter revision after r1322 wave shipped early.')
  RETURNING id INTO s3;

  INSERT INTO public.founder_quarterly_product_strategy_r2561
    (quarter_label, version_label, pivots_md, kill_candidates_md, greenlights_md,
     board_alignment_score, founder_self_confidence_score, owner_email, status, notes)
  VALUES ('2026-Q3', 'v0.9',
          '- Reposition engineer app v0.6 as primary revenue driver',
          '- Kill candidate: franchise model (signal weak)',
          '- Greenlight: AI triage, Cashfree at scale, hospital portal v2',
          68, 72, 'founder@equipseva.in', 'in_review',
          'Q3 draft, board feedback pending on franchise kill.')
  RETURNING id INTO s4;

  -- Pivot events
  INSERT INTO public.product_strategy_pivot_events_r2561
    (strategy_id, pivot_at, pivot_kind, pivot_summary_md, board_response_kind, owner_email, notes)
  VALUES
    (s1, '2026-02-10T10:00:00Z'::timestamptz, 'expanded',
     'Expanded AMC tiers from 2 to 4 after Tier-1 hospital feedback', 'aligned',
     'founder@equipseva.in', 'Board liked broader segmentation.'),
    (s1, '2026-03-05T10:00:00Z'::timestamptz, 'killed',
     'Killed standalone consumer app — wrong ICP', 'aligned_with_question',
     'founder@equipseva.in', 'Asked: why not B2B2C later?'),
    (s2, '2026-04-15T10:00:00Z'::timestamptz, 'repositioned',
     'Repositioned roadmap around hospital chains over single hospitals', 'aligned',
     'founder@equipseva.in', 'Chain TAM math landed.'),
    (s2, '2026-05-08T10:00:00Z'::timestamptz, 'killed',
     'Killed paid acquisition spend; doubled down on referrals', 'concerned',
     'founder@equipseva.in', 'Board concerned about growth rate.'),
    (s3, '2026-06-01T10:00:00Z'::timestamptz, 'new_thread',
     'Added Tier-1 home expansion as new thread', 'aligned',
     'founder@equipseva.in', 'New TAM unlocked.'),
    (s4, '2026-06-18T10:00:00Z'::timestamptz, 'scoped_down',
     'Scoped down franchise model to single pilot', 'diverged',
     'founder@equipseva.in', 'Two board members wanted full kill.');
END;
$seed$;

-- ============================================================
-- RPC 1: list_strategy_docs_r2561
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_strategy_docs_r2561()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  version_label text,
  board_alignment_score int,
  founder_self_confidence_score int,
  owner_email text,
  status text,
  pivots_md text,
  kill_candidates_md text,
  greenlights_md text,
  created_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.quarter_label, s.version_label, s.board_alignment_score,
         s.founder_self_confidence_score, s.owner_email, s.status,
         s.pivots_md, s.kill_candidates_md, s.greenlights_md,
         s.created_at, s.notes
  FROM public.founder_quarterly_product_strategy_r2561 s
  ORDER BY s.quarter_label DESC, s.version_label DESC, s.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_strategy_docs_r2561() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_strategy_docs_r2561() TO authenticated;

-- ============================================================
-- RPC 2: list_pivot_events_r2561
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_pivot_events_r2561()
RETURNS TABLE (
  id uuid,
  strategy_id uuid,
  quarter_label text,
  version_label text,
  pivot_at timestamptz,
  pivot_kind text,
  pivot_summary_md text,
  board_response_kind text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.strategy_id, s.quarter_label, s.version_label,
         p.pivot_at, p.pivot_kind, p.pivot_summary_md,
         p.board_response_kind, p.owner_email, p.notes
  FROM public.product_strategy_pivot_events_r2561 p
  JOIN public.founder_quarterly_product_strategy_r2561 s ON s.id = p.strategy_id
  ORDER BY p.pivot_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pivot_events_r2561() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pivot_events_r2561() TO authenticated;

-- ============================================================
-- RPC 3: alignment_score_trend_r2561
-- ============================================================
CREATE OR REPLACE FUNCTION public.alignment_score_trend_r2561()
RETURNS TABLE (
  quarter_label text,
  version_label text,
  board_alignment_score int,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label, s.version_label, s.board_alignment_score, s.status, s.created_at
  FROM public.founder_quarterly_product_strategy_r2561 s
  ORDER BY s.quarter_label ASC, s.version_label ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.alignment_score_trend_r2561() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.alignment_score_trend_r2561() TO authenticated;

-- ============================================================
-- RPC 4: pivot_kind_breakdown_r2561
-- ============================================================
CREATE OR REPLACE FUNCTION public.pivot_kind_breakdown_r2561()
RETURNS TABLE (
  pivot_kind text,
  event_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.pivot_kind, COUNT(*)::bigint AS event_count
  FROM public.product_strategy_pivot_events_r2561 p
  GROUP BY p.pivot_kind
  ORDER BY event_count DESC, p.pivot_kind ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.pivot_kind_breakdown_r2561() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pivot_kind_breakdown_r2561() TO authenticated;

-- ============================================================
-- RPC 5: board_response_summary_r2561
-- ============================================================
CREATE OR REPLACE FUNCTION public.board_response_summary_r2561()
RETURNS TABLE (
  board_response_kind text,
  event_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.board_response_kind, COUNT(*)::bigint AS event_count
  FROM public.product_strategy_pivot_events_r2561 p
  GROUP BY p.board_response_kind
  ORDER BY event_count DESC, p.board_response_kind ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.board_response_summary_r2561() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.board_response_summary_r2561() TO authenticated;

-- ============================================================
-- RPC 6: quarterly_confidence_trend_r2561
-- ============================================================
CREATE OR REPLACE FUNCTION public.quarterly_confidence_trend_r2561()
RETURNS TABLE (
  quarter_label text,
  version_label text,
  founder_self_confidence_score int,
  board_alignment_score int,
  confidence_gap int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter_label, s.version_label,
         s.founder_self_confidence_score, s.board_alignment_score,
         (s.founder_self_confidence_score - s.board_alignment_score) AS confidence_gap,
         s.status
  FROM public.founder_quarterly_product_strategy_r2561 s
  ORDER BY s.quarter_label ASC, s.version_label ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.quarterly_confidence_trend_r2561() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_confidence_trend_r2561() TO authenticated;

-- ============================================================
-- RPC 7: latest_locked_strategy_r2561
-- ============================================================
CREATE OR REPLACE FUNCTION public.latest_locked_strategy_r2561()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  version_label text,
  status text,
  board_alignment_score int,
  founder_self_confidence_score int,
  pivots_md text,
  kill_candidates_md text,
  greenlights_md text,
  owner_email text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.quarter_label, s.version_label, s.status,
         s.board_alignment_score, s.founder_self_confidence_score,
         s.pivots_md, s.kill_candidates_md, s.greenlights_md,
         s.owner_email, s.created_at
  FROM public.founder_quarterly_product_strategy_r2561 s
  WHERE s.status IN ('final','closed')
  ORDER BY s.quarter_label DESC, s.version_label DESC, s.created_at DESC
  LIMIT 1;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.latest_locked_strategy_r2561() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.latest_locked_strategy_r2561() TO authenticated;

