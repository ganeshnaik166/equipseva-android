-- Round 2910: Engineer Monthly Customer Site Photo-Documentation Quality Audit
-- Heavy founder ops: 2 tables + 7 RPCs

-- =====================================================
-- TABLE 1: photo_audit_submissions_r2910
-- =====================================================
CREATE TABLE IF NOT EXISTS public.photo_audit_submissions_r2910 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  audit_month date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  hospital_name text NOT NULL,
  city text NOT NULL,
  visits_completed int NOT NULL DEFAULT 0,
  photos_submitted int NOT NULL DEFAULT 0,
  photos_required int NOT NULL DEFAULT 0,
  blurry_count int NOT NULL DEFAULT 0,
  wrong_angle_count int NOT NULL DEFAULT 0,
  missing_serial_count int NOT NULL DEFAULT 0,
  missing_before_after_count int NOT NULL DEFAULT 0,
  geotag_mismatch_count int NOT NULL DEFAULT 0,
  quality_score numeric(5,2) NOT NULL DEFAULT 0,
  reviewer_verdict text NOT NULL CHECK (reviewer_verdict IN ('pass','minor_issues','major_issues','fail')),
  rework_required boolean NOT NULL DEFAULT false
);

ALTER TABLE public.photo_audit_submissions_r2910 ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- TABLE 2: photo_audit_findings_r2910
-- =====================================================
CREATE TABLE IF NOT EXISTS public.photo_audit_findings_r2910 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  finding_date date NOT NULL,
  engineer_code text NOT NULL,
  engineer_name text NOT NULL,
  hospital_name text NOT NULL,
  finding_category text NOT NULL CHECK (finding_category IN ('blurry','wrong_angle','missing_serial','missing_before_after','geotag_mismatch','duplicate_upload','watermark_missing','timestamp_drift')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  description text NOT NULL,
  remediation_status text NOT NULL CHECK (remediation_status IN ('open','in_progress','resolved','escalated')),
  resolved_at timestamptz,
  coach_assigned text,
  retraining_required boolean NOT NULL DEFAULT false
);

ALTER TABLE public.photo_audit_findings_r2910 ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- SEED DATA (18 + 20 rows)
-- =====================================================
INSERT INTO public.photo_audit_submissions_r2910 (audit_month, engineer_code, engineer_name, hospital_name, city, visits_completed, photos_submitted, photos_required, blurry_count, wrong_angle_count, missing_serial_count, missing_before_after_count, geotag_mismatch_count, quality_score, reviewer_verdict, rework_required) VALUES
('2026-06-01'::date, 'ENG-001', 'Ravi Kumar', 'Apollo Hyderabad', 'Hyderabad', 18, 142, 144, 2, 1, 0, 1, 0, 94.50, 'pass', false),
('2026-06-01'::date, 'ENG-002', 'Sneha Reddy', 'KIMS Secunderabad', 'Hyderabad', 22, 168, 176, 5, 3, 2, 1, 0, 87.20, 'minor_issues', false),
('2026-06-01'::date, 'ENG-003', 'Amit Patel', 'Yashoda Somajiguda', 'Hyderabad', 20, 155, 160, 8, 4, 3, 2, 1, 78.50, 'major_issues', true),
('2026-06-01'::date, 'ENG-004', 'Priya Sharma', 'Care Banjara', 'Hyderabad', 16, 128, 128, 1, 0, 0, 0, 0, 98.40, 'pass', false),
('2026-06-01'::date, 'ENG-005', 'Vikram Singh', 'Sunshine Paradise', 'Hyderabad', 24, 180, 192, 12, 6, 4, 3, 2, 65.80, 'fail', true),
('2026-06-01'::date, 'ENG-006', 'Anjali Nair', 'Manipal Vijayawada', 'Vijayawada', 19, 148, 152, 3, 2, 1, 1, 0, 91.30, 'pass', false),
('2026-06-01'::date, 'ENG-007', 'Rohit Verma', 'Aster Medcity Kochi', 'Kochi', 21, 158, 168, 6, 4, 2, 2, 1, 82.70, 'minor_issues', false),
('2026-06-01'::date, 'ENG-008', 'Kavya Iyer', 'Fortis Bannerghatta', 'Bangalore', 17, 132, 136, 4, 2, 1, 0, 0, 89.60, 'minor_issues', false),
('2026-06-01'::date, 'ENG-009', 'Sandeep Joshi', 'Narayana Mysore', 'Mysore', 23, 175, 184, 9, 5, 3, 2, 1, 76.10, 'major_issues', true),
('2026-06-01'::date, 'ENG-010', 'Meera Pillai', 'Rainbow Childrens', 'Hyderabad', 15, 118, 120, 2, 1, 0, 1, 0, 93.80, 'pass', false),
('2026-06-01'::date, 'ENG-011', 'Arjun Menon', 'Continental Gachibowli', 'Hyderabad', 20, 152, 160, 7, 3, 2, 1, 1, 81.40, 'minor_issues', false),
('2026-06-01'::date, 'ENG-012', 'Divya Krishnan', 'Star Hospitals', 'Hyderabad', 18, 140, 144, 3, 2, 1, 0, 0, 90.20, 'pass', false),
('2026-06-01'::date, 'ENG-013', 'Naveen Rao', 'Pace Hospital', 'Hyderabad', 22, 162, 176, 11, 6, 4, 3, 2, 68.50, 'fail', true),
('2026-06-01'::date, 'ENG-014', 'Lakshmi Devi', 'Care Hi-tech', 'Hyderabad', 16, 126, 128, 2, 1, 0, 0, 0, 95.70, 'pass', false),
('2026-06-01'::date, 'ENG-015', 'Karthik Reddy', 'Aware Gleneagles', 'Hyderabad', 21, 160, 168, 5, 3, 2, 1, 0, 86.90, 'minor_issues', false),
('2026-06-01'::date, 'ENG-016', 'Sunita Ghosh', 'Olive Hospitals', 'Hyderabad', 19, 146, 152, 6, 4, 2, 1, 1, 83.20, 'minor_issues', false),
('2026-06-01'::date, 'ENG-017', 'Pradeep Naidu', 'Citizens Specialty', 'Hyderabad', 17, 130, 136, 8, 5, 3, 2, 1, 71.80, 'major_issues', true),
('2026-06-01'::date, 'ENG-018', 'Neha Gupta', 'Asian Institute Gastro', 'Hyderabad', 20, 158, 160, 1, 1, 0, 0, 0, 97.50, 'pass', false);

INSERT INTO public.photo_audit_findings_r2910 (finding_date, engineer_code, engineer_name, hospital_name, finding_category, severity, description, remediation_status, resolved_at, coach_assigned, retraining_required) VALUES
('2026-06-02'::date, 'ENG-005', 'Vikram Singh', 'Sunshine Paradise', 'blurry', 'high', 'Anesthesia machine serial plate unreadable across 12 photos', 'in_progress', NULL, 'Coach Ramesh', true),
('2026-06-03'::date, 'ENG-005', 'Vikram Singh', 'Sunshine Paradise', 'geotag_mismatch', 'critical', 'GPS coordinates 800m off hospital geofence', 'escalated', NULL, 'Coach Ramesh', true),
('2026-06-04'::date, 'ENG-013', 'Naveen Rao', 'Pace Hospital', 'missing_before_after', 'high', 'Before/after pairs missing for 3 ventilators', 'open', NULL, 'Coach Suresh', true),
('2026-06-05'::date, 'ENG-013', 'Naveen Rao', 'Pace Hospital', 'wrong_angle', 'medium', 'Side-angle shots instead of front-facing for serial plates', 'in_progress', NULL, 'Coach Suresh', false),
('2026-06-06'::date, 'ENG-003', 'Amit Patel', 'Yashoda Somajiguda', 'blurry', 'medium', '8 photos rejected for motion blur', 'resolved', '2026-06-10 14:00:00+05:30'::timestamptz, 'Coach Lakshmi', false),
('2026-06-07'::date, 'ENG-003', 'Amit Patel', 'Yashoda Somajiguda', 'missing_serial', 'high', 'Defibrillator unit serial obscured by sticker', 'resolved', '2026-06-11 11:30:00+05:30'::timestamptz, 'Coach Lakshmi', false),
('2026-06-08'::date, 'ENG-009', 'Sandeep Joshi', 'Narayana Mysore', 'missing_before_after', 'high', 'Maintenance verification incomplete', 'in_progress', NULL, 'Coach Ramesh', true),
('2026-06-09'::date, 'ENG-009', 'Sandeep Joshi', 'Narayana Mysore', 'duplicate_upload', 'low', '3 identical photos uploaded twice', 'resolved', '2026-06-12 09:15:00+05:30'::timestamptz, NULL, false),
('2026-06-10'::date, 'ENG-017', 'Pradeep Naidu', 'Citizens Specialty', 'watermark_missing', 'medium', 'EquipSeva watermark stripped from 8 uploads', 'open', NULL, 'Coach Suresh', false),
('2026-06-11'::date, 'ENG-017', 'Pradeep Naidu', 'Citizens Specialty', 'timestamp_drift', 'high', 'Photo timestamps 4h before visit log entry', 'escalated', NULL, 'Coach Suresh', true),
('2026-06-12'::date, 'ENG-002', 'Sneha Reddy', 'KIMS Secunderabad', 'blurry', 'low', '5 photos minor blur but acceptable', 'resolved', '2026-06-13 16:20:00+05:30'::timestamptz, NULL, false),
('2026-06-13'::date, 'ENG-007', 'Rohit Verma', 'Aster Medcity Kochi', 'wrong_angle', 'medium', '4 angle issues on ultrasound machines', 'in_progress', NULL, 'Coach Lakshmi', false),
('2026-06-14'::date, 'ENG-011', 'Arjun Menon', 'Continental Gachibowli', 'missing_serial', 'medium', '2 serial numbers cropped out of frame', 'resolved', '2026-06-15 10:00:00+05:30'::timestamptz, NULL, false),
('2026-06-15'::date, 'ENG-016', 'Sunita Ghosh', 'Olive Hospitals', 'blurry', 'medium', '6 photos motion-blurred on portable X-ray', 'in_progress', NULL, 'Coach Ramesh', false),
('2026-06-16'::date, 'ENG-008', 'Kavya Iyer', 'Fortis Bannerghatta', 'blurry', 'low', '4 marginal blur cases', 'resolved', '2026-06-17 13:45:00+05:30'::timestamptz, NULL, false),
('2026-06-17'::date, 'ENG-015', 'Karthik Reddy', 'Aware Gleneagles', 'wrong_angle', 'low', '3 wrong-angle but identifiable', 'resolved', '2026-06-18 11:00:00+05:30'::timestamptz, NULL, false),
('2026-06-18'::date, 'ENG-005', 'Vikram Singh', 'Sunshine Paradise', 'missing_serial', 'critical', '4 critical-equipment serials missing entirely', 'escalated', NULL, 'Coach Ramesh', true),
('2026-06-19'::date, 'ENG-013', 'Naveen Rao', 'Pace Hospital', 'geotag_mismatch', 'high', 'GPS shows parking lot not equipment room', 'open', NULL, 'Coach Suresh', true),
('2026-06-20'::date, 'ENG-009', 'Sandeep Joshi', 'Narayana Mysore', 'timestamp_drift', 'medium', 'Photo timestamps 2h off visit window', 'in_progress', NULL, 'Coach Ramesh', false),
('2026-06-21'::date, 'ENG-017', 'Pradeep Naidu', 'Citizens Specialty', 'duplicate_upload', 'low', '5 photos uploaded across 2 separate visits', 'open', NULL, NULL, false);

-- =====================================================
-- RPC 1: KPI Summary
-- =====================================================
CREATE OR REPLACE FUNCTION public.r2910_kpi_summary()
RETURNS TABLE (
  metric text,
  value text,
  detail text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT 'Engineers Audited'::text, count(*)::text, 'this month'::text FROM photo_audit_submissions_r2910
  UNION ALL
  SELECT 'Avg Quality Score'::text, round(avg(quality_score),1)::text || '%', 'out of 100'::text FROM photo_audit_submissions_r2910
  UNION ALL
  SELECT 'Pass Rate'::text, round(100.0 * count(*) FILTER (WHERE reviewer_verdict='pass') / nullif(count(*),0), 1)::text || '%', 'engineers passing'::text FROM photo_audit_submissions_r2910
  UNION ALL
  SELECT 'Failing Engineers'::text, count(*) FILTER (WHERE reviewer_verdict='fail')::text, 'require retraining'::text FROM photo_audit_submissions_r2910
  UNION ALL
  SELECT 'Open Findings'::text, count(*) FILTER (WHERE remediation_status IN ('open','in_progress'))::text, 'unresolved'::text FROM photo_audit_findings_r2910
  UNION ALL
  SELECT 'Critical Findings'::text, count(*) FILTER (WHERE severity='critical')::text, 'escalation needed'::text FROM photo_audit_findings_r2910;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2910_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2910_kpi_summary() TO authenticated;

-- =====================================================
-- RPC 2: Engineer Quality Leaderboard
-- =====================================================
CREATE OR REPLACE FUNCTION public.r2910_engineer_leaderboard()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  hospital_name text,
  visits_completed int,
  photos_submitted int,
  quality_score numeric,
  reviewer_verdict text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.hospital_name, s.visits_completed, s.photos_submitted, s.quality_score, s.reviewer_verdict
  FROM photo_audit_submissions_r2910 s
  ORDER BY s.quality_score DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2910_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2910_engineer_leaderboard() TO authenticated;

-- =====================================================
-- RPC 3: Failing Engineers Requiring Rework
-- =====================================================
CREATE OR REPLACE FUNCTION public.r2910_failing_engineers()
RETURNS TABLE (
  engineer_code text,
  engineer_name text,
  hospital_name text,
  city text,
  quality_score numeric,
  blurry_count int,
  missing_serial_count int,
  geotag_mismatch_count int,
  reviewer_verdict text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.engineer_code, s.engineer_name, s.hospital_name, s.city, s.quality_score, s.blurry_count, s.missing_serial_count, s.geotag_mismatch_count, s.reviewer_verdict
  FROM photo_audit_submissions_r2910 s
  WHERE s.rework_required = true
  ORDER BY s.quality_score ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2910_failing_engineers() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2910_failing_engineers() TO authenticated;

-- =====================================================
-- RPC 4: Findings by Category
-- =====================================================
CREATE OR REPLACE FUNCTION public.r2910_findings_by_category()
RETURNS TABLE (
  finding_category text,
  total_count bigint,
  critical_count bigint,
  high_count bigint,
  open_count bigint,
  resolved_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    f.finding_category,
    count(*)::bigint,
    count(*) FILTER (WHERE f.severity='critical')::bigint,
    count(*) FILTER (WHERE f.severity='high')::bigint,
    count(*) FILTER (WHERE f.remediation_status='open')::bigint,
    count(*) FILTER (WHERE f.remediation_status='resolved')::bigint
  FROM photo_audit_findings_r2910 f
  GROUP BY f.finding_category
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2910_findings_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2910_findings_by_category() TO authenticated;

-- =====================================================
-- RPC 5: Critical & High Severity Findings
-- =====================================================
CREATE OR REPLACE FUNCTION public.r2910_critical_findings()
RETURNS TABLE (
  finding_date date,
  engineer_name text,
  hospital_name text,
  finding_category text,
  severity text,
  description text,
  remediation_status text,
  coach_assigned text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT f.finding_date, f.engineer_name, f.hospital_name, f.finding_category, f.severity, f.description, f.remediation_status, coalesce(f.coach_assigned,'unassigned')
  FROM photo_audit_findings_r2910 f
  WHERE f.severity IN ('critical','high')
  ORDER BY f.finding_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2910_critical_findings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2910_critical_findings() TO authenticated;

-- =====================================================
-- RPC 6: City Quality Rollup
-- =====================================================
CREATE OR REPLACE FUNCTION public.r2910_city_rollup()
RETURNS TABLE (
  city text,
  engineers int,
  avg_quality numeric,
  total_blurry bigint,
  total_missing_serial bigint,
  total_geotag_mismatch bigint,
  failing_engineers bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.city,
    count(*)::int,
    round(avg(s.quality_score),2),
    sum(s.blurry_count)::bigint,
    sum(s.missing_serial_count)::bigint,
    sum(s.geotag_mismatch_count)::bigint,
    count(*) FILTER (WHERE s.reviewer_verdict IN ('fail','major_issues'))::bigint
  FROM photo_audit_submissions_r2910 s
  GROUP BY s.city
  ORDER BY avg(s.quality_score) ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2910_city_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2910_city_rollup() TO authenticated;

-- =====================================================
-- RPC 7: Coach Workload
-- =====================================================
CREATE OR REPLACE FUNCTION public.r2910_coach_workload()
RETURNS TABLE (
  coach_assigned text,
  open_findings bigint,
  critical_findings bigint,
  retraining_cases bigint,
  resolved_findings bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    coalesce(f.coach_assigned,'unassigned'),
    count(*) FILTER (WHERE f.remediation_status IN ('open','in_progress'))::bigint,
    count(*) FILTER (WHERE f.severity='critical')::bigint,
    count(*) FILTER (WHERE f.retraining_required = true)::bigint,
    count(*) FILTER (WHERE f.remediation_status='resolved')::bigint
  FROM photo_audit_findings_r2910 f
  GROUP BY f.coach_assigned
  ORDER BY count(*) FILTER (WHERE f.remediation_status IN ('open','in_progress')) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.r2910_coach_workload() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2910_coach_workload() TO authenticated;
