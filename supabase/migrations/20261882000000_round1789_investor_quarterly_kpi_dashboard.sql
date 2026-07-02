BEGIN;

-- ============================================================
-- Round 1789 — Investor Quarterly KPI Dashboard
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_quarterly_kpis_r1789 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_quarter text NOT NULL UNIQUE,
  revenue_rupees bigint NOT NULL DEFAULT 0,
  customer_count int NOT NULL DEFAULT 0,
  churn_rate_pct numeric(6,2) NOT NULL DEFAULT 0,
  nps_score int NOT NULL DEFAULT 0,
  headcount int NOT NULL DEFAULT 0,
  runway_months int NOT NULL DEFAULT 0,
  snapshot_taken_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_kpi_milestone_alerts_r1789 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_id uuid NOT NULL REFERENCES public.investor_quarterly_kpis_r1789(id) ON DELETE CASCADE,
  milestone text NOT NULL CHECK (milestone IN ('first_million_arr','ten_customers','break_even','profitability','twenty_employees')),
  achieved boolean NOT NULL DEFAULT false,
  achieved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (quarter_id, milestone)
);

ALTER TABLE public.investor_quarterly_kpis_r1789 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_kpi_milestone_alerts_r1789 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_kpis_r1789 ON public.investor_quarterly_kpis_r1789;
CREATE POLICY founder_all_kpis_r1789 ON public.investor_quarterly_kpis_r1789
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_milestones_r1789 ON public.investor_kpi_milestone_alerts_r1789;
CREATE POLICY founder_all_milestones_r1789 ON public.investor_kpi_milestone_alerts_r1789
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_kpis
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_investor_kpis_r1789()
RETURNS TABLE (
  id uuid,
  fiscal_quarter text,
  revenue_rupees bigint,
  customer_count int,
  churn_rate_pct numeric,
  nps_score int,
  headcount int,
  runway_months int,
  snapshot_taken_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.fiscal_quarter, k.revenue_rupees, k.customer_count,
         k.churn_rate_pct, k.nps_score, k.headcount, k.runway_months,
         k.snapshot_taken_at, k.status
  FROM public.investor_quarterly_kpis_r1789 k
  ORDER BY k.fiscal_quarter DESC
  LIMIT 50;
END;
$$;

-- ============================================================
-- RPC 2: take_snapshot
-- ============================================================
CREATE OR REPLACE FUNCTION public.take_investor_kpi_snapshot_r1789(
  p_fiscal_quarter text,
  p_revenue_rupees bigint,
  p_customer_count int,
  p_churn_rate_pct numeric,
  p_nps_score int,
  p_headcount int,
  p_runway_months int
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_quarterly_kpis_r1789 (
    fiscal_quarter, revenue_rupees, customer_count, churn_rate_pct,
    nps_score, headcount, runway_months
  ) VALUES (
    p_fiscal_quarter, p_revenue_rupees, p_customer_count, p_churn_rate_pct,
    p_nps_score, p_headcount, p_runway_months
  )
  ON CONFLICT (fiscal_quarter) DO UPDATE
    SET revenue_rupees = EXCLUDED.revenue_rupees,
        customer_count = EXCLUDED.customer_count,
        churn_rate_pct = EXCLUDED.churn_rate_pct,
        nps_score = EXCLUDED.nps_score,
        headcount = EXCLUDED.headcount,
        runway_months = EXCLUDED.runway_months,
        snapshot_taken_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'take_investor_kpi_snapshot_r1789',
          jsonb_build_object('id', v_id, 'fiscal_quarter', p_fiscal_quarter));

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 3: list_milestones
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_investor_kpi_milestones_r1789()
RETURNS TABLE (
  id uuid,
  quarter_id uuid,
  fiscal_quarter text,
  milestone text,
  achieved boolean,
  achieved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.quarter_id, k.fiscal_quarter, m.milestone, m.achieved, m.achieved_at
  FROM public.investor_kpi_milestone_alerts_r1789 m
  JOIN public.investor_quarterly_kpis_r1789 k ON k.id = m.quarter_id
  ORDER BY k.fiscal_quarter DESC, m.milestone
  LIMIT 200;
END;
$$;

-- ============================================================
-- RPC 4: mark_milestone_achieved
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_investor_kpi_milestone_r1789(
  p_quarter_id uuid,
  p_milestone text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_kpi_milestone_alerts_r1789 (quarter_id, milestone, achieved, achieved_at)
  VALUES (p_quarter_id, p_milestone, true, now())
  ON CONFLICT (quarter_id, milestone) DO UPDATE
    SET achieved = true,
        achieved_at = COALESCE(public.investor_kpi_milestone_alerts_r1789.achieved_at, now()),
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_investor_kpi_milestone_r1789',
          jsonb_build_object('quarter_id', p_quarter_id, 'milestone', p_milestone));

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: latest_quarterly_summary
-- ============================================================
CREATE OR REPLACE FUNCTION public.latest_investor_kpi_summary_r1789()
RETURNS TABLE (
  fiscal_quarter text,
  revenue_rupees bigint,
  customer_count int,
  churn_rate_pct numeric,
  nps_score int,
  headcount int,
  runway_months int,
  status text,
  snapshot_taken_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.fiscal_quarter, k.revenue_rupees, k.customer_count, k.churn_rate_pct,
         k.nps_score, k.headcount, k.runway_months, k.status, k.snapshot_taken_at
  FROM public.investor_quarterly_kpis_r1789 k
  ORDER BY k.fiscal_quarter DESC
  LIMIT 1;
END;
$$;

-- ============================================================
-- RPC 6: trend_comparison
-- ============================================================
CREATE OR REPLACE FUNCTION public.investor_kpi_trend_comparison_r1789()
RETURNS TABLE (
  fiscal_quarter text,
  revenue_rupees bigint,
  customer_count int,
  churn_rate_pct numeric,
  nps_score int,
  prev_revenue_rupees bigint,
  revenue_delta_rupees bigint,
  customer_delta int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ordered AS (
    SELECT k.fiscal_quarter, k.revenue_rupees, k.customer_count, k.churn_rate_pct, k.nps_score,
           LAG(k.revenue_rupees) OVER (ORDER BY k.fiscal_quarter) AS prev_rev,
           LAG(k.customer_count) OVER (ORDER BY k.fiscal_quarter) AS prev_cust
    FROM public.investor_quarterly_kpis_r1789 k
  )
  SELECT o.fiscal_quarter, o.revenue_rupees, o.customer_count, o.churn_rate_pct, o.nps_score,
         COALESCE(o.prev_rev, 0)::bigint AS prev_revenue_rupees,
         (o.revenue_rupees - COALESCE(o.prev_rev, 0))::bigint AS revenue_delta_rupees,
         (o.customer_count - COALESCE(o.prev_cust, 0))::int AS customer_delta
  FROM ordered o
  ORDER BY o.fiscal_quarter DESC
  LIMIT 20;
END;
$$;

-- ============================================================
-- RPC 7: milestone_summary
-- ============================================================
CREATE OR REPLACE FUNCTION public.investor_kpi_milestone_summary_r1789()
RETURNS TABLE (
  milestone text,
  total_count int,
  achieved_count int,
  first_achieved_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.milestone,
         (COUNT(*))::int AS total_count,
         (COUNT(*) FILTER (WHERE m.achieved))::int AS achieved_count,
         MIN(m.achieved_at) AS first_achieved_at
  FROM public.investor_kpi_milestone_alerts_r1789 m
  GROUP BY m.milestone
  ORDER BY m.milestone;
END;
$$;

-- ============================================================
-- REVOKE + GRANT
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.list_investor_kpis_r1789() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.take_investor_kpi_snapshot_r1789(text,bigint,int,numeric,int,int,int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_investor_kpi_milestones_r1789() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_investor_kpi_milestone_r1789(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.latest_investor_kpi_summary_r1789() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.investor_kpi_trend_comparison_r1789() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.investor_kpi_milestone_summary_r1789() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_investor_kpis_r1789() TO authenticated;
GRANT EXECUTE ON FUNCTION public.take_investor_kpi_snapshot_r1789(text,bigint,int,numeric,int,int,int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_investor_kpi_milestones_r1789() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_investor_kpi_milestone_r1789(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.latest_investor_kpi_summary_r1789() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_kpi_trend_comparison_r1789() TO authenticated;
GRANT EXECUTE ON FUNCTION public.investor_kpi_milestone_summary_r1789() TO authenticated;

COMMIT;