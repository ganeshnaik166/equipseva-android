BEGIN;

-- Round r2779 — Hospital Chain Quarterly Quality Accreditation Prep
-- Tracks accreditation readiness across hospital chains by phase, our prep status, gaps, actions, verdict

CREATE TABLE IF NOT EXISTS hospital_chain_accreditation_prep_r2779 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  accreditation_body text NOT NULL CHECK (accreditation_body IN ('nabh','jci','iso_9001','iso_15189','nabl','aerb','cap')),
  phase text NOT NULL CHECK (phase IN ('document_review','self_assessment','pre_assessment','final_assessment','closure','surveillance')),
  cycle_quarter text NOT NULL CHECK (cycle_quarter IN ('q1_2026','q2_2026','q3_2026','q4_2026','q1_2027')),
  sites_in_scope int NOT NULL CHECK (sites_in_scope >= 0),
  our_prep_pct numeric(5,2) NOT NULL CHECK (our_prep_pct >= 0 AND our_prep_pct <= 100),
  open_gaps int NOT NULL CHECK (open_gaps >= 0),
  critical_action text NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('on_track','at_risk','blocked','recovered','passed','failed')),
  assessor_visit_on date,
  responsible_owner text NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_accreditation_prep_r2779 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_accreditation_prep_r2779;
CREATE POLICY founder_all ON hospital_chain_accreditation_prep_r2779 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_accreditation_gap_action_r2779 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prep_id uuid REFERENCES hospital_chain_accreditation_prep_r2779(id) ON DELETE CASCADE,
  chain_name text NOT NULL,
  gap_area text NOT NULL CHECK (gap_area IN ('equipment_calibration','preventive_maintenance','spare_parts_traceability','biomedical_engineer_credentials','documentation','training_logs','incident_response','sterilization_records')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  evidence_required text NOT NULL,
  evidence_supplied_pct numeric(5,2) NOT NULL CHECK (evidence_supplied_pct >= 0 AND evidence_supplied_pct <= 100),
  action_owner text NOT NULL,
  due_on date NOT NULL,
  status text NOT NULL CHECK (status IN ('not_started','in_progress','submitted','accepted','rejected')),
  blocker_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_accreditation_gap_action_r2779 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_accreditation_gap_action_r2779;
CREATE POLICY founder_all ON hospital_chain_accreditation_gap_action_r2779 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed prep rows
INSERT INTO hospital_chain_accreditation_prep_r2779 (chain_name, accreditation_body, phase, cycle_quarter, sites_in_scope, our_prep_pct, open_gaps, critical_action, verdict, assessor_visit_on, responsible_owner, notes) VALUES
('Apollo Hospitals', 'nabh', 'final_assessment', 'q3_2026', 12, 92.50, 3, 'Close 3 PM logs for ventilators in CCU', 'on_track', '2026-09-15'::date, 'Dr. Mehta', '8 sites cleared self-assessment'),
('Manipal Hospitals', 'jci', 'pre_assessment', 'q4_2026', 9, 76.00, 11, 'Calibration certs for infusion pumps missing', 'at_risk', '2026-11-22'::date, 'Anita Rao', 'JCI surveyor expected on-site'),
('Fortis Healthcare', 'nabh', 'document_review', 'q2_2026', 16, 64.20, 18, 'Engineer credentials not uploaded for 4 sites', 'blocked', '2026-08-10'::date, 'Suresh Kumar', 'Awaiting CV upload by Phyllo engineers'),
('Max Healthcare', 'iso_9001', 'closure', 'q1_2026', 7, 100.00, 0, 'Closure letter signed', 'passed', '2026-03-04'::date, 'Priya N.', 'Surveillance audit Q3-2026'),
('Yashoda Hospitals', 'nabl', 'self_assessment', 'q3_2026', 5, 81.40, 5, 'Lab equipment annual cal pending', 'on_track', '2026-09-28'::date, 'Vikram Singh', 'Hyderabad cluster'),
('AIIMS Network', 'aerb', 'final_assessment', 'q4_2026', 22, 58.90, 27, 'AERB radiation safety logs incomplete', 'at_risk', '2026-12-05'::date, 'Dr. Banerjee', 'High-stakes — govt visibility'),
('Narayana Health', 'cap', 'surveillance', 'q2_2026', 6, 95.10, 1, 'Annual peer review submission', 'recovered', '2026-07-20'::date, 'Latha M.', 'Recovered from Q1 minor finding');

INSERT INTO hospital_chain_accreditation_gap_action_r2779 (prep_id, chain_name, gap_area, severity, evidence_required, evidence_supplied_pct, action_owner, due_on, status, blocker_note) VALUES
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='Apollo Hospitals' LIMIT 1), 'Apollo Hospitals', 'preventive_maintenance', 'medium', '12 months PM logs for 18 ventilators', 88.00, 'Phyllo Ops', '2026-09-01'::date, 'in_progress', NULL),
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='Manipal Hospitals' LIMIT 1), 'Manipal Hospitals', 'equipment_calibration', 'high', 'NABL traceable cal certs for 42 infusion pumps', 54.00, 'Calibration Vendor', '2026-10-15'::date, 'in_progress', 'Vendor backlog'),
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='Fortis Healthcare' LIMIT 1), 'Fortis Healthcare', 'biomedical_engineer_credentials', 'critical', 'BMET cert + experience letters for 14 engineers', 21.00, 'Phyllo HR', '2026-07-30'::date, 'not_started', 'Engineers not uploading docs'),
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='Fortis Healthcare' LIMIT 1), 'Fortis Healthcare', 'spare_parts_traceability', 'high', 'Bonded part lot trace for 60 day window', 70.00, 'Inventory Lead', '2026-08-05'::date, 'in_progress', NULL),
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='Yashoda Hospitals' LIMIT 1), 'Yashoda Hospitals', 'training_logs', 'low', 'Quarterly engineer refresher attendance', 92.00, 'Training Lead', '2026-09-20'::date, 'submitted', NULL),
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='AIIMS Network' LIMIT 1), 'AIIMS Network', 'documentation', 'critical', 'AERB Form A renewals for 11 sites', 39.00, 'Compliance Cell', '2026-11-25'::date, 'in_progress', 'AERB portal slow'),
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='AIIMS Network' LIMIT 1), 'AIIMS Network', 'sterilization_records', 'high', 'Autoclave biological indicator logs 6 months', 62.00, 'Site BME', '2026-11-10'::date, 'in_progress', NULL),
((SELECT id FROM hospital_chain_accreditation_prep_r2779 WHERE chain_name='Narayana Health' LIMIT 1), 'Narayana Health', 'incident_response', 'low', 'Closure of one minor finding from Q1', 100.00, 'QA Lead', '2026-06-30'::date, 'accepted', NULL);

-- RPCs
DROP FUNCTION IF EXISTS rpc_r2779_overview();
CREATE OR REPLACE FUNCTION rpc_r2779_overview()
RETURNS TABLE(total_chains int, total_sites int, avg_prep_pct numeric, total_open_gaps int, at_risk int, blocked int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT chain_name)::int,
    COALESCE(SUM(sites_in_scope),0)::int,
    ROUND(COALESCE(AVG(our_prep_pct),0)::numeric, 2),
    COALESCE(SUM(open_gaps),0)::int,
    COUNT(*) FILTER (WHERE verdict='at_risk')::int,
    COUNT(*) FILTER (WHERE verdict='blocked')::int
  FROM hospital_chain_accreditation_prep_r2779;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_overview() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2779_by_chain();
CREATE OR REPLACE FUNCTION rpc_r2779_by_chain()
RETURNS TABLE(chain_name text, accreditation_body text, phase text, cycle_quarter text, sites_in_scope int, our_prep_pct numeric, open_gaps int, verdict text, assessor_visit_on date, critical_action text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.accreditation_body, p.phase, p.cycle_quarter, p.sites_in_scope, p.our_prep_pct, p.open_gaps, p.verdict, p.assessor_visit_on, p.critical_action
  FROM hospital_chain_accreditation_prep_r2779 p
  ORDER BY
    CASE p.verdict WHEN 'blocked' THEN 1 WHEN 'at_risk' THEN 2 WHEN 'on_track' THEN 3 WHEN 'recovered' THEN 4 WHEN 'passed' THEN 5 ELSE 6 END,
    p.our_prep_pct ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2779_gap_actions();
CREATE OR REPLACE FUNCTION rpc_r2779_gap_actions()
RETURNS TABLE(chain_name text, gap_area text, severity text, evidence_required text, evidence_supplied_pct numeric, action_owner text, due_on date, status text, blocker_note text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.chain_name, g.gap_area, g.severity, g.evidence_required, g.evidence_supplied_pct, g.action_owner, g.due_on, g.status, g.blocker_note
  FROM hospital_chain_accreditation_gap_action_r2779 g
  ORDER BY
    CASE g.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    g.due_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_gap_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_gap_actions() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2779_by_phase();
CREATE OR REPLACE FUNCTION rpc_r2779_by_phase()
RETURNS TABLE(phase text, chains int, sites int, avg_prep_pct numeric, open_gaps int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.phase, COUNT(DISTINCT p.chain_name)::int, COALESCE(SUM(p.sites_in_scope),0)::int, ROUND(AVG(p.our_prep_pct)::numeric, 2), COALESCE(SUM(p.open_gaps),0)::int
  FROM hospital_chain_accreditation_prep_r2779 p
  GROUP BY p.phase
  ORDER BY 4 ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_by_phase() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_by_phase() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2779_critical_gaps();
CREATE OR REPLACE FUNCTION rpc_r2779_critical_gaps()
RETURNS TABLE(chain_name text, gap_area text, evidence_required text, evidence_supplied_pct numeric, due_on date, blocker_note text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.chain_name, g.gap_area, g.evidence_required, g.evidence_supplied_pct, g.due_on, g.blocker_note
  FROM hospital_chain_accreditation_gap_action_r2779 g
  WHERE g.severity IN ('critical','high')
  ORDER BY g.due_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_critical_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_critical_gaps() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2779_upcoming_visits();
CREATE OR REPLACE FUNCTION rpc_r2779_upcoming_visits()
RETURNS TABLE(chain_name text, accreditation_body text, phase text, assessor_visit_on date, days_remaining int, our_prep_pct numeric, verdict text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.accreditation_body, p.phase, p.assessor_visit_on,
    GREATEST(0, (p.assessor_visit_on - CURRENT_DATE))::int,
    p.our_prep_pct, p.verdict
  FROM hospital_chain_accreditation_prep_r2779 p
  WHERE p.assessor_visit_on IS NOT NULL AND p.assessor_visit_on >= CURRENT_DATE
  ORDER BY p.assessor_visit_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_upcoming_visits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_upcoming_visits() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2779_evidence_progress();
CREATE OR REPLACE FUNCTION rpc_r2779_evidence_progress()
RETURNS TABLE(gap_area text, total_actions int, avg_evidence_pct numeric, accepted int, in_progress int, not_started int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.gap_area,
    COUNT(*)::int,
    ROUND(AVG(g.evidence_supplied_pct)::numeric, 2),
    COUNT(*) FILTER (WHERE g.status='accepted')::int,
    COUNT(*) FILTER (WHERE g.status='in_progress')::int,
    COUNT(*) FILTER (WHERE g.status='not_started')::int
  FROM hospital_chain_accreditation_gap_action_r2779 g
  GROUP BY g.gap_area
  ORDER BY 3 ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_evidence_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_evidence_progress() TO authenticated;

DROP FUNCTION IF EXISTS rpc_r2779_verdict_mix();
CREATE OR REPLACE FUNCTION rpc_r2779_verdict_mix()
RETURNS TABLE(verdict text, chains int, sites int, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  total_sites int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(SUM(sites_in_scope),0) INTO total_sites FROM hospital_chain_accreditation_prep_r2779;
  IF total_sites = 0 THEN total_sites := 1; END IF;
  RETURN QUERY
  SELECT p.verdict, COUNT(*)::int, COALESCE(SUM(p.sites_in_scope),0)::int,
    ROUND((COALESCE(SUM(p.sites_in_scope),0)::numeric / total_sites) * 100, 2)
  FROM hospital_chain_accreditation_prep_r2779 p
  GROUP BY p.verdict
  ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_r2779_verdict_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r2779_verdict_mix() TO authenticated;

COMMIT;
