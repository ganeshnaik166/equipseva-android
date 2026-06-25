BEGIN;

-- ============================================================
-- Round 2761: Founder Quarterly Secondary Market Equity Pulse
-- Tracks secondary market share-sale requests, tenders, valuations,
-- sources, close events, signals, and founder decisions across
-- quarterly secondary windows.
-- ============================================================

-- ----------------------------------------------------------------
-- Table 1: secondary_market_requests_r2761
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS secondary_market_requests_r2761 (
  id BIGSERIAL PRIMARY KEY,
  quarter_label TEXT NOT NULL,
  seller_party TEXT NOT NULL,
  seller_type TEXT NOT NULL CHECK (seller_type IN ('founder','employee','angel','seed_fund','series_a_fund','advisor')),
  shares_offered BIGINT NOT NULL CHECK (shares_offered > 0),
  ask_price_per_share_rupees NUMERIC(12,2) NOT NULL CHECK (ask_price_per_share_rupees > 0),
  implied_valuation_crores NUMERIC(12,2) NOT NULL CHECK (implied_valuation_crores > 0),
  tender_status TEXT NOT NULL CHECK (tender_status IN ('open','matched','partial','closed','withdrawn')),
  source_channel TEXT NOT NULL CHECK (source_channel IN ('inbound_buyer','outbound_broker','employee_liquidity_program','founder_initiated','existing_investor_topup')),
  signal_strength TEXT NOT NULL CHECK (signal_strength IN ('strong_buy','buy','neutral','sell','strong_sell')),
  founder_decision TEXT NOT NULL CHECK (founder_decision IN ('approved','rejected','deferred','renegotiate','escalate_board')),
  decision_rationale TEXT,
  requested_at DATE NOT NULL,
  closed_at DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE secondary_market_requests_r2761 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON secondary_market_requests_r2761;
CREATE POLICY founder_all ON secondary_market_requests_r2761
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO secondary_market_requests_r2761
  (quarter_label, seller_party, seller_type, shares_offered, ask_price_per_share_rupees, implied_valuation_crores, tender_status, source_channel, signal_strength, founder_decision, decision_rationale, requested_at, closed_at)
VALUES
  ('Q1-2026', 'Aarav Mehta (founding engineer)', 'employee', 12000, 1850.00, 185.00, 'matched', 'employee_liquidity_program', 'buy', 'approved', 'Tenured employee · 5yr vest · clean exit', '2026-01-12'::date, '2026-02-18'::date),
  ('Q1-2026', 'Blume Seed Fund I', 'seed_fund', 85000, 2100.00, 210.00, 'partial', 'outbound_broker', 'neutral', 'renegotiate', 'Valuation gap vs last 409A · push for tranche', '2026-01-22'::date, NULL),
  ('Q2-2026', 'Priya Nair (angel)', 'angel', 4500, 2350.00, 235.00, 'closed', 'inbound_buyer', 'strong_buy', 'approved', 'Strategic buyer is hospital chain CFO · add to cap table', '2026-04-08'::date, '2026-05-15'::date),
  ('Q2-2026', 'Series A Lead (Accel)', 'series_a_fund', 150000, 2500.00, 250.00, 'open', 'existing_investor_topup', 'strong_buy', 'deferred', 'Top-up signal positive but capacity limit at 18% pool', '2026-05-20'::date, NULL),
  ('Q3-2026', 'Founder co-founder partial', 'founder', 25000, 2700.00, 270.00, 'withdrawn', 'founder_initiated', 'sell', 'rejected', 'Optics risk pre-Series B · pulled by board', '2026-07-04'::date, '2026-07-19'::date),
  ('Q3-2026', 'Ex-advisor liquidity ask', 'advisor', 8000, 2600.00, 260.00, 'matched', 'outbound_broker', 'neutral', 'approved', 'Advisor tenure ended · clean exit pricing', '2026-08-11'::date, '2026-09-09'::date),
  ('Q4-2026', 'Anonymous secondary buyer', 'employee', 18000, 2900.00, 290.00, 'open', 'inbound_buyer', 'strong_buy', 'escalate_board', 'Strategic premium · board needs to ratify ROFR waiver', '2026-10-14'::date, NULL);

CREATE INDEX IF NOT EXISTS idx_smr_r2761_quarter ON secondary_market_requests_r2761(quarter_label);
CREATE INDEX IF NOT EXISTS idx_smr_r2761_status ON secondary_market_requests_r2761(tender_status);
CREATE INDEX IF NOT EXISTS idx_smr_r2761_decision ON secondary_market_requests_r2761(founder_decision);

-- ----------------------------------------------------------------
-- Table 2: secondary_market_valuation_signals_r2761
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS secondary_market_valuation_signals_r2761 (
  id BIGSERIAL PRIMARY KEY,
  quarter_label TEXT NOT NULL,
  signal_source TEXT NOT NULL CHECK (signal_source IN ('409a','last_primary','secondary_trades','comparable_co','broker_quote','founder_estimate')),
  signal_valuation_crores NUMERIC(12,2) NOT NULL CHECK (signal_valuation_crores > 0),
  confidence_pct INT NOT NULL CHECK (confidence_pct BETWEEN 0 AND 100),
  delta_vs_prior_quarter_pct NUMERIC(6,2) NOT NULL,
  market_regime TEXT NOT NULL CHECK (market_regime IN ('bull','base','flat','correction','bear')),
  founder_call TEXT NOT NULL CHECK (founder_call IN ('hold_floor','open_window','tighten_rofr','signal_neutral','pause_secondaries')),
  recorded_at DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE secondary_market_valuation_signals_r2761 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON secondary_market_valuation_signals_r2761;
CREATE POLICY founder_all ON secondary_market_valuation_signals_r2761
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO secondary_market_valuation_signals_r2761
  (quarter_label, signal_source, signal_valuation_crores, confidence_pct, delta_vs_prior_quarter_pct, market_regime, founder_call, recorded_at)
VALUES
  ('Q1-2026', '409a', 180.00, 95, 4.20, 'base', 'hold_floor', '2026-01-05'::date),
  ('Q1-2026', 'broker_quote', 205.00, 60, 8.50, 'bull', 'open_window', '2026-01-28'::date),
  ('Q2-2026', 'last_primary', 225.00, 90, 12.30, 'bull', 'open_window', '2026-04-02'::date),
  ('Q2-2026', 'comparable_co', 240.00, 70, 9.40, 'bull', 'tighten_rofr', '2026-05-11'::date),
  ('Q3-2026', 'secondary_trades', 265.00, 80, 6.70, 'base', 'signal_neutral', '2026-07-22'::date),
  ('Q3-2026', 'founder_estimate', 280.00, 55, 7.50, 'base', 'tighten_rofr', '2026-08-30'::date),
  ('Q4-2026', '409a', 285.00, 95, 3.10, 'flat', 'pause_secondaries', '2026-10-05'::date);

CREATE INDEX IF NOT EXISTS idx_smvs_r2761_quarter ON secondary_market_valuation_signals_r2761(quarter_label);
CREATE INDEX IF NOT EXISTS idx_smvs_r2761_source ON secondary_market_valuation_signals_r2761(signal_source);

-- ============================================================
-- RPCs
-- ============================================================

-- RPC 1: Quarterly KPIs
DROP FUNCTION IF EXISTS founder_r2761_quarterly_kpis();
CREATE OR REPLACE FUNCTION founder_r2761_quarterly_kpis()
RETURNS TABLE (
  total_requests BIGINT,
  approved_requests BIGINT,
  open_requests BIGINT,
  closed_requests BIGINT,
  total_shares_offered BIGINT,
  weighted_avg_price NUMERIC,
  latest_valuation_crores NUMERIC,
  approval_rate_pct NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT,
    COUNT(*) FILTER (WHERE founder_decision = 'approved')::BIGINT,
    COUNT(*) FILTER (WHERE tender_status = 'open')::BIGINT,
    COUNT(*) FILTER (WHERE tender_status = 'closed')::BIGINT,
    COALESCE(SUM(shares_offered), 0)::BIGINT,
    CASE WHEN SUM(shares_offered) > 0
         THEN ROUND(SUM(shares_offered * ask_price_per_share_rupees) / SUM(shares_offered), 2)
         ELSE 0 END,
    (SELECT signal_valuation_crores FROM secondary_market_valuation_signals_r2761 ORDER BY recorded_at DESC LIMIT 1),
    CASE WHEN COUNT(*) > 0
         THEN ROUND(100.0 * COUNT(*) FILTER (WHERE founder_decision = 'approved') / COUNT(*), 1)
         ELSE 0 END
  FROM secondary_market_requests_r2761;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_quarterly_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_quarterly_kpis() TO authenticated;

-- RPC 2: Requests by quarter
DROP FUNCTION IF EXISTS founder_r2761_requests_by_quarter();
CREATE OR REPLACE FUNCTION founder_r2761_requests_by_quarter()
RETURNS TABLE (
  quarter_label TEXT,
  request_count BIGINT,
  shares_total BIGINT,
  avg_implied_valuation NUMERIC,
  approved_count BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.quarter_label,
    COUNT(*)::BIGINT,
    SUM(r.shares_offered)::BIGINT,
    ROUND(AVG(r.implied_valuation_crores), 2),
    COUNT(*) FILTER (WHERE r.founder_decision = 'approved')::BIGINT
  FROM secondary_market_requests_r2761 r
  GROUP BY r.quarter_label
  ORDER BY r.quarter_label;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_requests_by_quarter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_requests_by_quarter() TO authenticated;

-- RPC 3: Requests by seller type
DROP FUNCTION IF EXISTS founder_r2761_seller_type_mix();
CREATE OR REPLACE FUNCTION founder_r2761_seller_type_mix()
RETURNS TABLE (
  seller_type TEXT,
  request_count BIGINT,
  shares_total BIGINT,
  avg_ask_price NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.seller_type,
    COUNT(*)::BIGINT,
    SUM(r.shares_offered)::BIGINT,
    ROUND(AVG(r.ask_price_per_share_rupees), 2)
  FROM secondary_market_requests_r2761 r
  GROUP BY r.seller_type
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_seller_type_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_seller_type_mix() TO authenticated;

-- RPC 4: Valuation signal timeline
DROP FUNCTION IF EXISTS founder_r2761_valuation_timeline();
CREATE OR REPLACE FUNCTION founder_r2761_valuation_timeline()
RETURNS TABLE (
  recorded_at DATE,
  quarter_label TEXT,
  signal_source TEXT,
  signal_valuation_crores NUMERIC,
  confidence_pct INT,
  market_regime TEXT,
  founder_call TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT v.recorded_at, v.quarter_label, v.signal_source, v.signal_valuation_crores, v.confidence_pct, v.market_regime, v.founder_call
  FROM secondary_market_valuation_signals_r2761 v
  ORDER BY v.recorded_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_valuation_timeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_valuation_timeline() TO authenticated;

-- RPC 5: Open tenders requiring action
DROP FUNCTION IF EXISTS founder_r2761_open_tenders();
CREATE OR REPLACE FUNCTION founder_r2761_open_tenders()
RETURNS TABLE (
  id BIGINT,
  quarter_label TEXT,
  seller_party TEXT,
  seller_type TEXT,
  shares_offered BIGINT,
  ask_price_per_share_rupees NUMERIC,
  implied_valuation_crores NUMERIC,
  signal_strength TEXT,
  founder_decision TEXT,
  days_open INT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id, r.quarter_label, r.seller_party, r.seller_type, r.shares_offered,
    r.ask_price_per_share_rupees, r.implied_valuation_crores, r.signal_strength, r.founder_decision,
    (CURRENT_DATE - r.requested_at)::INT
  FROM secondary_market_requests_r2761 r
  WHERE r.tender_status IN ('open','partial')
  ORDER BY r.requested_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_open_tenders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_open_tenders() TO authenticated;

-- RPC 6: Decision distribution
DROP FUNCTION IF EXISTS founder_r2761_decision_distribution();
CREATE OR REPLACE FUNCTION founder_r2761_decision_distribution()
RETURNS TABLE (
  founder_decision TEXT,
  request_count BIGINT,
  shares_total BIGINT,
  share_of_total_pct NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total BIGINT;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COUNT(*) INTO v_total FROM secondary_market_requests_r2761;

  RETURN QUERY
  SELECT
    r.founder_decision,
    COUNT(*)::BIGINT,
    SUM(r.shares_offered)::BIGINT,
    CASE WHEN v_total > 0 THEN ROUND(100.0 * COUNT(*) / v_total, 1) ELSE 0 END
  FROM secondary_market_requests_r2761 r
  GROUP BY r.founder_decision
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_decision_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_decision_distribution() TO authenticated;

-- RPC 7: Source channel breakdown
DROP FUNCTION IF EXISTS founder_r2761_source_channel_breakdown();
CREATE OR REPLACE FUNCTION founder_r2761_source_channel_breakdown()
RETURNS TABLE (
  source_channel TEXT,
  request_count BIGINT,
  approved_count BIGINT,
  shares_total BIGINT,
  approval_rate_pct NUMERIC
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.source_channel,
    COUNT(*)::BIGINT,
    COUNT(*) FILTER (WHERE r.founder_decision = 'approved')::BIGINT,
    SUM(r.shares_offered)::BIGINT,
    CASE WHEN COUNT(*) > 0
         THEN ROUND(100.0 * COUNT(*) FILTER (WHERE r.founder_decision = 'approved') / COUNT(*), 1)
         ELSE 0 END
  FROM secondary_market_requests_r2761 r
  GROUP BY r.source_channel
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_source_channel_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_source_channel_breakdown() TO authenticated;

-- RPC 8: Signal strength heatmap
DROP FUNCTION IF EXISTS founder_r2761_signal_strength_heatmap();
CREATE OR REPLACE FUNCTION founder_r2761_signal_strength_heatmap()
RETURNS TABLE (
  signal_strength TEXT,
  request_count BIGINT,
  avg_implied_valuation NUMERIC,
  approved_count BIGINT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.signal_strength,
    COUNT(*)::BIGINT,
    ROUND(AVG(r.implied_valuation_crores), 2),
    COUNT(*) FILTER (WHERE r.founder_decision = 'approved')::BIGINT
  FROM secondary_market_requests_r2761 r
  GROUP BY r.signal_strength
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_r2761_signal_strength_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2761_signal_strength_heatmap() TO authenticated;

COMMIT;
