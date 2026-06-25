BEGIN;

-- ============================================================
-- Round 2747 — Hospital Chain Quarterly Emerging Tech Pilot
-- ============================================================

CREATE TABLE IF NOT EXISTS hospital_chain_tech_pilots_r2747 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  quarter_label text NOT NULL,
  tech_kind text NOT NULL CHECK (tech_kind IN ('ai_triage','iot_telemetry','ar_remote_assist','robotic_calibration','blockchain_provenance','quantum_imaging')),
  pilot_scope text NOT NULL CHECK (pilot_scope IN ('single_site','multi_site','chain_wide','flagship_only')),
  start_date date NOT NULL,
  end_date date NOT NULL,
  budget_rupees bigint NOT NULL CHECK (budget_rupees >= 0),
  status text NOT NULL CHECK (status IN ('planned','running','complete','paused','cancelled')) DEFAULT 'planned',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_tech_pilots_r2747 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_tech_pilots_r2747;
CREATE POLICY founder_all ON hospital_chain_tech_pilots_r2747 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_chain_tech_pilot_outcomes_r2747 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pilot_id uuid NOT NULL REFERENCES hospital_chain_tech_pilots_r2747(id) ON DELETE CASCADE,
  kpi_label text NOT NULL,
  target_value numeric NOT NULL,
  actual_value numeric NOT NULL,
  unit text NOT NULL,
  outcome_grade text NOT NULL CHECK (outcome_grade IN ('exceeded','met','below','failed')),
  scale_decision text NOT NULL CHECK (scale_decision IN ('scale_chain_wide','scale_select_sites','extend_pilot','kill','pivot')),
  decision_notes text,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE hospital_chain_tech_pilot_outcomes_r2747 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON hospital_chain_tech_pilot_outcomes_r2747;
CREATE POLICY founder_all ON hospital_chain_tech_pilot_outcomes_r2747 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- Seed pilots ----------
INSERT INTO hospital_chain_tech_pilots_r2747 (chain_name, quarter_label, tech_kind, pilot_scope, start_date, end_date, budget_rupees, status) VALUES
  ('Apollo Group','Q2-2026','ai_triage','multi_site','2026-04-01'::date,'2026-06-30'::date,4500000,'complete'),
  ('Manipal Health','Q2-2026','iot_telemetry','chain_wide','2026-04-15'::date,'2026-06-30'::date,7800000,'complete'),
  ('Fortis Network','Q2-2026','ar_remote_assist','flagship_only','2026-05-01'::date,'2026-07-31'::date,2200000,'running'),
  ('Yashoda Hospitals','Q2-2026','robotic_calibration','single_site','2026-04-20'::date,'2026-06-20'::date,1800000,'complete'),
  ('Care Hospitals','Q2-2026','blockchain_provenance','multi_site','2026-05-10'::date,'2026-08-10'::date,3400000,'running'),
  ('KIMS Group','Q2-2026','quantum_imaging','flagship_only','2026-05-15'::date,'2026-09-15'::date,9600000,'planned');

-- ---------- Seed outcomes ----------
INSERT INTO hospital_chain_tech_pilot_outcomes_r2747 (pilot_id, kpi_label, target_value, actual_value, unit, outcome_grade, scale_decision, decision_notes)
SELECT id, 'triage_accuracy_pct', 85, 91, 'pct', 'exceeded', 'scale_chain_wide', 'AI triage beat radiologist baseline at 12 sites'
  FROM hospital_chain_tech_pilots_r2747 WHERE chain_name='Apollo Group' AND tech_kind='ai_triage';

INSERT INTO hospital_chain_tech_pilot_outcomes_r2747 (pilot_id, kpi_label, target_value, actual_value, unit, outcome_grade, scale_decision, decision_notes)
SELECT id, 'uptime_pct', 99, 99.7, 'pct', 'exceeded', 'scale_chain_wide', 'IoT telemetry kept all 28 CT scanners online'
  FROM hospital_chain_tech_pilots_r2747 WHERE chain_name='Manipal Health';

INSERT INTO hospital_chain_tech_pilot_outcomes_r2747 (pilot_id, kpi_label, target_value, actual_value, unit, outcome_grade, scale_decision, decision_notes)
SELECT id, 'first_call_resolution_pct', 70, 64, 'pct', 'below', 'extend_pilot', 'AR remote assist needs better bandwidth at tier-2 sites'
  FROM hospital_chain_tech_pilots_r2747 WHERE chain_name='Fortis Network';

INSERT INTO hospital_chain_tech_pilot_outcomes_r2747 (pilot_id, kpi_label, target_value, actual_value, unit, outcome_grade, scale_decision, decision_notes)
SELECT id, 'calibration_drift_microns', 50, 22, 'microns', 'exceeded', 'scale_select_sites', 'Robotic calibration cut drift by 56 pct'
  FROM hospital_chain_tech_pilots_r2747 WHERE chain_name='Yashoda Hospitals';

INSERT INTO hospital_chain_tech_pilot_outcomes_r2747 (pilot_id, kpi_label, target_value, actual_value, unit, outcome_grade, scale_decision, decision_notes)
SELECT id, 'parts_provenance_coverage_pct', 95, 88, 'pct', 'met', 'extend_pilot', 'Blockchain provenance partial — 12 pct of vendors not onboarded'
  FROM hospital_chain_tech_pilots_r2747 WHERE chain_name='Care Hospitals';

INSERT INTO hospital_chain_tech_pilot_outcomes_r2747 (pilot_id, kpi_label, target_value, actual_value, unit, outcome_grade, scale_decision, decision_notes)
SELECT id, 'imaging_clarity_index', 8, 0, 'index', 'failed', 'kill', 'Quantum imaging vendor missed delivery; kill pilot'
  FROM hospital_chain_tech_pilots_r2747 WHERE chain_name='KIMS Group';

-- ============================================================
-- RPCs
-- ============================================================

DROP FUNCTION IF EXISTS founder_r2747_pilot_overview();
CREATE OR REPLACE FUNCTION founder_r2747_pilot_overview()
RETURNS TABLE(total_pilots bigint, running_pilots bigint, complete_pilots bigint, total_budget_rupees bigint, avg_budget_rupees numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint,
         count(*) FILTER (WHERE status='running')::bigint,
         count(*) FILTER (WHERE status='complete')::bigint,
         COALESCE(sum(budget_rupees),0)::bigint,
         COALESCE(avg(budget_rupees),0)::numeric
    FROM hospital_chain_tech_pilots_r2747;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_pilot_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_pilot_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2747_pilots_by_chain();
CREATE OR REPLACE FUNCTION founder_r2747_pilots_by_chain()
RETURNS TABLE(chain_name text, pilot_count bigint, total_budget_rupees bigint, running bigint, complete bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name,
         count(*)::bigint,
         COALESCE(sum(p.budget_rupees),0)::bigint,
         count(*) FILTER (WHERE p.status='running')::bigint,
         count(*) FILTER (WHERE p.status='complete')::bigint
    FROM hospital_chain_tech_pilots_r2747 p
   GROUP BY p.chain_name
   ORDER BY total_budget_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_pilots_by_chain() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_pilots_by_chain() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2747_pilots_by_tech_kind();
CREATE OR REPLACE FUNCTION founder_r2747_pilots_by_tech_kind()
RETURNS TABLE(tech_kind text, pilot_count bigint, total_budget_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.tech_kind,
         count(*)::bigint,
         COALESCE(sum(p.budget_rupees),0)::bigint
    FROM hospital_chain_tech_pilots_r2747 p
   GROUP BY p.tech_kind
   ORDER BY total_budget_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_pilots_by_tech_kind() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_pilots_by_tech_kind() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2747_outcome_grade_breakdown();
CREATE OR REPLACE FUNCTION founder_r2747_outcome_grade_breakdown()
RETURNS TABLE(outcome_grade text, outcome_count bigint, pct_of_total numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE total_rows bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO total_rows FROM hospital_chain_tech_pilot_outcomes_r2747;
  IF total_rows = 0 THEN total_rows := 1; END IF;
  RETURN QUERY
  SELECT o.outcome_grade,
         count(*)::bigint,
         round((count(*)::numeric / total_rows) * 100, 1)
    FROM hospital_chain_tech_pilot_outcomes_r2747 o
   GROUP BY o.outcome_grade
   ORDER BY outcome_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_outcome_grade_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_outcome_grade_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2747_scale_decision_breakdown();
CREATE OR REPLACE FUNCTION founder_r2747_scale_decision_breakdown()
RETURNS TABLE(scale_decision text, decision_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.scale_decision, count(*)::bigint
    FROM hospital_chain_tech_pilot_outcomes_r2747 o
   GROUP BY o.scale_decision
   ORDER BY decision_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_scale_decision_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_scale_decision_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2747_pilots_list();
CREATE OR REPLACE FUNCTION founder_r2747_pilots_list()
RETURNS TABLE(id uuid, chain_name text, quarter_label text, tech_kind text, pilot_scope text, start_date date, end_date date, budget_rupees bigint, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.chain_name, p.quarter_label, p.tech_kind, p.pilot_scope, p.start_date, p.end_date, p.budget_rupees, p.status
    FROM hospital_chain_tech_pilots_r2747 p
   ORDER BY p.start_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_pilots_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_pilots_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2747_outcomes_list();
CREATE OR REPLACE FUNCTION founder_r2747_outcomes_list()
RETURNS TABLE(id uuid, chain_name text, tech_kind text, kpi_label text, target_value numeric, actual_value numeric, unit text, outcome_grade text, scale_decision text, decision_notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, p.chain_name, p.tech_kind, o.kpi_label, o.target_value, o.actual_value, o.unit, o.outcome_grade, o.scale_decision, o.decision_notes
    FROM hospital_chain_tech_pilot_outcomes_r2747 o
    JOIN hospital_chain_tech_pilots_r2747 p ON p.id = o.pilot_id
   ORDER BY o.recorded_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_outcomes_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_outcomes_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2747_scale_winners();
CREATE OR REPLACE FUNCTION founder_r2747_scale_winners()
RETURNS TABLE(chain_name text, tech_kind text, kpi_label text, actual_value numeric, target_value numeric, scale_decision text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.chain_name, p.tech_kind, o.kpi_label, o.actual_value, o.target_value, o.scale_decision
    FROM hospital_chain_tech_pilot_outcomes_r2747 o
    JOIN hospital_chain_tech_pilots_r2747 p ON p.id = o.pilot_id
   WHERE o.scale_decision IN ('scale_chain_wide','scale_select_sites')
   ORDER BY o.actual_value DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2747_scale_winners() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2747_scale_winners() TO authenticated;

COMMIT;
