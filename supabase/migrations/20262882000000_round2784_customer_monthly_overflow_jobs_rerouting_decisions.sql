BEGIN;

-- =========================================================================
-- Round 2784 — Customer Monthly Overflow Jobs Rerouting Decisions
-- HEAVY ★★★★ founder console
-- =========================================================================

CREATE TABLE IF NOT EXISTS overflow_reroute_jobs_r2784 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_org_id uuid,
  customer_name text NOT NULL,
  job_ref text NOT NULL,
  job_type text NOT NULL CHECK (job_type IN ('repair','maintenance','install','amc_visit','calibration')),
  primary_engineer_id uuid,
  primary_engineer_name text NOT NULL,
  primary_load_pct int NOT NULL CHECK (primary_load_pct BETWEEN 0 AND 200),
  overflow_reason text NOT NULL CHECK (overflow_reason IN ('over_capacity','leave','sla_risk','skill_gap','geo_distance','priority_bump')),
  reroute_engineer_id uuid,
  reroute_engineer_name text,
  reroute_decision text NOT NULL CHECK (reroute_decision IN ('approved','declined','pending','auto_routed','escalated')),
  decision_by_role text NOT NULL CHECK (decision_by_role IN ('founder','ops_lead','dispatch','auto_router')),
  outcome text NOT NULL CHECK (outcome IN ('completed_on_time','completed_late','rescheduled','cancelled','in_progress')),
  cost_delta_rupees numeric(12,2) NOT NULL DEFAULT 0,
  refine_action text NOT NULL CHECK (refine_action IN ('tighten_rules','expand_pool','no_change','retrain_engineer','hire_more','geo_rebalance')),
  decided_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS overflow_reroute_refinements_r2784 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  refinement_label text NOT NULL,
  rule_category text NOT NULL CHECK (rule_category IN ('capacity','geo','skill','sla','escalation','cost')),
  before_overflow_pct numeric(5,2) NOT NULL,
  after_overflow_pct numeric(5,2) NOT NULL,
  jobs_impacted int NOT NULL CHECK (jobs_impacted >= 0),
  cost_saved_rupees numeric(12,2) NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('proposed','active','rolled_back','observing')),
  owner text NOT NULL,
  effective_from date NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE overflow_reroute_jobs_r2784 ENABLE ROW LEVEL SECURITY;
ALTER TABLE overflow_reroute_refinements_r2784 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON overflow_reroute_jobs_r2784
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE POLICY founder_all ON overflow_reroute_refinements_r2784
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- =========================================================================
-- SEED DATA
-- =========================================================================

INSERT INTO overflow_reroute_jobs_r2784
  (customer_name, job_ref, job_type, primary_engineer_name, primary_load_pct,
   overflow_reason, reroute_engineer_name, reroute_decision, decision_by_role,
   outcome, cost_delta_rupees, refine_action, decided_on)
VALUES
  ('Apollo Hyderabad','JOB-2784-A1','repair','Ravi Kumar',145,'over_capacity','Suresh Naik','approved','ops_lead','completed_on_time',850.00,'expand_pool','2026-06-01'::date),
  ('Yashoda Secunderabad','JOB-2784-A2','maintenance','Priya Sharma',128,'sla_risk','Arjun Reddy','auto_routed','auto_router','completed_on_time',420.00,'no_change','2026-06-03'::date),
  ('KIMS Kondapur','JOB-2784-A3','install','Venkat Rao',110,'skill_gap','Mohan Das','approved','founder','completed_late',1250.00,'retrain_engineer','2026-06-05'::date),
  ('Care Banjara','JOB-2784-A4','amc_visit','Lakshmi Devi',102,'geo_distance','Kiran Babu','declined','dispatch','rescheduled',-200.00,'geo_rebalance','2026-06-07'::date),
  ('Continental Gachibowli','JOB-2784-A5','calibration','Naga Raju',155,'priority_bump','Suresh Naik','escalated','founder','completed_on_time',2100.00,'hire_more','2026-06-09'::date),
  ('Star Begumpet','JOB-2784-A6','repair','Ravi Kumar',132,'over_capacity','Mohan Das','approved','ops_lead','in_progress',680.00,'tighten_rules','2026-06-11'::date),
  ('Sunshine Paradise','JOB-2784-A7','maintenance','Priya Sharma',98,'leave','Arjun Reddy','auto_routed','auto_router','completed_on_time',350.00,'no_change','2026-06-13'::date);

INSERT INTO overflow_reroute_refinements_r2784
  (refinement_label, rule_category, before_overflow_pct, after_overflow_pct,
   jobs_impacted, cost_saved_rupees, status, owner, effective_from, notes)
VALUES
  ('Capacity ceiling lowered to 110%','capacity',24.50,14.20,42,18400.00,'active','Founder','2026-06-02'::date,'Trigger earlier reroute before overload'),
  ('Geo rebalance west-zone pool','geo',18.30,9.80,28,9200.00,'active','Ops Lead','2026-06-04'::date,'Added 3 engineers to Gachibowli ring'),
  ('Skill-gap auto-route to senior','skill',12.10,5.40,18,6700.00,'observing','Dispatch','2026-06-06'::date,'Tier-3 calibration always routes to L4'),
  ('SLA breach escalation T-2h','sla',8.90,4.10,22,11200.00,'active','Founder','2026-06-08'::date,'Pre-emptive escalation 2h before SLA'),
  ('Cost-cap on reroute premium','cost',6.50,6.50,0,0.00,'proposed','Founder','2026-06-15'::date,'Cap reroute cost-delta at 2000 per job'),
  ('Auto-escalate after 2 declines','escalation',15.40,7.20,31,4800.00,'active','Ops Lead','2026-06-10'::date,'Founder paged on 3rd decline');

-- =========================================================================
-- RPC 1 — KPI summary
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_kpis();
CREATE OR REPLACE FUNCTION founder_overflow_r2784_kpis()
RETURNS TABLE (
  total_jobs int,
  approved_jobs int,
  auto_routed_jobs int,
  escalated_jobs int,
  avg_cost_delta numeric,
  total_cost_delta numeric,
  pct_on_time numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE reroute_decision = 'approved')::int,
    COUNT(*) FILTER (WHERE reroute_decision = 'auto_routed')::int,
    COUNT(*) FILTER (WHERE reroute_decision = 'escalated')::int,
    COALESCE(ROUND(AVG(cost_delta_rupees)::numeric, 2), 0),
    COALESCE(SUM(cost_delta_rupees), 0),
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE outcome = 'completed_on_time') / COUNT(*), 1)
    END
  FROM overflow_reroute_jobs_r2784;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_kpis() TO authenticated;

-- =========================================================================
-- RPC 2 — list jobs
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_jobs();
CREATE OR REPLACE FUNCTION founder_overflow_r2784_jobs()
RETURNS TABLE (
  id uuid,
  customer_name text,
  job_ref text,
  job_type text,
  primary_engineer_name text,
  primary_load_pct int,
  overflow_reason text,
  reroute_engineer_name text,
  reroute_decision text,
  outcome text,
  cost_delta_rupees numeric,
  refine_action text,
  decided_on date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.id, j.customer_name, j.job_ref, j.job_type,
         j.primary_engineer_name, j.primary_load_pct, j.overflow_reason,
         j.reroute_engineer_name, j.reroute_decision, j.outcome,
         j.cost_delta_rupees, j.refine_action, j.decided_on
  FROM overflow_reroute_jobs_r2784 j
  ORDER BY j.decided_on DESC, j.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_jobs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_jobs() TO authenticated;

-- =========================================================================
-- RPC 3 — reason breakdown
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_reasons();
CREATE OR REPLACE FUNCTION founder_overflow_r2784_reasons()
RETURNS TABLE (
  overflow_reason text,
  job_count int,
  avg_cost_delta numeric,
  on_time_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.overflow_reason,
         COUNT(*)::int,
         ROUND(AVG(j.cost_delta_rupees)::numeric, 2),
         ROUND(100.0 * COUNT(*) FILTER (WHERE j.outcome = 'completed_on_time') / COUNT(*), 1)
  FROM overflow_reroute_jobs_r2784 j
  GROUP BY j.overflow_reason
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_reasons() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_reasons() TO authenticated;

-- =========================================================================
-- RPC 4 — engineer load
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_engineer_load();
CREATE OR REPLACE FUNCTION founder_overflow_r2784_engineer_load()
RETURNS TABLE (
  primary_engineer_name text,
  job_count int,
  avg_load_pct numeric,
  total_cost_delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.primary_engineer_name,
         COUNT(*)::int,
         ROUND(AVG(j.primary_load_pct)::numeric, 1),
         COALESCE(SUM(j.cost_delta_rupees), 0)
  FROM overflow_reroute_jobs_r2784 j
  GROUP BY j.primary_engineer_name
  ORDER BY AVG(j.primary_load_pct) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_engineer_load() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_engineer_load() TO authenticated;

-- =========================================================================
-- RPC 5 — refinements list
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_refinements();
CREATE OR REPLACE FUNCTION founder_overflow_r2784_refinements()
RETURNS TABLE (
  id uuid,
  refinement_label text,
  rule_category text,
  before_overflow_pct numeric,
  after_overflow_pct numeric,
  delta_pct numeric,
  jobs_impacted int,
  cost_saved_rupees numeric,
  status text,
  owner text,
  effective_from date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.refinement_label, r.rule_category,
         r.before_overflow_pct, r.after_overflow_pct,
         ROUND((r.before_overflow_pct - r.after_overflow_pct)::numeric, 2),
         r.jobs_impacted, r.cost_saved_rupees,
         r.status, r.owner, r.effective_from
  FROM overflow_reroute_refinements_r2784 r
  ORDER BY (r.before_overflow_pct - r.after_overflow_pct) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_refinements() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_refinements() TO authenticated;

-- =========================================================================
-- RPC 6 — outcome breakdown
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_outcomes();
CREATE OR REPLACE FUNCTION founder_overflow_r2784_outcomes()
RETURNS TABLE (
  outcome text,
  job_count int,
  total_cost_delta numeric,
  pct_share numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total_jobs int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_jobs FROM overflow_reroute_jobs_r2784;
  RETURN QUERY
  SELECT j.outcome,
         COUNT(*)::int,
         COALESCE(SUM(j.cost_delta_rupees), 0),
         CASE WHEN total_jobs = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) / total_jobs, 1) END
  FROM overflow_reroute_jobs_r2784 j
  GROUP BY j.outcome
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_outcomes() TO authenticated;

-- =========================================================================
-- RPC 7 — refine action recommendation
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_refine_actions();
CREATE OR REPLACE FUNCTION founder_overflow_r2784_refine_actions()
RETURNS TABLE (
  refine_action text,
  job_count int,
  total_cost_delta numeric,
  avg_load_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT j.refine_action,
         COUNT(*)::int,
         COALESCE(SUM(j.cost_delta_rupees), 0),
         ROUND(AVG(j.primary_load_pct)::numeric, 1)
  FROM overflow_reroute_jobs_r2784 j
  GROUP BY j.refine_action
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_refine_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_refine_actions() TO authenticated;

-- =========================================================================
-- RPC 8 — record a new reroute decision (VOLATILE)
-- =========================================================================
DROP FUNCTION IF EXISTS founder_overflow_r2784_record_decision(text, text, text, text, int, text, text, text, text, text, numeric, text);
CREATE OR REPLACE FUNCTION founder_overflow_r2784_record_decision(
  p_customer_name text,
  p_job_ref text,
  p_job_type text,
  p_primary_engineer_name text,
  p_primary_load_pct int,
  p_overflow_reason text,
  p_reroute_engineer_name text,
  p_reroute_decision text,
  p_decision_by_role text,
  p_outcome text,
  p_cost_delta_rupees numeric,
  p_refine_action text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO overflow_reroute_jobs_r2784
    (customer_name, job_ref, job_type, primary_engineer_name, primary_load_pct,
     overflow_reason, reroute_engineer_name, reroute_decision, decision_by_role,
     outcome, cost_delta_rupees, refine_action, decided_on)
  VALUES
    (p_customer_name, p_job_ref, p_job_type, p_primary_engineer_name, p_primary_load_pct,
     p_overflow_reason, p_reroute_engineer_name, p_reroute_decision, p_decision_by_role,
     p_outcome, p_cost_delta_rupees, p_refine_action, CURRENT_DATE)
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_overflow_r2784_record_decision(text, text, text, text, int, text, text, text, text, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_overflow_r2784_record_decision(text, text, text, text, int, text, text, text, text, text, numeric, text) TO authenticated;

COMMIT;
