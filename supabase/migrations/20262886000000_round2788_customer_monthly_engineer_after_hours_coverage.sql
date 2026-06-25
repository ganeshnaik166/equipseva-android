BEGIN;

-- =====================================================================
-- Round r2788 — Customer Monthly Engineer After-Hours Coverage
-- HEAVY ★★★★ founder console
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: customer monthly after-hours incident ledger
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_after_hours_incidents_r2788 (
  id bigserial PRIMARY KEY,
  month_label text NOT NULL,
  customer_org_name text NOT NULL,
  customer_tier text NOT NULL CHECK (customer_tier IN ('platinum','gold','silver','bronze')),
  incident_count int NOT NULL CHECK (incident_count >= 0),
  after_hours_count int NOT NULL CHECK (after_hours_count >= 0),
  weekend_count int NOT NULL CHECK (weekend_count >= 0),
  avg_response_minutes numeric(10,2) NOT NULL CHECK (avg_response_minutes >= 0),
  sla_breach_count int NOT NULL CHECK (sla_breach_count >= 0),
  resolved_count int NOT NULL CHECK (resolved_count >= 0),
  outcome_status text NOT NULL CHECK (outcome_status IN ('within_policy','breach_minor','breach_major','escalated','review_pending')),
  policy_band text NOT NULL CHECK (policy_band IN ('24x7_premium','extended_hours','business_hours','best_effort')),
  override_credit_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (override_credit_rupees >= 0),
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_after_hours_incidents_r2788 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON customer_after_hours_incidents_r2788;
CREATE POLICY founder_all ON customer_after_hours_incidents_r2788
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_after_hours_incidents_r2788
  (month_label, customer_org_name, customer_tier, incident_count, after_hours_count,
   weekend_count, avg_response_minutes, sla_breach_count, resolved_count,
   outcome_status, policy_band, override_credit_rupees, reviewed_at)
VALUES
  ('2026-06','Apollo Hyderabad Jubilee','platinum',18,11,4,14.20,1,17,'within_policy','24x7_premium',0,'2026-06-21T09:00:00+05:30'::timestamptz),
  ('2026-06','KIMS Secunderabad','gold',12,7,3,26.50,2,11,'breach_minor','extended_hours',4500.00,'2026-06-21T09:15:00+05:30'::timestamptz),
  ('2026-06','Yashoda Somajiguda','gold',9,5,2,41.80,3,8,'breach_major','extended_hours',12000.00,'2026-06-21T09:30:00+05:30'::timestamptz),
  ('2026-06','Care Banjara','silver',6,2,1,55.40,1,6,'within_policy','business_hours',0,'2026-06-21T09:45:00+05:30'::timestamptz),
  ('2026-06','Sunshine Paradise','silver',4,1,0,38.10,0,4,'within_policy','business_hours',0,'2026-06-21T10:00:00+05:30'::timestamptz),
  ('2026-06','Rainbow Children Hitech','bronze',3,0,0,72.20,1,3,'review_pending','best_effort',0,NULL),
  ('2026-06','Continental Gachibowli','platinum',15,9,3,12.40,0,15,'within_policy','24x7_premium',0,'2026-06-21T10:15:00+05:30'::timestamptz),
  ('2026-06','Asian Institute Mehdipatnam','gold',7,4,2,33.70,2,6,'escalated','extended_hours',8500.00,NULL);

-- ---------------------------------------------------------------------
-- Table 2: engineer after-hours coverage roster
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_after_hours_coverage_r2788 (
  id bigserial PRIMARY KEY,
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  engineer_tier text NOT NULL CHECK (engineer_tier IN ('senior','mid','junior','contractor')),
  shifts_assigned int NOT NULL CHECK (shifts_assigned >= 0),
  shifts_accepted int NOT NULL CHECK (shifts_accepted >= 0),
  shifts_no_show int NOT NULL CHECK (shifts_no_show >= 0),
  incidents_handled int NOT NULL CHECK (incidents_handled >= 0),
  avg_first_response_min numeric(10,2) NOT NULL CHECK (avg_first_response_min >= 0),
  customer_csat numeric(3,2) NOT NULL CHECK (customer_csat >= 0 AND customer_csat <= 5),
  outcome_grade text NOT NULL CHECK (outcome_grade IN ('A','B','C','D','review')),
  policy_compliance_pct numeric(5,2) NOT NULL CHECK (policy_compliance_pct >= 0 AND policy_compliance_pct <= 100),
  on_call_bonus_rupees numeric(12,2) NOT NULL DEFAULT 0 CHECK (on_call_bonus_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_after_hours_coverage_r2788 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON engineer_after_hours_coverage_r2788;
CREATE POLICY founder_all ON engineer_after_hours_coverage_r2788
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_after_hours_coverage_r2788
  (month_label, engineer_name, engineer_tier, shifts_assigned, shifts_accepted,
   shifts_no_show, incidents_handled, avg_first_response_min, customer_csat,
   outcome_grade, policy_compliance_pct, on_call_bonus_rupees, notes)
VALUES
  ('2026-06','Ravi Kumar','senior',12,12,0,28,11.40,4.80,'A',98.50,18000.00,'Top performer Apollo + Continental night runs'),
  ('2026-06','Suresh Reddy','senior',10,10,0,22,15.20,4.60,'A',96.00,15000.00,'Stable KIMS coverage'),
  ('2026-06','Priya Sharma','mid',9,8,1,17,22.80,4.30,'B',88.00,9500.00,'One no-show 14-Jun'),
  ('2026-06','Anil Naidu','mid',8,7,1,14,28.40,4.10,'B',85.50,8000.00,'Yashoda escalation cleared'),
  ('2026-06','Lakshmi Devi','junior',7,7,0,11,34.20,3.90,'C',82.00,5500.00,'Mentor pairing recommended'),
  ('2026-06','Mahesh Goud','contractor',6,5,1,9,42.10,3.60,'C',72.00,4000.00,'Contract review July'),
  ('2026-06','Deepak Iyer','senior',11,11,0,26,12.80,4.70,'A',97.50,17000.00,'Asian Institute escalation lead'),
  ('2026-06','Sneha Patel','junior',5,4,1,7,48.60,3.30,'D',65.00,2500.00,'PIP triggered policy review');

-- ---------------------------------------------------------------------
-- RPC 1: monthly summary KPIs
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_summary();
CREATE OR REPLACE FUNCTION founder_r2788_summary()
RETURNS TABLE(
  total_customers int,
  total_incidents int,
  total_after_hours int,
  total_breaches int,
  total_credit_rupees numeric,
  avg_response_min numeric,
  total_engineers int,
  total_shifts int,
  total_no_shows int,
  total_bonus_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM customer_after_hours_incidents_r2788),
    (SELECT COALESCE(SUM(incident_count),0)::int FROM customer_after_hours_incidents_r2788),
    (SELECT COALESCE(SUM(after_hours_count),0)::int FROM customer_after_hours_incidents_r2788),
    (SELECT COALESCE(SUM(sla_breach_count),0)::int FROM customer_after_hours_incidents_r2788),
    (SELECT COALESCE(SUM(override_credit_rupees),0)::numeric FROM customer_after_hours_incidents_r2788),
    (SELECT COALESCE(ROUND(AVG(avg_response_minutes),2),0)::numeric FROM customer_after_hours_incidents_r2788),
    (SELECT COUNT(*)::int FROM engineer_after_hours_coverage_r2788),
    (SELECT COALESCE(SUM(shifts_assigned),0)::int FROM engineer_after_hours_coverage_r2788),
    (SELECT COALESCE(SUM(shifts_no_show),0)::int FROM engineer_after_hours_coverage_r2788),
    (SELECT COALESCE(SUM(on_call_bonus_rupees),0)::numeric FROM engineer_after_hours_coverage_r2788);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_summary() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 2: customers by tier breakdown
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_customers_by_tier();
CREATE OR REPLACE FUNCTION founder_r2788_customers_by_tier()
RETURNS TABLE(
  customer_tier text,
  customer_count int,
  incident_total int,
  after_hours_total int,
  breach_total int,
  avg_response numeric,
  credit_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.customer_tier,
    COUNT(*)::int,
    COALESCE(SUM(c.incident_count),0)::int,
    COALESCE(SUM(c.after_hours_count),0)::int,
    COALESCE(SUM(c.sla_breach_count),0)::int,
    COALESCE(ROUND(AVG(c.avg_response_minutes),2),0)::numeric,
    COALESCE(SUM(c.override_credit_rupees),0)::numeric
  FROM customer_after_hours_incidents_r2788 c
  GROUP BY c.customer_tier
  ORDER BY breach_total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_customers_by_tier() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_customers_by_tier() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 3: outcome status distribution
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_outcome_distribution();
CREATE OR REPLACE FUNCTION founder_r2788_outcome_distribution()
RETURNS TABLE(
  outcome_status text,
  customer_count int,
  incident_total int,
  credit_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.outcome_status,
    COUNT(*)::int,
    COALESCE(SUM(c.incident_count),0)::int,
    COALESCE(SUM(c.override_credit_rupees),0)::numeric
  FROM customer_after_hours_incidents_r2788 c
  GROUP BY c.outcome_status
  ORDER BY credit_total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_outcome_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_outcome_distribution() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 4: policy band breakdown
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_policy_bands();
CREATE OR REPLACE FUNCTION founder_r2788_policy_bands()
RETURNS TABLE(
  policy_band text,
  customer_count int,
  after_hours_total int,
  breach_total int,
  avg_response numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.policy_band,
    COUNT(*)::int,
    COALESCE(SUM(c.after_hours_count),0)::int,
    COALESCE(SUM(c.sla_breach_count),0)::int,
    COALESCE(ROUND(AVG(c.avg_response_minutes),2),0)::numeric
  FROM customer_after_hours_incidents_r2788 c
  GROUP BY c.policy_band
  ORDER BY breach_total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_policy_bands() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_policy_bands() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 5: top breach customers
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_top_breach_customers();
CREATE OR REPLACE FUNCTION founder_r2788_top_breach_customers()
RETURNS TABLE(
  customer_org_name text,
  customer_tier text,
  policy_band text,
  after_hours_count int,
  sla_breach_count int,
  avg_response_minutes numeric,
  override_credit_rupees numeric,
  outcome_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.customer_org_name, c.customer_tier, c.policy_band,
    c.after_hours_count, c.sla_breach_count, c.avg_response_minutes,
    c.override_credit_rupees, c.outcome_status
  FROM customer_after_hours_incidents_r2788 c
  ORDER BY c.sla_breach_count DESC, c.override_credit_rupees DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_top_breach_customers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_top_breach_customers() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 6: engineer roster ranking
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_engineer_roster();
CREATE OR REPLACE FUNCTION founder_r2788_engineer_roster()
RETURNS TABLE(
  engineer_name text,
  engineer_tier text,
  shifts_assigned int,
  shifts_accepted int,
  shifts_no_show int,
  incidents_handled int,
  avg_first_response_min numeric,
  customer_csat numeric,
  outcome_grade text,
  policy_compliance_pct numeric,
  on_call_bonus_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.engineer_name, e.engineer_tier, e.shifts_assigned, e.shifts_accepted,
    e.shifts_no_show, e.incidents_handled, e.avg_first_response_min,
    e.customer_csat, e.outcome_grade, e.policy_compliance_pct, e.on_call_bonus_rupees
  FROM engineer_after_hours_coverage_r2788 e
  ORDER BY e.policy_compliance_pct DESC, e.customer_csat DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_engineer_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_engineer_roster() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 7: engineer grade rollup
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_engineer_grade_rollup();
CREATE OR REPLACE FUNCTION founder_r2788_engineer_grade_rollup()
RETURNS TABLE(
  outcome_grade text,
  engineer_count int,
  shifts_total int,
  no_show_total int,
  incidents_total int,
  avg_csat numeric,
  bonus_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.outcome_grade,
    COUNT(*)::int,
    COALESCE(SUM(e.shifts_assigned),0)::int,
    COALESCE(SUM(e.shifts_no_show),0)::int,
    COALESCE(SUM(e.incidents_handled),0)::int,
    COALESCE(ROUND(AVG(e.customer_csat),2),0)::numeric,
    COALESCE(SUM(e.on_call_bonus_rupees),0)::numeric
  FROM engineer_after_hours_coverage_r2788 e
  GROUP BY e.outcome_grade
  ORDER BY avg_csat DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_engineer_grade_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_engineer_grade_rollup() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC 8: policy review queue (pending + escalated)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS founder_r2788_policy_review_queue();
CREATE OR REPLACE FUNCTION founder_r2788_policy_review_queue()
RETURNS TABLE(
  customer_org_name text,
  customer_tier text,
  policy_band text,
  outcome_status text,
  after_hours_count int,
  sla_breach_count int,
  override_credit_rupees numeric,
  reviewed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.customer_org_name, c.customer_tier, c.policy_band, c.outcome_status,
    c.after_hours_count, c.sla_breach_count, c.override_credit_rupees, c.reviewed_at
  FROM customer_after_hours_incidents_r2788 c
  WHERE c.outcome_status IN ('escalated','review_pending','breach_major')
     OR c.reviewed_at IS NULL
  ORDER BY c.sla_breach_count DESC, c.override_credit_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2788_policy_review_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2788_policy_review_queue() TO authenticated;

COMMIT;
