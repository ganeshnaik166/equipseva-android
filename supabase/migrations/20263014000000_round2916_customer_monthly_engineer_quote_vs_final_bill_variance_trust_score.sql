-- Round r2916: Customer Monthly Engineer Quote-vs-Final-Bill Variance & Trust Score
-- HEAVY founder ops round

CREATE TABLE IF NOT EXISTS customer_quote_variance_snapshots_r2916 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  snapshot_month date NOT NULL,
  customer_org_id uuid,
  customer_org_name text NOT NULL,
  engineer_id uuid,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL,
  jobs_completed int NOT NULL,
  total_quoted_rupees numeric(12,2) NOT NULL,
  total_final_billed_rupees numeric(12,2) NOT NULL,
  variance_rupees numeric(12,2) NOT NULL,
  variance_pct numeric(6,2) NOT NULL,
  trust_score numeric(5,2) NOT NULL,
  trust_band text NOT NULL,
  disputed_jobs int NOT NULL DEFAULT 0,
  refund_issued_rupees numeric(12,2) NOT NULL DEFAULT 0,
  notes text
);

ALTER TABLE customer_quote_variance_snapshots_r2916 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS customer_quote_variance_incidents_r2916 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  snapshot_id uuid REFERENCES customer_quote_variance_snapshots_r2916(id),
  repair_job_ref text NOT NULL,
  customer_org_name text NOT NULL,
  engineer_name text NOT NULL,
  quoted_rupees numeric(12,2) NOT NULL,
  final_billed_rupees numeric(12,2) NOT NULL,
  variance_pct numeric(6,2) NOT NULL,
  variance_reason text NOT NULL,
  severity text NOT NULL,
  resolution_status text NOT NULL,
  resolved_at timestamptz,
  refund_rupees numeric(12,2) NOT NULL DEFAULT 0,
  founder_review boolean NOT NULL DEFAULT false
);

ALTER TABLE customer_quote_variance_incidents_r2916 ENABLE ROW LEVEL SECURITY;

-- Seed snapshots (15 rows)
INSERT INTO customer_quote_variance_snapshots_r2916 (snapshot_month, customer_org_name, engineer_name, engineer_tier, jobs_completed, total_quoted_rupees, total_final_billed_rupees, variance_rupees, variance_pct, trust_score, trust_band, disputed_jobs, refund_issued_rupees, notes) VALUES
('2026-06-01'::date, 'Apollo Hyderabad', 'Ravi Kumar', 'gold', 12, 184000.00, 186500.00, 2500.00, 1.36, 96.50, 'excellent', 0, 0, 'Within tolerance'),
('2026-06-01'::date, 'KIMS Secunderabad', 'Suresh Reddy', 'silver', 9, 142000.00, 158400.00, 16400.00, 11.55, 71.20, 'fair', 2, 4500.00, 'Parts overrun'),
('2026-06-01'::date, 'Yashoda Somajiguda', 'Anand Patel', 'platinum', 18, 268000.00, 269800.00, 1800.00, 0.67, 98.80, 'excellent', 0, 0, 'Top performer'),
('2026-06-01'::date, 'Care Hospital Banjara', 'Manoj Singh', 'bronze', 6, 78000.00, 96400.00, 18400.00, 23.59, 48.50, 'poor', 3, 12000.00, 'Multiple disputes'),
('2026-06-01'::date, 'Sunshine Hospital', 'Deepak Yadav', 'gold', 14, 210000.00, 215200.00, 5200.00, 2.48, 92.40, 'good', 1, 1500.00, 'Minor variance'),
('2026-06-01'::date, 'Continental Gachibowli', 'Priya Sharma', 'silver', 10, 156000.00, 168900.00, 12900.00, 8.27, 76.80, 'fair', 1, 3200.00, 'Diagnostic add-ons'),
('2026-06-01'::date, 'Star Hospital Banjara', 'Vikram Joshi', 'platinum', 22, 332000.00, 334500.00, 2500.00, 0.75, 97.90, 'excellent', 0, 0, 'Consistent'),
('2026-06-01'::date, 'AIG Hospital', 'Rohit Mehra', 'gold', 11, 168000.00, 174800.00, 6800.00, 4.05, 88.30, 'good', 0, 0, 'Acceptable'),
('2026-05-01'::date, 'Apollo Hyderabad', 'Ravi Kumar', 'gold', 13, 198000.00, 201200.00, 3200.00, 1.62, 95.20, 'excellent', 0, 0, 'May baseline'),
('2026-05-01'::date, 'KIMS Secunderabad', 'Suresh Reddy', 'silver', 8, 124000.00, 138600.00, 14600.00, 11.77, 70.50, 'fair', 1, 3800.00, 'May baseline'),
('2026-05-01'::date, 'Yashoda Somajiguda', 'Anand Patel', 'platinum', 17, 252000.00, 253400.00, 1400.00, 0.56, 98.90, 'excellent', 0, 0, 'May baseline'),
('2026-05-01'::date, 'Care Hospital Banjara', 'Manoj Singh', 'bronze', 5, 64000.00, 79800.00, 15800.00, 24.69, 46.20, 'poor', 2, 9800.00, 'Repeat offender'),
('2026-06-01'::date, 'Rainbow Childrens', 'Lakshmi Iyer', 'gold', 8, 116000.00, 118400.00, 2400.00, 2.07, 93.50, 'good', 0, 0, 'Clean month'),
('2026-06-01'::date, 'Olive Hospital', 'Kiran Rao', 'silver', 7, 98000.00, 106200.00, 8200.00, 8.37, 75.40, 'fair', 1, 2100.00, 'Pre-approval gap'),
('2026-06-01'::date, 'Medicover Hitec City', 'Sneha Kapoor', 'bronze', 4, 52000.00, 64800.00, 12800.00, 24.62, 49.10, 'poor', 2, 7600.00, 'Quote discipline weak');

-- Seed incidents (16 rows)
INSERT INTO customer_quote_variance_incidents_r2916 (repair_job_ref, customer_org_name, engineer_name, quoted_rupees, final_billed_rupees, variance_pct, variance_reason, severity, resolution_status, resolved_at, refund_rupees, founder_review) VALUES
('RJ-26060001', 'Care Hospital Banjara', 'Manoj Singh', 8500.00, 12800.00, 50.59, 'unauthorized_parts', 'high', 'refunded', '2026-06-08 14:00:00'::timestamptz, 4300.00, true),
('RJ-26060002', 'KIMS Secunderabad', 'Suresh Reddy', 14000.00, 18200.00, 30.00, 'scope_creep', 'medium', 'resolved', '2026-06-10 11:00:00'::timestamptz, 2200.00, false),
('RJ-26060003', 'Care Hospital Banjara', 'Manoj Singh', 12000.00, 17400.00, 45.00, 'undisclosed_labor', 'high', 'refunded', '2026-06-12 09:30:00'::timestamptz, 5400.00, true),
('RJ-26060004', 'Medicover Hitec City', 'Sneha Kapoor', 9500.00, 13800.00, 45.26, 'parts_markup_excess', 'high', 'refunded', '2026-06-14 16:00:00'::timestamptz, 4300.00, true),
('RJ-26060005', 'Continental Gachibowli', 'Priya Sharma', 18000.00, 21200.00, 17.78, 'diagnostic_addon', 'low', 'resolved', '2026-06-15 10:00:00'::timestamptz, 1600.00, false),
('RJ-26060006', 'Olive Hospital', 'Kiran Rao', 11000.00, 13900.00, 26.36, 'pre_approval_skipped', 'medium', 'open', NULL, 0, true),
('RJ-26060007', 'Care Hospital Banjara', 'Manoj Singh', 7800.00, 10100.00, 29.49, 'consumable_overstatement', 'medium', 'refunded', '2026-06-18 13:00:00'::timestamptz, 2300.00, false),
('RJ-26060008', 'Sunshine Hospital', 'Deepak Yadav', 16500.00, 18000.00, 9.09, 'minor_addon', 'low', 'resolved', '2026-06-20 12:00:00'::timestamptz, 750.00, false),
('RJ-26060009', 'Medicover Hitec City', 'Sneha Kapoor', 8400.00, 12200.00, 45.24, 'fictitious_part', 'high', 'investigating', NULL, 0, true),
('RJ-26060010', 'KIMS Secunderabad', 'Suresh Reddy', 16800.00, 19500.00, 16.07, 'travel_addon_undisclosed', 'medium', 'resolved', '2026-06-22 09:00:00'::timestamptz, 1300.00, false),
('RJ-26060011', 'AIG Hospital', 'Rohit Mehra', 22000.00, 23400.00, 6.36, 'rounding', 'low', 'resolved', '2026-06-23 10:00:00'::timestamptz, 0, false),
('RJ-26060012', 'Apollo Hyderabad', 'Ravi Kumar', 19000.00, 19400.00, 2.11, 'within_tolerance', 'low', 'resolved', '2026-06-24 11:00:00'::timestamptz, 0, false),
('RJ-26060013', 'Olive Hospital', 'Kiran Rao', 13000.00, 15900.00, 22.31, 'parts_markup_excess', 'medium', 'open', NULL, 0, true),
('RJ-26060014', 'Medicover Hitec City', 'Sneha Kapoor', 10500.00, 14600.00, 39.05, 'unauthorized_parts', 'high', 'investigating', NULL, 0, true),
('RJ-26060015', 'Star Hospital Banjara', 'Vikram Joshi', 24000.00, 24200.00, 0.83, 'within_tolerance', 'low', 'resolved', '2026-06-26 09:00:00'::timestamptz, 0, false),
('RJ-26060016', 'Care Hospital Banjara', 'Manoj Singh', 9200.00, 13500.00, 46.74, 'fictitious_part', 'high', 'investigating', NULL, 0, true);

-- RPC 1: Monthly KPI rollup
CREATE OR REPLACE FUNCTION rpc_r2916_kpi_summary()
RETURNS TABLE (
  metric text,
  value text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT 'engineers_tracked'::text, count(DISTINCT engineer_name)::text
  FROM customer_quote_variance_snapshots_r2916
  WHERE snapshot_month = '2026-06-01'::date
  UNION ALL
  SELECT 'avg_variance_pct'::text, round(avg(variance_pct)::numeric, 2)::text
  FROM customer_quote_variance_snapshots_r2916
  WHERE snapshot_month = '2026-06-01'::date
  UNION ALL
  SELECT 'total_refund_rupees'::text, sum(refund_issued_rupees)::text
  FROM customer_quote_variance_snapshots_r2916
  WHERE snapshot_month = '2026-06-01'::date
  UNION ALL
  SELECT 'open_incidents'::text, count(*)::text
  FROM customer_quote_variance_incidents_r2916
  WHERE resolution_status IN ('open','investigating')
  UNION ALL
  SELECT 'high_severity_incidents'::text, count(*)::text
  FROM customer_quote_variance_incidents_r2916
  WHERE severity = 'high';
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2916_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2916_kpi_summary() TO authenticated;

-- RPC 2: Engineer trust leaderboard
CREATE OR REPLACE FUNCTION rpc_r2916_engineer_trust_leaderboard()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  engineer_tier text,
  jobs_completed int,
  variance_pct numeric,
  trust_score numeric,
  trust_band text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT s.id, s.engineer_name, s.engineer_tier, s.jobs_completed, s.variance_pct, s.trust_score, s.trust_band
  FROM customer_quote_variance_snapshots_r2916 s
  WHERE s.snapshot_month = '2026-06-01'::date
  ORDER BY s.trust_score DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2916_engineer_trust_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2916_engineer_trust_leaderboard() TO authenticated;

-- RPC 3: Customer variance per hospital
CREATE OR REPLACE FUNCTION rpc_r2916_customer_variance_view()
RETURNS TABLE (
  id uuid,
  customer_org_name text,
  total_quoted_rupees numeric,
  total_final_billed_rupees numeric,
  variance_rupees numeric,
  variance_pct numeric,
  disputed_jobs int,
  refund_issued_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT s.id, s.customer_org_name, s.total_quoted_rupees, s.total_final_billed_rupees,
         s.variance_rupees, s.variance_pct, s.disputed_jobs, s.refund_issued_rupees
  FROM customer_quote_variance_snapshots_r2916 s
  WHERE s.snapshot_month = '2026-06-01'::date
  ORDER BY s.variance_pct DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2916_customer_variance_view() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2916_customer_variance_view() TO authenticated;

-- RPC 4: Open incidents
CREATE OR REPLACE FUNCTION rpc_r2916_open_incidents()
RETURNS TABLE (
  id uuid,
  repair_job_ref text,
  customer_org_name text,
  engineer_name text,
  variance_pct numeric,
  variance_reason text,
  severity text,
  resolution_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT i.id, i.repair_job_ref, i.customer_org_name, i.engineer_name,
         i.variance_pct, i.variance_reason, i.severity, i.resolution_status
  FROM customer_quote_variance_incidents_r2916 i
  WHERE i.resolution_status IN ('open','investigating')
  ORDER BY i.variance_pct DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2916_open_incidents() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2916_open_incidents() TO authenticated;

-- RPC 5: High severity refunded
CREATE OR REPLACE FUNCTION rpc_r2916_refund_log()
RETURNS TABLE (
  id uuid,
  repair_job_ref text,
  engineer_name text,
  variance_pct numeric,
  refund_rupees numeric,
  resolved_at timestamptz,
  variance_reason text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT i.id, i.repair_job_ref, i.engineer_name, i.variance_pct,
         i.refund_rupees, i.resolved_at, i.variance_reason
  FROM customer_quote_variance_incidents_r2916 i
  WHERE i.refund_rupees > 0
  ORDER BY i.refund_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2916_refund_log() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2916_refund_log() TO authenticated;

-- RPC 6: Month-over-month variance trend per engineer
CREATE OR REPLACE FUNCTION rpc_r2916_mom_trend()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  may_variance_pct numeric,
  jun_variance_pct numeric,
  delta_pct numeric,
  direction text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    gen_random_uuid() AS id,
    m.engineer_name,
    m.variance_pct AS may_variance_pct,
    j.variance_pct AS jun_variance_pct,
    round((j.variance_pct - m.variance_pct)::numeric, 2) AS delta_pct,
    CASE WHEN j.variance_pct > m.variance_pct THEN 'worsening' ELSE 'improving' END AS direction
  FROM customer_quote_variance_snapshots_r2916 m
  JOIN customer_quote_variance_snapshots_r2916 j
    ON m.engineer_name = j.engineer_name
  WHERE m.snapshot_month = '2026-05-01'::date
    AND j.snapshot_month = '2026-06-01'::date
  ORDER BY abs(j.variance_pct - m.variance_pct) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2916_mom_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2916_mom_trend() TO authenticated;

-- RPC 7: Reason category breakdown
CREATE OR REPLACE FUNCTION rpc_r2916_reason_breakdown()
RETURNS TABLE (
  id uuid,
  variance_reason text,
  incident_count int,
  total_refund_rupees numeric,
  avg_variance_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden: founder only';
  END IF;

  RETURN QUERY
  SELECT
    gen_random_uuid() AS id,
    i.variance_reason,
    count(*)::int AS incident_count,
    coalesce(sum(i.refund_rupees), 0) AS total_refund_rupees,
    round(avg(i.variance_pct)::numeric, 2) AS avg_variance_pct
  FROM customer_quote_variance_incidents_r2916 i
  GROUP BY i.variance_reason
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r2916_reason_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2916_reason_breakdown() TO authenticated;
