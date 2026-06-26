BEGIN;

-- ============================================================================
-- Round 2876: Customer Monthly Engineer Bilingual Handover Effectiveness
-- engineer x customer x spoken language x clarity x adoption x refine action
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: bilingual handover sessions (one row per engineer-customer handover)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bilingual_handover_sessions_r2876 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_month date NOT NULL,
  engineer_name text NOT NULL,
  engineer_region text NOT NULL,
  customer_org text NOT NULL,
  customer_contact text NOT NULL,
  spoken_language text NOT NULL CHECK (spoken_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english_only')),
  secondary_language text NOT NULL CHECK (secondary_language IN ('english','hindi','none')),
  equipment_category text NOT NULL CHECK (equipment_category IN ('xray','ultrasound','ecg','ventilator','dental','autoclave','infusion_pump')),
  handover_minutes integer NOT NULL CHECK (handover_minutes >= 0),
  clarity_score numeric(4,2) NOT NULL CHECK (clarity_score >= 0 AND clarity_score <= 5),
  customer_repeat_back_pct numeric(5,2) NOT NULL CHECK (customer_repeat_back_pct >= 0 AND customer_repeat_back_pct <= 100),
  adoption_followup_pct numeric(5,2) NOT NULL CHECK (adoption_followup_pct >= 0 AND adoption_followup_pct <= 100),
  refine_action text NOT NULL CHECK (refine_action IN ('none','add_visuals','slow_down','use_local_dialect','add_takeaway_card','pair_translator','retrain_engineer')),
  refine_status text NOT NULL CHECK (refine_status IN ('open','in_progress','closed','blocked')),
  followup_repair_within_30d boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE bilingual_handover_sessions_r2876 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON bilingual_handover_sessions_r2876;
CREATE POLICY founder_all ON bilingual_handover_sessions_r2876
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO bilingual_handover_sessions_r2876
  (session_month, engineer_name, engineer_region, customer_org, customer_contact, spoken_language, secondary_language, equipment_category, handover_minutes, clarity_score, customer_repeat_back_pct, adoption_followup_pct, refine_action, refine_status, followup_repair_within_30d, notes)
VALUES
  ('2026-06-01'::date, 'Ravi Kumar', 'Hyderabad', 'Apollo Clinic Banjara', 'Dr Sharma', 'telugu', 'english', 'xray', 22, 4.60, 88.00, 82.50, 'none', 'closed', false, 'Smooth telugu handover'),
  ('2026-06-01'::date, 'Suresh Patil', 'Pune', 'Sahyadri Hospital', 'Mr Joshi', 'marathi', 'hindi', 'ultrasound', 35, 3.20, 55.00, 48.00, 'add_visuals', 'in_progress', true, 'Customer asked for visual cheat sheet'),
  ('2026-06-01'::date, 'Aisha Khan', 'Mumbai', 'Lilavati Cardiac Wing', 'Dr Mehta', 'hindi', 'english', 'ecg', 18, 4.85, 92.00, 90.00, 'none', 'closed', false, 'Bilingual perfect'),
  ('2026-06-01'::date, 'Manoj Reddy', 'Bengaluru', 'Manipal Whitefield', 'Sr Lakshmi', 'kannada', 'english', 'ventilator', 48, 2.90, 42.00, 38.50, 'pair_translator', 'open', true, 'Engineer kannada weak'),
  ('2026-06-01'::date, 'Pooja Iyer', 'Chennai', 'MIOT International', 'Dr Raghavan', 'tamil', 'english', 'dental', 26, 4.10, 76.00, 71.00, 'add_takeaway_card', 'in_progress', false, 'Asked for printed card'),
  ('2026-06-01'::date, 'Arjun Banerjee', 'Kolkata', 'AMRI Salt Lake', 'Mr Das', 'bengali', 'hindi', 'autoclave', 30, 3.75, 68.00, 60.00, 'slow_down', 'closed', false, 'Pacing too fast initially'),
  ('2026-06-01'::date, 'Vikram Singh', 'Delhi NCR', 'Max Saket', 'Dr Kapoor', 'hindi', 'english', 'infusion_pump', 24, 4.40, 84.00, 79.50, 'none', 'closed', false, 'Solid hindi-english mix'),
  ('2026-05-01'::date, 'Ravi Kumar', 'Hyderabad', 'KIMS Secunderabad', 'Dr Rao', 'telugu', 'english', 'ultrasound', 28, 4.20, 80.00, 74.00, 'add_takeaway_card', 'closed', false, 'Prior month baseline'),
  ('2026-05-01'::date, 'Manoj Reddy', 'Bengaluru', 'Fortis Bannerghatta', 'Sr Priya', 'kannada', 'english', 'xray', 40, 3.10, 50.00, 44.00, 'retrain_engineer', 'closed', true, 'Triggered retraining plan');

-- ----------------------------------------------------------------------------
-- Table 2: engineer monthly language scorecard
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_language_scorecard_r2876 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scorecard_month date NOT NULL,
  engineer_name text NOT NULL,
  primary_language text NOT NULL CHECK (primary_language IN ('hindi','telugu','tamil','kannada','marathi','bengali','english_only')),
  fluency_self_rated numeric(4,2) NOT NULL CHECK (fluency_self_rated >= 0 AND fluency_self_rated <= 5),
  fluency_customer_rated numeric(4,2) NOT NULL CHECK (fluency_customer_rated >= 0 AND fluency_customer_rated <= 5),
  sessions_count integer NOT NULL CHECK (sessions_count >= 0),
  avg_clarity_score numeric(4,2) NOT NULL CHECK (avg_clarity_score >= 0 AND avg_clarity_score <= 5),
  avg_adoption_pct numeric(5,2) NOT NULL CHECK (avg_adoption_pct >= 0 AND avg_adoption_pct <= 100),
  refine_actions_open integer NOT NULL DEFAULT 0 CHECK (refine_actions_open >= 0),
  coaching_track text NOT NULL CHECK (coaching_track IN ('none','peer_buddy','intensive_training','language_app','translator_pairing')),
  promotion_eligible boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scorecard_month, engineer_name, primary_language)
);

ALTER TABLE engineer_language_scorecard_r2876 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_language_scorecard_r2876;
CREATE POLICY founder_all ON engineer_language_scorecard_r2876
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_language_scorecard_r2876
  (scorecard_month, engineer_name, primary_language, fluency_self_rated, fluency_customer_rated, sessions_count, avg_clarity_score, avg_adoption_pct, refine_actions_open, coaching_track, promotion_eligible)
VALUES
  ('2026-06-01'::date, 'Ravi Kumar', 'telugu', 4.80, 4.65, 12, 4.55, 81.50, 0, 'none', true),
  ('2026-06-01'::date, 'Suresh Patil', 'marathi', 4.20, 3.40, 9, 3.30, 51.00, 2, 'peer_buddy', false),
  ('2026-06-01'::date, 'Aisha Khan', 'hindi', 4.90, 4.80, 14, 4.75, 88.00, 0, 'none', true),
  ('2026-06-01'::date, 'Manoj Reddy', 'kannada', 3.50, 2.95, 8, 2.95, 41.00, 3, 'intensive_training', false),
  ('2026-06-01'::date, 'Pooja Iyer', 'tamil', 4.30, 4.10, 11, 4.05, 72.00, 1, 'language_app', false),
  ('2026-06-01'::date, 'Arjun Banerjee', 'bengali', 4.10, 3.80, 10, 3.85, 62.00, 1, 'peer_buddy', false),
  ('2026-06-01'::date, 'Vikram Singh', 'hindi', 4.60, 4.45, 13, 4.40, 79.00, 0, 'none', true);

-- ============================================================================
-- RPC 1: KPI rollup for current month
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_kpis();
CREATE OR REPLACE FUNCTION founder_r2876_kpis()
RETURNS TABLE (
  total_sessions bigint,
  avg_clarity numeric,
  avg_adoption numeric,
  open_refines bigint,
  followup_repair_rate numeric,
  promotion_eligible_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM bilingual_handover_sessions_r2876 WHERE session_month = '2026-06-01'::date),
    (SELECT ROUND(AVG(clarity_score)::numeric, 2) FROM bilingual_handover_sessions_r2876 WHERE session_month = '2026-06-01'::date),
    (SELECT ROUND(AVG(adoption_followup_pct)::numeric, 2) FROM bilingual_handover_sessions_r2876 WHERE session_month = '2026-06-01'::date),
    (SELECT COUNT(*) FROM bilingual_handover_sessions_r2876 WHERE refine_status IN ('open','in_progress')),
    (SELECT ROUND(100.0 * SUM(CASE WHEN followup_repair_within_30d THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2) FROM bilingual_handover_sessions_r2876 WHERE session_month = '2026-06-01'::date),
    (SELECT COUNT(*) FROM engineer_language_scorecard_r2876 WHERE scorecard_month = '2026-06-01'::date AND promotion_eligible = true);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_kpis() TO authenticated;

-- ============================================================================
-- RPC 2: list current month sessions
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_sessions();
CREATE OR REPLACE FUNCTION founder_r2876_sessions()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  engineer_region text,
  customer_org text,
  spoken_language text,
  equipment_category text,
  handover_minutes integer,
  clarity_score numeric,
  adoption_followup_pct numeric,
  refine_action text,
  refine_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.id, s.engineer_name, s.engineer_region, s.customer_org, s.spoken_language, s.equipment_category,
         s.handover_minutes, s.clarity_score, s.adoption_followup_pct, s.refine_action, s.refine_status
  FROM bilingual_handover_sessions_r2876 s
  WHERE s.session_month = '2026-06-01'::date
  ORDER BY s.clarity_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_sessions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_sessions() TO authenticated;

-- ============================================================================
-- RPC 3: language breakdown
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_language_breakdown();
CREATE OR REPLACE FUNCTION founder_r2876_language_breakdown()
RETURNS TABLE (
  spoken_language text,
  session_count bigint,
  avg_clarity numeric,
  avg_adoption numeric,
  avg_repeat_back numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.spoken_language,
         COUNT(*)::bigint,
         ROUND(AVG(s.clarity_score)::numeric, 2),
         ROUND(AVG(s.adoption_followup_pct)::numeric, 2),
         ROUND(AVG(s.customer_repeat_back_pct)::numeric, 2)
  FROM bilingual_handover_sessions_r2876 s
  WHERE s.session_month = '2026-06-01'::date
  GROUP BY s.spoken_language
  ORDER BY AVG(s.clarity_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_language_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_language_breakdown() TO authenticated;

-- ============================================================================
-- RPC 4: engineer scorecard list
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_scorecards();
CREATE OR REPLACE FUNCTION founder_r2876_scorecards()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  primary_language text,
  fluency_self_rated numeric,
  fluency_customer_rated numeric,
  sessions_count integer,
  avg_clarity_score numeric,
  avg_adoption_pct numeric,
  refine_actions_open integer,
  coaching_track text,
  promotion_eligible boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT sc.id, sc.engineer_name, sc.primary_language, sc.fluency_self_rated, sc.fluency_customer_rated,
         sc.sessions_count, sc.avg_clarity_score, sc.avg_adoption_pct, sc.refine_actions_open,
         sc.coaching_track, sc.promotion_eligible
  FROM engineer_language_scorecard_r2876 sc
  WHERE sc.scorecard_month = '2026-06-01'::date
  ORDER BY sc.avg_clarity_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_scorecards() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_scorecards() TO authenticated;

-- ============================================================================
-- RPC 5: refine action funnel
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_refine_funnel();
CREATE OR REPLACE FUNCTION founder_r2876_refine_funnel()
RETURNS TABLE (
  refine_action text,
  refine_status text,
  count_sessions bigint,
  avg_clarity numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.refine_action, s.refine_status,
         COUNT(*)::bigint,
         ROUND(AVG(s.clarity_score)::numeric, 2)
  FROM bilingual_handover_sessions_r2876 s
  GROUP BY s.refine_action, s.refine_status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_refine_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_refine_funnel() TO authenticated;

-- ============================================================================
-- RPC 6: region rollup
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_region_rollup();
CREATE OR REPLACE FUNCTION founder_r2876_region_rollup()
RETURNS TABLE (
  engineer_region text,
  session_count bigint,
  avg_clarity numeric,
  avg_adoption numeric,
  followup_rate numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT s.engineer_region,
         COUNT(*)::bigint,
         ROUND(AVG(s.clarity_score)::numeric, 2),
         ROUND(AVG(s.adoption_followup_pct)::numeric, 2),
         ROUND(100.0 * SUM(CASE WHEN s.followup_repair_within_30d THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 2)
  FROM bilingual_handover_sessions_r2876 s
  WHERE s.session_month = '2026-06-01'::date
  GROUP BY s.engineer_region
  ORDER BY AVG(s.clarity_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_region_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_region_rollup() TO authenticated;

-- ============================================================================
-- RPC 7: coaching track distribution
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_coaching_distribution();
CREATE OR REPLACE FUNCTION founder_r2876_coaching_distribution()
RETURNS TABLE (
  coaching_track text,
  engineer_count bigint,
  avg_clarity numeric,
  avg_adoption numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT sc.coaching_track,
         COUNT(*)::bigint,
         ROUND(AVG(sc.avg_clarity_score)::numeric, 2),
         ROUND(AVG(sc.avg_adoption_pct)::numeric, 2)
  FROM engineer_language_scorecard_r2876 sc
  WHERE sc.scorecard_month = '2026-06-01'::date
  GROUP BY sc.coaching_track
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_coaching_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_coaching_distribution() TO authenticated;

-- ============================================================================
-- RPC 8: month-over-month delta for engineer
-- ============================================================================
DROP FUNCTION IF EXISTS founder_r2876_engineer_mom();
CREATE OR REPLACE FUNCTION founder_r2876_engineer_mom()
RETURNS TABLE (
  engineer_name text,
  cur_avg_clarity numeric,
  prev_avg_clarity numeric,
  clarity_delta numeric,
  cur_sessions bigint,
  prev_sessions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH cur AS (
    SELECT engineer_name, AVG(clarity_score) AS avg_clarity, COUNT(*) AS cnt
    FROM bilingual_handover_sessions_r2876
    WHERE session_month = '2026-06-01'::date
    GROUP BY engineer_name
  ),
  prev AS (
    SELECT engineer_name, AVG(clarity_score) AS avg_clarity, COUNT(*) AS cnt
    FROM bilingual_handover_sessions_r2876
    WHERE session_month = '2026-05-01'::date
    GROUP BY engineer_name
  )
  SELECT COALESCE(c.engineer_name, p.engineer_name) AS engineer_name,
         ROUND(COALESCE(c.avg_clarity, 0)::numeric, 2),
         ROUND(COALESCE(p.avg_clarity, 0)::numeric, 2),
         ROUND((COALESCE(c.avg_clarity,0) - COALESCE(p.avg_clarity,0))::numeric, 2),
         COALESCE(c.cnt, 0)::bigint,
         COALESCE(p.cnt, 0)::bigint
  FROM cur c
  FULL OUTER JOIN prev p ON c.engineer_name = p.engineer_name
  ORDER BY COALESCE(c.avg_clarity,0) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2876_engineer_mom() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2876_engineer_mom() TO authenticated;

COMMIT;
