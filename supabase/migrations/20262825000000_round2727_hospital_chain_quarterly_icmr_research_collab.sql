BEGIN;

-- ============================================================
-- Round 2727: Hospital Chain Quarterly ICMR Research Collab
-- ============================================================

-- Drop existing objects
DROP FUNCTION IF EXISTS founder_icmr_collab_overview_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_projects_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_publications_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_chain_breakdown_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_data_share_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_outcomes_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_pipeline_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_top_equipment_r2727();
DROP FUNCTION IF EXISTS founder_icmr_collab_quarterly_trend_r2727();

DROP TABLE IF EXISTS icmr_research_publications_r2727;
DROP TABLE IF EXISTS icmr_research_projects_r2727;

-- ============================================================
-- Table 1: Research Projects
-- ============================================================
CREATE TABLE icmr_research_projects_r2727 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text NOT NULL CHECK (quarter IN ('Q1_2026','Q2_2026','Q3_2026','Q4_2026','Q1_2027')),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier1_metro','tier2_city','super_specialty','government')),
  project_code text NOT NULL UNIQUE,
  project_title text NOT NULL,
  icmr_protocol_id text NOT NULL,
  principal_investigator text NOT NULL,
  equipment_category text NOT NULL CHECK (equipment_category IN ('imaging','ventilator','dialysis','monitoring','surgical','laboratory')),
  equipment_count int NOT NULL CHECK (equipment_count > 0),
  data_points_shared bigint NOT NULL DEFAULT 0 CHECK (data_points_shared >= 0),
  ethics_clearance_status text NOT NULL CHECK (ethics_clearance_status IN ('pending','approved','conditional','rejected')),
  budget_inr_lakhs numeric(10,2) NOT NULL CHECK (budget_inr_lakhs >= 0),
  start_date date NOT NULL,
  expected_end_date date NOT NULL,
  status text NOT NULL CHECK (status IN ('proposed','active','data_collection','analysis','published','suspended')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE icmr_research_projects_r2727 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON icmr_research_projects_r2727
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO icmr_research_projects_r2727
  (quarter, chain_name, chain_tier, project_code, project_title, icmr_protocol_id, principal_investigator, equipment_category, equipment_count, data_points_shared, ethics_clearance_status, budget_inr_lakhs, start_date, expected_end_date, status)
VALUES
  ('Q1_2026','Apollo Health City','tier1_metro','ICMR-EQS-2727-001','Predictive Maintenance via Vibration Signatures in Cath Lab','ICMR/CARDIO/2026/044','Dr. R. Subramanian','imaging',12,184500,'approved',42.50,'2026-01-15'::date,'2026-12-20'::date,'data_collection'),
  ('Q1_2026','Manipal Hospitals','tier1_metro','ICMR-EQS-2727-002','Ventilator Utilization Patterns in ICU Surge Events','ICMR/PULMO/2026/012','Dr. Priya Menon','ventilator',38,512300,'approved',58.75,'2026-02-01'::date,'2027-01-31'::date,'active'),
  ('Q2_2026','NephroPlus Dialysis','super_specialty','ICMR-EQS-2727-003','Dialysis Membrane Wear vs Patient Outcome Correlation','ICMR/NEPH/2026/078','Dr. Anand Kapoor','dialysis',24,298700,'approved',31.20,'2026-04-10'::date,'2026-10-30'::date,'analysis'),
  ('Q2_2026','AIIMS Delhi','government','ICMR-EQS-2727-004','Multi-Parameter Monitor Alarm Fatigue Study','ICMR/CRITC/2026/091','Dr. Sanjay Verma','monitoring',56,876400,'conditional',71.00,'2026-05-20'::date,'2027-05-19'::date,'data_collection'),
  ('Q3_2026','Fortis Healthcare','tier1_metro','ICMR-EQS-2727-005','Surgical Robot Downtime Impact on OR Throughput','ICMR/SURG/2026/103','Dr. Meera Iyer','surgical',6,72300,'approved',88.40,'2026-07-05'::date,'2027-06-30'::date,'active'),
  ('Q3_2026','KIMS Hospitals','tier2_city','ICMR-EQS-2727-006','Lab Analyzer Calibration Drift in Tier-2 Cities','ICMR/PATH/2026/056','Dr. Vivek Rao','laboratory',45,634500,'approved',24.80,'2026-08-12'::date,'2026-12-15'::date,'data_collection'),
  ('Q4_2026','Yashoda Hospitals','tier2_city','ICMR-EQS-2727-007','MRI Coil Failure Prediction using Acoustic ML','ICMR/RADIO/2026/118','Dr. Lakshmi Narayan','imaging',8,142800,'pending',54.30,'2026-10-01'::date,'2027-09-30'::date,'proposed'),
  ('Q4_2026','PGIMER Chandigarh','government','ICMR-EQS-2727-008','Ventilator Hours vs COPD Readmission Outcomes','ICMR/PULMO/2026/142','Dr. Harpreet Singh','ventilator',22,389600,'approved',46.90,'2026-11-15'::date,'2027-11-14'::date,'active');

-- ============================================================
-- Table 2: Research Publications & Outcomes
-- ============================================================
CREATE TABLE icmr_research_publications_r2727 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES icmr_research_projects_r2727(id) ON DELETE CASCADE,
  publication_title text NOT NULL,
  journal_name text NOT NULL,
  impact_factor numeric(4,2) NOT NULL CHECK (impact_factor >= 0),
  publication_date date NOT NULL,
  citation_count int NOT NULL DEFAULT 0 CHECK (citation_count >= 0),
  publication_type text NOT NULL CHECK (publication_type IN ('peer_review','conference','white_paper','preprint','policy_brief')),
  outcome_summary text NOT NULL,
  equipseva_credited boolean NOT NULL DEFAULT false,
  press_coverage_count int NOT NULL DEFAULT 0 CHECK (press_coverage_count >= 0),
  follow_on_grant_inr_lakhs numeric(10,2) NOT NULL DEFAULT 0 CHECK (follow_on_grant_inr_lakhs >= 0),
  policy_impact_level text NOT NULL CHECK (policy_impact_level IN ('none','local','state','national','international')),
  status text NOT NULL CHECK (status IN ('draft','submitted','under_review','accepted','published','retracted')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE icmr_research_publications_r2727 ENABLE ROW LEVEL SECURITY;
CREATE POLICY founder_all ON icmr_research_publications_r2727
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO icmr_research_publications_r2727
  (project_id, publication_title, journal_name, impact_factor, publication_date, citation_count, publication_type, outcome_summary, equipseva_credited, press_coverage_count, follow_on_grant_inr_lakhs, policy_impact_level, status)
VALUES
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-001'),'Vibration-Signature ML reduces Cath Lab failure by 41%','Indian Heart Journal',3.20,'2026-09-15'::date,18,'peer_review','41% reduction in unplanned downtime; 6 patients deaths averted',true,7,25.00,'national','published'),
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-002'),'ICU Ventilator Surge Capacity Modeling Post-COVID','Lancet Regional Health SEA',12.40,'2026-11-08'::date,42,'peer_review','National surge framework adopted by MoHFW; 3 states piloting',true,23,75.00,'national','published'),
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-003'),'Dialyzer Membrane Lifecycle vs Kt/V Outcomes','Indian J Nephrology',2.10,'2026-10-22'::date,9,'peer_review','Membrane replacement guideline updated; ₹14L per center savings',true,4,18.50,'state','published'),
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-004'),'Alarm Fatigue: Frequency Analysis across 56 Monitors','J Critical Care India',1.80,'2026-08-30'::date,12,'conference','22% reduction in non-actionable alarms; nurse fatigue scores improved',true,2,8.00,'local','published'),
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-005'),'Robot Surgery OR Throughput: Downtime Cost Analysis','Indian J Surg',2.60,'2026-12-01'::date,5,'preprint','Each hour robot downtime costs OR ₹3.2L; preventive cycle proposed',true,1,12.00,'local','under_review'),
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-006'),'Tier-2 Lab Analyzer Drift: 45-Device Pan-India Audit','J Lab Med India',1.40,'2026-11-25'::date,3,'peer_review','Quarterly recalibration mandate proposed to NABH',true,6,15.50,'national','accepted'),
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-002'),'Ventilator Bundle Compliance: 12-Month Telugu-Belt Cohort','Indian J Anaesth',2.40,'2026-12-18'::date,1,'peer_review','Bundle compliance up 38%; VAP rates down 27%',false,0,0,'local','submitted'),
  ((SELECT id FROM icmr_research_projects_r2727 WHERE project_code='ICMR-EQS-2727-008'),'COPD Ventilator-Hours Readmission Predictor','BMJ Open Respir Res',4.10,'2026-12-20'::date,0,'preprint','First-of-kind India dataset; 14% predictive accuracy gain over GOLD',true,3,0,'national','draft');

-- ============================================================
-- RPC 1: Overview KPIs
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_overview_r2727()
RETURNS TABLE (
  total_projects int,
  active_projects int,
  total_publications int,
  published_count int,
  total_data_points_millions numeric,
  total_budget_lakhs numeric,
  total_followon_grant_lakhs numeric,
  total_citations int,
  avg_impact_factor numeric,
  equipseva_credited_pct numeric,
  national_policy_impact_count int,
  unique_chains int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM icmr_research_projects_r2727),
    (SELECT COUNT(*)::int FROM icmr_research_projects_r2727 WHERE status IN ('active','data_collection','analysis')),
    (SELECT COUNT(*)::int FROM icmr_research_publications_r2727),
    (SELECT COUNT(*)::int FROM icmr_research_publications_r2727 WHERE status='published'),
    (SELECT ROUND((COALESCE(SUM(data_points_shared),0) / 1000000.0)::numeric, 2) FROM icmr_research_projects_r2727),
    (SELECT COALESCE(SUM(budget_inr_lakhs),0) FROM icmr_research_projects_r2727),
    (SELECT COALESCE(SUM(follow_on_grant_inr_lakhs),0) FROM icmr_research_publications_r2727),
    (SELECT COALESCE(SUM(citation_count),0)::int FROM icmr_research_publications_r2727),
    (SELECT ROUND(COALESCE(AVG(impact_factor),0)::numeric, 2) FROM icmr_research_publications_r2727),
    (SELECT ROUND((COUNT(*) FILTER (WHERE equipseva_credited) * 100.0 / NULLIF(COUNT(*),0))::numeric, 1) FROM icmr_research_publications_r2727),
    (SELECT COUNT(*)::int FROM icmr_research_publications_r2727 WHERE policy_impact_level IN ('national','international')),
    (SELECT COUNT(DISTINCT chain_name)::int FROM icmr_research_projects_r2727);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_overview_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_overview_r2727() TO authenticated;

-- ============================================================
-- RPC 2: Projects list
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_projects_r2727()
RETURNS TABLE (
  project_code text,
  chain_name text,
  quarter text,
  project_title text,
  equipment_category text,
  equipment_count int,
  data_points_shared bigint,
  budget_inr_lakhs numeric,
  status text,
  ethics_clearance_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    p.project_code, p.chain_name, p.quarter, p.project_title,
    p.equipment_category, p.equipment_count, p.data_points_shared,
    p.budget_inr_lakhs, p.status, p.ethics_clearance_status
  FROM icmr_research_projects_r2727 p
  ORDER BY p.start_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_projects_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_projects_r2727() TO authenticated;

-- ============================================================
-- RPC 3: Publications list
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_publications_r2727()
RETURNS TABLE (
  publication_title text,
  journal_name text,
  impact_factor numeric,
  publication_date date,
  citation_count int,
  publication_type text,
  policy_impact_level text,
  equipseva_credited boolean,
  follow_on_grant_inr_lakhs numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    pub.publication_title, pub.journal_name, pub.impact_factor, pub.publication_date,
    pub.citation_count, pub.publication_type, pub.policy_impact_level,
    pub.equipseva_credited, pub.follow_on_grant_inr_lakhs, pub.status
  FROM icmr_research_publications_r2727 pub
  ORDER BY pub.publication_date DESC NULLS LAST;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_publications_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_publications_r2727() TO authenticated;

-- ============================================================
-- RPC 4: Chain breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_chain_breakdown_r2727()
RETURNS TABLE (
  chain_name text,
  chain_tier text,
  project_count int,
  total_equipment int,
  total_data_points bigint,
  total_budget_lakhs numeric,
  publication_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    p.chain_name,
    MAX(p.chain_tier)::text,
    COUNT(*)::int,
    COALESCE(SUM(p.equipment_count),0)::int,
    COALESCE(SUM(p.data_points_shared),0)::bigint,
    COALESCE(SUM(p.budget_inr_lakhs),0)::numeric,
    (SELECT COUNT(*)::int FROM icmr_research_publications_r2727 pub
       JOIN icmr_research_projects_r2727 pp ON pub.project_id=pp.id
       WHERE pp.chain_name=p.chain_name)
  FROM icmr_research_projects_r2727 p
  GROUP BY p.chain_name
  ORDER BY COALESCE(SUM(p.budget_inr_lakhs),0) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_chain_breakdown_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_chain_breakdown_r2727() TO authenticated;

-- ============================================================
-- RPC 5: Data share volume per quarter
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_data_share_r2727()
RETURNS TABLE (
  quarter text,
  projects int,
  data_points_millions numeric,
  budget_lakhs numeric,
  active_chains int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    p.quarter,
    COUNT(*)::int,
    ROUND((COALESCE(SUM(p.data_points_shared),0) / 1000000.0)::numeric, 2),
    COALESCE(SUM(p.budget_inr_lakhs),0)::numeric,
    COUNT(DISTINCT p.chain_name)::int
  FROM icmr_research_projects_r2727 p
  GROUP BY p.quarter
  ORDER BY p.quarter;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_data_share_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_data_share_r2727() TO authenticated;

-- ============================================================
-- RPC 6: Outcomes & policy impact
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_outcomes_r2727()
RETURNS TABLE (
  policy_impact_level text,
  publication_count int,
  total_citations int,
  total_followon_grant_lakhs numeric,
  total_press_coverage int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    pub.policy_impact_level,
    COUNT(*)::int,
    COALESCE(SUM(pub.citation_count),0)::int,
    COALESCE(SUM(pub.follow_on_grant_inr_lakhs),0)::numeric,
    COALESCE(SUM(pub.press_coverage_count),0)::int
  FROM icmr_research_publications_r2727 pub
  GROUP BY pub.policy_impact_level
  ORDER BY
    CASE pub.policy_impact_level
      WHEN 'international' THEN 1
      WHEN 'national' THEN 2
      WHEN 'state' THEN 3
      WHEN 'local' THEN 4
      ELSE 5
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_outcomes_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_outcomes_r2727() TO authenticated;

-- ============================================================
-- RPC 7: Pipeline status
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_pipeline_r2727()
RETURNS TABLE (
  status text,
  project_count int,
  total_budget_lakhs numeric,
  pct_of_portfolio numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total_count int;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT COUNT(*) INTO total_count FROM icmr_research_projects_r2727;

  RETURN QUERY
  SELECT
    p.status,
    COUNT(*)::int,
    COALESCE(SUM(p.budget_inr_lakhs),0)::numeric,
    ROUND((COUNT(*) * 100.0 / NULLIF(total_count,0))::numeric, 1)
  FROM icmr_research_projects_r2727 p
  GROUP BY p.status
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_pipeline_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_pipeline_r2727() TO authenticated;

-- ============================================================
-- RPC 8: Top equipment categories
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_top_equipment_r2727()
RETURNS TABLE (
  equipment_category text,
  project_count int,
  total_units int,
  total_data_points bigint,
  total_budget_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    p.equipment_category,
    COUNT(*)::int,
    COALESCE(SUM(p.equipment_count),0)::int,
    COALESCE(SUM(p.data_points_shared),0)::bigint,
    COALESCE(SUM(p.budget_inr_lakhs),0)::numeric
  FROM icmr_research_projects_r2727 p
  GROUP BY p.equipment_category
  ORDER BY COALESCE(SUM(p.budget_inr_lakhs),0) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_top_equipment_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_top_equipment_r2727() TO authenticated;

-- ============================================================
-- RPC 9: Quarterly trend
-- ============================================================
CREATE OR REPLACE FUNCTION founder_icmr_collab_quarterly_trend_r2727()
RETURNS TABLE (
  quarter text,
  publications int,
  citations int,
  avg_impact_factor numeric,
  followon_grant_lakhs numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    p.quarter,
    COUNT(pub.id)::int,
    COALESCE(SUM(pub.citation_count),0)::int,
    ROUND(COALESCE(AVG(pub.impact_factor),0)::numeric, 2),
    COALESCE(SUM(pub.follow_on_grant_inr_lakhs),0)::numeric
  FROM icmr_research_projects_r2727 p
  LEFT JOIN icmr_research_publications_r2727 pub ON pub.project_id=p.id
  GROUP BY p.quarter
  ORDER BY p.quarter;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_icmr_collab_quarterly_trend_r2727() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_icmr_collab_quarterly_trend_r2727() TO authenticated;

COMMIT;
