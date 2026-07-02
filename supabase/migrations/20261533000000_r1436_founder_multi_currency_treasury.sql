BEGIN;
-- r1436_founder_multi_currency_treasury.sql
-- Multi-currency treasury — cash positions across countries + currencies.
-- Extends r1398 (founder_international_countries + founder_international_currencies).
-- 1 table + 7 RPCs.

-- ============================================================================
-- TABLE: founder_multi_currency_treasury_positions
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_multi_currency_treasury_positions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  currency_code text NOT NULL
    REFERENCES public.founder_international_currencies(currency_code) ON DELETE RESTRICT,
  country_id uuid
    REFERENCES public.founder_international_countries(id) ON DELETE SET NULL,
  position_label text NOT NULL,
  position_kind text NOT NULL DEFAULT 'bank_account'
    CHECK (position_kind IN ('bank_account','cash_in_hand','escrow','holding_account','forex_card','other')),
  balance_amount numeric NOT NULL DEFAULT 0,
  balance_inr_equivalent numeric,
  last_synced_at timestamptz DEFAULT now(),
  bank_name text,
  account_label_masked text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_treasury_currency_label UNIQUE (currency_code, position_label)
);

CREATE INDEX IF NOT EXISTS idx_treasury_positions_currency
  ON public.founder_multi_currency_treasury_positions(currency_code);
CREATE INDEX IF NOT EXISTS idx_treasury_positions_country
  ON public.founder_multi_currency_treasury_positions(country_id);
CREATE INDEX IF NOT EXISTS idx_treasury_positions_kind
  ON public.founder_multi_currency_treasury_positions(position_kind);
CREATE INDEX IF NOT EXISTS idx_treasury_positions_inr
  ON public.founder_multi_currency_treasury_positions(balance_inr_equivalent DESC NULLS LAST);

ALTER TABLE public.founder_multi_currency_treasury_positions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_treasury_positions_founder_all ON public.founder_multi_currency_treasury_positions;
CREATE POLICY p_treasury_positions_founder_all ON public.founder_multi_currency_treasury_positions
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: founder_multi_currency_treasury_summary — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_multi_currency_treasury_summary();
CREATE OR REPLACE FUNCTION public.founder_multi_currency_treasury_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_positions int := 0;
  v_total_currencies int := 0;
  v_total_countries int := 0;
  v_total_balance_inr numeric := 0;
  v_bank_account_count int := 0;
  v_cash_in_hand_count int := 0;
  v_escrow_count int := 0;
  v_holding_count int := 0;
  v_forex_count int := 0;
  v_other_count int := 0;
  v_top_currency text;
  v_top_currency_inr numeric := 0;
  v_top_country text;
  v_top_country_inr numeric := 0;
  v_stale_positions int := 0;
  v_unresolved_inr int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'Forbidden: founder-only';
  END IF;

  SELECT
    COUNT(*),
    COUNT(DISTINCT currency_code),
    COUNT(DISTINCT country_id) FILTER (WHERE country_id IS NOT NULL),
    COALESCE(SUM(balance_inr_equivalent), 0),
    COUNT(*) FILTER (WHERE position_kind = 'bank_account'),
    COUNT(*) FILTER (WHERE position_kind = 'cash_in_hand'),
    COUNT(*) FILTER (WHERE position_kind = 'escrow'),
    COUNT(*) FILTER (WHERE position_kind = 'holding_account'),
    COUNT(*) FILTER (WHERE position_kind = 'forex_card'),
    COUNT(*) FILTER (WHERE position_kind = 'other'),
    COUNT(*) FILTER (WHERE last_synced_at < now() - interval '14 days'),
    COUNT(*) FILTER (WHERE balance_inr_equivalent IS NULL)
  INTO
    v_total_positions, v_total_currencies, v_total_countries, v_total_balance_inr,
    v_bank_account_count, v_cash_in_hand_count, v_escrow_count, v_holding_count,
    v_forex_count, v_other_count, v_stale_positions, v_unresolved_inr
  FROM public.founder_multi_currency_treasury_positions;

  SELECT currency_code, COALESCE(SUM(balance_inr_equivalent),0) AS s
    INTO v_top_currency, v_top_currency_inr
    FROM public.founder_multi_currency_treasury_positions
   GROUP BY currency_code
   ORDER BY s DESC NULLS LAST
   LIMIT 1;

  SELECT c.country_code, COALESCE(SUM(p.balance_inr_equivalent),0) AS s
    INTO v_top_country, v_top_country_inr
    FROM public.founder_multi_currency_treasury_positions p
    JOIN public.founder_international_countries c ON c.id = p.country_id
   GROUP BY c.country_code
   ORDER BY s DESC NULLS LAST
   LIMIT 1;

  RETURN jsonb_build_object(
    'total_positions', v_total_positions,
    'total_currencies', v_total_currencies,
    'total_countries', v_total_countries,
    'total_balance_inr_equivalent', v_total_balance_inr,
    'bank_account_count', v_bank_account_count,
    'cash_in_hand_count', v_cash_in_hand_count,
    'escrow_count', v_escrow_count,
    'holding_account_count', v_holding_count,
    'forex_card_count', v_forex_count,
    'other_count', v_other_count,
    'top_currency_by_inr', COALESCE(v_top_currency, '—'),
    'top_currency_inr_value', COALESCE(v_top_currency_inr, 0),
    'top_country_by_inr', COALESCE(v_top_country, '—'),
    'top_country_inr_value', COALESCE(v_top_country_inr, 0),
    'stale_positions_14d', v_stale_positions,
    'positions_missing_inr', v_unresolved_inr
  );
END;
$$;
REVOKE ALL ON FUNCTION public.founder_multi_currency_treasury_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_multi_currency_treasury_summary() TO authenticated;

-- ============================================================================
-- RPC 2: founder_multi_currency_treasury_positions_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_multi_currency_treasury_positions_recent(int);
CREATE OR REPLACE FUNCTION public.founder_multi_currency_treasury_positions_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  currency_code text,
  country_id uuid,
  country_code text,
  country_name text,
  position_label text,
  position_kind text,
  balance_amount numeric,
  balance_inr_equivalent numeric,
  last_synced_at timestamptz,
  bank_name text,
  account_label_masked text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'Forbidden: founder-only';
  END IF;

  RETURN QUERY
  SELECT p.id, p.currency_code, p.country_id,
         c.country_code, c.country_name,
         p.position_label, p.position_kind,
         p.balance_amount, p.balance_inr_equivalent,
         p.last_synced_at, p.bank_name, p.account_label_masked, p.notes,
         p.created_at
    FROM public.founder_multi_currency_treasury_positions p
    LEFT JOIN public.founder_international_countries c ON c.id = p.country_id
   ORDER BY p.balance_inr_equivalent DESC NULLS LAST, p.created_at DESC
   LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE ALL ON FUNCTION public.founder_multi_currency_treasury_positions_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_multi_currency_treasury_positions_recent(int) TO authenticated;

-- ============================================================================
-- RPC 3: founder_multi_currency_treasury_by_currency
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_multi_currency_treasury_by_currency();
CREATE OR REPLACE FUNCTION public.founder_multi_currency_treasury_by_currency()
RETURNS TABLE (
  currency_code text,
  currency_label text,
  exchange_rate_inr numeric,
  position_count bigint,
  total_balance_amount numeric,
  total_balance_inr_equivalent numeric,
  last_synced_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'Forbidden: founder-only';
  END IF;

  RETURN QUERY
  SELECT cu.currency_code,
         cu.currency_label,
         cu.exchange_rate_inr,
         COUNT(p.id) AS position_count,
         COALESCE(SUM(p.balance_amount), 0) AS total_balance_amount,
         COALESCE(SUM(p.balance_inr_equivalent), 0) AS total_balance_inr_equivalent,
         MAX(p.last_synced_at) AS last_synced_at
    FROM public.founder_international_currencies cu
    LEFT JOIN public.founder_multi_currency_treasury_positions p ON p.currency_code = cu.currency_code
   GROUP BY cu.currency_code, cu.currency_label, cu.exchange_rate_inr
   ORDER BY total_balance_inr_equivalent DESC NULLS LAST;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_multi_currency_treasury_by_currency() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_multi_currency_treasury_by_currency() TO authenticated;

-- ============================================================================
-- RPC 4: founder_multi_currency_treasury_by_country
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_multi_currency_treasury_by_country();
CREATE OR REPLACE FUNCTION public.founder_multi_currency_treasury_by_country()
RETURNS TABLE (
  country_id uuid,
  country_code text,
  country_name text,
  expansion_status text,
  position_count bigint,
  total_balance_inr_equivalent numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'Forbidden: founder-only';
  END IF;

  RETURN QUERY
  SELECT c.id AS country_id,
         c.country_code,
         c.country_name,
         c.expansion_status,
         COUNT(p.id) AS position_count,
         COALESCE(SUM(p.balance_inr_equivalent), 0) AS total_balance_inr_equivalent
    FROM public.founder_international_countries c
    LEFT JOIN public.founder_multi_currency_treasury_positions p ON p.country_id = c.id
   GROUP BY c.id, c.country_code, c.country_name, c.expansion_status
   ORDER BY total_balance_inr_equivalent DESC NULLS LAST;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_multi_currency_treasury_by_country() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_multi_currency_treasury_by_country() TO authenticated;

-- ============================================================================
-- RPC 5: log_founder_treasury_register_position
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_treasury_register_position(text, uuid, text, text, numeric, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_treasury_register_position(
  p_currency_code text,
  p_country_id uuid,
  p_position_label text,
  p_position_kind text,
  p_balance_amount numeric,
  p_bank_name text DEFAULT NULL,
  p_account_label_masked text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_rate numeric;
  v_inr numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'Forbidden: founder-only';
  END IF;

  SELECT exchange_rate_inr INTO v_rate
    FROM public.founder_international_currencies
   WHERE currency_code = p_currency_code AND is_active = true;

  IF v_rate IS NULL THEN
    RAISE EXCEPTION 'Currency % not registered or inactive', p_currency_code;
  END IF;

  v_inr := COALESCE(p_balance_amount, 0) * v_rate;

  INSERT INTO public.founder_multi_currency_treasury_positions(
    currency_code, country_id, position_label, position_kind,
    balance_amount, balance_inr_equivalent, last_synced_at,
    bank_name, account_label_masked, notes
  )
  VALUES (
    p_currency_code, p_country_id, p_position_label, p_position_kind,
    COALESCE(p_balance_amount, 0), v_inr, now(),
    p_bank_name, p_account_label_masked, p_notes
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_treasury_register_position(text, uuid, text, text, numeric, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_treasury_register_position(text, uuid, text, text, numeric, text, text, text) TO authenticated;

-- ============================================================================
-- RPC 6: log_founder_treasury_update_balance
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_treasury_update_balance(uuid, numeric, text);
CREATE OR REPLACE FUNCTION public.log_founder_treasury_update_balance(
  p_position_id uuid,
  p_new_balance numeric,
  p_note text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_currency text;
  v_rate numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'Forbidden: founder-only';
  END IF;

  SELECT p.currency_code, cu.exchange_rate_inr
    INTO v_currency, v_rate
    FROM public.founder_multi_currency_treasury_positions p
    JOIN public.founder_international_currencies cu ON cu.currency_code = p.currency_code
   WHERE p.id = p_position_id;

  IF v_currency IS NULL THEN
    RAISE EXCEPTION 'Position % not found', p_position_id;
  END IF;

  UPDATE public.founder_multi_currency_treasury_positions
     SET balance_amount = COALESCE(p_new_balance, 0),
         balance_inr_equivalent = COALESCE(p_new_balance, 0) * v_rate,
         last_synced_at = now(),
         notes = COALESCE(p_note, notes),
         updated_at = now()
   WHERE id = p_position_id;

  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_treasury_update_balance(uuid, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_treasury_update_balance(uuid, numeric, text) TO authenticated;

-- ============================================================================
-- RPC 7: log_founder_treasury_recompute_inr_equivalents (cron-callable)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_treasury_recompute_inr_equivalents();
CREATE OR REPLACE FUNCTION public.log_founder_treasury_recompute_inr_equivalents()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
BEGIN
  -- Cron-callable: no is_founder gate (runs as the role pg_cron is configured with;
  -- function only writes derived balance_inr_equivalent which is non-sensitive math).
  UPDATE public.founder_multi_currency_treasury_positions p
     SET balance_inr_equivalent = COALESCE(p.balance_amount, 0) * cu.exchange_rate_inr,
         updated_at = now()
    FROM public.founder_international_currencies cu
   WHERE cu.currency_code = p.currency_code
     AND cu.is_active = true;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_treasury_recompute_inr_equivalents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_treasury_recompute_inr_equivalents() TO authenticated;

COMMIT;