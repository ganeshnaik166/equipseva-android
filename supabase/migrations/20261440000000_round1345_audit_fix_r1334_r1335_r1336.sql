BEGIN;
-- r1345 — audit-fix sweep for batch 14 (workflow wkeox1odv).
-- 10 confirmed bugs surfaced; 3 fixed here (the breaking-or-misleading ones).
-- Cosmetic findings deferred (city/state empty-fallback, action_items_cockpit
-- status-vocabulary blending, page TS due_date parsing — all benign).
-- r1335 "SQL syntax error" claim was a FALSE POSITIVE — Postgres parses
-- `FROM agg, raised LEFT JOIN latest ON true` as `FROM agg CROSS JOIN
-- (raised LEFT JOIN latest ON true)` and the migration applied cleanly.
--
-- 1. r1334 CRITICAL: founder_unit_economics_summary returned the SAME value
--    twice (v_monthly_gp for both monthly_gross_profit_per_account_rupees
--    and monthly_contribution_per_account_rupees). UI shows two identical
--    cards with different labels. Fix: subtract per-account amortized
--    customer acquisition cost from contribution (CAC / lifetime_months).
--
-- 2. r1335 HIGH: available_esop_pct == esop_pool_pct (both compute
--    pool_n*100/v_total). Available = pool minus already-granted employee
--    shares (out of the pool itself).
--
-- 3. r1336 HIGH: log_founder_decision_record_outcome set only reviewed_at,
--    but founder_decisions_due_revisit() + summary check revisited_at IS NULL.
--    Writing an outcome should atomically mark the decision as revisited.

-- ============================================================================
-- 1. r1334 — fix monthly_contribution to differ from gross profit
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_unit_economics_summary();
CREATE OR REPLACE FUNCTION public.founder_unit_economics_summary()
RETURNS TABLE (
  snapshot_label text,
  cac_rupees numeric,
  monthly_revenue_per_account_rupees numeric,
  monthly_gross_profit_per_account_rupees numeric,
  monthly_contribution_per_account_rupees numeric,
  contribution_margin_pct numeric,
  ltv_rupees numeric,
  ltv_to_cac_ratio numeric,
  payback_months numeric,
  health_band text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_input record;
  v_new_amcs int;
  v_total_acq_cost numeric;
  v_cac numeric;
  v_monthly_rev numeric;
  v_monthly_gp numeric;
  v_monthly_contrib numeric;
  v_contrib_margin numeric;
  v_ltv numeric;
  v_ratio numeric;
  v_payback numeric;
  v_band text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT * INTO v_input
  FROM public.founder_unit_economics_inputs
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_input IS NULL THEN RETURN; END IF;

  SELECT count(*) INTO v_new_amcs
  FROM public.amc_contracts
  WHERE activated_at >= now() - interval '90 days';

  v_total_acq_cost := COALESCE(v_input.sales_cost_quarter_rupees, 0)
                    + COALESCE(v_input.bd_headcount_cost_quarter_rupees, 0)
                    + COALESCE(v_input.marketing_cost_quarter_rupees, 0);

  v_cac := CASE WHEN v_new_amcs > 0 THEN v_total_acq_cost / v_new_amcs ELSE NULL END;

  v_monthly_rev := v_input.avg_hospital_amc_monthly_rupees * v_input.avg_take_rate_pct / 100.0;
  v_monthly_gp := v_monthly_rev - COALESCE(v_input.avg_cogs_per_amc_monthly_rupees, 0);

  -- r1345 FIX: contribution = gross_profit minus CAC amortized over lifetime
  -- (this is what "contribution after acquisition costs" means in unit econ)
  v_monthly_contrib := v_monthly_gp - CASE
    WHEN v_cac IS NULL OR v_input.avg_hospital_lifetime_months <= 0 THEN 0
    ELSE v_cac / v_input.avg_hospital_lifetime_months
  END;

  v_contrib_margin := CASE WHEN v_monthly_rev > 0 THEN (v_monthly_contrib / v_monthly_rev) * 100.0 ELSE NULL END;
  v_ltv := v_monthly_gp * v_input.avg_hospital_lifetime_months;
  v_ratio := CASE WHEN v_cac IS NOT NULL AND v_cac > 0 THEN v_ltv / v_cac ELSE NULL END;
  v_payback := CASE WHEN v_monthly_gp > 0 AND v_cac IS NOT NULL THEN v_cac / v_monthly_gp ELSE NULL END;

  v_band := CASE
    WHEN v_ratio IS NULL OR v_payback IS NULL THEN 'warn'
    WHEN v_ratio >= 3 AND v_payback <= 18 THEN 'ok'
    WHEN v_ratio >= 1.5 THEN 'warn'
    ELSE 'danger'
  END;

  RETURN QUERY SELECT
    v_input.snapshot_label,
    ROUND(v_cac, 2),
    ROUND(v_monthly_rev, 2),
    ROUND(v_monthly_gp, 2),
    ROUND(v_monthly_contrib, 2),
    ROUND(v_contrib_margin, 2),
    ROUND(v_ltv, 2),
    ROUND(v_ratio, 2),
    ROUND(v_payback, 2),
    v_band;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_unit_economics_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_unit_economics_summary() TO authenticated;

-- ============================================================================
-- 2. r1335 — available_esop_pct distinct from esop_pool_pct
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_cap_table_summary();
CREATE OR REPLACE FUNCTION public.founder_cap_table_summary()
RETURNS TABLE (
  total_shares                bigint,
  founders_pct                numeric,
  employees_pct               numeric,
  angels_pct                  numeric,
  vcs_pct                     numeric,
  esop_pool_pct               numeric,
  available_esop_pct          numeric,
  total_raised_rupees         numeric,
  latest_round_label          text,
  latest_post_money_rupees    numeric,
  fully_diluted_shares        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT COALESCE(sum(s.shares_count), 0)::bigint INTO v_total
    FROM public.founder_cap_table_shareholders s;

  RETURN QUERY
  WITH agg AS (
    SELECT
      COALESCE(sum(s.shares_count) FILTER (WHERE s.shareholder_kind = 'founder'),  0)::numeric AS founders_n,
      COALESCE(sum(s.shares_count) FILTER (WHERE s.shareholder_kind = 'employee'), 0)::numeric AS employees_n,
      COALESCE(sum(s.shares_count) FILTER (WHERE s.shareholder_kind = 'angel'),    0)::numeric AS angels_n,
      COALESCE(sum(s.shares_count) FILTER (WHERE s.shareholder_kind IN ('vc','strategic')), 0)::numeric AS vcs_n,
      COALESCE(sum(s.shares_count) FILTER (WHERE s.shareholder_kind = 'esop_pool'),0)::numeric AS pool_n,
      COALESCE(sum(s.investment_amount_rupees), 0)::numeric AS invested_n
    FROM public.founder_cap_table_shareholders s
  ),
  latest AS (
    SELECT r.round_label,
           (r.pre_money_valuation_rupees + r.raise_amount_rupees)::numeric AS post_money
      FROM public.founder_cap_table_rounds r
     ORDER BY r.closed_at DESC NULLS LAST, r.created_at DESC
     LIMIT 1
  ),
  raised AS (
    SELECT COALESCE(sum(r.raise_amount_rupees), 0)::numeric AS total_raised
      FROM public.founder_cap_table_rounds r
  )
  SELECT
    v_total                                                                            AS total_shares,
    CASE WHEN v_total > 0 THEN ROUND(agg.founders_n  * 100.0 / v_total, 2) ELSE 0 END  AS founders_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.employees_n * 100.0 / v_total, 2) ELSE 0 END  AS employees_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.angels_n    * 100.0 / v_total, 2) ELSE 0 END  AS angels_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.vcs_n       * 100.0 / v_total, 2) ELSE 0 END  AS vcs_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.pool_n      * 100.0 / v_total, 2) ELSE 0 END  AS esop_pool_pct,
    -- r1345 FIX: available pool = pool_n - employees_n (granted employee shares
    -- come out of the pool). Pct of total. If employees > pool, available = 0.
    CASE WHEN v_total > 0
         THEN ROUND(GREATEST(agg.pool_n - agg.employees_n, 0) * 100.0 / v_total, 2)
         ELSE 0 END                                                                    AS available_esop_pct,
    raised.total_raised                                                                AS total_raised_rupees,
    latest.round_label                                                                 AS latest_round_label,
    latest.post_money                                                                  AS latest_post_money_rupees,
    v_total                                                                            AS fully_diluted_shares
  FROM agg
  CROSS JOIN raised
  LEFT JOIN latest ON true;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cap_table_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cap_table_summary() TO authenticated;

-- ============================================================================
-- 3. r1336 — recording outcome also stamps revisited_at
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_decision_record_outcome(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_decision_record_outcome(p_decision_id uuid, p_actual_outcome text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  UPDATE public.founder_decisions
  SET actual_outcome = p_actual_outcome,
      reviewed_at = now(),
      -- r1345 FIX: also stamp revisited_at so the due-revisit queue clears
      revisited_at = COALESCE(revisited_at, now())
  WHERE id = p_decision_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_decision_record_outcome(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_decision_record_outcome(uuid, text) TO authenticated;

COMMIT;
