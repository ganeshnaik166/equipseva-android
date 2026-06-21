BEGIN;

-- Round 1556: Founder Investor Reference Call Log
-- Track reference calls between prospective investors and existing portfolio founders.
-- 3-stage workflow: asked -> scheduled -> done.

CREATE TABLE IF NOT EXISTS investor_reference_calls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prospective_investor_name text NOT NULL,
  prospective_investor_firm text,
  prospective_investor_email text,
  portfolio_reference_name text NOT NULL,
  portfolio_reference_company text,
  portfolio_reference_email text,
  stage text NOT NULL DEFAULT 'asked' CHECK (stage IN ('asked','scheduled','done')),
  asked_at timestamptz NOT NULL DEFAULT now(),
  scheduled_for timestamptz,
  completed_at timestamptz,
  founder_notes text,
  reference_feedback text,
  signal_strength text CHECK (signal_strength IN ('very_positive','positive','neutral','concern','red_flag')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iref_calls_stage ON investor_reference_calls(stage);
CREATE INDEX IF NOT EXISTS idx_iref_calls_investor ON investor_reference_calls(prospective_investor_name);
CREATE INDEX IF NOT EXISTS idx_iref_calls_reference ON investor_reference_calls(portfolio_reference_name);
CREATE INDEX IF NOT EXISTS idx_iref_calls_asked_at ON investor_reference_calls(asked_at DESC);

ALTER TABLE investor_reference_calls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iref_calls_founder_all ON investor_reference_calls;
CREATE POLICY iref_calls_founder_all ON investor_reference_calls
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Per-reference call quota tracking (calls-given count by portfolio reference)
CREATE TABLE IF NOT EXISTS investor_reference_quota (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_reference_name text NOT NULL UNIQUE,
  portfolio_reference_company text,
  total_calls_given int NOT NULL DEFAULT 0,
  monthly_cap int NOT NULL DEFAULT 2,
  last_call_at timestamptz,
  goodwill_balance numeric(8,2) NOT NULL DEFAULT 5.00,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iref_quota_name ON investor_reference_quota(portfolio_reference_name);

ALTER TABLE investor_reference_quota ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iref_quota_founder_all ON investor_reference_quota;
CREATE POLICY iref_quota_founder_all ON investor_reference_quota
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ========================================================================
-- READ RPCs (STABLE)
-- ========================================================================

CREATE OR REPLACE FUNCTION founder_iref_calls_overview()
RETURNS TABLE (
  total_calls int,
  asked_calls int,
  scheduled_calls int,
  done_calls int,
  distinct_investors int,
  distinct_references int,
  positive_signals int,
  red_flag_signals int,
  avg_days_to_schedule numeric,
  avg_days_to_complete numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE stage = 'asked')::int,
    COUNT(*) FILTER (WHERE stage = 'scheduled')::int,
    COUNT(*) FILTER (WHERE stage = 'done')::int,
    COUNT(DISTINCT prospective_investor_name)::int,
    COUNT(DISTINCT portfolio_reference_name)::int,
    COUNT(*) FILTER (WHERE signal_strength IN ('positive','very_positive'))::int,
    COUNT(*) FILTER (WHERE signal_strength = 'red_flag')::int,
    ROUND(AVG(EXTRACT(EPOCH FROM (scheduled_for - asked_at))/86400.0) FILTER (WHERE scheduled_for IS NOT NULL)::numeric, 2),
    ROUND(AVG(EXTRACT(EPOCH FROM (completed_at - asked_at))/86400.0) FILTER (WHERE completed_at IS NOT NULL)::numeric, 2)
  FROM investor_reference_calls;
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_calls_recent()
RETURNS TABLE (
  id uuid,
  prospective_investor_name text,
  prospective_investor_firm text,
  portfolio_reference_name text,
  portfolio_reference_company text,
  stage text,
  asked_at timestamptz,
  scheduled_for timestamptz,
  completed_at timestamptz,
  signal_strength text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.prospective_investor_name, c.prospective_investor_firm,
         c.portfolio_reference_name, c.portfolio_reference_company,
         c.stage, c.asked_at, c.scheduled_for, c.completed_at, c.signal_strength
  FROM investor_reference_calls c
  ORDER BY c.asked_at DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_calls_by_stage()
RETURNS TABLE (
  stage text,
  call_count int,
  oldest_asked_at timestamptz,
  newest_asked_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.stage, COUNT(*)::int, MIN(c.asked_at), MAX(c.asked_at)
  FROM investor_reference_calls c
  GROUP BY c.stage
  ORDER BY CASE c.stage WHEN 'asked' THEN 1 WHEN 'scheduled' THEN 2 WHEN 'done' THEN 3 END;
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_calls_per_investor()
RETURNS TABLE (
  prospective_investor_name text,
  prospective_investor_firm text,
  calls_asked int,
  calls_done int,
  positive_signal_pct numeric,
  latest_call_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.prospective_investor_name,
    MAX(c.prospective_investor_firm),
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE c.stage = 'done')::int,
    ROUND(100.0 * COUNT(*) FILTER (WHERE c.signal_strength IN ('positive','very_positive')) / NULLIF(COUNT(*) FILTER (WHERE c.stage = 'done'), 0), 1),
    MAX(c.asked_at)
  FROM investor_reference_calls c
  GROUP BY c.prospective_investor_name
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_calls_per_reference()
RETURNS TABLE (
  portfolio_reference_name text,
  portfolio_reference_company text,
  total_calls_given int,
  monthly_cap int,
  goodwill_balance numeric,
  last_call_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.portfolio_reference_name, q.portfolio_reference_company,
         q.total_calls_given, q.monthly_cap, q.goodwill_balance, q.last_call_at
  FROM investor_reference_quota q
  ORDER BY q.total_calls_given DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_calls_pending_followup()
RETURNS TABLE (
  id uuid,
  prospective_investor_name text,
  portfolio_reference_name text,
  stage text,
  asked_at timestamptz,
  days_open numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.prospective_investor_name, c.portfolio_reference_name,
         c.stage, c.asked_at,
         ROUND(EXTRACT(EPOCH FROM (now() - c.asked_at))/86400.0, 1)
  FROM investor_reference_calls c
  WHERE c.stage IN ('asked','scheduled')
  ORDER BY c.asked_at ASC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_signal_summary()
RETURNS TABLE (
  signal_strength text,
  call_count int,
  pct_of_done numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  total_done int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total_done FROM investor_reference_calls WHERE stage = 'done';
  RETURN QUERY
  SELECT COALESCE(c.signal_strength, 'unspecified'),
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) / NULLIF(total_done, 0), 1)
  FROM investor_reference_calls c
  WHERE c.stage = 'done'
  GROUP BY c.signal_strength
  ORDER BY COUNT(*) DESC;
END;
$$;

-- ========================================================================
-- WRITE RPCs (VOLATILE)
-- ========================================================================

CREATE OR REPLACE FUNCTION founder_iref_log_ask(
  p_investor_name text,
  p_investor_firm text,
  p_reference_name text,
  p_reference_company text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_reference_calls
    (prospective_investor_name, prospective_investor_firm,
     portfolio_reference_name, portfolio_reference_company,
     stage, founder_notes)
  VALUES
    (p_investor_name, p_investor_firm, p_reference_name, p_reference_company,
     'asked', p_notes)
  RETURNING id INTO v_id;

  INSERT INTO investor_reference_quota (portfolio_reference_name, portfolio_reference_company)
  VALUES (p_reference_name, p_reference_company)
  ON CONFLICT (portfolio_reference_name) DO NOTHING;

  PERFORM log_founder_iref_call_logged(v_id, p_investor_name, p_reference_name);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_advance_stage(
  p_call_id uuid,
  p_new_stage text,
  p_scheduled_for timestamptz
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_ref_name text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_stage NOT IN ('asked','scheduled','done') THEN
    RAISE EXCEPTION 'invalid stage: %', p_new_stage;
  END IF;

  UPDATE investor_reference_calls
  SET stage = p_new_stage,
      scheduled_for = CASE WHEN p_new_stage = 'scheduled' THEN COALESCE(p_scheduled_for, now()) ELSE scheduled_for END,
      completed_at = CASE WHEN p_new_stage = 'done' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_call_id
  RETURNING portfolio_reference_name INTO v_ref_name;

  IF p_new_stage = 'done' AND v_ref_name IS NOT NULL THEN
    UPDATE investor_reference_quota
    SET total_calls_given = total_calls_given + 1,
        last_call_at = now(),
        goodwill_balance = GREATEST(goodwill_balance - 1.0, 0),
        updated_at = now()
    WHERE portfolio_reference_name = v_ref_name;
  END IF;

  PERFORM log_founder_iref_stage_change(p_call_id, p_new_stage);
END;
$$;

CREATE OR REPLACE FUNCTION founder_iref_record_feedback(
  p_call_id uuid,
  p_signal_strength text,
  p_feedback text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_reference_calls
  SET signal_strength = p_signal_strength,
      reference_feedback = p_feedback,
      updated_at = now()
  WHERE id = p_call_id;

  PERFORM log_founder_iref_feedback_recorded(p_call_id, p_signal_strength);
END;
$$;

-- ========================================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- ========================================================================

CREATE OR REPLACE FUNCTION log_founder_iref_call_logged(
  p_call_id uuid,
  p_investor_name text,
  p_reference_name text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'iref_call_logged',
    jsonb_build_object('call_id', p_call_id, 'investor', p_investor_name, 'reference', p_reference_name)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_iref_stage_change(
  p_call_id uuid,
  p_new_stage text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'iref_stage_change',
    jsonb_build_object('call_id', p_call_id, 'new_stage', p_new_stage)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_iref_feedback_recorded(
  p_call_id uuid,
  p_signal_strength text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'iref_feedback_recorded',
    jsonb_build_object('call_id', p_call_id, 'signal_strength', p_signal_strength)
  );
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_iref_quota_adjusted(
  p_reference_name text,
  p_new_cap int
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'iref_quota_adjusted',
    jsonb_build_object('reference', p_reference_name, 'new_cap', p_new_cap)
  );
END;
$$;

-- ========================================================================
-- Permissions
-- ========================================================================

REVOKE EXECUTE ON FUNCTION founder_iref_calls_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_calls_recent() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_calls_by_stage() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_calls_per_investor() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_calls_per_reference() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_calls_pending_followup() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_signal_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_log_ask(text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_advance_stage(uuid, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_iref_record_feedback(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_iref_call_logged(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_iref_stage_change(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_iref_feedback_recorded(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_iref_quota_adjusted(text, int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_iref_calls_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_calls_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_calls_by_stage() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_calls_per_investor() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_calls_per_reference() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_calls_pending_followup() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_signal_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_log_ask(text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_advance_stage(uuid, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_iref_record_feedback(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_iref_call_logged(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_iref_stage_change(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_iref_feedback_recorded(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_iref_quota_adjusted(text, int) TO authenticated;

COMMIT;