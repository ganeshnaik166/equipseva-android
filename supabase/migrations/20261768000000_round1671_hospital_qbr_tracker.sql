BEGIN;

-- =========================================================================
-- Round 1671 — Hospital Quarterly Review Tracker
-- 2 NEW tables with _r1671 suffix + 7 RPCs (founder-gated).
-- =========================================================================

CREATE TABLE hospital_qbr_sessions_r1671 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  hospital_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  quarter text NOT NULL,
  scheduled_at timestamptz NOT NULL,
  completed_at timestamptz,
  attendees text[] NOT NULL DEFAULT '{}'::text[],
  summary_md text,
  satisfaction_score int CHECK (satisfaction_score BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_qbr_sessions_r1671_hospital ON hospital_qbr_sessions_r1671(hospital_user_id);
CREATE INDEX idx_qbr_sessions_r1671_quarter ON hospital_qbr_sessions_r1671(quarter);
CREATE INDEX idx_qbr_sessions_r1671_scheduled ON hospital_qbr_sessions_r1671(scheduled_at DESC);

CREATE TABLE hospital_qbr_action_items_r1671 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES hospital_qbr_sessions_r1671(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text NOT NULL,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','cancelled')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_qbr_actions_r1671_session ON hospital_qbr_action_items_r1671(session_id);
CREATE INDEX idx_qbr_actions_r1671_status ON hospital_qbr_action_items_r1671(status);
CREATE INDEX idx_qbr_actions_r1671_due ON hospital_qbr_action_items_r1671(due_date);

ALTER TABLE hospital_qbr_sessions_r1671 ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_qbr_action_items_r1671 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_qbr_sessions_r1671 ON hospital_qbr_sessions_r1671
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE POLICY founder_qbr_actions_r1671 ON hospital_qbr_action_items_r1671
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_sessions
-- =========================================================================
CREATE OR REPLACE FUNCTION list_sessions_r1671()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  quarter text,
  scheduled_at timestamptz,
  completed_at timestamptz,
  attendees text[],
  summary_md text,
  satisfaction_score int,
  open_actions int,
  total_actions int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.hospital_user_id,
    COALESCE(o.name, p.full_name, 'Hospital'::text) AS hospital_name,
    s.quarter,
    s.scheduled_at,
    s.completed_at,
    s.attendees,
    s.summary_md,
    s.satisfaction_score,
    (COUNT(a.id) FILTER (WHERE a.status = 'open'))::int AS open_actions,
    (COUNT(a.id))::int AS total_actions
  FROM hospital_qbr_sessions_r1671 s
  LEFT JOIN profiles p ON p.id = s.hospital_user_id
  LEFT JOIN organizations o ON o.id = p.organization_id
  LEFT JOIN hospital_qbr_action_items_r1671 a ON a.session_id = s.id
  GROUP BY s.id, o.name, p.full_name
  ORDER BY s.scheduled_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_sessions_r1671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_sessions_r1671() TO authenticated;

-- =========================================================================
-- RPC 2: schedule_session
-- =========================================================================
CREATE OR REPLACE FUNCTION schedule_session_r1671(
  p_hospital_user_id uuid,
  p_quarter text,
  p_scheduled_at timestamptz,
  p_attendees text[]
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO hospital_qbr_sessions_r1671 (hospital_user_id, quarter, scheduled_at, attendees)
  VALUES (p_hospital_user_id, p_quarter, p_scheduled_at, COALESCE(p_attendees, '{}'::text[]))
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1671_schedule_session',
    jsonb_build_object(
      'session_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'quarter', p_quarter,
      'scheduled_at', p_scheduled_at,
      'attendees', p_attendees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION schedule_session_r1671(uuid, text, timestamptz, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION schedule_session_r1671(uuid, text, timestamptz, text[]) TO authenticated;

-- =========================================================================
-- RPC 3: complete_session
-- =========================================================================
CREATE OR REPLACE FUNCTION complete_session_r1671(
  p_session_id uuid,
  p_summary_md text,
  p_satisfaction_score int
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_satisfaction_score IS NOT NULL AND (p_satisfaction_score < 1 OR p_satisfaction_score > 10) THEN
    RAISE EXCEPTION 'satisfaction_score must be between 1 and 10';
  END IF;

  UPDATE hospital_qbr_sessions_r1671
  SET completed_at = now(),
      summary_md = p_summary_md,
      satisfaction_score = p_satisfaction_score,
      updated_at = now()
  WHERE id = p_session_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1671_complete_session',
    jsonb_build_object(
      'session_id', p_session_id,
      'satisfaction_score', p_satisfaction_score,
      'summary_len', COALESCE(length(p_summary_md), 0)
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION complete_session_r1671(uuid, text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION complete_session_r1671(uuid, text, int) TO authenticated;

-- =========================================================================
-- RPC 4: list_actions
-- =========================================================================
CREATE OR REPLACE FUNCTION list_actions_r1671(p_session_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  session_id uuid,
  quarter text,
  hospital_name text,
  action_text text,
  owner_email text,
  due_date date,
  status text,
  completed_at timestamptz,
  days_overdue int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    a.id,
    a.session_id,
    s.quarter,
    COALESCE(o.name, p.full_name, 'Hospital'::text) AS hospital_name,
    a.action_text,
    a.owner_email,
    a.due_date,
    a.status,
    a.completed_at,
    CASE
      WHEN a.status = 'open' AND a.due_date IS NOT NULL AND a.due_date < CURRENT_DATE
        THEN (CURRENT_DATE - a.due_date)::int
      ELSE 0
    END AS days_overdue
  FROM hospital_qbr_action_items_r1671 a
  JOIN hospital_qbr_sessions_r1671 s ON s.id = a.session_id
  LEFT JOIN profiles p ON p.id = s.hospital_user_id
  LEFT JOIN organizations o ON o.id = p.organization_id
  WHERE (p_session_id IS NULL OR a.session_id = p_session_id)
  ORDER BY
    CASE a.status WHEN 'open' THEN 0 WHEN 'done' THEN 1 ELSE 2 END,
    a.due_date NULLS LAST,
    a.created_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_actions_r1671(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_actions_r1671(uuid) TO authenticated;

-- =========================================================================
-- RPC 5: add_action
-- =========================================================================
CREATE OR REPLACE FUNCTION add_action_r1671(
  p_session_id uuid,
  p_action_text text,
  p_owner_email text,
  p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO hospital_qbr_action_items_r1671 (session_id, action_text, owner_email, due_date)
  VALUES (p_session_id, p_action_text, p_owner_email, p_due_date)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1671_add_action',
    jsonb_build_object(
      'action_id', v_id,
      'session_id', p_session_id,
      'owner_email', p_owner_email,
      'due_date', p_due_date
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION add_action_r1671(uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION add_action_r1671(uuid, text, text, date) TO authenticated;

-- =========================================================================
-- RPC 6: complete_action
-- =========================================================================
CREATE OR REPLACE FUNCTION complete_action_r1671(
  p_action_id uuid,
  p_new_status text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_new_status NOT IN ('done','cancelled','open') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status;
  END IF;

  UPDATE hospital_qbr_action_items_r1671
  SET status = p_new_status,
      completed_at = CASE WHEN p_new_status IN ('done','cancelled') THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_action_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1671_complete_action',
    jsonb_build_object(
      'action_id', p_action_id,
      'new_status', p_new_status
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION complete_action_r1671(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION complete_action_r1671(uuid, text) TO authenticated;

-- =========================================================================
-- RPC 7: qbr_summary — rollup KPIs
-- =========================================================================
CREATE OR REPLACE FUNCTION qbr_summary_r1671()
RETURNS TABLE (
  total_sessions int,
  completed_sessions int,
  upcoming_sessions int,
  avg_satisfaction numeric,
  open_actions int,
  overdue_actions int,
  done_actions int,
  unique_hospitals int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM hospital_qbr_sessions_r1671),
    (SELECT (COUNT(*) FILTER (WHERE completed_at IS NOT NULL))::int FROM hospital_qbr_sessions_r1671),
    (SELECT (COUNT(*) FILTER (WHERE completed_at IS NULL AND scheduled_at >= now()))::int FROM hospital_qbr_sessions_r1671),
    (SELECT ROUND(AVG(satisfaction_score)::numeric, 2) FROM hospital_qbr_sessions_r1671 WHERE satisfaction_score IS NOT NULL),
    (SELECT (COUNT(*) FILTER (WHERE status = 'open'))::int FROM hospital_qbr_action_items_r1671),
    (SELECT (COUNT(*) FILTER (WHERE status = 'open' AND due_date IS NOT NULL AND due_date < CURRENT_DATE))::int FROM hospital_qbr_action_items_r1671),
    (SELECT (COUNT(*) FILTER (WHERE status = 'done'))::int FROM hospital_qbr_action_items_r1671),
    (SELECT COUNT(DISTINCT hospital_user_id)::int FROM hospital_qbr_sessions_r1671);
END;
$$;

REVOKE EXECUTE ON FUNCTION qbr_summary_r1671() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION qbr_summary_r1671() TO authenticated;

COMMIT;