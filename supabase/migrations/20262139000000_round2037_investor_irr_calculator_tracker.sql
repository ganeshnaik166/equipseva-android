BEGIN;

-- ============================================================================
-- Round 2037: Investor IRR Calculator Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_irr_calculations_r2037 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  invested_rupees bigint NOT NULL DEFAULT 0,
  current_value_rupees bigint NOT NULL DEFAULT 0,
  irr_pct numeric(8,4) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','sent','disputed')),
  calculated_at timestamptz,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irr_calc_r2037_investor ON public.investor_irr_calculations_r2037(investor_id);
CREATE INDEX IF NOT EXISTS idx_irr_calc_r2037_status ON public.investor_irr_calculations_r2037(status);
CREATE INDEX IF NOT EXISTS idx_irr_calc_r2037_created ON public.investor_irr_calculations_r2037(created_at DESC);

CREATE TABLE IF NOT EXISTS public.investor_irr_action_log_r2037 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  calc_id uuid NOT NULL REFERENCES public.investor_irr_calculations_r2037(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('calculated','approved','sent','disputed','recalculated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irr_log_r2037_calc ON public.investor_irr_action_log_r2037(calc_id);
CREATE INDEX IF NOT EXISTS idx_irr_log_r2037_type ON public.investor_irr_action_log_r2037(action_type);
CREATE INDEX IF NOT EXISTS idx_irr_log_r2037_taken ON public.investor_irr_action_log_r2037(taken_at DESC);

ALTER TABLE public.investor_irr_calculations_r2037 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_irr_action_log_r2037 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_irr_calc_r2037 ON public.investor_irr_calculations_r2037;
CREATE POLICY founder_all_irr_calc_r2037 ON public.investor_irr_calculations_r2037
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_irr_log_r2037 ON public.investor_irr_action_log_r2037;
CREATE POLICY founder_all_irr_log_r2037 ON public.investor_irr_action_log_r2037
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_calcs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_irr_calcs_r2037()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  period_label text,
  invested_rupees bigint,
  current_value_rupees bigint,
  irr_pct numeric,
  status text,
  calculated_at timestamptz,
  approved_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.investor_id, p.email, c.period_label, c.invested_rupees, c.current_value_rupees,
         c.irr_pct, c.status, c.calculated_at, c.approved_at, c.created_at
  FROM public.investor_irr_calculations_r2037 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: log_calc
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_irr_calc_r2037(
  p_investor_id uuid,
  p_period_label text,
  p_invested bigint,
  p_current_value bigint,
  p_irr_pct numeric
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

  INSERT INTO public.investor_irr_calculations_r2037 (
    investor_id, period_label, invested_rupees, current_value_rupees, irr_pct, status, calculated_at
  ) VALUES (
    p_investor_id, p_period_label, p_invested, p_current_value, p_irr_pct, 'draft', now()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_irr_calc_r2037',
          jsonb_build_object('calc_id', v_id, 'investor_id', p_investor_id, 'irr_pct', p_irr_pct));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_irr_actions_r2037(p_calc_id uuid)
RETURNS TABLE (
  id uuid,
  calc_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.calc_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_irr_action_log_r2037 a
  WHERE a.calc_id = p_calc_id
  ORDER BY a.taken_at DESC;
END;
$$;

-- ============================================================================
-- RPC 4: log_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_irr_action_r2037(
  p_calc_id uuid,
  p_action_type text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.investor_irr_action_log_r2037 (calc_id, action_type, taken_at, by_email, notes_md)
  VALUES (p_calc_id, p_action_type, now(), v_email, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_irr_action_r2037',
          jsonb_build_object('log_id', v_id, 'calc_id', p_calc_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_irr_status_r2037(
  p_calc_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.investor_irr_calculations_r2037
  SET status = p_status,
      approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE approved_at END,
      updated_at = now()
  WHERE id = p_calc_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_irr_status_r2037',
          jsonb_build_object('calc_id', p_calc_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 6: top_irrs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_irrs_r2037()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  period_label text,
  irr_pct numeric,
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
  SELECT c.id, c.investor_id, p.email, c.period_label, c.irr_pct, c.status, c.calculated_at
  FROM public.investor_irr_calculations_r2037 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY c.irr_pct DESC NULLS LAST
  LIMIT 25;
END;
$$;

-- ============================================================================
-- RPC 7: recent_actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_irr_actions_r2037()
RETURNS TABLE (
  id uuid,
  calc_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.calc_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.investor_irr_action_log_r2037 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_irr_calcs_r2037() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_irr_calc_r2037(uuid, text, bigint, bigint, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_irr_actions_r2037(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_irr_action_r2037(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_irr_status_r2037(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_irrs_r2037() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_irr_actions_r2037() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_irr_calcs_r2037() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_irr_calc_r2037(uuid, text, bigint, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_irr_actions_r2037(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_irr_action_r2037(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_irr_status_r2037(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_irrs_r2037() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_irr_actions_r2037() TO authenticated;

COMMIT;
