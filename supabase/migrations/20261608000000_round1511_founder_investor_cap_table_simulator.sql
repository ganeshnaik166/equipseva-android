BEGIN;

-- ============================================================================
-- r1511 — Founder Investor Cap-Table Simulator
-- Simulate next-round dilution (Series A/B at multiple valuations),
-- SAFE note conversion, ESOP refresh; founder-reviewable scenarios.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: cap_table_scenarios — header row for each simulation
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cap_table_scenarios_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_name text NOT NULL,
  round_type text NOT NULL CHECK (round_type IN ('series_a','series_b','bridge','safe_only')),
  pre_money_valuation_inr numeric(18,2) NOT NULL CHECK (pre_money_valuation_inr > 0),
  new_money_raised_inr numeric(18,2) NOT NULL CHECK (new_money_raised_inr >= 0),
  safe_principal_inr numeric(18,2) NOT NULL DEFAULT 0 CHECK (safe_principal_inr >= 0),
  safe_discount_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (safe_discount_pct >= 0 AND safe_discount_pct <= 100),
  safe_valuation_cap_inr numeric(18,2),
  esop_refresh_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (esop_refresh_pct >= 0 AND esop_refresh_pct <= 50),
  pre_round_shares_outstanding numeric(18,4) NOT NULL CHECK (pre_round_shares_outstanding > 0),
  founder_review_status text NOT NULL DEFAULT 'pending' CHECK (founder_review_status IN ('pending','approved','rejected','archived')),
  founder_notes text,
  reviewed_at timestamptz,
  created_by_user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cap_table_scenarios_v2_status_idx ON public.cap_table_scenarios_v2(founder_review_status, created_at DESC);
CREATE INDEX IF NOT EXISTS cap_table_scenarios_v2_round_idx ON public.cap_table_scenarios_v2(round_type, created_at DESC);

ALTER TABLE public.cap_table_scenarios_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cap_table_scenarios_v2_founder ON public.cap_table_scenarios_v2;
CREATE POLICY cap_table_scenarios_v2_founder ON public.cap_table_scenarios_v2
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- Table 2: cap_table_scenario_lines — per-stakeholder lines per scenario
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cap_table_scenario_lines_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id uuid NOT NULL REFERENCES public.cap_table_scenarios_v2(id) ON DELETE CASCADE,
  stakeholder_label text NOT NULL,
  stakeholder_class text NOT NULL CHECK (stakeholder_class IN ('founder','employee_esop','angel','safe_investor','new_lead','new_followon','reserved_esop')),
  pre_round_shares numeric(18,4) NOT NULL DEFAULT 0 CHECK (pre_round_shares >= 0),
  new_round_shares numeric(18,4) NOT NULL DEFAULT 0 CHECK (new_round_shares >= 0),
  pre_round_ownership_pct numeric(7,4) NOT NULL DEFAULT 0,
  post_round_ownership_pct numeric(7,4) NOT NULL DEFAULT 0,
  dilution_pct numeric(7,4) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS cap_table_scenario_lines_v2_scenario_idx ON public.cap_table_scenario_lines_v2(scenario_id, stakeholder_class);

ALTER TABLE public.cap_table_scenario_lines_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cap_table_scenario_lines_v2_founder ON public.cap_table_scenario_lines_v2;
CREATE POLICY cap_table_scenario_lines_v2_founder ON public.cap_table_scenario_lines_v2
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ===========================================================================
-- Logging helpers
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.log_founder_cap_table_scenario_create(p_scenario_id uuid, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'cap_table_scenario_create',
    jsonb_build_object('scenario_id', p_scenario_id, 'payload', p_payload));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cap_table_scenario_create(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cap_table_scenario_create(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_cap_table_scenario_review(p_scenario_id uuid, p_status text, p_notes text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'cap_table_scenario_review',
    jsonb_build_object('scenario_id', p_scenario_id, 'status', p_status, 'notes', p_notes));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cap_table_scenario_review(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cap_table_scenario_review(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_cap_table_scenario_archive(p_scenario_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'cap_table_scenario_archive',
    jsonb_build_object('scenario_id', p_scenario_id));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cap_table_scenario_archive(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cap_table_scenario_archive(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_cap_table_export(p_format text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()), 'cap_table_export',
    jsonb_build_object('format', p_format, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_cap_table_export(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_cap_table_export(text) TO authenticated;

-- ===========================================================================
-- Read RPCs (STABLE)
-- ===========================================================================

-- 1) List scenarios summary
CREATE OR REPLACE FUNCTION public.founder_cap_table_scenarios_list()
RETURNS TABLE (
  id uuid,
  scenario_name text,
  round_type text,
  pre_money_valuation_inr numeric,
  new_money_raised_inr numeric,
  post_money_inr numeric,
  new_investor_pct numeric,
  esop_refresh_pct numeric,
  founder_review_status text,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_name, s.round_type, s.pre_money_valuation_inr, s.new_money_raised_inr,
    (s.pre_money_valuation_inr + s.new_money_raised_inr) AS post_money_inr,
    CASE WHEN (s.pre_money_valuation_inr + s.new_money_raised_inr) > 0
      THEN (s.new_money_raised_inr / (s.pre_money_valuation_inr + s.new_money_raised_inr) * 100.0)
      ELSE 0 END AS new_investor_pct,
    s.esop_refresh_pct, s.founder_review_status, s.created_at
  FROM public.cap_table_scenarios_v2 s
  ORDER BY s.created_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_scenarios_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_scenarios_list() TO authenticated;

-- 2) Founder ownership trajectory across approved scenarios
CREATE OR REPLACE FUNCTION public.founder_cap_table_founder_trajectory()
RETURNS TABLE (
  scenario_id uuid,
  scenario_name text,
  round_type text,
  founder_pre_pct numeric,
  founder_post_pct numeric,
  founder_dilution_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_name, s.round_type,
    COALESCE(SUM(l.pre_round_ownership_pct) FILTER (WHERE l.stakeholder_class = 'founder'), 0),
    COALESCE(SUM(l.post_round_ownership_pct) FILTER (WHERE l.stakeholder_class = 'founder'), 0),
    COALESCE(SUM(l.dilution_pct) FILTER (WHERE l.stakeholder_class = 'founder'), 0)
  FROM public.cap_table_scenarios_v2 s
  LEFT JOIN public.cap_table_scenario_lines_v2 l ON l.scenario_id = s.id
  WHERE s.founder_review_status IN ('approved','pending')
  GROUP BY s.id, s.scenario_name, s.round_type, s.created_at
  ORDER BY s.created_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_founder_trajectory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_founder_trajectory() TO authenticated;

-- 3) SAFE conversion impact summary
CREATE OR REPLACE FUNCTION public.founder_cap_table_safe_impact()
RETURNS TABLE (
  scenario_id uuid,
  scenario_name text,
  safe_principal_inr numeric,
  safe_discount_pct numeric,
  safe_valuation_cap_inr numeric,
  effective_conversion_price numeric,
  safe_post_shares numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_name, s.safe_principal_inr, s.safe_discount_pct, s.safe_valuation_cap_inr,
    CASE
      WHEN s.pre_round_shares_outstanding > 0 AND s.pre_money_valuation_inr > 0 THEN
        LEAST(
          (s.pre_money_valuation_inr / s.pre_round_shares_outstanding) * (1 - s.safe_discount_pct/100.0),
          COALESCE(s.safe_valuation_cap_inr, s.pre_money_valuation_inr) / NULLIF(s.pre_round_shares_outstanding, 0)
        )
      ELSE 0 END,
    COALESCE(SUM(l.new_round_shares) FILTER (WHERE l.stakeholder_class = 'safe_investor'), 0)
  FROM public.cap_table_scenarios_v2 s
  LEFT JOIN public.cap_table_scenario_lines_v2 l ON l.scenario_id = s.id
  WHERE s.safe_principal_inr > 0
  GROUP BY s.id, s.scenario_name, s.safe_principal_inr, s.safe_discount_pct, s.safe_valuation_cap_inr, s.pre_money_valuation_inr, s.pre_round_shares_outstanding
  ORDER BY s.safe_principal_inr DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_safe_impact() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_safe_impact() TO authenticated;

-- 4) ESOP refresh sizing
CREATE OR REPLACE FUNCTION public.founder_cap_table_esop_refresh()
RETURNS TABLE (
  scenario_id uuid,
  scenario_name text,
  esop_refresh_pct numeric,
  esop_pre_pool_pct numeric,
  esop_post_pool_pct numeric,
  esop_new_shares numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.scenario_name, s.esop_refresh_pct,
    COALESCE(SUM(l.pre_round_ownership_pct) FILTER (WHERE l.stakeholder_class IN ('employee_esop','reserved_esop')), 0),
    COALESCE(SUM(l.post_round_ownership_pct) FILTER (WHERE l.stakeholder_class IN ('employee_esop','reserved_esop')), 0),
    COALESCE(SUM(l.new_round_shares) FILTER (WHERE l.stakeholder_class = 'reserved_esop'), 0)
  FROM public.cap_table_scenarios_v2 s
  LEFT JOIN public.cap_table_scenario_lines_v2 l ON l.scenario_id = s.id
  GROUP BY s.id, s.scenario_name, s.esop_refresh_pct, s.created_at
  ORDER BY s.created_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_esop_refresh() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_esop_refresh() TO authenticated;

-- 5) Valuation grid (compare scenarios)
CREATE OR REPLACE FUNCTION public.founder_cap_table_valuation_grid()
RETURNS TABLE (
  round_type text,
  scenario_count int,
  min_pre_money numeric,
  max_pre_money numeric,
  avg_pre_money numeric,
  avg_new_money numeric,
  avg_post_money numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.round_type, COUNT(*)::int,
    MIN(s.pre_money_valuation_inr), MAX(s.pre_money_valuation_inr), AVG(s.pre_money_valuation_inr),
    AVG(s.new_money_raised_inr), AVG(s.pre_money_valuation_inr + s.new_money_raised_inr)
  FROM public.cap_table_scenarios_v2 s
  WHERE s.founder_review_status <> 'archived'
  GROUP BY s.round_type
  ORDER BY s.round_type;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_valuation_grid() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_valuation_grid() TO authenticated;

-- 6) Scenario detail lines
CREATE OR REPLACE FUNCTION public.founder_cap_table_scenario_lines(p_scenario_id uuid)
RETURNS TABLE (
  id uuid,
  stakeholder_label text,
  stakeholder_class text,
  pre_round_shares numeric,
  new_round_shares numeric,
  pre_round_ownership_pct numeric,
  post_round_ownership_pct numeric,
  dilution_pct numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.stakeholder_label, l.stakeholder_class, l.pre_round_shares, l.new_round_shares,
    l.pre_round_ownership_pct, l.post_round_ownership_pct, l.dilution_pct
  FROM public.cap_table_scenario_lines_v2 l
  WHERE l.scenario_id = p_scenario_id
  ORDER BY l.post_round_ownership_pct DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_scenario_lines(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_scenario_lines(uuid) TO authenticated;

-- 7) Aggregate KPI snapshot
CREATE OR REPLACE FUNCTION public.founder_cap_table_kpi_snapshot()
RETURNS TABLE (
  total_scenarios int,
  pending_review_count int,
  approved_count int,
  rejected_count int,
  archived_count int,
  series_a_count int,
  series_b_count int,
  bridge_count int,
  safe_only_count int,
  avg_pre_money_inr numeric,
  max_pre_money_inr numeric,
  avg_new_money_inr numeric,
  total_safe_principal_inr numeric,
  avg_esop_refresh_pct numeric,
  latest_scenario_at timestamptz,
  scenarios_last_30d int
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE founder_review_status = 'pending')::int,
    COUNT(*) FILTER (WHERE founder_review_status = 'approved')::int,
    COUNT(*) FILTER (WHERE founder_review_status = 'rejected')::int,
    COUNT(*) FILTER (WHERE founder_review_status = 'archived')::int,
    COUNT(*) FILTER (WHERE round_type = 'series_a')::int,
    COUNT(*) FILTER (WHERE round_type = 'series_b')::int,
    COUNT(*) FILTER (WHERE round_type = 'bridge')::int,
    COUNT(*) FILTER (WHERE round_type = 'safe_only')::int,
    AVG(pre_money_valuation_inr),
    MAX(pre_money_valuation_inr),
    AVG(new_money_raised_inr),
    SUM(safe_principal_inr),
    AVG(esop_refresh_pct),
    MAX(created_at),
    COUNT(*) FILTER (WHERE created_at > now() - interval '30 days')::int
  FROM public.cap_table_scenarios_v2;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_cap_table_kpi_snapshot() TO authenticated;

COMMIT;