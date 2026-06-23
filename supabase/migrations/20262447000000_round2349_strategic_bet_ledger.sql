BEGIN;

-- ============================================================================
-- Round 2349: Founder strategic-bet ledger
-- Every strategic bet placed (geo expansion, vertical, hire), hypothesis,
-- outcome, attribution to growth
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_strategic_bets_r2349 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_name text NOT NULL,
  bet_category text NOT NULL CHECK (bet_category IN ('geo_expansion','vertical','hire','product','partnership','pricing','channel','tech')),
  thesis text NOT NULL,
  hypothesis text NOT NULL,
  success_criteria text NOT NULL,
  capital_committed_rupees bigint NOT NULL DEFAULT 0,
  time_commitment_weeks integer NOT NULL DEFAULT 0,
  expected_revenue_lift_rupees bigint NOT NULL DEFAULT 0,
  actual_revenue_lift_rupees bigint NOT NULL DEFAULT 0,
  expected_logo_lift integer NOT NULL DEFAULT 0,
  actual_logo_lift integer NOT NULL DEFAULT 0,
  confidence_pct integer NOT NULL DEFAULT 50 CHECK (confidence_pct BETWEEN 0 AND 100),
  risk_level text NOT NULL DEFAULT 'medium' CHECK (risk_level IN ('low','medium','high','bet_the_farm')),
  status text NOT NULL DEFAULT 'placed' CHECK (status IN ('placed','in_flight','won','lost','partial','killed')),
  placed_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  placed_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  outcome_summary text,
  growth_attribution_pct integer DEFAULT 0 CHECK (growth_attribution_pct BETWEEN 0 AND 100),
  lessons_learned text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsbets_r2349_status
  ON public.founder_strategic_bets_r2349(status, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsbets_r2349_cat
  ON public.founder_strategic_bets_r2349(bet_category, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsbets_r2349_risk
  ON public.founder_strategic_bets_r2349(risk_level, status);

ALTER TABLE public.founder_strategic_bets_r2349 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fsbets_r2349 ON public.founder_strategic_bets_r2349;
CREATE POLICY founder_all_fsbets_r2349 ON public.founder_strategic_bets_r2349
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_strategic_bet_milestones_r2349 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bet_id uuid NOT NULL REFERENCES public.founder_strategic_bets_r2349(id) ON DELETE CASCADE,
  milestone_label text NOT NULL,
  target_date date NOT NULL,
  hit_date date,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','hit','missed','slipped')),
  metric_target_value numeric,
  metric_actual_value numeric,
  metric_unit text,
  noted_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fsbet_ms_r2349_bet
  ON public.founder_strategic_bet_milestones_r2349(bet_id, target_date);
CREATE INDEX IF NOT EXISTS idx_fsbet_ms_r2349_status
  ON public.founder_strategic_bet_milestones_r2349(status, target_date);

ALTER TABLE public.founder_strategic_bet_milestones_r2349 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fsbet_ms_r2349 ON public.founder_strategic_bet_milestones_r2349;
CREATE POLICY founder_all_fsbet_ms_r2349 ON public.founder_strategic_bet_milestones_r2349
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: portfolio snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_strategic_bets_r2349_portfolio()
RETURNS TABLE (
  total_bets bigint,
  bets_in_flight bigint,
  bets_won bigint,
  bets_lost bigint,
  bets_partial bigint,
  bets_killed bigint,
  total_capital_committed_rupees bigint,
  total_expected_revenue_rupees bigint,
  total_actual_revenue_rupees bigint,
  win_rate_pct numeric,
  capital_efficiency_x numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE b.status IN ('placed','in_flight'))::bigint,
    COUNT(*) FILTER (WHERE b.status = 'won')::bigint,
    COUNT(*) FILTER (WHERE b.status = 'lost')::bigint,
    COUNT(*) FILTER (WHERE b.status = 'partial')::bigint,
    COUNT(*) FILTER (WHERE b.status = 'killed')::bigint,
    COALESCE(SUM(b.capital_committed_rupees), 0)::bigint,
    COALESCE(SUM(b.expected_revenue_lift_rupees), 0)::bigint,
    COALESCE(SUM(b.actual_revenue_lift_rupees), 0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE b.status IN ('won','lost','partial','killed')) > 0
      THEN ROUND(
        100.0 * COUNT(*) FILTER (WHERE b.status = 'won')::numeric
          / COUNT(*) FILTER (WHERE b.status IN ('won','lost','partial','killed'))::numeric,
        1)
      ELSE 0 END,
    CASE WHEN COALESCE(SUM(b.capital_committed_rupees), 0) > 0
      THEN ROUND(
        SUM(b.actual_revenue_lift_rupees)::numeric
          / NULLIF(SUM(b.capital_committed_rupees), 0)::numeric,
        2)
      ELSE 0 END
  FROM public.founder_strategic_bets_r2349 b;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_strategic_bets_r2349_portfolio() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_strategic_bets_r2349_portfolio() TO authenticated;

-- ============================================================================
-- RPC 2: bets by category
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_strategic_bets_r2349_by_category()
RETURNS TABLE (
  bet_category text,
  total_bets bigint,
  bets_won bigint,
  bets_lost bigint,
  capital_committed_rupees bigint,
  actual_revenue_rupees bigint,
  win_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    b.bet_category,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE b.status = 'won')::bigint,
    COUNT(*) FILTER (WHERE b.status = 'lost')::bigint,
    COALESCE(SUM(b.capital_committed_rupees), 0)::bigint,
    COALESCE(SUM(b.actual_revenue_lift_rupees), 0)::bigint,
    CASE WHEN COUNT(*) FILTER (WHERE b.status IN ('won','lost','partial','killed')) > 0
      THEN ROUND(
        100.0 * COUNT(*) FILTER (WHERE b.status = 'won')::numeric
          / COUNT(*) FILTER (WHERE b.status IN ('won','lost','partial','killed'))::numeric,
        1)
      ELSE 0 END
  FROM public.founder_strategic_bets_r2349 b
  GROUP BY b.bet_category
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_strategic_bets_r2349_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_strategic_bets_r2349_by_category() TO authenticated;

-- ============================================================================
-- RPC 3: list bets
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_strategic_bets_r2349_list(
  p_status text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  bet_name text,
  bet_category text,
  status text,
  risk_level text,
  capital_committed_rupees bigint,
  expected_revenue_lift_rupees bigint,
  actual_revenue_lift_rupees bigint,
  confidence_pct integer,
  growth_attribution_pct integer,
  placed_at timestamptz,
  decided_at timestamptz,
  placed_by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.bet_name,
    b.bet_category,
    b.status,
    b.risk_level,
    b.capital_committed_rupees,
    b.expected_revenue_lift_rupees,
    b.actual_revenue_lift_rupees,
    b.confidence_pct,
    b.growth_attribution_pct,
    b.placed_at,
    b.decided_at,
    p.email
  FROM public.founder_strategic_bets_r2349 b
  LEFT JOIN public.profiles p ON p.id = b.placed_by_user_id
  WHERE (p_status IS NULL OR b.status = p_status)
    AND (p_category IS NULL OR b.bet_category = p_category)
  ORDER BY b.placed_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_strategic_bets_r2349_list(text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_strategic_bets_r2349_list(text, text, integer) TO authenticated;

-- ============================================================================
-- RPC 4: top wins
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_strategic_bets_r2349_top_wins()
RETURNS TABLE (
  id uuid,
  bet_name text,
  bet_category text,
  capital_committed_rupees bigint,
  actual_revenue_lift_rupees bigint,
  return_multiple numeric,
  growth_attribution_pct integer,
  decided_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.bet_name,
    b.bet_category,
    b.capital_committed_rupees,
    b.actual_revenue_lift_rupees,
    CASE WHEN b.capital_committed_rupees > 0
      THEN ROUND(b.actual_revenue_lift_rupees::numeric / b.capital_committed_rupees::numeric, 2)
      ELSE 0 END,
    b.growth_attribution_pct,
    b.decided_at
  FROM public.founder_strategic_bets_r2349 b
  WHERE b.status IN ('won','partial')
    AND b.actual_revenue_lift_rupees > 0
  ORDER BY b.actual_revenue_lift_rupees DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_strategic_bets_r2349_top_wins() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_strategic_bets_r2349_top_wins() TO authenticated;

-- ============================================================================
-- RPC 5: top losses
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_strategic_bets_r2349_top_losses()
RETURNS TABLE (
  id uuid,
  bet_name text,
  bet_category text,
  capital_committed_rupees bigint,
  actual_revenue_lift_rupees bigint,
  net_loss_rupees bigint,
  lessons_learned text,
  decided_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.bet_name,
    b.bet_category,
    b.capital_committed_rupees,
    b.actual_revenue_lift_rupees,
    (b.capital_committed_rupees - b.actual_revenue_lift_rupees)::bigint,
    b.lessons_learned,
    b.decided_at
  FROM public.founder_strategic_bets_r2349 b
  WHERE b.status IN ('lost','killed')
  ORDER BY (b.capital_committed_rupees - b.actual_revenue_lift_rupees) DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_strategic_bets_r2349_top_losses() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_strategic_bets_r2349_top_losses() TO authenticated;

-- ============================================================================
-- RPC 6: milestones at risk
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_strategic_bets_r2349_milestones_at_risk()
RETURNS TABLE (
  milestone_id uuid,
  bet_id uuid,
  bet_name text,
  bet_category text,
  milestone_label text,
  target_date date,
  days_overdue integer,
  metric_target_value numeric,
  metric_actual_value numeric,
  metric_unit text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    m.id,
    b.id,
    b.bet_name,
    b.bet_category,
    m.milestone_label,
    m.target_date,
    (CURRENT_DATE - m.target_date)::integer,
    m.metric_target_value,
    m.metric_actual_value,
    m.metric_unit
  FROM public.founder_strategic_bet_milestones_r2349 m
  JOIN public.founder_strategic_bets_r2349 b ON b.id = m.bet_id
  WHERE m.status IN ('pending','slipped')
    AND m.target_date <= CURRENT_DATE + INTERVAL '14 days'
    AND b.status IN ('placed','in_flight')
  ORDER BY m.target_date ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_strategic_bets_r2349_milestones_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_strategic_bets_r2349_milestones_at_risk() TO authenticated;

-- ============================================================================
-- RPC 7: growth attribution
-- ============================================================================
CREATE OR REPLACE FUNCTION public.founder_strategic_bets_r2349_growth_attribution()
RETURNS TABLE (
  bet_category text,
  total_attribution_pct bigint,
  total_revenue_attributed_rupees bigint,
  bet_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    b.bet_category,
    COALESCE(SUM(b.growth_attribution_pct), 0)::bigint,
    COALESCE(SUM(b.actual_revenue_lift_rupees), 0)::bigint,
    COUNT(*)::bigint
  FROM public.founder_strategic_bets_r2349 b
  WHERE b.status IN ('won','partial')
  GROUP BY b.bet_category
  ORDER BY SUM(b.actual_revenue_lift_rupees) DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_strategic_bets_r2349_growth_attribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_strategic_bets_r2349_growth_attribution() TO authenticated;

COMMIT;
