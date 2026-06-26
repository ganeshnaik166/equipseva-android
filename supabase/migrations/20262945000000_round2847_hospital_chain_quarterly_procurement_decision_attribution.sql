BEGIN;

-- =============================================================================
-- Round 2847 — Hospital Chain Quarterly Procurement Decision Attribution
-- =============================================================================

CREATE TABLE IF NOT EXISTS chain_procurement_decisions_r2847 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  decision_quarter text NOT NULL,
  decision_category text NOT NULL CHECK (decision_category IN ('amc_renewal','equipment_purchase','vendor_consolidation','spare_parts_contract','service_expansion')),
  stakeholders text NOT NULL,
  our_influence_score numeric(5,2) NOT NULL CHECK (our_influence_score BETWEEN 0 AND 100),
  close_status text NOT NULL CHECK (close_status IN ('won','lost','pending','deferred','partial')),
  contract_value_rupees bigint NOT NULL CHECK (contract_value_rupees >= 0),
  our_cost_rupees bigint NOT NULL CHECK (our_cost_rupees >= 0),
  verdict text NOT NULL CHECK (verdict IN ('strong_win','marginal_win','break_even','loss','strategic_loss')),
  decided_at date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_procurement_decisions_r2847 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_procurement_decisions_r2847;
CREATE POLICY founder_all ON chain_procurement_decisions_r2847 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS chain_attribution_touchpoints_r2847 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id uuid NOT NULL REFERENCES chain_procurement_decisions_r2847(id) ON DELETE CASCADE,
  touchpoint_type text NOT NULL CHECK (touchpoint_type IN ('founder_visit','engineer_demo','exec_dinner','rfp_response','reference_call','case_study','onsite_audit')),
  touchpoint_date date NOT NULL,
  owner_name text NOT NULL,
  influence_delta numeric(5,2) NOT NULL CHECK (influence_delta BETWEEN -50 AND 50),
  cost_rupees bigint NOT NULL DEFAULT 0 CHECK (cost_rupees >= 0),
  outcome_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_attribution_touchpoints_r2847 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_attribution_touchpoints_r2847;
CREATE POLICY founder_all ON chain_attribution_touchpoints_r2847 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed decisions
INSERT INTO chain_procurement_decisions_r2847 (chain_name, decision_quarter, decision_category, stakeholders, our_influence_score, close_status, contract_value_rupees, our_cost_rupees, verdict, decided_at, notes) VALUES
  ('Apollo Hospitals Hyderabad','2026-Q2','amc_renewal','CFO, Biomed Head, COO',82.50,'won',8400000,420000,'strong_win','2026-05-12'::date,'Renewed 18-month AMC after founder dinner + 2 onsite audits.'),
  ('KIMS Group','2026-Q2','vendor_consolidation','Procurement Director, MD',61.00,'partial',12500000,860000,'marginal_win','2026-04-28'::date,'Won 60% of MRI+CT bucket; lost ventilator line.'),
  ('Yashoda Hospitals','2026-Q1','equipment_purchase','Biomed Lead, Finance Head',45.50,'lost',6700000,310000,'strategic_loss','2026-03-15'::date,'Lost to Siemens direct; learned RFP signal too late.'),
  ('Care Hospitals Banjara','2026-Q2','spare_parts_contract','Biomed Manager, CFO',71.25,'won',2200000,95000,'strong_win','2026-06-02'::date,'Bonded-parts pitch sealed deal; 24-month exclusive.'),
  ('Continental Hospitals','2026-Q1','service_expansion','COO, Medical Director',38.00,'deferred',5400000,180000,'break_even','2026-02-20'::date,'Deferred to Q3 pending board approval.'),
  ('Rainbow Childrens Group','2026-Q2','amc_renewal','Procurement Head, CFO',74.00,'won',4800000,240000,'marginal_win','2026-05-30'::date,'Renewed but pricing trimmed 8%.'),
  ('AIG Hospitals','2026-Q1','vendor_consolidation','MD, Biomed Head',58.50,'pending',9800000,540000,'break_even','2026-06-18'::date,'Still in negotiation; decision moved to Q3.');

-- Seed touchpoints
INSERT INTO chain_attribution_touchpoints_r2847 (decision_id, touchpoint_type, touchpoint_date, owner_name, influence_delta, cost_rupees, outcome_note)
SELECT id, 'founder_visit', '2026-04-10'::date, 'Ganesh D', 18.50, 25000, 'Onsite walkthrough with CFO; surfaced uptime data.'
FROM chain_procurement_decisions_r2847 WHERE chain_name='Apollo Hospitals Hyderabad' LIMIT 1;

INSERT INTO chain_attribution_touchpoints_r2847 (decision_id, touchpoint_type, touchpoint_date, owner_name, influence_delta, cost_rupees, outcome_note)
SELECT id, 'reference_call', '2026-04-22'::date, 'Sales Lead Priya', 12.00, 0, 'KIMS CFO spoke to Apollo CFO; confirmed reliability.'
FROM chain_procurement_decisions_r2847 WHERE chain_name='KIMS Group' LIMIT 1;

INSERT INTO chain_attribution_touchpoints_r2847 (decision_id, touchpoint_type, touchpoint_date, owner_name, influence_delta, cost_rupees, outcome_note)
SELECT id, 'engineer_demo', '2026-03-01'::date, 'Sr Engineer Rakesh', 8.00, 18000, 'Live ventilator board swap demo on floor.'
FROM chain_procurement_decisions_r2847 WHERE chain_name='Yashoda Hospitals' LIMIT 1;

INSERT INTO chain_attribution_touchpoints_r2847 (decision_id, touchpoint_type, touchpoint_date, owner_name, influence_delta, cost_rupees, outcome_note)
SELECT id, 'onsite_audit', '2026-05-15'::date, 'QA Lead Sneha', 22.00, 35000, 'Bonded-parts inventory audit closed counterfeit fears.'
FROM chain_procurement_decisions_r2847 WHERE chain_name='Care Hospitals Banjara' LIMIT 1;

INSERT INTO chain_attribution_touchpoints_r2847 (decision_id, touchpoint_type, touchpoint_date, owner_name, influence_delta, cost_rupees, outcome_note)
SELECT id, 'exec_dinner', '2026-02-05'::date, 'Ganesh D', 10.50, 42000, 'Continental MD + COO dinner; positive but slow.'
FROM chain_procurement_decisions_r2847 WHERE chain_name='Continental Hospitals' LIMIT 1;

INSERT INTO chain_attribution_touchpoints_r2847 (decision_id, touchpoint_type, touchpoint_date, owner_name, influence_delta, cost_rupees, outcome_note)
SELECT id, 'case_study', '2026-05-20'::date, 'Marketing Lead Anu', 7.50, 12000, 'Shared 3 anonymized AMC case studies pre-renewal.'
FROM chain_procurement_decisions_r2847 WHERE chain_name='Rainbow Childrens Group' LIMIT 1;

INSERT INTO chain_attribution_touchpoints_r2847 (decision_id, touchpoint_type, touchpoint_date, owner_name, influence_delta, cost_rupees, outcome_note)
SELECT id, 'rfp_response', '2026-06-10'::date, 'Sales Lead Priya', 15.00, 8000, 'Detailed 40-page RFP response with SLAs.'
FROM chain_procurement_decisions_r2847 WHERE chain_name='AIG Hospitals' LIMIT 1;

-- =============================================================================
-- RPCs
-- =============================================================================

DROP FUNCTION IF EXISTS r2847_summary();
CREATE OR REPLACE FUNCTION r2847_summary()
RETURNS TABLE (
  total_decisions int,
  won_count int,
  lost_count int,
  pending_count int,
  total_contract_value_rupees bigint,
  total_our_cost_rupees bigint,
  avg_influence_score numeric,
  win_rate_pct numeric
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
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE close_status='won')::int,
    COUNT(*) FILTER (WHERE close_status='lost')::int,
    COUNT(*) FILTER (WHERE close_status='pending')::int,
    COALESCE(SUM(contract_value_rupees),0)::bigint,
    COALESCE(SUM(our_cost_rupees),0)::bigint,
    COALESCE(ROUND(AVG(our_influence_score),2),0)::numeric,
    CASE WHEN COUNT(*)=0 THEN 0 ELSE ROUND(COUNT(*) FILTER (WHERE close_status='won')::numeric * 100 / COUNT(*), 2) END
  FROM chain_procurement_decisions_r2847;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2847_list_decisions();
CREATE OR REPLACE FUNCTION r2847_list_decisions()
RETURNS TABLE (
  id uuid,
  chain_name text,
  decision_quarter text,
  decision_category text,
  stakeholders text,
  our_influence_score numeric,
  close_status text,
  contract_value_rupees bigint,
  our_cost_rupees bigint,
  verdict text,
  decided_at date
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.decision_quarter, d.decision_category, d.stakeholders,
         d.our_influence_score, d.close_status, d.contract_value_rupees, d.our_cost_rupees, d.verdict, d.decided_at
  FROM chain_procurement_decisions_r2847 d
  ORDER BY d.decided_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_list_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_list_decisions() TO authenticated;

DROP FUNCTION IF EXISTS r2847_by_category();
CREATE OR REPLACE FUNCTION r2847_by_category()
RETURNS TABLE (
  decision_category text,
  decisions int,
  wins int,
  win_rate_pct numeric,
  total_value_rupees bigint,
  total_cost_rupees bigint
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
    d.decision_category,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE d.close_status='won')::int,
    CASE WHEN COUNT(*)=0 THEN 0 ELSE ROUND(COUNT(*) FILTER (WHERE d.close_status='won')::numeric * 100 / COUNT(*), 2) END,
    COALESCE(SUM(d.contract_value_rupees),0)::bigint,
    COALESCE(SUM(d.our_cost_rupees),0)::bigint
  FROM chain_procurement_decisions_r2847 d
  GROUP BY d.decision_category
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_by_category() TO authenticated;

DROP FUNCTION IF EXISTS r2847_by_verdict();
CREATE OR REPLACE FUNCTION r2847_by_verdict()
RETURNS TABLE (
  verdict text,
  decisions int,
  total_value_rupees bigint,
  total_cost_rupees bigint,
  avg_influence numeric
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
    d.verdict,
    COUNT(*)::int,
    COALESCE(SUM(d.contract_value_rupees),0)::bigint,
    COALESCE(SUM(d.our_cost_rupees),0)::bigint,
    COALESCE(ROUND(AVG(d.our_influence_score),2),0)::numeric
  FROM chain_procurement_decisions_r2847 d
  GROUP BY d.verdict
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_by_verdict() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_by_verdict() TO authenticated;

DROP FUNCTION IF EXISTS r2847_touchpoints();
CREATE OR REPLACE FUNCTION r2847_touchpoints()
RETURNS TABLE (
  id uuid,
  chain_name text,
  touchpoint_type text,
  touchpoint_date date,
  owner_name text,
  influence_delta numeric,
  cost_rupees bigint,
  outcome_note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, d.chain_name, t.touchpoint_type, t.touchpoint_date, t.owner_name,
         t.influence_delta, t.cost_rupees, t.outcome_note
  FROM chain_attribution_touchpoints_r2847 t
  JOIN chain_procurement_decisions_r2847 d ON d.id = t.decision_id
  ORDER BY t.touchpoint_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_touchpoints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_touchpoints() TO authenticated;

DROP FUNCTION IF EXISTS r2847_top_chains();
CREATE OR REPLACE FUNCTION r2847_top_chains()
RETURNS TABLE (
  chain_name text,
  decisions int,
  total_value_rupees bigint,
  total_cost_rupees bigint,
  net_margin_rupees bigint,
  avg_influence numeric
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
    d.chain_name,
    COUNT(*)::int,
    COALESCE(SUM(d.contract_value_rupees),0)::bigint,
    COALESCE(SUM(d.our_cost_rupees),0)::bigint,
    (COALESCE(SUM(d.contract_value_rupees),0) - COALESCE(SUM(d.our_cost_rupees),0))::bigint,
    COALESCE(ROUND(AVG(d.our_influence_score),2),0)::numeric
  FROM chain_procurement_decisions_r2847 d
  GROUP BY d.chain_name
  ORDER BY SUM(d.contract_value_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_top_chains() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_top_chains() TO authenticated;

DROP FUNCTION IF EXISTS r2847_quarterly_trend();
CREATE OR REPLACE FUNCTION r2847_quarterly_trend()
RETURNS TABLE (
  decision_quarter text,
  decisions int,
  wins int,
  value_rupees bigint,
  cost_rupees bigint,
  win_rate_pct numeric
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
    d.decision_quarter,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE d.close_status='won')::int,
    COALESCE(SUM(d.contract_value_rupees),0)::bigint,
    COALESCE(SUM(d.our_cost_rupees),0)::bigint,
    CASE WHEN COUNT(*)=0 THEN 0 ELSE ROUND(COUNT(*) FILTER (WHERE d.close_status='won')::numeric * 100 / COUNT(*), 2) END
  FROM chain_procurement_decisions_r2847 d
  GROUP BY d.decision_quarter
  ORDER BY d.decision_quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_quarterly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_quarterly_trend() TO authenticated;

DROP FUNCTION IF EXISTS r2847_influence_efficiency();
CREATE OR REPLACE FUNCTION r2847_influence_efficiency()
RETURNS TABLE (
  chain_name text,
  decision_category text,
  our_influence_score numeric,
  contract_value_rupees bigint,
  our_cost_rupees bigint,
  rupees_per_influence_point numeric,
  verdict text
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
    d.chain_name,
    d.decision_category,
    d.our_influence_score,
    d.contract_value_rupees,
    d.our_cost_rupees,
    CASE WHEN d.our_influence_score = 0 THEN 0 ELSE ROUND(d.our_cost_rupees::numeric / d.our_influence_score, 2) END,
    d.verdict
  FROM chain_procurement_decisions_r2847 d
  ORDER BY d.our_influence_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2847_influence_efficiency() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2847_influence_efficiency() TO authenticated;

COMMIT;
