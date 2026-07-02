BEGIN;

-- ============================================================================
-- r1471 — Engineer Customer Effort Score (CES)
-- Capture per-job effort scores from hospital contacts; surface frictions.
-- ============================================================================

-- ---- Tables ----------------------------------------------------------------

CREATE TABLE IF NOT EXISTS engineer_ces_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id uuid NOT NULL REFERENCES repair_jobs(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  respondent_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  ces_score smallint NOT NULL CHECK (ces_score BETWEEN 1 AND 7),
  effort_bucket text NOT NULL CHECK (effort_bucket IN ('low_effort','neutral','high_effort')),
  friction_tag text,
  free_text text,
  responded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_ces_responses_engineer
  ON engineer_ces_responses(engineer_id, responded_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_ces_responses_hospital
  ON engineer_ces_responses(hospital_org_id, responded_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_ces_responses_bucket
  ON engineer_ces_responses(effort_bucket, responded_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_engineer_ces_per_job
  ON engineer_ces_responses(repair_job_id);

ALTER TABLE engineer_ces_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_engineer_ces_responses_founder_only ON engineer_ces_responses;
CREATE POLICY p_engineer_ces_responses_founder_only
  ON engineer_ces_responses
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS engineer_ces_friction_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  response_id uuid NOT NULL REFERENCES engineer_ces_responses(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('coach_call','training','reassign','suspend','followup','closed')),
  notes text,
  taken_by_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  taken_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_engineer_ces_friction_actions_engineer
  ON engineer_ces_friction_actions(engineer_id, taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_engineer_ces_friction_actions_response
  ON engineer_ces_friction_actions(response_id);

ALTER TABLE engineer_ces_friction_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_engineer_ces_friction_actions_founder_only ON engineer_ces_friction_actions;
CREATE POLICY p_engineer_ces_friction_actions_founder_only
  ON engineer_ces_friction_actions
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- ---- Read RPCs (STABLE) ----------------------------------------------------

CREATE OR REPLACE FUNCTION founder_engineer_ces_overview_30d()
RETURNS TABLE(
  responses_30d bigint,
  low_effort_30d bigint,
  neutral_30d bigint,
  high_effort_30d bigint,
  avg_ces_30d numeric,
  response_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH r AS (
    SELECT * FROM engineer_ces_responses
    WHERE responded_at >= now() - interval '30 days'
  ),
  j AS (
    SELECT count(*)::bigint AS completed_jobs
    FROM repair_jobs
    WHERE status = 'completed'
      AND completed_at >= now() - interval '30 days'
  )
  SELECT
    (SELECT count(*) FROM r)::bigint,
    (SELECT count(*) FROM r WHERE effort_bucket = 'low_effort')::bigint,
    (SELECT count(*) FROM r WHERE effort_bucket = 'neutral')::bigint,
    (SELECT count(*) FROM r WHERE effort_bucket = 'high_effort')::bigint,
    COALESCE((SELECT round(avg(ces_score)::numeric, 2) FROM r), 0)::numeric,
    CASE WHEN (SELECT completed_jobs FROM j) > 0
      THEN round(((SELECT count(*) FROM r)::numeric * 100.0) / (SELECT completed_jobs FROM j), 1)
      ELSE 0 END::numeric;
END $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_ces_overview_30d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_ces_overview_30d() TO authenticated;


CREATE OR REPLACE FUNCTION founder_engineer_ces_by_engineer_90d()
RETURNS TABLE(
  engineer_id uuid,
  engineer_name text,
  cached_highest_tier text,
  response_count bigint,
  avg_ces numeric,
  low_effort_count bigint,
  high_effort_count bigint,
  high_effort_pct numeric,
  last_response_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, p.email, '(unknown)')::text,
    e.cached_highest_tier::text,
    count(r.*)::bigint,
    COALESCE(round(avg(r.ces_score)::numeric, 2), 0)::numeric,
    count(*) FILTER (WHERE r.effort_bucket = 'low_effort')::bigint,
    count(*) FILTER (WHERE r.effort_bucket = 'high_effort')::bigint,
    CASE WHEN count(r.*) > 0
      THEN round((count(*) FILTER (WHERE r.effort_bucket = 'high_effort')::numeric * 100.0) / count(r.*), 1)
      ELSE 0 END::numeric,
    max(r.responded_at)
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN engineer_ces_responses r ON r.engineer_id = e.id
    AND r.responded_at >= now() - interval '90 days'
  GROUP BY e.id, p.full_name, p.email, e.cached_highest_tier
  HAVING count(r.*) > 0
  ORDER BY high_effort_pct DESC NULLS LAST, avg_ces ASC NULLS LAST
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_ces_by_engineer_90d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_ces_by_engineer_90d() TO authenticated;


CREATE OR REPLACE FUNCTION founder_engineer_ces_high_effort_recent()
RETURNS TABLE(
  response_id uuid,
  repair_job_id uuid,
  engineer_id uuid,
  engineer_name text,
  hospital_org_id uuid,
  hospital_name text,
  ces_score smallint,
  friction_tag text,
  free_text text,
  responded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.repair_job_id,
    r.engineer_id,
    COALESCE(p.full_name, p.email, '(unknown)')::text,
    r.hospital_org_id,
    o.name::text,
    r.ces_score,
    r.friction_tag,
    r.free_text,
    r.responded_at
  FROM engineer_ces_responses r
  LEFT JOIN engineers e ON e.id = r.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.effort_bucket = 'high_effort'
    AND r.responded_at >= now() - interval '60 days'
  ORDER BY r.responded_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_ces_high_effort_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_ces_high_effort_recent() TO authenticated;


CREATE OR REPLACE FUNCTION founder_engineer_ces_low_effort_recent()
RETURNS TABLE(
  response_id uuid,
  repair_job_id uuid,
  engineer_id uuid,
  engineer_name text,
  hospital_org_id uuid,
  hospital_name text,
  ces_score smallint,
  free_text text,
  responded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.repair_job_id,
    r.engineer_id,
    COALESCE(p.full_name, p.email, '(unknown)')::text,
    r.hospital_org_id,
    o.name::text,
    r.ces_score,
    r.free_text,
    r.responded_at
  FROM engineer_ces_responses r
  LEFT JOIN engineers e ON e.id = r.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.effort_bucket = 'low_effort'
    AND r.responded_at >= now() - interval '60 days'
  ORDER BY r.responded_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_ces_low_effort_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_ces_low_effort_recent() TO authenticated;


CREATE OR REPLACE FUNCTION founder_engineer_ces_friction_tag_rollup()
RETURNS TABLE(
  friction_tag text,
  response_count bigint,
  avg_ces numeric,
  distinct_engineers bigint,
  last_seen_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(r.friction_tag, '(untagged)')::text,
    count(*)::bigint,
    round(avg(r.ces_score)::numeric, 2)::numeric,
    count(DISTINCT r.engineer_id)::bigint,
    max(r.responded_at)
  FROM engineer_ces_responses r
  WHERE r.responded_at >= now() - interval '90 days'
  GROUP BY 1
  ORDER BY count(*) DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_ces_friction_tag_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_ces_friction_tag_rollup() TO authenticated;


CREATE OR REPLACE FUNCTION founder_engineer_ces_weekly_trend_13wk()
RETURNS TABLE(
  week_start date,
  responses bigint,
  low_effort bigint,
  high_effort bigint,
  avg_ces numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', r.responded_at)::date AS wk,
    count(*)::bigint,
    count(*) FILTER (WHERE r.effort_bucket = 'low_effort')::bigint,
    count(*) FILTER (WHERE r.effort_bucket = 'high_effort')::bigint,
    round(avg(r.ces_score)::numeric, 2)::numeric
  FROM engineer_ces_responses r
  WHERE r.responded_at >= now() - interval '13 weeks'
  GROUP BY 1
  ORDER BY wk DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_ces_weekly_trend_13wk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_ces_weekly_trend_13wk() TO authenticated;


CREATE OR REPLACE FUNCTION founder_engineer_ces_open_frictions()
RETURNS TABLE(
  response_id uuid,
  engineer_id uuid,
  engineer_name text,
  hospital_name text,
  ces_score smallint,
  friction_tag text,
  free_text text,
  responded_at timestamptz,
  action_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.engineer_id,
    COALESCE(p.full_name, p.email, '(unknown)')::text,
    o.name::text,
    r.ces_score,
    r.friction_tag,
    r.free_text,
    r.responded_at,
    (SELECT count(*) FROM engineer_ces_friction_actions a WHERE a.response_id = r.id)::bigint
  FROM engineer_ces_responses r
  LEFT JOIN engineers e ON e.id = r.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN organizations o ON o.id = r.hospital_org_id
  WHERE r.effort_bucket = 'high_effort'
    AND NOT EXISTS (
      SELECT 1 FROM engineer_ces_friction_actions a
      WHERE a.response_id = r.id AND a.action_type = 'closed'
    )
  ORDER BY r.responded_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_engineer_ces_open_frictions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_ces_open_frictions() TO authenticated;


-- ---- Write helpers (VOLATILE) ---------------------------------------------

CREATE OR REPLACE FUNCTION log_founder_ces_record_response(
  p_repair_job_id uuid,
  p_ces_score smallint,
  p_friction_tag text,
  p_free_text text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_engineer_id uuid;
  v_hospital_org_id uuid;
  v_bucket text;
  v_id uuid;
  v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_ces_score IS NULL OR p_ces_score < 1 OR p_ces_score > 7 THEN
    RAISE EXCEPTION 'ces_score must be 1..7';
  END IF;

  SELECT rj.engineer_id, rj.hospital_org_id
    INTO v_engineer_id, v_hospital_org_id
  FROM repair_jobs rj
  WHERE rj.id = p_repair_job_id;
  IF v_engineer_id IS NULL THEN RAISE EXCEPTION 'repair_job_not_found_or_no_engineer'; END IF;

  v_bucket := CASE
    WHEN p_ces_score <= 3 THEN 'high_effort'
    WHEN p_ces_score >= 6 THEN 'low_effort'
    ELSE 'neutral'
  END;

  INSERT INTO engineer_ces_responses(
    repair_job_id, engineer_id, hospital_org_id,
    respondent_user_id, ces_score, effort_bucket, friction_tag, free_text
  )
  VALUES (
    p_repair_job_id, v_engineer_id, v_hospital_org_id,
    auth.uid(), p_ces_score, v_bucket, p_friction_tag, p_free_text
  )
  ON CONFLICT (repair_job_id) DO UPDATE
    SET ces_score = EXCLUDED.ces_score,
        effort_bucket = EXCLUDED.effort_bucket,
        friction_tag = EXCLUDED.friction_tag,
        free_text = EXCLUDED.free_text,
        responded_at = now()
  RETURNING id INTO v_id;

  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'ces_record_response',
    jsonb_build_object('response_id', v_id, 'repair_job_id', p_repair_job_id,
      'engineer_id', v_engineer_id, 'ces_score', p_ces_score, 'bucket', v_bucket));

  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ces_record_response(uuid, smallint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ces_record_response(uuid, smallint, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_ces_take_action(
  p_response_id uuid,
  p_action_type text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_engineer_id uuid;
  v_id uuid;
  v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_action_type NOT IN ('coach_call','training','reassign','suspend','followup','closed') THEN
    RAISE EXCEPTION 'bad_action_type';
  END IF;

  SELECT engineer_id INTO v_engineer_id
  FROM engineer_ces_responses WHERE id = p_response_id;
  IF v_engineer_id IS NULL THEN RAISE EXCEPTION 'response_not_found'; END IF;

  INSERT INTO engineer_ces_friction_actions(
    response_id, engineer_id, action_type, notes, taken_by_user_id
  )
  VALUES (p_response_id, v_engineer_id, p_action_type, p_notes, auth.uid())
  RETURNING id INTO v_id;

  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'ces_take_action',
    jsonb_build_object('action_id', v_id, 'response_id', p_response_id,
      'engineer_id', v_engineer_id, 'action_type', p_action_type));

  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ces_take_action(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ces_take_action(uuid, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_ces_close_friction(
  p_response_id uuid,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_engineer_id uuid;
  v_id uuid;
  v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT engineer_id INTO v_engineer_id
  FROM engineer_ces_responses WHERE id = p_response_id;
  IF v_engineer_id IS NULL THEN RAISE EXCEPTION 'response_not_found'; END IF;

  INSERT INTO engineer_ces_friction_actions(
    response_id, engineer_id, action_type, notes, taken_by_user_id
  )
  VALUES (p_response_id, v_engineer_id, 'closed', p_notes, auth.uid())
  RETURNING id INTO v_id;

  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'ces_close_friction',
    jsonb_build_object('action_id', v_id, 'response_id', p_response_id,
      'engineer_id', v_engineer_id));

  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ces_close_friction(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ces_close_friction(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_ces_retag_response(
  p_response_id uuid,
  p_new_tag text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE engineer_ces_responses
     SET friction_tag = p_new_tag
   WHERE id = p_response_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'response_not_found'; END IF;

  SELECT email INTO v_actor_email FROM profiles WHERE id = auth.uid();
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_actor_email, 'ces_retag_response',
    jsonb_build_object('response_id', p_response_id, 'new_tag', p_new_tag));

  RETURN p_response_id;
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ces_retag_response(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ces_retag_response(uuid, text) TO authenticated;

COMMIT;