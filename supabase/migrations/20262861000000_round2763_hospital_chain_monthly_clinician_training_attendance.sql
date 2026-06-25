BEGIN;

-- ============================================================================
-- Round 2763: Hospital Chain Monthly Clinician Training Attendance
-- chain x session x clinicians invited x attended x certified x outcome
-- ============================================================================

CREATE TABLE IF NOT EXISTS chain_clinician_training_sessions_r2763 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_code text NOT NULL,
  chain_name text NOT NULL,
  session_month date NOT NULL,
  session_title text NOT NULL,
  modality text NOT NULL CHECK (modality IN ('onsite','virtual','hybrid')),
  clinicians_invited integer NOT NULL CHECK (clinicians_invited >= 0),
  clinicians_attended integer NOT NULL CHECK (clinicians_attended >= 0),
  clinicians_certified integer NOT NULL CHECK (clinicians_certified >= 0),
  outcome_score numeric(5,2) NOT NULL CHECK (outcome_score >= 0 AND outcome_score <= 100),
  outcome_status text NOT NULL CHECK (outcome_status IN ('exceeded','on_track','below_target','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_clinician_training_sessions_r2763 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_clinician_training_sessions_r2763;
CREATE POLICY founder_all ON chain_clinician_training_sessions_r2763
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS chain_clinician_training_outcomes_r2763 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES chain_clinician_training_sessions_r2763(id) ON DELETE CASCADE,
  chain_code text NOT NULL,
  outcome_metric text NOT NULL,
  baseline_value numeric(8,2) NOT NULL,
  post_training_value numeric(8,2) NOT NULL,
  delta_percent numeric(6,2) NOT NULL,
  improvement_grade text NOT NULL CHECK (improvement_grade IN ('A','B','C','D','F')),
  follow_up_required boolean NOT NULL DEFAULT false,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE chain_clinician_training_outcomes_r2763 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON chain_clinician_training_outcomes_r2763;
CREATE POLICY founder_all ON chain_clinician_training_outcomes_r2763
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- Seed sessions
INSERT INTO chain_clinician_training_sessions_r2763
  (chain_code, chain_name, session_month, session_title, modality, clinicians_invited, clinicians_attended, clinicians_certified, outcome_score, outcome_status, notes)
VALUES
  ('APOLLO', 'Apollo Hospitals', '2026-06-01'::date, 'Ventilator Maintenance Protocol', 'hybrid', 120, 108, 96, 92.50, 'exceeded', 'Strong attendance in Hyd cluster'),
  ('FORTIS', 'Fortis Healthcare', '2026-06-01'::date, 'Defibrillator Safety Drill', 'onsite', 85, 70, 58, 76.40, 'on_track', 'Bengaluru sites lagged 12%'),
  ('MAX', 'Max Healthcare', '2026-06-01'::date, 'Infusion Pump Calibration', 'virtual', 140, 92, 71, 64.20, 'below_target', 'Virtual fatigue noted'),
  ('MANIPAL', 'Manipal Hospitals', '2026-06-01'::date, 'NABH Equipment Logbook', 'onsite', 95, 89, 84, 88.10, 'exceeded', 'Best-in-class cohort'),
  ('NARAYANA', 'Narayana Health', '2026-06-01'::date, 'Patient Monitor Alarm Mgmt', 'hybrid', 110, 62, 41, 48.75, 'critical', 'Escalated to CMO');

-- Seed outcomes
INSERT INTO chain_clinician_training_outcomes_r2763
  (session_id, chain_code, outcome_metric, baseline_value, post_training_value, delta_percent, improvement_grade, follow_up_required)
SELECT id, chain_code, 'Equipment downtime incidents/month', 14.0, 6.0, -57.14, 'A', false
FROM chain_clinician_training_sessions_r2763 WHERE chain_code = 'APOLLO'
UNION ALL
SELECT id, chain_code, 'Defib first-shock success rate %', 71.0, 84.0, 18.31, 'B', false
FROM chain_clinician_training_sessions_r2763 WHERE chain_code = 'FORTIS'
UNION ALL
SELECT id, chain_code, 'Infusion pump miscal incidents', 22.0, 18.0, -18.18, 'C', true
FROM chain_clinician_training_sessions_r2763 WHERE chain_code = 'MAX'
UNION ALL
SELECT id, chain_code, 'NABH logbook compliance %', 78.0, 96.0, 23.08, 'A', false
FROM chain_clinician_training_sessions_r2763 WHERE chain_code = 'MANIPAL'
UNION ALL
SELECT id, chain_code, 'Alarm-fatigue incidents/week', 31.0, 28.0, -9.68, 'D', true
FROM chain_clinician_training_sessions_r2763 WHERE chain_code = 'NARAYANA';

-- ============================================================================
-- RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS founder_chain_training_sessions_r2763();
CREATE OR REPLACE FUNCTION founder_chain_training_sessions_r2763()
RETURNS TABLE (
  id uuid,
  chain_code text,
  chain_name text,
  session_month date,
  session_title text,
  modality text,
  clinicians_invited integer,
  clinicians_attended integer,
  clinicians_certified integer,
  attendance_pct numeric,
  certification_pct numeric,
  outcome_score numeric,
  outcome_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.chain_code, s.chain_name, s.session_month, s.session_title, s.modality,
         s.clinicians_invited, s.clinicians_attended, s.clinicians_certified,
         ROUND((s.clinicians_attended::numeric / NULLIF(s.clinicians_invited,0)) * 100, 1),
         ROUND((s.clinicians_certified::numeric / NULLIF(s.clinicians_attended,0)) * 100, 1),
         s.outcome_score, s.outcome_status
  FROM chain_clinician_training_sessions_r2763 s
  ORDER BY s.outcome_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_sessions_r2763() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_sessions_r2763() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_training_kpis_r2763();
CREATE OR REPLACE FUNCTION founder_chain_training_kpis_r2763()
RETURNS TABLE (
  total_chains integer,
  total_invited integer,
  total_attended integer,
  total_certified integer,
  avg_attendance_pct numeric,
  avg_certification_pct numeric,
  avg_outcome_score numeric,
  critical_chains integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(DISTINCT chain_code)::integer,
         SUM(clinicians_invited)::integer,
         SUM(clinicians_attended)::integer,
         SUM(clinicians_certified)::integer,
         ROUND(AVG(clinicians_attended::numeric / NULLIF(clinicians_invited,0)) * 100, 1),
         ROUND(AVG(clinicians_certified::numeric / NULLIF(clinicians_attended,0)) * 100, 1),
         ROUND(AVG(outcome_score), 2),
         SUM(CASE WHEN outcome_status = 'critical' THEN 1 ELSE 0 END)::integer
  FROM chain_clinician_training_sessions_r2763;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_kpis_r2763() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_kpis_r2763() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_training_outcomes_r2763();
CREATE OR REPLACE FUNCTION founder_chain_training_outcomes_r2763()
RETURNS TABLE (
  outcome_id uuid,
  chain_code text,
  outcome_metric text,
  baseline_value numeric,
  post_training_value numeric,
  delta_percent numeric,
  improvement_grade text,
  follow_up_required boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.chain_code, o.outcome_metric, o.baseline_value, o.post_training_value,
         o.delta_percent, o.improvement_grade, o.follow_up_required
  FROM chain_clinician_training_outcomes_r2763 o
  ORDER BY o.improvement_grade ASC, o.delta_percent DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_outcomes_r2763() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_outcomes_r2763() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_training_modality_breakdown_r2763();
CREATE OR REPLACE FUNCTION founder_chain_training_modality_breakdown_r2763()
RETURNS TABLE (
  modality text,
  sessions_count integer,
  avg_attendance_pct numeric,
  avg_certification_pct numeric,
  avg_outcome_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.modality,
         COUNT(*)::integer,
         ROUND(AVG(s.clinicians_attended::numeric / NULLIF(s.clinicians_invited,0)) * 100, 1),
         ROUND(AVG(s.clinicians_certified::numeric / NULLIF(s.clinicians_attended,0)) * 100, 1),
         ROUND(AVG(s.outcome_score), 2)
  FROM chain_clinician_training_sessions_r2763 s
  GROUP BY s.modality
  ORDER BY 5 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_modality_breakdown_r2763() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_modality_breakdown_r2763() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_training_critical_followups_r2763();
CREATE OR REPLACE FUNCTION founder_chain_training_critical_followups_r2763()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  outcome_metric text,
  improvement_grade text,
  delta_percent numeric,
  outcome_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.chain_code, s.chain_name, o.outcome_metric, o.improvement_grade, o.delta_percent, s.outcome_status
  FROM chain_clinician_training_outcomes_r2763 o
  JOIN chain_clinician_training_sessions_r2763 s ON s.id = o.session_id
  WHERE o.follow_up_required = true OR s.outcome_status IN ('critical','below_target')
  ORDER BY s.outcome_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_critical_followups_r2763() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_critical_followups_r2763() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_training_top_performers_r2763();
CREATE OR REPLACE FUNCTION founder_chain_training_top_performers_r2763()
RETURNS TABLE (
  chain_code text,
  chain_name text,
  session_title text,
  attendance_pct numeric,
  certification_pct numeric,
  outcome_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.chain_code, s.chain_name, s.session_title,
         ROUND((s.clinicians_attended::numeric / NULLIF(s.clinicians_invited,0)) * 100, 1),
         ROUND((s.clinicians_certified::numeric / NULLIF(s.clinicians_attended,0)) * 100, 1),
         s.outcome_score
  FROM chain_clinician_training_sessions_r2763 s
  WHERE s.outcome_status IN ('exceeded','on_track')
  ORDER BY s.outcome_score DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_top_performers_r2763() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_top_performers_r2763() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_training_grade_distribution_r2763();
CREATE OR REPLACE FUNCTION founder_chain_training_grade_distribution_r2763()
RETURNS TABLE (
  improvement_grade text,
  outcomes_count integer,
  avg_delta_percent numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.improvement_grade,
         COUNT(*)::integer,
         ROUND(AVG(o.delta_percent), 2)
  FROM chain_clinician_training_outcomes_r2763 o
  GROUP BY o.improvement_grade
  ORDER BY o.improvement_grade ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_grade_distribution_r2763() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_grade_distribution_r2763() TO authenticated;

DROP FUNCTION IF EXISTS founder_chain_training_log_session_r2763(text, text, date, text, text, integer, integer, integer, numeric, text, text);
CREATE OR REPLACE FUNCTION founder_chain_training_log_session_r2763(
  p_chain_code text,
  p_chain_name text,
  p_session_month date,
  p_session_title text,
  p_modality text,
  p_invited integer,
  p_attended integer,
  p_certified integer,
  p_outcome_score numeric,
  p_outcome_status text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO chain_clinician_training_sessions_r2763
    (chain_code, chain_name, session_month, session_title, modality,
     clinicians_invited, clinicians_attended, clinicians_certified,
     outcome_score, outcome_status, notes)
  VALUES (p_chain_code, p_chain_name, p_session_month, p_session_title, p_modality,
          p_invited, p_attended, p_certified, p_outcome_score, p_outcome_status, p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_chain_training_log_session_r2763(text, text, date, text, text, integer, integer, integer, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_training_log_session_r2763(text, text, date, text, text, integer, integer, integer, numeric, text, text) TO authenticated;

COMMIT;
