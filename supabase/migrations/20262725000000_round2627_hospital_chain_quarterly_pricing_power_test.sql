-- Round 2627: Hospital chain quarterly pricing power test
-- Tracks pricing-power test campaigns per chain per quarter and their outcomes.

BEGIN;

-- ============================================================================
-- TABLE 1: chain_pricing_power_tests_r2627
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.chain_pricing_power_tests_r2627 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  test_increase_pct numeric(6,2) NOT NULL DEFAULT 0,
  baseline_revenue_rupees bigint NOT NULL DEFAULT 0,
  actual_revenue_rupees bigint NOT NULL DEFAULT 0,
  churn_count int NOT NULL DEFAULT 0,
  retention_pct numeric(6,2) NOT NULL DEFAULT 100,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','active','completed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cppt_r2627_chain ON public.chain_pricing_power_tests_r2627(chain_name);
CREATE INDEX IF NOT EXISTS idx_cppt_r2627_quarter ON public.chain_pricing_power_tests_r2627(quarter_label);
CREATE INDEX IF NOT EXISTS idx_cppt_r2627_status ON public.chain_pricing_power_tests_r2627(status);

ALTER TABLE public.chain_pricing_power_tests_r2627 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_pricing_power_tests_r2627;
CREATE POLICY founder_all ON public.chain_pricing_power_tests_r2627
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: pricing_power_test_outcomes_r2627
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.pricing_power_test_outcomes_r2627 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id uuid NOT NULL REFERENCES public.chain_pricing_power_tests_r2627(id) ON DELETE CASCADE,
  outcome_at timestamptz NOT NULL DEFAULT now(),
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('net_positive','net_neutral','net_negative','dropped')),
  rationale_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ppto_r2627_test ON public.pricing_power_test_outcomes_r2627(test_id);
CREATE INDEX IF NOT EXISTS idx_ppto_r2627_kind ON public.pricing_power_test_outcomes_r2627(outcome_kind);
CREATE INDEX IF NOT EXISTS idx_ppto_r2627_status ON public.pricing_power_test_outcomes_r2627(status);

ALTER TABLE public.pricing_power_test_outcomes_r2627 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.pricing_power_test_outcomes_r2627;
CREATE POLICY founder_all ON public.pricing_power_test_outcomes_r2627
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_tests_r2627
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_tests_r2627()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter_label text,
  test_increase_pct numeric,
  baseline_revenue_rupees bigint,
  actual_revenue_rupees bigint,
  delta_rupees bigint,
  churn_count int,
  retention_pct numeric,
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
  SELECT t.id, t.chain_name, t.quarter_label, t.test_increase_pct,
         t.baseline_revenue_rupees, t.actual_revenue_rupees,
         (t.actual_revenue_rupees - t.baseline_revenue_rupees)::bigint AS delta_rupees,
         t.churn_count, t.retention_pct, t.owner_email, t.status, t.notes, t.created_at
  FROM public.chain_pricing_power_tests_r2627 t
  ORDER BY t.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_tests_r2627() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_tests_r2627() TO authenticated;

-- ============================================================================
-- RPC 2: list_outcomes_r2627
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_outcomes_r2627()
RETURNS TABLE (
  id uuid,
  test_id uuid,
  chain_name text,
  quarter_label text,
  outcome_at timestamptz,
  outcome_kind text,
  rationale_md text,
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
  SELECT o.id, o.test_id, t.chain_name, t.quarter_label,
         o.outcome_at, o.outcome_kind, o.rationale_md, o.owner_email,
         o.status, o.notes, o.created_at
  FROM public.pricing_power_test_outcomes_r2627 o
  JOIN public.chain_pricing_power_tests_r2627 t ON t.id = o.test_id
  ORDER BY o.outcome_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2627() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2627() TO authenticated;

-- ============================================================================
-- RPC 3: top_net_positive_focus_r2627
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_net_positive_focus_r2627()
RETURNS TABLE (
  chain_name text,
  net_positive_count bigint,
  total_delta_rupees bigint,
  avg_retention_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name,
         COUNT(*) FILTER (WHERE o.outcome_kind = 'net_positive') AS net_positive_count,
         COALESCE(SUM(t.actual_revenue_rupees - t.baseline_revenue_rupees), 0)::bigint AS total_delta_rupees,
         COALESCE(AVG(t.retention_pct), 0)::numeric AS avg_retention_pct
  FROM public.chain_pricing_power_tests_r2627 t
  LEFT JOIN public.pricing_power_test_outcomes_r2627 o ON o.test_id = t.id
  GROUP BY t.chain_name
  ORDER BY net_positive_count DESC, total_delta_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_net_positive_focus_r2627() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_net_positive_focus_r2627() TO authenticated;

-- ============================================================================
-- RPC 4: retention_summary_r2627
-- ============================================================================
CREATE OR REPLACE FUNCTION public.retention_summary_r2627()
RETURNS TABLE (
  status text,
  test_count bigint,
  total_churn int,
  avg_retention_pct numeric,
  avg_test_increase_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status,
         COUNT(*) AS test_count,
         COALESCE(SUM(t.churn_count), 0)::int AS total_churn,
         COALESCE(AVG(t.retention_pct), 0)::numeric AS avg_retention_pct,
         COALESCE(AVG(t.test_increase_pct), 0)::numeric AS avg_test_increase_pct
  FROM public.chain_pricing_power_tests_r2627 t
  GROUP BY t.status
  ORDER BY test_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.retention_summary_r2627() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retention_summary_r2627() TO authenticated;

-- ============================================================================
-- RPC 5: status_funnel_r2627
-- ============================================================================
CREATE OR REPLACE FUNCTION public.status_funnel_r2627()
RETURNS TABLE (
  bucket text,
  cnt bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status::text AS bucket, COUNT(*)::bigint AS cnt
  FROM public.chain_pricing_power_tests_r2627 t
  GROUP BY t.status
  UNION ALL
  SELECT 'outcome_' || o.outcome_kind::text, COUNT(*)::bigint
  FROM public.pricing_power_test_outcomes_r2627 o
  GROUP BY o.outcome_kind
  ORDER BY 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2627() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2627() TO authenticated;

-- ============================================================================
-- RPC 6: quarterly_test_trend_r2627
-- ============================================================================
CREATE OR REPLACE FUNCTION public.quarterly_test_trend_r2627()
RETURNS TABLE (
  quarter_label text,
  test_count bigint,
  total_baseline_rupees bigint,
  total_actual_rupees bigint,
  total_delta_rupees bigint,
  avg_retention_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.quarter_label,
         COUNT(*) AS test_count,
         COALESCE(SUM(t.baseline_revenue_rupees), 0)::bigint AS total_baseline_rupees,
         COALESCE(SUM(t.actual_revenue_rupees), 0)::bigint AS total_actual_rupees,
         COALESCE(SUM(t.actual_revenue_rupees - t.baseline_revenue_rupees), 0)::bigint AS total_delta_rupees,
         COALESCE(AVG(t.retention_pct), 0)::numeric AS avg_retention_pct
  FROM public.chain_pricing_power_tests_r2627 t
  GROUP BY t.quarter_label
  ORDER BY t.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_test_trend_r2627() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_test_trend_r2627() TO authenticated;

-- ============================================================================
-- RPC 7: owner_load_r2627
-- ============================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2627()
RETURNS TABLE (
  owner_email text,
  test_count bigint,
  outcome_count bigint,
  open_outcome_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH t AS (
    SELECT COALESCE(owner_email, 'unassigned') AS owner_email, COUNT(*)::bigint AS test_count
    FROM public.chain_pricing_power_tests_r2627
    GROUP BY COALESCE(owner_email, 'unassigned')
  ),
  o AS (
    SELECT COALESCE(owner_email, 'unassigned') AS owner_email,
           COUNT(*)::bigint AS outcome_count,
           COUNT(*) FILTER (WHERE status = 'open')::bigint AS open_outcome_count
    FROM public.pricing_power_test_outcomes_r2627
    GROUP BY COALESCE(owner_email, 'unassigned')
  )
  SELECT COALESCE(t.owner_email, o.owner_email) AS owner_email,
         COALESCE(t.test_count, 0)::bigint,
         COALESCE(o.outcome_count, 0)::bigint,
         COALESCE(o.open_outcome_count, 0)::bigint
  FROM t
  FULL OUTER JOIN o ON o.owner_email = t.owner_email
  ORDER BY COALESCE(t.test_count, 0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2627() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2627() TO authenticated;

-- ============================================================================
-- SEED DATA
-- ============================================================================
INSERT INTO public.chain_pricing_power_tests_r2627
  (chain_name, quarter_label, test_increase_pct, baseline_revenue_rupees, actual_revenue_rupees, churn_count, retention_pct, owner_email, status, notes)
VALUES
  ('Apollo South Multi-Site', 'Q1-2026', 7.50, 4200000, 4480000, 0, 100.00, 'founder@equipseva.com', 'completed', 'Bundled AMC + spare-part across 6 sites'),
  ('Yashoda Group', 'Q2-2026', 5.00, 2800000, 2920000, 1, 96.50, 'founder@equipseva.com', 'active', 'Annual contract uplift on 4 sites'),
  ('Kamineni Network', 'Q2-2026', 10.00, 1600000, 1520000, 2, 88.00, 'founder@equipseva.com', 'completed', 'Aggressive uplift backed off; partial dropoff'),
  ('Care Hospitals Tier-2', 'Q1-2026', 4.00, 3100000, 3210000, 0, 100.00, 'founder@equipseva.com', 'completed', 'Mild adjustment; full retention'),
  ('KIMS Suburban', 'Q3-2026', 8.00, 1900000, 0, 0, 100.00, 'founder@equipseva.com', 'planned', 'Pending board approval');

INSERT INTO public.pricing_power_test_outcomes_r2627 (test_id, outcome_at, outcome_kind, rationale_md, owner_email, status, notes)
SELECT t.id, (now() - interval '5 days')::timestamptz, 'net_positive', 'Revenue up 6.7 pct vs baseline; zero churn', 'founder@equipseva.com', 'done', 'Replicate playbook'
FROM public.chain_pricing_power_tests_r2627 t WHERE t.chain_name = 'Apollo South Multi-Site' LIMIT 1;

INSERT INTO public.pricing_power_test_outcomes_r2627 (test_id, outcome_at, outcome_kind, rationale_md, owner_email, status, notes)
SELECT t.id, (now() - interval '3 days')::timestamptz, 'net_negative', 'Two sites churned; net delta negative', 'founder@equipseva.com', 'done', 'Roll back to 4 pct'
FROM public.chain_pricing_power_tests_r2627 t WHERE t.chain_name = 'Kamineni Network' LIMIT 1;

INSERT INTO public.pricing_power_test_outcomes_r2627 (test_id, outcome_at, outcome_kind, rationale_md, owner_email, status, notes)
SELECT t.id, (now() - interval '2 days')::timestamptz, 'net_positive', 'Tier-2 absorbed uplift without resistance', 'founder@equipseva.com', 'done', 'Apply to Tier-2 segment broadly'
FROM public.chain_pricing_power_tests_r2627 t WHERE t.chain_name = 'Care Hospitals Tier-2' LIMIT 1;

INSERT INTO public.pricing_power_test_outcomes_r2627 (test_id, outcome_at, outcome_kind, rationale_md, owner_email, status, notes)
SELECT t.id, (now() - interval '1 day')::timestamptz, 'net_neutral', 'Tracking on plan; one minor pushback', 'founder@equipseva.com', 'open', 'Reassess at quarter end'
FROM public.chain_pricing_power_tests_r2627 t WHERE t.chain_name = 'Yashoda Group' LIMIT 1;

COMMIT;
