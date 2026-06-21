BEGIN;

-- =============================================================
-- r1557 — Founder Annual Plan Tracker
-- Annual planning doc with 4 quarterly checkpoints,
-- per-pillar goals/initiatives, mid-year refresh, carryover.
-- =============================================================

CREATE TABLE IF NOT EXISTS founder_annual_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_year int NOT NULL UNIQUE CHECK (plan_year BETWEEN 2024 AND 2040),
  north_star_metric text NOT NULL,
  north_star_target_value numeric,
  north_star_unit text,
  vision_statement text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','mid_year_refresh','closed','archived')),
  q1_checkpoint_status text NOT NULL DEFAULT 'pending' CHECK (q1_checkpoint_status IN ('pending','on_track','at_risk','off_track','done')),
  q2_checkpoint_status text NOT NULL DEFAULT 'pending' CHECK (q2_checkpoint_status IN ('pending','on_track','at_risk','off_track','done')),
  q3_checkpoint_status text NOT NULL DEFAULT 'pending' CHECK (q3_checkpoint_status IN ('pending','on_track','at_risk','off_track','done')),
  q4_checkpoint_status text NOT NULL DEFAULT 'pending' CHECK (q4_checkpoint_status IN ('pending','on_track','at_risk','off_track','done')),
  q1_notes text,
  q2_notes text,
  q3_notes text,
  q4_notes text,
  mid_year_refresh_at timestamptz,
  mid_year_refresh_notes text,
  carryover_from_year int,
  carryover_notes text,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_annual_plans_year ON founder_annual_plans(plan_year DESC);
CREATE INDEX IF NOT EXISTS idx_founder_annual_plans_status ON founder_annual_plans(status);

CREATE TABLE IF NOT EXISTS founder_annual_plan_pillars (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES founder_annual_plans(id) ON DELETE CASCADE,
  pillar_name text NOT NULL,
  pillar_order int NOT NULL DEFAULT 0,
  goal_statement text NOT NULL,
  key_initiatives text[] NOT NULL DEFAULT '{}'::text[],
  owner_email text,
  target_metric text,
  target_value numeric,
  current_value numeric DEFAULT 0,
  health_status text NOT NULL DEFAULT 'on_track' CHECK (health_status IN ('on_track','at_risk','off_track','done','blocked')),
  carried_over boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(plan_id, pillar_name)
);

CREATE INDEX IF NOT EXISTS idx_founder_annual_plan_pillars_plan ON founder_annual_plan_pillars(plan_id);
CREATE INDEX IF NOT EXISTS idx_founder_annual_plan_pillars_health ON founder_annual_plan_pillars(health_status);

ALTER TABLE founder_annual_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_annual_plan_pillars ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_annual_plans ON founder_annual_plans;
CREATE POLICY founder_only_annual_plans ON founder_annual_plans
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_annual_plan_pillars ON founder_annual_plan_pillars;
CREATE POLICY founder_only_annual_plan_pillars ON founder_annual_plan_pillars
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- =====================================================
-- READ RPCs (STABLE)
-- =====================================================

CREATE OR REPLACE FUNCTION founder_annual_plan_overview()
RETURNS TABLE (
  plan_id uuid,
  plan_year int,
  status text,
  north_star_metric text,
  north_star_target_value numeric,
  north_star_unit text,
  pillar_count bigint,
  on_track_count bigint,
  at_risk_count bigint,
  off_track_count bigint,
  done_count bigint,
  mid_year_refresh_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.plan_year,
    p.status,
    p.north_star_metric,
    p.north_star_target_value,
    p.north_star_unit,
    COALESCE((SELECT count(*) FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id), 0),
    COALESCE((SELECT count(*) FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id AND pp.health_status = 'on_track'), 0),
    COALESCE((SELECT count(*) FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id AND pp.health_status = 'at_risk'), 0),
    COALESCE((SELECT count(*) FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id AND pp.health_status = 'off_track'), 0),
    COALESCE((SELECT count(*) FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id AND pp.health_status = 'done'), 0),
    p.mid_year_refresh_at,
    p.created_at
  FROM founder_annual_plans p
  ORDER BY p.plan_year DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_current()
RETURNS TABLE (
  plan_id uuid,
  plan_year int,
  status text,
  north_star_metric text,
  vision_statement text,
  q1_status text,
  q2_status text,
  q3_status text,
  q4_status text,
  q1_notes text,
  q2_notes text,
  q3_notes text,
  q4_notes text,
  mid_year_refresh_at timestamptz,
  mid_year_refresh_notes text,
  carryover_from_year int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.plan_year,
    p.status,
    p.north_star_metric,
    p.vision_statement,
    p.q1_checkpoint_status,
    p.q2_checkpoint_status,
    p.q3_checkpoint_status,
    p.q4_checkpoint_status,
    p.q1_notes,
    p.q2_notes,
    p.q3_notes,
    p.q4_notes,
    p.mid_year_refresh_at,
    p.mid_year_refresh_notes,
    p.carryover_from_year
  FROM founder_annual_plans p
  WHERE p.status IN ('active','mid_year_refresh')
  ORDER BY p.plan_year DESC
  LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_pillars_list(p_plan_id uuid)
RETURNS TABLE (
  id uuid,
  pillar_name text,
  pillar_order int,
  goal_statement text,
  key_initiatives text[],
  owner_email text,
  target_metric text,
  target_value numeric,
  current_value numeric,
  health_status text,
  carried_over boolean,
  progress_pct numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    pp.id,
    pp.pillar_name,
    pp.pillar_order,
    pp.goal_statement,
    pp.key_initiatives,
    pp.owner_email,
    pp.target_metric,
    pp.target_value,
    pp.current_value,
    pp.health_status,
    pp.carried_over,
    CASE WHEN pp.target_value IS NULL OR pp.target_value = 0 THEN 0
         ELSE round(100.0 * pp.current_value / NULLIF(pp.target_value, 0), 1) END,
    pp.notes
  FROM founder_annual_plan_pillars pp
  WHERE pp.plan_id = p_plan_id
  ORDER BY pp.pillar_order, pp.pillar_name;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_quarter_summary(p_plan_id uuid)
RETURNS TABLE (
  quarter text,
  checkpoint_status text,
  notes text,
  quarter_index int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'Q1'::text, p.q1_checkpoint_status, p.q1_notes, 1 FROM founder_annual_plans p WHERE p.id = p_plan_id
  UNION ALL
  SELECT 'Q2'::text, p.q2_checkpoint_status, p.q2_notes, 2 FROM founder_annual_plans p WHERE p.id = p_plan_id
  UNION ALL
  SELECT 'Q3'::text, p.q3_checkpoint_status, p.q3_notes, 3 FROM founder_annual_plans p WHERE p.id = p_plan_id
  UNION ALL
  SELECT 'Q4'::text, p.q4_checkpoint_status, p.q4_notes, 4 FROM founder_annual_plans p WHERE p.id = p_plan_id
  ORDER BY 4;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_carryover_candidates(p_from_year int)
RETURNS TABLE (
  pillar_id uuid,
  pillar_name text,
  goal_statement text,
  health_status text,
  current_value numeric,
  target_value numeric,
  progress_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    pp.id,
    pp.pillar_name,
    pp.goal_statement,
    pp.health_status,
    pp.current_value,
    pp.target_value,
    CASE WHEN pp.target_value IS NULL OR pp.target_value = 0 THEN 0
         ELSE round(100.0 * pp.current_value / NULLIF(pp.target_value, 0), 1) END
  FROM founder_annual_plan_pillars pp
  JOIN founder_annual_plans p ON p.id = pp.plan_id
  WHERE p.plan_year = p_from_year
    AND pp.health_status IN ('at_risk','off_track','blocked')
  ORDER BY pp.pillar_order;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_health_distribution()
RETURNS TABLE (
  health_status text,
  pillar_count bigint,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM founder_annual_plan_pillars pp
    JOIN founder_annual_plans p ON p.id = pp.plan_id
    WHERE p.status IN ('active','mid_year_refresh');
  RETURN QUERY
  SELECT
    pp.health_status,
    count(*)::bigint,
    CASE WHEN v_total = 0 THEN 0 ELSE round(100.0 * count(*) / NULLIF(v_total, 0), 1) END
  FROM founder_annual_plan_pillars pp
  JOIN founder_annual_plans p ON p.id = pp.plan_id
  WHERE p.status IN ('active','mid_year_refresh')
  GROUP BY pp.health_status
  ORDER BY 2 DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_annual_plan_year_compare()
RETURNS TABLE (
  plan_year int,
  total_pillars bigint,
  done_pillars bigint,
  completion_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.plan_year,
    COALESCE((SELECT count(*) FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id), 0),
    COALESCE((SELECT count(*) FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id AND pp.health_status = 'done'), 0),
    COALESCE(
      (SELECT round(100.0 * count(*) FILTER (WHERE pp.health_status = 'done') / NULLIF(count(*), 0), 1)
       FROM founder_annual_plan_pillars pp WHERE pp.plan_id = p.id),
      0
    ),
    p.status
  FROM founder_annual_plans p
  ORDER BY p.plan_year DESC;
END;
$$;

-- =====================================================
-- LOG HELPERS (VOLATILE)
-- =====================================================

CREATE OR REPLACE FUNCTION log_founder_annual_plan_created(p_plan_id uuid, p_plan_year int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_annual_plan_created',
    jsonb_build_object('plan_id', p_plan_id, 'plan_year', p_plan_year)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_annual_plan_checkpoint(p_plan_id uuid, p_quarter text, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_annual_plan_checkpoint',
    jsonb_build_object('plan_id', p_plan_id, 'quarter', p_quarter, 'status', p_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_annual_plan_mid_year_refresh(p_plan_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_annual_plan_mid_year_refresh',
    jsonb_build_object('plan_id', p_plan_id, 'refreshed_at', now())
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_annual_plan_carryover(p_plan_id uuid, p_from_year int, p_pillar_count int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_annual_plan_carryover',
    jsonb_build_object('plan_id', p_plan_id, 'from_year', p_from_year, 'pillar_count', p_pillar_count)
  );
END;
$$;

-- =====================================================
-- GRANTS
-- =====================================================

REVOKE EXECUTE ON FUNCTION founder_annual_plan_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_annual_plan_current() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_annual_plan_pillars_list(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_annual_plan_quarter_summary(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_annual_plan_carryover_candidates(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_annual_plan_health_distribution() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_annual_plan_year_compare() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_annual_plan_created(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_annual_plan_checkpoint(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_annual_plan_mid_year_refresh(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_annual_plan_carryover(uuid, int, int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_annual_plan_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_annual_plan_current() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_annual_plan_pillars_list(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_annual_plan_quarter_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_annual_plan_carryover_candidates(int) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_annual_plan_health_distribution() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_annual_plan_year_compare() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_annual_plan_created(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_annual_plan_checkpoint(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_annual_plan_mid_year_refresh(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_annual_plan_carryover(uuid, int, int) TO authenticated;

COMMIT;