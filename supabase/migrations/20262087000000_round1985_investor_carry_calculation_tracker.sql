BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_carry_calculations_r1985 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  gross_returns_rupees bigint NOT NULL DEFAULT 0,
  lp_returns_rupees bigint NOT NULL DEFAULT 0,
  gp_carry_rupees bigint NOT NULL DEFAULT 0,
  carry_rate_pct numeric(6,3) NOT NULL DEFAULT 20.000,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','paid','disputed','voided')),
  calculated_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_carry_action_log_r1985 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  calc_id uuid NOT NULL REFERENCES public.investor_carry_calculations_r1985(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('calculated','approved','disputed','paid','voided','recalculated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  amount_rupees bigint,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_carry_calculations_r1985 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_carry_action_log_r1985 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_founder_calcs_r1985 ON public.investor_carry_calculations_r1985;
CREATE POLICY p_founder_calcs_r1985 ON public.investor_carry_calculations_r1985
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_founder_actions_r1985 ON public.investor_carry_action_log_r1985;
CREATE POLICY p_founder_actions_r1985 ON public.investor_carry_action_log_r1985
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_calcs_r1985_status ON public.investor_carry_calculations_r1985(status);
CREATE INDEX IF NOT EXISTS idx_calcs_r1985_investor ON public.investor_carry_calculations_r1985(investor_id);
CREATE INDEX IF NOT EXISTS idx_actions_r1985_calc ON public.investor_carry_action_log_r1985(calc_id);
CREATE INDEX IF NOT EXISTS idx_actions_r1985_taken ON public.investor_carry_action_log_r1985(taken_at DESC);

CREATE OR REPLACE FUNCTION public.list_calcs_r1985(p_limit int DEFAULT 100)
RETURNS TABLE(id uuid, investor_id uuid, period_label text, gross_returns_rupees bigint, lp_returns_rupees bigint, gp_carry_rupees bigint, carry_rate_pct numeric, status text, calculated_at timestamptz, paid_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.investor_id, c.period_label, c.gross_returns_rupees, c.lp_returns_rupees, c.gp_carry_rupees, c.carry_rate_pct, c.status, c.calculated_at, c.paid_at
    FROM public.investor_carry_calculations_r1985 c
    ORDER BY c.calculated_at DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 100));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_calc_r1985(
  p_investor_id uuid,
  p_period_label text,
  p_gross_returns_rupees bigint,
  p_lp_returns_rupees bigint,
  p_gp_carry_rupees bigint,
  p_carry_rate_pct numeric
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_carry_calculations_r1985(investor_id, period_label, gross_returns_rupees, lp_returns_rupees, gp_carry_rupees, carry_rate_pct)
  VALUES (p_investor_id, p_period_label, COALESCE(p_gross_returns_rupees,0), COALESCE(p_lp_returns_rupees,0), COALESCE(p_gp_carry_rupees,0), COALESCE(p_carry_rate_pct,20))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_calc_r1985', jsonb_build_object('calc_id', v_id, 'investor_id', p_investor_id, 'period_label', p_period_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1985(p_calc_id uuid, p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, calc_id uuid, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.calc_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_carry_action_log_r1985 a
    WHERE a.calc_id = p_calc_id
    ORDER BY a.taken_at DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1985(
  p_calc_id uuid,
  p_action_type text,
  p_by_email text,
  p_amount_rupees bigint,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_carry_action_log_r1985(calc_id, action_type, by_email, amount_rupees, notes_md)
  VALUES (p_calc_id, p_action_type, p_by_email, p_amount_rupees, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r1985', jsonb_build_object('action_id', v_id, 'calc_id', p_calc_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1985(p_calc_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('draft','approved','paid','disputed','voided') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_carry_calculations_r1985
     SET status = p_status,
         paid_at = CASE WHEN p_status = 'paid' THEN now() ELSE paid_at END,
         updated_at = now()
   WHERE id = p_calc_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1985', jsonb_build_object('calc_id', p_calc_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.total_paid_r1985()
RETURNS TABLE(total_paid_rupees bigint, paid_count bigint, draft_count bigint, approved_count bigint, disputed_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      COALESCE(SUM(CASE WHEN status = 'paid' THEN gp_carry_rupees ELSE 0 END), 0)::bigint,
      COUNT(*) FILTER (WHERE status = 'paid')::bigint,
      COUNT(*) FILTER (WHERE status = 'draft')::bigint,
      COUNT(*) FILTER (WHERE status = 'approved')::bigint,
      COUNT(*) FILTER (WHERE status = 'disputed')::bigint
    FROM public.investor_carry_calculations_r1985;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r1985(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, calc_id uuid, action_type text, taken_at timestamptz, by_email text, amount_rupees bigint, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.calc_id, a.action_type, a.taken_at, a.by_email, a.amount_rupees, a.notes_md
    FROM public.investor_carry_action_log_r1985 a
    ORDER BY a.taken_at DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_calcs_r1985(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_calc_r1985(uuid, text, bigint, bigint, bigint, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1985(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1985(uuid, text, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1985(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_paid_r1985() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r1985(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_calcs_r1985(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_calc_r1985(uuid, text, bigint, bigint, bigint, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1985(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1985(uuid, text, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1985(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_paid_r1985() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r1985(int) TO authenticated;

COMMIT;
