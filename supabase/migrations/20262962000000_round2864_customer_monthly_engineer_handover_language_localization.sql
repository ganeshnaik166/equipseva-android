BEGIN;

-- ============================================================================
-- Round 2864: Customer Monthly Engineer Handover Language Localization
-- engineer x customer x language x translation quality x comprehension x outcome
-- ============================================================================

-- Table 1: handover sessions (engineer -> customer monthly handover in local language)
CREATE TABLE IF NOT EXISTS customer_handover_sessions_r2864 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_code text NOT NULL UNIQUE,
  engineer_name text NOT NULL,
  engineer_id_code text NOT NULL,
  customer_org text NOT NULL,
  customer_city text NOT NULL,
  device_category text NOT NULL,
  source_language text NOT NULL CHECK (source_language IN ('english','hindi','telugu','tamil','kannada','marathi','bengali','gujarati')),
  target_language text NOT NULL CHECK (target_language IN ('english','hindi','telugu','tamil','kannada','marathi','bengali','gujarati')),
  translation_method text NOT NULL CHECK (translation_method IN ('human','machine','hybrid','engineer_native')),
  translation_quality_score numeric(4,2) NOT NULL CHECK (translation_quality_score BETWEEN 0 AND 5),
  comprehension_score numeric(4,2) NOT NULL CHECK (comprehension_score BETWEEN 0 AND 5),
  customer_satisfaction numeric(4,2) NOT NULL CHECK (customer_satisfaction BETWEEN 0 AND 5),
  handover_duration_minutes int NOT NULL CHECK (handover_duration_minutes >= 0),
  follow_up_calls int NOT NULL DEFAULT 0 CHECK (follow_up_calls >= 0),
  outcome text NOT NULL CHECK (outcome IN ('clear','partial','escalated','retranslate','rebooked')),
  handover_month date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE customer_handover_sessions_r2864 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON customer_handover_sessions_r2864;
CREATE POLICY founder_all ON customer_handover_sessions_r2864
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO customer_handover_sessions_r2864 (session_code, engineer_name, engineer_id_code, customer_org, customer_city, device_category, source_language, target_language, translation_method, translation_quality_score, comprehension_score, customer_satisfaction, handover_duration_minutes, follow_up_calls, outcome, handover_month) VALUES
('HND-001', 'Ravi Kumar', 'ENG-1024', 'Sunrise Multispecialty', 'Hyderabad', 'ventilator', 'english', 'telugu', 'engineer_native', 4.80, 4.70, 4.65, 38, 0, 'clear', '2026-06-01'::date),
('HND-002', 'Pradeep Reddy', 'ENG-1031', 'Apollo Spectra', 'Chennai', 'dialysis_unit', 'english', 'tamil', 'engineer_native', 4.70, 4.55, 4.50, 42, 1, 'clear', '2026-06-01'::date),
('HND-003', 'Sanjay Patel', 'ENG-1042', 'Sterling Hospitals', 'Ahmedabad', 'ct_scanner', 'english', 'gujarati', 'hybrid', 4.20, 3.80, 3.90, 55, 2, 'partial', '2026-06-01'::date),
('HND-004', 'Arjun Nair', 'ENG-1058', 'KIMS Healthcare', 'Bengaluru', 'mri_scanner', 'english', 'kannada', 'machine', 3.10, 2.80, 2.95, 68, 4, 'retranslate', '2026-06-01'::date),
('HND-005', 'Vikram Iyer', 'ENG-1067', 'Fortis Memorial', 'Mumbai', 'ultrasound', 'english', 'marathi', 'human', 4.55, 4.35, 4.40, 45, 1, 'clear', '2026-06-01'::date),
('HND-006', 'Rohit Sharma', 'ENG-1073', 'AIIMS Patna', 'Patna', 'x_ray', 'english', 'hindi', 'engineer_native', 4.90, 4.80, 4.85, 32, 0, 'clear', '2026-06-01'::date),
('HND-007', 'Subroto Das', 'ENG-1081', 'AMRI Hospitals', 'Kolkata', 'ecg_machine', 'english', 'bengali', 'hybrid', 4.10, 3.95, 4.05, 48, 1, 'partial', '2026-06-01'::date),
('HND-008', 'Manoj Joshi', 'ENG-1092', 'Tata Cancer Center', 'Mumbai', 'linear_accelerator', 'english', 'marathi', 'machine', 2.80, 2.40, 2.50, 75, 5, 'escalated', '2026-06-01'::date);

-- Table 2: language localization quality metrics per region
CREATE TABLE IF NOT EXISTS handover_language_quality_r2864 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language_code text NOT NULL CHECK (language_code IN ('hindi','telugu','tamil','kannada','marathi','bengali','gujarati')),
  region text NOT NULL,
  total_handovers int NOT NULL CHECK (total_handovers >= 0),
  avg_quality_score numeric(4,2) NOT NULL CHECK (avg_quality_score BETWEEN 0 AND 5),
  avg_comprehension numeric(4,2) NOT NULL CHECK (avg_comprehension BETWEEN 0 AND 5),
  native_engineer_pct numeric(5,2) NOT NULL CHECK (native_engineer_pct BETWEEN 0 AND 100),
  machine_fallback_pct numeric(5,2) NOT NULL CHECK (machine_fallback_pct BETWEEN 0 AND 100),
  retranslate_rate_pct numeric(5,2) NOT NULL CHECK (retranslate_rate_pct BETWEEN 0 AND 100),
  glossary_terms_loaded int NOT NULL CHECK (glossary_terms_loaded >= 0),
  status text NOT NULL CHECK (status IN ('healthy','watch','gap','critical')),
  observed_month date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE handover_language_quality_r2864 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON handover_language_quality_r2864;
CREATE POLICY founder_all ON handover_language_quality_r2864
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO handover_language_quality_r2864 (language_code, region, total_handovers, avg_quality_score, avg_comprehension, native_engineer_pct, machine_fallback_pct, retranslate_rate_pct, glossary_terms_loaded, status, observed_month) VALUES
('telugu', 'Andhra & Telangana', 142, 4.65, 4.55, 78.50, 8.20, 3.50, 1280, 'healthy', '2026-06-01'::date),
('tamil', 'Tamil Nadu', 128, 4.55, 4.45, 72.30, 10.50, 4.20, 1150, 'healthy', '2026-06-01'::date),
('hindi', 'North India', 215, 4.75, 4.70, 85.40, 5.20, 2.10, 1620, 'healthy', '2026-06-01'::date),
('marathi', 'Maharashtra', 98, 3.95, 3.75, 58.20, 22.40, 12.50, 850, 'watch', '2026-06-01'::date),
('kannada', 'Karnataka', 76, 3.20, 2.95, 35.80, 38.50, 22.40, 480, 'gap', '2026-06-01'::date),
('bengali', 'West Bengal', 64, 4.05, 3.85, 62.50, 18.20, 9.80, 720, 'watch', '2026-06-01'::date),
('gujarati', 'Gujarat', 58, 4.25, 4.10, 68.40, 14.50, 7.20, 880, 'healthy', '2026-06-01'::date);

-- ============================================================================
-- RPCs (7+ SECDEF, founder-gated)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_r2864_overview();
CREATE FUNCTION founder_r2864_overview()
RETURNS TABLE (
  total_handovers bigint,
  avg_quality numeric,
  avg_comprehension numeric,
  avg_satisfaction numeric,
  clear_outcome_pct numeric,
  retranslate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    ROUND(AVG(translation_quality_score)::numeric, 2),
    ROUND(AVG(comprehension_score)::numeric, 2),
    ROUND(AVG(customer_satisfaction)::numeric, 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE outcome = 'clear') / NULLIF(COUNT(*),0), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE outcome IN ('retranslate','escalated')) / NULLIF(COUNT(*),0), 2)
  FROM customer_handover_sessions_r2864;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_overview() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2864_by_language();
CREATE FUNCTION founder_r2864_by_language()
RETURNS TABLE (
  target_language text,
  sessions bigint,
  avg_quality numeric,
  avg_comprehension numeric,
  avg_duration numeric,
  outcome_clear bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.target_language,
    COUNT(*)::bigint,
    ROUND(AVG(s.translation_quality_score)::numeric, 2),
    ROUND(AVG(s.comprehension_score)::numeric, 2),
    ROUND(AVG(s.handover_duration_minutes)::numeric, 1),
    COUNT(*) FILTER (WHERE s.outcome = 'clear')::bigint
  FROM customer_handover_sessions_r2864 s
  GROUP BY s.target_language
  ORDER BY AVG(s.translation_quality_score) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_by_language() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_by_language() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2864_by_method();
CREATE FUNCTION founder_r2864_by_method()
RETURNS TABLE (
  translation_method text,
  sessions bigint,
  avg_quality numeric,
  avg_satisfaction numeric,
  avg_followups numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.translation_method,
    COUNT(*)::bigint,
    ROUND(AVG(s.translation_quality_score)::numeric, 2),
    ROUND(AVG(s.customer_satisfaction)::numeric, 2),
    ROUND(AVG(s.follow_up_calls)::numeric, 2)
  FROM customer_handover_sessions_r2864 s
  GROUP BY s.translation_method
  ORDER BY AVG(s.translation_quality_score) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_by_method() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_by_method() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2864_region_quality();
CREATE FUNCTION founder_r2864_region_quality()
RETURNS TABLE (
  language_code text,
  region text,
  total_handovers int,
  avg_quality_score numeric,
  native_engineer_pct numeric,
  retranslate_rate_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.language_code, q.region, q.total_handovers,
    q.avg_quality_score, q.native_engineer_pct,
    q.retranslate_rate_pct, q.status
  FROM handover_language_quality_r2864 q
  ORDER BY q.avg_quality_score ASC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_region_quality() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_region_quality() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2864_at_risk();
CREATE FUNCTION founder_r2864_at_risk()
RETURNS TABLE (
  session_code text,
  engineer_name text,
  customer_org text,
  target_language text,
  quality_score numeric,
  comprehension_score numeric,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.session_code, s.engineer_name, s.customer_org, s.target_language,
    s.translation_quality_score, s.comprehension_score, s.outcome
  FROM customer_handover_sessions_r2864 s
  WHERE s.translation_quality_score < 4.0 OR s.outcome IN ('retranslate','escalated','rebooked')
  ORDER BY s.translation_quality_score ASC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_at_risk() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2864_engineer_leaderboard();
CREATE FUNCTION founder_r2864_engineer_leaderboard()
RETURNS TABLE (
  engineer_name text,
  engineer_id_code text,
  sessions bigint,
  avg_quality numeric,
  avg_satisfaction numeric,
  clear_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.engineer_name, s.engineer_id_code,
    COUNT(*)::bigint,
    ROUND(AVG(s.translation_quality_score)::numeric, 2),
    ROUND(AVG(s.customer_satisfaction)::numeric, 2),
    COUNT(*) FILTER (WHERE s.outcome = 'clear')::bigint
  FROM customer_handover_sessions_r2864 s
  GROUP BY s.engineer_name, s.engineer_id_code
  ORDER BY AVG(s.translation_quality_score) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_engineer_leaderboard() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2864_glossary_gaps();
CREATE FUNCTION founder_r2864_glossary_gaps()
RETURNS TABLE (
  language_code text,
  region text,
  glossary_terms_loaded int,
  machine_fallback_pct numeric,
  gap_severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    q.language_code, q.region, q.glossary_terms_loaded, q.machine_fallback_pct,
    CASE
      WHEN q.glossary_terms_loaded < 600 THEN 'critical'
      WHEN q.glossary_terms_loaded < 1000 THEN 'gap'
      WHEN q.glossary_terms_loaded < 1400 THEN 'watch'
      ELSE 'healthy'
    END
  FROM handover_language_quality_r2864 q
  ORDER BY q.glossary_terms_loaded ASC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_glossary_gaps() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_glossary_gaps() TO authenticated;

DROP FUNCTION IF EXISTS founder_r2864_outcome_mix();
CREATE FUNCTION founder_r2864_outcome_mix()
RETURNS TABLE (
  outcome text,
  sessions bigint,
  share_pct numeric,
  avg_followups numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total_count bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_count FROM customer_handover_sessions_r2864;
  RETURN QUERY
  SELECT
    s.outcome,
    COUNT(*)::bigint,
    ROUND(100.0 * COUNT(*) / NULLIF(total_count,0), 2),
    ROUND(AVG(s.follow_up_calls)::numeric, 2)
  FROM customer_handover_sessions_r2864 s
  GROUP BY s.outcome
  ORDER BY COUNT(*) DESC;
END $$;

REVOKE EXECUTE ON FUNCTION founder_r2864_outcome_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2864_outcome_mix() TO authenticated;

COMMIT;
