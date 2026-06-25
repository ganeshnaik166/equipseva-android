BEGIN;

CREATE TABLE IF NOT EXISTS hospital_chain_research_collaborations_r2759 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  research_title text NOT NULL,
  research_domain text NOT NULL CHECK (research_domain IN ('imaging_ai','sterilization','predictive_maintenance','infection_control','workflow_optimization','device_safety')),
  our_role text NOT NULL CHECK (our_role IN ('data_provider','co_investigator','principal_site','tech_platform','co_author')),
  publication_target text NOT NULL,
  ip_arrangement text NOT NULL CHECK (ip_arrangement IN ('co_owned','licensed_back','assigned_to_chain','assigned_to_us','open_source')),
  strategic_value text NOT NULL CHECK (strategic_value IN ('flagship','high','medium','low')),
  quarter text NOT NULL,
  budget_lakhs numeric(10,2) NOT NULL,
  status text NOT NULL CHECK (status IN ('proposed','active','data_collection','analysis','published','blocked')),
  expected_publication_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_research_collaborations_r2759 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_research_collaborations_r2759;
CREATE POLICY founder_all ON hospital_chain_research_collaborations_r2759 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_research_milestones_r2759 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  collaboration_id uuid NOT NULL REFERENCES hospital_chain_research_collaborations_r2759(id) ON DELETE CASCADE,
  milestone_label text NOT NULL,
  milestone_type text NOT NULL CHECK (milestone_type IN ('protocol','irb_approval','data_lock','analysis','draft','submission','acceptance','publication')),
  due_date date NOT NULL,
  completed_at timestamptz,
  status text NOT NULL CHECK (status IN ('pending','in_progress','done','at_risk','missed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_research_milestones_r2759 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_research_milestones_r2759;
CREATE POLICY founder_all ON hospital_chain_research_milestones_r2759 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO hospital_chain_research_collaborations_r2759 (id, chain_name, research_title, research_domain, our_role, publication_target, ip_arrangement, strategic_value, quarter, budget_lakhs, status, expected_publication_date) VALUES
  ('11111111-1111-1111-1111-111111111111','Apollo Hospitals','AI-Driven Predictive Maintenance for CT Scanners','predictive_maintenance','tech_platform','Journal of Medical Imaging','co_owned','flagship','2026-Q3',45.00,'data_collection','2026-12-15'::date),
  ('22222222-2222-2222-2222-222222222222','Manipal Health','Autoclave Cycle Optimization in High-Volume OTs','sterilization','co_investigator','American Journal of Infection Control','co_owned','high','2026-Q3',22.50,'analysis','2026-11-30'::date),
  ('33333333-3333-3333-3333-333333333333','Fortis Healthcare','Imaging Device Downtime vs Patient Outcomes','workflow_optimization','principal_site','BMJ Quality & Safety','assigned_to_us','flagship','2026-Q4',38.00,'active','2027-02-28'::date),
  ('44444444-4444-4444-4444-444444444444','Max Healthcare','HEPA Filter Failure Patterns in ICU','infection_control','data_provider','Indian Journal of Critical Care','licensed_back','medium','2026-Q3',12.00,'proposed','2027-01-15'::date),
  ('55555555-5555-5555-5555-555555555555','Narayana Health','Device-Recall Surveillance Pipeline','device_safety','co_author','Lancet Digital Health','co_owned','flagship','2026-Q4',55.00,'active','2027-03-30'::date),
  ('66666666-6666-6666-6666-666666666666','KIMS Hospitals','Ventilator Calibration Drift Study','device_safety','tech_platform','Anesthesia & Analgesia','assigned_to_chain','high','2026-Q3',18.00,'data_collection','2026-12-20'::date);

INSERT INTO hospital_chain_research_milestones_r2759 (collaboration_id, milestone_label, milestone_type, due_date, completed_at, status, notes) VALUES
  ('11111111-1111-1111-1111-111111111111','Protocol finalized','protocol','2026-05-15'::date, '2026-05-12 10:00:00+05:30','done','Apollo CTO signed off'),
  ('11111111-1111-1111-1111-111111111111','IRB approval','irb_approval','2026-06-30'::date, '2026-06-22 14:00:00+05:30','done','Multi-site nod across 8 units'),
  ('22222222-2222-2222-2222-222222222222','Data lock','data_lock','2026-07-15'::date, NULL,'in_progress','Pulling autoclave logs from 4 sites'),
  ('33333333-3333-3333-3333-333333333333','Draft manuscript','draft','2026-09-30'::date, NULL,'pending','First-pass owned by Dr Iyer'),
  ('44444444-4444-4444-4444-444444444444','Protocol','protocol','2026-07-20'::date, NULL,'at_risk','Max legal review delayed two weeks'),
  ('55555555-5555-5555-5555-555555555555','Submission','submission','2026-12-15'::date, NULL,'in_progress','Lancet pre-submission inquiry positive'),
  ('66666666-6666-6666-6666-666666666666','Analysis complete','analysis','2026-09-10'::date, NULL,'pending','Awaiting calibration cohort');

DROP FUNCTION IF EXISTS founder_r2759_overview();
CREATE OR REPLACE FUNCTION founder_r2759_overview()
RETURNS TABLE(total_collabs int, active_collabs int, flagship_collabs int, total_budget_lakhs numeric, publications_pending int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status IN ('active','data_collection','analysis'))::int,
    COUNT(*) FILTER (WHERE strategic_value = 'flagship')::int,
    COALESCE(SUM(budget_lakhs),0)::numeric,
    COUNT(*) FILTER (WHERE status <> 'published')::int
  FROM hospital_chain_research_collaborations_r2759;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2759_collaborations();
CREATE OR REPLACE FUNCTION founder_r2759_collaborations()
RETURNS SETOF hospital_chain_research_collaborations_r2759
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM hospital_chain_research_collaborations_r2759 ORDER BY strategic_value, quarter DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_collaborations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_collaborations() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2759_by_domain();
CREATE OR REPLACE FUNCTION founder_r2759_by_domain()
RETURNS TABLE(research_domain text, collab_count int, total_budget numeric, flagship_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    c.research_domain,
    COUNT(*)::int,
    COALESCE(SUM(c.budget_lakhs),0)::numeric,
    COUNT(*) FILTER (WHERE c.strategic_value = 'flagship')::int
  FROM hospital_chain_research_collaborations_r2759 c
  GROUP BY c.research_domain
  ORDER BY 3 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_by_domain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_by_domain() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2759_by_chain();
CREATE OR REPLACE FUNCTION founder_r2759_by_chain()
RETURNS TABLE(chain_name text, collab_count int, total_budget numeric, our_lead_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    c.chain_name,
    COUNT(*)::int,
    COALESCE(SUM(c.budget_lakhs),0)::numeric,
    COUNT(*) FILTER (WHERE c.our_role IN ('principal_site','co_author','tech_platform'))::int
  FROM hospital_chain_research_collaborations_r2759 c
  GROUP BY c.chain_name
  ORDER BY 3 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2759_ip_mix();
CREATE OR REPLACE FUNCTION founder_r2759_ip_mix()
RETURNS TABLE(ip_arrangement text, collab_count int, total_budget numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    c.ip_arrangement,
    COUNT(*)::int,
    COALESCE(SUM(c.budget_lakhs),0)::numeric
  FROM hospital_chain_research_collaborations_r2759 c
  GROUP BY c.ip_arrangement
  ORDER BY 2 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_ip_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_ip_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2759_at_risk_milestones();
CREATE OR REPLACE FUNCTION founder_r2759_at_risk_milestones()
RETURNS TABLE(chain_name text, research_title text, milestone_label text, milestone_type text, due_date date, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    c.chain_name, c.research_title, m.milestone_label, m.milestone_type, m.due_date, m.status, m.notes
  FROM hospital_chain_research_milestones_r2759 m
  JOIN hospital_chain_research_collaborations_r2759 c ON c.id = m.collaboration_id
  WHERE m.status IN ('at_risk','missed','pending','in_progress')
  ORDER BY m.due_date ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_at_risk_milestones() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_at_risk_milestones() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2759_publication_pipeline();
CREATE OR REPLACE FUNCTION founder_r2759_publication_pipeline()
RETURNS TABLE(chain_name text, research_title text, publication_target text, expected_publication_date date, status text, strategic_value text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    c.chain_name, c.research_title, c.publication_target, c.expected_publication_date, c.status, c.strategic_value
  FROM hospital_chain_research_collaborations_r2759 c
  WHERE c.status <> 'published'
  ORDER BY c.expected_publication_date ASC NULLS LAST;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_publication_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_publication_pipeline() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2759_strategic_value_summary();
CREATE OR REPLACE FUNCTION founder_r2759_strategic_value_summary()
RETURNS TABLE(strategic_value text, collab_count int, total_budget numeric, flagship_publications int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    c.strategic_value,
    COUNT(*)::int,
    COALESCE(SUM(c.budget_lakhs),0)::numeric,
    COUNT(*) FILTER (WHERE c.publication_target ILIKE ANY (ARRAY['%lancet%','%bmj%','%journal%']))::int
  FROM hospital_chain_research_collaborations_r2759 c
  GROUP BY c.strategic_value
  ORDER BY 2 DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2759_strategic_value_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2759_strategic_value_summary() TO authenticated;

COMMIT;
