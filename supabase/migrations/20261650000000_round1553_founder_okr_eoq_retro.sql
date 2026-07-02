BEGIN;

-- =====================================================================
-- r1553 — Founder OKR End-of-Quarter Retro
-- Founder grades every objective (A/B/C/D/F) with reason + learning;
-- aggregate quarter grade; recipe analysis across quarters.
-- =====================================================================

-- ------------------------------------------------------------------
-- Table 1: per-objective grade for a quarter
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_okr_eoq_grades (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label   text NOT NULL,           -- e.g. '2026-Q2'
  quarter_start   date NOT NULL,
  quarter_end     date NOT NULL,
  objective_key   text NOT NULL,           -- short id like 'growth.amc_chains'
  objective_title text NOT NULL,
  target_text     text,
  actual_text     text,
  grade           text NOT NULL CHECK (grade IN ('A','B','C','D','F')),
  grade_points    numeric(3,2) NOT NULL,   -- A=4.0 B=3.0 C=2.0 D=1.0 F=0.0
  weight          numeric(4,2) NOT NULL DEFAULT 1.00,
  reason          text NOT NULL,
  learning        text NOT NULL,
  recipe_tag      text,                    -- 'execution','focus','luck','market','team','process'
  graded_by       uuid REFERENCES auth.users(id),
  graded_by_email text,
  graded_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (quarter_label, objective_key)
);

CREATE INDEX IF NOT EXISTS idx_okr_eoq_grades_quarter ON founder_okr_eoq_grades(quarter_label);
CREATE INDEX IF NOT EXISTS idx_okr_eoq_grades_recipe ON founder_okr_eoq_grades(recipe_tag);

ALTER TABLE founder_okr_eoq_grades ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS okr_eoq_grades_founder_only ON founder_okr_eoq_grades;
CREATE POLICY okr_eoq_grades_founder_only ON founder_okr_eoq_grades
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ------------------------------------------------------------------
-- Table 2: aggregate quarter retro summary
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS founder_okr_eoq_retros (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label       text NOT NULL UNIQUE,
  quarter_start       date NOT NULL,
  quarter_end         date NOT NULL,
  aggregate_gpa       numeric(3,2),         -- weighted avg of grade_points
  aggregate_letter    text CHECK (aggregate_letter IN ('A','B','C','D','F')),
  objectives_count    int NOT NULL DEFAULT 0,
  top_recipe_tag      text,
  retro_narrative     text,
  next_quarter_bets   text,
  closed_at           timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_okr_eoq_retros ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS okr_eoq_retros_founder_only ON founder_okr_eoq_retros;
CREATE POLICY okr_eoq_retros_founder_only ON founder_okr_eoq_retros
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ==================================================================
-- Helper VOLATILE log functions (founder_action_log)
-- ==================================================================

CREATE OR REPLACE FUNCTION log_founder_okr_grade_upsert(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_eoq.grade_upsert', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_okr_grade_upsert(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_okr_grade_upsert(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_okr_retro_close(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_eoq.retro_close', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_okr_retro_close(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_okr_retro_close(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_okr_recipe_assign(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_eoq.recipe_assign', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_okr_recipe_assign(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_okr_recipe_assign(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_okr_retro_narrative(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_eoq.retro_narrative', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_okr_retro_narrative(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_okr_retro_narrative(jsonb) TO authenticated;

-- ==================================================================
-- READ RPCs (STABLE)
-- ==================================================================

-- 1. KPI roll-up across all quarters
CREATE OR REPLACE FUNCTION founder_okr_eoq_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'quarters_total',        (SELECT COUNT(DISTINCT quarter_label) FROM founder_okr_eoq_grades),
    'quarters_closed',       (SELECT COUNT(*) FROM founder_okr_eoq_retros WHERE closed_at IS NOT NULL),
    'quarters_open',         (SELECT COUNT(*) FROM founder_okr_eoq_retros WHERE closed_at IS NULL),
    'objectives_total',      (SELECT COUNT(*) FROM founder_okr_eoq_grades),
    'objectives_a',          (SELECT COUNT(*) FROM founder_okr_eoq_grades WHERE grade='A'),
    'objectives_b',          (SELECT COUNT(*) FROM founder_okr_eoq_grades WHERE grade='B'),
    'objectives_c',          (SELECT COUNT(*) FROM founder_okr_eoq_grades WHERE grade='C'),
    'objectives_d',          (SELECT COUNT(*) FROM founder_okr_eoq_grades WHERE grade='D'),
    'objectives_f',          (SELECT COUNT(*) FROM founder_okr_eoq_grades WHERE grade='F'),
    'gpa_lifetime',          (SELECT ROUND(AVG(grade_points)::numeric, 2) FROM founder_okr_eoq_grades),
    'gpa_last_quarter',      (SELECT ROUND(AVG(grade_points)::numeric, 2) FROM founder_okr_eoq_grades WHERE quarter_label = (SELECT MAX(quarter_label) FROM founder_okr_eoq_grades)),
    'top_recipe_tag',        (SELECT recipe_tag FROM founder_okr_eoq_grades WHERE recipe_tag IS NOT NULL GROUP BY recipe_tag ORDER BY COUNT(*) DESC LIMIT 1),
    'recipe_tags_distinct',  (SELECT COUNT(DISTINCT recipe_tag) FROM founder_okr_eoq_grades WHERE recipe_tag IS NOT NULL),
    'objectives_no_recipe',  (SELECT COUNT(*) FROM founder_okr_eoq_grades WHERE recipe_tag IS NULL),
    'last_grade_at',         (SELECT MAX(graded_at) FROM founder_okr_eoq_grades),
    'last_retro_close_at',   (SELECT MAX(closed_at) FROM founder_okr_eoq_retros)
  ) INTO v;
  RETURN COALESCE(v, '{}'::jsonb);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_okr_eoq_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_okr_eoq_kpis() TO authenticated;

-- 2. Quarter summary list
CREATE OR REPLACE FUNCTION founder_okr_eoq_quarters()
RETURNS TABLE (
  quarter_label text,
  quarter_start date,
  quarter_end   date,
  aggregate_gpa numeric,
  aggregate_letter text,
  objectives_count int,
  top_recipe_tag text,
  closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.quarter_label, r.quarter_start, r.quarter_end,
         r.aggregate_gpa, r.aggregate_letter, r.objectives_count,
         r.top_recipe_tag, r.closed_at
    FROM founder_okr_eoq_retros r
   ORDER BY r.quarter_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_okr_eoq_quarters() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_okr_eoq_quarters() TO authenticated;

-- 3. Objectives within a quarter
CREATE OR REPLACE FUNCTION founder_okr_eoq_objectives(p_quarter_label text)
RETURNS TABLE (
  id uuid,
  objective_key text,
  objective_title text,
  target_text text,
  actual_text text,
  grade text,
  grade_points numeric,
  weight numeric,
  recipe_tag text,
  reason text,
  learning text,
  graded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.id, g.objective_key, g.objective_title, g.target_text, g.actual_text,
         g.grade, g.grade_points, g.weight, g.recipe_tag, g.reason, g.learning, g.graded_at
    FROM founder_okr_eoq_grades g
   WHERE g.quarter_label = p_quarter_label
   ORDER BY g.grade_points ASC, g.objective_title;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_okr_eoq_objectives(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_okr_eoq_objectives(text) TO authenticated;

-- 4. Recipe analysis across quarters
CREATE OR REPLACE FUNCTION founder_okr_eoq_recipe_analysis()
RETURNS TABLE (
  recipe_tag text,
  occurrences int,
  avg_gpa numeric,
  best_grade text,
  worst_grade text,
  quarters_seen int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.recipe_tag,
         COUNT(*)::int AS occurrences,
         ROUND(AVG(g.grade_points)::numeric, 2) AS avg_gpa,
         MIN(g.grade) AS best_grade,
         MAX(g.grade) AS worst_grade,
         COUNT(DISTINCT g.quarter_label)::int AS quarters_seen
    FROM founder_okr_eoq_grades g
   WHERE g.recipe_tag IS NOT NULL
   GROUP BY g.recipe_tag
   ORDER BY occurrences DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_okr_eoq_recipe_analysis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_okr_eoq_recipe_analysis() TO authenticated;

-- 5. Grade distribution per quarter (trend)
CREATE OR REPLACE FUNCTION founder_okr_eoq_grade_trend()
RETURNS TABLE (
  quarter_label text,
  a_count int,
  b_count int,
  c_count int,
  d_count int,
  f_count int,
  gpa numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT g.quarter_label,
         COUNT(*) FILTER (WHERE g.grade='A')::int,
         COUNT(*) FILTER (WHERE g.grade='B')::int,
         COUNT(*) FILTER (WHERE g.grade='C')::int,
         COUNT(*) FILTER (WHERE g.grade='D')::int,
         COUNT(*) FILTER (WHERE g.grade='F')::int,
         ROUND(AVG(g.grade_points)::numeric, 2) AS gpa
    FROM founder_okr_eoq_grades g
   GROUP BY g.quarter_label
   ORDER BY g.quarter_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_okr_eoq_grade_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_okr_eoq_grade_trend() TO authenticated;

-- ==================================================================
-- WRITE RPCs (VOLATILE)
-- ==================================================================

-- 6. Upsert grade for an objective
CREATE OR REPLACE FUNCTION founder_okr_eoq_upsert_grade(
  p_quarter_label text,
  p_quarter_start date,
  p_quarter_end   date,
  p_objective_key text,
  p_objective_title text,
  p_target_text   text,
  p_actual_text   text,
  p_grade         text,
  p_weight        numeric,
  p_reason        text,
  p_learning      text,
  p_recipe_tag    text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_points numeric;
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_points := CASE p_grade
    WHEN 'A' THEN 4.0
    WHEN 'B' THEN 3.0
    WHEN 'C' THEN 2.0
    WHEN 'D' THEN 1.0
    WHEN 'F' THEN 0.0
    ELSE NULL
  END;
  IF v_points IS NULL THEN RAISE EXCEPTION 'bad grade'; END IF;

  INSERT INTO founder_okr_eoq_grades(
    quarter_label, quarter_start, quarter_end, objective_key, objective_title,
    target_text, actual_text, grade, grade_points, weight, reason, learning,
    recipe_tag, graded_by, graded_by_email)
  VALUES (
    p_quarter_label, p_quarter_start, p_quarter_end, p_objective_key, p_objective_title,
    p_target_text, p_actual_text, p_grade, v_points, COALESCE(p_weight,1.00), p_reason, p_learning,
    p_recipe_tag, auth.uid(), (auth.jwt()->>'email'))
  ON CONFLICT (quarter_label, objective_key) DO UPDATE
    SET objective_title=EXCLUDED.objective_title,
        target_text=EXCLUDED.target_text,
        actual_text=EXCLUDED.actual_text,
        grade=EXCLUDED.grade,
        grade_points=EXCLUDED.grade_points,
        weight=EXCLUDED.weight,
        reason=EXCLUDED.reason,
        learning=EXCLUDED.learning,
        recipe_tag=EXCLUDED.recipe_tag,
        graded_by=auth.uid(),
        graded_by_email=(auth.jwt()->>'email'),
        graded_at=now()
  RETURNING id INTO v_id;

  -- Recompute parent retro
  INSERT INTO founder_okr_eoq_retros(quarter_label, quarter_start, quarter_end, objectives_count)
  VALUES (p_quarter_label, p_quarter_start, p_quarter_end, 0)
  ON CONFLICT (quarter_label) DO NOTHING;

  UPDATE founder_okr_eoq_retros r
     SET aggregate_gpa = sub.gpa,
         aggregate_letter = CASE
           WHEN sub.gpa >= 3.5 THEN 'A'
           WHEN sub.gpa >= 2.5 THEN 'B'
           WHEN sub.gpa >= 1.5 THEN 'C'
           WHEN sub.gpa >= 0.5 THEN 'D'
           ELSE 'F'
         END,
         objectives_count = sub.cnt,
         top_recipe_tag = sub.top_tag,
         updated_at = now()
    FROM (
      SELECT ROUND(AVG(grade_points)::numeric,2) AS gpa,
             COUNT(*)::int AS cnt,
             (SELECT recipe_tag FROM founder_okr_eoq_grades WHERE quarter_label=p_quarter_label AND recipe_tag IS NOT NULL GROUP BY recipe_tag ORDER BY COUNT(*) DESC LIMIT 1) AS top_tag
        FROM founder_okr_eoq_grades
       WHERE quarter_label = p_quarter_label
    ) sub
   WHERE r.quarter_label = p_quarter_label;

  PERFORM log_founder_okr_grade_upsert(jsonb_build_object(
    'id', v_id, 'quarter', p_quarter_label, 'objective', p_objective_key, 'grade', p_grade));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_okr_eoq_upsert_grade(text,date,date,text,text,text,text,text,numeric,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_okr_eoq_upsert_grade(text,date,date,text,text,text,text,text,numeric,text,text,text) TO authenticated;

-- 7. Close retro with narrative
CREATE OR REPLACE FUNCTION founder_okr_eoq_close_retro(
  p_quarter_label   text,
  p_retro_narrative text,
  p_next_quarter_bets text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_okr_eoq_retros
     SET retro_narrative = p_retro_narrative,
         next_quarter_bets = p_next_quarter_bets,
         closed_at = now(),
         updated_at = now()
   WHERE quarter_label = p_quarter_label
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN RAISE EXCEPTION 'no retro for quarter %', p_quarter_label; END IF;
  PERFORM log_founder_okr_retro_close(jsonb_build_object('id', v_id, 'quarter', p_quarter_label));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_okr_eoq_close_retro(text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_okr_eoq_close_retro(text,text,text) TO authenticated;

COMMIT;