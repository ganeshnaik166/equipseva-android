BEGIN;

-- ============================================================================
-- Round 1537 — Founder Engineer Wellbeing Pulse Survey
-- Weekly 5-question pulse: workload, support, growth, burnout-risk, joy.
-- Per-engineer trend, founder review of red flags.
-- ============================================================================

-- Survey cycles (weekly cadence anchor)
CREATE TABLE IF NOT EXISTS engineer_wellbeing_cycles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_label text NOT NULL UNIQUE,
  starts_on date NOT NULL,
  ends_on date NOT NULL,
  is_open boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_engineer_wellbeing_cycles_starts ON engineer_wellbeing_cycles(starts_on DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_wellbeing_cycles_open ON engineer_wellbeing_cycles(is_open) WHERE is_open;

ALTER TABLE engineer_wellbeing_cycles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_wellbeing_cycles ON engineer_wellbeing_cycles;
CREATE POLICY founder_only_wellbeing_cycles ON engineer_wellbeing_cycles
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Per-engineer responses for a cycle
CREATE TABLE IF NOT EXISTS engineer_wellbeing_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES engineer_wellbeing_cycles(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  workload_score int NOT NULL CHECK (workload_score BETWEEN 1 AND 5),
  support_score int NOT NULL CHECK (support_score BETWEEN 1 AND 5),
  growth_score int NOT NULL CHECK (growth_score BETWEEN 1 AND 5),
  burnout_risk int NOT NULL CHECK (burnout_risk BETWEEN 1 AND 5),
  joy_score int NOT NULL CHECK (joy_score BETWEEN 1 AND 5),
  free_text text,
  composite_score numeric GENERATED ALWAYS AS (
    ((workload_score + support_score + growth_score + joy_score)::numeric - burnout_risk::numeric) / 4.0
  ) STORED,
  is_red_flag boolean NOT NULL DEFAULT false,
  reviewed_at timestamptz,
  reviewed_by uuid,
  founder_note text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (cycle_id, engineer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_engineer_wellbeing_responses_eng ON engineer_wellbeing_responses(engineer_user_id, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_wellbeing_responses_red ON engineer_wellbeing_responses(is_red_flag) WHERE is_red_flag;
CREATE INDEX IF NOT EXISTS idx_engineer_wellbeing_responses_cycle ON engineer_wellbeing_responses(cycle_id);

ALTER TABLE engineer_wellbeing_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_wellbeing_responses ON engineer_wellbeing_responses;
CREATE POLICY founder_only_wellbeing_responses ON engineer_wellbeing_responses
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Red-flag flag trigger: burnout_risk >= 4 OR joy <= 2 OR composite < 2
CREATE OR REPLACE FUNCTION trg_engineer_wellbeing_red_flag()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.is_red_flag := (NEW.burnout_risk >= 4) OR (NEW.joy_score <= 2)
                  OR (((NEW.workload_score + NEW.support_score + NEW.growth_score + NEW.joy_score)::numeric - NEW.burnout_risk::numeric) / 4.0 < 2.0);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_wellbeing_red_flag ON engineer_wellbeing_responses;
CREATE TRIGGER trg_wellbeing_red_flag
  BEFORE INSERT OR UPDATE ON engineer_wellbeing_responses
  FOR EACH ROW EXECUTE FUNCTION trg_engineer_wellbeing_red_flag();

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

DROP FUNCTION IF EXISTS founder_wellbeing_kpis();
CREATE OR REPLACE FUNCTION founder_wellbeing_kpis()
RETURNS TABLE (
  open_cycles bigint,
  total_cycles bigint,
  total_responses bigint,
  responses_30d bigint,
  responses_7d bigint,
  red_flags_total bigint,
  red_flags_open bigint,
  red_flags_7d bigint,
  engineers_responded_30d bigint,
  avg_workload numeric,
  avg_support numeric,
  avg_growth numeric,
  avg_burnout numeric,
  avg_joy numeric,
  avg_composite numeric,
  worst_composite numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM engineer_wellbeing_cycles WHERE is_open),
    (SELECT count(*) FROM engineer_wellbeing_cycles),
    (SELECT count(*) FROM engineer_wellbeing_responses),
    (SELECT count(*) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT count(*) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '7 days'),
    (SELECT count(*) FROM engineer_wellbeing_responses WHERE is_red_flag),
    (SELECT count(*) FROM engineer_wellbeing_responses WHERE is_red_flag AND reviewed_at IS NULL),
    (SELECT count(*) FROM engineer_wellbeing_responses WHERE is_red_flag AND submitted_at >= now() - interval '7 days'),
    (SELECT count(DISTINCT engineer_user_id) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT round(avg(workload_score)::numeric, 2) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT round(avg(support_score)::numeric, 2) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT round(avg(growth_score)::numeric, 2) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT round(avg(burnout_risk)::numeric, 2) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT round(avg(joy_score)::numeric, 2) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT round(avg(composite_score)::numeric, 2) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'),
    (SELECT round(min(composite_score)::numeric, 2) FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days');
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_wellbeing_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_wellbeing_kpis() TO authenticated;

DROP FUNCTION IF EXISTS founder_wellbeing_cycles_list();
CREATE OR REPLACE FUNCTION founder_wellbeing_cycles_list()
RETURNS TABLE (
  id uuid,
  cycle_label text,
  starts_on date,
  ends_on date,
  is_open boolean,
  response_count bigint,
  red_flag_count bigint,
  avg_composite numeric,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.cycle_label, c.starts_on, c.ends_on, c.is_open,
         (SELECT count(*) FROM engineer_wellbeing_responses r WHERE r.cycle_id = c.id),
         (SELECT count(*) FROM engineer_wellbeing_responses r WHERE r.cycle_id = c.id AND r.is_red_flag),
         (SELECT round(avg(r.composite_score)::numeric, 2) FROM engineer_wellbeing_responses r WHERE r.cycle_id = c.id),
         c.created_at
  FROM engineer_wellbeing_cycles c
  ORDER BY c.starts_on DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_wellbeing_cycles_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_wellbeing_cycles_list() TO authenticated;

DROP FUNCTION IF EXISTS founder_wellbeing_red_flags();
CREATE OR REPLACE FUNCTION founder_wellbeing_red_flags()
RETURNS TABLE (
  id uuid,
  cycle_label text,
  engineer_user_id uuid,
  engineer_email text,
  burnout_risk int,
  joy_score int,
  workload_score int,
  support_score int,
  growth_score int,
  composite_score numeric,
  free_text text,
  reviewed_at timestamptz,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, c.cycle_label, r.engineer_user_id,
         (SELECT u.email FROM auth.users u WHERE u.id = r.engineer_user_id),
         r.burnout_risk, r.joy_score, r.workload_score, r.support_score, r.growth_score,
         r.composite_score, r.free_text, r.reviewed_at, r.submitted_at
  FROM engineer_wellbeing_responses r
  JOIN engineer_wellbeing_cycles c ON c.id = r.cycle_id
  WHERE r.is_red_flag
  ORDER BY r.reviewed_at IS NULL DESC, r.submitted_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_wellbeing_red_flags() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_wellbeing_red_flags() TO authenticated;

DROP FUNCTION IF EXISTS founder_wellbeing_engineer_trend();
CREATE OR REPLACE FUNCTION founder_wellbeing_engineer_trend()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  responses_count bigint,
  avg_composite numeric,
  latest_composite numeric,
  latest_burnout int,
  latest_joy int,
  red_flag_count bigint,
  last_submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT r.engineer_user_id,
           count(*) AS rc,
           round(avg(r.composite_score)::numeric, 2) AS avg_c,
           count(*) FILTER (WHERE r.is_red_flag) AS red_c,
           max(r.submitted_at) AS last_at
    FROM engineer_wellbeing_responses r
    WHERE r.submitted_at >= now() - interval '90 days'
    GROUP BY r.engineer_user_id
  ),
  latest AS (
    SELECT DISTINCT ON (r.engineer_user_id)
           r.engineer_user_id, r.composite_score, r.burnout_risk, r.joy_score
    FROM engineer_wellbeing_responses r
    ORDER BY r.engineer_user_id, r.submitted_at DESC
  )
  SELECT a.engineer_user_id,
         (SELECT u.email FROM auth.users u WHERE u.id = a.engineer_user_id),
         a.rc, a.avg_c,
         l.composite_score, l.burnout_risk, l.joy_score,
         a.red_c, a.last_at
  FROM agg a
  LEFT JOIN latest l ON l.engineer_user_id = a.engineer_user_id
  ORDER BY a.avg_c ASC NULLS LAST
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_wellbeing_engineer_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_wellbeing_engineer_trend() TO authenticated;

DROP FUNCTION IF EXISTS founder_wellbeing_recent_responses();
CREATE OR REPLACE FUNCTION founder_wellbeing_recent_responses()
RETURNS TABLE (
  id uuid,
  cycle_label text,
  engineer_email text,
  workload_score int,
  support_score int,
  growth_score int,
  burnout_risk int,
  joy_score int,
  composite_score numeric,
  is_red_flag boolean,
  submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, c.cycle_label,
         (SELECT u.email FROM auth.users u WHERE u.id = r.engineer_user_id),
         r.workload_score, r.support_score, r.growth_score, r.burnout_risk, r.joy_score,
         r.composite_score, r.is_red_flag, r.submitted_at
  FROM engineer_wellbeing_responses r
  JOIN engineer_wellbeing_cycles c ON c.id = r.cycle_id
  ORDER BY r.submitted_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_wellbeing_recent_responses() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_wellbeing_recent_responses() TO authenticated;

DROP FUNCTION IF EXISTS founder_wellbeing_dimension_breakdown();
CREATE OR REPLACE FUNCTION founder_wellbeing_dimension_breakdown()
RETURNS TABLE (
  dimension text,
  avg_score numeric,
  count_1 bigint,
  count_2 bigint,
  count_3 bigint,
  count_4 bigint,
  count_5 bigint,
  total_responses bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'workload'::text, round(avg(workload_score)::numeric,2),
         count(*) FILTER (WHERE workload_score=1), count(*) FILTER (WHERE workload_score=2),
         count(*) FILTER (WHERE workload_score=3), count(*) FILTER (WHERE workload_score=4),
         count(*) FILTER (WHERE workload_score=5), count(*)
  FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'
  UNION ALL
  SELECT 'support', round(avg(support_score)::numeric,2),
         count(*) FILTER (WHERE support_score=1), count(*) FILTER (WHERE support_score=2),
         count(*) FILTER (WHERE support_score=3), count(*) FILTER (WHERE support_score=4),
         count(*) FILTER (WHERE support_score=5), count(*)
  FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'
  UNION ALL
  SELECT 'growth', round(avg(growth_score)::numeric,2),
         count(*) FILTER (WHERE growth_score=1), count(*) FILTER (WHERE growth_score=2),
         count(*) FILTER (WHERE growth_score=3), count(*) FILTER (WHERE growth_score=4),
         count(*) FILTER (WHERE growth_score=5), count(*)
  FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'
  UNION ALL
  SELECT 'burnout_risk', round(avg(burnout_risk)::numeric,2),
         count(*) FILTER (WHERE burnout_risk=1), count(*) FILTER (WHERE burnout_risk=2),
         count(*) FILTER (WHERE burnout_risk=3), count(*) FILTER (WHERE burnout_risk=4),
         count(*) FILTER (WHERE burnout_risk=5), count(*)
  FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days'
  UNION ALL
  SELECT 'joy', round(avg(joy_score)::numeric,2),
         count(*) FILTER (WHERE joy_score=1), count(*) FILTER (WHERE joy_score=2),
         count(*) FILTER (WHERE joy_score=3), count(*) FILTER (WHERE joy_score=4),
         count(*) FILTER (WHERE joy_score=5), count(*)
  FROM engineer_wellbeing_responses WHERE submitted_at >= now() - interval '30 days';
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_wellbeing_dimension_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_wellbeing_dimension_breakdown() TO authenticated;

DROP FUNCTION IF EXISTS founder_wellbeing_weekly_trend();
CREATE OR REPLACE FUNCTION founder_wellbeing_weekly_trend()
RETURNS TABLE (
  week_start date,
  responses bigint,
  red_flags bigint,
  avg_composite numeric,
  avg_burnout numeric,
  avg_joy numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', r.submitted_at)::date AS wk,
         count(*),
         count(*) FILTER (WHERE r.is_red_flag),
         round(avg(r.composite_score)::numeric, 2),
         round(avg(r.burnout_risk)::numeric, 2),
         round(avg(r.joy_score)::numeric, 2)
  FROM engineer_wellbeing_responses r
  WHERE r.submitted_at >= now() - interval '12 weeks'
  GROUP BY wk
  ORDER BY wk DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_wellbeing_weekly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_wellbeing_weekly_trend() TO authenticated;

-- ============================================================================
-- WRITE helpers (VOLATILE) — log to founder_action_log
-- ============================================================================

DROP FUNCTION IF EXISTS log_founder_wellbeing_open_cycle(text, date, date);
CREATE OR REPLACE FUNCTION log_founder_wellbeing_open_cycle(
  p_label text,
  p_starts date,
  p_ends date
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_wellbeing_cycles (cycle_label, starts_on, ends_on, is_open)
  VALUES (p_label, p_starts, p_ends, true)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'wellbeing_open_cycle',
          jsonb_build_object('cycle_id', v_id, 'label', p_label, 'starts', p_starts, 'ends', p_ends));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_wellbeing_open_cycle(text, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_wellbeing_open_cycle(text, date, date) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_wellbeing_close_cycle(uuid);
CREATE OR REPLACE FUNCTION log_founder_wellbeing_close_cycle(p_cycle_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_wellbeing_cycles
     SET is_open = false, closed_at = now()
   WHERE id = p_cycle_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'wellbeing_close_cycle',
          jsonb_build_object('cycle_id', p_cycle_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_wellbeing_close_cycle(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_wellbeing_close_cycle(uuid) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_wellbeing_review_response(uuid, text);
CREATE OR REPLACE FUNCTION log_founder_wellbeing_review_response(
  p_response_id uuid,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_wellbeing_responses
     SET reviewed_at = now(),
         reviewed_by = auth.uid(),
         founder_note = p_note
   WHERE id = p_response_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'wellbeing_review_response',
          jsonb_build_object('response_id', p_response_id, 'note', p_note));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_wellbeing_review_response(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_wellbeing_review_response(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS log_founder_wellbeing_submit_response(uuid, uuid, int, int, int, int, int, text);
CREATE OR REPLACE FUNCTION log_founder_wellbeing_submit_response(
  p_cycle_id uuid,
  p_engineer_user_id uuid,
  p_workload int,
  p_support int,
  p_growth int,
  p_burnout int,
  p_joy int,
  p_free_text text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_wellbeing_responses
    (cycle_id, engineer_user_id, workload_score, support_score, growth_score, burnout_risk, joy_score, free_text)
  VALUES (p_cycle_id, p_engineer_user_id, p_workload, p_support, p_growth, p_burnout, p_joy, p_free_text)
  ON CONFLICT (cycle_id, engineer_user_id) DO UPDATE
    SET workload_score = EXCLUDED.workload_score,
        support_score = EXCLUDED.support_score,
        growth_score = EXCLUDED.growth_score,
        burnout_risk = EXCLUDED.burnout_risk,
        joy_score = EXCLUDED.joy_score,
        free_text = EXCLUDED.free_text,
        submitted_at = now()
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'wellbeing_submit_response',
          jsonb_build_object('response_id', v_id, 'cycle_id', p_cycle_id, 'engineer_user_id', p_engineer_user_id));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_wellbeing_submit_response(uuid, uuid, int, int, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_wellbeing_submit_response(uuid, uuid, int, int, int, int, int, text) TO authenticated;

COMMIT;