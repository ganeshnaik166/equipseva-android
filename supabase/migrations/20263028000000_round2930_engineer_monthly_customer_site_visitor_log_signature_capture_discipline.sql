-- Round 2930: Engineer Monthly Customer Site Visitor-Log Signature Capture Discipline
-- HEAVY ★★★★ · 1500/50 milestone crossing

-- ============================================================
-- TABLE 1: engineer_site_visit_signatures_r2930
-- Per-visit signature capture record
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_site_visit_signatures_r2930 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid,
  hospital_org_id uuid,
  visit_date date NOT NULL,
  visit_purpose text NOT NULL,
  signature_captured boolean NOT NULL DEFAULT false,
  signature_method text NOT NULL,
  signature_quality_score numeric(4,2),
  signatory_name text,
  signatory_designation text,
  signatory_phone_last4 text,
  geo_verified boolean NOT NULL DEFAULT false,
  photo_attached boolean NOT NULL DEFAULT false,
  capture_lag_minutes integer,
  region text NOT NULL,
  tier text NOT NULL,
  notes text
);

ALTER TABLE engineer_site_visit_signatures_r2930 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- TABLE 2: engineer_monthly_signature_discipline_r2930
-- Per-engineer monthly rollup of capture discipline
-- ============================================================
CREATE TABLE IF NOT EXISTS engineer_monthly_signature_discipline_r2930 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid,
  cycle_month date NOT NULL,
  total_visits integer NOT NULL DEFAULT 0,
  signatures_captured integer NOT NULL DEFAULT 0,
  capture_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  avg_capture_lag_minutes numeric(6,2),
  avg_quality_score numeric(4,2),
  geo_verified_pct numeric(5,2),
  photo_attached_pct numeric(5,2),
  discipline_grade text NOT NULL,
  coaching_required boolean NOT NULL DEFAULT false,
  bonus_eligible boolean NOT NULL DEFAULT false,
  region text NOT NULL,
  tier text NOT NULL
);

ALTER TABLE engineer_monthly_signature_discipline_r2930 ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- SEED: visit signatures (20 rows)
-- ============================================================
INSERT INTO engineer_site_visit_signatures_r2930 (visit_date, visit_purpose, signature_captured, signature_method, signature_quality_score, signatory_name, signatory_designation, signatory_phone_last4, geo_verified, photo_attached, capture_lag_minutes, region, tier, notes) VALUES
('2026-06-01'::date, 'preventive_maintenance', true, 'tablet_stylus', 9.2, 'Dr Rao', 'Biomed HOD', '4521', true, true, 3, 'south', 'platinum', 'clean capture on-site'),
('2026-06-02'::date, 'breakdown_repair', true, 'tablet_finger', 7.4, 'Sister Lakshmi', 'Ward in-charge', '8832', true, true, 8, 'south', 'gold', 'finger sig acceptable'),
('2026-06-03'::date, 'amc_quarterly', false, 'none', NULL, NULL, NULL, NULL, false, false, NULL, 'north', 'silver', 'engineer left site before sign-off'),
('2026-06-04'::date, 'installation', true, 'tablet_stylus', 9.6, 'Dr Iyer', 'Director Tech Services', '1290', true, true, 2, 'south', 'platinum', 'immediate capture'),
('2026-06-05'::date, 'spare_replacement', true, 'tablet_finger', 6.8, 'Mr Khan', 'Maintenance Manager', '7711', true, false, 15, 'west', 'gold', 'photo missing'),
('2026-06-06'::date, 'preventive_maintenance', true, 'tablet_stylus', 8.9, 'Mrs Joshi', 'Biomed Officer', '4488', true, true, 5, 'west', 'platinum', NULL),
('2026-06-07'::date, 'breakdown_repair', false, 'verbal_only', NULL, 'Dr Mehta', 'CMO', '9921', false, true, NULL, 'east', 'silver', 'verbal sign-off only, dispute risk'),
('2026-06-08'::date, 'amc_quarterly', true, 'tablet_stylus', 9.0, 'Mr Singh', 'Procurement Head', '3344', true, true, 4, 'north', 'gold', 'clean'),
('2026-06-09'::date, 'preventive_maintenance', true, 'tablet_finger', 7.1, 'Sister Mary', 'OT Sister', '6677', true, true, 10, 'south', 'gold', NULL),
('2026-06-10'::date, 'breakdown_repair', true, 'tablet_stylus', 9.4, 'Dr Bose', 'HOD Radiology', '2255', true, true, 3, 'east', 'platinum', NULL),
('2026-06-11'::date, 'installation', true, 'tablet_stylus', 9.7, 'Mr Patel', 'Biomed Engineer', '0988', true, true, 2, 'west', 'platinum', NULL),
('2026-06-12'::date, 'spare_replacement', false, 'none', NULL, NULL, NULL, NULL, false, false, NULL, 'north', 'bronze', 'no capture - second offense'),
('2026-06-13'::date, 'amc_quarterly', true, 'tablet_finger', 6.4, 'Mr Reddy', 'Admin', '5566', false, true, 22, 'south', 'silver', 'GPS off, late capture'),
('2026-06-14'::date, 'preventive_maintenance', true, 'tablet_stylus', 9.1, 'Dr Nair', 'Biomed HOD', '7788', true, true, 4, 'south', 'platinum', NULL),
('2026-06-15'::date, 'breakdown_repair', true, 'tablet_finger', 7.8, 'Sister Anita', 'ICU Sister', '1122', true, true, 7, 'north', 'gold', NULL),
('2026-06-16'::date, 'preventive_maintenance', true, 'tablet_stylus', 8.6, 'Mr Verma', 'Maintenance', '3399', true, true, 5, 'east', 'gold', NULL),
('2026-06-17'::date, 'amc_quarterly', false, 'verbal_only', NULL, 'Dr Shah', 'CMO', '8866', false, false, NULL, 'west', 'silver', 'walked out before sig'),
('2026-06-18'::date, 'installation', true, 'tablet_stylus', 9.8, 'Mr Gupta', 'Director Tech', '4477', true, true, 1, 'north', 'platinum', 'gold standard capture'),
('2026-06-19'::date, 'spare_replacement', true, 'tablet_finger', 6.9, 'Sister Priya', 'Pharmacy Head', '2266', true, true, 12, 'south', 'silver', NULL),
('2026-06-20'::date, 'preventive_maintenance', true, 'tablet_stylus', 9.3, 'Dr Kapoor', 'Biomed HOD', '5599', true, true, 3, 'west', 'platinum', NULL);

-- ============================================================
-- SEED: monthly rollups (16 rows)
-- ============================================================
INSERT INTO engineer_monthly_signature_discipline_r2930 (cycle_month, total_visits, signatures_captured, capture_rate_pct, avg_capture_lag_minutes, avg_quality_score, geo_verified_pct, photo_attached_pct, discipline_grade, coaching_required, bonus_eligible, region, tier) VALUES
('2026-05-01'::date, 22, 22, 100.00, 3.20, 9.30, 100.00, 100.00, 'A+', false, true,  'south', 'platinum'),
('2026-05-01'::date, 18, 17, 94.44,  5.80, 8.40,  94.44,  88.89, 'A',  false, true,  'south', 'gold'),
('2026-05-01'::date, 25, 19, 76.00, 14.20, 7.20,  72.00,  68.00, 'C',  true,  false, 'north', 'silver'),
('2026-05-01'::date, 14, 9,  64.29, 22.10, 6.10,  57.14,  50.00, 'D',  true,  false, 'north', 'bronze'),
('2026-05-01'::date, 20, 20, 100.00, 2.80, 9.50, 100.00, 100.00, 'A+', false, true,  'west',  'platinum'),
('2026-05-01'::date, 16, 14, 87.50,  8.40, 8.10,  87.50,  81.25, 'B',  false, true,  'west',  'gold'),
('2026-05-01'::date, 12, 7,  58.33, 25.50, 5.80,  50.00,  41.67, 'D',  true,  false, 'east',  'silver'),
('2026-05-01'::date, 19, 18, 94.74,  4.60, 8.90,  94.74,  89.47, 'A',  false, true,  'east',  'gold'),
('2026-06-01'::date, 24, 24, 100.00, 2.90, 9.40, 100.00, 100.00, 'A+', false, true,  'south', 'platinum'),
('2026-06-01'::date, 17, 15, 88.24,  9.10, 7.60,  82.35,  76.47, 'B',  false, true,  'south', 'gold'),
('2026-06-01'::date, 21, 16, 76.19, 13.80, 7.10,  71.43,  66.67, 'C',  true,  false, 'north', 'silver'),
('2026-06-01'::date, 13, 8,  61.54, 20.40, 6.20,  53.85,  46.15, 'D',  true,  false, 'north', 'bronze'),
('2026-06-01'::date, 22, 22, 100.00, 2.40, 9.60, 100.00, 100.00, 'A+', false, true,  'west',  'platinum'),
('2026-06-01'::date, 15, 13, 86.67,  8.90, 8.00,  86.67,  80.00, 'B',  false, true,  'west',  'gold'),
('2026-06-01'::date, 11, 6,  54.55, 28.20, 5.50,  45.45,  36.36, 'D',  true,  false, 'east',  'silver'),
('2026-06-01'::date, 20, 19, 95.00,  4.20, 8.80,  95.00,  90.00, 'A',  false, true,  'east',  'gold');

-- ============================================================
-- RPC 1: capture rate distribution by grade
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_grade_distribution()
RETURNS TABLE(discipline_grade text, engineers_count integer, avg_capture_rate numeric, avg_quality numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.discipline_grade,
           count(*)::int,
           round(avg(m.capture_rate_pct), 2),
           round(avg(m.avg_quality_score), 2)
      FROM engineer_monthly_signature_discipline_r2930 m
     GROUP BY m.discipline_grade
     ORDER BY m.discipline_grade;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_grade_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_grade_distribution() TO authenticated;

-- ============================================================
-- RPC 2: visits missing signatures (compliance gap)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_missing_signatures()
RETURNS TABLE(visit_date date, visit_purpose text, region text, tier text, signature_method text, notes text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.visit_date, v.visit_purpose, v.region, v.tier, v.signature_method, v.notes
      FROM engineer_site_visit_signatures_r2930 v
     WHERE v.signature_captured = false
     ORDER BY v.visit_date DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_missing_signatures() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_missing_signatures() TO authenticated;

-- ============================================================
-- RPC 3: regional discipline scorecard
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_regional_scorecard()
RETURNS TABLE(region text, rollups integer, avg_capture_rate numeric, avg_geo_verified_pct numeric, coaching_count integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.region,
           count(*)::int,
           round(avg(m.capture_rate_pct), 2),
           round(avg(m.geo_verified_pct), 2),
           (count(*) filter (where m.coaching_required))::int
      FROM engineer_monthly_signature_discipline_r2930 m
     GROUP BY m.region
     ORDER BY avg(m.capture_rate_pct) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_regional_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_regional_scorecard() TO authenticated;

-- ============================================================
-- RPC 4: method breakdown
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_method_breakdown()
RETURNS TABLE(signature_method text, visits integer, avg_quality numeric, avg_lag_minutes numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.signature_method,
           count(*)::int,
           round(avg(v.signature_quality_score), 2),
           round(avg(v.capture_lag_minutes), 2)
      FROM engineer_site_visit_signatures_r2930 v
     GROUP BY v.signature_method
     ORDER BY count(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_method_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_method_breakdown() TO authenticated;

-- ============================================================
-- RPC 5: bonus eligibility funnel
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_bonus_funnel()
RETURNS TABLE(cycle_month date, total_rollups integer, bonus_eligible integer, coaching_required integer, bonus_rate_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.cycle_month,
           count(*)::int,
           (count(*) filter (where m.bonus_eligible))::int,
           (count(*) filter (where m.coaching_required))::int,
           round(100.0 * (count(*) filter (where m.bonus_eligible))::numeric / nullif(count(*), 0), 2)
      FROM engineer_monthly_signature_discipline_r2930 m
     GROUP BY m.cycle_month
     ORDER BY m.cycle_month DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_bonus_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_bonus_funnel() TO authenticated;

-- ============================================================
-- RPC 6: capture lag percentiles
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_lag_percentiles()
RETURNS TABLE(p50_lag numeric, p75_lag numeric, p90_lag numeric, p95_lag numeric, worst_lag integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      round(percentile_cont(0.50) within group (order by v.capture_lag_minutes)::numeric, 2),
      round(percentile_cont(0.75) within group (order by v.capture_lag_minutes)::numeric, 2),
      round(percentile_cont(0.90) within group (order by v.capture_lag_minutes)::numeric, 2),
      round(percentile_cont(0.95) within group (order by v.capture_lag_minutes)::numeric, 2),
      max(v.capture_lag_minutes)
      FROM engineer_site_visit_signatures_r2930 v
     WHERE v.capture_lag_minutes IS NOT NULL;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_lag_percentiles() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_lag_percentiles() TO authenticated;

-- ============================================================
-- RPC 7: tier vs capture rate
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_tier_capture_curve()
RETURNS TABLE(tier text, rollups integer, avg_capture_rate numeric, avg_quality numeric, bonus_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.tier,
           count(*)::int,
           round(avg(m.capture_rate_pct), 2),
           round(avg(m.avg_quality_score), 2),
           round(100.0 * (count(*) filter (where m.bonus_eligible))::numeric / nullif(count(*), 0), 2)
      FROM engineer_monthly_signature_discipline_r2930 m
     GROUP BY m.tier
     ORDER BY avg(m.capture_rate_pct) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_tier_capture_curve() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_tier_capture_curve() TO authenticated;

-- ============================================================
-- RPC 8: recent visits roll
-- ============================================================
CREATE OR REPLACE FUNCTION founder_r2930_recent_visits()
RETURNS TABLE(visit_date date, visit_purpose text, region text, tier text, signature_captured boolean, signature_quality_score numeric, capture_lag_minutes integer, signatory_designation text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.visit_date, v.visit_purpose, v.region, v.tier,
           v.signature_captured, v.signature_quality_score,
           v.capture_lag_minutes, v.signatory_designation
      FROM engineer_site_visit_signatures_r2930 v
     ORDER BY v.visit_date DESC
     LIMIT 30;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2930_recent_visits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2930_recent_visits() TO authenticated;
