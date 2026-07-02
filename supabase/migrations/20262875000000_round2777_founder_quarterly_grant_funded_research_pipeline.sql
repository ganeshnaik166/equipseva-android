BEGIN;

CREATE TABLE IF NOT EXISTS grant_research_projects_r2777 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_code text NOT NULL UNIQUE,
  grant_agency text NOT NULL,
  grant_program text NOT NULL,
  research_topic text NOT NULL,
  institution_name text NOT NULL,
  institution_tier text NOT NULL CHECK (institution_tier IN ('tier1_iit','tier1_aiims','tier2_nit','tier3_state','industry_lab')),
  stage text NOT NULL CHECK (stage IN ('proposal','approved','active','field_pilot','publication','commercialization')),
  award_amount_rupees bigint NOT NULL CHECK (award_amount_rupees >= 0),
  disbursed_rupees bigint NOT NULL DEFAULT 0 CHECK (disbursed_rupees >= 0),
  projected_revenue_rupees bigint NOT NULL DEFAULT 0 CHECK (projected_revenue_rupees >= 0),
  strategic_value text NOT NULL CHECK (strategic_value IN ('low','medium','high','flagship')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  pi_name text NOT NULL,
  pi_email text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE grant_research_projects_r2777 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON grant_research_projects_r2777;
CREATE POLICY founder_all ON grant_research_projects_r2777 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS grant_research_milestones_r2777 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES grant_research_projects_r2777(id) ON DELETE CASCADE,
  milestone_name text NOT NULL,
  milestone_quarter text NOT NULL,
  due_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('planned','in_progress','completed','delayed','at_risk')),
  deliverable_type text NOT NULL CHECK (deliverable_type IN ('prototype','paper','dataset','pilot_report','field_deployment','ip_filing')),
  tranche_rupees bigint NOT NULL DEFAULT 0 CHECK (tranche_rupees >= 0),
  completion_pct integer NOT NULL DEFAULT 0 CHECK (completion_pct >= 0 AND completion_pct <= 100),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE grant_research_milestones_r2777 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON grant_research_milestones_r2777;
CREATE POLICY founder_all ON grant_research_milestones_r2777 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO grant_research_projects_r2777 (project_code, grant_agency, grant_program, research_topic, institution_name, institution_tier, stage, award_amount_rupees, disbursed_rupees, projected_revenue_rupees, strategic_value, start_date, end_date, pi_name, pi_email, notes) VALUES
  ('GR-2026-Q1-001','DST-SERB','IMPRINT-2C','Low-cost ventilator field diagnostics','IIT Hyderabad','tier1_iit','active',8500000,4250000,32000000,'flagship','2026-01-15'::date,'2027-06-30'::date,'Dr Anil Kumar','anil.k@iith.ac.in','Co-funded with MoHFW; field pilot Q3'),
  ('GR-2026-Q1-002','BIRAC','BIG-Grant','Predictive HVAC failure ML for hospitals','AIIMS Delhi','tier1_aiims','field_pilot',6200000,5500000,18500000,'high','2026-02-01'::date,'2026-12-15'::date,'Dr Meera Sharma','meera.s@aiims.edu','Deployed at 4 AIIMS sites'),
  ('GR-2026-Q1-003','DBT','BIPP','Bonded spare parts blockchain provenance','NIT Warangal','tier2_nit','approved',4800000,1200000,22000000,'high','2026-03-10'::date,'2027-09-30'::date,'Dr Ravi Teja','ravi.t@nitw.ac.in','Tranche 1 disbursed; IP filing pending'),
  ('GR-2026-Q1-004','MeitY','TIDE-2.0','Edge AI for diagnostic equipment uptime','IIIT Bangalore','tier3_state','proposal',3500000,0,12000000,'medium','2026-07-01'::date,'2027-12-31'::date,'Dr Suresh Iyer','suresh.i@iiitb.ac.in','Awaiting EC approval'),
  ('GR-2026-Q1-005','ICMR','Adhoc-Grant','NABH compliance automation engine','PGIMER Chandigarh','tier1_aiims','publication',5400000,5400000,16000000,'high','2025-10-01'::date,'2026-09-30'::date,'Dr Kavita Rao','kavita.r@pgimer.edu','3 papers under review at Lancet Digital Health'),
  ('GR-2026-Q1-006','DST-SERB','SUPRA','Engineer skill ladder gamification research','IIT Bombay','tier1_iit','commercialization',7200000,7200000,28500000,'flagship','2025-04-15'::date,'2026-06-30'::date,'Dr Pradeep Joshi','pradeep.j@iitb.ac.in','Productized into v0.5 engineer app');

INSERT INTO grant_research_milestones_r2777 (project_id, milestone_name, milestone_quarter, due_date, status, deliverable_type, tranche_rupees, completion_pct, notes)
SELECT id, 'Field prototype v1','2026-Q2','2026-06-30'::date,'completed','prototype',2125000,100,'Tested at 3 sites' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-001'
UNION ALL
SELECT id, 'Clinical validation paper','2026-Q3','2026-09-15'::date,'in_progress','paper',2125000,60,'Drafting underway' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-001'
UNION ALL
SELECT id, 'AIIMS multi-site pilot','2026-Q2','2026-06-20'::date,'completed','field_deployment',2750000,100,'4 sites live' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-002'
UNION ALL
SELECT id, 'Failure prediction dataset','2026-Q3','2026-09-30'::date,'at_risk','dataset',2750000,40,'Data labelling delayed' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-002'
UNION ALL
SELECT id, 'Provenance smart contract','2026-Q3','2026-08-15'::date,'in_progress','prototype',1200000,55,'Polygon testnet live' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-003'
UNION ALL
SELECT id, 'Patent provisional filing','2026-Q4','2026-11-30'::date,'planned','ip_filing',1200000,10,'Drafted by attorneys' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-003'
UNION ALL
SELECT id, 'NABH automation engine paper','2026-Q1','2026-03-31'::date,'completed','paper',1800000,100,'Accepted Lancet Digital Health' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-005'
UNION ALL
SELECT id, 'Engineer ladder field study','2026-Q1','2026-02-28'::date,'completed','pilot_report',2400000,100,'600 engineers surveyed' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-006'
UNION ALL
SELECT id, 'Commercialization MoU','2026-Q2','2026-06-15'::date,'completed','field_deployment',2400000,100,'Signed with Equipseva v0.5' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-006'
UNION ALL
SELECT id, 'Edge AI proposal review','2026-Q3','2026-09-01'::date,'planned','prototype',0,0,'Awaiting MeitY EC' FROM grant_research_projects_r2777 WHERE project_code = 'GR-2026-Q1-004';

DROP FUNCTION IF EXISTS founder_r2777_pipeline_summary();
CREATE OR REPLACE FUNCTION founder_r2777_pipeline_summary()
RETURNS TABLE(total_projects bigint, total_award_rupees bigint, total_disbursed_rupees bigint, total_projected_revenue_rupees bigint, flagship_projects bigint, active_projects bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint,
           COALESCE(SUM(award_amount_rupees),0)::bigint,
           COALESCE(SUM(disbursed_rupees),0)::bigint,
           COALESCE(SUM(projected_revenue_rupees),0)::bigint,
           COUNT(*) FILTER (WHERE strategic_value = 'flagship')::bigint,
           COUNT(*) FILTER (WHERE stage IN ('active','field_pilot'))::bigint
    FROM grant_research_projects_r2777;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_pipeline_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_pipeline_summary() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2777_projects_by_stage();
CREATE OR REPLACE FUNCTION founder_r2777_projects_by_stage()
RETURNS TABLE(stage text, project_count bigint, total_award bigint, total_projected_revenue bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.stage, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint, COALESCE(SUM(p.projected_revenue_rupees),0)::bigint
    FROM grant_research_projects_r2777 p
    GROUP BY p.stage
    ORDER BY total_award DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_projects_by_stage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_projects_by_stage() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2777_top_projects();
CREATE OR REPLACE FUNCTION founder_r2777_top_projects()
RETURNS TABLE(project_code text, research_topic text, institution_name text, stage text, award_amount_rupees bigint, projected_revenue_rupees bigint, strategic_value text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.project_code, p.research_topic, p.institution_name, p.stage, p.award_amount_rupees, p.projected_revenue_rupees, p.strategic_value
    FROM grant_research_projects_r2777 p
    ORDER BY p.projected_revenue_rupees DESC, p.award_amount_rupees DESC
    LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_top_projects() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_top_projects() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2777_agency_breakdown();
CREATE OR REPLACE FUNCTION founder_r2777_agency_breakdown()
RETURNS TABLE(grant_agency text, project_count bigint, total_award bigint, total_disbursed bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.grant_agency, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint, COALESCE(SUM(p.disbursed_rupees),0)::bigint
    FROM grant_research_projects_r2777 p
    GROUP BY p.grant_agency
    ORDER BY total_award DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_agency_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_agency_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2777_institution_tier_rollup();
CREATE OR REPLACE FUNCTION founder_r2777_institution_tier_rollup()
RETURNS TABLE(institution_tier text, project_count bigint, total_award bigint, flagship_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.institution_tier, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint,
           COUNT(*) FILTER (WHERE p.strategic_value = 'flagship')::bigint
    FROM grant_research_projects_r2777 p
    GROUP BY p.institution_tier
    ORDER BY total_award DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_institution_tier_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_institution_tier_rollup() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2777_milestones_at_risk();
CREATE OR REPLACE FUNCTION founder_r2777_milestones_at_risk()
RETURNS TABLE(project_code text, milestone_name text, milestone_quarter text, due_date date, status text, completion_pct integer, tranche_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.project_code, m.milestone_name, m.milestone_quarter, m.due_date, m.status, m.completion_pct, m.tranche_rupees
    FROM grant_research_milestones_r2777 m
    JOIN grant_research_projects_r2777 p ON p.id = m.project_id
    WHERE m.status IN ('at_risk','delayed')
    ORDER BY m.due_date ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_milestones_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_milestones_at_risk() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2777_quarterly_tranche_view();
CREATE OR REPLACE FUNCTION founder_r2777_quarterly_tranche_view()
RETURNS TABLE(milestone_quarter text, milestone_count bigint, total_tranche_rupees bigint, completed_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.milestone_quarter, COUNT(*)::bigint, COALESCE(SUM(m.tranche_rupees),0)::bigint,
           COUNT(*) FILTER (WHERE m.status = 'completed')::bigint
    FROM grant_research_milestones_r2777 m
    GROUP BY m.milestone_quarter
    ORDER BY m.milestone_quarter ASC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_quarterly_tranche_view() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_quarterly_tranche_view() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2777_strategic_value_rollup();
CREATE OR REPLACE FUNCTION founder_r2777_strategic_value_rollup()
RETURNS TABLE(strategic_value text, project_count bigint, total_award bigint, total_projected_revenue bigint, revenue_multiple numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.strategic_value, COUNT(*)::bigint, COALESCE(SUM(p.award_amount_rupees),0)::bigint, COALESCE(SUM(p.projected_revenue_rupees),0)::bigint,
           CASE WHEN COALESCE(SUM(p.award_amount_rupees),0) = 0 THEN 0::numeric
                ELSE ROUND(SUM(p.projected_revenue_rupees)::numeric / SUM(p.award_amount_rupees)::numeric, 2) END
    FROM grant_research_projects_r2777 p
    GROUP BY p.strategic_value
    ORDER BY total_projected_revenue DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_r2777_strategic_value_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2777_strategic_value_rollup() TO authenticated;

COMMIT;