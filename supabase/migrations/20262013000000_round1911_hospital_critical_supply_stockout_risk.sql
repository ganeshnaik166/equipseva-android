BEGIN;

-- ============================================================================
-- Round 1911: Hospital Critical Supply Stockout Risk
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_critical_supply_stockout_r1911 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  supply_name text NOT NULL,
  supply_category text NOT NULL CHECK (supply_category IN ('consumable','spare','medication','diagnostic')),
  current_stock_units int NOT NULL DEFAULT 0,
  reorder_point int NOT NULL DEFAULT 0,
  days_until_stockout int NOT NULL DEFAULT 0,
  risk_level text NOT NULL CHECK (risk_level IN ('none','watch','concern','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stockout_r1911_hospital ON public.hospital_critical_supply_stockout_r1911(hospital_id);
CREATE INDEX IF NOT EXISTS idx_stockout_r1911_risk ON public.hospital_critical_supply_stockout_r1911(risk_level);
CREATE INDEX IF NOT EXISTS idx_stockout_r1911_captured ON public.hospital_critical_supply_stockout_r1911(captured_at DESC);

CREATE TABLE IF NOT EXISTS public.hospital_stockout_action_log_r1911 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stockout_id uuid NOT NULL REFERENCES public.hospital_critical_supply_stockout_r1911(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('reorder_placed','escalated','alternate_sourced','customer_notified')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_action_log_r1911_stockout ON public.hospital_stockout_action_log_r1911(stockout_id);
CREATE INDEX IF NOT EXISTS idx_action_log_r1911_taken ON public.hospital_stockout_action_log_r1911(taken_at DESC);

ALTER TABLE public.hospital_critical_supply_stockout_r1911 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_stockout_action_log_r1911 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_stockout_r1911 ON public.hospital_critical_supply_stockout_r1911;
CREATE POLICY founder_all_stockout_r1911 ON public.hospital_critical_supply_stockout_r1911
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r1911 ON public.hospital_stockout_action_log_r1911;
CREATE POLICY founder_all_action_log_r1911 ON public.hospital_stockout_action_log_r1911
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_stockouts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_stockouts_r1911()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  supply_name text,
  supply_category text,
  current_stock_units int,
  reorder_point int,
  days_until_stockout int,
  risk_level text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_id, COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
         s.supply_name, s.supply_category, s.current_stock_units, s.reorder_point,
         s.days_until_stockout, s.risk_level, s.captured_at
  FROM public.hospital_critical_supply_stockout_r1911 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY
    CASE s.risk_level WHEN 'critical' THEN 1 WHEN 'concern' THEN 2 WHEN 'watch' THEN 3 ELSE 4 END,
    s.days_until_stockout ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_stockouts_r1911() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_stockouts_r1911() TO authenticated;

-- ============================================================================
-- RPC 2: log_stockout
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_stockout_r1911(
  p_hospital_id uuid,
  p_supply_name text,
  p_supply_category text,
  p_current_stock_units int,
  p_reorder_point int,
  p_days_until_stockout int,
  p_risk_level text
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
  INSERT INTO public.hospital_critical_supply_stockout_r1911(
    hospital_id, supply_name, supply_category, current_stock_units, reorder_point,
    days_until_stockout, risk_level
  ) VALUES (
    p_hospital_id, p_supply_name, p_supply_category, p_current_stock_units, p_reorder_point,
    p_days_until_stockout, p_risk_level
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_stockout_r1911',
    jsonb_build_object('stockout_id', v_id, 'hospital_id', p_hospital_id, 'supply', p_supply_name, 'risk', p_risk_level));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_stockout_r1911(uuid, text, text, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_stockout_r1911(uuid, text, text, int, int, int, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_actions_r1911()
RETURNS TABLE (
  id uuid,
  stockout_id uuid,
  supply_name text,
  hospital_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.stockout_id, s.supply_name,
         COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
         a.action_type, a.taken_at, a.by_email, a.outcome
  FROM public.hospital_stockout_action_log_r1911 a
  JOIN public.hospital_critical_supply_stockout_r1911 s ON s.id = a.stockout_id
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY a.taken_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_actions_r1911() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r1911() TO authenticated;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r1911(
  p_stockout_id uuid,
  p_action_type text,
  p_outcome text
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
  INSERT INTO public.hospital_stockout_action_log_r1911(stockout_id, action_type, by_email, outcome)
  VALUES (p_stockout_id, p_action_type, (auth.jwt()->>'email'), p_outcome)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1911',
    jsonb_build_object('action_id', v_id, 'stockout_id', p_stockout_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_action_r1911(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r1911(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_reordered
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_reordered_r1911(
  p_stockout_id uuid,
  p_outcome text
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
  INSERT INTO public.hospital_stockout_action_log_r1911(stockout_id, action_type, by_email, outcome)
  VALUES (p_stockout_id, 'reorder_placed', (auth.jwt()->>'email'), p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.hospital_critical_supply_stockout_r1911
  SET risk_level = 'watch', updated_at = now()
  WHERE id = p_stockout_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_reordered_r1911',
    jsonb_build_object('action_id', v_id, 'stockout_id', p_stockout_id));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_reordered_r1911(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_reordered_r1911(uuid, text) TO authenticated;

-- ============================================================================
-- RPC 6: critical_only
-- ============================================================================
CREATE OR REPLACE FUNCTION public.critical_only_r1911()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  supply_name text,
  supply_category text,
  current_stock_units int,
  days_until_stockout int,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
         s.supply_name, s.supply_category, s.current_stock_units,
         s.days_until_stockout, s.captured_at
  FROM public.hospital_critical_supply_stockout_r1911 s
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE s.risk_level = 'critical'
  ORDER BY s.days_until_stockout ASC, s.captured_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.critical_only_r1911() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.critical_only_r1911() TO authenticated;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r1911()
RETURNS TABLE (
  id uuid,
  stockout_id uuid,
  supply_name text,
  hospital_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.stockout_id, s.supply_name,
         COALESCE(o.name, p.full_name, 'Unknown') AS hospital_name,
         a.action_type, a.taken_at, a.by_email, a.outcome
  FROM public.hospital_stockout_action_log_r1911 a
  JOIN public.hospital_critical_supply_stockout_r1911 s ON s.id = a.stockout_id
  LEFT JOIN public.profiles p ON p.id = s.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE a.taken_at > now() - interval '14 days'
  ORDER BY a.taken_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_actions_r1911() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1911() TO authenticated;

COMMIT;
