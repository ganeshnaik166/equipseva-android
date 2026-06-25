BEGIN;

-- =====================================================================
-- Round 2730 — Engineer Monthly Mentee Pairing Effectiveness
-- mentor x mentee x hours x skill jump x csat x pairing verdict
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: monthly mentor-mentee pairing scorecards
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_monthly_mentee_pairings_r2730 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pairing_month date NOT NULL,
  mentor_name text NOT NULL,
  mentor_tier text NOT NULL CHECK (mentor_tier IN ('platinum','gold','silver','bronze')),
  mentee_name text NOT NULL,
  mentee_tier_before text NOT NULL CHECK (mentee_tier_before IN ('bronze','silver','gold','platinum')),
  mentee_tier_after text NOT NULL CHECK (mentee_tier_after IN ('bronze','silver','gold','platinum')),
  hours_spent numeric(6,2) NOT NULL CHECK (hours_spent >= 0),
  shadow_jobs_completed int NOT NULL DEFAULT 0 CHECK (shadow_jobs_completed >= 0),
  solo_jobs_completed int NOT NULL DEFAULT 0 CHECK (solo_jobs_completed >= 0),
  skill_score_before numeric(4,2) NOT NULL CHECK (skill_score_before BETWEEN 0 AND 10),
  skill_score_after numeric(4,2) NOT NULL CHECK (skill_score_after BETWEEN 0 AND 10),
  csat_mentor_rating numeric(3,2) NOT NULL CHECK (csat_mentor_rating BETWEEN 0 AND 5),
  csat_mentee_rating numeric(3,2) NOT NULL CHECK (csat_mentee_rating BETWEEN 0 AND 5),
  pairing_verdict text NOT NULL CHECK (pairing_verdict IN ('extend','continue','reassign','terminate')),
  founder_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_monthly_mentee_pairings_r2730 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_monthly_mentee_pairings_r2730;
CREATE POLICY founder_all ON engineer_monthly_mentee_pairings_r2730
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_monthly_mentee_pairings_r2730
  (pairing_month, mentor_name, mentor_tier, mentee_name, mentee_tier_before, mentee_tier_after,
   hours_spent, shadow_jobs_completed, solo_jobs_completed,
   skill_score_before, skill_score_after, csat_mentor_rating, csat_mentee_rating,
   pairing_verdict, founder_notes)
VALUES
  ('2026-06-01'::date, 'Ravi Kumar', 'platinum', 'Anil Reddy', 'bronze', 'silver',
   42.50, 12, 7, 4.20, 6.80, 4.80, 4.90, 'extend', 'best in cohort - mentor produces lift fast'),
  ('2026-06-01'::date, 'Suresh Iyer', 'gold', 'Pravin Sharma', 'silver', 'gold',
   38.00, 9, 11, 5.80, 7.60, 4.50, 4.60, 'continue', 'steady jump - keep pair through Q3'),
  ('2026-06-01'::date, 'Manoj Patel', 'gold', 'Vikram Singh', 'bronze', 'bronze',
   28.50, 6, 3, 4.00, 4.40, 3.20, 2.80, 'reassign', 'mentor style mismatch - try Suresh next month'),
  ('2026-06-01'::date, 'Deepak Rao', 'platinum', 'Karthik Naidu', 'silver', 'gold',
   45.00, 14, 9, 5.50, 7.90, 4.90, 4.85, 'extend', 'platinum mentor pulling silver into gold - flagship pair'),
  ('2026-06-01'::date, 'Asha Menon', 'silver', 'Rahul Verma', 'bronze', 'bronze',
   18.00, 4, 2, 3.80, 3.90, 2.90, 2.70, 'terminate', 'silver mentor not equipped - kill pair'),
  ('2026-06-01'::date, 'Vikrant Joshi', 'gold', 'Sneha Pillai', 'bronze', 'silver',
   36.00, 10, 6, 4.50, 6.20, 4.40, 4.55, 'continue', 'solid bronze to silver - hold pair'),
  ('2026-06-01'::date, 'Rohan Desai', 'platinum', 'Tejas Bhat', 'gold', 'platinum',
   40.00, 8, 14, 7.50, 9.10, 4.95, 4.90, 'extend', 'gold to platinum in one month - rare event');

-- ---------------------------------------------------------------------
-- Table 2: skill area drilldown per pairing
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engineer_pairing_skill_breakdown_r2730 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pairing_id uuid NOT NULL REFERENCES engineer_monthly_mentee_pairings_r2730(id) ON DELETE CASCADE,
  skill_area text NOT NULL CHECK (skill_area IN ('diagnostics','repair','calibration','customer_handling','compliance','escalation')),
  proficiency_before numeric(4,2) NOT NULL CHECK (proficiency_before BETWEEN 0 AND 10),
  proficiency_after numeric(4,2) NOT NULL CHECK (proficiency_after BETWEEN 0 AND 10),
  practice_jobs int NOT NULL DEFAULT 0 CHECK (practice_jobs >= 0),
  mentor_signoff boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE engineer_pairing_skill_breakdown_r2730 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON engineer_pairing_skill_breakdown_r2730;
CREATE POLICY founder_all ON engineer_pairing_skill_breakdown_r2730
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO engineer_pairing_skill_breakdown_r2730
  (pairing_id, skill_area, proficiency_before, proficiency_after, practice_jobs, mentor_signoff)
SELECT id, 'diagnostics', 4.0, 6.5, 5, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Anil Reddy'
UNION ALL
SELECT id, 'repair', 4.2, 6.8, 7, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Anil Reddy'
UNION ALL
SELECT id, 'calibration', 5.5, 7.5, 6, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Pravin Sharma'
UNION ALL
SELECT id, 'customer_handling', 6.0, 7.8, 4, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Pravin Sharma'
UNION ALL
SELECT id, 'diagnostics', 4.0, 4.5, 2, false FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Vikram Singh'
UNION ALL
SELECT id, 'repair', 5.5, 8.0, 8, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Karthik Naidu'
UNION ALL
SELECT id, 'escalation', 5.0, 7.5, 5, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Karthik Naidu'
UNION ALL
SELECT id, 'compliance', 3.8, 3.9, 1, false FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Rahul Verma'
UNION ALL
SELECT id, 'diagnostics', 4.5, 6.5, 6, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Sneha Pillai'
UNION ALL
SELECT id, 'repair', 7.5, 9.0, 10, true FROM engineer_monthly_mentee_pairings_r2730 WHERE mentee_name = 'Tejas Bhat';

-- =====================================================================
-- RPCs
-- =====================================================================

-- 1. Overview KPIs
DROP FUNCTION IF EXISTS founder_r2730_pairing_overview();
CREATE OR REPLACE FUNCTION founder_r2730_pairing_overview()
RETURNS TABLE(
  total_pairings int,
  total_hours numeric,
  avg_skill_jump numeric,
  avg_csat_mentee numeric,
  extend_count int,
  reassign_count int,
  terminate_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COALESCE(SUM(hours_spent), 0)::numeric,
    COALESCE(AVG(skill_score_after - skill_score_before), 0)::numeric(6,2),
    COALESCE(AVG(csat_mentee_rating), 0)::numeric(4,2),
    COUNT(*) FILTER (WHERE pairing_verdict = 'extend')::int,
    COUNT(*) FILTER (WHERE pairing_verdict = 'reassign')::int,
    COUNT(*) FILTER (WHERE pairing_verdict = 'terminate')::int
  FROM engineer_monthly_mentee_pairings_r2730;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_pairing_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_pairing_overview() TO authenticated;

-- 2. List all pairings
DROP FUNCTION IF EXISTS founder_r2730_list_pairings();
CREATE OR REPLACE FUNCTION founder_r2730_list_pairings()
RETURNS TABLE(
  id uuid,
  pairing_month date,
  mentor_name text,
  mentor_tier text,
  mentee_name text,
  mentee_tier_before text,
  mentee_tier_after text,
  hours_spent numeric,
  skill_jump numeric,
  csat_mentee numeric,
  pairing_verdict text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.pairing_month, p.mentor_name, p.mentor_tier,
         p.mentee_name, p.mentee_tier_before, p.mentee_tier_after,
         p.hours_spent,
         (p.skill_score_after - p.skill_score_before)::numeric(5,2),
         p.csat_mentee_rating,
         p.pairing_verdict
  FROM engineer_monthly_mentee_pairings_r2730 p
  ORDER BY (p.skill_score_after - p.skill_score_before) DESC, p.hours_spent DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_list_pairings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_list_pairings() TO authenticated;

-- 3. Top performing mentors
DROP FUNCTION IF EXISTS founder_r2730_top_mentors();
CREATE OR REPLACE FUNCTION founder_r2730_top_mentors()
RETURNS TABLE(
  mentor_name text,
  mentor_tier text,
  mentee_count int,
  total_hours numeric,
  avg_skill_jump numeric,
  avg_csat_mentee numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.mentor_name, p.mentor_tier,
         COUNT(*)::int,
         SUM(p.hours_spent)::numeric,
         AVG(p.skill_score_after - p.skill_score_before)::numeric(5,2),
         AVG(p.csat_mentee_rating)::numeric(4,2)
  FROM engineer_monthly_mentee_pairings_r2730 p
  GROUP BY p.mentor_name, p.mentor_tier
  ORDER BY AVG(p.skill_score_after - p.skill_score_before) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_top_mentors() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_top_mentors() TO authenticated;

-- 4. Pairings to reassign or terminate
DROP FUNCTION IF EXISTS founder_r2730_action_required();
CREATE OR REPLACE FUNCTION founder_r2730_action_required()
RETURNS TABLE(
  mentor_name text,
  mentee_name text,
  hours_spent numeric,
  skill_jump numeric,
  csat_mentee numeric,
  pairing_verdict text,
  founder_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.mentor_name, p.mentee_name, p.hours_spent,
         (p.skill_score_after - p.skill_score_before)::numeric(5,2),
         p.csat_mentee_rating, p.pairing_verdict, p.founder_notes
  FROM engineer_monthly_mentee_pairings_r2730 p
  WHERE p.pairing_verdict IN ('reassign','terminate')
  ORDER BY p.pairing_verdict, p.csat_mentee_rating;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_action_required() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_action_required() TO authenticated;

-- 5. Skill breakdown rollup
DROP FUNCTION IF EXISTS founder_r2730_skill_breakdown();
CREATE OR REPLACE FUNCTION founder_r2730_skill_breakdown()
RETURNS TABLE(
  skill_area text,
  pair_count int,
  avg_before numeric,
  avg_after numeric,
  avg_jump numeric,
  signoff_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.skill_area,
         COUNT(*)::int,
         AVG(s.proficiency_before)::numeric(5,2),
         AVG(s.proficiency_after)::numeric(5,2),
         AVG(s.proficiency_after - s.proficiency_before)::numeric(5,2),
         (AVG(CASE WHEN s.mentor_signoff THEN 1.0 ELSE 0.0 END) * 100)::numeric(5,1)
  FROM engineer_pairing_skill_breakdown_r2730 s
  GROUP BY s.skill_area
  ORDER BY AVG(s.proficiency_after - s.proficiency_before) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_skill_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_skill_breakdown() TO authenticated;

-- 6. Tier progression count
DROP FUNCTION IF EXISTS founder_r2730_tier_progression();
CREATE OR REPLACE FUNCTION founder_r2730_tier_progression()
RETURNS TABLE(
  movement text,
  pair_count int,
  avg_hours numeric,
  avg_csat numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    CASE
      WHEN p.mentee_tier_before = p.mentee_tier_after THEN 'no change'
      ELSE p.mentee_tier_before || ' to ' || p.mentee_tier_after
    END AS movement,
    COUNT(*)::int,
    AVG(p.hours_spent)::numeric(6,2),
    AVG(p.csat_mentee_rating)::numeric(4,2)
  FROM engineer_monthly_mentee_pairings_r2730 p
  GROUP BY 1
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_tier_progression() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_tier_progression() TO authenticated;

-- 7. Update verdict
DROP FUNCTION IF EXISTS founder_r2730_set_verdict(uuid, text, text);
CREATE OR REPLACE FUNCTION founder_r2730_set_verdict(p_id uuid, p_verdict text, p_notes text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_verdict NOT IN ('extend','continue','reassign','terminate') THEN
    RAISE EXCEPTION 'invalid verdict';
  END IF;
  UPDATE engineer_monthly_mentee_pairings_r2730
     SET pairing_verdict = p_verdict,
         founder_notes = COALESCE(p_notes, founder_notes)
   WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_set_verdict(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_set_verdict(uuid, text, text) TO authenticated;

-- 8. Effectiveness score per pairing (composite)
DROP FUNCTION IF EXISTS founder_r2730_effectiveness_score();
CREATE OR REPLACE FUNCTION founder_r2730_effectiveness_score()
RETURNS TABLE(
  mentor_name text,
  mentee_name text,
  skill_jump numeric,
  csat_avg numeric,
  jobs_total int,
  effectiveness_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.mentor_name, p.mentee_name,
         (p.skill_score_after - p.skill_score_before)::numeric(5,2),
         ((p.csat_mentor_rating + p.csat_mentee_rating) / 2.0)::numeric(4,2),
         (p.shadow_jobs_completed + p.solo_jobs_completed)::int,
         (
           (p.skill_score_after - p.skill_score_before) * 4
           + ((p.csat_mentor_rating + p.csat_mentee_rating) / 2.0) * 3
           + (p.shadow_jobs_completed + p.solo_jobs_completed) * 0.2
         )::numeric(6,2)
  FROM engineer_monthly_mentee_pairings_r2730 p
  ORDER BY 6 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_r2730_effectiveness_score() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_r2730_effectiveness_score() TO authenticated;

COMMIT;
