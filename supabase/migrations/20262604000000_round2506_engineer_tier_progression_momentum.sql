-- Round 2506: Engineer Tier Progression Momentum
-- Track engineer tier progression velocity, stagnation risk, and promotion pipeline.

BEGIN;

-- ============================================================================
-- TABLE: engineer_tier_momentum_r2506
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_tier_momentum_r2506 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  current_tier text NOT NULL CHECK (current_tier IN ('t1','t2','t3','t4','t5')),
  days_at_tier int NOT NULL DEFAULT 0 CHECK (days_at_tier >= 0),
  points_to_next int NOT NULL DEFAULT 0 CHECK (points_to_next >= 0),
  points_this_month int NOT NULL DEFAULT 0 CHECK (points_this_month >= 0),
  momentum_kind text NOT NULL CHECK (momentum_kind IN ('accelerating','steady','decelerating','stagnant')),
  stagnation_risk text NOT NULL CHECK (stagnation_risk IN ('low','medium','high','critical')),
  top_blocker text,
  owner_email text,
  last_assessed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','coaching','promoting','at_risk')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_tier_momentum_r2506_eng ON public.engineer_tier_momentum_r2506(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_tier_momentum_r2506_tier ON public.engineer_tier_momentum_r2506(current_tier);
CREATE INDEX IF NOT EXISTS idx_eng_tier_momentum_r2506_risk ON public.engineer_tier_momentum_r2506(stagnation_risk);

ALTER TABLE public.engineer_tier_momentum_r2506 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_tier_momentum_r2506;
CREATE POLICY founder_all ON public.engineer_tier_momentum_r2506
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE: tier_promotion_pipeline_r2506
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.tier_promotion_pipeline_r2506 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  target_tier text NOT NULL CHECK (target_tier IN ('t1','t2','t3','t4','t5')),
  expected_promotion_at timestamptz,
  blockers_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','promoted','dropped')),
  promoted_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tier_promo_pipeline_r2506_eng ON public.tier_promotion_pipeline_r2506(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_tier_promo_pipeline_r2506_status ON public.tier_promotion_pipeline_r2506(status);
CREATE INDEX IF NOT EXISTS idx_tier_promo_pipeline_r2506_expected ON public.tier_promotion_pipeline_r2506(expected_promotion_at);

ALTER TABLE public.tier_promotion_pipeline_r2506 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.tier_promotion_pipeline_r2506;
CREATE POLICY founder_all ON public.tier_promotion_pipeline_r2506
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- SEEDS
-- ============================================================================
INSERT INTO public.engineer_tier_momentum_r2506
  (current_tier, days_at_tier, points_to_next, points_this_month, momentum_kind, stagnation_risk, top_blocker, owner_email, status, notes)
VALUES
  ('t2', 45, 120, 80, 'accelerating', 'low', 'needs 2 more critical-equipment jobs', 'ops@equipseva.com', 'promoting', 'on track for t3 in 30 days'),
  ('t1', 120, 200, 15, 'stagnant', 'critical', 'low job acceptance + missed SLAs', 'ops@equipseva.com', 'at_risk', 'consider PIP'),
  ('t3', 60, 90, 60, 'steady', 'medium', 'needs hospital-chain certification', 'ops@equipseva.com', 'coaching', 'enrolled in cert prep'),
  ('t4', 200, 250, 30, 'decelerating', 'high', 'plateau - no high-tier jobs in region', 'ops@equipseva.com', 'monitoring', 'consider regional reassign'),
  ('t2', 25, 150, 110, 'accelerating', 'low', 'none', 'ops@equipseva.com', 'promoting', 'rising star');

INSERT INTO public.tier_promotion_pipeline_r2506
  (target_tier, expected_promotion_at, blockers_md, owner_email, status, notes)
VALUES
  ('t3', (now() + interval '30 days')::timestamptz, '- 2 critical jobs\n- supervisor signoff', 'ops@equipseva.com', 'in_progress', 'high confidence'),
  ('t2', (now() + interval '14 days')::timestamptz, '- complete 3 AMC visits', 'ops@equipseva.com', 'planned', 'ready next sprint'),
  ('t4', (now() + interval '60 days')::timestamptz, '- chain cert pending\n- need 4 more chain jobs', 'ops@equipseva.com', 'in_progress', 'targeted Q3'),
  ('t3', (now() - interval '5 days')::timestamptz, NULL, 'ops@equipseva.com', 'promoted', 'successful promotion'),
  ('t5', NULL, '- dropped - performance plateau', 'ops@equipseva.com', 'dropped', 'review in 6 months');

-- ============================================================================
-- RPC: list_momentum_r2506
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_momentum_r2506();
CREATE OR REPLACE FUNCTION public.list_momentum_r2506()
RETURNS TABLE (
  id uuid,
  current_tier text,
  days_at_tier int,
  points_to_next int,
  points_this_month int,
  momentum_kind text,
  stagnation_risk text,
  top_blocker text,
  owner_email text,
  status text,
  last_assessed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.current_tier, m.days_at_tier, m.points_to_next, m.points_this_month,
           m.momentum_kind, m.stagnation_risk, m.top_blocker, m.owner_email, m.status, m.last_assessed_at
    FROM public.engineer_tier_momentum_r2506 m
    ORDER BY
      CASE m.stagnation_risk WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
      m.days_at_tier DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_momentum_r2506() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_momentum_r2506() TO authenticated;

-- ============================================================================
-- RPC: list_promotion_pipeline_r2506
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_promotion_pipeline_r2506();
CREATE OR REPLACE FUNCTION public.list_promotion_pipeline_r2506()
RETURNS TABLE (
  id uuid,
  target_tier text,
  expected_promotion_at timestamptz,
  blockers_md text,
  owner_email text,
  status text,
  promoted_at timestamptz,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.target_tier, p.expected_promotion_at, p.blockers_md, p.owner_email,
           p.status, p.promoted_at, p.notes
    FROM public.tier_promotion_pipeline_r2506 p
    ORDER BY
      CASE p.status WHEN 'in_progress' THEN 1 WHEN 'planned' THEN 2 WHEN 'promoted' THEN 3 ELSE 4 END,
      p.expected_promotion_at ASC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_promotion_pipeline_r2506() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_promotion_pipeline_r2506() TO authenticated;

-- ============================================================================
-- RPC: top_stagnant_engineers_r2506
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_stagnant_engineers_r2506();
CREATE OR REPLACE FUNCTION public.top_stagnant_engineers_r2506()
RETURNS TABLE (
  id uuid,
  current_tier text,
  days_at_tier int,
  stagnation_risk text,
  top_blocker text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.current_tier, m.days_at_tier, m.stagnation_risk, m.top_blocker, m.status
    FROM public.engineer_tier_momentum_r2506 m
    WHERE m.stagnation_risk IN ('high','critical') OR m.momentum_kind IN ('stagnant','decelerating')
    ORDER BY
      CASE m.stagnation_risk WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
      m.days_at_tier DESC
    LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_stagnant_engineers_r2506() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_stagnant_engineers_r2506() TO authenticated;

-- ============================================================================
-- RPC: momentum_distribution_r2506
-- ============================================================================
DROP FUNCTION IF EXISTS public.momentum_distribution_r2506();
CREATE OR REPLACE FUNCTION public.momentum_distribution_r2506()
RETURNS TABLE (
  momentum_kind text,
  engineer_count bigint,
  avg_days_at_tier numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.momentum_kind, COUNT(*)::bigint AS engineer_count, ROUND(AVG(m.days_at_tier)::numeric, 1) AS avg_days_at_tier
    FROM public.engineer_tier_momentum_r2506 m
    GROUP BY m.momentum_kind
    ORDER BY engineer_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.momentum_distribution_r2506() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.momentum_distribution_r2506() TO authenticated;

-- ============================================================================
-- RPC: expected_promotions_this_quarter_r2506
-- ============================================================================
DROP FUNCTION IF EXISTS public.expected_promotions_this_quarter_r2506();
CREATE OR REPLACE FUNCTION public.expected_promotions_this_quarter_r2506()
RETURNS TABLE (
  target_tier text,
  expected_count bigint,
  in_progress_count bigint,
  planned_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.target_tier,
           COUNT(*) FILTER (WHERE p.status IN ('planned','in_progress') AND p.expected_promotion_at >= date_trunc('quarter', now()) AND p.expected_promotion_at < date_trunc('quarter', now()) + interval '3 months')::bigint AS expected_count,
           COUNT(*) FILTER (WHERE p.status = 'in_progress')::bigint AS in_progress_count,
           COUNT(*) FILTER (WHERE p.status = 'planned')::bigint AS planned_count
    FROM public.tier_promotion_pipeline_r2506 p
    GROUP BY p.target_tier
    ORDER BY p.target_tier;
END $$;
REVOKE EXECUTE ON FUNCTION public.expected_promotions_this_quarter_r2506() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expected_promotions_this_quarter_r2506() TO authenticated;

-- ============================================================================
-- RPC: tier_distribution_r2506
-- ============================================================================
DROP FUNCTION IF EXISTS public.tier_distribution_r2506();
CREATE OR REPLACE FUNCTION public.tier_distribution_r2506()
RETURNS TABLE (
  current_tier text,
  engineer_count bigint,
  avg_points_this_month numeric,
  high_risk_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.current_tier,
           COUNT(*)::bigint AS engineer_count,
           ROUND(AVG(m.points_this_month)::numeric, 1) AS avg_points_this_month,
           COUNT(*) FILTER (WHERE m.stagnation_risk IN ('high','critical'))::bigint AS high_risk_count
    FROM public.engineer_tier_momentum_r2506 m
    GROUP BY m.current_tier
    ORDER BY m.current_tier;
END $$;
REVOKE EXECUTE ON FUNCTION public.tier_distribution_r2506() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tier_distribution_r2506() TO authenticated;

-- ============================================================================
-- RPC: weekly_promotion_trend_r2506
-- ============================================================================
DROP FUNCTION IF EXISTS public.weekly_promotion_trend_r2506();
CREATE OR REPLACE FUNCTION public.weekly_promotion_trend_r2506()
RETURNS TABLE (
  week_start timestamptz,
  promoted_count bigint,
  dropped_count bigint,
  net_progress bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('week', COALESCE(p.promoted_at, p.created_at))::timestamptz AS week_start,
           COUNT(*) FILTER (WHERE p.status = 'promoted')::bigint AS promoted_count,
           COUNT(*) FILTER (WHERE p.status = 'dropped')::bigint AS dropped_count,
           (COUNT(*) FILTER (WHERE p.status = 'promoted') - COUNT(*) FILTER (WHERE p.status = 'dropped'))::bigint AS net_progress
    FROM public.tier_promotion_pipeline_r2506 p
    GROUP BY week_start
    ORDER BY week_start DESC
    LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_promotion_trend_r2506() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_promotion_trend_r2506() TO authenticated;

