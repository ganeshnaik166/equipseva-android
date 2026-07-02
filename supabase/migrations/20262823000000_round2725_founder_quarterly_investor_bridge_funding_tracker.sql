BEGIN;

-- ============================================================================
-- Round 2725: Founder Quarterly Investor Bridge Funding Tracker
-- Tracks bridge funding asks across investors with terms, commitments,
-- wires, and outcomes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: bridge_funding_asks_r2725
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bridge_funding_asks_r2725 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_type text NOT NULL CHECK (investor_type IN ('angel','syndicate','family_office','micro_vc','strategic','existing_lp')),
  ask_amount_rupees bigint NOT NULL CHECK (ask_amount_rupees > 0),
  term_sheet_valuation_rupees bigint NOT NULL CHECK (term_sheet_valuation_rupees > 0),
  instrument text NOT NULL CHECK (instrument IN ('safe','ccd','ccps','convertible_note','equity')),
  discount_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (discount_pct >= 0 AND discount_pct <= 50),
  cap_rupees bigint CHECK (cap_rupees IS NULL OR cap_rupees > 0),
  status text NOT NULL CHECK (status IN ('intro','pitched','diligence','term_sheet','committed','wired','declined','ghosted')),
  ask_opened_on date NOT NULL,
  last_touch_on date NOT NULL,
  quarter_tag text NOT NULL CHECK (quarter_tag IN ('Q1','Q2','Q3','Q4')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bridge_funding_asks_r2725 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON bridge_funding_asks_r2725;
CREATE POLICY founder_all ON bridge_funding_asks_r2725 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO bridge_funding_asks_r2725 (investor_name, investor_type, ask_amount_rupees, term_sheet_valuation_rupees, instrument, discount_pct, cap_rupees, status, ask_opened_on, last_touch_on, quarter_tag, notes) VALUES
  ('Lumikai Ventures', 'micro_vc', 15000000, 1200000000, 'safe', 20.00, 1000000000, 'term_sheet', '2026-04-10'::date, '2026-06-18'::date, 'Q2', 'Lead candidate, strong conviction on medtech vertical'),
  ('Sanjay Reddy (Apollo Family Office)', 'family_office', 25000000, 1500000000, 'ccps', 15.00, 1200000000, 'committed', '2026-04-15'::date, '2026-06-20'::date, 'Q2', 'Strategic hospital channel, sector match'),
  ('Better Capital Syndicate', 'syndicate', 10000000, 1200000000, 'safe', 20.00, 1000000000, 'wired', '2026-03-22'::date, '2026-05-30'::date, 'Q2', 'First wire received 2026-05-28, ₹1Cr cleared'),
  ('Inflection Point Ventures', 'syndicate', 12000000, 1300000000, 'convertible_note', 18.00, 1100000000, 'diligence', '2026-05-02'::date, '2026-06-19'::date, 'Q2', 'Awaiting CA diligence pack signoff'),
  ('Rajesh Yabaji (BlackBuck Angel)', 'angel', 5000000, 1200000000, 'safe', 25.00, 900000000, 'pitched', '2026-05-18'::date, '2026-06-15'::date, 'Q2', 'Warm intro via portfolio CEO, wants Q3 close'),
  ('Stride Ventures', 'micro_vc', 30000000, 1600000000, 'equity', 0.00, NULL, 'declined', '2026-04-05'::date, '2026-05-12'::date, 'Q2', 'Pass - stage too early for their thesis'),
  ('GenNext Hub', 'strategic', 20000000, 1400000000, 'ccd', 12.00, 1200000000, 'ghosted', '2026-03-18'::date, '2026-04-25'::date, 'Q2', 'No response after second pitch, deprioritized');

-- ----------------------------------------------------------------------------
-- Table 2: bridge_funding_wires_r2725
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bridge_funding_wires_r2725 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ask_id uuid NOT NULL REFERENCES bridge_funding_asks_r2725(id) ON DELETE CASCADE,
  commitment_amount_rupees bigint NOT NULL CHECK (commitment_amount_rupees > 0),
  wired_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (wired_amount_rupees >= 0),
  committed_on date NOT NULL,
  wire_expected_on date,
  wire_received_on date,
  wire_status text NOT NULL CHECK (wire_status IN ('committed','wire_initiated','partial_wire','full_wire','clawback','withdrawn')),
  outcome text NOT NULL CHECK (outcome IN ('pending','closed_win','closed_loss','rolled_to_next_round','withdrew_commitment')),
  bank_ref text,
  outcome_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bridge_funding_wires_r2725 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON bridge_funding_wires_r2725;
CREATE POLICY founder_all ON bridge_funding_wires_r2725 FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO bridge_funding_wires_r2725 (ask_id, commitment_amount_rupees, wired_amount_rupees, committed_on, wire_expected_on, wire_received_on, wire_status, outcome, bank_ref, outcome_notes) VALUES
  ((SELECT id FROM bridge_funding_asks_r2725 WHERE investor_name = 'Better Capital Syndicate'), 10000000, 10000000, '2026-05-15'::date, '2026-05-28'::date, '2026-05-28'::date, 'full_wire', 'closed_win', 'HDFC-WIRE-88421', 'Full wire on schedule, SAFE executed'),
  ((SELECT id FROM bridge_funding_asks_r2725 WHERE investor_name = 'Sanjay Reddy (Apollo Family Office)'), 25000000, 12500000, '2026-06-10'::date, '2026-06-25'::date, '2026-06-15'::date, 'partial_wire', 'pending', 'ICICI-WIRE-77103', 'Tranche 1 of 2 received, balance due 2026-07-15'),
  ((SELECT id FROM bridge_funding_asks_r2725 WHERE investor_name = 'Lumikai Ventures'), 15000000, 0, '2026-06-18'::date, '2026-07-05'::date, NULL, 'committed', 'pending', NULL, 'Term sheet countersigned, awaiting wire instructions'),
  ((SELECT id FROM bridge_funding_asks_r2725 WHERE investor_name = 'Stride Ventures'), 5000000, 0, '2026-04-20'::date, NULL, NULL, 'withdrawn', 'closed_loss', NULL, 'Withdrew after IC pass'),
  ((SELECT id FROM bridge_funding_asks_r2725 WHERE investor_name = 'Inflection Point Ventures'), 12000000, 0, '2026-06-12'::date, '2026-07-20'::date, NULL, 'committed', 'pending', NULL, 'Verbal commit pending DD complete'),
  ((SELECT id FROM bridge_funding_asks_r2725 WHERE investor_name = 'Rajesh Yabaji (BlackBuck Angel)'), 5000000, 0, '2026-06-08'::date, '2026-08-01'::date, NULL, 'committed', 'rolled_to_next_round', NULL, 'Rolled to Series A from bridge');

-- ----------------------------------------------------------------------------
-- RPC 1: get_bridge_funding_overview_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_bridge_funding_overview_r2725();
CREATE OR REPLACE FUNCTION get_bridge_funding_overview_r2725()
RETURNS TABLE (
  total_asks bigint,
  total_ask_amount_rupees bigint,
  total_committed_rupees bigint,
  total_wired_rupees bigint,
  active_pipeline bigint,
  closed_wins bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM bridge_funding_asks_r2725)::bigint,
    COALESCE((SELECT SUM(ask_amount_rupees) FROM bridge_funding_asks_r2725), 0)::bigint,
    COALESCE((SELECT SUM(commitment_amount_rupees) FROM bridge_funding_wires_r2725), 0)::bigint,
    COALESCE((SELECT SUM(wired_amount_rupees) FROM bridge_funding_wires_r2725), 0)::bigint,
    (SELECT COUNT(*) FROM bridge_funding_asks_r2725 WHERE status IN ('intro','pitched','diligence','term_sheet','committed'))::bigint,
    (SELECT COUNT(*) FROM bridge_funding_wires_r2725 WHERE outcome = 'closed_win')::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_bridge_funding_overview_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_bridge_funding_overview_r2725() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 2: list_bridge_funding_asks_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_bridge_funding_asks_r2725();
CREATE OR REPLACE FUNCTION list_bridge_funding_asks_r2725()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_type text,
  ask_amount_rupees bigint,
  term_sheet_valuation_rupees bigint,
  instrument text,
  discount_pct numeric,
  cap_rupees bigint,
  status text,
  ask_opened_on date,
  last_touch_on date,
  quarter_tag text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.investor_name, a.investor_type, a.ask_amount_rupees, a.term_sheet_valuation_rupees,
         a.instrument, a.discount_pct, a.cap_rupees, a.status, a.ask_opened_on, a.last_touch_on,
         a.quarter_tag, a.notes
  FROM bridge_funding_asks_r2725 a
  ORDER BY a.ask_amount_rupees DESC, a.last_touch_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_bridge_funding_asks_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_bridge_funding_asks_r2725() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 3: list_bridge_funding_wires_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS list_bridge_funding_wires_r2725();
CREATE OR REPLACE FUNCTION list_bridge_funding_wires_r2725()
RETURNS TABLE (
  id uuid,
  investor_name text,
  commitment_amount_rupees bigint,
  wired_amount_rupees bigint,
  committed_on date,
  wire_expected_on date,
  wire_received_on date,
  wire_status text,
  outcome text,
  bank_ref text,
  outcome_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.id, a.investor_name, w.commitment_amount_rupees, w.wired_amount_rupees,
         w.committed_on, w.wire_expected_on, w.wire_received_on, w.wire_status, w.outcome,
         w.bank_ref, w.outcome_notes
  FROM bridge_funding_wires_r2725 w
  JOIN bridge_funding_asks_r2725 a ON a.id = w.ask_id
  ORDER BY w.committed_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION list_bridge_funding_wires_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_bridge_funding_wires_r2725() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 4: get_bridge_funding_by_status_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_bridge_funding_by_status_r2725();
CREATE OR REPLACE FUNCTION get_bridge_funding_by_status_r2725()
RETURNS TABLE (
  status text,
  ask_count bigint,
  total_ask_rupees bigint,
  avg_valuation_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status, COUNT(*)::bigint, SUM(a.ask_amount_rupees)::bigint, AVG(a.term_sheet_valuation_rupees)::bigint
  FROM bridge_funding_asks_r2725 a
  GROUP BY a.status
  ORDER BY SUM(a.ask_amount_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_bridge_funding_by_status_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_bridge_funding_by_status_r2725() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 5: get_bridge_funding_by_instrument_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_bridge_funding_by_instrument_r2725();
CREATE OR REPLACE FUNCTION get_bridge_funding_by_instrument_r2725()
RETURNS TABLE (
  instrument text,
  ask_count bigint,
  total_ask_rupees bigint,
  avg_discount_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.instrument, COUNT(*)::bigint, SUM(a.ask_amount_rupees)::bigint, AVG(a.discount_pct)::numeric
  FROM bridge_funding_asks_r2725 a
  GROUP BY a.instrument
  ORDER BY SUM(a.ask_amount_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_bridge_funding_by_instrument_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_bridge_funding_by_instrument_r2725() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 6: get_bridge_funding_wire_pipeline_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_bridge_funding_wire_pipeline_r2725();
CREATE OR REPLACE FUNCTION get_bridge_funding_wire_pipeline_r2725()
RETURNS TABLE (
  wire_status text,
  wire_count bigint,
  committed_rupees bigint,
  wired_rupees bigint,
  gap_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT w.wire_status, COUNT(*)::bigint,
         SUM(w.commitment_amount_rupees)::bigint,
         SUM(w.wired_amount_rupees)::bigint,
         (SUM(w.commitment_amount_rupees) - SUM(w.wired_amount_rupees))::bigint
  FROM bridge_funding_wires_r2725 w
  GROUP BY w.wire_status
  ORDER BY SUM(w.commitment_amount_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_bridge_funding_wire_pipeline_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_bridge_funding_wire_pipeline_r2725() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 7: get_bridge_funding_top_commitments_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_bridge_funding_top_commitments_r2725();
CREATE OR REPLACE FUNCTION get_bridge_funding_top_commitments_r2725()
RETURNS TABLE (
  investor_name text,
  investor_type text,
  commitment_amount_rupees bigint,
  wired_amount_rupees bigint,
  fill_pct numeric,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.investor_name, a.investor_type, w.commitment_amount_rupees, w.wired_amount_rupees,
         ROUND((w.wired_amount_rupees::numeric / NULLIF(w.commitment_amount_rupees,0)::numeric) * 100, 2)::numeric,
         w.outcome
  FROM bridge_funding_wires_r2725 w
  JOIN bridge_funding_asks_r2725 a ON a.id = w.ask_id
  ORDER BY w.commitment_amount_rupees DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_bridge_funding_top_commitments_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_bridge_funding_top_commitments_r2725() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC 8: get_bridge_funding_quarter_summary_r2725
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_bridge_funding_quarter_summary_r2725();
CREATE OR REPLACE FUNCTION get_bridge_funding_quarter_summary_r2725()
RETURNS TABLE (
  quarter_tag text,
  ask_count bigint,
  total_ask_rupees bigint,
  committed_rupees bigint,
  wired_rupees bigint,
  conversion_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.quarter_tag,
         COUNT(*)::bigint,
         SUM(a.ask_amount_rupees)::bigint,
         COALESCE(SUM(w.commitment_amount_rupees), 0)::bigint,
         COALESCE(SUM(w.wired_amount_rupees), 0)::bigint,
         ROUND((COALESCE(SUM(w.wired_amount_rupees),0)::numeric / NULLIF(SUM(a.ask_amount_rupees),0)::numeric) * 100, 2)::numeric
  FROM bridge_funding_asks_r2725 a
  LEFT JOIN bridge_funding_wires_r2725 w ON w.ask_id = a.id
  GROUP BY a.quarter_tag
  ORDER BY a.quarter_tag;
END;
$$;
REVOKE EXECUTE ON FUNCTION get_bridge_funding_quarter_summary_r2725() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION get_bridge_funding_quarter_summary_r2725() TO authenticated;

COMMIT;
