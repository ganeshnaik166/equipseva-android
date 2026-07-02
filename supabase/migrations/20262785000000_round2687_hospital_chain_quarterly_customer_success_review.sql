BEGIN;

-- ============================================================
-- Round 2687: Hospital Chain Quarterly Customer Success Review
-- chain x CS health x outcome metric x success milestone x risk x action
-- ============================================================

-- Table 1: chain-level QBR records
CREATE TABLE IF NOT EXISTS hospital_chain_qbr_r2687 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  qbr_quarter text NOT NULL,
  cs_owner text NOT NULL,
  health_score numeric(5,2) NOT NULL CHECK (health_score >= 0 AND health_score <= 100),
  health_tier text NOT NULL CHECK (health_tier IN ('thriving','healthy','at_risk','critical')),
  arr_rupees bigint NOT NULL CHECK (arr_rupees >= 0),
  net_retention_pct numeric(5,2) NOT NULL,
  uptime_pct numeric(5,2) NOT NULL,
  csat_score numeric(3,2) NOT NULL CHECK (csat_score >= 0 AND csat_score <= 5),
  exec_sponsor text NOT NULL,
  review_date date NOT NULL,
  next_review_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('scheduled','in_progress','completed','renewed','escalated')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_qbr_r2687 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_qbr_r2687;
CREATE POLICY founder_all ON hospital_chain_qbr_r2687 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_qbr_r2687 (chain_code, chain_name, qbr_quarter, cs_owner, health_score, health_tier, arr_rupees, net_retention_pct, uptime_pct, csat_score, exec_sponsor, review_date, next_review_date, status) VALUES
('APOLLO', 'Apollo Hospitals Group', 'Q2-FY26', 'Priya Menon', 92.40, 'thriving', 18400000, 118.50, 99.62, 4.70, 'Dr. Sangita Reddy', '2026-06-12', '2026-09-15', 'renewed'),
('FORTIS', 'Fortis Healthcare', 'Q2-FY26', 'Rohan Kapoor', 78.20, 'healthy', 12200000, 104.10, 98.40, 4.30, 'Dr. Ashutosh Raghuvanshi', '2026-06-14', '2026-09-18', 'completed'),
('MANIPAL', 'Manipal Hospitals', 'Q2-FY26', 'Asha Bhat', 84.50, 'healthy', 9800000, 109.80, 99.10, 4.50, 'Dilip Jose', '2026-06-15', '2026-09-20', 'completed'),
('MAX', 'Max Healthcare', 'Q2-FY26', 'Vikram Suri', 62.80, 'at_risk', 7600000, 92.30, 96.10, 3.80, 'Abhay Soi', '2026-06-18', '2026-07-25', 'escalated'),
('NARAYANA', 'Narayana Health', 'Q2-FY26', 'Meera Iyer', 88.10, 'thriving', 8900000, 114.20, 99.30, 4.60, 'Dr. Devi Shetty', '2026-06-20', '2026-09-22', 'completed'),
('AIIMS-NETWORK', 'AIIMS Network', 'Q2-FY26', 'Suresh Pillai', 45.20, 'critical', 4200000, 78.40, 93.50, 3.10, 'Dr. M Srinivas', '2026-06-22', '2026-07-05', 'escalated'),
('KIMS', 'KIMS Hospitals', 'Q2-FY26', 'Rashmi Nair', 81.70, 'healthy', 6700000, 107.40, 98.80, 4.40, 'Dr. Bhaskar Rao', '2026-06-24', '2026-09-28', 'in_progress');

-- Table 2: per-chain action items, outcomes, milestones, risks
CREATE TABLE IF NOT EXISTS hospital_chain_qbr_actions_r2687 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qbr_id uuid NOT NULL REFERENCES hospital_chain_qbr_r2687(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('outcome_metric','success_milestone','risk_item','action_item')),
  title text NOT NULL,
  detail text NOT NULL,
  target_value text,
  actual_value text,
  owner text NOT NULL,
  due_date date,
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')),
  state text NOT NULL CHECK (state IN ('open','in_progress','done','blocked','deferred')),
  impact_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_qbr_actions_r2687 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_qbr_actions_r2687;
CREATE POLICY founder_all ON hospital_chain_qbr_actions_r2687 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'outcome_metric', 'MRI Uptime Target', 'Maintain MRI fleet uptime above SLA threshold', '99.5%', '99.62%', 'Priya Menon', '2026-09-15', 'p1', 'done', 1800000 FROM hospital_chain_qbr_r2687 WHERE chain_code='APOLLO';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'success_milestone', 'Expansion to 12 new sites', 'Onboard Apollo Bengaluru cluster + Hyderabad expansion', '12 sites', '12 sites', 'Priya Menon', '2026-06-10', 'p1', 'done', 6400000 FROM hospital_chain_qbr_r2687 WHERE chain_code='APOLLO';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'risk_item', 'AMC pricing pressure', 'Procurement asking for 8% AMC discount on renewal', '0% discount', 'Open negotiation', 'Rohan Kapoor', '2026-08-15', 'p1', 'in_progress', -980000 FROM hospital_chain_qbr_r2687 WHERE chain_code='FORTIS';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'action_item', 'Onsite engineer rotation', 'Quarterly engineer rotation review per Fortis SOP', '4 rotations', '3 done', 'Rohan Kapoor', '2026-07-20', 'p2', 'in_progress', 0 FROM hospital_chain_qbr_r2687 WHERE chain_code='FORTIS';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'risk_item', 'CT scanner aging fleet', '12 units past 7yr lifecycle, replacement quote pending', 'Replace 12', '4 quoted', 'Asha Bhat', '2026-08-30', 'p1', 'in_progress', -2200000 FROM hospital_chain_qbr_r2687 WHERE chain_code='MANIPAL';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'risk_item', 'Competitor pilot underway', 'Max IT team running competitor pilot in 2 sites', 'No churn', 'Pilot active', 'Vikram Suri', '2026-07-15', 'p0', 'open', -7600000 FROM hospital_chain_qbr_r2687 WHERE chain_code='MAX';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'action_item', 'Exec save call w/ Abhay Soi', 'Founder + Max chairman 1:1 to defuse competitor pilot', '1 meeting', 'Scheduled', 'Founder', '2026-07-02', 'p0', 'in_progress', 0 FROM hospital_chain_qbr_r2687 WHERE chain_code='MAX';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'success_milestone', 'NABH audit clean pass', 'Narayana audit closed with zero non-conformities', '0 NCs', '0 NCs', 'Meera Iyer', '2026-05-30', 'p1', 'done', 1900000 FROM hospital_chain_qbr_r2687 WHERE chain_code='NARAYANA';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'risk_item', 'AIIMS payment delay 90+ days', 'Govt PO clearance stalled, ₹42L AR aging', 'Collect 42L', '8L collected', 'Suresh Pillai', '2026-07-10', 'p0', 'blocked', -3400000 FROM hospital_chain_qbr_r2687 WHERE chain_code='AIIMS-NETWORK';
INSERT INTO hospital_chain_qbr_actions_r2687 (qbr_id, category, title, detail, target_value, actual_value, owner, due_date, priority, state, impact_rupees)
SELECT id, 'outcome_metric', 'KIMS first-call resolution', 'FCR rate for service requests', '85%', '88.4%', 'Rashmi Nair', '2026-06-30', 'p2', 'done', 740000 FROM hospital_chain_qbr_r2687 WHERE chain_code='KIMS';

-- ============================================================
-- RPC 1: KPI summary
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_kpis_r2687();
CREATE FUNCTION founder_chain_qbr_kpis_r2687()
RETURNS TABLE (
  total_chains int,
  thriving_chains int,
  at_risk_chains int,
  critical_chains int,
  total_arr_rupees bigint,
  avg_health_score numeric,
  avg_net_retention numeric,
  avg_csat numeric,
  open_p0_risks int,
  total_impact_at_risk_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM hospital_chain_qbr_r2687),
    (SELECT COUNT(*)::int FROM hospital_chain_qbr_r2687 WHERE health_tier='thriving'),
    (SELECT COUNT(*)::int FROM hospital_chain_qbr_r2687 WHERE health_tier='at_risk'),
    (SELECT COUNT(*)::int FROM hospital_chain_qbr_r2687 WHERE health_tier='critical'),
    (SELECT COALESCE(SUM(arr_rupees),0)::bigint FROM hospital_chain_qbr_r2687),
    (SELECT COALESCE(AVG(health_score),0)::numeric FROM hospital_chain_qbr_r2687),
    (SELECT COALESCE(AVG(net_retention_pct),0)::numeric FROM hospital_chain_qbr_r2687),
    (SELECT COALESCE(AVG(csat_score),0)::numeric FROM hospital_chain_qbr_r2687),
    (SELECT COUNT(*)::int FROM hospital_chain_qbr_actions_r2687 WHERE priority='p0' AND state IN ('open','in_progress','blocked')),
    (SELECT COALESCE(SUM(impact_rupees),0)::bigint FROM hospital_chain_qbr_actions_r2687 WHERE category='risk_item' AND state IN ('open','in_progress','blocked'));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_kpis_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_kpis_r2687() TO authenticated;

-- ============================================================
-- RPC 2: list chains with health tier
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_list_r2687();
CREATE FUNCTION founder_chain_qbr_list_r2687()
RETURNS TABLE (
  id uuid,
  chain_code text,
  chain_name text,
  qbr_quarter text,
  cs_owner text,
  health_score numeric,
  health_tier text,
  arr_rupees bigint,
  net_retention_pct numeric,
  uptime_pct numeric,
  csat_score numeric,
  exec_sponsor text,
  status text,
  review_date date,
  next_review_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.chain_code, q.chain_name, q.qbr_quarter, q.cs_owner,
         q.health_score, q.health_tier, q.arr_rupees, q.net_retention_pct,
         q.uptime_pct, q.csat_score, q.exec_sponsor, q.status,
         q.review_date, q.next_review_date
  FROM hospital_chain_qbr_r2687 q
  ORDER BY q.health_score ASC, q.arr_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_list_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_list_r2687() TO authenticated;

-- ============================================================
-- RPC 3: list risks (p0/p1 first)
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_risks_r2687();
CREATE FUNCTION founder_chain_qbr_risks_r2687()
RETURNS TABLE (
  id uuid,
  chain_name text,
  title text,
  detail text,
  owner text,
  priority text,
  state text,
  due_date date,
  impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, q.chain_name, a.title, a.detail, a.owner, a.priority, a.state, a.due_date, a.impact_rupees
  FROM hospital_chain_qbr_actions_r2687 a
  JOIN hospital_chain_qbr_r2687 q ON q.id = a.qbr_id
  WHERE a.category = 'risk_item'
  ORDER BY
    CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    a.impact_rupees ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_risks_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_risks_r2687() TO authenticated;

-- ============================================================
-- RPC 4: milestones
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_milestones_r2687();
CREATE FUNCTION founder_chain_qbr_milestones_r2687()
RETURNS TABLE (
  id uuid,
  chain_name text,
  title text,
  detail text,
  target_value text,
  actual_value text,
  owner text,
  state text,
  impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, q.chain_name, a.title, a.detail, a.target_value, a.actual_value, a.owner, a.state, a.impact_rupees
  FROM hospital_chain_qbr_actions_r2687 a
  JOIN hospital_chain_qbr_r2687 q ON q.id = a.qbr_id
  WHERE a.category = 'success_milestone'
  ORDER BY a.impact_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_milestones_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_milestones_r2687() TO authenticated;

-- ============================================================
-- RPC 5: outcome metrics
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_outcomes_r2687();
CREATE FUNCTION founder_chain_qbr_outcomes_r2687()
RETURNS TABLE (
  id uuid,
  chain_name text,
  title text,
  detail text,
  target_value text,
  actual_value text,
  state text,
  impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, q.chain_name, a.title, a.detail, a.target_value, a.actual_value, a.state, a.impact_rupees
  FROM hospital_chain_qbr_actions_r2687 a
  JOIN hospital_chain_qbr_r2687 q ON q.id = a.qbr_id
  WHERE a.category = 'outcome_metric'
  ORDER BY q.chain_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_outcomes_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_outcomes_r2687() TO authenticated;

-- ============================================================
-- RPC 6: action items
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_actions_r2687();
CREATE FUNCTION founder_chain_qbr_actions_r2687()
RETURNS TABLE (
  id uuid,
  chain_name text,
  title text,
  detail text,
  owner text,
  priority text,
  state text,
  due_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, q.chain_name, a.title, a.detail, a.owner, a.priority, a.state, a.due_date
  FROM hospital_chain_qbr_actions_r2687 a
  JOIN hospital_chain_qbr_r2687 q ON q.id = a.qbr_id
  WHERE a.category = 'action_item'
  ORDER BY
    CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    a.due_date ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_actions_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_actions_r2687() TO authenticated;

-- ============================================================
-- RPC 7: tier rollup
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_tier_rollup_r2687();
CREATE FUNCTION founder_chain_qbr_tier_rollup_r2687()
RETURNS TABLE (
  health_tier text,
  chain_count int,
  total_arr_rupees bigint,
  avg_health numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.health_tier,
    COUNT(*)::int,
    COALESCE(SUM(q.arr_rupees),0)::bigint,
    COALESCE(AVG(q.health_score),0)::numeric,
    COALESCE(AVG(q.csat_score),0)::numeric
  FROM hospital_chain_qbr_r2687 q
  GROUP BY q.health_tier
  ORDER BY
    CASE q.health_tier
      WHEN 'critical' THEN 0
      WHEN 'at_risk' THEN 1
      WHEN 'healthy' THEN 2
      WHEN 'thriving' THEN 3
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_tier_rollup_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_tier_rollup_r2687() TO authenticated;

-- ============================================================
-- RPC 8: upcoming reviews
-- ============================================================
DROP FUNCTION IF EXISTS founder_chain_qbr_upcoming_r2687();
CREATE FUNCTION founder_chain_qbr_upcoming_r2687()
RETURNS TABLE (
  id uuid,
  chain_name text,
  cs_owner text,
  exec_sponsor text,
  health_tier text,
  next_review_date date,
  days_until int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.chain_name, q.cs_owner, q.exec_sponsor, q.health_tier, q.next_review_date,
         (q.next_review_date - CURRENT_DATE)::int
  FROM hospital_chain_qbr_r2687 q
  ORDER BY q.next_review_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_qbr_upcoming_r2687() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_qbr_upcoming_r2687() TO authenticated;

COMMIT;
