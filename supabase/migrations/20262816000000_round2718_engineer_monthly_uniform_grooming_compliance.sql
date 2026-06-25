BEGIN;

-- ============================================================
-- Round 2718: Engineer Monthly Uniform & Grooming Compliance
-- Tables: ugc_inspections_r2718, ugc_violations_r2718
-- ============================================================

DROP TABLE IF EXISTS ugc_violations_r2718 CASCADE;
DROP TABLE IF EXISTS ugc_inspections_r2718 CASCADE;

CREATE TABLE ugc_inspections_r2718 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_code   text NOT NULL,
  engineer_name   text NOT NULL,
  region          text NOT NULL,
  inspection_date date NOT NULL,
  inspector_name  text NOT NULL,
  uniform_score   int  NOT NULL CHECK (uniform_score BETWEEN 0 AND 100),
  grooming_score  int  NOT NULL CHECK (grooming_score BETWEEN 0 AND 100),
  overall_score   int  NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
  outcome         text NOT NULL CHECK (outcome IN ('pass','warning','fail','exemplary')),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ugc_violations_r2718 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id   uuid NOT NULL REFERENCES ugc_inspections_r2718(id) ON DELETE CASCADE,
  category        text NOT NULL CHECK (category IN ('uniform','grooming','badge','footwear','hygiene')),
  severity        text NOT NULL CHECK (severity IN ('minor','moderate','major','critical')),
  description     text NOT NULL,
  corrective_action text NOT NULL,
  resolved        boolean NOT NULL DEFAULT false,
  resolved_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE ugc_inspections_r2718 ENABLE ROW LEVEL SECURITY;
ALTER TABLE ugc_violations_r2718  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON ugc_inspections_r2718;
CREATE POLICY founder_all ON ugc_inspections_r2718 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_all ON ugc_violations_r2718;
CREATE POLICY founder_all ON ugc_violations_r2718 FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Seed inspections (8 rows)
-- ============================================================
INSERT INTO ugc_inspections_r2718
  (id, engineer_code, engineer_name, region, inspection_date, inspector_name, uniform_score, grooming_score, overall_score, outcome, notes)
VALUES
  ('11111111-1111-1111-1111-111111111101'::uuid, 'ENG-001', 'Ravi Kumar',     'Hyderabad', '2026-06-01'::date, 'Suresh M.',  95, 92, 94, 'exemplary', 'Crisp uniform, ID badge prominent'),
  ('11111111-1111-1111-1111-111111111102'::uuid, 'ENG-002', 'Anita Sharma',   'Bengaluru', '2026-06-03'::date, 'Priya R.',   88, 90, 89, 'pass',      'Minor cuff stain noted'),
  ('11111111-1111-1111-1111-111111111103'::uuid, 'ENG-003', 'Vikram Singh',   'Mumbai',    '2026-06-05'::date, 'Rohan K.',   62, 70, 66, 'warning',   'Wrinkled shirt, missing name tag'),
  ('11111111-1111-1111-1111-111111111104'::uuid, 'ENG-004', 'Deepa Iyer',     'Chennai',   '2026-06-08'::date, 'Mahesh V.',  78, 82, 80, 'pass',      'Acceptable, shoes need polish'),
  ('11111111-1111-1111-1111-111111111105'::uuid, 'ENG-005', 'Karthik Nair',   'Hyderabad', '2026-06-10'::date, 'Suresh M.',  45, 55, 50, 'fail',      'No badge, untrimmed beard, dirty shoes'),
  ('11111111-1111-1111-1111-111111111106'::uuid, 'ENG-006', 'Pooja Reddy',    'Bengaluru', '2026-06-12'::date, 'Priya R.',   92, 95, 94, 'exemplary', 'Excellent presentation'),
  ('11111111-1111-1111-1111-111111111107'::uuid, 'ENG-007', 'Arjun Mehta',    'Delhi',     '2026-06-14'::date, 'Neeraj P.',  72, 68, 70, 'warning',   'Hair grooming below standard'),
  ('11111111-1111-1111-1111-111111111108'::uuid, 'ENG-008', 'Lakshmi Pillai', 'Chennai',   '2026-06-18'::date, 'Mahesh V.',  85, 88, 86, 'pass',      'Clean overall');

-- ============================================================
-- Seed violations (8 rows)
-- ============================================================
INSERT INTO ugc_violations_r2718
  (inspection_id, category, severity, description, corrective_action, resolved, resolved_at)
VALUES
  ('11111111-1111-1111-1111-111111111103'::uuid, 'uniform',  'moderate', 'Wrinkled shirt observed',           'Issue replacement uniform',           true,  '2026-06-07 10:00:00+05:30'),
  ('11111111-1111-1111-1111-111111111103'::uuid, 'badge',    'major',    'Missing employee name tag',         'Print + dispatch new badge',          true,  '2026-06-06 14:00:00+05:30'),
  ('11111111-1111-1111-1111-111111111105'::uuid, 'badge',    'critical', 'No badge on site visit',            'Suspend until badge confirmed',       false, NULL),
  ('11111111-1111-1111-1111-111111111105'::uuid, 'grooming', 'major',    'Untrimmed beard, unkempt hair',     'Counsel + grooming allowance',        false, NULL),
  ('11111111-1111-1111-1111-111111111105'::uuid, 'footwear', 'moderate', 'Dirty / scuffed safety shoes',      'Issue new safety shoes',              true,  '2026-06-15 11:00:00+05:30'),
  ('11111111-1111-1111-1111-111111111107'::uuid, 'grooming', 'minor',    'Hair length exceeds policy',        'Verbal warning + barber voucher',     true,  '2026-06-16 09:00:00+05:30'),
  ('11111111-1111-1111-1111-111111111104'::uuid, 'footwear', 'minor',    'Shoes need polish',                 'Provide polish kit',                  true,  '2026-06-10 12:00:00+05:30'),
  ('11111111-1111-1111-1111-111111111102'::uuid, 'uniform',  'minor',    'Cuff stain on shirt sleeve',        'Laundry voucher issued',              true,  '2026-06-04 16:00:00+05:30');

-- ============================================================
-- RPCs (8 SECDEF, plpgsql)
-- ============================================================

DROP FUNCTION IF EXISTS founder_ugc_overview_r2718();
CREATE FUNCTION founder_ugc_overview_r2718()
RETURNS TABLE (
  total_inspections int,
  exemplary_count   int,
  pass_count        int,
  warning_count     int,
  fail_count        int,
  avg_overall       numeric,
  open_violations   int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM ugc_inspections_r2718),
      (SELECT COUNT(*)::int FROM ugc_inspections_r2718 WHERE outcome = 'exemplary'),
      (SELECT COUNT(*)::int FROM ugc_inspections_r2718 WHERE outcome = 'pass'),
      (SELECT COUNT(*)::int FROM ugc_inspections_r2718 WHERE outcome = 'warning'),
      (SELECT COUNT(*)::int FROM ugc_inspections_r2718 WHERE outcome = 'fail'),
      (SELECT ROUND(AVG(overall_score)::numeric, 1) FROM ugc_inspections_r2718),
      (SELECT COUNT(*)::int FROM ugc_violations_r2718 WHERE NOT resolved);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_overview_r2718() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_overview_r2718() TO authenticated;

DROP FUNCTION IF EXISTS founder_ugc_inspections_r2718();
CREATE FUNCTION founder_ugc_inspections_r2718()
RETURNS TABLE (
  id uuid, engineer_code text, engineer_name text, region text,
  inspection_date date, inspector_name text,
  uniform_score int, grooming_score int, overall_score int, outcome text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.engineer_code, i.engineer_name, i.region,
           i.inspection_date, i.inspector_name,
           i.uniform_score, i.grooming_score, i.overall_score, i.outcome, i.notes
    FROM ugc_inspections_r2718 i
    ORDER BY i.inspection_date DESC, i.engineer_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_inspections_r2718() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_inspections_r2718() TO authenticated;

DROP FUNCTION IF EXISTS founder_ugc_violations_r2718();
CREATE FUNCTION founder_ugc_violations_r2718()
RETURNS TABLE (
  id uuid, engineer_code text, engineer_name text, category text, severity text,
  description text, corrective_action text, resolved boolean, resolved_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, i.engineer_code, i.engineer_name, v.category, v.severity,
           v.description, v.corrective_action, v.resolved, v.resolved_at
    FROM ugc_violations_r2718 v
    JOIN ugc_inspections_r2718 i ON i.id = v.inspection_id
    ORDER BY v.resolved, v.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_violations_r2718() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_violations_r2718() TO authenticated;

DROP FUNCTION IF EXISTS founder_ugc_region_breakdown_r2718();
CREATE FUNCTION founder_ugc_region_breakdown_r2718()
RETURNS TABLE (
  region text, inspections int, avg_uniform numeric, avg_grooming numeric,
  avg_overall numeric, fail_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.region,
           COUNT(*)::int,
           ROUND(AVG(i.uniform_score)::numeric, 1),
           ROUND(AVG(i.grooming_score)::numeric, 1),
           ROUND(AVG(i.overall_score)::numeric, 1),
           COUNT(*) FILTER (WHERE i.outcome = 'fail')::int
    FROM ugc_inspections_r2718 i
    GROUP BY i.region
    ORDER BY ROUND(AVG(i.overall_score)::numeric, 1) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_region_breakdown_r2718() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_region_breakdown_r2718() TO authenticated;

DROP FUNCTION IF EXISTS founder_ugc_category_severity_r2718();
CREATE FUNCTION founder_ugc_category_severity_r2718()
RETURNS TABLE (
  category text, severity text, total int, open_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.category, v.severity,
           COUNT(*)::int,
           COUNT(*) FILTER (WHERE NOT v.resolved)::int
    FROM ugc_violations_r2718 v
    GROUP BY v.category, v.severity
    ORDER BY v.category, v.severity;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_category_severity_r2718() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_category_severity_r2718() TO authenticated;

DROP FUNCTION IF EXISTS founder_ugc_top_offenders_r2718();
CREATE FUNCTION founder_ugc_top_offenders_r2718()
RETURNS TABLE (
  engineer_code text, engineer_name text, region text,
  inspections int, avg_overall numeric, violation_count int, open_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.engineer_code, i.engineer_name, i.region,
           COUNT(DISTINCT i.id)::int,
           ROUND(AVG(i.overall_score)::numeric, 1),
           COUNT(v.id)::int,
           COUNT(v.id) FILTER (WHERE v.resolved IS FALSE)::int
    FROM ugc_inspections_r2718 i
    LEFT JOIN ugc_violations_r2718 v ON v.inspection_id = i.id
    GROUP BY i.engineer_code, i.engineer_name, i.region
    ORDER BY ROUND(AVG(i.overall_score)::numeric, 1) ASC, COUNT(v.id) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_top_offenders_r2718() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_top_offenders_r2718() TO authenticated;

DROP FUNCTION IF EXISTS founder_ugc_corrective_status_r2718();
CREATE FUNCTION founder_ugc_corrective_status_r2718()
RETURNS TABLE (
  status text, total int, pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  grand int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO grand FROM ugc_violations_r2718;
  IF grand = 0 THEN grand := 1; END IF;
  RETURN QUERY
    SELECT 'resolved'::text, COUNT(*)::int,
           ROUND((COUNT(*)::numeric / grand) * 100, 1)
    FROM ugc_violations_r2718 WHERE resolved
    UNION ALL
    SELECT 'open'::text, COUNT(*)::int,
           ROUND((COUNT(*)::numeric / grand) * 100, 1)
    FROM ugc_violations_r2718 WHERE NOT resolved;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_corrective_status_r2718() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_corrective_status_r2718() TO authenticated;

DROP FUNCTION IF EXISTS founder_ugc_resolve_violation_r2718(uuid);
CREATE FUNCTION founder_ugc_resolve_violation_r2718(p_id uuid)
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  n int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE ugc_violations_r2718
     SET resolved = true, resolved_at = now()
   WHERE id = p_id AND NOT resolved;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_ugc_resolve_violation_r2718(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION founder_ugc_resolve_violation_r2718(uuid) TO authenticated;

COMMIT;
