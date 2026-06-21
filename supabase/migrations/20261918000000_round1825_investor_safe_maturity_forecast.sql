BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_safe_maturity_forecasts_r1825 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_label text NOT NULL,
  assumed_next_round_date date,
  assumed_next_valuation_rupees bigint,
  total_safes_count int DEFAULT 0,
  total_safe_amount_rupees bigint DEFAULT 0,
  expected_conversion_shares bigint DEFAULT 0,
  founder_ownership_after_pct numeric(6,3) DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','baseline','scenario')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_safe_maturity_assumptions_r1825 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.investor_safe_maturity_forecasts_r1825(id) ON DELETE CASCADE,
  assumption_label text NOT NULL,
  assumption_value text NOT NULL,
  weight text NOT NULL DEFAULT 'important' CHECK (weight IN ('critical','important','sensitivity')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_safe_maturity_forecasts_r1825 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_safe_maturity_assumptions_r1825 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_forecasts_r1825 ON public.investor_safe_maturity_forecasts_r1825;
CREATE POLICY founder_all_forecasts_r1825 ON public.investor_safe_maturity_forecasts_r1825
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_assumptions_r1825 ON public.investor_safe_maturity_assumptions_r1825;
CREATE POLICY founder_all_assumptions_r1825 ON public.investor_safe_maturity_assumptions_r1825
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_forecasts
CREATE OR REPLACE FUNCTION public.list_safe_maturity_forecasts_r1825()
RETURNS TABLE (
  id uuid,
  model_label text,
  assumed_next_round_date date,
  assumed_next_valuation_rupees bigint,
  total_safes_count int,
  total_safe_amount_rupees bigint,
  expected_conversion_shares bigint,
  founder_ownership_after_pct numeric,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.model_label, f.assumed_next_round_date, f.assumed_next_valuation_rupees,
         f.total_safes_count, f.total_safe_amount_rupees, f.expected_conversion_shares,
         f.founder_ownership_after_pct, f.status, f.created_at
  FROM public.investor_safe_maturity_forecasts_r1825 f
  ORDER BY f.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: save_forecast
CREATE OR REPLACE FUNCTION public.save_safe_maturity_forecast_r1825(
  p_model_label text,
  p_assumed_next_round_date date,
  p_assumed_next_valuation_rupees bigint,
  p_total_safes_count int,
  p_total_safe_amount_rupees bigint,
  p_expected_conversion_shares bigint,
  p_founder_ownership_after_pct numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_safe_maturity_forecasts_r1825(
    model_label, assumed_next_round_date, assumed_next_valuation_rupees,
    total_safes_count, total_safe_amount_rupees, expected_conversion_shares,
    founder_ownership_after_pct, status)
  VALUES (p_model_label, p_assumed_next_round_date, p_assumed_next_valuation_rupees,
          COALESCE(p_total_safes_count, 0), COALESCE(p_total_safe_amount_rupees, 0),
          COALESCE(p_expected_conversion_shares, 0),
          COALESCE(p_founder_ownership_after_pct, 0),
          COALESCE(p_status, 'draft'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_safe_maturity_forecast_r1825',
          jsonb_build_object('id', v_id, 'model_label', p_model_label, 'status', p_status));

  RETURN v_id;
END;
$$;

-- RPC 3: list_assumptions
CREATE OR REPLACE FUNCTION public.list_safe_maturity_assumptions_r1825(p_forecast_id uuid)
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  assumption_label text,
  assumption_value text,
  weight text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.forecast_id, a.assumption_label, a.assumption_value, a.weight, a.created_at
  FROM public.investor_safe_maturity_assumptions_r1825 a
  WHERE (p_forecast_id IS NULL OR a.forecast_id = p_forecast_id)
  ORDER BY a.created_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log_assumption
CREATE OR REPLACE FUNCTION public.log_safe_maturity_assumption_r1825(
  p_forecast_id uuid,
  p_assumption_label text,
  p_assumption_value text,
  p_weight text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_safe_maturity_assumptions_r1825(
    forecast_id, assumption_label, assumption_value, weight)
  VALUES (p_forecast_id, p_assumption_label, p_assumption_value, COALESCE(p_weight, 'important'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_safe_maturity_assumption_r1825',
          jsonb_build_object('id', v_id, 'forecast_id', p_forecast_id, 'label', p_assumption_label));

  RETURN v_id;
END;
$$;

-- RPC 5: baseline_forecast
CREATE OR REPLACE FUNCTION public.baseline_safe_maturity_forecast_r1825()
RETURNS TABLE (
  id uuid,
  model_label text,
  total_safe_amount_rupees bigint,
  expected_conversion_shares bigint,
  founder_ownership_after_pct numeric,
  assumed_next_round_date date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.model_label, f.total_safe_amount_rupees, f.expected_conversion_shares,
         f.founder_ownership_after_pct, f.assumed_next_round_date
  FROM public.investor_safe_maturity_forecasts_r1825 f
  WHERE f.status = 'baseline'
  ORDER BY f.created_at DESC
  LIMIT 1;
END;
$$;

-- RPC 6: dilution_curve
CREATE OR REPLACE FUNCTION public.safe_maturity_dilution_curve_r1825()
RETURNS TABLE (
  status text,
  model_count int,
  avg_ownership_after_pct numeric,
  total_amount_rupees bigint,
  total_shares bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.status,
         (COUNT(*))::int AS model_count,
         ROUND(AVG(COALESCE(f.founder_ownership_after_pct, 0))::numeric, 3) AS avg_ownership_after_pct,
         COALESCE(SUM(f.total_safe_amount_rupees), 0)::bigint AS total_amount_rupees,
         COALESCE(SUM(f.expected_conversion_shares), 0)::bigint AS total_shares
  FROM public.investor_safe_maturity_forecasts_r1825 f
  GROUP BY f.status
  ORDER BY f.status;
END;
$$;

-- RPC 7: scenario_comparison
CREATE OR REPLACE FUNCTION public.safe_maturity_scenario_comparison_r1825()
RETURNS TABLE (
  model_label text,
  status text,
  total_safe_amount_rupees bigint,
  expected_conversion_shares bigint,
  founder_ownership_after_pct numeric,
  delta_vs_baseline_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_base numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COALESCE(f.founder_ownership_after_pct, 0) INTO v_base
  FROM public.investor_safe_maturity_forecasts_r1825 f
  WHERE f.status = 'baseline'
  ORDER BY f.created_at DESC LIMIT 1;

  RETURN QUERY
  SELECT f.model_label, f.status, f.total_safe_amount_rupees, f.expected_conversion_shares,
         f.founder_ownership_after_pct,
         ROUND((COALESCE(f.founder_ownership_after_pct, 0) - COALESCE(v_base, 0))::numeric, 3) AS delta_vs_baseline_pct
  FROM public.investor_safe_maturity_forecasts_r1825 f
  ORDER BY f.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_safe_maturity_forecasts_r1825() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_safe_maturity_forecast_r1825(text, date, bigint, int, bigint, bigint, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_safe_maturity_assumptions_r1825(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_safe_maturity_assumption_r1825(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.baseline_safe_maturity_forecast_r1825() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.safe_maturity_dilution_curve_r1825() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.safe_maturity_scenario_comparison_r1825() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_safe_maturity_forecasts_r1825() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_safe_maturity_forecast_r1825(text, date, bigint, int, bigint, bigint, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_safe_maturity_assumptions_r1825(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_safe_maturity_assumption_r1825(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.baseline_safe_maturity_forecast_r1825() TO authenticated;
GRANT EXECUTE ON FUNCTION public.safe_maturity_dilution_curve_r1825() TO authenticated;
GRANT EXECUTE ON FUNCTION public.safe_maturity_scenario_comparison_r1825() TO authenticated;

COMMIT;