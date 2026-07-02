BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_bridge_financing_calculators_r1893 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_label text NOT NULL,
  target_amount_rupees bigint NOT NULL DEFAULT 0,
  avg_check_rupees bigint NOT NULL DEFAULT 0,
  number_of_investors int NOT NULL DEFAULT 0,
  valuation_cap_rupees bigint NOT NULL DEFAULT 0,
  discount_pct numeric NOT NULL DEFAULT 0,
  founder_dilution_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','baseline','locked')),
  modeled_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_bridge_financing_assumptions_r1893 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  calc_id uuid NOT NULL REFERENCES public.investor_bridge_financing_calculators_r1893(id) ON DELETE CASCADE,
  assumption_label text NOT NULL,
  assumption_value text NOT NULL DEFAULT '',
  weight text NOT NULL DEFAULT 'important' CHECK (weight IN ('critical','important','sensitivity')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_bridge_financing_calculators_r1893 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_bridge_financing_assumptions_r1893 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_calcs_r1893 ON public.investor_bridge_financing_calculators_r1893;
CREATE POLICY founder_all_calcs_r1893 ON public.investor_bridge_financing_calculators_r1893
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_assump_r1893 ON public.investor_bridge_financing_assumptions_r1893;
CREATE POLICY founder_all_assump_r1893 ON public.investor_bridge_financing_assumptions_r1893
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_calculations
CREATE OR REPLACE FUNCTION public.list_calculations_r1893()
RETURNS TABLE (
  id uuid,
  model_label text,
  target_amount_rupees bigint,
  avg_check_rupees bigint,
  number_of_investors int,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  founder_dilution_pct numeric,
  status text,
  modeled_at timestamptz,
  assumption_count int,
  critical_assumption_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.model_label, c.target_amount_rupees, c.avg_check_rupees, c.number_of_investors,
    c.valuation_cap_rupees, c.discount_pct, c.founder_dilution_pct, c.status, c.modeled_at,
    (SELECT (COUNT(*))::int FROM public.investor_bridge_financing_assumptions_r1893 a WHERE a.calc_id = c.id) AS assumption_count,
    (SELECT (COUNT(*) FILTER (WHERE a.weight = 'critical'))::int FROM public.investor_bridge_financing_assumptions_r1893 a WHERE a.calc_id = c.id) AS critical_assumption_count
  FROM public.investor_bridge_financing_calculators_r1893 c
  ORDER BY c.modeled_at DESC;
END;
$$;

-- RPC 2: save_calculation
CREATE OR REPLACE FUNCTION public.save_calculation_r1893(
  p_model_label text,
  p_target_amount_rupees bigint,
  p_avg_check_rupees bigint,
  p_number_of_investors int,
  p_valuation_cap_rupees bigint,
  p_discount_pct numeric,
  p_founder_dilution_pct numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_bridge_financing_calculators_r1893
    (model_label, target_amount_rupees, avg_check_rupees, number_of_investors, valuation_cap_rupees, discount_pct, founder_dilution_pct, status)
  VALUES
    (p_model_label, COALESCE(p_target_amount_rupees, 0), COALESCE(p_avg_check_rupees, 0), COALESCE(p_number_of_investors, 0),
     COALESCE(p_valuation_cap_rupees, 0), COALESCE(p_discount_pct, 0), COALESCE(p_founder_dilution_pct, 0), COALESCE(p_status, 'draft'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_calculation_r1893',
    jsonb_build_object('id', v_id, 'model_label', p_model_label, 'target_amount_rupees', p_target_amount_rupees));

  RETURN v_id;
END;
$$;

-- RPC 3: list_assumptions
CREATE OR REPLACE FUNCTION public.list_assumptions_r1893(p_calc_id uuid)
RETURNS TABLE (
  id uuid,
  calc_id uuid,
  assumption_label text,
  assumption_value text,
  weight text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.calc_id, a.assumption_label, a.assumption_value, a.weight, a.created_at
  FROM public.investor_bridge_financing_assumptions_r1893 a
  WHERE (p_calc_id IS NULL OR a.calc_id = p_calc_id)
  ORDER BY a.created_at DESC;
END;
$$;

-- RPC 4: log_assumption
CREATE OR REPLACE FUNCTION public.log_assumption_r1893(
  p_calc_id uuid,
  p_assumption_label text,
  p_assumption_value text,
  p_weight text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_bridge_financing_assumptions_r1893 (calc_id, assumption_label, assumption_value, weight)
  VALUES (p_calc_id, p_assumption_label, COALESCE(p_assumption_value, ''), COALESCE(p_weight, 'important'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_assumption_r1893',
    jsonb_build_object('id', v_id, 'calc_id', p_calc_id, 'label', p_assumption_label, 'weight', p_weight));

  RETURN v_id;
END;
$$;

-- RPC 5: lock_calculation
CREATE OR REPLACE FUNCTION public.lock_calculation_r1893(p_calc_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_bridge_financing_calculators_r1893
    SET status = 'locked', updated_at = now()
    WHERE id = p_calc_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'lock_calculation_r1893',
    jsonb_build_object('calc_id', p_calc_id));
END;
$$;

-- RPC 6: founder_dilution_outlook
CREATE OR REPLACE FUNCTION public.founder_dilution_outlook_r1893()
RETURNS TABLE (
  status text,
  model_count int,
  avg_dilution_pct numeric,
  min_dilution_pct numeric,
  max_dilution_pct numeric,
  total_target_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.status,
    (COUNT(*))::int AS model_count,
    ROUND(AVG(c.founder_dilution_pct)::numeric, 2) AS avg_dilution_pct,
    ROUND(MIN(c.founder_dilution_pct)::numeric, 2) AS min_dilution_pct,
    ROUND(MAX(c.founder_dilution_pct)::numeric, 2) AS max_dilution_pct,
    COALESCE(SUM(c.target_amount_rupees), 0)::bigint AS total_target_rupees
  FROM public.investor_bridge_financing_calculators_r1893 c
  GROUP BY c.status
  ORDER BY c.status;
END;
$$;

-- RPC 7: scenario_comparison
CREATE OR REPLACE FUNCTION public.scenario_comparison_r1893()
RETURNS TABLE (
  id uuid,
  model_label text,
  status text,
  target_amount_rupees bigint,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  founder_dilution_pct numeric,
  effective_price_per_pct numeric,
  modeled_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.model_label, c.status, c.target_amount_rupees, c.valuation_cap_rupees, c.discount_pct, c.founder_dilution_pct,
    CASE WHEN c.founder_dilution_pct > 0
         THEN ROUND((c.target_amount_rupees::numeric / NULLIF(c.founder_dilution_pct, 0))::numeric, 2)
         ELSE 0::numeric
    END AS effective_price_per_pct,
    c.modeled_at
  FROM public.investor_bridge_financing_calculators_r1893 c
  ORDER BY c.founder_dilution_pct ASC, c.modeled_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_calculations_r1893() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_calculation_r1893(text, bigint, bigint, int, bigint, numeric, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_assumptions_r1893(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_assumption_r1893(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.lock_calculation_r1893(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_dilution_outlook_r1893() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.scenario_comparison_r1893() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_calculations_r1893() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_calculation_r1893(text, bigint, bigint, int, bigint, numeric, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_assumptions_r1893(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_assumption_r1893(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lock_calculation_r1893(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_dilution_outlook_r1893() TO authenticated;
GRANT EXECUTE ON FUNCTION public.scenario_comparison_r1893() TO authenticated;

COMMIT;