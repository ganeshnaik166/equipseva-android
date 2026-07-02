BEGIN;

-- Round 1603 — Founder Engineer Field-Test Program
-- Beta-test new tools/SOPs with engineer subset; track cohorts + outcomes;
-- founder graduate-to-fleet decision.

-- =========================================================================
-- Tables
-- =========================================================================

CREATE TABLE IF NOT EXISTS engineer_field_tests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  hypothesis text NOT NULL,
  test_kind text NOT NULL CHECK (test_kind IN ('tool','sop','workflow','training','equipment')),
  status text NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned','running','paused','complete','graduated','rejected')),
  cohort_size_target int NOT NULL DEFAULT 5 CHECK (cohort_size_target > 0),
  success_metric text NOT NULL,
  success_threshold_pct numeric(5,2) NOT NULL DEFAULT 70 CHECK (success_threshold_pct BETWEEN 0 AND 100),
  baseline_value numeric(12,2),
  observed_value numeric(12,2),
  started_at timestamptz,
  ended_at timestamptz,
  graduated_at timestamptz,
  rejected_at timestamptz,
  decision_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_field_tests_status ON engineer_field_tests(status);
CREATE INDEX IF NOT EXISTS idx_field_tests_kind ON engineer_field_tests(test_kind);
CREATE INDEX IF NOT EXISTS idx_field_tests_started ON engineer_field_tests(started_at DESC);

CREATE TABLE IF NOT EXISTS engineer_field_test_outcomes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_test_id uuid NOT NULL REFERENCES engineer_field_tests(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  outcome text CHECK (outcome IN ('pending','success','partial','fail','dropout')),
  metric_value numeric(12,2),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (field_test_id, engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_field_test_outcomes_test ON engineer_field_test_outcomes(field_test_id);
CREATE INDEX IF NOT EXISTS idx_field_test_outcomes_eng ON engineer_field_test_outcomes(engineer_id);
CREATE INDEX IF NOT EXISTS idx_field_test_outcomes_outcome ON engineer_field_test_outcomes(outcome);

ALTER TABLE engineer_field_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE engineer_field_test_outcomes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_field_tests" ON engineer_field_tests;
CREATE POLICY "founder_only_field_tests" ON engineer_field_tests
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS "founder_only_field_test_outcomes" ON engineer_field_test_outcomes;
CREATE POLICY "founder_only_field_test_outcomes" ON engineer_field_test_outcomes
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- Helper: log entries
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_field_test_create(p_test_id uuid, p_title text, p_kind text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'field_test.create',
          jsonb_build_object('test_id', p_test_id, 'title', p_title, 'kind', p_kind));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_field_test_create(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_field_test_create(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_field_test_enroll(p_test_id uuid, p_engineer_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'field_test.enroll',
          jsonb_build_object('test_id', p_test_id, 'engineer_id', p_engineer_id));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_field_test_enroll(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_field_test_enroll(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_field_test_outcome(p_outcome_id uuid, p_outcome text, p_value numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'field_test.record_outcome',
          jsonb_build_object('outcome_id', p_outcome_id, 'outcome', p_outcome, 'value', p_value));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_field_test_outcome(uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_field_test_outcome(uuid, text, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_field_test_decision(p_test_id uuid, p_decision text, p_notes text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'field_test.decision',
          jsonb_build_object('test_id', p_test_id, 'decision', p_decision, 'notes', p_notes));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_field_test_decision(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_field_test_decision(uuid, text, text) TO authenticated;

-- =========================================================================
-- Read RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_field_test_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH t AS (
    SELECT
      count(*)::int AS total_tests,
      count(*) FILTER (WHERE status='planned')::int AS planned,
      count(*) FILTER (WHERE status='running')::int AS running,
      count(*) FILTER (WHERE status='paused')::int AS paused,
      count(*) FILTER (WHERE status='complete')::int AS complete,
      count(*) FILTER (WHERE status='graduated')::int AS graduated,
      count(*) FILTER (WHERE status='rejected')::int AS rejected,
      count(*) FILTER (WHERE test_kind='tool')::int AS tool_tests,
      count(*) FILTER (WHERE test_kind='sop')::int AS sop_tests,
      count(*) FILTER (WHERE test_kind='workflow')::int AS workflow_tests,
      count(*) FILTER (WHERE test_kind='training')::int AS training_tests,
      count(*) FILTER (WHERE test_kind='equipment')::int AS equipment_tests
    FROM engineer_field_tests
  ),
  o AS (
    SELECT
      count(*)::int AS total_outcomes,
      count(*) FILTER (WHERE outcome='success')::int AS successes,
      count(*) FILTER (WHERE outcome='fail')::int AS failures,
      count(*) FILTER (WHERE outcome='dropout')::int AS dropouts,
      count(DISTINCT engineer_id)::int AS unique_engineers
    FROM engineer_field_test_outcomes
  )
  SELECT to_jsonb(t.*) || to_jsonb(o.*) INTO r FROM t, o;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION founder_field_test_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_field_test_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_field_test_list()
RETURNS TABLE (
  id uuid, title text, test_kind text, status text,
  cohort_size_target int, enrolled int, success_rate_pct numeric,
  started_at timestamptz, ended_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH e AS (
    SELECT field_test_id, count(*)::int AS enrolled
    FROM engineer_field_test_outcomes GROUP BY field_test_id
  ),
  s AS (
    SELECT field_test_id,
      ROUND(100.0 * count(*) FILTER (WHERE outcome='success')::numeric / NULLIF(count(*),0), 1) AS rate
    FROM engineer_field_test_outcomes
    WHERE outcome IS NOT NULL AND outcome <> 'pending'
    GROUP BY field_test_id
  )
  SELECT f.id, f.title, f.test_kind, f.status, f.cohort_size_target,
         COALESCE(e.enrolled, 0), COALESCE(s.rate, 0)::numeric,
         f.started_at, f.ended_at
  FROM engineer_field_tests f
  LEFT JOIN e ON e.field_test_id = f.id
  LEFT JOIN s ON s.field_test_id = f.id
  ORDER BY f.created_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_field_test_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_field_test_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_field_test_running()
RETURNS TABLE (
  id uuid, title text, test_kind text, success_metric text,
  success_threshold_pct numeric, baseline_value numeric, observed_value numeric,
  enrolled int, days_running numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH e AS (
    SELECT field_test_id, count(*)::int AS enrolled
    FROM engineer_field_test_outcomes GROUP BY field_test_id
  )
  SELECT f.id, f.title, f.test_kind, f.success_metric,
         f.success_threshold_pct, f.baseline_value, f.observed_value,
         COALESCE(e.enrolled, 0),
         ROUND(EXTRACT(EPOCH FROM (now() - f.started_at)) / 86400.0, 1)::numeric AS days_running
  FROM engineer_field_tests f
  LEFT JOIN e ON e.field_test_id = f.id
  WHERE f.status = 'running'
  ORDER BY f.started_at ASC NULLS LAST
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_field_test_running() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_field_test_running() TO authenticated;

CREATE OR REPLACE FUNCTION founder_field_test_outcomes_recent()
RETURNS TABLE (
  id uuid, field_test_id uuid, test_title text, engineer_id uuid,
  outcome text, metric_value numeric, completed_at timestamptz, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.field_test_id, f.title, o.engineer_id,
         o.outcome, o.metric_value, o.completed_at, o.notes
  FROM engineer_field_test_outcomes o
  JOIN engineer_field_tests f ON f.id = o.field_test_id
  WHERE o.completed_at IS NOT NULL
  ORDER BY o.completed_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_field_test_outcomes_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_field_test_outcomes_recent() TO authenticated;

CREATE OR REPLACE FUNCTION founder_field_test_graduation_candidates()
RETURNS TABLE (
  id uuid, title text, test_kind text, success_threshold_pct numeric,
  observed_rate_pct numeric, enrolled int, cohort_size_target int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH s AS (
    SELECT field_test_id,
      count(*)::int AS enrolled,
      ROUND(100.0 * count(*) FILTER (WHERE outcome='success')::numeric / NULLIF(count(*) FILTER (WHERE outcome IS NOT NULL AND outcome <> 'pending'),0), 1) AS rate
    FROM engineer_field_test_outcomes
    GROUP BY field_test_id
  )
  SELECT f.id, f.title, f.test_kind, f.success_threshold_pct,
         COALESCE(s.rate, 0)::numeric, COALESCE(s.enrolled, 0), f.cohort_size_target
  FROM engineer_field_tests f
  LEFT JOIN s ON s.field_test_id = f.id
  WHERE f.status IN ('running','complete')
    AND COALESCE(s.enrolled, 0) >= f.cohort_size_target
    AND COALESCE(s.rate, 0) >= f.success_threshold_pct
  ORDER BY s.rate DESC NULLS LAST
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_field_test_graduation_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_field_test_graduation_candidates() TO authenticated;

CREATE OR REPLACE FUNCTION founder_field_test_engineer_leaderboard()
RETURNS TABLE (
  engineer_id uuid, tests_run int, successes int, failures int, success_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.engineer_id,
         count(*)::int AS tests_run,
         count(*) FILTER (WHERE outcome='success')::int AS successes,
         count(*) FILTER (WHERE outcome='fail')::int AS failures,
         ROUND(100.0 * count(*) FILTER (WHERE outcome='success')::numeric / NULLIF(count(*) FILTER (WHERE outcome IS NOT NULL AND outcome <> 'pending'),0), 1)::numeric AS success_rate_pct
  FROM engineer_field_test_outcomes o
  GROUP BY o.engineer_id
  ORDER BY tests_run DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_field_test_engineer_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_field_test_engineer_leaderboard() TO authenticated;

-- =========================================================================
-- Write RPC (VOLATILE) — founder graduate-to-fleet decision
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_field_test_decide(
  p_test_id uuid,
  p_decision text,
  p_notes text DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('graduated','rejected') THEN
    RAISE EXCEPTION 'invalid decision: %', p_decision;
  END IF;
  UPDATE engineer_field_tests
    SET status = p_decision,
        graduated_at = CASE WHEN p_decision='graduated' THEN now() ELSE graduated_at END,
        rejected_at = CASE WHEN p_decision='rejected' THEN now() ELSE rejected_at END,
        decision_notes = COALESCE(p_notes, decision_notes),
        ended_at = COALESCE(ended_at, now()),
        updated_at = now()
    WHERE id = p_test_id;
  PERFORM log_founder_field_test_decision(p_test_id, p_decision, p_notes);
  RETURN p_test_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_field_test_decide(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_field_test_decide(uuid, text, text) TO authenticated;

COMMIT;