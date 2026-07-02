BEGIN;

-- =====================================================================
-- Round 2731 — Hospital Chain Quarterly Payer Cycle Impact
-- Tracks how quarterly insurance/govt payer claim cycles affect hospital
-- chain cash flow, AMC payment timing, and our role in cushioning delays.
-- =====================================================================

CREATE TABLE IF NOT EXISTS hospital_chain_payer_cycle_r2731 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  payer_name text NOT NULL,
  payer_kind text NOT NULL CHECK (payer_kind IN ('cghs','esic','state_govt','private_insurer','tpa','self_pay')),
  fiscal_quarter text NOT NULL CHECK (fiscal_quarter IN ('Q1_FY26','Q2_FY26','Q3_FY26','Q4_FY26','Q1_FY27')),
  cycle_start_date date NOT NULL,
  cycle_close_date date NOT NULL,
  claims_submitted_rupees bigint NOT NULL CHECK (claims_submitted_rupees >= 0),
  claims_settled_rupees bigint NOT NULL CHECK (claims_settled_rupees >= 0),
  expected_settlement_days int NOT NULL CHECK (expected_settlement_days >= 0),
  actual_settlement_days int NOT NULL CHECK (actual_settlement_days >= 0),
  delay_days int GENERATED ALWAYS AS (actual_settlement_days - expected_settlement_days) STORED,
  amc_invoice_impact_rupees bigint NOT NULL DEFAULT 0,
  our_amc_role text NOT NULL CHECK (our_amc_role IN ('on_time','grace_extended','bridge_credit','partial_freeze','escalated','renegotiated')),
  cycle_outcome text NOT NULL CHECK (cycle_outcome IN ('healthy','watch','strained','distressed','recovered')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_payer_cycle_r2731 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_payer_cycle_r2731;
CREATE POLICY founder_all ON hospital_chain_payer_cycle_r2731
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_amc_cushion_r2731 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  fiscal_quarter text NOT NULL CHECK (fiscal_quarter IN ('Q1_FY26','Q2_FY26','Q3_FY26','Q4_FY26','Q1_FY27')),
  amc_invoices_due_rupees bigint NOT NULL CHECK (amc_invoices_due_rupees >= 0),
  amc_invoices_collected_rupees bigint NOT NULL CHECK (amc_invoices_collected_rupees >= 0),
  bridge_credit_extended_rupees bigint NOT NULL DEFAULT 0,
  dso_days int NOT NULL CHECK (dso_days >= 0),
  payer_concentration_top1_pct numeric(5,2) NOT NULL CHECK (payer_concentration_top1_pct >= 0 AND payer_concentration_top1_pct <= 100),
  cushion_strategy text NOT NULL CHECK (cushion_strategy IN ('no_action','soft_reminder','grace_period','split_invoice','bridge_finance','renegotiate_terms','escalate_legal')),
  renewal_risk_score int NOT NULL CHECK (renewal_risk_score BETWEEN 0 AND 100),
  recovered_in_quarter boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_amc_cushion_r2731 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_amc_cushion_r2731;
CREATE POLICY founder_all ON hospital_chain_amc_cushion_r2731
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =====================================================================
-- Seed data
-- =====================================================================

INSERT INTO hospital_chain_payer_cycle_r2731
  (chain_name, payer_name, payer_kind, fiscal_quarter, cycle_start_date, cycle_close_date,
   claims_submitted_rupees, claims_settled_rupees, expected_settlement_days, actual_settlement_days,
   amc_invoice_impact_rupees, our_amc_role, cycle_outcome, notes)
VALUES
  ('Apollo Tier-2 Cluster', 'CGHS', 'cghs', 'Q1_FY26', '2026-04-01'::date, '2026-06-30'::date,
   42000000, 31000000, 60, 92, 480000, 'grace_extended', 'strained',
   'Q1 CGHS rate revision pending; chain CFO requested 30d grace on AMC March invoice'),
  ('KIMS Andhra Network', 'Aarogyasri AP', 'state_govt', 'Q1_FY26', '2026-04-01'::date, '2026-06-30'::date,
   58000000, 22000000, 75, 145, 720000, 'bridge_credit', 'distressed',
   'AP govt budget freeze; 38% settlement only; offered 60d bridge on 2 AMC invoices'),
  ('Yashoda Hospitals', 'Star Health TPA', 'tpa', 'Q2_FY26', '2026-07-01'::date, '2026-09-30'::date,
   31000000, 29500000, 45, 51, 0, 'on_time', 'healthy',
   'TPA settled within tolerance; no AMC impact'),
  ('Care Hospitals Group', 'ESIC', 'esic', 'Q2_FY26', '2026-07-01'::date, '2026-09-30'::date,
   18000000, 14200000, 90, 118, 240000, 'grace_extended', 'watch',
   'ESIC reconciliation delays; partial AMC March + April grace approved'),
  ('Sunshine Multispecialty', 'Self-pay + Cash', 'self_pay', 'Q3_FY26', '2026-10-01'::date, '2026-12-31'::date,
   8500000, 8500000, 0, 0, 0, 'on_time', 'healthy',
   'Cash-pay heavy; zero payer dependency; AMC always on time'),
  ('Apollo Tier-2 Cluster', 'Aarogyasri TS', 'state_govt', 'Q2_FY26', '2026-07-01'::date, '2026-09-30'::date,
   36000000, 33000000, 75, 81, 120000, 'on_time', 'recovered',
   'Telangana cleared backlog; chain recovered, paid Q1 grace dues'),
  ('Maxivision Eye Hospitals', 'Bajaj Allianz', 'private_insurer', 'Q3_FY26', '2026-10-01'::date, '2026-12-31'::date,
   12000000, 11800000, 30, 34, 0, 'on_time', 'healthy',
   'Eye-care chain; lean payer mix; AMC on time'),
  ('Rainbow Children Hospitals', 'CGHS', 'cghs', 'Q3_FY26', '2026-10-01'::date, '2026-12-31'::date,
   22000000, 14000000, 60, 110, 360000, 'partial_freeze', 'strained',
   'CGHS pediatric rate dispute; froze 50% of AMC service calls until 30% paid'),
  ('Continental Hospitals', 'HDFC Ergo', 'private_insurer', 'Q1_FY26', '2026-04-01'::date, '2026-06-30'::date,
   28000000, 27500000, 30, 38, 0, 'on_time', 'healthy',
   'Tier-1 private insurer; well behaved'),
  ('AIG Hospitals', 'Aarogyasri TS', 'state_govt', 'Q4_FY26', '2026-01-01'::date, '2026-03-31'::date,
   45000000, 28000000, 75, 165, 960000, 'escalated', 'distressed',
   'Election-quarter budget freeze; escalated to chain CMD; AMC put on legal hold');

INSERT INTO hospital_chain_amc_cushion_r2731
  (chain_name, fiscal_quarter, amc_invoices_due_rupees, amc_invoices_collected_rupees,
   bridge_credit_extended_rupees, dso_days, payer_concentration_top1_pct,
   cushion_strategy, renewal_risk_score, recovered_in_quarter, notes)
VALUES
  ('Apollo Tier-2 Cluster', 'Q1_FY26', 1800000, 1320000, 0, 78, 42.50,
   'grace_period', 35, true,
   'Granted 30d grace on March invoice; recovered by mid-Q2'),
  ('KIMS Andhra Network', 'Q1_FY26', 2400000, 960000, 720000, 142, 68.30,
   'bridge_finance', 72, false,
   'AP govt heavy chain; 60% concentration on Aarogyasri; bridge extended Q1→Q2'),
  ('Yashoda Hospitals', 'Q2_FY26', 1600000, 1600000, 0, 32, 28.40,
   'no_action', 12, true,
   'Diversified payer mix; no intervention needed'),
  ('Care Hospitals Group', 'Q2_FY26', 2100000, 1480000, 0, 86, 35.60,
   'split_invoice', 28, true,
   'Split April + May invoice into 3 tranches; collected 70% in quarter'),
  ('Sunshine Multispecialty', 'Q3_FY26', 480000, 480000, 0, 18, 8.20,
   'no_action', 5, true,
   'Cash-pay heavy; AMC always on time'),
  ('Rainbow Children Hospitals', 'Q3_FY26', 1200000, 720000, 0, 95, 52.10,
   'renegotiate_terms', 48, false,
   'Renegotiated to milestone-billing tied to CGHS receipts'),
  ('AIG Hospitals', 'Q4_FY26', 3200000, 1100000, 0, 168, 71.40,
   'escalate_legal', 88, false,
   'Election quarter; chain DSO blew out; legal escalation drafted'),
  ('Continental Hospitals', 'Q1_FY26', 1400000, 1400000, 0, 35, 32.10,
   'no_action', 10, true,
   'Tier-1 chain; healthy'),
  ('Maxivision Eye Hospitals', 'Q3_FY26', 380000, 380000, 0, 22, 18.50,
   'no_action', 8, true,
   'Lean specialty chain; no intervention'),
  ('Apollo Tier-2 Cluster', 'Q2_FY26', 1900000, 1900000, 0, 41, 40.20,
   'soft_reminder', 18, true,
   'Q1 grace cleared; back to on-time');

-- =====================================================================
-- RPC 1 — Chain × payer cycle ledger
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_chain_payer_cycle_ledger();
CREATE OR REPLACE FUNCTION founder_r2731_chain_payer_cycle_ledger()
RETURNS TABLE(
  chain_name text,
  payer_name text,
  payer_kind text,
  fiscal_quarter text,
  claims_submitted_rupees bigint,
  claims_settled_rupees bigint,
  settlement_pct numeric,
  delay_days int,
  amc_invoice_impact_rupees bigint,
  our_amc_role text,
  cycle_outcome text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      p.chain_name,
      p.payer_name,
      p.payer_kind,
      p.fiscal_quarter,
      p.claims_submitted_rupees,
      p.claims_settled_rupees,
      ROUND(100.0 * p.claims_settled_rupees / NULLIF(p.claims_submitted_rupees, 0), 2) AS settlement_pct,
      p.delay_days,
      p.amc_invoice_impact_rupees,
      p.our_amc_role,
      p.cycle_outcome
    FROM hospital_chain_payer_cycle_r2731 p
    ORDER BY p.fiscal_quarter DESC, p.amc_invoice_impact_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_chain_payer_cycle_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_chain_payer_cycle_ledger() TO authenticated;

-- =====================================================================
-- RPC 2 — Quarterly delay heatmap
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_quarterly_delay_heatmap();
CREATE OR REPLACE FUNCTION founder_r2731_quarterly_delay_heatmap()
RETURNS TABLE(
  fiscal_quarter text,
  payer_kind text,
  cycles_count bigint,
  avg_delay_days numeric,
  max_delay_days int,
  total_claims_rupees bigint,
  total_amc_impact_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      p.fiscal_quarter,
      p.payer_kind,
      COUNT(*)::bigint AS cycles_count,
      ROUND(AVG(p.delay_days)::numeric, 1) AS avg_delay_days,
      MAX(p.delay_days) AS max_delay_days,
      SUM(p.claims_submitted_rupees)::bigint AS total_claims_rupees,
      SUM(p.amc_invoice_impact_rupees)::bigint AS total_amc_impact_rupees
    FROM hospital_chain_payer_cycle_r2731 p
    GROUP BY p.fiscal_quarter, p.payer_kind
    ORDER BY p.fiscal_quarter DESC, avg_delay_days DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_quarterly_delay_heatmap() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_quarterly_delay_heatmap() TO authenticated;

-- =====================================================================
-- RPC 3 — Chain cushion strategy ledger
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_chain_cushion_ledger();
CREATE OR REPLACE FUNCTION founder_r2731_chain_cushion_ledger()
RETURNS TABLE(
  chain_name text,
  fiscal_quarter text,
  amc_invoices_due_rupees bigint,
  amc_invoices_collected_rupees bigint,
  collection_pct numeric,
  bridge_credit_extended_rupees bigint,
  dso_days int,
  payer_concentration_top1_pct numeric,
  cushion_strategy text,
  renewal_risk_score int,
  recovered_in_quarter boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      c.chain_name,
      c.fiscal_quarter,
      c.amc_invoices_due_rupees,
      c.amc_invoices_collected_rupees,
      ROUND(100.0 * c.amc_invoices_collected_rupees / NULLIF(c.amc_invoices_due_rupees, 0), 2) AS collection_pct,
      c.bridge_credit_extended_rupees,
      c.dso_days,
      c.payer_concentration_top1_pct,
      c.cushion_strategy,
      c.renewal_risk_score,
      c.recovered_in_quarter
    FROM hospital_chain_amc_cushion_r2731 c
    ORDER BY c.renewal_risk_score DESC, c.dso_days DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_chain_cushion_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_chain_cushion_ledger() TO authenticated;

-- =====================================================================
-- RPC 4 — Top distressed chain cycles
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_distressed_cycles();
CREATE OR REPLACE FUNCTION founder_r2731_distressed_cycles()
RETURNS TABLE(
  chain_name text,
  payer_name text,
  fiscal_quarter text,
  delay_days int,
  settlement_pct numeric,
  amc_invoice_impact_rupees bigint,
  our_amc_role text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      p.chain_name,
      p.payer_name,
      p.fiscal_quarter,
      p.delay_days,
      ROUND(100.0 * p.claims_settled_rupees / NULLIF(p.claims_submitted_rupees, 0), 2) AS settlement_pct,
      p.amc_invoice_impact_rupees,
      p.our_amc_role,
      p.notes
    FROM hospital_chain_payer_cycle_r2731 p
    WHERE p.cycle_outcome IN ('strained', 'distressed')
    ORDER BY p.amc_invoice_impact_rupees DESC, p.delay_days DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_distressed_cycles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_distressed_cycles() TO authenticated;

-- =====================================================================
-- RPC 5 — Our AMC role distribution
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_amc_role_distribution();
CREATE OR REPLACE FUNCTION founder_r2731_amc_role_distribution()
RETURNS TABLE(
  our_amc_role text,
  cycle_count bigint,
  total_amc_impact_rupees bigint,
  avg_delay_days numeric,
  distinct_chains bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      p.our_amc_role,
      COUNT(*)::bigint AS cycle_count,
      SUM(p.amc_invoice_impact_rupees)::bigint AS total_amc_impact_rupees,
      ROUND(AVG(p.delay_days)::numeric, 1) AS avg_delay_days,
      COUNT(DISTINCT p.chain_name)::bigint AS distinct_chains
    FROM hospital_chain_payer_cycle_r2731 p
    GROUP BY p.our_amc_role
    ORDER BY total_amc_impact_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_amc_role_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_amc_role_distribution() TO authenticated;

-- =====================================================================
-- RPC 6 — Chain renewal risk board
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_renewal_risk_board();
CREATE OR REPLACE FUNCTION founder_r2731_renewal_risk_board()
RETURNS TABLE(
  chain_name text,
  total_quarters bigint,
  avg_dso_days numeric,
  avg_renewal_risk numeric,
  total_bridge_extended_rupees bigint,
  recovered_quarters bigint,
  risk_band text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      c.chain_name,
      COUNT(*)::bigint AS total_quarters,
      ROUND(AVG(c.dso_days)::numeric, 1) AS avg_dso_days,
      ROUND(AVG(c.renewal_risk_score)::numeric, 1) AS avg_renewal_risk,
      SUM(c.bridge_credit_extended_rupees)::bigint AS total_bridge_extended_rupees,
      SUM(CASE WHEN c.recovered_in_quarter THEN 1 ELSE 0 END)::bigint AS recovered_quarters,
      CASE
        WHEN AVG(c.renewal_risk_score) >= 70 THEN 'red'
        WHEN AVG(c.renewal_risk_score) >= 40 THEN 'amber'
        ELSE 'green'
      END AS risk_band
    FROM hospital_chain_amc_cushion_r2731 c
    GROUP BY c.chain_name
    ORDER BY avg_renewal_risk DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_renewal_risk_board() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_renewal_risk_board() TO authenticated;

-- =====================================================================
-- RPC 7 — Headline KPIs
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_headline_kpis();
CREATE OR REPLACE FUNCTION founder_r2731_headline_kpis()
RETURNS TABLE(
  total_cycles bigint,
  distressed_cycles bigint,
  total_claims_rupees bigint,
  total_amc_impact_rupees bigint,
  total_bridge_extended_rupees bigint,
  avg_delay_days numeric,
  distinct_chains bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::bigint FROM hospital_chain_payer_cycle_r2731) AS total_cycles,
      (SELECT COUNT(*)::bigint FROM hospital_chain_payer_cycle_r2731 WHERE cycle_outcome IN ('strained','distressed')) AS distressed_cycles,
      (SELECT COALESCE(SUM(claims_submitted_rupees),0)::bigint FROM hospital_chain_payer_cycle_r2731) AS total_claims_rupees,
      (SELECT COALESCE(SUM(amc_invoice_impact_rupees),0)::bigint FROM hospital_chain_payer_cycle_r2731) AS total_amc_impact_rupees,
      (SELECT COALESCE(SUM(bridge_credit_extended_rupees),0)::bigint FROM hospital_chain_amc_cushion_r2731) AS total_bridge_extended_rupees,
      (SELECT ROUND(AVG(delay_days)::numeric, 1) FROM hospital_chain_payer_cycle_r2731) AS avg_delay_days,
      (SELECT COUNT(DISTINCT chain_name)::bigint FROM hospital_chain_payer_cycle_r2731) AS distinct_chains;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_headline_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_headline_kpis() TO authenticated;

-- =====================================================================
-- RPC 8 — Cushion strategy mix
-- =====================================================================
DROP FUNCTION IF EXISTS founder_r2731_cushion_strategy_mix();
CREATE OR REPLACE FUNCTION founder_r2731_cushion_strategy_mix()
RETURNS TABLE(
  cushion_strategy text,
  quarter_count bigint,
  total_due_rupees bigint,
  total_collected_rupees bigint,
  collection_pct numeric,
  avg_renewal_risk numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      c.cushion_strategy,
      COUNT(*)::bigint AS quarter_count,
      SUM(c.amc_invoices_due_rupees)::bigint AS total_due_rupees,
      SUM(c.amc_invoices_collected_rupees)::bigint AS total_collected_rupees,
      ROUND(100.0 * SUM(c.amc_invoices_collected_rupees) / NULLIF(SUM(c.amc_invoices_due_rupees), 0), 2) AS collection_pct,
      ROUND(AVG(c.renewal_risk_score)::numeric, 1) AS avg_renewal_risk
    FROM hospital_chain_amc_cushion_r2731 c
    GROUP BY c.cushion_strategy
    ORDER BY quarter_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2731_cushion_strategy_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2731_cushion_strategy_mix() TO authenticated;

COMMIT;
