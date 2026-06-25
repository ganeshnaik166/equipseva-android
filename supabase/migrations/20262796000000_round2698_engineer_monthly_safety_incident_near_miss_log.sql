BEGIN;

-- ============================================================
-- Round 2698: Engineer Monthly Safety Incident & Near-Miss Log
-- ============================================================

-- Table 1: Safety incident log
CREATE TABLE IF NOT EXISTS engineer_safety_incident_log_r2698 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_date date NOT NULL,
  engineer_name text NOT NULL,
  city text NOT NULL,
  incident_kind text NOT NULL CHECK (incident_kind IN ('near_miss','first_aid','recordable','lost_time','property_damage','environmental')),
  severity text NOT NULL CHECK (severity IN ('s1_critical','s2_high','s3_medium','s4_low')),
  root_cause text NOT NULL CHECK (root_cause IN ('ppe_gap','training_gap','equipment_defect','procedure_skip','environmental_hazard','fatigue','communication')),
  corrective_action text NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('resolved','in_progress','escalated','closed_no_action')),
  prevention_measure text NOT NULL,
  downtime_minutes integer NOT NULL DEFAULT 0,
  hospital_partner text,
  reported_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_safety_incident_log_r2698 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_safety_incident_log_r2698;
CREATE POLICY founder_all ON engineer_safety_incident_log_r2698 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: Monthly safety scorecard
CREATE TABLE IF NOT EXISTS engineer_safety_monthly_scorecard_r2698 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  engineer_name text NOT NULL,
  city text NOT NULL,
  total_incidents integer NOT NULL DEFAULT 0,
  near_miss_count integer NOT NULL DEFAULT 0,
  recordable_count integer NOT NULL DEFAULT 0,
  ppe_compliance_pct integer NOT NULL CHECK (ppe_compliance_pct BETWEEN 0 AND 100),
  training_hours numeric(6,2) NOT NULL DEFAULT 0,
  safety_score integer NOT NULL CHECK (safety_score BETWEEN 0 AND 100),
  status text NOT NULL CHECK (status IN ('excellent','good','watch','at_risk')),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_safety_monthly_scorecard_r2698 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_safety_monthly_scorecard_r2698;
CREATE POLICY founder_all ON engineer_safety_monthly_scorecard_r2698 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Seeds: incident log
-- ============================================================
INSERT INTO engineer_safety_incident_log_r2698 (incident_date, engineer_name, city, incident_kind, severity, root_cause, corrective_action, outcome, prevention_measure, downtime_minutes, hospital_partner) VALUES
  ('2026-06-02'::date, 'Ravi Kumar', 'Hyderabad', 'near_miss', 's3_medium', 'ppe_gap', 'Issued ESD wrist strap kit', 'resolved', 'Mandatory ESD kit photo in pre-job checklist', 15, 'Apollo Jubilee'),
  ('2026-06-05'::date, 'Anita Sharma', 'Bengaluru', 'first_aid', 's3_medium', 'equipment_defect', 'Replaced faulty multimeter probe', 'resolved', 'Quarterly probe insulation test', 30, 'Manipal Old Airport'),
  ('2026-06-09'::date, 'Suresh Patel', 'Mumbai', 'recordable', 's2_high', 'procedure_skip', 'Re-trained on LOTO sequence', 'in_progress', 'LOTO sign-off on every panel job', 90, 'Fortis Mulund'),
  ('2026-06-12'::date, 'Deepa Iyer', 'Chennai', 'near_miss', 's4_low', 'communication', 'Toolbox talk on radio etiquette', 'closed_no_action', 'Daily 8am radio check', 10, 'MIOT International'),
  ('2026-06-16'::date, 'Vikram Singh', 'Delhi', 'lost_time', 's1_critical', 'fatigue', 'Mandatory rest after 4-hour shift', 'escalated', 'Roster engine caps 4hr continuous service', 240, 'Max Saket'),
  ('2026-06-18'::date, 'Priya Nair', 'Kochi', 'environmental', 's2_high', 'environmental_hazard', 'Spill kit replenished + drain blocked', 'resolved', 'Site survey before chem job', 60, 'Aster Medcity'),
  ('2026-06-20'::date, 'Arjun Reddy', 'Hyderabad', 'property_damage', 's3_medium', 'training_gap', 'Compressor anchor bolt re-spec', 'in_progress', 'Vendor anchor-bolt SOP update', 45, 'Yashoda Hitec');

-- Seeds: monthly scorecard
INSERT INTO engineer_safety_monthly_scorecard_r2698 (month_label, engineer_name, city, total_incidents, near_miss_count, recordable_count, ppe_compliance_pct, training_hours, safety_score, status) VALUES
  ('2026-06', 'Ravi Kumar', 'Hyderabad', 1, 1, 0, 96, 8.00, 92, 'excellent'),
  ('2026-06', 'Anita Sharma', 'Bengaluru', 1, 0, 0, 94, 6.50, 88, 'good'),
  ('2026-06', 'Suresh Patel', 'Mumbai', 1, 0, 1, 82, 4.00, 64, 'watch'),
  ('2026-06', 'Deepa Iyer', 'Chennai', 1, 1, 0, 98, 9.50, 95, 'excellent'),
  ('2026-06', 'Vikram Singh', 'Delhi', 1, 0, 1, 71, 3.00, 48, 'at_risk'),
  ('2026-06', 'Priya Nair', 'Kochi', 1, 0, 0, 90, 7.00, 81, 'good'),
  ('2026-06', 'Arjun Reddy', 'Hyderabad', 1, 0, 0, 86, 5.50, 74, 'watch');

-- ============================================================
-- RPCs (all SECDEF, founder-gated)
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2698_safety_kpis();
CREATE FUNCTION founder_r2698_safety_kpis()
RETURNS TABLE(total_incidents bigint, near_miss bigint, recordable bigint, lost_time bigint, critical_severity bigint, total_downtime_min bigint, avg_safety_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM engineer_safety_incident_log_r2698),
    (SELECT COUNT(*) FROM engineer_safety_incident_log_r2698 WHERE incident_kind = 'near_miss'),
    (SELECT COUNT(*) FROM engineer_safety_incident_log_r2698 WHERE incident_kind = 'recordable'),
    (SELECT COUNT(*) FROM engineer_safety_incident_log_r2698 WHERE incident_kind = 'lost_time'),
    (SELECT COUNT(*) FROM engineer_safety_incident_log_r2698 WHERE severity = 's1_critical'),
    (SELECT COALESCE(SUM(downtime_minutes),0)::bigint FROM engineer_safety_incident_log_r2698),
    (SELECT ROUND(COALESCE(AVG(safety_score),0)::numeric, 1) FROM engineer_safety_monthly_scorecard_r2698);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_safety_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_safety_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2698_incident_list();
CREATE FUNCTION founder_r2698_incident_list()
RETURNS TABLE(incident_date date, engineer_name text, city text, incident_kind text, severity text, root_cause text, outcome text, downtime_minutes integer, hospital_partner text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.incident_date, l.engineer_name, l.city, l.incident_kind, l.severity, l.root_cause, l.outcome, l.downtime_minutes, l.hospital_partner
  FROM engineer_safety_incident_log_r2698 l
  ORDER BY l.incident_date DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_incident_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_incident_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2698_root_cause_breakdown();
CREATE FUNCTION founder_r2698_root_cause_breakdown()
RETURNS TABLE(root_cause text, incident_count bigint, total_downtime_min bigint, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE tot bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO tot FROM engineer_safety_incident_log_r2698;
  IF tot = 0 THEN tot := 1; END IF;
  RETURN QUERY
  SELECT l.root_cause, COUNT(*)::bigint, COALESCE(SUM(l.downtime_minutes),0)::bigint,
         ROUND((COUNT(*)::numeric / tot) * 100, 1)
  FROM engineer_safety_incident_log_r2698 l
  GROUP BY l.root_cause
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_root_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_root_cause_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2698_severity_mix();
CREATE FUNCTION founder_r2698_severity_mix()
RETURNS TABLE(severity text, incident_count bigint, share_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE tot bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO tot FROM engineer_safety_incident_log_r2698;
  IF tot = 0 THEN tot := 1; END IF;
  RETURN QUERY
  SELECT l.severity, COUNT(*)::bigint, ROUND((COUNT(*)::numeric / tot) * 100, 1)
  FROM engineer_safety_incident_log_r2698 l
  GROUP BY l.severity
  ORDER BY l.severity;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_severity_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_severity_mix() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2698_engineer_scorecard();
CREATE FUNCTION founder_r2698_engineer_scorecard()
RETURNS TABLE(engineer_name text, city text, total_incidents integer, near_miss_count integer, recordable_count integer, ppe_compliance_pct integer, training_hours numeric, safety_score integer, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.city, s.total_incidents, s.near_miss_count, s.recordable_count,
         s.ppe_compliance_pct, s.training_hours, s.safety_score, s.status
  FROM engineer_safety_monthly_scorecard_r2698 s
  ORDER BY s.safety_score DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_engineer_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_engineer_scorecard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2698_at_risk_engineers();
CREATE FUNCTION founder_r2698_at_risk_engineers()
RETURNS TABLE(engineer_name text, city text, safety_score integer, ppe_compliance_pct integer, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_name, s.city, s.safety_score, s.ppe_compliance_pct, s.status
  FROM engineer_safety_monthly_scorecard_r2698 s
  WHERE s.status IN ('watch','at_risk')
  ORDER BY s.safety_score ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_at_risk_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_at_risk_engineers() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2698_corrective_actions();
CREATE FUNCTION founder_r2698_corrective_actions()
RETURNS TABLE(incident_date date, engineer_name text, corrective_action text, prevention_measure text, outcome text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.incident_date, l.engineer_name, l.corrective_action, l.prevention_measure, l.outcome
  FROM engineer_safety_incident_log_r2698 l
  ORDER BY l.incident_date DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_corrective_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_corrective_actions() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2698_city_rollup();
CREATE FUNCTION founder_r2698_city_rollup()
RETURNS TABLE(city text, incidents bigint, total_downtime_min bigint, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.city, COUNT(*)::bigint, COALESCE(SUM(l.downtime_minutes),0)::bigint,
         ROUND(COALESCE((SELECT AVG(s.safety_score) FROM engineer_safety_monthly_scorecard_r2698 s WHERE s.city = l.city),0)::numeric, 1)
  FROM engineer_safety_incident_log_r2698 l
  GROUP BY l.city
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_r2698_city_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2698_city_rollup() TO authenticated;

COMMIT;
