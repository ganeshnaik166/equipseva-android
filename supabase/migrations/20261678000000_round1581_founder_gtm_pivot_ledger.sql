BEGIN;

-- ============================================================================
-- r1581 — Founder GTM Pivot Ledger
-- Log every GTM pivot decision (channel switch, segment change, ICP refine);
-- track reason, expected impact, actual outcome at 30/60/90d, and ROI per pivot.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: founder_gtm_pivots — one row per pivot decision
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_gtm_pivots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pivot_code text NOT NULL UNIQUE,
  pivot_type text NOT NULL CHECK (pivot_type IN ('channel_switch','segment_change','icp_refine','pricing','messaging','geo','partnership')),
  title text NOT NULL,
  reason text NOT NULL,
  hypothesis text,
  from_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  to_state jsonb NOT NULL DEFAULT '{}'::jsonb,
  expected_impact_rupees bigint NOT NULL DEFAULT 0,
  expected_uplift_pct numeric(6,2) NOT NULL DEFAULT 0,
  cost_to_pivot_rupees bigint NOT NULL DEFAULT 0,
  decided_by_email text NOT NULL,
  decided_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','reversed','abandoned')),
  outcome_30d_rupees bigint,
  outcome_60d_rupees bigint,
  outcome_90d_rupees bigint,
  outcome_30d_at timestamptz,
  outcome_60d_at timestamptz,
  outcome_90d_at timestamptz,
  verdict text CHECK (verdict IN ('win','loss','mixed','too_early','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_gtm_pivots_decided_at ON public.founder_gtm_pivots(decided_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_gtm_pivots_type ON public.founder_gtm_pivots(pivot_type);
CREATE INDEX IF NOT EXISTS idx_founder_gtm_pivots_status ON public.founder_gtm_pivots(status);
CREATE INDEX IF NOT EXISTS idx_founder_gtm_pivots_verdict ON public.founder_gtm_pivots(verdict);

ALTER TABLE public.founder_gtm_pivots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_gtm_pivots_founder_only ON public.founder_gtm_pivots;
CREATE POLICY founder_gtm_pivots_founder_only ON public.founder_gtm_pivots
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- Table 2: founder_gtm_pivot_milestones — interim measurements between checkpoints
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_gtm_pivot_milestones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pivot_id uuid NOT NULL REFERENCES public.founder_gtm_pivots(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  metric_name text NOT NULL,
  metric_value_rupees bigint NOT NULL DEFAULT 0,
  metric_value_count integer NOT NULL DEFAULT 0,
  note text,
  recorded_by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_gtm_pivot_milestones_pivot ON public.founder_gtm_pivot_milestones(pivot_id, observed_at DESC);

ALTER TABLE public.founder_gtm_pivot_milestones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_gtm_pivot_milestones_founder_only ON public.founder_gtm_pivot_milestones;
CREATE POLICY founder_gtm_pivot_milestones_founder_only ON public.founder_gtm_pivot_milestones
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ===========================================================================
-- LOG HELPERS (VOLATILE SECDEF) — write into founder_action_log
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.log_founder_pivot_logged(p_pivot_id uuid, p_pivot_code text, p_pivot_type text, p_expected_rupees bigint)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'gtm_pivot_logged',
          jsonb_build_object('pivot_id', p_pivot_id, 'pivot_code', p_pivot_code, 'pivot_type', p_pivot_type, 'expected_rupees', p_expected_rupees));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_pivot_logged(uuid, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_pivot_logged(uuid, text, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_pivot_outcome_recorded(p_pivot_id uuid, p_window text, p_outcome_rupees bigint)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'gtm_pivot_outcome_recorded',
          jsonb_build_object('pivot_id', p_pivot_id, 'window', p_window, 'outcome_rupees', p_outcome_rupees));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_pivot_outcome_recorded(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_pivot_outcome_recorded(uuid, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_pivot_verdict_set(p_pivot_id uuid, p_verdict text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'gtm_pivot_verdict_set',
          jsonb_build_object('pivot_id', p_pivot_id, 'verdict', p_verdict));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_pivot_verdict_set(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_pivot_verdict_set(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_pivot_milestone_added(p_pivot_id uuid, p_metric_name text, p_value_rupees bigint)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'gtm_pivot_milestone_added',
          jsonb_build_object('pivot_id', p_pivot_id, 'metric', p_metric_name, 'value_rupees', p_value_rupees));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_pivot_milestone_added(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_pivot_milestone_added(uuid, text, bigint) TO authenticated;

-- ===========================================================================
-- READ RPCs (STABLE SECDEF)
-- ===========================================================================

-- 1) Headline KPI roll-up
CREATE OR REPLACE FUNCTION public.founder_gtm_pivot_kpis()
RETURNS TABLE(
  total_pivots bigint,
  active_pivots bigint,
  completed_pivots bigint,
  reversed_pivots bigint,
  abandoned_pivots bigint,
  win_count bigint,
  loss_count bigint,
  mixed_count bigint,
  pending_count bigint,
  total_expected_rupees bigint,
  total_outcome_90d_rupees bigint,
  total_cost_rupees bigint,
  net_roi_rupees bigint,
  avg_uplift_pct numeric,
  pivots_last_30d bigint,
  pivots_last_90d bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status='active')::bigint,
    COUNT(*) FILTER (WHERE status='completed')::bigint,
    COUNT(*) FILTER (WHERE status='reversed')::bigint,
    COUNT(*) FILTER (WHERE status='abandoned')::bigint,
    COUNT(*) FILTER (WHERE verdict='win')::bigint,
    COUNT(*) FILTER (WHERE verdict='loss')::bigint,
    COUNT(*) FILTER (WHERE verdict='mixed')::bigint,
    COUNT(*) FILTER (WHERE verdict='pending' OR verdict IS NULL)::bigint,
    COALESCE(SUM(expected_impact_rupees),0)::bigint,
    COALESCE(SUM(outcome_90d_rupees),0)::bigint,
    COALESCE(SUM(cost_to_pivot_rupees),0)::bigint,
    (COALESCE(SUM(outcome_90d_rupees),0) - COALESCE(SUM(cost_to_pivot_rupees),0))::bigint,
    COALESCE(AVG(expected_uplift_pct),0)::numeric,
    COUNT(*) FILTER (WHERE decided_at >= now() - interval '30 days')::bigint,
    COUNT(*) FILTER (WHERE decided_at >= now() - interval '90 days')::bigint
  FROM public.founder_gtm_pivots;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gtm_pivot_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gtm_pivot_kpis() TO authenticated;

-- 2) Recent pivots
CREATE OR REPLACE FUNCTION public.founder_gtm_pivot_recent(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  pivot_code text,
  pivot_type text,
  title text,
  reason text,
  status text,
  verdict text,
  decided_by_email text,
  decided_at timestamptz,
  expected_impact_rupees bigint,
  outcome_90d_rupees bigint,
  cost_to_pivot_rupees bigint,
  days_since_decision numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.pivot_code, p.pivot_type, p.title, p.reason, p.status, p.verdict,
         p.decided_by_email, p.decided_at,
         p.expected_impact_rupees, p.outcome_90d_rupees, p.cost_to_pivot_rupees,
         ROUND(EXTRACT(EPOCH FROM (now() - p.decided_at))/86400.0, 1)::numeric
  FROM public.founder_gtm_pivots p
  ORDER BY p.decided_at DESC
  LIMIT GREATEST(p_limit,1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gtm_pivot_recent(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gtm_pivot_recent(integer) TO authenticated;

-- 3) Roll-up by pivot type
CREATE OR REPLACE FUNCTION public.founder_gtm_pivot_by_type()
RETURNS TABLE(
  pivot_type text,
  pivot_count bigint,
  win_count bigint,
  loss_count bigint,
  total_expected_rupees bigint,
  total_outcome_90d_rupees bigint,
  total_cost_rupees bigint,
  net_roi_rupees bigint,
  avg_uplift_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.pivot_type,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE p.verdict='win')::bigint,
         COUNT(*) FILTER (WHERE p.verdict='loss')::bigint,
         COALESCE(SUM(p.expected_impact_rupees),0)::bigint,
         COALESCE(SUM(p.outcome_90d_rupees),0)::bigint,
         COALESCE(SUM(p.cost_to_pivot_rupees),0)::bigint,
         (COALESCE(SUM(p.outcome_90d_rupees),0) - COALESCE(SUM(p.cost_to_pivot_rupees),0))::bigint,
         COALESCE(AVG(p.expected_uplift_pct),0)::numeric
  FROM public.founder_gtm_pivots p
  GROUP BY p.pivot_type
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gtm_pivot_by_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gtm_pivot_by_type() TO authenticated;

-- 4) Top winners by net ROI
CREATE OR REPLACE FUNCTION public.founder_gtm_pivot_top_winners(p_limit integer DEFAULT 20)
RETURNS TABLE(
  id uuid,
  pivot_code text,
  pivot_type text,
  title text,
  decided_at timestamptz,
  expected_impact_rupees bigint,
  outcome_90d_rupees bigint,
  cost_to_pivot_rupees bigint,
  net_roi_rupees bigint,
  roi_multiple numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.pivot_code, p.pivot_type, p.title, p.decided_at,
         p.expected_impact_rupees,
         p.outcome_90d_rupees,
         p.cost_to_pivot_rupees,
         (COALESCE(p.outcome_90d_rupees,0) - COALESCE(p.cost_to_pivot_rupees,0))::bigint,
         CASE WHEN COALESCE(p.cost_to_pivot_rupees,0) > 0
              THEN ROUND(COALESCE(p.outcome_90d_rupees,0)::numeric / p.cost_to_pivot_rupees, 2)
              ELSE NULL END
  FROM public.founder_gtm_pivots p
  WHERE p.outcome_90d_rupees IS NOT NULL
  ORDER BY (COALESCE(p.outcome_90d_rupees,0) - COALESCE(p.cost_to_pivot_rupees,0)) DESC
  LIMIT GREATEST(p_limit,1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gtm_pivot_top_winners(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gtm_pivot_top_winners(integer) TO authenticated;

-- 5) Worst losers
CREATE OR REPLACE FUNCTION public.founder_gtm_pivot_worst_losers(p_limit integer DEFAULT 20)
RETURNS TABLE(
  id uuid,
  pivot_code text,
  pivot_type text,
  title text,
  decided_at timestamptz,
  expected_impact_rupees bigint,
  outcome_90d_rupees bigint,
  cost_to_pivot_rupees bigint,
  net_roi_rupees bigint,
  variance_vs_expected bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.pivot_code, p.pivot_type, p.title, p.decided_at,
         p.expected_impact_rupees,
         p.outcome_90d_rupees,
         p.cost_to_pivot_rupees,
         (COALESCE(p.outcome_90d_rupees,0) - COALESCE(p.cost_to_pivot_rupees,0))::bigint,
         (COALESCE(p.outcome_90d_rupees,0) - COALESCE(p.expected_impact_rupees,0))::bigint
  FROM public.founder_gtm_pivots p
  WHERE p.outcome_90d_rupees IS NOT NULL
  ORDER BY (COALESCE(p.outcome_90d_rupees,0) - COALESCE(p.cost_to_pivot_rupees,0)) ASC
  LIMIT GREATEST(p_limit,1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gtm_pivot_worst_losers(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gtm_pivot_worst_losers(integer) TO authenticated;

-- 6) Outcome window status — pivots awaiting 30/60/90d checkpoints
CREATE OR REPLACE FUNCTION public.founder_gtm_pivot_checkpoint_due()
RETURNS TABLE(
  id uuid,
  pivot_code text,
  title text,
  decided_at timestamptz,
  days_since numeric,
  next_checkpoint text,
  next_checkpoint_due_in_days numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.pivot_code, p.title, p.decided_at,
         ROUND(EXTRACT(EPOCH FROM (now() - p.decided_at))/86400.0, 1)::numeric AS days_since,
         CASE
           WHEN p.outcome_30d_rupees IS NULL THEN '30d'
           WHEN p.outcome_60d_rupees IS NULL THEN '60d'
           WHEN p.outcome_90d_rupees IS NULL THEN '90d'
           ELSE 'done'
         END,
         CASE
           WHEN p.outcome_30d_rupees IS NULL THEN ROUND(30 - EXTRACT(EPOCH FROM (now() - p.decided_at))/86400.0, 1)::numeric
           WHEN p.outcome_60d_rupees IS NULL THEN ROUND(60 - EXTRACT(EPOCH FROM (now() - p.decided_at))/86400.0, 1)::numeric
           WHEN p.outcome_90d_rupees IS NULL THEN ROUND(90 - EXTRACT(EPOCH FROM (now() - p.decided_at))/86400.0, 1)::numeric
           ELSE NULL
         END
  FROM public.founder_gtm_pivots p
  WHERE p.status='active'
  ORDER BY p.decided_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gtm_pivot_checkpoint_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gtm_pivot_checkpoint_due() TO authenticated;

-- 7) Recent milestones (interim measurements)
CREATE OR REPLACE FUNCTION public.founder_gtm_pivot_recent_milestones(p_limit integer DEFAULT 30)
RETURNS TABLE(
  milestone_id uuid,
  pivot_id uuid,
  pivot_code text,
  pivot_title text,
  observed_at timestamptz,
  metric_name text,
  metric_value_rupees bigint,
  metric_value_count integer,
  recorded_by_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.pivot_id, p.pivot_code, p.title,
         m.observed_at, m.metric_name,
         m.metric_value_rupees, m.metric_value_count,
         m.recorded_by_email
  FROM public.founder_gtm_pivot_milestones m
  JOIN public.founder_gtm_pivots p ON p.id = m.pivot_id
  ORDER BY m.observed_at DESC
  LIMIT GREATEST(p_limit,1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_gtm_pivot_recent_milestones(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_gtm_pivot_recent_milestones(integer) TO authenticated;

COMMIT;