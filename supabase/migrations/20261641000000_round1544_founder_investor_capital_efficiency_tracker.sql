BEGIN;

-- =========================================================================
-- r1544 — Founder Investor Capital Efficiency Tracker
-- Track CAC/LTV, payback period, revenue per rupee raised, burn multiple
-- per cohort + per investor; benchmark vs SaaS norms.
-- =========================================================================

-- 1) Capital raise rounds (rounds of funding)
CREATE TABLE IF NOT EXISTS founder_capital_raise_rounds_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_label text NOT NULL,
  raised_at date NOT NULL,
  amount_rupees bigint NOT NULL CHECK (amount_rupees >= 0),
  pre_money_valuation_rupees bigint,
  post_money_valuation_rupees bigint,
  investor_name text NOT NULL,
  investor_type text NOT NULL CHECK (investor_type IN ('angel','seed_fund','venture','strategic','founder','debt','grant')),
  cohort_label text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_capital_raise_rounds_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only capital raise rounds v2" ON founder_capital_raise_rounds_v2;
CREATE POLICY "founder only capital raise rounds v2" ON founder_capital_raise_rounds_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- 2) Monthly burn / revenue snapshots (for burn multiple)
CREATE TABLE IF NOT EXISTS founder_capital_efficiency_snapshots_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_month date NOT NULL UNIQUE,
  net_burn_rupees bigint NOT NULL DEFAULT 0,
  net_new_revenue_rupees bigint NOT NULL DEFAULT 0,
  total_revenue_rupees bigint NOT NULL DEFAULT 0,
  marketing_spend_rupees bigint NOT NULL DEFAULT 0,
  sales_spend_rupees bigint NOT NULL DEFAULT 0,
  new_customers integer NOT NULL DEFAULT 0,
  churned_customers integer NOT NULL DEFAULT 0,
  cash_balance_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_capital_efficiency_snapshots_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder only capital eff snapshots v2" ON founder_capital_efficiency_snapshots_v2;
CREATE POLICY "founder only capital eff snapshots v2" ON founder_capital_efficiency_snapshots_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- Log helpers (VOLATILE SECDEF, founder-gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_capital_raise_recorded(
  p_round_id uuid,
  p_investor text,
  p_amount bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'capital_raise_recorded',
          jsonb_build_object('round_id', p_round_id, 'investor', p_investor, 'amount_rupees', p_amount));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_capital_raise_recorded(uuid, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_raise_recorded(uuid, text, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_capital_snapshot_recorded(
  p_period date,
  p_burn bigint,
  p_revenue bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'capital_snapshot_recorded',
          jsonb_build_object('period_month', p_period, 'burn', p_burn, 'revenue', p_revenue));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_capital_snapshot_recorded(date, bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_snapshot_recorded(date, bigint, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_capital_efficiency_viewed(
  p_view text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'capital_efficiency_viewed',
          jsonb_build_object('view', p_view, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_capital_efficiency_viewed(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_efficiency_viewed(text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_capital_benchmark_run(
  p_metric text,
  p_value numeric
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'capital_benchmark_run',
          jsonb_build_object('metric', p_metric, 'value', p_value));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_capital_benchmark_run(text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_capital_benchmark_run(text, numeric) TO authenticated;

-- =========================================================================
-- Write RPCs (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_capital_raise_record(
  p_round_label text,
  p_raised_at date,
  p_amount_rupees bigint,
  p_investor_name text,
  p_investor_type text,
  p_cohort_label text DEFAULT NULL,
  p_pre_money bigint DEFAULT NULL,
  p_post_money bigint DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_capital_raise_rounds_v2
    (round_label, raised_at, amount_rupees, investor_name, investor_type, cohort_label,
     pre_money_valuation_rupees, post_money_valuation_rupees, notes)
  VALUES (p_round_label, p_raised_at, p_amount_rupees, p_investor_name, p_investor_type, p_cohort_label,
          p_pre_money, p_post_money, p_notes)
  RETURNING id INTO v_id;
  PERFORM log_founder_capital_raise_recorded(v_id, p_investor_name, p_amount_rupees);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_raise_record(text, date, bigint, text, text, text, bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_raise_record(text, date, bigint, text, text, text, bigint, bigint, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_capital_snapshot_record(
  p_period_month date,
  p_net_burn bigint,
  p_net_new_revenue bigint,
  p_total_revenue bigint,
  p_marketing_spend bigint,
  p_sales_spend bigint,
  p_new_customers integer,
  p_churned_customers integer,
  p_cash_balance bigint
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_capital_efficiency_snapshots_v2
    (period_month, net_burn_rupees, net_new_revenue_rupees, total_revenue_rupees,
     marketing_spend_rupees, sales_spend_rupees, new_customers, churned_customers, cash_balance_rupees)
  VALUES (p_period_month, p_net_burn, p_net_new_revenue, p_total_revenue,
          p_marketing_spend, p_sales_spend, p_new_customers, p_churned_customers, p_cash_balance)
  ON CONFLICT (period_month) DO UPDATE SET
    net_burn_rupees = EXCLUDED.net_burn_rupees,
    net_new_revenue_rupees = EXCLUDED.net_new_revenue_rupees,
    total_revenue_rupees = EXCLUDED.total_revenue_rupees,
    marketing_spend_rupees = EXCLUDED.marketing_spend_rupees,
    sales_spend_rupees = EXCLUDED.sales_spend_rupees,
    new_customers = EXCLUDED.new_customers,
    churned_customers = EXCLUDED.churned_customers,
    cash_balance_rupees = EXCLUDED.cash_balance_rupees
  RETURNING id INTO v_id;
  PERFORM log_founder_capital_snapshot_recorded(p_period_month, p_net_burn, p_net_new_revenue);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_snapshot_record(date, bigint, bigint, bigint, bigint, bigint, integer, integer, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_snapshot_record(date, bigint, bigint, bigint, bigint, bigint, integer, integer, bigint) TO authenticated;

-- =========================================================================
-- Read RPCs (STABLE)
-- =========================================================================

-- 1) Headline KPIs
CREATE OR REPLACE FUNCTION founder_capital_efficiency_kpis()
RETURNS TABLE(
  total_raised_rupees bigint,
  total_revenue_rupees bigint,
  revenue_per_rupee_raised numeric,
  ltm_burn_rupees bigint,
  ltm_net_new_revenue_rupees bigint,
  burn_multiple numeric,
  cash_balance_rupees bigint,
  runway_months numeric,
  ltm_marketing_spend_rupees bigint,
  ltm_sales_spend_rupees bigint,
  ltm_new_customers integer,
  cac_rupees numeric,
  ltm_revenue_per_customer numeric,
  ltv_rupees numeric,
  ltv_to_cac numeric,
  payback_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_raised bigint;
  v_total_rev bigint;
  v_ltm_burn bigint;
  v_ltm_nnr bigint;
  v_cash bigint;
  v_mkt bigint;
  v_sales bigint;
  v_new_cust integer;
  v_churned integer;
  v_active integer;
  v_cac numeric;
  v_rpc numeric;
  v_churn_rate numeric;
  v_ltv numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(amount_rupees),0) INTO v_raised FROM founder_capital_raise_rounds_v2;
  SELECT COALESCE(SUM(total_revenue_rupees),0) INTO v_total_rev FROM founder_capital_efficiency_snapshots_v2;

  SELECT COALESCE(SUM(net_burn_rupees),0),
         COALESCE(SUM(net_new_revenue_rupees),0),
         COALESCE(SUM(marketing_spend_rupees),0),
         COALESCE(SUM(sales_spend_rupees),0),
         COALESCE(SUM(new_customers),0),
         COALESCE(SUM(churned_customers),0)
  INTO v_ltm_burn, v_ltm_nnr, v_mkt, v_sales, v_new_cust, v_churned
  FROM founder_capital_efficiency_snapshots_v2
  WHERE period_month >= (CURRENT_DATE - INTERVAL '12 months');

  SELECT cash_balance_rupees INTO v_cash
  FROM founder_capital_efficiency_snapshots_v2
  ORDER BY period_month DESC LIMIT 1;
  v_cash := COALESCE(v_cash, 0);

  v_active := GREATEST(v_new_cust - v_churned, 1);
  v_cac := CASE WHEN v_new_cust > 0 THEN (v_mkt + v_sales)::numeric / v_new_cust ELSE NULL END;
  v_rpc := CASE WHEN v_active > 0 THEN v_ltm_nnr::numeric / v_active ELSE NULL END;
  v_churn_rate := CASE WHEN v_active > 0 THEN v_churned::numeric / v_active ELSE 0.1 END;
  IF v_churn_rate <= 0 THEN v_churn_rate := 0.1; END IF;
  v_ltv := CASE WHEN v_rpc IS NOT NULL THEN v_rpc / v_churn_rate ELSE NULL END;

  RETURN QUERY SELECT
    v_raised,
    v_total_rev,
    CASE WHEN v_raised > 0 THEN ROUND(v_total_rev::numeric / v_raised, 4) ELSE NULL END,
    v_ltm_burn,
    v_ltm_nnr,
    CASE WHEN v_ltm_nnr > 0 THEN ROUND(v_ltm_burn::numeric / v_ltm_nnr, 2) ELSE NULL END,
    v_cash,
    CASE WHEN v_ltm_burn > 0 THEN ROUND((v_cash::numeric * 12.0) / v_ltm_burn, 1) ELSE NULL END,
    v_mkt,
    v_sales,
    v_new_cust,
    CASE WHEN v_cac IS NOT NULL THEN ROUND(v_cac, 0) ELSE NULL END,
    CASE WHEN v_rpc IS NOT NULL THEN ROUND(v_rpc, 0) ELSE NULL END,
    CASE WHEN v_ltv IS NOT NULL THEN ROUND(v_ltv, 0) ELSE NULL END,
    CASE WHEN v_cac IS NOT NULL AND v_cac > 0 AND v_ltv IS NOT NULL THEN ROUND(v_ltv / v_cac, 2) ELSE NULL END,
    CASE WHEN v_rpc IS NOT NULL AND v_rpc > 0 AND v_cac IS NOT NULL THEN ROUND((v_cac / v_rpc) * 12.0, 1) ELSE NULL END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_efficiency_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_efficiency_kpis() TO authenticated;

-- 2) Per-investor breakdown
CREATE OR REPLACE FUNCTION founder_capital_per_investor()
RETURNS TABLE(
  id uuid,
  investor_name text,
  investor_type text,
  total_invested_rupees bigint,
  rounds_participated integer,
  first_check_date date,
  latest_check_date date,
  share_of_total_raise_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(amount_rupees),0) INTO v_total FROM founder_capital_raise_rounds_v2;
  RETURN QUERY
  SELECT
    md5(investor_name || investor_type)::uuid AS id,
    investor_name,
    investor_type,
    SUM(amount_rupees)::bigint,
    COUNT(*)::integer,
    MIN(raised_at),
    MAX(raised_at),
    CASE WHEN v_total > 0 THEN ROUND(SUM(amount_rupees)::numeric * 100.0 / v_total, 2) ELSE 0 END
  FROM founder_capital_raise_rounds_v2
  GROUP BY investor_name, investor_type
  ORDER BY SUM(amount_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_per_investor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_per_investor() TO authenticated;

-- 3) Per-cohort breakdown
CREATE OR REPLACE FUNCTION founder_capital_per_cohort()
RETURNS TABLE(
  id uuid,
  cohort_label text,
  raised_rupees bigint,
  investor_count integer,
  first_close_date date,
  last_close_date date,
  pre_money_avg_rupees bigint,
  post_money_avg_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    md5(COALESCE(cohort_label,'unlabeled'))::uuid AS id,
    COALESCE(cohort_label,'unlabeled') AS cohort_label,
    SUM(amount_rupees)::bigint,
    COUNT(DISTINCT investor_name)::integer,
    MIN(raised_at),
    MAX(raised_at),
    AVG(pre_money_valuation_rupees)::bigint,
    AVG(post_money_valuation_rupees)::bigint
  FROM founder_capital_raise_rounds_v2
  GROUP BY COALESCE(cohort_label,'unlabeled')
  ORDER BY SUM(amount_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_per_cohort() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_per_cohort() TO authenticated;

-- 4) Monthly burn-multiple series
CREATE OR REPLACE FUNCTION founder_capital_monthly_series()
RETURNS TABLE(
  id uuid,
  period_month date,
  net_burn_rupees bigint,
  net_new_revenue_rupees bigint,
  burn_multiple numeric,
  total_revenue_rupees bigint,
  new_customers integer,
  cash_balance_rupees bigint,
  runway_months numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.id,
    s.period_month,
    s.net_burn_rupees,
    s.net_new_revenue_rupees,
    CASE WHEN s.net_new_revenue_rupees > 0
         THEN ROUND(s.net_burn_rupees::numeric / s.net_new_revenue_rupees, 2)
         ELSE NULL END,
    s.total_revenue_rupees,
    s.new_customers,
    s.cash_balance_rupees,
    CASE WHEN s.net_burn_rupees > 0
         THEN ROUND(s.cash_balance_rupees::numeric / s.net_burn_rupees, 1)
         ELSE NULL END
  FROM founder_capital_efficiency_snapshots_v2 s
  ORDER BY s.period_month DESC
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_monthly_series() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_monthly_series() TO authenticated;

-- 5) Benchmark vs SaaS norms
CREATE OR REPLACE FUNCTION founder_capital_benchmark_saas()
RETURNS TABLE(
  id uuid,
  metric text,
  our_value numeric,
  saas_good numeric,
  saas_great numeric,
  verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_bm numeric;
  v_ltvcac numeric;
  v_payback numeric;
  v_rpr numeric;
  v_raised bigint;
  v_total_rev bigint;
  v_burn bigint;
  v_nnr bigint;
  v_mkt bigint;
  v_sales bigint;
  v_new_cust integer;
  v_churned integer;
  v_active integer;
  v_cac numeric;
  v_rpc numeric;
  v_churn_rate numeric;
  v_ltv numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(SUM(amount_rupees),0) INTO v_raised FROM founder_capital_raise_rounds_v2;
  SELECT COALESCE(SUM(total_revenue_rupees),0) INTO v_total_rev FROM founder_capital_efficiency_snapshots_v2;

  SELECT COALESCE(SUM(net_burn_rupees),0),
         COALESCE(SUM(net_new_revenue_rupees),0),
         COALESCE(SUM(marketing_spend_rupees),0),
         COALESCE(SUM(sales_spend_rupees),0),
         COALESCE(SUM(new_customers),0),
         COALESCE(SUM(churned_customers),0)
  INTO v_burn, v_nnr, v_mkt, v_sales, v_new_cust, v_churned
  FROM founder_capital_efficiency_snapshots_v2
  WHERE period_month >= (CURRENT_DATE - INTERVAL '12 months');

  v_active := GREATEST(v_new_cust - v_churned, 1);
  v_cac := CASE WHEN v_new_cust > 0 THEN (v_mkt + v_sales)::numeric / v_new_cust ELSE NULL END;
  v_rpc := CASE WHEN v_active > 0 THEN v_nnr::numeric / v_active ELSE NULL END;
  v_churn_rate := CASE WHEN v_active > 0 THEN v_churned::numeric / v_active ELSE 0.1 END;
  IF v_churn_rate <= 0 THEN v_churn_rate := 0.1; END IF;
  v_ltv := CASE WHEN v_rpc IS NOT NULL THEN v_rpc / v_churn_rate ELSE NULL END;

  v_bm := CASE WHEN v_nnr > 0 THEN ROUND(v_burn::numeric / v_nnr, 2) ELSE NULL END;
  v_ltvcac := CASE WHEN v_cac IS NOT NULL AND v_cac > 0 AND v_ltv IS NOT NULL THEN ROUND(v_ltv / v_cac, 2) ELSE NULL END;
  v_payback := CASE WHEN v_rpc IS NOT NULL AND v_rpc > 0 AND v_cac IS NOT NULL THEN ROUND((v_cac / v_rpc) * 12.0, 1) ELSE NULL END;
  v_rpr := CASE WHEN v_raised > 0 THEN ROUND(v_total_rev::numeric / v_raised, 4) ELSE NULL END;

  RETURN QUERY
  SELECT gen_random_uuid(), 'burn_multiple'::text, v_bm, 2.0::numeric, 1.0::numeric,
         CASE WHEN v_bm IS NULL THEN 'no_data'
              WHEN v_bm <= 1.0 THEN 'great'
              WHEN v_bm <= 2.0 THEN 'good'
              ELSE 'concerning' END
  UNION ALL
  SELECT gen_random_uuid(), 'ltv_to_cac'::text, v_ltvcac, 3.0::numeric, 5.0::numeric,
         CASE WHEN v_ltvcac IS NULL THEN 'no_data'
              WHEN v_ltvcac >= 5.0 THEN 'great'
              WHEN v_ltvcac >= 3.0 THEN 'good'
              ELSE 'concerning' END
  UNION ALL
  SELECT gen_random_uuid(), 'payback_months'::text, v_payback, 12.0::numeric, 6.0::numeric,
         CASE WHEN v_payback IS NULL THEN 'no_data'
              WHEN v_payback <= 6.0 THEN 'great'
              WHEN v_payback <= 12.0 THEN 'good'
              ELSE 'concerning' END
  UNION ALL
  SELECT gen_random_uuid(), 'revenue_per_rupee_raised'::text, v_rpr, 0.5::numeric, 1.0::numeric,
         CASE WHEN v_rpr IS NULL THEN 'no_data'
              WHEN v_rpr >= 1.0 THEN 'great'
              WHEN v_rpr >= 0.5 THEN 'good'
              ELSE 'concerning' END;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_benchmark_saas() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_benchmark_saas() TO authenticated;

-- 6) Raise rounds list
CREATE OR REPLACE FUNCTION founder_capital_raise_rounds_list()
RETURNS TABLE(
  id uuid,
  round_label text,
  raised_at date,
  amount_rupees bigint,
  investor_name text,
  investor_type text,
  cohort_label text,
  pre_money_valuation_rupees bigint,
  post_money_valuation_rupees bigint,
  days_since_close integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.round_label,
    r.raised_at,
    r.amount_rupees,
    r.investor_name,
    r.investor_type,
    r.cohort_label,
    r.pre_money_valuation_rupees,
    r.post_money_valuation_rupees,
    (CURRENT_DATE - r.raised_at)::integer
  FROM founder_capital_raise_rounds_v2 r
  ORDER BY r.raised_at DESC, r.amount_rupees DESC
  LIMIT 500;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_raise_rounds_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_raise_rounds_list() TO authenticated;

-- 7) Efficiency by investor type
CREATE OR REPLACE FUNCTION founder_capital_by_investor_type()
RETURNS TABLE(
  id uuid,
  investor_type text,
  total_invested_rupees bigint,
  investor_count integer,
  round_count integer,
  avg_check_rupees bigint,
  share_of_raise_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(amount_rupees),0) INTO v_total FROM founder_capital_raise_rounds_v2;
  RETURN QUERY
  SELECT
    md5(investor_type)::uuid,
    investor_type,
    SUM(amount_rupees)::bigint,
    COUNT(DISTINCT investor_name)::integer,
    COUNT(*)::integer,
    AVG(amount_rupees)::bigint,
    CASE WHEN v_total > 0 THEN ROUND(SUM(amount_rupees)::numeric * 100.0 / v_total, 2) ELSE 0 END
  FROM founder_capital_raise_rounds_v2
  GROUP BY investor_type
  ORDER BY SUM(amount_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_capital_by_investor_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_capital_by_investor_type() TO authenticated;

COMMIT;