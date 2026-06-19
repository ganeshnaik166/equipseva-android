BEGIN;
-- r1334 — founder unit economics: CAC + LTV + payback + contribution margin
-- Inputs table = founder records quarterly spend + AMC econ params
-- RPCs compute live CAC from last-90d AMC cohort



CREATE TABLE IF NOT EXISTS public.founder_unit_economics_inputs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_label text NOT NULL UNIQUE,
  sales_cost_quarter_rupees numeric NOT NULL CHECK (sales_cost_quarter_rupees >= 0),
  bd_headcount_cost_quarter_rupees numeric NOT NULL CHECK (bd_headcount_cost_quarter_rupees >= 0),
  marketing_cost_quarter_rupees numeric DEFAULT 0 CHECK (marketing_cost_quarter_rupees >= 0),
  avg_hospital_amc_monthly_rupees numeric NOT NULL CHECK (avg_hospital_amc_monthly_rupees > 0),
  avg_take_rate_pct numeric NOT NULL CHECK (avg_take_rate_pct > 0 AND avg_take_rate_pct <= 100),
  avg_cogs_per_amc_monthly_rupees numeric DEFAULT 0 CHECK (avg_cogs_per_amc_monthly_rupees >= 0),
  avg_hospital_lifetime_months numeric NOT NULL CHECK (avg_hospital_lifetime_months > 0),
  recorded_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_unit_econ_inputs_created
  ON public.founder_unit_economics_inputs(created_at DESC);

ALTER TABLE public.founder_unit_economics_inputs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_unit_econ_inputs_no_direct ON public.founder_unit_economics_inputs;
CREATE POLICY founder_unit_econ_inputs_no_direct
  ON public.founder_unit_economics_inputs
  FOR ALL TO authenticated
  USING (false) WITH CHECK (false);

-- Summary RPC: pulls latest input row + computes CAC/LTV/payback live
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
  v_contrib_margin numeric;
  v_ltv numeric;
  v_ratio numeric;
  v_payback numeric;
  v_band text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_input
  FROM public.founder_unit_economics_inputs
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_input IS NULL THEN
    RETURN;
  END IF;

  SELECT COUNT(*) INTO v_new_amcs
  FROM public.amc_contracts
  WHERE activated_at >= now() - interval '90 days';

  v_total_acq_cost := COALESCE(v_input.sales_cost_quarter_rupees, 0)
                    + COALESCE(v_input.bd_headcount_cost_quarter_rupees, 0)
                    + COALESCE(v_input.marketing_cost_quarter_rupees, 0);

  v_cac := CASE WHEN v_new_amcs > 0 THEN v_total_acq_cost / v_new_amcs ELSE NULL END;

  v_monthly_rev := v_input.avg_hospital_amc_monthly_rupees * v_input.avg_take_rate_pct / 100.0;
  v_monthly_gp := v_monthly_rev - COALESCE(v_input.avg_cogs_per_amc_monthly_rupees, 0);
  v_contrib_margin := CASE WHEN v_monthly_rev > 0 THEN (v_monthly_gp / v_monthly_rev) * 100.0 ELSE NULL END;
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
    ROUND(v_monthly_gp, 2),
    ROUND(v_contrib_margin, 2),
    ROUND(v_ltv, 2),
    ROUND(v_ratio, 2),
    ROUND(v_payback, 2),
    v_band;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_unit_economics_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_unit_economics_summary() TO authenticated;

-- History RPC: recent snapshots with their stored params
DROP FUNCTION IF EXISTS public.founder_unit_economics_history(int);
CREATE OR REPLACE FUNCTION public.founder_unit_economics_history(p_limit int DEFAULT 8)
RETURNS TABLE (
  snapshot_label text,
  sales_cost_quarter_rupees numeric,
  bd_headcount_cost_quarter_rupees numeric,
  marketing_cost_quarter_rupees numeric,
  avg_hospital_amc_monthly_rupees numeric,
  avg_take_rate_pct numeric,
  avg_cogs_per_amc_monthly_rupees numeric,
  avg_hospital_lifetime_months numeric,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    i.snapshot_label,
    i.sales_cost_quarter_rupees,
    i.bd_headcount_cost_quarter_rupees,
    i.marketing_cost_quarter_rupees,
    i.avg_hospital_amc_monthly_rupees,
    i.avg_take_rate_pct,
    i.avg_cogs_per_amc_monthly_rupees,
    i.avg_hospital_lifetime_months,
    i.created_at
  FROM public.founder_unit_economics_inputs i
  ORDER BY i.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 50));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_unit_economics_history(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_unit_economics_history(int) TO authenticated;

-- Logger RPC: founder records a new snapshot
DROP FUNCTION IF EXISTS public.log_founder_unit_economics_snapshot(text, numeric, numeric, numeric, numeric, numeric, numeric, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_unit_economics_snapshot(
  p_snapshot_label text,
  p_sales_cost_quarter_rupees numeric,
  p_bd_headcount_cost_quarter_rupees numeric,
  p_marketing_cost_quarter_rupees numeric,
  p_avg_hospital_amc_monthly_rupees numeric,
  p_avg_take_rate_pct numeric,
  p_avg_cogs_per_amc_monthly_rupees numeric,
  p_avg_hospital_lifetime_months numeric
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.founder_unit_economics_inputs (
    snapshot_label,
    sales_cost_quarter_rupees,
    bd_headcount_cost_quarter_rupees,
    marketing_cost_quarter_rupees,
    avg_hospital_amc_monthly_rupees,
    avg_take_rate_pct,
    avg_cogs_per_amc_monthly_rupees,
    avg_hospital_lifetime_months,
    recorded_by
  ) VALUES (
    p_snapshot_label,
    p_sales_cost_quarter_rupees,
    p_bd_headcount_cost_quarter_rupees,
    COALESCE(p_marketing_cost_quarter_rupees, 0),
    p_avg_hospital_amc_monthly_rupees,
    p_avg_take_rate_pct,
    COALESCE(p_avg_cogs_per_amc_monthly_rupees, 0),
    p_avg_hospital_lifetime_months,
    auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_unit_economics_snapshot(text, numeric, numeric, numeric, numeric, numeric, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_unit_economics_snapshot(text, numeric, numeric, numeric, numeric, numeric, numeric, numeric) TO authenticated;

COMMIT;