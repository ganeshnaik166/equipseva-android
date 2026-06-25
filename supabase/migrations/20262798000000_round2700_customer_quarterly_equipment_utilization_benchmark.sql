BEGIN;

-- Round 2700 — Customer Quarterly Equipment Utilization Benchmark
-- Equipment × our customer util × benchmark × gap × cause × close action

-- =========================================================================
-- TABLE 1: customer_equipment_util_benchmark_r2700
-- Per-customer per-equipment quarterly utilization vs peer benchmark
-- =========================================================================
CREATE TABLE IF NOT EXISTS customer_equipment_util_benchmark_r2700 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,
  customer_org_name text NOT NULL,
  customer_tier text NOT NULL CHECK (customer_tier IN ('tier1','tier2','tier3','chain','enterprise')),
  equipment_category text NOT NULL,
  equipment_model text NOT NULL,
  units_deployed integer NOT NULL CHECK (units_deployed > 0),
  our_util_pct numeric(5,2) NOT NULL CHECK (our_util_pct >= 0 AND our_util_pct <= 100),
  peer_benchmark_pct numeric(5,2) NOT NULL CHECK (peer_benchmark_pct >= 0 AND peer_benchmark_pct <= 100),
  top_decile_pct numeric(5,2) NOT NULL CHECK (top_decile_pct >= 0 AND top_decile_pct <= 100),
  utilization_gap_pct numeric(5,2) NOT NULL,
  gap_severity text NOT NULL CHECK (gap_severity IN ('green','amber','red','critical')),
  revenue_lost_rupees bigint NOT NULL DEFAULT 0,
  measured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_equipment_util_benchmark_r2700 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_equipment_util_benchmark_r2700;
CREATE POLICY founder_all ON customer_equipment_util_benchmark_r2700
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_equipment_util_benchmark_r2700
  (quarter_label, customer_org_name, customer_tier, equipment_category, equipment_model, units_deployed, our_util_pct, peer_benchmark_pct, top_decile_pct, utilization_gap_pct, gap_severity, revenue_lost_rupees)
VALUES
  ('Q1-2026','Apollo Hyderabad','enterprise','Imaging','GE Optima MR450w 1.5T',2,42.50,68.00,84.00,-25.50,'critical',1850000),
  ('Q1-2026','KIMS Secunderabad','tier1','Imaging','Siemens Somatom go.Top CT',3,71.25,68.00,84.00,3.25,'green',0),
  ('Q1-2026','Yashoda Hospitals','chain','Surgical','Karl Storz Image1 S Tower',5,55.80,62.50,78.00,-6.70,'amber',420000),
  ('Q1-2026','Care Hospitals Banjara','tier1','Diagnostic','Roche Cobas 6000',4,48.20,64.00,82.00,-15.80,'red',980000),
  ('Q1-2026','Continental Gachibowli','tier2','ICU','Mindray BeneVision N17 Monitor',8,38.50,55.00,72.00,-16.50,'red',1250000),
  ('Q1-2026','AIG Hospitals','enterprise','Endoscopy','Olympus EVIS X1 CV-1500',6,82.40,71.00,86.00,11.40,'green',0),
  ('Q1-2026','Sunshine Hospitals Paradise','tier2','Imaging','Philips Affiniti 70 Ultrasound',3,29.80,58.00,75.00,-28.20,'critical',1680000),
  ('Q1-2026','MaxCure Madhapur','tier3','Surgical','Stryker System 8 Drill',4,44.00,60.00,76.00,-16.00,'red',520000);

-- =========================================================================
-- TABLE 2: util_gap_cause_action_r2700
-- Root cause and close action per gap line
-- =========================================================================
CREATE TABLE IF NOT EXISTS util_gap_cause_action_r2700 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  benchmark_id uuid REFERENCES customer_equipment_util_benchmark_r2700(id) ON DELETE CASCADE,
  root_cause_category text NOT NULL CHECK (root_cause_category IN ('staffing','training','downtime','demand','scheduling','consumables','referrals','pricing')),
  cause_summary text NOT NULL,
  close_action text NOT NULL,
  action_owner text NOT NULL,
  action_owner_role text NOT NULL CHECK (action_owner_role IN ('csm','ae','engineer','founder','customer_admin','ops')),
  expected_uplift_pct numeric(5,2) NOT NULL CHECK (expected_uplift_pct >= 0),
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('planned','in_progress','blocked','closed','at_risk')),
  expected_revenue_recovered_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE util_gap_cause_action_r2700 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON util_gap_cause_action_r2700;
CREATE POLICY founder_all ON util_gap_cause_action_r2700
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO util_gap_cause_action_r2700
  (benchmark_id, root_cause_category, cause_summary, close_action, action_owner, action_owner_role, expected_uplift_pct, due_date, status, expected_revenue_recovered_rupees)
SELECT id, 'staffing','MR tech short by 1 FTE on PM shift','Hire and onboard 2 MR techs by Q2','Priya Menon','csm',18.00,'2026-09-30'::date,'in_progress',1400000
FROM customer_equipment_util_benchmark_r2700 WHERE customer_org_name='Apollo Hyderabad' LIMIT 1;

INSERT INTO util_gap_cause_action_r2700
  (benchmark_id, root_cause_category, cause_summary, close_action, action_owner, action_owner_role, expected_uplift_pct, due_date, status, expected_revenue_recovered_rupees)
SELECT id, 'scheduling','OR block underused Wed/Fri afternoons','Re-align surgeon blocks to demand window','Ravi Krishnan','ae',8.50,'2026-08-15'::date,'planned',360000
FROM customer_equipment_util_benchmark_r2700 WHERE customer_org_name='Yashoda Hospitals' LIMIT 1;

INSERT INTO util_gap_cause_action_r2700
  (benchmark_id, root_cause_category, cause_summary, close_action, action_owner, action_owner_role, expected_uplift_pct, due_date, status, expected_revenue_recovered_rupees)
SELECT id, 'consumables','Reagent stockout 7 days in Q1','Auto-replenish tied to ledger threshold','Suresh Iyer','ops',12.00,'2026-07-31'::date,'in_progress',780000
FROM customer_equipment_util_benchmark_r2700 WHERE customer_org_name='Care Hospitals Banjara' LIMIT 1;

INSERT INTO util_gap_cause_action_r2700
  (benchmark_id, root_cause_category, cause_summary, close_action, action_owner, action_owner_role, expected_uplift_pct, due_date, status, expected_revenue_recovered_rupees)
SELECT id, 'downtime','3 unplanned downtime events 14 days total','Predictive maintenance + spare-on-shelf','Anil Reddy','engineer',14.00,'2026-08-30'::date,'at_risk',1050000
FROM customer_equipment_util_benchmark_r2700 WHERE customer_org_name='Continental Gachibowli' LIMIT 1;

INSERT INTO util_gap_cause_action_r2700
  (benchmark_id, root_cause_category, cause_summary, close_action, action_owner, action_owner_role, expected_uplift_pct, due_date, status, expected_revenue_recovered_rupees)
SELECT id, 'referrals','GP referral funnel dropped 40% QoQ','Joint GP outreach + ultrasound voucher','Neha Sharma','csm',22.00,'2026-09-15'::date,'planned',1480000
FROM customer_equipment_util_benchmark_r2700 WHERE customer_org_name='Sunshine Hospitals Paradise' LIMIT 1;

INSERT INTO util_gap_cause_action_r2700
  (benchmark_id, root_cause_category, cause_summary, close_action, action_owner, action_owner_role, expected_uplift_pct, due_date, status, expected_revenue_recovered_rupees)
SELECT id, 'training','Drill new-OS adoption stalled at 30%','Half-day hands-on for 6 surgeons','Vikram Joshi','engineer',10.00,'2026-08-10'::date,'closed',420000
FROM customer_equipment_util_benchmark_r2700 WHERE customer_org_name='MaxCure Madhapur' LIMIT 1;

INSERT INTO util_gap_cause_action_r2700
  (benchmark_id, root_cause_category, cause_summary, close_action, action_owner, action_owner_role, expected_uplift_pct, due_date, status, expected_revenue_recovered_rupees)
SELECT id, 'demand','Specialty-pull lower than peer chains','Co-market 2 imaging packages','Priya Menon','csm',6.00,'2026-09-05'::date,'blocked',280000
FROM customer_equipment_util_benchmark_r2700 WHERE customer_org_name='Apollo Hyderabad' LIMIT 1;

-- =========================================================================
-- RPC 1: top KPIs
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_benchmark_kpis_r2700();
CREATE OR REPLACE FUNCTION founder_util_benchmark_kpis_r2700()
RETURNS TABLE (
  total_customers integer,
  total_equipment_lines integer,
  avg_our_util_pct numeric,
  avg_peer_benchmark_pct numeric,
  total_gap_pct numeric,
  total_revenue_lost_rupees bigint,
  critical_lines integer,
  red_lines integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT customer_org_name)::int,
    COUNT(*)::int,
    ROUND(AVG(our_util_pct)::numeric, 2),
    ROUND(AVG(peer_benchmark_pct)::numeric, 2),
    ROUND(AVG(utilization_gap_pct)::numeric, 2),
    COALESCE(SUM(revenue_lost_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE gap_severity='critical')::int,
    COUNT(*) FILTER (WHERE gap_severity='red')::int
  FROM customer_equipment_util_benchmark_r2700;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_benchmark_kpis_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_benchmark_kpis_r2700() TO authenticated;

-- =========================================================================
-- RPC 2: per-customer rollup
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_by_customer_r2700();
CREATE OR REPLACE FUNCTION founder_util_by_customer_r2700()
RETURNS TABLE (
  customer_org_name text,
  customer_tier text,
  equipment_lines integer,
  avg_our_util_pct numeric,
  avg_peer_pct numeric,
  total_gap_pct numeric,
  revenue_lost_rupees bigint,
  worst_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.customer_org_name,
    MAX(b.customer_tier),
    COUNT(*)::int,
    ROUND(AVG(b.our_util_pct)::numeric, 2),
    ROUND(AVG(b.peer_benchmark_pct)::numeric, 2),
    ROUND(SUM(b.utilization_gap_pct)::numeric, 2),
    COALESCE(SUM(b.revenue_lost_rupees),0)::bigint,
    CASE
      WHEN bool_or(b.gap_severity='critical') THEN 'critical'
      WHEN bool_or(b.gap_severity='red') THEN 'red'
      WHEN bool_or(b.gap_severity='amber') THEN 'amber'
      ELSE 'green'
    END
  FROM customer_equipment_util_benchmark_r2700 b
  GROUP BY b.customer_org_name
  ORDER BY SUM(b.revenue_lost_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_by_customer_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_by_customer_r2700() TO authenticated;

-- =========================================================================
-- RPC 3: per-equipment category rollup
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_by_category_r2700();
CREATE OR REPLACE FUNCTION founder_util_by_category_r2700()
RETURNS TABLE (
  equipment_category text,
  lines integer,
  avg_our_util_pct numeric,
  avg_peer_pct numeric,
  avg_top_decile_pct numeric,
  total_gap_pct numeric,
  revenue_lost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.equipment_category,
    COUNT(*)::int,
    ROUND(AVG(b.our_util_pct)::numeric, 2),
    ROUND(AVG(b.peer_benchmark_pct)::numeric, 2),
    ROUND(AVG(b.top_decile_pct)::numeric, 2),
    ROUND(SUM(b.utilization_gap_pct)::numeric, 2),
    COALESCE(SUM(b.revenue_lost_rupees),0)::bigint
  FROM customer_equipment_util_benchmark_r2700 b
  GROUP BY b.equipment_category
  ORDER BY SUM(b.revenue_lost_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_by_category_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_by_category_r2700() TO authenticated;

-- =========================================================================
-- RPC 4: detail line list
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_lines_r2700();
CREATE OR REPLACE FUNCTION founder_util_lines_r2700()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  customer_org_name text,
  customer_tier text,
  equipment_category text,
  equipment_model text,
  units_deployed integer,
  our_util_pct numeric,
  peer_benchmark_pct numeric,
  top_decile_pct numeric,
  utilization_gap_pct numeric,
  gap_severity text,
  revenue_lost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.quarter_label, b.customer_org_name, b.customer_tier,
         b.equipment_category, b.equipment_model, b.units_deployed,
         b.our_util_pct, b.peer_benchmark_pct, b.top_decile_pct,
         b.utilization_gap_pct, b.gap_severity, b.revenue_lost_rupees
  FROM customer_equipment_util_benchmark_r2700 b
  ORDER BY b.utilization_gap_pct ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_lines_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_lines_r2700() TO authenticated;

-- =========================================================================
-- RPC 5: cause and action list joined
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_actions_r2700();
CREATE OR REPLACE FUNCTION founder_util_actions_r2700()
RETURNS TABLE (
  id uuid,
  customer_org_name text,
  equipment_model text,
  root_cause_category text,
  cause_summary text,
  close_action text,
  action_owner text,
  action_owner_role text,
  expected_uplift_pct numeric,
  due_date date,
  status text,
  expected_revenue_recovered_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, b.customer_org_name, b.equipment_model,
         a.root_cause_category, a.cause_summary, a.close_action,
         a.action_owner, a.action_owner_role, a.expected_uplift_pct,
         a.due_date, a.status, a.expected_revenue_recovered_rupees
  FROM util_gap_cause_action_r2700 a
  LEFT JOIN customer_equipment_util_benchmark_r2700 b ON b.id = a.benchmark_id
  ORDER BY a.due_date ASC, a.expected_revenue_recovered_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_actions_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_actions_r2700() TO authenticated;

-- =========================================================================
-- RPC 6: cause rollup
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_cause_rollup_r2700();
CREATE OR REPLACE FUNCTION founder_util_cause_rollup_r2700()
RETURNS TABLE (
  root_cause_category text,
  actions integer,
  avg_expected_uplift_pct numeric,
  expected_revenue_recovered_rupees bigint,
  closed_actions integer,
  at_risk_actions integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.root_cause_category,
    COUNT(*)::int,
    ROUND(AVG(a.expected_uplift_pct)::numeric, 2),
    COALESCE(SUM(a.expected_revenue_recovered_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE a.status='closed')::int,
    COUNT(*) FILTER (WHERE a.status='at_risk' OR a.status='blocked')::int
  FROM util_gap_cause_action_r2700 a
  GROUP BY a.root_cause_category
  ORDER BY SUM(a.expected_revenue_recovered_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_cause_rollup_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_cause_rollup_r2700() TO authenticated;

-- =========================================================================
-- RPC 7: severity rollup
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_severity_rollup_r2700();
CREATE OR REPLACE FUNCTION founder_util_severity_rollup_r2700()
RETURNS TABLE (
  gap_severity text,
  lines integer,
  avg_gap_pct numeric,
  revenue_lost_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.gap_severity,
    COUNT(*)::int,
    ROUND(AVG(b.utilization_gap_pct)::numeric, 2),
    COALESCE(SUM(b.revenue_lost_rupees),0)::bigint
  FROM customer_equipment_util_benchmark_r2700 b
  GROUP BY b.gap_severity
  ORDER BY
    CASE b.gap_severity
      WHEN 'critical' THEN 1
      WHEN 'red' THEN 2
      WHEN 'amber' THEN 3
      WHEN 'green' THEN 4
      ELSE 5
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_severity_rollup_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_severity_rollup_r2700() TO authenticated;

-- =========================================================================
-- RPC 8: top recovery opportunities
-- =========================================================================
DROP FUNCTION IF EXISTS founder_util_top_recovery_r2700();
CREATE OR REPLACE FUNCTION founder_util_top_recovery_r2700()
RETURNS TABLE (
  customer_org_name text,
  equipment_model text,
  utilization_gap_pct numeric,
  revenue_lost_rupees bigint,
  close_action text,
  expected_uplift_pct numeric,
  expected_revenue_recovered_rupees bigint,
  due_date date,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.customer_org_name, b.equipment_model,
         b.utilization_gap_pct, b.revenue_lost_rupees,
         a.close_action, a.expected_uplift_pct,
         a.expected_revenue_recovered_rupees, a.due_date, a.status
  FROM customer_equipment_util_benchmark_r2700 b
  JOIN util_gap_cause_action_r2700 a ON a.benchmark_id = b.id
  ORDER BY a.expected_revenue_recovered_rupees DESC NULLS LAST
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_util_top_recovery_r2700() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_util_top_recovery_r2700() TO authenticated;

COMMIT;
