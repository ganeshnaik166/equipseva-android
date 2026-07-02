BEGIN;

-- Round 1621 — Investor Secondary Market Intel
-- Track third-party share transactions in our cap table, founder RoFR triggers,
-- counterparty intel, and valuation signals from secondary trades.

-- =====================================================================
-- TABLE 1: secondary_market_transactions
-- =====================================================================
CREATE TABLE IF NOT EXISTS secondary_market_transactions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  txn_date        date NOT NULL,
  seller_name     text NOT NULL,
  seller_type     text NOT NULL CHECK (seller_type IN ('founder','employee','angel','vc','family_friend','esop_holder','other')),
  buyer_name      text,
  buyer_type      text CHECK (buyer_type IN ('strategic','vc','pe','family_office','angel','employee','unknown')),
  share_count     bigint NOT NULL CHECK (share_count > 0),
  price_per_share_rupees numeric(18,4) NOT NULL CHECK (price_per_share_rupees >= 0),
  total_value_rupees numeric(18,2) GENERATED ALWAYS AS (share_count * price_per_share_rupees) STORED,
  implied_valuation_rupees numeric(20,2),
  rofr_status     text NOT NULL DEFAULT 'pending' CHECK (rofr_status IN ('pending','waived','exercised','expired','not_applicable')),
  rofr_deadline   date,
  rofr_exercised_at timestamptz,
  intel_source    text,
  intel_confidence text NOT NULL DEFAULT 'medium' CHECK (intel_confidence IN ('low','medium','high','confirmed')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_smt_date ON secondary_market_transactions (txn_date DESC);
CREATE INDEX IF NOT EXISTS idx_smt_rofr ON secondary_market_transactions (rofr_status) WHERE rofr_status = 'pending';
CREATE INDEX IF NOT EXISTS idx_smt_seller_type ON secondary_market_transactions (seller_type);

ALTER TABLE secondary_market_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS smt_founder_only ON secondary_market_transactions;
CREATE POLICY smt_founder_only ON secondary_market_transactions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- TABLE 2: secondary_market_counterparties
-- =====================================================================
CREATE TABLE IF NOT EXISTS secondary_market_counterparties (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  party_name      text NOT NULL UNIQUE,
  party_type      text NOT NULL CHECK (party_type IN ('strategic','vc','pe','family_office','angel','employee','founder','other')),
  contact_email   text,
  contact_phone   text,
  current_holding_shares bigint NOT NULL DEFAULT 0,
  cost_basis_per_share_rupees numeric(18,4),
  watchlist_flag  boolean NOT NULL DEFAULT false,
  intent_to_sell  text CHECK (intent_to_sell IN ('none','soft','hard','listed','sold')),
  last_signal_at  timestamptz,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_smc_watchlist ON secondary_market_counterparties (watchlist_flag) WHERE watchlist_flag;
CREATE INDEX IF NOT EXISTS idx_smc_intent ON secondary_market_counterparties (intent_to_sell);

ALTER TABLE secondary_market_counterparties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS smc_founder_only ON secondary_market_counterparties;
CREATE POLICY smc_founder_only ON secondary_market_counterparties
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_smt_record(p_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'smt_record', jsonb_build_object('id', p_id, 'data', p_payload), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_smt_record(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_smt_record(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_smt_rofr(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'smt_rofr_action', jsonb_build_object('txn_id', p_id, 'status', p_status), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_smt_rofr(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_smt_rofr(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_smt_counterparty(p_id uuid, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'smt_counterparty_upsert', jsonb_build_object('id', p_id, 'data', p_payload), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_smt_counterparty(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_smt_counterparty(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_smt_watchlist(p_id uuid, p_flag boolean)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'smt_watchlist_toggle', jsonb_build_object('counterparty_id', p_id, 'watchlist', p_flag), now());
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_smt_watchlist(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_smt_watchlist(uuid, boolean) TO authenticated;

-- =====================================================================
-- READ RPCs (STABLE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_smt_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH base AS (
    SELECT * FROM secondary_market_transactions
  ),
  recent AS (
    SELECT * FROM base WHERE txn_date >= (current_date - 90)
  ),
  ytd AS (
    SELECT * FROM base WHERE txn_date >= date_trunc('year', current_date)::date
  ),
  pending_rofr AS (
    SELECT * FROM base WHERE rofr_status = 'pending'
  ),
  cp AS (
    SELECT * FROM secondary_market_counterparties
  )
  SELECT jsonb_build_object(
    'total_txns', (SELECT count(*) FROM base),
    'ytd_txns', (SELECT count(*) FROM ytd),
    'recent_txns_90d', (SELECT count(*) FROM recent),
    'total_value_rupees', COALESCE((SELECT sum(total_value_rupees) FROM base), 0),
    'ytd_value_rupees', COALESCE((SELECT sum(total_value_rupees) FROM ytd), 0),
    'recent_value_rupees', COALESCE((SELECT sum(total_value_rupees) FROM recent), 0),
    'avg_price_per_share', COALESCE((SELECT avg(price_per_share_rupees) FROM recent), 0),
    'max_price_per_share', COALESCE((SELECT max(price_per_share_rupees) FROM recent), 0),
    'min_price_per_share', COALESCE((SELECT min(price_per_share_rupees) FROM recent), 0),
    'implied_valuation_latest', COALESCE((SELECT implied_valuation_rupees FROM base ORDER BY txn_date DESC LIMIT 1), 0),
    'pending_rofr_count', (SELECT count(*) FROM pending_rofr),
    'exercised_rofr_count', (SELECT count(*) FROM base WHERE rofr_status='exercised'),
    'waived_rofr_count', (SELECT count(*) FROM base WHERE rofr_status='waived'),
    'watchlist_count', (SELECT count(*) FROM cp WHERE watchlist_flag),
    'hard_intent_count', (SELECT count(*) FROM cp WHERE intent_to_sell='hard'),
    'tracked_counterparties', (SELECT count(*) FROM cp)
  ) INTO v_result;
  RETURN v_result;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_smt_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_smt_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_smt_recent_transactions(p_limit int DEFAULT 50)
RETURNS TABLE (id uuid, txn_date date, seller_name text, seller_type text, buyer_name text, buyer_type text, share_count bigint, price_per_share_rupees numeric, total_value_rupees numeric, implied_valuation_rupees numeric, rofr_status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.txn_date, t.seller_name, t.seller_type, t.buyer_name, t.buyer_type,
           t.share_count, t.price_per_share_rupees, t.total_value_rupees, t.implied_valuation_rupees, t.rofr_status
    FROM secondary_market_transactions t
    ORDER BY t.txn_date DESC, t.created_at DESC
    LIMIT p_limit;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_smt_recent_transactions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_smt_recent_transactions(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_smt_pending_rofr()
RETURNS TABLE (id uuid, txn_date date, seller_name text, share_count bigint, price_per_share_rupees numeric, total_value_rupees numeric, rofr_deadline date, days_to_deadline int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.txn_date, t.seller_name, t.share_count, t.price_per_share_rupees, t.total_value_rupees,
           t.rofr_deadline,
           (t.rofr_deadline - current_date)::int AS days_to_deadline
    FROM secondary_market_transactions t
    WHERE t.rofr_status = 'pending'
    ORDER BY t.rofr_deadline ASC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_smt_pending_rofr() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_smt_pending_rofr() TO authenticated;

CREATE OR REPLACE FUNCTION founder_smt_price_trajectory()
RETURNS TABLE (month_start date, txn_count bigint, avg_price numeric, max_price numeric, total_volume numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', t.txn_date)::date AS month_start,
           count(*)::bigint AS txn_count,
           avg(t.price_per_share_rupees)::numeric AS avg_price,
           max(t.price_per_share_rupees)::numeric AS max_price,
           sum(t.total_value_rupees)::numeric AS total_volume
    FROM secondary_market_transactions t
    WHERE t.txn_date >= (current_date - 365)
    GROUP BY 1
    ORDER BY 1 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_smt_price_trajectory() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_smt_price_trajectory() TO authenticated;

CREATE OR REPLACE FUNCTION founder_smt_watchlist()
RETURNS TABLE (id uuid, party_name text, party_type text, current_holding_shares bigint, intent_to_sell text, last_signal_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.party_name, c.party_type, c.current_holding_shares, c.intent_to_sell, c.last_signal_at
    FROM secondary_market_counterparties c
    WHERE c.watchlist_flag
    ORDER BY c.last_signal_at DESC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_smt_watchlist() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_smt_watchlist() TO authenticated;

-- =====================================================================
-- WRITE RPCs (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_smt_record_txn(
  p_txn_date date,
  p_seller_name text,
  p_seller_type text,
  p_buyer_name text,
  p_buyer_type text,
  p_share_count bigint,
  p_price_per_share numeric,
  p_implied_valuation numeric,
  p_rofr_deadline date,
  p_intel_source text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO secondary_market_transactions (
    txn_date, seller_name, seller_type, buyer_name, buyer_type,
    share_count, price_per_share_rupees, implied_valuation_rupees,
    rofr_deadline, intel_source, notes
  ) VALUES (
    p_txn_date, p_seller_name, p_seller_type, p_buyer_name, p_buyer_type,
    p_share_count, p_price_per_share, p_implied_valuation,
    p_rofr_deadline, p_intel_source, p_notes
  ) RETURNING id INTO v_id;
  PERFORM log_founder_smt_record(v_id, jsonb_build_object('seller', p_seller_name, 'shares', p_share_count, 'price', p_price_per_share));
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_smt_record_txn(date, text, text, text, text, bigint, numeric, numeric, date, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_smt_record_txn(date, text, text, text, text, bigint, numeric, numeric, date, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_smt_set_rofr(p_txn_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('pending','waived','exercised','expired','not_applicable') THEN
    RAISE EXCEPTION 'invalid rofr status';
  END IF;
  UPDATE secondary_market_transactions
  SET rofr_status = p_status,
      rofr_exercised_at = CASE WHEN p_status='exercised' THEN now() ELSE rofr_exercised_at END,
      updated_at = now()
  WHERE id = p_txn_id;
  PERFORM log_founder_smt_rofr(p_txn_id, p_status);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_smt_set_rofr(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_smt_set_rofr(uuid, text) TO authenticated;

COMMIT;