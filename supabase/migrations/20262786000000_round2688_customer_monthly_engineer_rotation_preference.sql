BEGIN;

-- Round 2688: Customer Monthly Engineer Rotation Preference
-- Two round-suffixed tables tracking customer preferred engineer vs actual
-- assignment, satisfaction, rotation reasons and outcomes.

-- ============================================================
-- Table 1: Monthly preference snapshots per customer
-- ============================================================
CREATE TABLE IF NOT EXISTS customer_monthly_engineer_rotation_r2688 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_month date NOT NULL,
  customer_org_name text NOT NULL,
  city text NOT NULL,
  preferred_engineer_name text NOT NULL,
  actual_engineer_name text NOT NULL,
  match_status text NOT NULL CHECK (match_status IN ('matched','swapped','escalated','unavailable','reassigned')),
  satisfaction_score numeric(3,1) NOT NULL CHECK (satisfaction_score >= 0 AND satisfaction_score <= 10),
  rotation_reason text NOT NULL CHECK (rotation_reason IN ('engineer_leave','load_balancing','customer_request','skill_mismatch','geographic_optimization','none')),
  outcome text NOT NULL CHECK (outcome IN ('retained','at_risk','churned','upgraded','neutral')),
  jobs_in_month int NOT NULL CHECK (jobs_in_month >= 0),
  monthly_revenue_rupees bigint NOT NULL CHECK (monthly_revenue_rupees >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_monthly_engineer_rotation_r2688 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON customer_monthly_engineer_rotation_r2688;
CREATE POLICY founder_all ON customer_monthly_engineer_rotation_r2688
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_monthly_engineer_rotation_r2688
  (cycle_month, customer_org_name, city, preferred_engineer_name, actual_engineer_name, match_status, satisfaction_score, rotation_reason, outcome, jobs_in_month, monthly_revenue_rupees)
VALUES
  ('2026-06-01','Apollo Hyderabad','Hyderabad','Ravi Kumar','Ravi Kumar','matched',9.4,'none','retained',6,148000),
  ('2026-06-01','KIMS Secunderabad','Hyderabad','Suresh Babu','Anil Reddy','swapped',7.2,'engineer_leave','at_risk',4,92000),
  ('2026-06-01','Care Banjara','Hyderabad','Lakshmi Devi','Lakshmi Devi','matched',9.7,'none','upgraded',8,210000),
  ('2026-06-01','Yashoda Somajiguda','Hyderabad','Vikram Singh','Pradeep Rao','reassigned',6.1,'skill_mismatch','at_risk',3,68000),
  ('2026-06-01','Continental Gachibowli','Hyderabad','Manoj Reddy','Manoj Reddy','matched',9.1,'none','retained',5,134000),
  ('2026-06-01','Sunshine Begumpet','Hyderabad','Kavya Sharma','Ramesh Naidu','swapped',5.4,'customer_request','churned',2,42000),
  ('2026-06-01','AIG Hospitals','Hyderabad','Divya Prasad','Divya Prasad','matched',9.8,'none','upgraded',9,256000),
  ('2026-06-01','Rainbow Childrens','Hyderabad','Naveen Joshi','Sunil Patel','escalated',4.8,'load_balancing','churned',2,38000);

-- ============================================================
-- Table 2: Rotation rules + preference outcomes catalog
-- ============================================================
CREATE TABLE IF NOT EXISTS rotation_outcome_catalog_r2688 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  rotation_reason text NOT NULL CHECK (rotation_reason IN ('engineer_leave','load_balancing','customer_request','skill_mismatch','geographic_optimization','none')),
  expected_satisfaction_delta numeric(3,1) NOT NULL,
  expected_churn_pct numeric(5,2) NOT NULL CHECK (expected_churn_pct >= 0 AND expected_churn_pct <= 100),
  mitigation_action text NOT NULL,
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE rotation_outcome_catalog_r2688 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON rotation_outcome_catalog_r2688;
CREATE POLICY founder_all ON rotation_outcome_catalog_r2688
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO rotation_outcome_catalog_r2688
  (rotation_reason, expected_satisfaction_delta, expected_churn_pct, mitigation_action, priority, active)
VALUES
  ('engineer_leave', -1.5, 18.00, 'Pre-warn customer 7 days before leave window', 'p1', true),
  ('load_balancing', -0.8, 8.50, 'Match by familiarity score above 0.75 only', 'p2', true),
  ('customer_request', 0.5, 4.00, 'Auto-honor within 24h, log reason', 'p0', true),
  ('skill_mismatch', -2.2, 26.00, 'Block assignment, escalate to ops lead', 'p0', true),
  ('geographic_optimization', -0.4, 6.50, 'Notify customer; bundle adjacent visits', 'p2', true),
  ('none', 0.2, 2.50, 'No rotation, retain preferred engineer', 'p3', true);

-- ============================================================
-- RPCs (7+), all SECURITY DEFINER, is_founder() gated
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2688_rotation_kpis();
CREATE OR REPLACE FUNCTION founder_r2688_rotation_kpis()
RETURNS TABLE(
  total_customers int,
  matched_pct numeric,
  avg_satisfaction numeric,
  at_risk_customers int,
  churned_customers int,
  total_monthly_revenue bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    ROUND(100.0 * SUM(CASE WHEN match_status = 'matched' THEN 1 ELSE 0 END) / GREATEST(COUNT(*),1), 2),
    ROUND(AVG(satisfaction_score)::numeric, 2),
    SUM(CASE WHEN outcome = 'at_risk' THEN 1 ELSE 0 END)::int,
    SUM(CASE WHEN outcome = 'churned' THEN 1 ELSE 0 END)::int,
    COALESCE(SUM(monthly_revenue_rupees),0)::bigint
  FROM customer_monthly_engineer_rotation_r2688;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_rotation_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_rotation_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2688_rotation_rows();
CREATE OR REPLACE FUNCTION founder_r2688_rotation_rows()
RETURNS SETOF customer_monthly_engineer_rotation_r2688
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM customer_monthly_engineer_rotation_r2688
  ORDER BY satisfaction_score ASC, monthly_revenue_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_rotation_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_rotation_rows() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2688_reason_breakdown();
CREATE OR REPLACE FUNCTION founder_r2688_reason_breakdown()
RETURNS TABLE(
  rotation_reason text,
  customer_count int,
  avg_satisfaction numeric,
  churn_count int,
  total_revenue bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.rotation_reason,
    COUNT(*)::int,
    ROUND(AVG(r.satisfaction_score)::numeric, 2),
    SUM(CASE WHEN r.outcome = 'churned' THEN 1 ELSE 0 END)::int,
    COALESCE(SUM(r.monthly_revenue_rupees),0)::bigint
  FROM customer_monthly_engineer_rotation_r2688 r
  GROUP BY r.rotation_reason
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_reason_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_reason_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2688_outcome_mix();
CREATE OR REPLACE FUNCTION founder_r2688_outcome_mix()
RETURNS TABLE(
  outcome text,
  cust_count int,
  share_pct numeric,
  revenue_share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total_c int;
  total_rev bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*), COALESCE(SUM(monthly_revenue_rupees),0)
  INTO total_c, total_rev FROM customer_monthly_engineer_rotation_r2688;
  RETURN QUERY
  SELECT
    r.outcome,
    COUNT(*)::int,
    ROUND(100.0 * COUNT(*) / GREATEST(total_c,1), 2),
    ROUND(100.0 * COALESCE(SUM(r.monthly_revenue_rupees),0) / GREATEST(total_rev,1), 2)
  FROM customer_monthly_engineer_rotation_r2688 r
  GROUP BY r.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_outcome_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_outcome_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2688_at_risk_customers();
CREATE OR REPLACE FUNCTION founder_r2688_at_risk_customers()
RETURNS SETOF customer_monthly_engineer_rotation_r2688
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM customer_monthly_engineer_rotation_r2688
  WHERE outcome IN ('at_risk','churned')
  ORDER BY satisfaction_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_at_risk_customers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_at_risk_customers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2688_catalog_rows();
CREATE OR REPLACE FUNCTION founder_r2688_catalog_rows()
RETURNS SETOF rotation_outcome_catalog_r2688
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT * FROM rotation_outcome_catalog_r2688
  ORDER BY priority ASC, expected_churn_pct DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_catalog_rows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_catalog_rows() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2688_match_status_summary();
CREATE OR REPLACE FUNCTION founder_r2688_match_status_summary()
RETURNS TABLE(
  match_status text,
  cust_count int,
  avg_satisfaction numeric,
  avg_jobs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.match_status,
    COUNT(*)::int,
    ROUND(AVG(r.satisfaction_score)::numeric, 2),
    ROUND(AVG(r.jobs_in_month)::numeric, 2)
  FROM customer_monthly_engineer_rotation_r2688 r
  GROUP BY r.match_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_match_status_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_match_status_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2688_revenue_by_outcome();
CREATE OR REPLACE FUNCTION founder_r2688_revenue_by_outcome()
RETURNS TABLE(
  outcome text,
  total_rev bigint,
  avg_rev_per_cust bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.outcome,
    COALESCE(SUM(r.monthly_revenue_rupees),0)::bigint,
    (COALESCE(SUM(r.monthly_revenue_rupees),0) / GREATEST(COUNT(*),1))::bigint
  FROM customer_monthly_engineer_rotation_r2688 r
  GROUP BY r.outcome
  ORDER BY SUM(r.monthly_revenue_rupees) DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2688_revenue_by_outcome() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2688_revenue_by_outcome() TO authenticated;

COMMIT;
