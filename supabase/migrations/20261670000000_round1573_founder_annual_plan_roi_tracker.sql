BEGIN;

-- =====================================================================
-- r1573 — Founder Annual Plan ROI Tracker
-- After annual plan ends, log actual outcomes vs predictions.
-- ROI per pillar + lessons-learned feed next-year planning.
-- =====================================================================

CREATE TABLE IF NOT EXISTS founder_annual_plan_roi (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_year int NOT NULL,
  pillar text NOT NULL CHECK (pillar IN ('revenue','margin','engineer_supply','amc_density','geo_expansion','reliability','compliance','product','brand','people')),
  predicted_value_rupees numeric(14,2) NOT NULL DEFAULT 0,
  actual_value_rupees numeric(14,2) NOT NULL DEFAULT 0,
  predicted_unit_count int NOT NULL DEFAULT 0,
  actual_unit_count int NOT NULL DEFAULT 0,
  investment_rupees numeric(14,2) NOT NULL DEFAULT 0,
  variance_pct numeric(7,2),
  roi_pct numeric(7,2),
  verdict text NOT NULL DEFAULT 'pending' CHECK (verdict IN ('hit','miss','exceeded','partial','pending')),
  notes text,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plan_year, pillar)
);

CREATE INDEX IF NOT EXISTS idx_fapr_year ON founder_annual_plan_roi(plan_year);
CREATE INDEX IF NOT EXISTS idx_fapr_verdict ON founder_annual_plan_roi(verdict);

CREATE TABLE IF NOT EXISTS founder_annual_plan_lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_year int NOT NULL,
  pillar text NOT NULL,
  lesson text NOT NULL,
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  carry_to_next_year boolean NOT NULL DEFAULT true,
  follow_up_action text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fapl_year ON founder_annual_plan_lessons(plan_year);
CREATE INDEX IF NOT EXISTS idx_fapl_carry ON founder_annual_plan_lessons(carry_to_next_year) WHERE carry_to_next_year IS TRUE;

ALTER TABLE founder_annual_plan_roi ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_annual_plan_lessons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fapr_founder_all ON founder_annual_plan_roi;
CREATE POLICY fapr_founder_all ON founder_annual_plan_roi FOR ALL USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS fapl_founder_all ON founder_annual_plan_lessons;
CREATE POLICY fapl_founder_all ON founder_annual_plan_lessons FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_annual_plan_roi_overview(p_year int)
RETURNS TABLE (
  plan_year int,
  pillars_total int,
  pillars_hit int,
  pillars_missed int,
  pillars_exceeded int,
  predicted_total_rupees numeric,
  actual_total_rupees numeric,
  investment_total_rupees numeric,
  blended_roi_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p_year,
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE verdict='hit')::int,
    COUNT(*) FILTER (WHERE verdict='miss')::int,
    COUNT(*) FILTER (WHERE verdict='exceeded')::int,
    COALESCE(SUM(predicted_value_rupees),0),
    COALESCE(SUM(actual_value_rupees),0),
    COALESCE(SUM(investment_rupees),0),
    CASE WHEN COALESCE(SUM(investment_rupees),0) > 0
      THEN ROUND(((SUM(actual_value_rupees) - SUM(investment_rupees)) / SUM(investment_rupees)) * 100, 2)
      ELSE 0 END
  FROM founder_annual_plan_roi
  WHERE plan_year = p_year;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_roi_by_pillar(p_year int)
RETURNS TABLE (
  id uuid,
  pillar text,
  predicted_value_rupees numeric,
  actual_value_rupees numeric,
  investment_rupees numeric,
  variance_pct numeric,
  roi_pct numeric,
  verdict text,
  closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.pillar, r.predicted_value_rupees, r.actual_value_rupees,
         r.investment_rupees, r.variance_pct, r.roi_pct, r.verdict, r.closed_at
  FROM founder_annual_plan_roi r
  WHERE r.plan_year = p_year
  ORDER BY r.roi_pct DESC NULLS LAST;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_top_hits(p_year int, p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  pillar text,
  actual_value_rupees numeric,
  roi_pct numeric,
  variance_pct numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.pillar, r.actual_value_rupees, r.roi_pct, r.variance_pct, r.notes
  FROM founder_annual_plan_roi r
  WHERE r.plan_year = p_year AND r.verdict IN ('hit','exceeded')
  ORDER BY r.roi_pct DESC NULLS LAST
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_top_misses(p_year int, p_limit int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  pillar text,
  predicted_value_rupees numeric,
  actual_value_rupees numeric,
  variance_pct numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.pillar, r.predicted_value_rupees, r.actual_value_rupees, r.variance_pct, r.notes
  FROM founder_annual_plan_roi r
  WHERE r.plan_year = p_year AND r.verdict IN ('miss','partial')
  ORDER BY r.variance_pct ASC NULLS LAST
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_lessons_list(p_year int)
RETURNS TABLE (
  id uuid,
  pillar text,
  lesson text,
  severity text,
  carry_to_next_year boolean,
  follow_up_action text,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.pillar, l.lesson, l.severity, l.carry_to_next_year, l.follow_up_action, l.status, l.created_at
  FROM founder_annual_plan_lessons l
  WHERE l.plan_year = p_year
  ORDER BY (CASE l.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END), l.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_carry_forward(p_year int)
RETURNS TABLE (
  id uuid,
  pillar text,
  lesson text,
  severity text,
  follow_up_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.pillar, l.lesson, l.severity, l.follow_up_action
  FROM founder_annual_plan_lessons l
  WHERE l.plan_year = p_year AND l.carry_to_next_year IS TRUE AND l.status <> 'closed'
  ORDER BY (CASE l.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END);
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_year_compare(p_year_a int, p_year_b int)
RETURNS TABLE (
  pillar text,
  actual_a numeric,
  actual_b numeric,
  delta_rupees numeric,
  delta_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH a AS (SELECT pillar, actual_value_rupees FROM founder_annual_plan_roi WHERE plan_year = p_year_a),
       b AS (SELECT pillar, actual_value_rupees FROM founder_annual_plan_roi WHERE plan_year = p_year_b)
  SELECT COALESCE(a.pillar, b.pillar),
         COALESCE(a.actual_value_rupees,0),
         COALESCE(b.actual_value_rupees,0),
         COALESCE(b.actual_value_rupees,0) - COALESCE(a.actual_value_rupees,0),
         CASE WHEN COALESCE(a.actual_value_rupees,0) > 0
           THEN ROUND(((COALESCE(b.actual_value_rupees,0) - a.actual_value_rupees) / a.actual_value_rupees) * 100, 2)
           ELSE NULL END
  FROM a FULL OUTER JOIN b ON a.pillar = b.pillar
  ORDER BY COALESCE(a.pillar, b.pillar);
END;
$$;

-- =====================================================================
-- WRITE log_founder_* helpers (VOLATILE)
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_annual_roi_upsert(
  p_year int,
  p_pillar text,
  p_predicted numeric,
  p_actual numeric,
  p_investment numeric,
  p_verdict text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_var numeric;
  v_roi numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_var := CASE WHEN p_predicted > 0 THEN ROUND(((p_actual - p_predicted) / p_predicted) * 100, 2) ELSE NULL END;
  v_roi := CASE WHEN p_investment > 0 THEN ROUND(((p_actual - p_investment) / p_investment) * 100, 2) ELSE NULL END;

  INSERT INTO founder_annual_plan_roi (plan_year, pillar, predicted_value_rupees, actual_value_rupees, investment_rupees, variance_pct, roi_pct, verdict, notes, closed_at, updated_at)
  VALUES (p_year, p_pillar, p_predicted, p_actual, p_investment, v_var, v_roi, p_verdict, p_notes,
          CASE WHEN p_verdict <> 'pending' THEN now() ELSE NULL END, now())
  ON CONFLICT (plan_year, pillar) DO UPDATE
    SET predicted_value_rupees = EXCLUDED.predicted_value_rupees,
        actual_value_rupees = EXCLUDED.actual_value_rupees,
        investment_rupees = EXCLUDED.investment_rupees,
        variance_pct = EXCLUDED.variance_pct,
        roi_pct = EXCLUDED.roi_pct,
        verdict = EXCLUDED.verdict,
        notes = EXCLUDED.notes,
        closed_at = EXCLUDED.closed_at,
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'annual_roi_upsert',
          jsonb_build_object('year', p_year, 'pillar', p_pillar, 'verdict', p_verdict, 'roi_pct', v_roi));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_annual_lesson_add(
  p_year int,
  p_pillar text,
  p_lesson text,
  p_severity text,
  p_carry boolean,
  p_follow_up text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_annual_plan_lessons (plan_year, pillar, lesson, severity, carry_to_next_year, follow_up_action)
  VALUES (p_year, p_pillar, p_lesson, p_severity, p_carry, p_follow_up)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'annual_lesson_add',
          jsonb_build_object('year', p_year, 'pillar', p_pillar, 'severity', p_severity));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_annual_lesson_close(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_annual_plan_lessons
  SET status = 'closed', carry_to_next_year = false, updated_at = now()
  WHERE id = p_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'annual_lesson_close', jsonb_build_object('id', p_id));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_annual_plan_finalize(p_year int)
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_annual_plan_roi
  SET closed_at = COALESCE(closed_at, now()), updated_at = now()
  WHERE plan_year = p_year AND verdict <> 'pending';
  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'annual_plan_finalize',
          jsonb_build_object('year', p_year, 'pillars_closed', v_count));

  RETURN v_count;
END;
$$;

-- =====================================================================
-- GRANTS
-- =====================================================================

REVOKE EXECUTE ON FUNCTION founder_annual_plan_roi_overview(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_annual_plan_roi_overview(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_annual_plan_roi_by_pillar(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_annual_plan_roi_by_pillar(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_annual_plan_top_hits(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_annual_plan_top_hits(int, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_annual_plan_top_misses(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_annual_plan_top_misses(int, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_annual_plan_lessons_list(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_annual_plan_lessons_list(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_annual_plan_carry_forward(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_annual_plan_carry_forward(int) TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_annual_plan_year_compare(int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_annual_plan_year_compare(int, int) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_annual_roi_upsert(int, text, numeric, numeric, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_annual_roi_upsert(int, text, numeric, numeric, numeric, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_annual_lesson_add(int, text, text, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_annual_lesson_add(int, text, text, text, boolean, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_annual_lesson_close(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_annual_lesson_close(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_annual_plan_finalize(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_annual_plan_finalize(int) TO authenticated;

COMMIT;