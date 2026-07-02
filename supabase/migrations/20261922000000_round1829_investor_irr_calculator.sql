BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_irr_calculations_r1829 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  calculation_label text NOT NULL,
  total_invested_rupees bigint NOT NULL DEFAULT 0,
  total_distributions_rupees bigint NOT NULL DEFAULT 0,
  current_value_rupees bigint NOT NULL DEFAULT 0,
  holding_period_years numeric NOT NULL DEFAULT 0,
  irr_pct numeric NOT NULL DEFAULT 0,
  dpi numeric NOT NULL DEFAULT 0,
  tvpi numeric NOT NULL DEFAULT 0,
  calculated_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','superseded','disputed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_irr_cash_flows_r1829 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  calculation_id uuid NOT NULL REFERENCES public.investor_irr_calculations_r1829(id) ON DELETE CASCADE,
  flow_date date NOT NULL,
  flow_type text NOT NULL CHECK (flow_type IN ('investment','distribution','valuation_mark')),
  amount_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irr_calc_r1829_investor ON public.investor_irr_calculations_r1829(investor_id);
CREATE INDEX IF NOT EXISTS idx_irr_calc_r1829_status ON public.investor_irr_calculations_r1829(status);
CREATE INDEX IF NOT EXISTS idx_irr_flow_r1829_calc ON public.investor_irr_cash_flows_r1829(calculation_id);
CREATE INDEX IF NOT EXISTS idx_irr_flow_r1829_date ON public.investor_irr_cash_flows_r1829(flow_date);

ALTER TABLE public.investor_irr_calculations_r1829 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_irr_cash_flows_r1829 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_irr_calc_r1829 ON public.investor_irr_calculations_r1829;
CREATE POLICY founder_all_irr_calc_r1829 ON public.investor_irr_calculations_r1829
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_irr_flow_r1829 ON public.investor_irr_cash_flows_r1829;
CREATE POLICY founder_all_irr_flow_r1829 ON public.investor_irr_cash_flows_r1829
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_calculations_r1829()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  calculation_label text,
  total_invested_rupees bigint,
  total_distributions_rupees bigint,
  current_value_rupees bigint,
  holding_period_years numeric,
  irr_pct numeric,
  dpi numeric,
  tvpi numeric,
  status text,
  calculated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.investor_id, p.email, c.calculation_label,
         c.total_invested_rupees, c.total_distributions_rupees, c.current_value_rupees,
         c.holding_period_years, c.irr_pct, c.dpi, c.tvpi, c.status, c.calculated_at
  FROM public.investor_irr_calculations_r1829 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY c.calculated_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.run_calculation_r1829(
  p_investor_id uuid,
  p_label text,
  p_invested bigint,
  p_distributions bigint,
  p_current_value bigint,
  p_years numeric,
  p_irr_pct numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_dpi numeric;
  v_tvpi numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_dpi := CASE WHEN p_invested > 0 THEN ROUND((p_distributions::numeric / p_invested::numeric), 4) ELSE 0 END;
  v_tvpi := CASE WHEN p_invested > 0 THEN ROUND(((p_distributions + p_current_value)::numeric / p_invested::numeric), 4) ELSE 0 END;

  UPDATE public.investor_irr_calculations_r1829
    SET status = 'superseded', updated_at = now()
    WHERE investor_id = p_investor_id AND status = 'current';

  INSERT INTO public.investor_irr_calculations_r1829(
    investor_id, calculation_label, total_invested_rupees, total_distributions_rupees,
    current_value_rupees, holding_period_years, irr_pct, dpi, tvpi, status
  )
  VALUES (p_investor_id, p_label, p_invested, p_distributions, p_current_value,
          p_years, p_irr_pct, v_dpi, v_tvpi, 'current')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'run_calculation_r1829',
          jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'irr_pct', p_irr_pct));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_cash_flows_r1829(p_calculation_id uuid)
RETURNS TABLE (
  id uuid,
  calculation_id uuid,
  flow_date date,
  flow_type text,
  amount_rupees bigint,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.calculation_id, f.flow_date, f.flow_type, f.amount_rupees, f.notes, f.created_at
  FROM public.investor_irr_cash_flows_r1829 f
  WHERE f.calculation_id = p_calculation_id
  ORDER BY f.flow_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_cash_flow_r1829(
  p_calculation_id uuid,
  p_flow_date date,
  p_flow_type text,
  p_amount bigint,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_irr_cash_flows_r1829(calculation_id, flow_date, flow_type, amount_rupees, notes)
  VALUES (p_calculation_id, p_flow_date, p_flow_type, p_amount, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cash_flow_r1829',
          jsonb_build_object('id', v_id, 'calculation_id', p_calculation_id, 'flow_type', p_flow_type, 'amount', p_amount));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_disputed_r1829(p_calculation_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_irr_calculations_r1829
    SET status = 'disputed', updated_at = now()
    WHERE id = p_calculation_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_disputed_r1829',
          jsonb_build_object('id', p_calculation_id, 'reason', p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION public.irr_leaderboard_r1829()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  best_irr_pct numeric,
  best_tvpi numeric,
  best_dpi numeric,
  calc_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.investor_id,
         p.email,
         MAX(c.irr_pct) AS best_irr_pct,
         MAX(c.tvpi) AS best_tvpi,
         MAX(c.dpi) AS best_dpi,
         (COUNT(*) FILTER (WHERE c.status = 'current'))::int AS calc_count
  FROM public.investor_irr_calculations_r1829 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  GROUP BY c.investor_id, p.email
  ORDER BY best_irr_pct DESC NULLS LAST
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_calculations_r1829()
RETURNS TABLE (
  id uuid,
  investor_email text,
  calculation_label text,
  irr_pct numeric,
  tvpi numeric,
  dpi numeric,
  status text,
  calculated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, p.email, c.calculation_label, c.irr_pct, c.tvpi, c.dpi, c.status, c.calculated_at
  FROM public.investor_irr_calculations_r1829 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  WHERE c.calculated_at >= now() - interval '30 days'
  ORDER BY c.calculated_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_calculations_r1829() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.run_calculation_r1829(uuid, text, bigint, bigint, bigint, numeric, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_cash_flows_r1829(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cash_flow_r1829(uuid, date, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_disputed_r1829(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.irr_leaderboard_r1829() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_calculations_r1829() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_calculations_r1829() TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_calculation_r1829(uuid, text, bigint, bigint, bigint, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_cash_flows_r1829(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cash_flow_r1829(uuid, date, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_disputed_r1829(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.irr_leaderboard_r1829() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_calculations_r1829() TO authenticated;

COMMIT;