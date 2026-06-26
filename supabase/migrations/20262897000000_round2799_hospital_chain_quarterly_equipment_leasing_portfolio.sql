BEGIN;

-- Round 2799 — Hospital Chain Quarterly Equipment Leasing Portfolio
-- Tracks lease structure across chain × asset × tenor × residual × outcome

CREATE TABLE IF NOT EXISTS hospital_chain_lease_portfolio_r2799 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('imaging','dialysis','ventilator','surgical','lab_analyzer','endoscopy','monitoring')),
  asset_model text NOT NULL,
  lease_structure text NOT NULL CHECK (lease_structure IN ('finance_lease','operating_lease','hire_purchase','pay_per_use','rental')),
  tenor_quarters int NOT NULL CHECK (tenor_quarters BETWEEN 1 AND 60),
  quarterly_lease_rupees bigint NOT NULL CHECK (quarterly_lease_rupees >= 0),
  residual_value_rupees bigint NOT NULL CHECK (residual_value_rupees >= 0),
  residual_percent numeric(5,2) NOT NULL CHECK (residual_percent BETWEEN 0 AND 100),
  asset_cost_rupees bigint NOT NULL CHECK (asset_cost_rupees > 0),
  units_deployed int NOT NULL CHECK (units_deployed > 0),
  quarter_started date NOT NULL,
  quarter_ending date NOT NULL,
  status text NOT NULL CHECK (status IN ('active','renewal_pending','renewed','returned','restructured','defaulted')),
  founder_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_lease_portfolio_r2799 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON hospital_chain_lease_portfolio_r2799 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_lease_outcomes_r2799 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lease_id uuid NOT NULL REFERENCES hospital_chain_lease_portfolio_r2799(id) ON DELETE CASCADE,
  outcome_quarter date NOT NULL,
  outcome_type text NOT NULL CHECK (outcome_type IN ('renew_same','renew_upgrade','return_asset','buyout','restructure','default')),
  outcome_value_rupees bigint NOT NULL CHECK (outcome_value_rupees >= 0),
  uptime_percent numeric(5,2) NOT NULL CHECK (uptime_percent BETWEEN 0 AND 100),
  utilisation_percent numeric(5,2) NOT NULL CHECK (utilisation_percent BETWEEN 0 AND 100),
  service_cost_rupees bigint NOT NULL DEFAULT 0 CHECK (service_cost_rupees >= 0),
  net_yield_percent numeric(6,2) NOT NULL,
  decision_owner text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_lease_outcomes_r2799 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON hospital_chain_lease_outcomes_r2799 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seeds: 6 leases
INSERT INTO hospital_chain_lease_portfolio_r2799
  (chain_code, chain_name, asset_category, asset_model, lease_structure, tenor_quarters, quarterly_lease_rupees, residual_value_rupees, residual_percent, asset_cost_rupees, units_deployed, quarter_started, quarter_ending, status, founder_notes)
VALUES
  ('APOLLO','Apollo Hospitals','imaging','GE Optima MR450w 1.5T','finance_lease',20,4200000,18000000,15.00,120000000,3,'2025-01-01'::date,'2029-12-31'::date,'active','flagship MR fleet — anchor'),
  ('FORTIS','Fortis Healthcare','dialysis','Fresenius 5008S CorDiax','operating_lease',12,850000,3500000,12.50,28000000,18,'2025-04-01'::date,'2028-03-31'::date,'renewal_pending','renewal Q3 — push pay-per-use'),
  ('MAX','Max Healthcare','ventilator','Hamilton C6','pay_per_use',8,620000,1800000,8.00,22500000,24,'2026-01-01'::date,'2027-12-31'::date,'active','per-use floor 70% — beating'),
  ('NARAYANA','Narayana Health','surgical','da Vinci Xi (rental swap)','rental',4,9800000,0,0.00,210000000,1,'2026-04-01'::date,'2027-03-31'::date,'restructured','converted from finance — saved'),
  ('MANIPAL','Manipal Hospitals','lab_analyzer','Roche cobas 8000','hire_purchase',16,1450000,2200000,4.50,48000000,6,'2024-10-01'::date,'2028-09-30'::date,'active','autoswitch to ownership Q14'),
  ('AIIMS','AIIMS Delhi Government','endoscopy','Olympus EVIS X1','finance_lease',24,2100000,11000000,22.00,50000000,4,'2025-07-01'::date,'2031-06-30'::date,'returned','tender lapse — returning Q8');

-- Seeds: 6 outcomes
INSERT INTO hospital_chain_lease_outcomes_r2799
  (lease_id, outcome_quarter, outcome_type, outcome_value_rupees, uptime_percent, utilisation_percent, service_cost_rupees, net_yield_percent, decision_owner, notes)
SELECT id, '2026-03-31'::date, 'renew_same', 4200000, 98.50, 84.00, 380000, 14.80, 'cfo_apollo', 'no escalation requested' FROM hospital_chain_lease_portfolio_r2799 WHERE chain_code = 'APOLLO'
UNION ALL
SELECT id, '2026-03-31'::date, 'renew_upgrade', 920000, 96.20, 78.50, 410000, 11.40, 'biomed_fortis', 'upgrade to 5008X — +8% lease' FROM hospital_chain_lease_portfolio_r2799 WHERE chain_code = 'FORTIS'
UNION ALL
SELECT id, '2026-06-30'::date, 'buyout', 9200000, 99.10, 91.00, 220000, 18.20, 'cmo_max', 'per-use volume blew past floor' FROM hospital_chain_lease_portfolio_r2799 WHERE chain_code = 'MAX'
UNION ALL
SELECT id, '2026-06-30'::date, 'restructure', 8200000, 94.00, 65.00, 1900000, 6.50, 'coo_narayana', 'rental swap saved default' FROM hospital_chain_lease_portfolio_r2799 WHERE chain_code = 'NARAYANA'
UNION ALL
SELECT id, '2026-03-31'::date, 'renew_same', 1450000, 97.80, 88.50, 295000, 12.90, 'lab_dir_manipal', 'reagent attach 92%' FROM hospital_chain_lease_portfolio_r2799 WHERE chain_code = 'MANIPAL'
UNION ALL
SELECT id, '2026-06-30'::date, 'return_asset', 0, 89.40, 52.00, 580000, -2.40, 'procurement_aiims', 'tender lapse — net negative' FROM hospital_chain_lease_portfolio_r2799 WHERE chain_code = 'AIIMS';

-- RPC 1: portfolio rollup
DROP FUNCTION IF EXISTS founder_chain_lease_portfolio_rollup_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_portfolio_rollup_r2799()
RETURNS TABLE (
  total_leases bigint,
  active_leases bigint,
  renewal_pending bigint,
  returned_leases bigint,
  total_units bigint,
  gross_asset_value_rupees bigint,
  quarterly_lease_run_rate bigint,
  residual_at_risk_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status = 'active')::bigint,
    COUNT(*) FILTER (WHERE status = 'renewal_pending')::bigint,
    COUNT(*) FILTER (WHERE status = 'returned')::bigint,
    COALESCE(SUM(units_deployed),0)::bigint,
    COALESCE(SUM(asset_cost_rupees),0)::bigint,
    COALESCE(SUM(quarterly_lease_rupees) FILTER (WHERE status IN ('active','renewal_pending','renewed')),0)::bigint,
    COALESCE(SUM(residual_value_rupees) FILTER (WHERE status IN ('renewal_pending','returned','defaulted')),0)::bigint
  FROM hospital_chain_lease_portfolio_r2799;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_portfolio_rollup_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_portfolio_rollup_r2799() TO authenticated;

-- RPC 2: by chain
DROP FUNCTION IF EXISTS founder_chain_lease_by_chain_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_by_chain_r2799()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  active_leases bigint,
  units bigint,
  quarterly_rupees bigint,
  avg_residual_percent numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_code,
    MAX(p.chain_name),
    COUNT(*)::bigint,
    SUM(p.units_deployed)::bigint,
    SUM(p.quarterly_lease_rupees)::bigint,
    ROUND(AVG(p.residual_percent),2)
  FROM hospital_chain_lease_portfolio_r2799 p
  GROUP BY p.chain_code
  ORDER BY SUM(p.quarterly_lease_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_by_chain_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_by_chain_r2799() TO authenticated;

-- RPC 3: by asset category
DROP FUNCTION IF EXISTS founder_chain_lease_by_asset_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_by_asset_r2799()
RETURNS TABLE (
  asset_category text,
  leases bigint,
  units bigint,
  gross_value_rupees bigint,
  avg_tenor_quarters numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.asset_category,
    COUNT(*)::bigint,
    SUM(p.units_deployed)::bigint,
    SUM(p.asset_cost_rupees)::bigint,
    ROUND(AVG(p.tenor_quarters),1)
  FROM hospital_chain_lease_portfolio_r2799 p
  GROUP BY p.asset_category
  ORDER BY SUM(p.asset_cost_rupees) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_by_asset_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_by_asset_r2799() TO authenticated;

-- RPC 4: by lease structure
DROP FUNCTION IF EXISTS founder_chain_lease_by_structure_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_by_structure_r2799()
RETURNS TABLE (
  lease_structure text,
  leases bigint,
  avg_quarterly_rupees bigint,
  avg_residual_percent numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.lease_structure,
    COUNT(*)::bigint,
    ROUND(AVG(p.quarterly_lease_rupees))::bigint,
    ROUND(AVG(p.residual_percent),2)
  FROM hospital_chain_lease_portfolio_r2799 p
  GROUP BY p.lease_structure
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_by_structure_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_by_structure_r2799() TO authenticated;

-- RPC 5: outcome mix
DROP FUNCTION IF EXISTS founder_chain_lease_outcome_mix_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_outcome_mix_r2799()
RETURNS TABLE (
  outcome_type text,
  outcomes bigint,
  avg_uptime numeric,
  avg_utilisation numeric,
  avg_net_yield numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.outcome_type,
    COUNT(*)::bigint,
    ROUND(AVG(o.uptime_percent),2),
    ROUND(AVG(o.utilisation_percent),2),
    ROUND(AVG(o.net_yield_percent),2)
  FROM hospital_chain_lease_outcomes_r2799 o
  GROUP BY o.outcome_type
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_outcome_mix_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_outcome_mix_r2799() TO authenticated;

-- RPC 6: renewal funnel
DROP FUNCTION IF EXISTS founder_chain_lease_renewal_funnel_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_renewal_funnel_r2799()
RETURNS TABLE (
  chain_code text,
  asset_model text,
  status text,
  quarter_ending date,
  residual_value_rupees bigint,
  founder_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_code, p.asset_model, p.status, p.quarter_ending, p.residual_value_rupees, p.founder_notes
  FROM hospital_chain_lease_portfolio_r2799 p
  WHERE p.status IN ('renewal_pending','restructured','returned','defaulted')
  ORDER BY p.quarter_ending ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_renewal_funnel_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_renewal_funnel_r2799() TO authenticated;

-- RPC 7: lease detail with outcome
DROP FUNCTION IF EXISTS founder_chain_lease_detail_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_detail_r2799()
RETURNS TABLE (
  chain_code text,
  asset_category text,
  asset_model text,
  lease_structure text,
  tenor_quarters int,
  quarterly_lease_rupees bigint,
  status text,
  outcome_type text,
  net_yield_percent numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_code, p.asset_category, p.asset_model, p.lease_structure, p.tenor_quarters,
    p.quarterly_lease_rupees, p.status, o.outcome_type, o.net_yield_percent
  FROM hospital_chain_lease_portfolio_r2799 p
  LEFT JOIN hospital_chain_lease_outcomes_r2799 o ON o.lease_id = p.id
  ORDER BY p.quarterly_lease_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_detail_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_detail_r2799() TO authenticated;

-- RPC 8: top performers
DROP FUNCTION IF EXISTS founder_chain_lease_top_yield_r2799();
CREATE OR REPLACE FUNCTION founder_chain_lease_top_yield_r2799()
RETURNS TABLE (
  chain_code text,
  asset_model text,
  outcome_type text,
  uptime_percent numeric,
  utilisation_percent numeric,
  net_yield_percent numeric,
  decision_owner text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.chain_code, p.asset_model, o.outcome_type, o.uptime_percent, o.utilisation_percent, o.net_yield_percent, o.decision_owner
  FROM hospital_chain_lease_outcomes_r2799 o
  JOIN hospital_chain_lease_portfolio_r2799 p ON p.id = o.lease_id
  ORDER BY o.net_yield_percent DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_lease_top_yield_r2799() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_lease_top_yield_r2799() TO authenticated;

COMMIT;