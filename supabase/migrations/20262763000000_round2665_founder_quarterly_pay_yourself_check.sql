-- Round 2665: Founder Quarterly Pay Yourself Check
-- Track founder salary vs market benchmark and equity-aware decisions per quarter.

BEGIN;

-- =========================================================================
-- TABLE 1: founder_pay_yourself_r2665
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.founder_pay_yourself_r2665 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  salary_drawn_rupees bigint NOT NULL DEFAULT 0,
  market_benchmark_rupees bigint NOT NULL DEFAULT 0,
  sweat_equity_value_rupees bigint NOT NULL DEFAULT 0,
  comfort_score int NOT NULL DEFAULT 5 CHECK (comfort_score BETWEEN 0 AND 10),
  owner_email text,
  status text NOT NULL DEFAULT 'market' CHECK (status IN ('below_market','market','above_market','owner_choice')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpy_r2665_quarter ON public.founder_pay_yourself_r2665(quarter_label);
CREATE INDEX IF NOT EXISTS idx_fpy_r2665_status ON public.founder_pay_yourself_r2665(status);
CREATE INDEX IF NOT EXISTS idx_fpy_r2665_comfort ON public.founder_pay_yourself_r2665(comfort_score);

ALTER TABLE public.founder_pay_yourself_r2665 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.founder_pay_yourself_r2665;
CREATE POLICY founder_all ON public.founder_pay_yourself_r2665
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- TABLE 2: pay_yourself_decisions_r2665
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.pay_yourself_decisions_r2665 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  check_id uuid NOT NULL REFERENCES public.founder_pay_yourself_r2665(id) ON DELETE CASCADE,
  decided_at timestamptz NOT NULL DEFAULT now(),
  decision_kind text NOT NULL CHECK (decision_kind IN ('raise','cut','maintain','equity_swap','deferred')),
  summary_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pyd_r2665_check ON public.pay_yourself_decisions_r2665(check_id);
CREATE INDEX IF NOT EXISTS idx_pyd_r2665_status ON public.pay_yourself_decisions_r2665(status);
CREATE INDEX IF NOT EXISTS idx_pyd_r2665_decided_at ON public.pay_yourself_decisions_r2665(decided_at);

ALTER TABLE public.pay_yourself_decisions_r2665 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.pay_yourself_decisions_r2665;
CREATE POLICY founder_all ON public.pay_yourself_decisions_r2665
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- SEED DATA
-- =========================================================================
INSERT INTO public.founder_pay_yourself_r2665
  (quarter_label, salary_drawn_rupees, market_benchmark_rupees, sweat_equity_value_rupees, comfort_score, owner_email, status, notes)
VALUES
  ('Q1 FY27', 600000, 1800000, 12000000, 4, 'founder@equipseva.in', 'below_market', 'Drew minimum to extend runway by 6 months'),
  ('Q4 FY26', 750000, 1800000, 9500000, 5, 'founder@equipseva.in', 'below_market', 'Bumped salary post Series A close'),
  ('Q3 FY26', 450000, 1700000, 7800000, 3, 'founder@equipseva.in', 'below_market', 'Pre Series A cash crunch'),
  ('Q2 FY26', 300000, 1600000, 6200000, 2, 'founder@equipseva.in', 'below_market', 'Bootstrapping phase'),
  ('Q1 FY26', 2200000, 1500000, 5000000, 8, 'founder@equipseva.in', 'above_market', 'One-time bonus post seed round close');

INSERT INTO public.pay_yourself_decisions_r2665
  (check_id, decided_at, decision_kind, summary_md, owner_email, status, notes)
SELECT id, now() - interval '20 days', 'maintain', 'Hold salary at 6L for Q2; revisit at next board meet', 'founder@equipseva.in', 'planned', 'Comfort still low but runway priority'
FROM public.founder_pay_yourself_r2665 WHERE quarter_label = 'Q1 FY27' LIMIT 1;

INSERT INTO public.pay_yourself_decisions_r2665
  (check_id, decided_at, decision_kind, summary_md, owner_email, status, notes)
SELECT id, now() - interval '90 days', 'raise', 'Raised salary from 4.5L to 7.5L post Series A', 'founder@equipseva.in', 'done', 'Approved by board unanimously'
FROM public.founder_pay_yourself_r2665 WHERE quarter_label = 'Q4 FY26' LIMIT 1;

INSERT INTO public.pay_yourself_decisions_r2665
  (check_id, decided_at, decision_kind, summary_md, owner_email, status, notes)
SELECT id, now() - interval '180 days', 'equity_swap', 'Took ESOP refresh in lieu of cash bump', 'founder@equipseva.in', 'done', 'Net new 2.5pc grant vested over 4y'
FROM public.founder_pay_yourself_r2665 WHERE quarter_label = 'Q3 FY26' LIMIT 1;

INSERT INTO public.pay_yourself_decisions_r2665
  (check_id, decided_at, decision_kind, summary_md, owner_email, status, notes)
SELECT id, now() - interval '270 days', 'deferred', 'Salary deferred 3 months to fund engineer payouts', 'founder@equipseva.in', 'done', 'Recovered in following quarter'
FROM public.founder_pay_yourself_r2665 WHERE quarter_label = 'Q2 FY26' LIMIT 1;

INSERT INTO public.pay_yourself_decisions_r2665
  (check_id, decided_at, decision_kind, summary_md, owner_email, status, notes)
SELECT id, now() - interval '360 days', 'cut', 'Reverted bonus back into company bank account', 'founder@equipseva.in', 'done', 'Self-imposed correction after audit'
FROM public.founder_pay_yourself_r2665 WHERE quarter_label = 'Q1 FY26' LIMIT 1;

-- =========================================================================
-- RPC 1: list_pay_check_r2665
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_pay_check_r2665();
CREATE FUNCTION public.list_pay_check_r2665()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  salary_drawn_rupees bigint,
  market_benchmark_rupees bigint,
  sweat_equity_value_rupees bigint,
  comfort_score int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.quarter_label, f.salary_drawn_rupees, f.market_benchmark_rupees,
         f.sweat_equity_value_rupees, f.comfort_score, f.owner_email, f.status, f.notes, f.created_at
  FROM public.founder_pay_yourself_r2665 f
  ORDER BY f.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_pay_check_r2665() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pay_check_r2665() TO authenticated;

-- =========================================================================
-- RPC 2: list_decisions_r2665
-- =========================================================================
DROP FUNCTION IF EXISTS public.list_decisions_r2665();
CREATE FUNCTION public.list_decisions_r2665()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  decided_at timestamptz,
  decision_kind text,
  summary_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, f.quarter_label, d.decided_at, d.decision_kind, d.summary_md,
         d.owner_email, d.status, d.notes
  FROM public.pay_yourself_decisions_r2665 d
  JOIN public.founder_pay_yourself_r2665 f ON f.id = d.check_id
  ORDER BY d.decided_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_decisions_r2665() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_decisions_r2665() TO authenticated;

-- =========================================================================
-- RPC 3: top_comfort_focus_r2665
-- =========================================================================
DROP FUNCTION IF EXISTS public.top_comfort_focus_r2665();
CREATE FUNCTION public.top_comfort_focus_r2665()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  salary_drawn_rupees bigint,
  market_benchmark_rupees bigint,
  comfort_score int,
  status text,
  owner_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.quarter_label, f.salary_drawn_rupees, f.market_benchmark_rupees,
         f.comfort_score, f.status, f.owner_email
  FROM public.founder_pay_yourself_r2665 f
  WHERE f.comfort_score <= 5
  ORDER BY f.comfort_score ASC, f.created_at DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_comfort_focus_r2665() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_comfort_focus_r2665() TO authenticated;

-- =========================================================================
-- RPC 4: status_distribution_r2665
-- =========================================================================
DROP FUNCTION IF EXISTS public.status_distribution_r2665();
CREATE FUNCTION public.status_distribution_r2665()
RETURNS TABLE (
  status text,
  check_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.status, count(*)::bigint
  FROM public.founder_pay_yourself_r2665 f
  GROUP BY f.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_distribution_r2665() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_distribution_r2665() TO authenticated;

-- =========================================================================
-- RPC 5: status_funnel_r2665
-- =========================================================================
DROP FUNCTION IF EXISTS public.status_funnel_r2665();
CREATE FUNCTION public.status_funnel_r2665()
RETURNS TABLE (
  status text,
  decision_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.status, count(*)::bigint
  FROM public.pay_yourself_decisions_r2665 d
  GROUP BY d.status
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2665() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2665() TO authenticated;

-- =========================================================================
-- RPC 6: quarterly_pay_trend_r2665
-- =========================================================================
DROP FUNCTION IF EXISTS public.quarterly_pay_trend_r2665();
CREATE FUNCTION public.quarterly_pay_trend_r2665()
RETURNS TABLE (
  quarter_label text,
  total_checks bigint,
  avg_salary_rupees bigint,
  avg_benchmark_rupees bigint,
  avg_comfort numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.quarter_label,
         count(*)::bigint,
         coalesce(avg(f.salary_drawn_rupees), 0)::bigint,
         coalesce(avg(f.market_benchmark_rupees), 0)::bigint,
         round(coalesce(avg(f.comfort_score), 0)::numeric, 2)
  FROM public.founder_pay_yourself_r2665 f
  GROUP BY f.quarter_label
  ORDER BY f.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.quarterly_pay_trend_r2665() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_pay_trend_r2665() TO authenticated;

-- =========================================================================
-- RPC 7: founder_pulse_summary_r2665
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_pulse_summary_r2665();
CREATE FUNCTION public.founder_pulse_summary_r2665()
RETURNS TABLE (
  total_checks bigint,
  below_market_checks bigint,
  above_market_checks bigint,
  avg_comfort numeric,
  total_decisions bigint,
  open_decisions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::bigint FROM public.founder_pay_yourself_r2665),
    (SELECT count(*)::bigint FROM public.founder_pay_yourself_r2665 WHERE status = 'below_market'),
    (SELECT count(*)::bigint FROM public.founder_pay_yourself_r2665 WHERE status = 'above_market'),
    (SELECT round(coalesce(avg(comfort_score), 0)::numeric, 2) FROM public.founder_pay_yourself_r2665),
    (SELECT count(*)::bigint FROM public.pay_yourself_decisions_r2665),
    (SELECT count(*)::bigint FROM public.pay_yourself_decisions_r2665 WHERE status = 'planned');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pulse_summary_r2665() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_pulse_summary_r2665() TO authenticated;

COMMIT;
