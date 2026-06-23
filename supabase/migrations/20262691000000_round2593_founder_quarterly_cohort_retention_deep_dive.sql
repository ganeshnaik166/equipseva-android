-- Round 2593: founder quarterly cohort retention deep dive
-- Tracks cohort retention by month, churn cause, recovery cost, LTV impact, plus recovery actions.

BEGIN;

-- ============================================================
-- Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS public.founder_cohort_retention_r2593 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  cohort_label text NOT NULL,
  period_month int NOT NULL CHECK (period_month BETWEEN 0 AND 36),
  retained_count int NOT NULL DEFAULT 0 CHECK (retained_count >= 0),
  churned_count int NOT NULL DEFAULT 0 CHECK (churned_count >= 0),
  retention_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (retention_pct >= 0 AND retention_pct <= 100),
  churn_cause_kind text NOT NULL CHECK (churn_cause_kind IN ('price','quality','competitor','internal_decision','other')),
  recovery_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (recovery_cost_rupees >= 0),
  ltv_impact_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','final','published')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.cohort_retention_recovery_actions_r2593 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  cohort_id uuid NOT NULL REFERENCES public.founder_cohort_retention_r2593(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('win_back','price_lock','feature_promise','exec_call','refund')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  recovered_arr_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE public.founder_cohort_retention_r2593 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cohort_retention_recovery_actions_r2593 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_cohort_retention_r2593;
CREATE POLICY founder_all ON public.founder_cohort_retention_r2593
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.cohort_retention_recovery_actions_r2593;
CREATE POLICY founder_all ON public.cohort_retention_recovery_actions_r2593
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Seeds
-- ============================================================

INSERT INTO public.founder_cohort_retention_r2593
  (id, cohort_label, period_month, retained_count, churned_count, retention_pct, churn_cause_kind, recovery_cost_rupees, ltv_impact_rupees, owner_email, status, notes)
VALUES
  ('aaaaaaa1-0000-0000-0000-000000000001', 'Q1-2025', 3, 48, 12, 80.00, 'price', 150000, -2400000, 'founder@equipseva.com', 'published', 'price-sensitive Tier-3 hospitals'),
  ('aaaaaaa1-0000-0000-0000-000000000002', 'Q1-2025', 6, 42, 18, 70.00, 'competitor', 220000, -3600000, 'founder@equipseva.com', 'published', 'lost 6 to local OEM'),
  ('aaaaaaa1-0000-0000-0000-000000000003', 'Q2-2025', 3, 55, 5, 91.67, 'quality', 80000, -900000, 'founder@equipseva.com', 'final', 'engineer rotation issue'),
  ('aaaaaaa1-0000-0000-0000-000000000004', 'Q3-2025', 3, 62, 8, 88.57, 'internal_decision', 95000, -1400000, 'founder@equipseva.com', 'final', 'chain switched in-house team'),
  ('aaaaaaa1-0000-0000-0000-000000000005', 'Q4-2025', 3, 70, 4, 94.59, 'other', 50000, -700000, 'founder@equipseva.com', 'draft', 'isolated cases')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cohort_retention_recovery_actions_r2593
  (cohort_id, action_at, action_kind, outcome, recovered_arr_rupees, owner_email, status, notes)
VALUES
  ('aaaaaaa1-0000-0000-0000-000000000001', now() - interval '180 days', 'price_lock', 'positive', 900000, 'founder@equipseva.com', 'done', '12mo price lock retained 4'),
  ('aaaaaaa1-0000-0000-0000-000000000001', now() - interval '150 days', 'refund', 'neutral', 0, 'founder@equipseva.com', 'done', 'goodwill refund 2 clients'),
  ('aaaaaaa1-0000-0000-0000-000000000002', now() - interval '120 days', 'win_back', 'negative', 0, 'founder@equipseva.com', 'done', 'OEM gave 30% discount'),
  ('aaaaaaa1-0000-0000-0000-000000000002', now() - interval '90 days', 'exec_call', 'positive', 600000, 'founder@equipseva.com', 'done', 'CEO call won 2 back'),
  ('aaaaaaa1-0000-0000-0000-000000000003', now() - interval '60 days', 'feature_promise', 'pending', 0, 'founder@equipseva.com', 'open', 'promised QA dashboard'),
  ('aaaaaaa1-0000-0000-0000-000000000004', now() - interval '30 days', 'exec_call', 'pending', 0, 'founder@equipseva.com', 'open', 'pitching co-managed model'),
  ('aaaaaaa1-0000-0000-0000-000000000005', now() - interval '10 days', 'win_back', 'pending', 0, 'founder@equipseva.com', 'open', 'reach out next week');

-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_cohort_retention_r2593()
RETURNS TABLE (
  id uuid,
  cohort_label text,
  period_month int,
  retained_count int,
  churned_count int,
  retention_pct numeric,
  churn_cause_kind text,
  recovery_cost_rupees bigint,
  ltv_impact_rupees bigint,
  owner_email text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.cohort_label, c.period_month, c.retained_count, c.churned_count,
         c.retention_pct, c.churn_cause_kind, c.recovery_cost_rupees, c.ltv_impact_rupees,
         c.owner_email, c.status, c.created_at
  FROM public.founder_cohort_retention_r2593 c
  ORDER BY c.cohort_label DESC NULLS LAST, c.period_month ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_cohort_retention_r2593() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cohort_retention_r2593() TO authenticated;


CREATE OR REPLACE FUNCTION public.list_recovery_actions_r2593()
RETURNS TABLE (
  id uuid,
  cohort_id uuid,
  cohort_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  recovered_arr_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.cohort_id, c.cohort_label, a.action_at, a.action_kind, a.outcome,
         a.recovered_arr_rupees, a.owner_email, a.status, a.notes
  FROM public.cohort_retention_recovery_actions_r2593 a
  LEFT JOIN public.founder_cohort_retention_r2593 c ON c.id = a.cohort_id
  ORDER BY a.action_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_actions_r2593() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_actions_r2593() TO authenticated;


CREATE OR REPLACE FUNCTION public.top_ltv_impact_cohorts_r2593()
RETURNS TABLE (
  cohort_label text,
  period_month int,
  ltv_impact_rupees bigint,
  churn_cause_kind text,
  retention_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.cohort_label, c.period_month, c.ltv_impact_rupees, c.churn_cause_kind, c.retention_pct
  FROM public.founder_cohort_retention_r2593 c
  ORDER BY c.ltv_impact_rupees ASC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_ltv_impact_cohorts_r2593() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_ltv_impact_cohorts_r2593() TO authenticated;


CREATE OR REPLACE FUNCTION public.churn_cause_distribution_r2593()
RETURNS TABLE (
  churn_cause_kind text,
  cohort_count bigint,
  total_churned bigint,
  total_ltv_impact bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.churn_cause_kind,
         count(*)::bigint AS cohort_count,
         COALESCE(sum(c.churned_count), 0)::bigint AS total_churned,
         COALESCE(sum(c.ltv_impact_rupees), 0)::bigint AS total_ltv_impact
  FROM public.founder_cohort_retention_r2593 c
  GROUP BY c.churn_cause_kind
  ORDER BY total_churned DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.churn_cause_distribution_r2593() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.churn_cause_distribution_r2593() TO authenticated;


CREATE OR REPLACE FUNCTION public.recovery_cost_summary_r2593()
RETURNS TABLE (
  cohort_label text,
  total_recovery_cost bigint,
  total_recovered_arr bigint,
  net_recovery bigint,
  action_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.cohort_label,
         COALESCE(sum(c.recovery_cost_rupees), 0)::bigint AS total_recovery_cost,
         COALESCE((SELECT sum(a.recovered_arr_rupees) FROM public.cohort_retention_recovery_actions_r2593 a WHERE a.cohort_id IN (SELECT c2.id FROM public.founder_cohort_retention_r2593 c2 WHERE c2.cohort_label = c.cohort_label)), 0)::bigint AS total_recovered_arr,
         (COALESCE((SELECT sum(a.recovered_arr_rupees) FROM public.cohort_retention_recovery_actions_r2593 a WHERE a.cohort_id IN (SELECT c2.id FROM public.founder_cohort_retention_r2593 c2 WHERE c2.cohort_label = c.cohort_label)), 0) - COALESCE(sum(c.recovery_cost_rupees), 0))::bigint AS net_recovery,
         (SELECT count(*) FROM public.cohort_retention_recovery_actions_r2593 a WHERE a.cohort_id IN (SELECT c2.id FROM public.founder_cohort_retention_r2593 c2 WHERE c2.cohort_label = c.cohort_label))::bigint AS action_count
  FROM public.founder_cohort_retention_r2593 c
  GROUP BY c.cohort_label
  ORDER BY c.cohort_label DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recovery_cost_summary_r2593() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recovery_cost_summary_r2593() TO authenticated;


CREATE OR REPLACE FUNCTION public.quarterly_retention_trend_r2593()
RETURNS TABLE (
  cohort_label text,
  period_month int,
  retention_pct numeric,
  retained_count int,
  churned_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.cohort_label, c.period_month, c.retention_pct, c.retained_count, c.churned_count
  FROM public.founder_cohort_retention_r2593 c
  ORDER BY c.cohort_label ASC NULLS LAST, c.period_month ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_retention_trend_r2593() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_retention_trend_r2593() TO authenticated;


CREATE OR REPLACE FUNCTION public.recovered_arr_summary_r2593()
RETURNS TABLE (
  action_kind text,
  action_count bigint,
  total_recovered_arr bigint,
  positive_outcomes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         count(*)::bigint AS action_count,
         COALESCE(sum(a.recovered_arr_rupees), 0)::bigint AS total_recovered_arr,
         count(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_outcomes
  FROM public.cohort_retention_recovery_actions_r2593 a
  GROUP BY a.action_kind
  ORDER BY total_recovered_arr DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recovered_arr_summary_r2593() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recovered_arr_summary_r2593() TO authenticated;

