BEGIN;

-- ============================================================================
-- Round 2691: Hospital Chain Quarterly Cross-Sell Opportunity
-- chain × current product × cross-sell candidate × signal × pursuit × outcome
-- ============================================================================

-- Drop existing
DROP TABLE IF EXISTS chain_xsell_opportunities_r2691 CASCADE;
DROP TABLE IF EXISTS chain_xsell_pursuits_r2691 CASCADE;

-- Opportunities table: chain × current × candidate × signal
CREATE TABLE chain_xsell_opportunities_r2691 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL,
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('flagship','metro','tier2','tier3')),
  city text NOT NULL,
  current_product text NOT NULL CHECK (current_product IN ('repair_oneshot','amc_basic','amc_pro','amc_elite','parts_only','rentals')),
  candidate_product text NOT NULL CHECK (candidate_product IN ('amc_basic','amc_pro','amc_elite','parts_supply','rentals','engineer_residency','training','telemetry')),
  signal_type text NOT NULL CHECK (signal_type IN ('breakdown_spike','tender_window','expansion_announced','competitor_loss','exec_intro','referral_inbound')),
  signal_strength int NOT NULL CHECK (signal_strength BETWEEN 1 AND 10),
  estimated_acv_rupees bigint NOT NULL CHECK (estimated_acv_rupees >= 0),
  probability_pct int NOT NULL CHECK (probability_pct BETWEEN 0 AND 100),
  champion_contact text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Pursuits table: pursuit × outcome
CREATE TABLE chain_xsell_pursuits_r2691 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  opportunity_id uuid NOT NULL REFERENCES chain_xsell_opportunities_r2691(id) ON DELETE CASCADE,
  pursuit_stage text NOT NULL CHECK (pursuit_stage IN ('discover','qualify','demo','pilot','contract','closed_won','closed_lost')),
  owner_name text NOT NULL,
  last_touch_at timestamptz NOT NULL DEFAULT now(),
  next_step text NOT NULL,
  blocker text,
  outcome text CHECK (outcome IN ('pending','won','lost','stalled','deferred')),
  realized_acv_rupees bigint CHECK (realized_acv_rupees >= 0),
  notes text
);

-- RLS
ALTER TABLE chain_xsell_opportunities_r2691 ENABLE ROW LEVEL SECURITY;
ALTER TABLE chain_xsell_pursuits_r2691 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON chain_xsell_opportunities_r2691;
CREATE POLICY founder_all ON chain_xsell_opportunities_r2691 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON chain_xsell_pursuits_r2691;
CREATE POLICY founder_all ON chain_xsell_pursuits_r2691 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed opportunities (6 rows)
INSERT INTO chain_xsell_opportunities_r2691
(quarter, chain_name, chain_tier, city, current_product, candidate_product, signal_type, signal_strength, estimated_acv_rupees, probability_pct, champion_contact)
VALUES
('2026Q3','Apollo Network','flagship','Hyderabad','amc_basic','amc_elite','breakdown_spike',9,4800000,72,'Biomed Head — Dr. Rao'),
('2026Q3','Yashoda Group','metro','Hyderabad','repair_oneshot','amc_pro','tender_window',8,2200000,60,'Procurement — Ms. Iyer'),
('2026Q3','Manipal Chain','flagship','Bengaluru','amc_pro','engineer_residency','expansion_announced',9,3600000,55,'CTO — Mr. Bhat'),
('2026Q3','Care Hospitals','metro','Visakhapatnam','parts_only','amc_basic','competitor_loss',7,950000,68,'CFO Office — Mr. Kumar'),
('2026Q3','KIMS','metro','Hyderabad','amc_basic','telemetry','referral_inbound',6,1400000,45,'Biomed — Mr. Reddy'),
('2026Q3','Aster DM','flagship','Kochi','amc_elite','training','exec_intro',8,800000,75,'Academic Dean — Dr. Pillai');

-- Seed pursuits (6 rows)
INSERT INTO chain_xsell_pursuits_r2691
(opportunity_id, pursuit_stage, owner_name, next_step, blocker, outcome, realized_acv_rupees, notes)
SELECT id, 'pilot','Ganesh','Sign 30-day elite pilot MoU','Awaiting CFO sign-off','pending',NULL,'8 sites in pilot scope'
FROM chain_xsell_opportunities_r2691 WHERE chain_name='Apollo Network' LIMIT 1;

INSERT INTO chain_xsell_pursuits_r2691
(opportunity_id, pursuit_stage, owner_name, next_step, blocker, outcome, realized_acv_rupees, notes)
SELECT id,'qualify','Vijay','Submit tender bid pack',NULL,'pending',NULL,'Tender closes Aug 14'
FROM chain_xsell_opportunities_r2691 WHERE chain_name='Yashoda Group' LIMIT 1;

INSERT INTO chain_xsell_pursuits_r2691
(opportunity_id, pursuit_stage, owner_name, next_step, blocker, outcome, realized_acv_rupees, notes)
SELECT id,'demo','Ganesh','Onsite residency demo at Whitefield','Legal review of residency T&C','stalled',NULL,'Need MSA addendum'
FROM chain_xsell_opportunities_r2691 WHERE chain_name='Manipal Chain' LIMIT 1;

INSERT INTO chain_xsell_pursuits_r2691
(opportunity_id, pursuit_stage, owner_name, next_step, blocker, outcome, realized_acv_rupees, notes)
SELECT id,'contract','Anil','Final redlines on AMC SoW',NULL,'pending',NULL,'Replacing Medtronic AMC'
FROM chain_xsell_opportunities_r2691 WHERE chain_name='Care Hospitals' LIMIT 1;

INSERT INTO chain_xsell_pursuits_r2691
(opportunity_id, pursuit_stage, owner_name, next_step, blocker, outcome, realized_acv_rupees, notes)
SELECT id,'closed_won','Ganesh','Kickoff Sep 1',NULL,'won',1380000,'Telemetry add-on signed'
FROM chain_xsell_opportunities_r2691 WHERE chain_name='KIMS' LIMIT 1;

INSERT INTO chain_xsell_pursuits_r2691
(opportunity_id, pursuit_stage, owner_name, next_step, blocker, outcome, realized_acv_rupees, notes)
SELECT id,'closed_lost','Vijay','Debrief and re-pitch in Q4','Budget cycle shift','lost',0,'Reattempt Oct'
FROM chain_xsell_opportunities_r2691 WHERE chain_name='Aster DM' LIMIT 1;

-- ============================================================================
-- RPCs (7+ SECDEF, all is_founder gated)
-- ============================================================================

-- 1. KPI summary
DROP FUNCTION IF EXISTS r2691_kpi_summary();
CREATE FUNCTION r2691_kpi_summary()
RETURNS TABLE(
  total_opps int,
  total_pipeline_rupees bigint,
  weighted_pipeline_rupees bigint,
  won_acv_rupees bigint,
  win_count int,
  loss_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM chain_xsell_opportunities_r2691),
    COALESCE((SELECT SUM(estimated_acv_rupees) FROM chain_xsell_opportunities_r2691),0),
    COALESCE((SELECT SUM(estimated_acv_rupees * probability_pct / 100) FROM chain_xsell_opportunities_r2691),0),
    COALESCE((SELECT SUM(realized_acv_rupees) FROM chain_xsell_pursuits_r2691 WHERE outcome='won'),0),
    (SELECT COUNT(*)::int FROM chain_xsell_pursuits_r2691 WHERE outcome='won'),
    (SELECT COUNT(*)::int FROM chain_xsell_pursuits_r2691 WHERE outcome='lost');
END $$;
REVOKE EXECUTE ON FUNCTION r2691_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_kpi_summary() TO authenticated;

-- 2. Opportunities by chain
DROP FUNCTION IF EXISTS r2691_by_chain();
CREATE FUNCTION r2691_by_chain()
RETURNS TABLE(
  chain_name text,
  chain_tier text,
  city text,
  opps int,
  total_acv_rupees bigint,
  weighted_acv_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.chain_name, o.chain_tier, o.city,
    COUNT(*)::int,
    SUM(o.estimated_acv_rupees)::bigint,
    SUM(o.estimated_acv_rupees * o.probability_pct / 100)::bigint
  FROM chain_xsell_opportunities_r2691 o
  GROUP BY o.chain_name, o.chain_tier, o.city
  ORDER BY SUM(o.estimated_acv_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2691_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_by_chain() TO authenticated;

-- 3. Signal mix
DROP FUNCTION IF EXISTS r2691_signal_mix();
CREATE FUNCTION r2691_signal_mix()
RETURNS TABLE(
  signal_type text,
  opps int,
  avg_strength numeric,
  total_acv_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.signal_type,
    COUNT(*)::int,
    ROUND(AVG(o.signal_strength)::numeric, 2),
    SUM(o.estimated_acv_rupees)::bigint
  FROM chain_xsell_opportunities_r2691 o
  GROUP BY o.signal_type
  ORDER BY SUM(o.estimated_acv_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2691_signal_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_signal_mix() TO authenticated;

-- 4. Product transition matrix
DROP FUNCTION IF EXISTS r2691_product_matrix();
CREATE FUNCTION r2691_product_matrix()
RETURNS TABLE(
  current_product text,
  candidate_product text,
  opps int,
  acv_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.current_product, o.candidate_product,
    COUNT(*)::int,
    SUM(o.estimated_acv_rupees)::bigint
  FROM chain_xsell_opportunities_r2691 o
  GROUP BY o.current_product, o.candidate_product
  ORDER BY SUM(o.estimated_acv_rupees) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2691_product_matrix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_product_matrix() TO authenticated;

-- 5. Pursuit pipeline by stage
DROP FUNCTION IF EXISTS r2691_pursuit_pipeline();
CREATE FUNCTION r2691_pursuit_pipeline()
RETURNS TABLE(
  pursuit_stage text,
  count int,
  acv_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.pursuit_stage,
    COUNT(*)::int,
    COALESCE(SUM(o.estimated_acv_rupees),0)::bigint
  FROM chain_xsell_pursuits_r2691 p
  JOIN chain_xsell_opportunities_r2691 o ON o.id = p.opportunity_id
  GROUP BY p.pursuit_stage
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2691_pursuit_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_pursuit_pipeline() TO authenticated;

-- 6. Top opportunities (joined detail)
DROP FUNCTION IF EXISTS r2691_top_opportunities();
CREATE FUNCTION r2691_top_opportunities()
RETURNS TABLE(
  chain_name text,
  city text,
  current_product text,
  candidate_product text,
  signal_type text,
  signal_strength int,
  estimated_acv_rupees bigint,
  probability_pct int,
  pursuit_stage text,
  owner_name text,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.chain_name, o.city, o.current_product, o.candidate_product,
    o.signal_type, o.signal_strength, o.estimated_acv_rupees, o.probability_pct,
    p.pursuit_stage, p.owner_name, p.outcome
  FROM chain_xsell_opportunities_r2691 o
  LEFT JOIN chain_xsell_pursuits_r2691 p ON p.opportunity_id = o.id
  ORDER BY o.estimated_acv_rupees DESC
  LIMIT 20;
END $$;
REVOKE EXECUTE ON FUNCTION r2691_top_opportunities() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_top_opportunities() TO authenticated;

-- 7. Blockers digest
DROP FUNCTION IF EXISTS r2691_blockers();
CREATE FUNCTION r2691_blockers()
RETURNS TABLE(
  chain_name text,
  pursuit_stage text,
  blocker text,
  next_step text,
  owner_name text,
  last_touch_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.chain_name, p.pursuit_stage, p.blocker, p.next_step, p.owner_name, p.last_touch_at
  FROM chain_xsell_pursuits_r2691 p
  JOIN chain_xsell_opportunities_r2691 o ON o.id = p.opportunity_id
  WHERE p.blocker IS NOT NULL AND p.blocker <> ''
  ORDER BY p.last_touch_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2691_blockers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_blockers() TO authenticated;

-- 8. Win/loss outcomes
DROP FUNCTION IF EXISTS r2691_outcomes();
CREATE FUNCTION r2691_outcomes()
RETURNS TABLE(
  outcome text,
  count int,
  realized_acv_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(p.outcome,'pending') AS outcome,
    COUNT(*)::int,
    COALESCE(SUM(p.realized_acv_rupees),0)::bigint
  FROM chain_xsell_pursuits_r2691 p
  GROUP BY p.outcome
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION r2691_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2691_outcomes() TO authenticated;

COMMIT;
