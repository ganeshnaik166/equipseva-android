BEGIN;

-- ============================================================================
-- Round r2735: Hospital Chain Quarterly Government Tender Win Rate
-- ============================================================================

-- Table 1: tenders
CREATE TABLE IF NOT EXISTS hospital_chain_govt_tenders_r2735 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  tender_ref text NOT NULL,
  tender_authority text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1','Q2','Q3','Q4')),
  fiscal_year text NOT NULL,
  bid_value_lakhs numeric(12,2) NOT NULL,
  bid_submitted_on date NOT NULL,
  result_announced_on date,
  outcome text NOT NULL CHECK (outcome IN ('won','lost','pending','disqualified','withdrawn')),
  loss_reason text CHECK (loss_reason IN ('price_too_high','price_too_low','technical_disqual','documentation_gap','vendor_blacklist','timeline_miss','none')),
  strategy_adjustment text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_govt_tenders_r2735 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_govt_tenders_r2735;
CREATE POLICY founder_all ON hospital_chain_govt_tenders_r2735 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: chain quarterly strategy
CREATE TABLE IF NOT EXISTS hospital_chain_tender_strategy_r2735 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  quarter text NOT NULL CHECK (quarter IN ('Q1','Q2','Q3','Q4')),
  fiscal_year text NOT NULL,
  target_wins int NOT NULL DEFAULT 0,
  target_value_lakhs numeric(12,2) NOT NULL DEFAULT 0,
  pricing_strategy text NOT NULL CHECK (pricing_strategy IN ('aggressive','balanced','premium','penetration')),
  next_quarter_focus text,
  owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed','paused')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_tender_strategy_r2735 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_tender_strategy_r2735;
CREATE POLICY founder_all ON hospital_chain_tender_strategy_r2735 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed tenders (12 rows)
INSERT INTO hospital_chain_govt_tenders_r2735 (chain_name, tender_ref, tender_authority, quarter, fiscal_year, bid_value_lakhs, bid_submitted_on, result_announced_on, outcome, loss_reason, strategy_adjustment, notes) VALUES
('Apollo Hospitals', 'AIIMS-DEL-2026-Q1-MRI', 'AIIMS Delhi', 'Q1', 'FY26', 245.50, '2026-04-12'::date, '2026-05-20'::date, 'won', 'none', 'Hold premium pricing on imaging', 'MRI AMC + spare parts bundle'),
('Apollo Hospitals', 'CGHS-MUM-2026-Q1-CT', 'CGHS Mumbai', 'Q1', 'FY26', 180.00, '2026-04-22'::date, '2026-06-01'::date, 'lost', 'price_too_high', 'Drop 8% on CT brackets in Mumbai', 'Lost to Siemens reseller by 6.2%'),
('Fortis Healthcare', 'ESI-BLR-2026-Q1-VENT', 'ESIC Karnataka', 'Q1', 'FY26', 92.30, '2026-04-15'::date, '2026-05-28'::date, 'won', 'none', 'Replicate ventilator bundle for Q2', 'Ventilator AMC 24-month'),
('Fortis Healthcare', 'DRDO-2026-Q1-OT', 'DRDO Hyderabad', 'Q1', 'FY26', 315.75, '2026-05-02'::date, '2026-06-10'::date, 'lost', 'technical_disqual', 'Get ISO 13485 cert before Q2', 'Tech spec gap on laminar flow'),
('Manipal Hospitals', 'KSPCB-2026-Q1-LAB', 'KSPCB Bangalore', 'Q1', 'FY26', 68.90, '2026-04-30'::date, '2026-06-05'::date, 'won', 'none', 'Lab equipment is repeatable', 'Pathology lab fitout'),
('Manipal Hospitals', 'AYUSH-2026-Q1-PHYSIO', 'AYUSH Ministry', 'Q1', 'FY26', 42.10, '2026-05-10'::date, NULL, 'pending', NULL, NULL, 'Awaiting Q2 result'),
('Max Healthcare', 'AIIMS-PAT-2026-Q1-ICU', 'AIIMS Patna', 'Q1', 'FY26', 410.20, '2026-04-08'::date, '2026-05-25'::date, 'won', 'none', 'ICU bundle works at premium', 'ICU bedside monitors + AMC'),
('Max Healthcare', 'RAILWAY-2026-Q1-AMB', 'Indian Railways Med', 'Q1', 'FY26', 125.40, '2026-04-18'::date, '2026-06-02'::date, 'lost', 'documentation_gap', 'Pre-cert all docs by month-end', 'GST cert expired in submission'),
('Narayana Health', 'GMC-VIJ-2026-Q1-DIAL', 'GMC Vijayawada', 'Q1', 'FY26', 78.60, '2026-04-25'::date, '2026-06-08'::date, 'won', 'none', 'Dialysis is high-margin', 'RO + dialysis machines'),
('Narayana Health', 'AP-HEALTH-2026-Q1-XRAY', 'AP Health Dept', 'Q1', 'FY26', 56.30, '2026-05-05'::date, '2026-06-12'::date, 'disqualified', 'vendor_blacklist', 'Resolve blacklist before re-bid', 'Pending blacklist appeal'),
('Yashoda Hospitals', 'TS-HEALTH-2026-Q1-CARD', 'TS Health Dept', 'Q1', 'FY26', 198.45, '2026-04-14'::date, '2026-05-30'::date, 'won', 'none', 'Cardiology bundle expand to AP', 'Cath lab + 5-yr AMC'),
('Yashoda Hospitals', 'KIMS-2026-Q1-NEURO', 'KIMS Govt Hospital', 'Q1', 'FY26', 87.20, '2026-05-08'::date, NULL, 'withdrawn', 'timeline_miss', 'Build 60-day lead buffer', 'Bid pulled - delivery timeline');

-- Seed strategy (6 rows)
INSERT INTO hospital_chain_tender_strategy_r2735 (chain_name, quarter, fiscal_year, target_wins, target_value_lakhs, pricing_strategy, next_quarter_focus, owner_email, status) VALUES
('Apollo Hospitals', 'Q2', 'FY26', 5, 800.00, 'premium', 'Imaging + ICU bundles', 'apollo-tenders@equipseva.in', 'active'),
('Fortis Healthcare', 'Q2', 'FY26', 4, 450.00, 'balanced', 'Get ISO 13485 + ventilator AMC', 'fortis-tenders@equipseva.in', 'active'),
('Manipal Hospitals', 'Q2', 'FY26', 3, 220.00, 'penetration', 'Lab + diagnostics expansion', 'manipal-tenders@equipseva.in', 'active'),
('Max Healthcare', 'Q2', 'FY26', 6, 950.00, 'premium', 'ICU + AIIMS regional pipeline', 'max-tenders@equipseva.in', 'active'),
('Narayana Health', 'Q2', 'FY26', 4, 380.00, 'aggressive', 'Dialysis + blacklist resolution', 'narayana-tenders@equipseva.in', 'active'),
('Yashoda Hospitals', 'Q2', 'FY26', 5, 520.00, 'balanced', 'Cardiology + neuro expansion', 'yashoda-tenders@equipseva.in', 'active');

-- ============================================================================
-- RPCs
-- ============================================================================

-- RPC 1: KPIs
DROP FUNCTION IF EXISTS founder_r2735_tender_kpis();
CREATE OR REPLACE FUNCTION founder_r2735_tender_kpis()
RETURNS TABLE (
  total_tenders bigint,
  total_won bigint,
  total_lost bigint,
  win_rate_pct numeric,
  total_bid_value_lakhs numeric,
  won_value_lakhs numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE outcome = 'won')::bigint,
    count(*) FILTER (WHERE outcome = 'lost')::bigint,
    ROUND(100.0 * count(*) FILTER (WHERE outcome = 'won')::numeric / NULLIF(count(*) FILTER (WHERE outcome IN ('won','lost')), 0), 2),
    COALESCE(SUM(bid_value_lakhs), 0)::numeric,
    COALESCE(SUM(bid_value_lakhs) FILTER (WHERE outcome = 'won'), 0)::numeric
  FROM hospital_chain_govt_tenders_r2735;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_tender_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_tender_kpis() TO authenticated;

-- RPC 2: by chain
DROP FUNCTION IF EXISTS founder_r2735_win_rate_by_chain();
CREATE OR REPLACE FUNCTION founder_r2735_win_rate_by_chain()
RETURNS TABLE (
  chain_name text,
  bids bigint,
  wins bigint,
  losses bigint,
  win_rate_pct numeric,
  total_value_lakhs numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.chain_name,
    count(*)::bigint,
    count(*) FILTER (WHERE t.outcome = 'won')::bigint,
    count(*) FILTER (WHERE t.outcome = 'lost')::bigint,
    ROUND(100.0 * count(*) FILTER (WHERE t.outcome = 'won')::numeric / NULLIF(count(*) FILTER (WHERE t.outcome IN ('won','lost')), 0), 2),
    COALESCE(SUM(t.bid_value_lakhs), 0)::numeric
  FROM hospital_chain_govt_tenders_r2735 t
  GROUP BY t.chain_name
  ORDER BY count(*) FILTER (WHERE t.outcome = 'won') DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_win_rate_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_win_rate_by_chain() TO authenticated;

-- RPC 3: loss reasons
DROP FUNCTION IF EXISTS founder_r2735_loss_reason_breakdown();
CREATE OR REPLACE FUNCTION founder_r2735_loss_reason_breakdown()
RETURNS TABLE (
  loss_reason text,
  lost_count bigint,
  lost_value_lakhs numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.loss_reason,
    count(*)::bigint,
    COALESCE(SUM(t.bid_value_lakhs), 0)::numeric
  FROM hospital_chain_govt_tenders_r2735 t
  WHERE t.outcome IN ('lost','disqualified','withdrawn')
    AND t.loss_reason IS NOT NULL
  GROUP BY t.loss_reason
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_loss_reason_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_loss_reason_breakdown() TO authenticated;

-- RPC 4: quarterly trend
DROP FUNCTION IF EXISTS founder_r2735_quarterly_trend();
CREATE OR REPLACE FUNCTION founder_r2735_quarterly_trend()
RETURNS TABLE (
  fiscal_year text,
  quarter text,
  bids bigint,
  wins bigint,
  win_rate_pct numeric,
  total_value_lakhs numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.fiscal_year,
    t.quarter,
    count(*)::bigint,
    count(*) FILTER (WHERE t.outcome = 'won')::bigint,
    ROUND(100.0 * count(*) FILTER (WHERE t.outcome = 'won')::numeric / NULLIF(count(*) FILTER (WHERE t.outcome IN ('won','lost')), 0), 2),
    COALESCE(SUM(t.bid_value_lakhs), 0)::numeric
  FROM hospital_chain_govt_tenders_r2735 t
  GROUP BY t.fiscal_year, t.quarter
  ORDER BY t.fiscal_year, t.quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_quarterly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_quarterly_trend() TO authenticated;

-- RPC 5: top tenders
DROP FUNCTION IF EXISTS founder_r2735_top_tenders();
CREATE OR REPLACE FUNCTION founder_r2735_top_tenders()
RETURNS TABLE (
  id uuid,
  chain_name text,
  tender_ref text,
  tender_authority text,
  outcome text,
  bid_value_lakhs numeric,
  bid_submitted_on date,
  loss_reason text,
  strategy_adjustment text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.id, t.chain_name, t.tender_ref, t.tender_authority,
    t.outcome, t.bid_value_lakhs, t.bid_submitted_on, t.loss_reason, t.strategy_adjustment
  FROM hospital_chain_govt_tenders_r2735 t
  ORDER BY t.bid_value_lakhs DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_top_tenders() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_top_tenders() TO authenticated;

-- RPC 6: chain strategy
DROP FUNCTION IF EXISTS founder_r2735_chain_strategy();
CREATE OR REPLACE FUNCTION founder_r2735_chain_strategy()
RETURNS TABLE (
  id uuid,
  chain_name text,
  quarter text,
  fiscal_year text,
  target_wins int,
  target_value_lakhs numeric,
  pricing_strategy text,
  next_quarter_focus text,
  owner_email text,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_name, s.quarter, s.fiscal_year,
         s.target_wins, s.target_value_lakhs, s.pricing_strategy,
         s.next_quarter_focus, s.owner_email, s.status
  FROM hospital_chain_tender_strategy_r2735 s
  ORDER BY s.chain_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_chain_strategy() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_chain_strategy() TO authenticated;

-- RPC 7: authority performance
DROP FUNCTION IF EXISTS founder_r2735_authority_performance();
CREATE OR REPLACE FUNCTION founder_r2735_authority_performance()
RETURNS TABLE (
  tender_authority text,
  bids bigint,
  wins bigint,
  win_rate_pct numeric,
  total_value_lakhs numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.tender_authority,
    count(*)::bigint,
    count(*) FILTER (WHERE t.outcome = 'won')::bigint,
    ROUND(100.0 * count(*) FILTER (WHERE t.outcome = 'won')::numeric / NULLIF(count(*) FILTER (WHERE t.outcome IN ('won','lost')), 0), 2),
    COALESCE(SUM(t.bid_value_lakhs), 0)::numeric
  FROM hospital_chain_govt_tenders_r2735 t
  GROUP BY t.tender_authority
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_authority_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_authority_performance() TO authenticated;

-- RPC 8: strategy adjustments
DROP FUNCTION IF EXISTS founder_r2735_strategy_adjustments();
CREATE OR REPLACE FUNCTION founder_r2735_strategy_adjustments()
RETURNS TABLE (
  chain_name text,
  tender_ref text,
  outcome text,
  loss_reason text,
  strategy_adjustment text,
  bid_value_lakhs numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.chain_name, t.tender_ref, t.outcome, t.loss_reason,
         t.strategy_adjustment, t.bid_value_lakhs
  FROM hospital_chain_govt_tenders_r2735 t
  WHERE t.strategy_adjustment IS NOT NULL
  ORDER BY t.bid_value_lakhs DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2735_strategy_adjustments() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2735_strategy_adjustments() TO authenticated;

COMMIT;
