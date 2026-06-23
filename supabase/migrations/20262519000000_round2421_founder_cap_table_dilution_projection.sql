-- Round 2421: Founder Cap Table Dilution Projection
-- 2 tables + 7 RPCs

BEGIN;

-- Table 1: cap_table_scenarios_r2421
CREATE TABLE IF NOT EXISTS public.cap_table_scenarios_r2421 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_name text NOT NULL,
  scenario_kind text NOT NULL CHECK (scenario_kind IN ('seed','series_a','series_b','bridge','safe')),
  pre_money_rupees bigint NOT NULL CHECK (pre_money_rupees >= 0),
  raise_amount_rupees bigint NOT NULL CHECK (raise_amount_rupees >= 0),
  post_money_rupees bigint NOT NULL CHECK (post_money_rupees >= 0),
  founder_pre_pct numeric(6,3) NOT NULL CHECK (founder_pre_pct >= 0 AND founder_pre_pct <= 100),
  founder_post_pct numeric(6,3) NOT NULL CHECK (founder_post_pct >= 0 AND founder_post_pct <= 100),
  esop_refresh_pct numeric(6,3) NOT NULL DEFAULT 0 CHECK (esop_refresh_pct >= 0 AND esop_refresh_pct <= 100),
  employee_dilution_pct numeric(6,3) NOT NULL DEFAULT 0 CHECK (employee_dilution_pct >= 0 AND employee_dilution_pct <= 100),
  lead_investor text,
  term_sheet_status text NOT NULL DEFAULT 'draft' CHECK (term_sheet_status IN ('draft','discussing','signed','dropped')),
  expected_close_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cap_table_scenarios_r2421 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.cap_table_scenarios_r2421;
CREATE POLICY founder_all ON public.cap_table_scenarios_r2421
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: esop_employee_impact_r2421
CREATE TABLE IF NOT EXISTS public.esop_employee_impact_r2421 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id uuid NOT NULL REFERENCES public.cap_table_scenarios_r2421(id) ON DELETE CASCADE,
  employee_email text NOT NULL,
  employee_name text NOT NULL,
  current_shares integer NOT NULL CHECK (current_shares >= 0),
  post_dilution_shares integer NOT NULL CHECK (post_dilution_shares >= 0),
  dilution_pct numeric(6,3) NOT NULL CHECK (dilution_pct >= 0 AND dilution_pct <= 100),
  retention_risk text NOT NULL CHECK (retention_risk IN ('low','medium','high')),
  retention_action text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.esop_employee_impact_r2421 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.esop_employee_impact_r2421;
CREATE POLICY founder_all ON public.esop_employee_impact_r2421
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed scenarios
INSERT INTO public.cap_table_scenarios_r2421
  (scenario_name, scenario_kind, pre_money_rupees, raise_amount_rupees, post_money_rupees,
   founder_pre_pct, founder_post_pct, esop_refresh_pct, employee_dilution_pct,
   lead_investor, term_sheet_status, expected_close_at, notes)
VALUES
  ('Seed Round 2026 Q3', 'seed', 400000000, 100000000, 500000000,
   80.000, 64.000, 5.000, 16.000, 'Blume Ventures', 'discussing', now() + interval '45 days',
   'Lead committed verbally; 20% dilution + 5% ESOP refresh'),
  ('Series A 2027 H1', 'series_a', 2000000000, 500000000, 2500000000,
   64.000, 51.200, 7.000, 12.800, 'Accel India', 'draft', now() + interval '180 days',
   '20% dilution + 7% ESOP top-up to 15% pool'),
  ('Bridge Note 2026 Q4', 'bridge', 600000000, 50000000, 650000000,
   80.000, 73.846, 0.000, 6.154, 'Existing angels', 'signed', now() + interval '20 days',
   'Convertible at Series A 20% discount; no ESOP refresh'),
  ('SAFE Cap 100Cr', 'safe', 1000000000, 75000000, 1075000000,
   80.000, 74.419, 0.000, 5.581, 'Sequoia Surge', 'draft', now() + interval '60 days',
   'SAFE with 100Cr post-money cap; converts at Series A'),
  ('Series B Conservative', 'series_b', 8000000000, 2000000000, 10000000000,
   51.200, 40.960, 10.000, 10.240, 'Tiger Global', 'draft', now() + interval '450 days',
   'Aggressive ESOP refresh to 20% pool; founder protective provisions');

-- Seed employee impact rows for first scenario
INSERT INTO public.esop_employee_impact_r2421
  (scenario_id, employee_email, employee_name, current_shares, post_dilution_shares,
   dilution_pct, retention_risk, retention_action, notes)
SELECT s.id, 'cto@equipseva.in', 'Ravi Kumar (CTO)', 50000, 40000, 20.000, 'high',
       'Top-up grant + accelerated vesting', 'Critical hire; refresh needed pre-close'
FROM public.cap_table_scenarios_r2421 s WHERE s.scenario_name = 'Seed Round 2026 Q3'
UNION ALL
SELECT s.id, 'vp.eng@equipseva.in', 'Priya Menon (VP Eng)', 30000, 24000, 20.000, 'medium',
       'Refresh grant on Series A', 'Solid retention so far'
FROM public.cap_table_scenarios_r2421 s WHERE s.scenario_name = 'Seed Round 2026 Q3'
UNION ALL
SELECT s.id, 'head.sales@equipseva.in', 'Arjun Reddy (Head Sales)', 20000, 16000, 20.000, 'low',
       'No action required', 'Recent hire; long vest runway'
FROM public.cap_table_scenarios_r2421 s WHERE s.scenario_name = 'Seed Round 2026 Q3'
UNION ALL
SELECT s.id, 'senior.eng1@equipseva.in', 'Sneha Iyer (Sr Eng)', 8000, 6400, 20.000, 'medium',
       'Performance refresh grant', 'Strong contributor; flight risk if no refresh'
FROM public.cap_table_scenarios_r2421 s WHERE s.scenario_name = 'Series A 2027 H1';

-- RPC 1: list_scenarios_r2421
CREATE OR REPLACE FUNCTION public.list_scenarios_r2421()
RETURNS TABLE (
  id uuid,
  scenario_name text,
  scenario_kind text,
  pre_money_rupees bigint,
  raise_amount_rupees bigint,
  post_money_rupees bigint,
  founder_pre_pct numeric,
  founder_post_pct numeric,
  esop_refresh_pct numeric,
  employee_dilution_pct numeric,
  lead_investor text,
  term_sheet_status text,
  expected_close_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.scenario_name, s.scenario_kind, s.pre_money_rupees, s.raise_amount_rupees,
           s.post_money_rupees, s.founder_pre_pct, s.founder_post_pct, s.esop_refresh_pct,
           s.employee_dilution_pct, s.lead_investor, s.term_sheet_status,
           s.expected_close_at, s.notes, s.created_at
    FROM public.cap_table_scenarios_r2421 s
    ORDER BY s.expected_close_at NULLS LAST, s.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_scenarios_r2421() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_scenarios_r2421() TO authenticated;

-- RPC 2: list_employee_impact_r2421
CREATE OR REPLACE FUNCTION public.list_employee_impact_r2421()
RETURNS TABLE (
  id uuid,
  scenario_id uuid,
  scenario_name text,
  scenario_kind text,
  employee_email text,
  employee_name text,
  current_shares integer,
  post_dilution_shares integer,
  dilution_pct numeric,
  retention_risk text,
  retention_action text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, e.scenario_id, s.scenario_name, s.scenario_kind,
           e.employee_email, e.employee_name, e.current_shares, e.post_dilution_shares,
           e.dilution_pct, e.retention_risk, e.retention_action, e.notes, e.created_at
    FROM public.esop_employee_impact_r2421 e
    JOIN public.cap_table_scenarios_r2421 s ON s.id = e.scenario_id
    ORDER BY e.dilution_pct DESC, e.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_employee_impact_r2421() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_employee_impact_r2421() TO authenticated;

-- RPC 3: top_diluted_employees_r2421
CREATE OR REPLACE FUNCTION public.top_diluted_employees_r2421()
RETURNS TABLE (
  employee_name text,
  employee_email text,
  scenario_name text,
  dilution_pct numeric,
  shares_lost integer,
  retention_risk text,
  retention_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.employee_name, e.employee_email, s.scenario_name, e.dilution_pct,
           (e.current_shares - e.post_dilution_shares)::integer AS shares_lost,
           e.retention_risk, e.retention_action
    FROM public.esop_employee_impact_r2421 e
    JOIN public.cap_table_scenarios_r2421 s ON s.id = e.scenario_id
    ORDER BY e.dilution_pct DESC, (e.current_shares - e.post_dilution_shares) DESC
    LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_diluted_employees_r2421() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_diluted_employees_r2421() TO authenticated;

-- RPC 4: scenario_compare_r2421
CREATE OR REPLACE FUNCTION public.scenario_compare_r2421()
RETURNS TABLE (
  scenario_name text,
  scenario_kind text,
  raise_amount_crores numeric,
  post_money_crores numeric,
  dilution_pct numeric,
  founder_post_pct numeric,
  esop_refresh_pct numeric,
  term_sheet_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.scenario_name, s.scenario_kind,
           ROUND(s.raise_amount_rupees::numeric / 10000000, 2) AS raise_amount_crores,
           ROUND(s.post_money_rupees::numeric / 10000000, 2) AS post_money_crores,
           ROUND((s.founder_pre_pct - s.founder_post_pct)::numeric, 3) AS dilution_pct,
           s.founder_post_pct, s.esop_refresh_pct, s.term_sheet_status
    FROM public.cap_table_scenarios_r2421 s
    ORDER BY s.post_money_rupees ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.scenario_compare_r2421() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.scenario_compare_r2421() TO authenticated;

-- RPC 5: retention_risk_summary_r2421
CREATE OR REPLACE FUNCTION public.retention_risk_summary_r2421()
RETURNS TABLE (
  retention_risk text,
  employee_count bigint,
  avg_dilution_pct numeric,
  total_shares_lost bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.retention_risk,
           COUNT(*)::bigint AS employee_count,
           ROUND(AVG(e.dilution_pct)::numeric, 3) AS avg_dilution_pct,
           COALESCE(SUM(e.current_shares - e.post_dilution_shares), 0)::bigint AS total_shares_lost
    FROM public.esop_employee_impact_r2421 e
    GROUP BY e.retention_risk
    ORDER BY CASE e.retention_risk WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.retention_risk_summary_r2421() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.retention_risk_summary_r2421() TO authenticated;

-- RPC 6: founder_ownership_trajectory_r2421
CREATE OR REPLACE FUNCTION public.founder_ownership_trajectory_r2421()
RETURNS TABLE (
  scenario_name text,
  scenario_kind text,
  expected_close_at timestamptz,
  founder_pre_pct numeric,
  founder_post_pct numeric,
  delta_pct numeric,
  term_sheet_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.scenario_name, s.scenario_kind, s.expected_close_at,
           s.founder_pre_pct, s.founder_post_pct,
           ROUND((s.founder_post_pct - s.founder_pre_pct)::numeric, 3) AS delta_pct,
           s.term_sheet_status
    FROM public.cap_table_scenarios_r2421 s
    ORDER BY s.expected_close_at NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_ownership_trajectory_r2421() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_ownership_trajectory_r2421() TO authenticated;

-- RPC 7: esop_refresh_summary_r2421
CREATE OR REPLACE FUNCTION public.esop_refresh_summary_r2421()
RETURNS TABLE (
  scenario_kind text,
  scenario_count bigint,
  avg_refresh_pct numeric,
  total_raise_crores numeric,
  avg_employee_dilution_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.scenario_kind,
           COUNT(*)::bigint AS scenario_count,
           ROUND(AVG(s.esop_refresh_pct)::numeric, 3) AS avg_refresh_pct,
           ROUND((SUM(s.raise_amount_rupees)::numeric / 10000000), 2) AS total_raise_crores,
           ROUND(AVG(s.employee_dilution_pct)::numeric, 3) AS avg_employee_dilution_pct
    FROM public.cap_table_scenarios_r2421 s
    GROUP BY s.scenario_kind
    ORDER BY s.scenario_kind;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.esop_refresh_summary_r2421() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.esop_refresh_summary_r2421() TO authenticated;

