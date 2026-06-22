BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_crypto_treasury_r1957 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_symbol text NOT NULL CHECK (asset_symbol IN ('BTC','ETH','USDC','USDT','OTHER')),
  holding_quantity numeric NOT NULL DEFAULT 0,
  avg_cost_basis_rupees numeric NOT NULL DEFAULT 0,
  current_value_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','divested','restricted','locked')),
  custodian text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_crypto_treasury_log_r1957 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  treasury_id uuid NOT NULL REFERENCES public.investor_crypto_treasury_r1957(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('purchase','sale','transfer','yield_earned','loss_recognized','custody_change')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  quantity_change numeric NOT NULL DEFAULT 0,
  value_change_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_crypto_treasury_r1957 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_crypto_treasury_log_r1957 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_treasury_r1957 ON public.investor_crypto_treasury_r1957;
CREATE POLICY founder_all_treasury_r1957 ON public.investor_crypto_treasury_r1957
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_treasury_log_r1957 ON public.investor_crypto_treasury_log_r1957;
CREATE POLICY founder_all_treasury_log_r1957 ON public.investor_crypto_treasury_log_r1957
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_crypto_holdings_r1957()
RETURNS SETOF public.investor_crypto_treasury_r1957
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_crypto_treasury_r1957 ORDER BY recorded_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_crypto_holding_r1957(
  p_asset_symbol text,
  p_holding_quantity numeric,
  p_avg_cost_basis_rupees numeric,
  p_current_value_rupees bigint,
  p_status text,
  p_custodian text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_crypto_treasury_r1957(asset_symbol, holding_quantity, avg_cost_basis_rupees, current_value_rupees, status, custodian)
  VALUES (p_asset_symbol, p_holding_quantity, p_avg_cost_basis_rupees, p_current_value_rupees, COALESCE(p_status,'active'), p_custodian)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_crypto_holding_r1957', jsonb_build_object('id', v_id, 'asset_symbol', p_asset_symbol, 'quantity', p_holding_quantity));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_crypto_actions_r1957(p_treasury_id uuid)
RETURNS SETOF public.investor_crypto_treasury_log_r1957
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_crypto_treasury_log_r1957 WHERE treasury_id = p_treasury_id ORDER BY taken_at DESC LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_crypto_action_r1957(
  p_treasury_id uuid,
  p_action_type text,
  p_by_email text,
  p_quantity_change numeric,
  p_value_change_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_crypto_treasury_log_r1957(treasury_id, action_type, by_email, quantity_change, value_change_rupees)
  VALUES (p_treasury_id, p_action_type, p_by_email, COALESCE(p_quantity_change,0), COALESCE(p_value_change_rupees,0))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_crypto_action_r1957', jsonb_build_object('id', v_id, 'treasury_id', p_treasury_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_crypto_status_r1957(p_treasury_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_crypto_treasury_r1957 SET status = p_status, updated_at = now() WHERE id = p_treasury_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_crypto_status_r1957', jsonb_build_object('id', p_treasury_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.total_crypto_value_r1957()
RETURNS TABLE(asset_symbol text, holdings_count bigint, total_value_rupees bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.asset_symbol, count(*)::bigint, COALESCE(sum(t.current_value_rupees),0)::bigint
  FROM public.investor_crypto_treasury_r1957 t
  WHERE t.status = 'active'
  GROUP BY t.asset_symbol
  ORDER BY t.asset_symbol;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_crypto_actions_r1957()
RETURNS SETOF public.investor_crypto_treasury_log_r1957
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.investor_crypto_treasury_log_r1957 ORDER BY taken_at DESC LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_crypto_holdings_r1957() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_crypto_holding_r1957(text, numeric, numeric, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_crypto_actions_r1957(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_crypto_action_r1957(uuid, text, text, numeric, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_crypto_status_r1957(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_crypto_value_r1957() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_crypto_actions_r1957() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_crypto_holdings_r1957() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_crypto_holding_r1957(text, numeric, numeric, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_crypto_actions_r1957(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_crypto_action_r1957(uuid, text, text, numeric, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_crypto_status_r1957(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_crypto_value_r1957() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_crypto_actions_r1957() TO authenticated;

COMMIT;
