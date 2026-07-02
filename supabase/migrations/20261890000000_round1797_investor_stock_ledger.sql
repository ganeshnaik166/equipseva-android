BEGIN;

-- =====================================================================
-- Round 1797 — Investor Stock Ledger (authoritative legal source of truth)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.investor_stock_ledger_r1797 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  holder_name text NOT NULL,
  holder_type text NOT NULL CHECK (holder_type IN ('founder','employee','investor','advisor','option_pool')),
  share_class text NOT NULL CHECK (share_class IN ('common','preferred_a','preferred_b','warrant','option')),
  shares_held bigint NOT NULL DEFAULT 0 CHECK (shares_held >= 0),
  certificate_number text,
  issued_date date NOT NULL DEFAULT CURRENT_DATE,
  current_balance bigint NOT NULL DEFAULT 0 CHECK (current_balance >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','transferred','exercised','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_stock_transactions_r1797 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ledger_id uuid NOT NULL REFERENCES public.investor_stock_ledger_r1797(id) ON DELETE CASCADE,
  transaction_type text NOT NULL CHECK (transaction_type IN ('issuance','transfer','exercise','cancellation','conversion')),
  transaction_date date NOT NULL DEFAULT CURRENT_DATE,
  shares_delta bigint NOT NULL,
  counterparty_holder text,
  transaction_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isl_r1797_holder_type ON public.investor_stock_ledger_r1797(holder_type);
CREATE INDEX IF NOT EXISTS idx_isl_r1797_share_class ON public.investor_stock_ledger_r1797(share_class);
CREATE INDEX IF NOT EXISTS idx_isl_r1797_status ON public.investor_stock_ledger_r1797(status);
CREATE INDEX IF NOT EXISTS idx_ist_r1797_ledger ON public.investor_stock_transactions_r1797(ledger_id);
CREATE INDEX IF NOT EXISTS idx_ist_r1797_type ON public.investor_stock_transactions_r1797(transaction_type);
CREATE INDEX IF NOT EXISTS idx_ist_r1797_date ON public.investor_stock_transactions_r1797(transaction_date DESC);

ALTER TABLE public.investor_stock_ledger_r1797 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_stock_transactions_r1797 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_isl_r1797 ON public.investor_stock_ledger_r1797;
CREATE POLICY founder_all_isl_r1797 ON public.investor_stock_ledger_r1797
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_ist_r1797 ON public.investor_stock_transactions_r1797;
CREATE POLICY founder_all_ist_r1797 ON public.investor_stock_transactions_r1797
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_ledger
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_ledger_r1797();
CREATE OR REPLACE FUNCTION public.list_ledger_r1797()
RETURNS TABLE (
  id uuid,
  holder_name text,
  holder_type text,
  share_class text,
  shares_held bigint,
  certificate_number text,
  issued_date date,
  current_balance bigint,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.holder_name, l.holder_type, l.share_class, l.shares_held,
         l.certificate_number, l.issued_date, l.current_balance, l.status, l.created_at
  FROM public.investor_stock_ledger_r1797 l
  ORDER BY l.current_balance DESC, l.created_at DESC;
END;
$$;

-- =====================================================================
-- RPC 2: add_holder
-- =====================================================================
DROP FUNCTION IF EXISTS public.add_holder_r1797(text, text, text, bigint, text, date);
CREATE OR REPLACE FUNCTION public.add_holder_r1797(
  p_holder_name text,
  p_holder_type text,
  p_share_class text,
  p_shares_held bigint,
  p_certificate_number text DEFAULT NULL,
  p_issued_date date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_stock_ledger_r1797
    (holder_name, holder_type, share_class, shares_held, certificate_number, issued_date, current_balance, status)
  VALUES (p_holder_name, p_holder_type, p_share_class, p_shares_held, p_certificate_number, p_issued_date, p_shares_held, 'active')
  RETURNING id INTO v_id;

  INSERT INTO public.investor_stock_transactions_r1797
    (ledger_id, transaction_type, transaction_date, shares_delta, transaction_note)
  VALUES (v_id, 'issuance', p_issued_date, p_shares_held, 'Initial issuance');

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_holder_r1797',
    jsonb_build_object('ledger_id', v_id, 'holder_name', p_holder_name, 'holder_type', p_holder_type, 'share_class', p_share_class, 'shares', p_shares_held));

  RETURN v_id;
END;
$$;

-- =====================================================================
-- RPC 3: list_transactions
-- =====================================================================
DROP FUNCTION IF EXISTS public.list_transactions_r1797(uuid);
CREATE OR REPLACE FUNCTION public.list_transactions_r1797(p_ledger_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  ledger_id uuid,
  holder_name text,
  transaction_type text,
  transaction_date date,
  shares_delta bigint,
  counterparty_holder text,
  transaction_note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.ledger_id, l.holder_name, t.transaction_type, t.transaction_date,
         t.shares_delta, t.counterparty_holder, t.transaction_note, t.created_at
  FROM public.investor_stock_transactions_r1797 t
  JOIN public.investor_stock_ledger_r1797 l ON l.id = t.ledger_id
  WHERE (p_ledger_id IS NULL OR t.ledger_id = p_ledger_id)
  ORDER BY t.transaction_date DESC, t.created_at DESC
  LIMIT 500;
END;
$$;

-- =====================================================================
-- RPC 4: log_transaction
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_transaction_r1797(uuid, text, bigint, text, text, date);
CREATE OR REPLACE FUNCTION public.log_transaction_r1797(
  p_ledger_id uuid,
  p_transaction_type text,
  p_shares_delta bigint,
  p_counterparty_holder text DEFAULT NULL,
  p_transaction_note text DEFAULT NULL,
  p_transaction_date date DEFAULT CURRENT_DATE
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_tx_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.investor_stock_transactions_r1797
    (ledger_id, transaction_type, transaction_date, shares_delta, counterparty_holder, transaction_note)
  VALUES (p_ledger_id, p_transaction_type, p_transaction_date, p_shares_delta, p_counterparty_holder, p_transaction_note)
  RETURNING id INTO v_tx_id;

  UPDATE public.investor_stock_ledger_r1797
     SET current_balance = GREATEST(current_balance + p_shares_delta, 0),
         status = CASE
                    WHEN p_transaction_type = 'transfer' AND (current_balance + p_shares_delta) <= 0 THEN 'transferred'
                    WHEN p_transaction_type = 'exercise' AND (current_balance + p_shares_delta) <= 0 THEN 'exercised'
                    WHEN p_transaction_type = 'cancellation' THEN 'cancelled'
                    ELSE status
                  END,
         updated_at = now()
   WHERE id = p_ledger_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_transaction_r1797',
    jsonb_build_object('tx_id', v_tx_id, 'ledger_id', p_ledger_id, 'type', p_transaction_type, 'delta', p_shares_delta));

  RETURN v_tx_id;
END;
$$;

-- =====================================================================
-- RPC 5: recompute_balance
-- =====================================================================
DROP FUNCTION IF EXISTS public.recompute_balance_r1797(uuid);
CREATE OR REPLACE FUNCTION public.recompute_balance_r1797(p_ledger_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_initial bigint; v_delta bigint; v_final bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT shares_held INTO v_initial FROM public.investor_stock_ledger_r1797 WHERE id = p_ledger_id;
  IF v_initial IS NULL THEN RAISE EXCEPTION 'ledger not found'; END IF;

  SELECT COALESCE(SUM(shares_delta), 0) INTO v_delta
    FROM public.investor_stock_transactions_r1797
   WHERE ledger_id = p_ledger_id
     AND transaction_type <> 'issuance';

  v_final := GREATEST(v_initial + v_delta, 0);

  UPDATE public.investor_stock_ledger_r1797
     SET current_balance = v_final, updated_at = now()
   WHERE id = p_ledger_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'recompute_balance_r1797',
    jsonb_build_object('ledger_id', p_ledger_id, 'final_balance', v_final));

  RETURN v_final;
END;
$$;

-- =====================================================================
-- RPC 6: total_outstanding_per_class
-- =====================================================================
DROP FUNCTION IF EXISTS public.total_outstanding_per_class_r1797();
CREATE OR REPLACE FUNCTION public.total_outstanding_per_class_r1797()
RETURNS TABLE (
  share_class text,
  total_outstanding bigint,
  holder_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.share_class,
         COALESCE(SUM(l.current_balance), 0)::bigint AS total_outstanding,
         (COUNT(*) FILTER (WHERE l.status = 'active'))::int AS holder_count
  FROM public.investor_stock_ledger_r1797 l
  GROUP BY l.share_class
  ORDER BY total_outstanding DESC;
END;
$$;

-- =====================================================================
-- RPC 7: top_holders
-- =====================================================================
DROP FUNCTION IF EXISTS public.top_holders_r1797(int);
CREATE OR REPLACE FUNCTION public.top_holders_r1797(p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  holder_name text,
  holder_type text,
  share_class text,
  current_balance bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(current_balance), 0) INTO v_total FROM public.investor_stock_ledger_r1797 WHERE status = 'active';
  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT l.id, l.holder_name, l.holder_type, l.share_class, l.current_balance,
         ROUND((l.current_balance::numeric / v_total::numeric) * 100, 2) AS pct_of_total
  FROM public.investor_stock_ledger_r1797 l
  WHERE l.status = 'active'
  ORDER BY l.current_balance DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- =====================================================================
-- Grants
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.list_ledger_r1797() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_holder_r1797(text, text, text, bigint, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_transactions_r1797(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_transaction_r1797(uuid, text, bigint, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recompute_balance_r1797(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.total_outstanding_per_class_r1797() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_holders_r1797(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_ledger_r1797() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_holder_r1797(text, text, text, bigint, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_transactions_r1797(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_transaction_r1797(uuid, text, bigint, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recompute_balance_r1797(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.total_outstanding_per_class_r1797() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_holders_r1797(int) TO authenticated;

COMMIT;