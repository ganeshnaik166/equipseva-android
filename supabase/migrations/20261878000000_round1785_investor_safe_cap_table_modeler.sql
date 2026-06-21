BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_safe_conversion_models_r1785 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_name text NOT NULL,
  modeled_valuation_rupees bigint NOT NULL DEFAULT 0,
  total_safe_amount_rupees bigint NOT NULL DEFAULT 0,
  conversion_share_count bigint NOT NULL DEFAULT 0,
  founder_ownership_after_pct numeric(6,2) NOT NULL DEFAULT 0,
  modeled_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','baseline','scenario','locked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_safe_conversion_scenarios_r1785 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id uuid NOT NULL REFERENCES public.investor_safe_conversion_models_r1785(id) ON DELETE CASCADE,
  scenario_label text NOT NULL,
  assumption_md text,
  founder_pct_after numeric(6,2) NOT NULL DEFAULT 0,
  employee_pool_after_pct numeric(6,2) NOT NULL DEFAULT 0,
  investor_pct_after numeric(6,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_safe_conversion_models_r1785 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_safe_conversion_scenarios_r1785 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_models_r1785 ON public.investor_safe_conversion_models_r1785;
CREATE POLICY founder_all_models_r1785 ON public.investor_safe_conversion_models_r1785
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_scenarios_r1785 ON public.investor_safe_conversion_scenarios_r1785;
CREATE POLICY founder_all_scenarios_r1785 ON public.investor_safe_conversion_scenarios_r1785
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_safe_models_r1785_status ON public.investor_safe_conversion_models_r1785(status);
CREATE INDEX IF NOT EXISTS idx_safe_scenarios_r1785_model ON public.investor_safe_conversion_scenarios_r1785(model_id);

DROP FUNCTION IF EXISTS public.list_safe_models_r1785();
CREATE OR REPLACE FUNCTION public.list_safe_models_r1785()
RETURNS TABLE (
  id uuid,
  model_name text,
  modeled_valuation_rupees bigint,
  total_safe_amount_rupees bigint,
  conversion_share_count bigint,
  founder_ownership_after_pct numeric,
  modeled_at timestamptz,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.model_name, m.modeled_valuation_rupees, m.total_safe_amount_rupees,
           m.conversion_share_count, m.founder_ownership_after_pct, m.modeled_at, m.status
      FROM public.investor_safe_conversion_models_r1785 m
      ORDER BY m.modeled_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.save_safe_model_r1785(text, bigint, bigint, bigint, numeric, text);
CREATE OR REPLACE FUNCTION public.save_safe_model_r1785(
  p_model_name text,
  p_modeled_valuation_rupees bigint,
  p_total_safe_amount_rupees bigint,
  p_conversion_share_count bigint,
  p_founder_ownership_after_pct numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_safe_conversion_models_r1785(
    model_name, modeled_valuation_rupees, total_safe_amount_rupees,
    conversion_share_count, founder_ownership_after_pct, status
  ) VALUES (
    p_model_name, COALESCE(p_modeled_valuation_rupees,0), COALESCE(p_total_safe_amount_rupees,0),
    COALESCE(p_conversion_share_count,0), COALESCE(p_founder_ownership_after_pct,0),
    COALESCE(p_status,'draft')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_safe_model_r1785',
          jsonb_build_object('id', v_id, 'model_name', p_model_name, 'status', p_status));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_safe_scenarios_r1785(uuid);
CREATE OR REPLACE FUNCTION public.list_safe_scenarios_r1785(p_model_id uuid)
RETURNS TABLE (
  id uuid,
  model_id uuid,
  scenario_label text,
  assumption_md text,
  founder_pct_after numeric,
  employee_pool_after_pct numeric,
  investor_pct_after numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.model_id, s.scenario_label, s.assumption_md,
           s.founder_pct_after, s.employee_pool_after_pct, s.investor_pct_after, s.created_at
      FROM public.investor_safe_conversion_scenarios_r1785 s
      WHERE p_model_id IS NULL OR s.model_id = p_model_id
      ORDER BY s.created_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.log_safe_scenario_r1785(uuid, text, text, numeric, numeric, numeric);
CREATE OR REPLACE FUNCTION public.log_safe_scenario_r1785(
  p_model_id uuid,
  p_scenario_label text,
  p_assumption_md text,
  p_founder_pct_after numeric,
  p_employee_pool_after_pct numeric,
  p_investor_pct_after numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_safe_conversion_scenarios_r1785(
    model_id, scenario_label, assumption_md,
    founder_pct_after, employee_pool_after_pct, investor_pct_after
  ) VALUES (
    p_model_id, p_scenario_label, p_assumption_md,
    COALESCE(p_founder_pct_after,0), COALESCE(p_employee_pool_after_pct,0), COALESCE(p_investor_pct_after,0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_safe_scenario_r1785',
          jsonb_build_object('id', v_id, 'model_id', p_model_id, 'scenario_label', p_scenario_label));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.lock_safe_model_r1785(uuid);
CREATE OR REPLACE FUNCTION public.lock_safe_model_r1785(p_model_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.investor_safe_conversion_models_r1785
     SET status = 'locked', updated_at = now()
   WHERE id = p_model_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'lock_safe_model_r1785',
          jsonb_build_object('id', p_model_id));

  RETURN true;
END;
$$;

DROP FUNCTION IF EXISTS public.founder_dilution_outlook_r1785();
CREATE OR REPLACE FUNCTION public.founder_dilution_outlook_r1785()
RETURNS TABLE (
  total_models int,
  locked_models int,
  baseline_models int,
  avg_founder_pct numeric,
  min_founder_pct numeric,
  total_safe_amount_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (COUNT(*))::int,
      (COUNT(*) FILTER (WHERE status = 'locked'))::int,
      (COUNT(*) FILTER (WHERE status = 'baseline'))::int,
      COALESCE(AVG(founder_ownership_after_pct), 0)::numeric,
      COALESCE(MIN(founder_ownership_after_pct), 0)::numeric,
      COALESCE(SUM(total_safe_amount_rupees), 0)::bigint
    FROM public.investor_safe_conversion_models_r1785;
END;
$$;

DROP FUNCTION IF EXISTS public.safe_scenario_comparison_r1785(uuid);
CREATE OR REPLACE FUNCTION public.safe_scenario_comparison_r1785(p_model_id uuid)
RETURNS TABLE (
  scenario_label text,
  founder_pct_after numeric,
  employee_pool_after_pct numeric,
  investor_pct_after numeric,
  total_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      s.scenario_label,
      s.founder_pct_after,
      s.employee_pool_after_pct,
      s.investor_pct_after,
      (COALESCE(s.founder_pct_after,0) + COALESCE(s.employee_pool_after_pct,0) + COALESCE(s.investor_pct_after,0))::numeric AS total_pct
    FROM public.investor_safe_conversion_scenarios_r1785 s
    WHERE p_model_id IS NULL OR s.model_id = p_model_id
    ORDER BY s.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_safe_models_r1785() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_safe_model_r1785(text, bigint, bigint, bigint, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_safe_scenarios_r1785(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_safe_scenario_r1785(uuid, text, text, numeric, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.lock_safe_model_r1785(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_dilution_outlook_r1785() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.safe_scenario_comparison_r1785(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_safe_models_r1785() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_safe_model_r1785(text, bigint, bigint, bigint, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_safe_scenarios_r1785(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_safe_scenario_r1785(uuid, text, text, numeric, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lock_safe_model_r1785(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_dilution_outlook_r1785() TO authenticated;
GRANT EXECUTE ON FUNCTION public.safe_scenario_comparison_r1785(uuid) TO authenticated;

COMMIT;