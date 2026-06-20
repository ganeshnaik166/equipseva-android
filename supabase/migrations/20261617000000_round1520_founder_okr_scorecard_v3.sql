BEGIN;

-- ============================================================
-- r1520 — Founder OKR Scorecard v3
-- Quarterly OKR tracker with weekly check-ins, auto-aggregated
-- progress, end-of-quarter founder grade.
-- ============================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS founder_okr_objectives_v3 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter_label text NOT NULL,                       -- e.g. '2026-Q2'
  quarter_starts_on date NOT NULL,
  quarter_ends_on date NOT NULL,
  objective_title text NOT NULL,
  objective_description text,
  owner_user_id uuid REFERENCES auth.users(id),
  weight_pct numeric NOT NULL DEFAULT 25 CHECK (weight_pct >= 0 AND weight_pct <= 100),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived','done')),
  final_grade text CHECK (final_grade IN ('A','B','C','D','F')),
  final_grade_notes text,
  graded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_okr_obj_v3_quarter ON founder_okr_objectives_v3 (quarter_label);
CREATE INDEX IF NOT EXISTS idx_okr_obj_v3_status ON founder_okr_objectives_v3 (status);

CREATE TABLE IF NOT EXISTS founder_okr_key_results_v3 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objective_id uuid NOT NULL REFERENCES founder_okr_objectives_v3(id) ON DELETE CASCADE,
  kr_title text NOT NULL,
  kr_unit text NOT NULL DEFAULT 'count',             -- 'count'|'rupees'|'percent'|'days'
  start_value numeric NOT NULL DEFAULT 0,
  target_value numeric NOT NULL,
  current_value numeric NOT NULL DEFAULT 0,
  last_checkin_at timestamptz,
  last_checkin_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_okr_kr_v3_obj ON founder_okr_key_results_v3 (objective_id);
CREATE INDEX IF NOT EXISTS idx_okr_kr_v3_checkin ON founder_okr_key_results_v3 (last_checkin_at DESC);

ALTER TABLE founder_okr_objectives_v3 ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_okr_key_results_v3 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_okr_obj_v3_founder_only ON founder_okr_objectives_v3;
CREATE POLICY founder_okr_obj_v3_founder_only ON founder_okr_objectives_v3
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_okr_kr_v3_founder_only ON founder_okr_key_results_v3;
CREATE POLICY founder_okr_kr_v3_founder_only ON founder_okr_key_results_v3
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---------- log helpers ----------

CREATE OR REPLACE FUNCTION log_founder_okr_v3_create_objective(p_obj_id uuid, p_title text, p_quarter text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_v3_create_objective',
          jsonb_build_object('obj_id', p_obj_id, 'title', p_title, 'quarter', p_quarter));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_okr_v3_checkin(p_kr_id uuid, p_value numeric, p_note text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_v3_checkin',
          jsonb_build_object('kr_id', p_kr_id, 'value', p_value, 'note', p_note));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_okr_v3_grade(p_obj_id uuid, p_grade text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_v3_grade',
          jsonb_build_object('obj_id', p_obj_id, 'grade', p_grade));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_okr_v3_archive(p_obj_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'okr_v3_archive',
          jsonb_build_object('obj_id', p_obj_id));
END;
$$;

-- ---------- READ RPCs (STABLE) ----------

DROP FUNCTION IF EXISTS founder_okr_v3_quarter_summary();
CREATE OR REPLACE FUNCTION founder_okr_v3_quarter_summary()
RETURNS TABLE (
  quarter_label text,
  objectives_count bigint,
  active_count bigint,
  done_count bigint,
  avg_progress_pct numeric,
  total_weight numeric,
  days_remaining numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.quarter_label,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE o.status='active')::bigint,
         COUNT(*) FILTER (WHERE o.status='done')::bigint,
         COALESCE(AVG(
           CASE WHEN (SELECT SUM(k.target_value - k.start_value) FROM founder_okr_key_results_v3 k WHERE k.objective_id = o.id) > 0
                THEN LEAST(100, GREATEST(0, 100.0 *
                     (SELECT SUM(k.current_value - k.start_value) FROM founder_okr_key_results_v3 k WHERE k.objective_id = o.id)
                   / NULLIF((SELECT SUM(k.target_value - k.start_value) FROM founder_okr_key_results_v3 k WHERE k.objective_id = o.id),0)))
                ELSE 0 END
         ), 0)::numeric,
         COALESCE(SUM(o.weight_pct),0)::numeric,
         GREATEST(0, EXTRACT(EPOCH FROM (MAX(o.quarter_ends_on)::timestamptz - now()))/86400.0)::numeric
  FROM founder_okr_objectives_v3 o
  GROUP BY o.quarter_label
  ORDER BY o.quarter_label DESC
  LIMIT 8;
END;
$$;

DROP FUNCTION IF EXISTS founder_okr_v3_objective_progress();
CREATE OR REPLACE FUNCTION founder_okr_v3_objective_progress()
RETURNS TABLE (
  id uuid,
  quarter_label text,
  objective_title text,
  status text,
  weight_pct numeric,
  kr_count bigint,
  progress_pct numeric,
  last_checkin_at timestamptz,
  days_to_close numeric,
  final_grade text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.quarter_label, o.objective_title, o.status, o.weight_pct,
         COUNT(k.id)::bigint,
         COALESCE(LEAST(100, GREATEST(0,
           100.0 * SUM(k.current_value - k.start_value) / NULLIF(SUM(k.target_value - k.start_value),0)
         )), 0)::numeric,
         MAX(k.last_checkin_at),
         GREATEST(0, EXTRACT(EPOCH FROM (o.quarter_ends_on::timestamptz - now()))/86400.0)::numeric,
         o.final_grade
  FROM founder_okr_objectives_v3 o
  LEFT JOIN founder_okr_key_results_v3 k ON k.objective_id = o.id
  GROUP BY o.id
  ORDER BY o.quarter_ends_on DESC, o.created_at DESC
  LIMIT 100;
END;
$$;

DROP FUNCTION IF EXISTS founder_okr_v3_key_results_detail();
CREATE OR REPLACE FUNCTION founder_okr_v3_key_results_detail()
RETURNS TABLE (
  id uuid,
  objective_title text,
  kr_title text,
  kr_unit text,
  start_value numeric,
  current_value numeric,
  target_value numeric,
  progress_pct numeric,
  last_checkin_at timestamptz,
  last_checkin_note text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, o.objective_title, k.kr_title, k.kr_unit,
         k.start_value, k.current_value, k.target_value,
         CASE WHEN (k.target_value - k.start_value) <> 0
              THEN LEAST(100, GREATEST(0, 100.0 * (k.current_value - k.start_value) / (k.target_value - k.start_value)))
              ELSE 0 END::numeric,
         k.last_checkin_at, k.last_checkin_note
  FROM founder_okr_key_results_v3 k
  JOIN founder_okr_objectives_v3 o ON o.id = k.objective_id
  ORDER BY k.last_checkin_at DESC NULLS LAST
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS founder_okr_v3_recent_checkins();
CREATE OR REPLACE FUNCTION founder_okr_v3_recent_checkins()
RETURNS TABLE (
  id uuid,
  objective_title text,
  kr_title text,
  checkin_at timestamptz,
  current_value numeric,
  note text,
  age_days numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, o.objective_title, k.kr_title,
         k.last_checkin_at, k.current_value, k.last_checkin_note,
         EXTRACT(EPOCH FROM (now() - k.last_checkin_at))/86400.0
  FROM founder_okr_key_results_v3 k
  JOIN founder_okr_objectives_v3 o ON o.id = k.objective_id
  WHERE k.last_checkin_at IS NOT NULL
  ORDER BY k.last_checkin_at DESC
  LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS founder_okr_v3_grade_distribution();
CREATE OR REPLACE FUNCTION founder_okr_v3_grade_distribution()
RETURNS TABLE (
  final_grade text,
  obj_count bigint,
  avg_weight numeric,
  quarters_covered bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(o.final_grade,'(ungraded)') AS final_grade,
         COUNT(*)::bigint,
         AVG(o.weight_pct)::numeric,
         COUNT(DISTINCT o.quarter_label)::bigint
  FROM founder_okr_objectives_v3 o
  GROUP BY o.final_grade
  ORDER BY 2 DESC;
END;
$$;

-- ---------- WRITE RPCs (VOLATILE) ----------

DROP FUNCTION IF EXISTS founder_okr_v3_create_objective(text, date, date, text, text, numeric);
CREATE OR REPLACE FUNCTION founder_okr_v3_create_objective(
  p_quarter_label text,
  p_starts date,
  p_ends date,
  p_title text,
  p_description text,
  p_weight numeric
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_okr_objectives_v3 (quarter_label, quarter_starts_on, quarter_ends_on,
                                          objective_title, objective_description, weight_pct)
  VALUES (p_quarter_label, p_starts, p_ends, p_title, p_description, COALESCE(p_weight,25))
  RETURNING id INTO v_id;
  PERFORM log_founder_okr_v3_create_objective(v_id, p_title, p_quarter_label);
  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS founder_okr_v3_record_checkin(uuid, numeric, text);
CREATE OR REPLACE FUNCTION founder_okr_v3_record_checkin(
  p_kr_id uuid,
  p_value numeric,
  p_note text
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_okr_key_results_v3
     SET current_value = p_value,
         last_checkin_at = now(),
         last_checkin_note = p_note,
         updated_at = now()
   WHERE id = p_kr_id;
  PERFORM log_founder_okr_v3_checkin(p_kr_id, p_value, p_note);
END;
$$;

-- ---------- Grants ----------

REVOKE EXECUTE ON FUNCTION founder_okr_v3_quarter_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_okr_v3_objective_progress() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_okr_v3_key_results_detail() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_okr_v3_recent_checkins() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_okr_v3_grade_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_okr_v3_create_objective(text, date, date, text, text, numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_okr_v3_record_checkin(uuid, numeric, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_okr_v3_quarter_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_okr_v3_objective_progress() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_okr_v3_key_results_detail() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_okr_v3_recent_checkins() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_okr_v3_grade_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_okr_v3_create_objective(text, date, date, text, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_okr_v3_record_checkin(uuid, numeric, text) TO authenticated;

COMMIT;