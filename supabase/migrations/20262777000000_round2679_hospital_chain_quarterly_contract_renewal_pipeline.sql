BEGIN;

-- =============================================================================
-- Round 2679 — Hospital Chain Quarterly Contract Renewal Pipeline
-- =============================================================================

-- ---------- Table 1: chain renewal pipeline ----------
DROP TABLE IF EXISTS hospital_chain_renewal_pipeline_r2679 CASCADE;
CREATE TABLE hospital_chain_renewal_pipeline_r2679 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('national','regional','metro','tier2')),
  city text NOT NULL,
  hospital_count int NOT NULL CHECK (hospital_count > 0),
  current_acv_lakhs numeric(10,2) NOT NULL CHECK (current_acv_lakhs >= 0),
  renewal_target_lakhs numeric(10,2) NOT NULL CHECK (renewal_target_lakhs >= 0),
  contract_end_quarter text NOT NULL CHECK (contract_end_quarter IN ('Q1','Q2','Q3','Q4')),
  contract_end_date date NOT NULL,
  renewal_stage text NOT NULL CHECK (renewal_stage IN ('discovery','proposal','negotiation','redlines','signed','lost')),
  risk_level text NOT NULL CHECK (risk_level IN ('low','medium','high','critical')),
  churn_probability_pct int NOT NULL CHECK (churn_probability_pct BETWEEN 0 AND 100),
  uptime_last_qtr_pct numeric(5,2) NOT NULL CHECK (uptime_last_qtr_pct BETWEEN 0 AND 100),
  satisfaction_score numeric(3,1) NOT NULL CHECK (satisfaction_score BETWEEN 0 AND 10),
  competitor_threat text NOT NULL CHECK (competitor_threat IN ('none','low','medium','high')),
  decision_maker text NOT NULL,
  owner_email text NOT NULL,
  next_action text NOT NULL,
  next_action_due date NOT NULL,
  founder_decision text NOT NULL CHECK (founder_decision IN ('pursue_aggressively','standard','discount_allowed','walk_away','escalate')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_renewal_pipeline_r2679 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_renewal_pipeline_r2679;
CREATE POLICY founder_all ON hospital_chain_renewal_pipeline_r2679
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_renewal_pipeline_r2679
  (chain_name, chain_tier, city, hospital_count, current_acv_lakhs, renewal_target_lakhs,
   contract_end_quarter, contract_end_date, renewal_stage, risk_level, churn_probability_pct,
   uptime_last_qtr_pct, satisfaction_score, competitor_threat, decision_maker, owner_email,
   next_action, next_action_due, founder_decision, notes)
VALUES
  ('Apollo Hospitals Group','national','Chennai',71,420.00,520.00,'Q3','2026-09-30','negotiation','high',45,97.20,8.4,'high','Dr. Preetha Reddy (Vice Chair)','keyaccts@equipseva.com','CFO meeting + uptime SLA upgrade pitch','2026-07-08','pursue_aggressively','Largest account. Philips threat real.'),
  ('Manipal Hospitals','national','Bengaluru',29,285.00,340.00,'Q3','2026-09-15','proposal','medium',28,98.10,8.8,'medium','Dr. Ranjan Pai (Chairman)','keyaccts@equipseva.com','Submit revised proposal w/ AMC tier upgrade','2026-07-02','pursue_aggressively','Strong relationship, expansion likely.'),
  ('Fortis Healthcare','national','New Delhi',36,310.00,360.00,'Q4','2026-12-20','discovery','medium',32,96.50,8.1,'medium','Dr. Ashutosh Raghuvanshi (CEO)','keyaccts@equipseva.com','Schedule QBR + multi-year discount discussion','2026-07-15','standard','IHH ownership new procurement policy.'),
  ('Narayana Health','national','Bengaluru',24,180.00,210.00,'Q3','2026-08-31','negotiation','low',15,99.10,9.2,'low','Dr. Devi Shetty (Chairman)','keyaccts@equipseva.com','Sign multi-year + volume rebate','2026-06-28','standard','Best-in-class uptime. Low churn risk.'),
  ('Max Healthcare','regional','New Delhi',17,145.00,175.00,'Q4','2026-11-15','redlines','high',52,94.80,7.6,'high','Abhay Soi (Chairman)','keyaccts@equipseva.com','Founder call + competitive defense','2026-07-05','escalate','GE Healthcare aggressive. Uptime slipped.'),
  ('KIMS Hospitals','regional','Hyderabad',12,82.00,105.00,'Q3','2026-09-22','proposal','medium',25,97.80,8.5,'medium','Dr. Bhaskar Rao (Chairman)','keyaccts@equipseva.com','Demo new triage workflow','2026-07-10','pursue_aggressively','Home turf. Strategic showcase.'),
  ('Yashoda Hospitals','metro','Hyderabad',6,52.00,68.00,'Q4','2026-10-30','discovery','low',18,98.50,8.9,'low','Dr. G S Rao (MD)','keyaccts@equipseva.com','QBR + expansion to Somajiguda','2026-07-20','standard','Reference account.'),
  ('Aster DM Healthcare','regional','Kochi',14,118.00,140.00,'Q3','2026-09-10','negotiation','medium',30,96.90,8.2,'medium','Dr. Azad Moopen (Chairman)','keyaccts@equipseva.com','Negotiate AED 4cr multi-country rider','2026-07-04','standard','Middle East ops cross-sell.'),
  ('Medanta','regional','Gurgaon',8,95.00,115.00,'Q4','2026-12-05','proposal','critical',68,93.20,7.2,'high','Dr. Naresh Trehan (Chairman)','keyaccts@equipseva.com','Founder onsite + free upgrade pilot','2026-07-01','escalate','Siemens active competitor displacement.'),
  ('Rainbow Hospitals','metro','Hyderabad',9,42.00,55.00,'Q3','2026-08-25','signed','low',8,99.30,9.4,'none','Dr. Ramesh Kancharla (Chairman)','keyaccts@equipseva.com','Kickoff renewal Q4 expansion','2026-08-15','standard','Already signed. Showcase win.');

-- ---------- Table 2: action ledger ----------
DROP TABLE IF EXISTS hospital_chain_renewal_action_ledger_r2679 CASCADE;
CREATE TABLE hospital_chain_renewal_action_ledger_r2679 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  action_type text NOT NULL CHECK (action_type IN ('email','call','meeting','proposal_sent','contract_sent','site_visit','escalation','signed')),
  action_summary text NOT NULL,
  action_owner text NOT NULL,
  action_outcome text NOT NULL CHECK (action_outcome IN ('positive','neutral','negative','pending')),
  delta_acv_lakhs numeric(10,2) NOT NULL DEFAULT 0,
  action_date date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_renewal_action_ledger_r2679 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_renewal_action_ledger_r2679;
CREATE POLICY founder_all ON hospital_chain_renewal_action_ledger_r2679
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_renewal_action_ledger_r2679
  (chain_name, action_type, action_summary, action_owner, action_outcome, delta_acv_lakhs, action_date)
VALUES
  ('Apollo Hospitals Group','meeting','QBR + uptime review with CIO','keyaccts@equipseva.com','positive',0,'2026-06-12'),
  ('Manipal Hospitals','proposal_sent','3-year proposal Rs 340L ACV','keyaccts@equipseva.com','pending',55.00,'2026-06-18'),
  ('Fortis Healthcare','call','IHH procurement intro call','keyaccts@equipseva.com','neutral',0,'2026-06-15'),
  ('Narayana Health','contract_sent','Multi-year DocuSign sent','keyaccts@equipseva.com','positive',30.00,'2026-06-19'),
  ('Max Healthcare','escalation','GE displacement threat — founder loop','founder@equipseva.com','negative',0,'2026-06-17'),
  ('KIMS Hospitals','site_visit','Showcase Hyderabad ops','keyaccts@equipseva.com','positive',0,'2026-06-10'),
  ('Medanta','meeting','Siemens defense — onsite Dr Trehan','founder@equipseva.com','neutral',0,'2026-06-20'),
  ('Aster DM Healthcare','email','Multi-country rider draft v2','keyaccts@equipseva.com','pending',22.00,'2026-06-16'),
  ('Rainbow Hospitals','signed','Q3 renewal signed Rs 55L ACV','keyaccts@equipseva.com','positive',13.00,'2026-06-14'),
  ('Yashoda Hospitals','call','Somajiguda expansion intro','keyaccts@equipseva.com','positive',0,'2026-06-19');

-- =============================================================================
-- RPC 1: KPIs
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_kpis();
CREATE OR REPLACE FUNCTION founder_r2679_kpis()
RETURNS TABLE(
  total_chains int,
  total_hospitals int,
  current_acv_lakhs numeric,
  target_acv_lakhs numeric,
  uplift_lakhs numeric,
  critical_count int,
  signed_count int,
  weighted_pipeline_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(hospital_count),0)::int,
    COALESCE(SUM(current_acv_lakhs),0)::numeric,
    COALESCE(SUM(renewal_target_lakhs),0)::numeric,
    COALESCE(SUM(renewal_target_lakhs - current_acv_lakhs),0)::numeric,
    COUNT(*) FILTER (WHERE risk_level = 'critical')::int,
    COUNT(*) FILTER (WHERE renewal_stage = 'signed')::int,
    COALESCE(SUM(renewal_target_lakhs * (100 - churn_probability_pct) / 100.0),0)::numeric
  FROM hospital_chain_renewal_pipeline_r2679;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_kpis() TO authenticated;

-- =============================================================================
-- RPC 2: Pipeline rows
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_pipeline();
CREATE OR REPLACE FUNCTION founder_r2679_pipeline()
RETURNS TABLE(
  id uuid,
  chain_name text,
  chain_tier text,
  city text,
  hospital_count int,
  current_acv_lakhs numeric,
  renewal_target_lakhs numeric,
  uplift_lakhs numeric,
  contract_end_quarter text,
  contract_end_date date,
  renewal_stage text,
  risk_level text,
  churn_probability_pct int,
  uptime_last_qtr_pct numeric,
  satisfaction_score numeric,
  competitor_threat text,
  decision_maker text,
  next_action text,
  next_action_due date,
  founder_decision text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.chain_name, p.chain_tier, p.city, p.hospital_count,
         p.current_acv_lakhs, p.renewal_target_lakhs,
         (p.renewal_target_lakhs - p.current_acv_lakhs)::numeric AS uplift_lakhs,
         p.contract_end_quarter, p.contract_end_date, p.renewal_stage,
         p.risk_level, p.churn_probability_pct, p.uptime_last_qtr_pct,
         p.satisfaction_score, p.competitor_threat, p.decision_maker,
         p.next_action, p.next_action_due, p.founder_decision
  FROM hospital_chain_renewal_pipeline_r2679 p
  ORDER BY
    CASE p.risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    p.contract_end_date ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_pipeline() TO authenticated;

-- =============================================================================
-- RPC 3: Risk roll-up
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_risk_rollup();
CREATE OR REPLACE FUNCTION founder_r2679_risk_rollup()
RETURNS TABLE(
  risk_level text,
  chain_count int,
  target_acv_lakhs numeric,
  avg_churn_pct numeric,
  weighted_at_risk_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.risk_level,
         COUNT(*)::int,
         COALESCE(SUM(p.renewal_target_lakhs),0)::numeric,
         ROUND(AVG(p.churn_probability_pct)::numeric, 1),
         COALESCE(SUM(p.renewal_target_lakhs * p.churn_probability_pct / 100.0),0)::numeric
  FROM hospital_chain_renewal_pipeline_r2679 p
  GROUP BY p.risk_level
  ORDER BY
    CASE p.risk_level WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_risk_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_risk_rollup() TO authenticated;

-- =============================================================================
-- RPC 4: Stage funnel
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_stage_funnel();
CREATE OR REPLACE FUNCTION founder_r2679_stage_funnel()
RETURNS TABLE(
  renewal_stage text,
  chain_count int,
  target_acv_lakhs numeric,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(renewal_target_lakhs),0) INTO total FROM hospital_chain_renewal_pipeline_r2679;
  IF total = 0 THEN total := 1; END IF;
  RETURN QUERY
  SELECT p.renewal_stage,
         COUNT(*)::int,
         COALESCE(SUM(p.renewal_target_lakhs),0)::numeric,
         ROUND((COALESCE(SUM(p.renewal_target_lakhs),0) / total * 100)::numeric, 1)
  FROM hospital_chain_renewal_pipeline_r2679 p
  GROUP BY p.renewal_stage
  ORDER BY
    CASE p.renewal_stage
      WHEN 'discovery' THEN 1
      WHEN 'proposal' THEN 2
      WHEN 'negotiation' THEN 3
      WHEN 'redlines' THEN 4
      WHEN 'signed' THEN 5
      WHEN 'lost' THEN 6
    END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_stage_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_stage_funnel() TO authenticated;

-- =============================================================================
-- RPC 5: Quarter breakdown
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_quarter_breakdown();
CREATE OR REPLACE FUNCTION founder_r2679_quarter_breakdown()
RETURNS TABLE(
  contract_end_quarter text,
  chain_count int,
  target_acv_lakhs numeric,
  at_risk_acv_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.contract_end_quarter,
         COUNT(*)::int,
         COALESCE(SUM(p.renewal_target_lakhs),0)::numeric,
         COALESCE(SUM(CASE WHEN p.risk_level IN ('high','critical') THEN p.renewal_target_lakhs ELSE 0 END),0)::numeric
  FROM hospital_chain_renewal_pipeline_r2679 p
  GROUP BY p.contract_end_quarter
  ORDER BY p.contract_end_quarter;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_quarter_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_quarter_breakdown() TO authenticated;

-- =============================================================================
-- RPC 6: Competitor threat scan
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_competitor_threats();
CREATE OR REPLACE FUNCTION founder_r2679_competitor_threats()
RETURNS TABLE(
  competitor_threat text,
  chain_count int,
  target_acv_lakhs numeric,
  avg_satisfaction numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.competitor_threat,
         COUNT(*)::int,
         COALESCE(SUM(p.renewal_target_lakhs),0)::numeric,
         ROUND(AVG(p.satisfaction_score)::numeric, 1)
  FROM hospital_chain_renewal_pipeline_r2679 p
  GROUP BY p.competitor_threat
  ORDER BY
    CASE p.competitor_threat WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 ELSE 4 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_competitor_threats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_competitor_threats() TO authenticated;

-- =============================================================================
-- RPC 7: Action ledger
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_action_ledger();
CREATE OR REPLACE FUNCTION founder_r2679_action_ledger()
RETURNS TABLE(
  id uuid,
  chain_name text,
  action_type text,
  action_summary text,
  action_owner text,
  action_outcome text,
  delta_acv_lakhs numeric,
  action_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.action_type, a.action_summary,
         a.action_owner, a.action_outcome, a.delta_acv_lakhs, a.action_date
  FROM hospital_chain_renewal_action_ledger_r2679 a
  ORDER BY a.action_date DESC, a.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_action_ledger() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_action_ledger() TO authenticated;

-- =============================================================================
-- RPC 8: Critical attention list
-- =============================================================================
DROP FUNCTION IF EXISTS founder_r2679_attention_list();
CREATE OR REPLACE FUNCTION founder_r2679_attention_list()
RETURNS TABLE(
  chain_name text,
  city text,
  renewal_target_lakhs numeric,
  risk_level text,
  churn_probability_pct int,
  competitor_threat text,
  founder_decision text,
  next_action text,
  next_action_due date,
  days_to_action int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.city, p.renewal_target_lakhs, p.risk_level,
         p.churn_probability_pct, p.competitor_threat, p.founder_decision,
         p.next_action, p.next_action_due,
         (p.next_action_due - CURRENT_DATE)::int AS days_to_action
  FROM hospital_chain_renewal_pipeline_r2679 p
  WHERE p.risk_level IN ('high','critical') OR p.founder_decision = 'escalate'
  ORDER BY p.next_action_due ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2679_attention_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2679_attention_list() TO authenticated;

COMMIT;
