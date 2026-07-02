BEGIN;

-- Engineer wellness check-in: monthly stress/workload/growth signal capture
-- Feeds per-engineer wellness score + founder action list for burnout prevention.

CREATE TABLE IF NOT EXISTS engineer_wellness_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  period_month date NOT NULL,
  stress_score smallint NOT NULL CHECK (stress_score BETWEEN 1 AND 10),
  workload_score smallint NOT NULL CHECK (workload_score BETWEEN 1 AND 10),
  growth_score smallint NOT NULL CHECK (growth_score BETWEEN 1 AND 10),
  free_text text,
  wants_callback boolean NOT NULL DEFAULT false,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_user_id, period_month)
);

CREATE INDEX IF NOT EXISTS engineer_wellness_checkins_engineer_idx
  ON engineer_wellness_checkins (engineer_user_id, period_month DESC);
CREATE INDEX IF NOT EXISTS engineer_wellness_checkins_month_idx
  ON engineer_wellness_checkins (period_month DESC);

ALTER TABLE engineer_wellness_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_wellness_checkins_founder ON engineer_wellness_checkins;
CREATE POLICY engineer_wellness_checkins_founder
  ON engineer_wellness_checkins
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_wellness_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('callback','timeoff','workload_rebalance','mentor_pairing','exit_interview','no_action')),
  notes text,
  created_by uuid REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

CREATE INDEX IF NOT EXISTS engineer_wellness_actions_engineer_idx
  ON engineer_wellness_actions (engineer_user_id, created_at DESC);

ALTER TABLE engineer_wellness_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_wellness_actions_founder ON engineer_wellness_actions;
CREATE POLICY engineer_wellness_actions_founder
  ON engineer_wellness_actions
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- READ RPC 1: per-engineer wellness scoreboard (latest 6 months avg)
DROP FUNCTION IF EXISTS founder_engineer_wellness_scoreboard();
CREATE FUNCTION founder_engineer_wellness_scoreboard()
RETURNS TABLE (
  engineer_user_id uuid,
  full_name text,
  tier text,
  checkins_6mo integer,
  avg_stress numeric,
  avg_workload numeric,
  avg_growth numeric,
  wellness_score numeric,
  last_checkin timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.user_id,
    p.full_name,
    e.cached_highest_tier,
    COUNT(c.id)::int,
    ROUND(AVG(c.stress_score)::numeric, 2),
    ROUND(AVG(c.workload_score)::numeric, 2),
    ROUND(AVG(c.growth_score)::numeric, 2),
    ROUND(((11 - COALESCE(AVG(c.stress_score), 5)) + (11 - COALESCE(AVG(c.workload_score), 5)) + COALESCE(AVG(c.growth_score), 5))::numeric / 3.0, 2),
    MAX(c.submitted_at)
  FROM engineers e
  JOIN profiles p ON p.id = e.user_id
  LEFT JOIN engineer_wellness_checkins c
    ON c.engineer_user_id = e.user_id
   AND c.period_month >= (date_trunc('month', now())::date - INTERVAL '6 months')
  GROUP BY e.user_id, p.full_name, e.cached_highest_tier
  ORDER BY ROUND(((11 - COALESCE(AVG(c.stress_score), 5)) + (11 - COALESCE(AVG(c.workload_score), 5)) + COALESCE(AVG(c.growth_score), 5))::numeric / 3.0, 2) ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_wellness_scoreboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wellness_scoreboard() TO authenticated;

-- READ RPC 2: founder action list (engineers needing intervention)
DROP FUNCTION IF EXISTS founder_engineer_wellness_action_list();
CREATE FUNCTION founder_engineer_wellness_action_list()
RETURNS TABLE (
  engineer_user_id uuid,
  full_name text,
  tier text,
  last_stress smallint,
  last_workload smallint,
  last_growth smallint,
  wants_callback boolean,
  submitted_at timestamptz,
  reason text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (c.engineer_user_id)
    c.engineer_user_id,
    p.full_name,
    e.cached_highest_tier,
    c.stress_score,
    c.workload_score,
    c.growth_score,
    c.wants_callback,
    c.submitted_at,
    CASE
      WHEN c.wants_callback THEN 'requested_callback'
      WHEN c.stress_score >= 8 THEN 'high_stress'
      WHEN c.workload_score >= 9 THEN 'overloaded'
      WHEN c.growth_score <= 3 THEN 'growth_stalled'
      ELSE 'monitor'
    END
  FROM engineer_wellness_checkins c
  JOIN profiles p ON p.id = c.engineer_user_id
  LEFT JOIN engineers e ON e.user_id = c.engineer_user_id
  WHERE (c.wants_callback OR c.stress_score >= 8 OR c.workload_score >= 9 OR c.growth_score <= 3)
    AND c.submitted_at >= (now() - INTERVAL '45 days')
  ORDER BY c.engineer_user_id, c.submitted_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_wellness_action_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wellness_action_list() TO authenticated;

-- READ RPC 3: monthly trend
DROP FUNCTION IF EXISTS founder_engineer_wellness_monthly_trend();
CREATE FUNCTION founder_engineer_wellness_monthly_trend()
RETURNS TABLE (
  period_month date,
  checkins integer,
  avg_stress numeric,
  avg_workload numeric,
  avg_growth numeric,
  callbacks integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.period_month,
    COUNT(*)::int,
    ROUND(AVG(c.stress_score)::numeric, 2),
    ROUND(AVG(c.workload_score)::numeric, 2),
    ROUND(AVG(c.growth_score)::numeric, 2),
    SUM(CASE WHEN c.wants_callback THEN 1 ELSE 0 END)::int
  FROM engineer_wellness_checkins c
  WHERE c.period_month >= (date_trunc('month', now())::date - INTERVAL '12 months')
  GROUP BY c.period_month
  ORDER BY c.period_month DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_wellness_monthly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wellness_monthly_trend() TO authenticated;

-- READ RPC 4: recent open actions
DROP FUNCTION IF EXISTS founder_engineer_wellness_open_actions();
CREATE FUNCTION founder_engineer_wellness_open_actions()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  full_name text,
  action_type text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.engineer_user_id, p.full_name, a.action_type, a.notes, a.created_at
  FROM engineer_wellness_actions a
  JOIN profiles p ON p.id = a.engineer_user_id
  WHERE a.closed_at IS NULL
  ORDER BY a.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_wellness_open_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wellness_open_actions() TO authenticated;

-- WRITE RPC 1: log a wellness check-in (founder backfill / proxy entry)
DROP FUNCTION IF EXISTS log_founder_engineer_wellness_checkin(uuid, date, smallint, smallint, smallint, text, boolean);
CREATE FUNCTION log_founder_engineer_wellness_checkin(
  p_engineer uuid,
  p_month date,
  p_stress smallint,
  p_workload smallint,
  p_growth smallint,
  p_notes text,
  p_wants_callback boolean
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_wellness_checkins(engineer_user_id, period_month, stress_score, workload_score, growth_score, free_text, wants_callback)
  VALUES (p_engineer, date_trunc('month', p_month)::date, p_stress, p_workload, p_growth, p_notes, COALESCE(p_wants_callback, false))
  ON CONFLICT (engineer_user_id, period_month) DO UPDATE
    SET stress_score = EXCLUDED.stress_score,
        workload_score = EXCLUDED.workload_score,
        growth_score = EXCLUDED.growth_score,
        free_text = EXCLUDED.free_text,
        wants_callback = EXCLUDED.wants_callback,
        submitted_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_engineer_wellness_checkin',
    jsonb_build_object('checkin_id', v_id, 'engineer', p_engineer, 'month', p_month, 'stress', p_stress, 'workload', p_workload, 'growth', p_growth, 'wants_callback', p_wants_callback),
    now()
  );
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_engineer_wellness_checkin(uuid, date, smallint, smallint, smallint, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_engineer_wellness_checkin(uuid, date, smallint, smallint, smallint, text, boolean) TO authenticated;

-- WRITE RPC 2: open a founder action on an engineer
DROP FUNCTION IF EXISTS log_founder_engineer_wellness_action(uuid, text, text);
CREATE FUNCTION log_founder_engineer_wellness_action(
  p_engineer uuid,
  p_action_type text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_wellness_actions(engineer_user_id, action_type, notes, created_by)
  VALUES (p_engineer, p_action_type, p_notes, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_engineer_wellness_action',
    jsonb_build_object('action_id', v_id, 'engineer', p_engineer, 'action_type', p_action_type),
    now()
  );
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_engineer_wellness_action(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_engineer_wellness_action(uuid, text, text) TO authenticated;

-- WRITE RPC 3: close an open action
DROP FUNCTION IF EXISTS log_founder_engineer_wellness_action_close(uuid, text);
CREATE FUNCTION log_founder_engineer_wellness_action_close(
  p_action_id uuid,
  p_resolution text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_wellness_actions
     SET closed_at = now(),
         notes = COALESCE(notes,'') || E'\n[closed] ' || COALESCE(p_resolution,'')
   WHERE id = p_action_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_engineer_wellness_action_close',
    jsonb_build_object('action_id', p_action_id, 'resolution', p_resolution),
    now()
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_engineer_wellness_action_close(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_engineer_wellness_action_close(uuid, text) TO authenticated;

COMMIT;