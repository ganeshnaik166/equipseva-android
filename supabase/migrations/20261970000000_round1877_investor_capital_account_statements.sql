BEGIN;

-- ============================================================================
-- Round 1877: Investor Capital Account Statements
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_capital_account_statements_r1877 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  statement_quarter text NOT NULL,
  opening_balance_rupees bigint NOT NULL DEFAULT 0,
  contributions_rupees bigint NOT NULL DEFAULT 0,
  distributions_rupees bigint NOT NULL DEFAULT 0,
  gains_losses_rupees bigint NOT NULL DEFAULT 0,
  closing_balance_rupees bigint NOT NULL DEFAULT 0,
  generated_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','acknowledged','disputed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icas_r1877_investor ON public.investor_capital_account_statements_r1877(investor_id);
CREATE INDEX IF NOT EXISTS idx_icas_r1877_quarter ON public.investor_capital_account_statements_r1877(statement_quarter);
CREATE INDEX IF NOT EXISTS idx_icas_r1877_status ON public.investor_capital_account_statements_r1877(status);

CREATE TABLE IF NOT EXISTS public.investor_capital_account_dispute_log_r1877 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  statement_id uuid NOT NULL REFERENCES public.investor_capital_account_statements_r1877(id) ON DELETE CASCADE,
  dispute_text text NOT NULL,
  raised_at timestamptz NOT NULL DEFAULT now(),
  raised_by_email text,
  resolution_at timestamptz,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_icadl_r1877_statement ON public.investor_capital_account_dispute_log_r1877(statement_id);

ALTER TABLE public.investor_capital_account_statements_r1877 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_capital_account_dispute_log_r1877 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_icas_r1877 ON public.investor_capital_account_statements_r1877;
CREATE POLICY founder_all_icas_r1877 ON public.investor_capital_account_statements_r1877
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_icadl_r1877 ON public.investor_capital_account_dispute_log_r1877;
CREATE POLICY founder_all_icadl_r1877 ON public.investor_capital_account_dispute_log_r1877
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_statements
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1877_list_statements();
CREATE OR REPLACE FUNCTION public.r1877_list_statements()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  statement_quarter text,
  opening_balance_rupees bigint,
  contributions_rupees bigint,
  distributions_rupees bigint,
  gains_losses_rupees bigint,
  closing_balance_rupees bigint,
  status text,
  generated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_id, p.email, s.statement_quarter,
         s.opening_balance_rupees, s.contributions_rupees, s.distributions_rupees,
         s.gains_losses_rupees, s.closing_balance_rupees, s.status, s.generated_at
  FROM public.investor_capital_account_statements_r1877 s
  LEFT JOIN public.profiles p ON p.id = s.investor_id
  ORDER BY s.generated_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: generate_statement
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1877_generate_statement(uuid, text, bigint, bigint, bigint, bigint);
CREATE OR REPLACE FUNCTION public.r1877_generate_statement(
  p_investor_id uuid,
  p_quarter text,
  p_opening bigint,
  p_contributions bigint,
  p_distributions bigint,
  p_gains_losses bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_closing bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_closing := p_opening + p_contributions - p_distributions + p_gains_losses;
  INSERT INTO public.investor_capital_account_statements_r1877
    (investor_id, statement_quarter, opening_balance_rupees, contributions_rupees,
     distributions_rupees, gains_losses_rupees, closing_balance_rupees, status)
  VALUES (p_investor_id, p_quarter, p_opening, p_contributions, p_distributions,
          p_gains_losses, v_closing, 'draft')
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1877_generate_statement',
          jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'quarter', p_quarter, 'closing', v_closing));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_disputes
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1877_list_disputes();
CREATE OR REPLACE FUNCTION public.r1877_list_disputes()
RETURNS TABLE (
  id uuid,
  statement_id uuid,
  investor_email text,
  statement_quarter text,
  dispute_text text,
  raised_at timestamptz,
  raised_by_email text,
  resolution_at timestamptz,
  resolution_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.statement_id, p.email, s.statement_quarter,
         d.dispute_text, d.raised_at, d.raised_by_email, d.resolution_at, d.resolution_note
  FROM public.investor_capital_account_dispute_log_r1877 d
  JOIN public.investor_capital_account_statements_r1877 s ON s.id = d.statement_id
  LEFT JOIN public.profiles p ON p.id = s.investor_id
  ORDER BY d.raised_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 4: log_dispute
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1877_log_dispute(uuid, text, text);
CREATE OR REPLACE FUNCTION public.r1877_log_dispute(
  p_statement_id uuid,
  p_dispute_text text,
  p_raised_by_email text
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
  INSERT INTO public.investor_capital_account_dispute_log_r1877
    (statement_id, dispute_text, raised_by_email)
  VALUES (p_statement_id, p_dispute_text, p_raised_by_email)
  RETURNING id INTO v_id;

  UPDATE public.investor_capital_account_statements_r1877
  SET status = 'disputed', updated_at = now()
  WHERE id = p_statement_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1877_log_dispute',
          jsonb_build_object('id', v_id, 'statement_id', p_statement_id));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: resolve_dispute
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1877_resolve_dispute(uuid, text);
CREATE OR REPLACE FUNCTION public.r1877_resolve_dispute(
  p_dispute_id uuid,
  p_resolution_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_statement_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_capital_account_dispute_log_r1877
  SET resolution_at = now(), resolution_note = p_resolution_note, updated_at = now()
  WHERE id = p_dispute_id
  RETURNING statement_id INTO v_statement_id;

  IF v_statement_id IS NOT NULL THEN
    UPDATE public.investor_capital_account_statements_r1877
    SET status = 'acknowledged', updated_at = now()
    WHERE id = v_statement_id;
  END IF;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1877_resolve_dispute',
          jsonb_build_object('dispute_id', p_dispute_id, 'statement_id', v_statement_id));
  RETURN p_dispute_id;
END;
$$;

-- ============================================================================
-- RPC 6: latest_balance
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1877_latest_balance();
CREATE OR REPLACE FUNCTION public.r1877_latest_balance()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  latest_quarter text,
  closing_balance_rupees bigint,
  generated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.investor_id)
    s.investor_id, p.email, s.statement_quarter, s.closing_balance_rupees, s.generated_at
  FROM public.investor_capital_account_statements_r1877 s
  LEFT JOIN public.profiles p ON p.id = s.investor_id
  ORDER BY s.investor_id, s.generated_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 7: top_growth
-- ============================================================================
DROP FUNCTION IF EXISTS public.r1877_top_growth();
CREATE OR REPLACE FUNCTION public.r1877_top_growth()
RETURNS TABLE (
  investor_id uuid,
  investor_email text,
  total_gains_rupees bigint,
  statement_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.investor_id,
         p.email,
         COALESCE(SUM(s.gains_losses_rupees), 0)::bigint AS total_gains_rupees,
         (COUNT(*))::int AS statement_count
  FROM public.investor_capital_account_statements_r1877 s
  LEFT JOIN public.profiles p ON p.id = s.investor_id
  GROUP BY s.investor_id, p.email
  ORDER BY total_gains_rupees DESC
  LIMIT 50;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.r1877_list_statements() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1877_generate_statement(uuid, text, bigint, bigint, bigint, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1877_list_disputes() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1877_log_dispute(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1877_resolve_dispute(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1877_latest_balance() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1877_top_growth() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1877_list_statements() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1877_generate_statement(uuid, text, bigint, bigint, bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1877_list_disputes() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1877_log_dispute(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1877_resolve_dispute(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1877_latest_balance() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1877_top_growth() TO authenticated;

COMMIT;