BEGIN;

-- ============================================================================
-- Round 2746 — Engineer Monthly Customer Handoff Photo Quality
-- Spec: engineer × photo × clarity × completeness × annotation × redo action
-- ============================================================================

CREATE TABLE IF NOT EXISTS engineer_handoff_photo_scores_r2746 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  month_label text NOT NULL,
  jobs_completed int NOT NULL CHECK (jobs_completed >= 0),
  photos_submitted int NOT NULL CHECK (photos_submitted >= 0),
  clarity_score numeric(4,2) NOT NULL CHECK (clarity_score >= 0 AND clarity_score <= 10),
  completeness_score numeric(4,2) NOT NULL CHECK (completeness_score >= 0 AND completeness_score <= 10),
  annotation_score numeric(4,2) NOT NULL CHECK (annotation_score >= 0 AND annotation_score <= 10),
  composite_score numeric(4,2) NOT NULL CHECK (composite_score >= 0 AND composite_score <= 10),
  redo_count int NOT NULL DEFAULT 0 CHECK (redo_count >= 0),
  grade text NOT NULL CHECK (grade IN ('A','B','C','D','F')),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_handoff_photo_scores_r2746 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handoff_photo_scores_r2746;
CREATE POLICY founder_all ON engineer_handoff_photo_scores_r2746
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_handoff_redo_actions_r2746 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code text NOT NULL,
  job_ref text NOT NULL,
  hospital_name text NOT NULL,
  failure_reason text NOT NULL CHECK (failure_reason IN ('blurry','missing_angle','no_annotation','poor_lighting','wrong_subject','missing_serial')),
  severity text NOT NULL CHECK (severity IN ('minor','major','critical')),
  redo_status text NOT NULL CHECK (redo_status IN ('pending','in_progress','resolved','escalated')),
  flagged_at timestamptz NOT NULL,
  resolved_at timestamptz,
  reviewer_note text
);

ALTER TABLE engineer_handoff_redo_actions_r2746 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_handoff_redo_actions_r2746;
CREATE POLICY founder_all ON engineer_handoff_redo_actions_r2746
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Seed: engineer_handoff_photo_scores_r2746
INSERT INTO engineer_handoff_photo_scores_r2746 (engineer_code, engineer_name, month_label, jobs_completed, photos_submitted, clarity_score, completeness_score, annotation_score, composite_score, redo_count, grade) VALUES
  ('ENG-021','Ravi Kumar','2026-06',42,168,9.20,9.10,8.80,9.03,2,'A'),
  ('ENG-034','Priya Sharma','2026-06',38,152,8.50,8.20,7.90,8.20,4,'B'),
  ('ENG-047','Anil Verma','2026-06',29,116,7.10,6.80,5.50,6.47,9,'C'),
  ('ENG-052','Suresh Patil','2026-06',45,180,9.50,9.40,9.20,9.37,1,'A'),
  ('ENG-061','Lakshmi Iyer','2026-06',33,132,6.20,5.80,4.90,5.63,12,'D'),
  ('ENG-073','Mohit Singh','2026-06',27,108,8.80,8.60,8.40,8.60,3,'B');

-- Seed: engineer_handoff_redo_actions_r2746
INSERT INTO engineer_handoff_redo_actions_r2746 (engineer_code, job_ref, hospital_name, failure_reason, severity, redo_status, flagged_at, resolved_at, reviewer_note) VALUES
  ('ENG-047','JOB-9821','Apollo Hyderabad','blurry','major','resolved','2026-06-08 10:15:00+05:30'::timestamptz,'2026-06-09 14:00:00+05:30'::timestamptz,'Retook photos, sharper now'),
  ('ENG-061','JOB-9854','Yashoda Hospitals','missing_serial','critical','escalated','2026-06-12 09:00:00+05:30'::timestamptz,NULL,'Cannot verify warranty without serial'),
  ('ENG-061','JOB-9867','KIMS Secunderabad','no_annotation','major','in_progress','2026-06-15 11:30:00+05:30'::timestamptz,NULL,'Engineer notified, awaiting fix'),
  ('ENG-034','JOB-9712','Care Hospitals','poor_lighting','minor','resolved','2026-06-04 13:20:00+05:30'::timestamptz,'2026-06-04 18:45:00+05:30'::timestamptz,'Flash used on second pass'),
  ('ENG-047','JOB-9890','Continental Hospitals','wrong_subject','major','pending','2026-06-18 16:00:00+05:30'::timestamptz,NULL,'Photo shows wrong equipment unit'),
  ('ENG-073','JOB-9905','Sunshine Hospital','missing_angle','minor','resolved','2026-06-20 08:45:00+05:30'::timestamptz,'2026-06-20 12:15:00+05:30'::timestamptz,'Rear-panel angle added');

-- ============================================================================
-- RPCs (7 minimum)
-- ============================================================================

DROP FUNCTION IF EXISTS r2746_kpi_summary();
CREATE OR REPLACE FUNCTION r2746_kpi_summary()
RETURNS TABLE (
  total_engineers int,
  avg_composite numeric,
  avg_clarity numeric,
  avg_completeness numeric,
  avg_annotation numeric,
  total_redos int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(DISTINCT engineer_code)::int,
    ROUND(AVG(composite_score)::numeric, 2),
    ROUND(AVG(clarity_score)::numeric, 2),
    ROUND(AVG(completeness_score)::numeric, 2),
    ROUND(AVG(annotation_score)::numeric, 2),
    COALESCE(SUM(redo_count), 0)::int
  FROM engineer_handoff_photo_scores_r2746;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_kpi_summary() TO authenticated;

DROP FUNCTION IF EXISTS r2746_engineer_leaderboard();
CREATE OR REPLACE FUNCTION r2746_engineer_leaderboard()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  composite_score numeric,
  grade text,
  jobs_completed int,
  redo_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.composite_score, s.grade, s.jobs_completed, s.redo_count
  FROM engineer_handoff_photo_scores_r2746 s
  ORDER BY s.composite_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS r2746_grade_distribution();
CREATE OR REPLACE FUNCTION r2746_grade_distribution()
RETURNS TABLE (grade text, engineer_count int, avg_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.grade, COUNT(*)::int, ROUND(AVG(s.composite_score)::numeric, 2)
  FROM engineer_handoff_photo_scores_r2746 s
  GROUP BY s.grade
  ORDER BY s.grade;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_grade_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_grade_distribution() TO authenticated;

DROP FUNCTION IF EXISTS r2746_redo_actions_open();
CREATE OR REPLACE FUNCTION r2746_redo_actions_open()
RETURNS TABLE (
  job_ref text,
  engineer_code text,
  hospital_name text,
  failure_reason text,
  severity text,
  redo_status text,
  flagged_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.job_ref, r.engineer_code, r.hospital_name, r.failure_reason, r.severity, r.redo_status, r.flagged_at
  FROM engineer_handoff_redo_actions_r2746 r
  WHERE r.redo_status IN ('pending','in_progress','escalated')
  ORDER BY r.flagged_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_redo_actions_open() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_redo_actions_open() TO authenticated;

DROP FUNCTION IF EXISTS r2746_failure_reason_breakdown();
CREATE OR REPLACE FUNCTION r2746_failure_reason_breakdown()
RETURNS TABLE (failure_reason text, count int, critical_count int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.failure_reason, COUNT(*)::int,
         COUNT(*) FILTER (WHERE r.severity = 'critical')::int
  FROM engineer_handoff_redo_actions_r2746 r
  GROUP BY r.failure_reason
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_failure_reason_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_failure_reason_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS r2746_low_score_engineers();
CREATE OR REPLACE FUNCTION r2746_low_score_engineers()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  composite_score numeric,
  redo_count int,
  grade text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.composite_score, s.redo_count, s.grade
  FROM engineer_handoff_photo_scores_r2746 s
  WHERE s.composite_score < 7.0
  ORDER BY s.composite_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_low_score_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_low_score_engineers() TO authenticated;

DROP FUNCTION IF EXISTS r2746_resolution_velocity();
CREATE OR REPLACE FUNCTION r2746_resolution_velocity()
RETURNS TABLE (
  total_resolved int,
  total_pending int,
  total_escalated int,
  avg_resolution_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE redo_status = 'resolved')::int,
    COUNT(*) FILTER (WHERE redo_status = 'pending')::int,
    COUNT(*) FILTER (WHERE redo_status = 'escalated')::int,
    ROUND(AVG(EXTRACT(EPOCH FROM (resolved_at - flagged_at)) / 3600.0) FILTER (WHERE resolved_at IS NOT NULL)::numeric, 2)
  FROM engineer_handoff_redo_actions_r2746;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_resolution_velocity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_resolution_velocity() TO authenticated;

DROP FUNCTION IF EXISTS r2746_quality_dimensions();
CREATE OR REPLACE FUNCTION r2746_quality_dimensions()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  clarity_score numeric,
  completeness_score numeric,
  annotation_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.clarity_score, s.completeness_score, s.annotation_score
  FROM engineer_handoff_photo_scores_r2746 s
  ORDER BY s.engineer_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION r2746_quality_dimensions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION r2746_quality_dimensions() TO authenticated;

COMMIT;
