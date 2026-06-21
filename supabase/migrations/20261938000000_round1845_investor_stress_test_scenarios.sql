BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_stress_test_scenarios_r1845 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_label text NOT NULL,
  scenario_type text NOT NULL CHECK (scenario_type IN ('downside','base','upside','black_swan')),
  assumed_exit_valuation_rupees bigint NOT NULL DEFAULT 0,
  assumed_exit_year int NOT NULL DEFAULT 2030,
  founder_return_pct numeric NOT NULL DEFAULT 0,
  employee_pool_pct numeric NOT NULL DEFAULT 0,
  investor_pool_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','baseline','locked')),
  modeled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_stress_test_assumptions_r1845 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scenario_id uuid NOT NULL REFERENCES public.investor_stress_test_scenarios_r1845(id) ON DELETE CASCADE,
  assumption_label text NOT NULL,
  assumption_value text NOT NULL,
  weight text NOT NULL CHECK (weight IN ('critical','important','sensitivity')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_stress_test_scenarios_r1845 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_stress_test_assumptions_r1845 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r1845_s ON public.investor_stress_test_scenarios_r1845;
CREATE POLICY founder_all_r1845_s ON public.investor_stress_test_scenarios_r1845
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r1845_a ON public.investor_stress_test_assumptions_r1845;
CREATE POLICY founder_all_r1845_a ON public.investor_stress_test_assumptions_r1845
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- list_scenarios
CREATE OR REPLACE FUNCTION public.list_scenarios_r1845()
RETURNS TABLE (
  id uuid,
  scenario_label text,
  scenario_type text,
  assumed_exit_valuation_rupees bigint,
  assumed_exit_year int,
  founder_return_pct numeric,
  employee_pool_pct numeric,
  investor_pool_pct numeric,
  status text,
  modeled_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.scenario_label, s.scenario_type, s.assumed_exit_valuation_rupees,
           s.assumed_exit_year, s.founder_return_pct, s.employee_pool_pct, s.investor_pool_pct,
           s.status, s.modeled_at, s.created_at
    FROM public.investor_stress_test_scenarios_r1845 s
    ORDER BY s.created_at DESC
    LIMIT 200;
END;
$$;

-- save_scenario
CREATE OR REPLACE FUNCTION public.save_scenario_r1845(
  p_label text,
  p_type text,
  p_valuation bigint,
  p_year int,
  p_founder_pct numeric,
  p_employee_pct numeric,
  p_investor_pct numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_stress_test_scenarios_r1845
    (scenario_label, scenario_type, assumed_exit_valuation_rupees, assumed_exit_year,
     founder_return_pct, employee_pool_pct, investor_pool_pct, status, modeled_at)
  VALUES (p_label, p_type, p_valuation, p_year, p_founder_pct, p_employee_pct, p_investor_pct, 'draft', now())
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_scenario_r1845',
          jsonb_build_object('scenario_id', v_id, 'label', p_label, 'type', p_type, 'valuation', p_valuation));

  RETURN v_id;
END;
$$;

-- list_assumptions
CREATE OR REPLACE FUNCTION public.list_assumptions_r1845(p_scenario uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  scenario_id uuid,
  scenario_label text,
  assumption_label text,
  assumption_value text,
  weight text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.scenario_id, s.scenario_label, a.assumption_label, a.assumption_value, a.weight, a.created_at
    FROM public.investor_stress_test_assumptions_r1845 a
    JOIN public.investor_stress_test_scenarios_r1845 s ON s.id = a.scenario_id
    WHERE p_scenario IS NULL OR a.scenario_id = p_scenario
    ORDER BY a.created_at DESC
    LIMIT 300;
END;
$$;

-- log_assumption
CREATE OR REPLACE FUNCTION public.log_assumption_r1845(
  p_scenario uuid,
  p_label text,
  p_value text,
  p_weight text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_stress_test_assumptions_r1845
    (scenario_id, assumption_label, assumption_value, weight)
  VALUES (p_scenario, p_label, p_value, p_weight)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_assumption_r1845',
          jsonb_build_object('assumption_id', v_id, 'scenario_id', p_scenario, 'label', p_label, 'weight', p_weight));

  RETURN v_id;
END;
$$;

-- lock_scenario
CREATE OR REPLACE FUNCTION public.lock_scenario_r1845(p_scenario uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_stress_test_scenarios_r1845
    SET status = 'locked', modeled_at = now(), updated_at = now()
  WHERE id = p_scenario;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'lock_scenario_r1845',
          jsonb_build_object('scenario_id', p_scenario));
END;
$$;

-- founder_return_outlook
CREATE OR REPLACE FUNCTION public.founder_return_outlook_r1845()
RETURNS TABLE (
  scenario_type text,
  scenarios_count int,
  avg_valuation_rupees numeric,
  avg_founder_pct numeric,
  avg_employee_pct numeric,
  avg_investor_pct numeric,
  locked_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.scenario_type,
           COUNT(*)::int AS scenarios_count,
           ROUND(AVG(s.assumed_exit_valuation_rupees), 0) AS avg_valuation_rupees,
           ROUND(AVG(s.founder_return_pct), 2) AS avg_founder_pct,
           ROUND(AVG(s.employee_pool_pct), 2) AS avg_employee_pct,
           ROUND(AVG(s.investor_pool_pct), 2) AS avg_investor_pct,
           (COUNT(*) FILTER (WHERE s.status = 'locked'))::int AS locked_count
    FROM public.investor_stress_test_scenarios_r1845 s
    GROUP BY s.scenario_type
    ORDER BY s.scenario_type;
END;
$$;

-- scenario_comparison
CREATE OR REPLACE FUNCTION public.scenario_comparison_r1845()
RETURNS TABLE (
  scenario_label text,
  scenario_type text,
  assumed_exit_valuation_rupees bigint,
  assumed_exit_year int,
  founder_return_pct numeric,
  founder_take_rupees numeric,
  employee_take_rupees numeric,
  investor_take_rupees numeric,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.scenario_label,
           s.scenario_type,
           s.assumed_exit_valuation_rupees,
           s.assumed_exit_year,
           s.founder_return_pct,
           ROUND(s.assumed_exit_valuation_rupees * s.founder_return_pct / 100.0, 0) AS founder_take_rupees,
           ROUND(s.assumed_exit_valuation_rupees * s.employee_pool_pct / 100.0, 0) AS employee_take_rupees,
           ROUND(s.assumed_exit_valuation_rupees * s.investor_pool_pct / 100.0, 0) AS investor_take_rupees,
           s.status
    FROM public.investor_stress_test_scenarios_r1845 s
    ORDER BY
      CASE s.scenario_type
        WHEN 'black_swan' THEN 1
        WHEN 'downside' THEN 2
        WHEN 'base' THEN 3
        WHEN 'upside' THEN 4
        ELSE 5
      END,
      s.assumed_exit_year;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_scenarios_r1845() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_scenario_r1845(text, text, bigint, int, numeric, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_assumptions_r1845(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_assumption_r1845(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.lock_scenario_r1845(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_return_outlook_r1845() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.scenario_comparison_r1845() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_scenarios_r1845() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_scenario_r1845(text, text, bigint, int, numeric, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_assumptions_r1845(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_assumption_r1845(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lock_scenario_r1845(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_return_outlook_r1845() TO authenticated;
GRANT EXECUTE ON FUNCTION public.scenario_comparison_r1845() TO authenticated;

COMMIT;