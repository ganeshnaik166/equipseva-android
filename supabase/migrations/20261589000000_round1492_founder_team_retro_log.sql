BEGIN;

-- ============================================================
-- r1492 — Founder Team Retrospective Log
-- Capture monthly team retros (start/stop/continue + actions)
-- Track action-item completion + stale retros + overdue items
-- ============================================================

CREATE TABLE IF NOT EXISTS founder_team_retros_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retro_month date NOT NULL,
  team_name text NOT NULL,
  facilitator_email text,
  attendee_count int NOT NULL DEFAULT 0 CHECK (attendee_count >= 0),
  start_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  stop_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  continue_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  morale_score int CHECK (morale_score BETWEEN 1 AND 10),
  notes text,
  is_archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_team_retros_month ON founder_team_retros_v2(retro_month DESC);
CREATE INDEX IF NOT EXISTS idx_founder_team_retros_team ON founder_team_retros_v2(team_name);

ALTER TABLE founder_team_retros_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_team_retros_founder_only ON founder_team_retros_v2;
CREATE POLICY founder_team_retros_founder_only ON founder_team_retros_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_team_retro_actions_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retro_id uuid NOT NULL REFERENCES founder_team_retros_v2(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text NOT NULL,
  due_date date NOT NULL,
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','completed','blocked','cancelled')),
  completion_notes text,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_retro_actions_retro ON founder_team_retro_actions_v2(retro_id);
CREATE INDEX IF NOT EXISTS idx_retro_actions_owner ON founder_team_retro_actions_v2(owner_email);
CREATE INDEX IF NOT EXISTS idx_retro_actions_status ON founder_team_retro_actions_v2(status);
CREATE INDEX IF NOT EXISTS idx_retro_actions_due ON founder_team_retro_actions_v2(due_date);

ALTER TABLE founder_team_retro_actions_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_team_retro_actions_v2_founder_only ON founder_team_retro_actions_v2;
CREATE POLICY founder_team_retro_actions_v2_founder_only ON founder_team_retro_actions_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_team_retro_list()
RETURNS TABLE (
  id uuid,
  retro_month date,
  team_name text,
  facilitator_email text,
  attendee_count int,
  morale_score int,
  total_actions bigint,
  completed_actions bigint,
  overdue_actions bigint,
  completion_pct numeric,
  days_since_retro numeric,
  is_stale boolean,
  is_archived boolean,
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
  SELECT
    r.id,
    r.retro_month,
    r.team_name,
    r.facilitator_email,
    r.attendee_count,
    r.morale_score,
    COALESCE(a.total_actions, 0) AS total_actions,
    COALESCE(a.completed_actions, 0) AS completed_actions,
    COALESCE(a.overdue_actions, 0) AS overdue_actions,
    CASE WHEN COALESCE(a.total_actions,0) = 0 THEN 0
         ELSE ROUND((a.completed_actions::numeric / a.total_actions::numeric) * 100, 1)
    END AS completion_pct,
    ROUND(EXTRACT(EPOCH FROM (now() - r.created_at))/86400.0, 1) AS days_since_retro,
    (EXTRACT(EPOCH FROM (now() - r.created_at))/86400.0) > 45 AS is_stale,
    r.is_archived,
    r.created_at
  FROM founder_team_retros_v2 r
  LEFT JOIN LATERAL (
    SELECT
      COUNT(*) AS total_actions,
      COUNT(*) FILTER (WHERE status = 'completed') AS completed_actions,
      COUNT(*) FILTER (WHERE status NOT IN ('completed','cancelled') AND due_date < CURRENT_DATE) AS overdue_actions
    FROM founder_team_retro_actions_v2
    WHERE retro_id = r.id
  ) a ON TRUE
  ORDER BY r.retro_month DESC, r.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_team_retro_actions_v2_overdue()
RETURNS TABLE (
  id uuid,
  retro_id uuid,
  team_name text,
  retro_month date,
  action_text text,
  owner_email text,
  due_date date,
  priority text,
  status text,
  days_overdue numeric
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
    a.id,
    a.retro_id,
    r.team_name,
    r.retro_month,
    a.action_text,
    a.owner_email,
    a.due_date,
    a.priority,
    a.status,
    ROUND(EXTRACT(EPOCH FROM (now() - a.due_date::timestamptz))/86400.0, 1) AS days_overdue
  FROM founder_team_retro_actions_v2 a
  JOIN founder_team_retros_v2 r ON r.id = a.retro_id
  WHERE a.status NOT IN ('completed','cancelled')
    AND a.due_date < CURRENT_DATE
  ORDER BY a.due_date ASC, a.priority DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_team_retro_actions_v2_open()
RETURNS TABLE (
  id uuid,
  retro_id uuid,
  team_name text,
  action_text text,
  owner_email text,
  due_date date,
  priority text,
  status text,
  days_until_due numeric
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
    a.id,
    a.retro_id,
    r.team_name,
    a.action_text,
    a.owner_email,
    a.due_date,
    a.priority,
    a.status,
    ROUND(EXTRACT(EPOCH FROM (a.due_date::timestamptz - now()))/86400.0, 1) AS days_until_due
  FROM founder_team_retro_actions_v2 a
  JOIN founder_team_retros_v2 r ON r.id = a.retro_id
  WHERE a.status IN ('open','in_progress')
  ORDER BY a.due_date ASC NULLS LAST, a.priority DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_team_retro_owner_scorecard()
RETURNS TABLE (
  owner_email text,
  total_actions bigint,
  completed_actions bigint,
  overdue_actions bigint,
  in_progress_actions bigint,
  completion_pct numeric,
  avg_days_to_close numeric
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
    a.owner_email,
    COUNT(*) AS total_actions,
    COUNT(*) FILTER (WHERE a.status = 'completed') AS completed_actions,
    COUNT(*) FILTER (WHERE a.status NOT IN ('completed','cancelled') AND a.due_date < CURRENT_DATE) AS overdue_actions,
    COUNT(*) FILTER (WHERE a.status = 'in_progress') AS in_progress_actions,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND((COUNT(*) FILTER (WHERE a.status = 'completed'))::numeric / COUNT(*)::numeric * 100, 1)
    END AS completion_pct,
    ROUND(AVG(EXTRACT(EPOCH FROM (a.completed_at - a.created_at))/86400.0) FILTER (WHERE a.completed_at IS NOT NULL), 1) AS avg_days_to_close
  FROM founder_team_retro_actions_v2 a
  GROUP BY a.owner_email
  ORDER BY total_actions DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_team_retro_stale()
RETURNS TABLE (
  team_name text,
  last_retro_month date,
  last_retro_at timestamptz,
  days_since_last numeric,
  open_actions bigint,
  overdue_actions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (r.team_name)
      r.team_name,
      r.retro_month,
      r.created_at,
      r.id
    FROM founder_team_retros_v2 r
    WHERE r.is_archived = false
    ORDER BY r.team_name, r.created_at DESC
  )
  SELECT
    l.team_name,
    l.retro_month AS last_retro_month,
    l.created_at AS last_retro_at,
    ROUND(EXTRACT(EPOCH FROM (now() - l.created_at))/86400.0, 1) AS days_since_last,
    COALESCE(COUNT(a.id) FILTER (WHERE a.status IN ('open','in_progress')), 0) AS open_actions,
    COALESCE(COUNT(a.id) FILTER (WHERE a.status NOT IN ('completed','cancelled') AND a.due_date < CURRENT_DATE), 0) AS overdue_actions
  FROM latest l
  LEFT JOIN founder_team_retro_actions_v2 a ON a.retro_id = l.id
  GROUP BY l.team_name, l.retro_month, l.created_at
  HAVING EXTRACT(EPOCH FROM (now() - l.created_at))/86400.0 > 45
  ORDER BY days_since_last DESC;
END;
$$;

CREATE OR REPLACE FUNCTION founder_team_retro_summary()
RETURNS TABLE (
  total_retros bigint,
  retros_last_30d bigint,
  active_teams bigint,
  stale_teams bigint,
  total_actions bigint,
  open_actions bigint,
  completed_actions bigint,
  overdue_actions bigint,
  in_progress_actions bigint,
  completion_pct numeric,
  overdue_pct numeric,
  avg_morale numeric,
  avg_attendees numeric,
  high_priority_open bigint,
  critical_priority_open bigint,
  unique_owners bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH r_stats AS (
    SELECT
      COUNT(*) AS total_retros,
      COUNT(*) FILTER (WHERE created_at > now() - interval '30 days') AS retros_last_30d,
      COUNT(DISTINCT team_name) AS active_teams,
      ROUND(AVG(morale_score)::numeric, 2) AS avg_morale,
      ROUND(AVG(attendee_count)::numeric, 1) AS avg_attendees
    FROM founder_team_retros_v2
    WHERE is_archived = false
  ),
  stale AS (
    SELECT COUNT(*) AS stale_teams FROM founder_team_retro_stale()
  ),
  a_stats AS (
    SELECT
      COUNT(*) AS total_actions,
      COUNT(*) FILTER (WHERE status IN ('open','in_progress')) AS open_actions,
      COUNT(*) FILTER (WHERE status = 'completed') AS completed_actions,
      COUNT(*) FILTER (WHERE status NOT IN ('completed','cancelled') AND due_date < CURRENT_DATE) AS overdue_actions,
      COUNT(*) FILTER (WHERE status = 'in_progress') AS in_progress_actions,
      COUNT(*) FILTER (WHERE status IN ('open','in_progress') AND priority = 'high') AS high_priority_open,
      COUNT(*) FILTER (WHERE status IN ('open','in_progress') AND priority = 'critical') AS critical_priority_open,
      COUNT(DISTINCT owner_email) AS unique_owners
    FROM founder_team_retro_actions_v2
  )
  SELECT
    r_stats.total_retros,
    r_stats.retros_last_30d,
    r_stats.active_teams,
    stale.stale_teams,
    a_stats.total_actions,
    a_stats.open_actions,
    a_stats.completed_actions,
    a_stats.overdue_actions,
    a_stats.in_progress_actions,
    CASE WHEN a_stats.total_actions = 0 THEN 0
         ELSE ROUND(a_stats.completed_actions::numeric / a_stats.total_actions::numeric * 100, 1)
    END,
    CASE WHEN a_stats.total_actions = 0 THEN 0
         ELSE ROUND(a_stats.overdue_actions::numeric / a_stats.total_actions::numeric * 100, 1)
    END,
    r_stats.avg_morale,
    r_stats.avg_attendees,
    a_stats.high_priority_open,
    a_stats.critical_priority_open,
    a_stats.unique_owners
  FROM r_stats, stale, a_stats;
END;
$$;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_retro_create(
  p_retro_month date,
  p_team_name text,
  p_facilitator_email text,
  p_attendee_count int,
  p_start_items jsonb,
  p_stop_items jsonb,
  p_continue_items jsonb,
  p_morale_score int,
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
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_team_retros_v2 (
    retro_month, team_name, facilitator_email, attendee_count,
    start_items, stop_items, continue_items, morale_score, notes
  ) VALUES (
    p_retro_month, p_team_name, p_facilitator_email, COALESCE(p_attendee_count,0),
    COALESCE(p_start_items,'[]'::jsonb), COALESCE(p_stop_items,'[]'::jsonb),
    COALESCE(p_continue_items,'[]'::jsonb), p_morale_score, p_notes
  )
  RETURNING id INTO v_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'retro_create',
    jsonb_build_object('retro_id', v_id, 'team', p_team_name, 'month', p_retro_month));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_retro_action_add(
  p_retro_id uuid,
  p_action_text text,
  p_owner_email text,
  p_due_date date,
  p_priority text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_team_retro_actions_v2 (
    retro_id, action_text, owner_email, due_date, priority
  ) VALUES (
    p_retro_id, p_action_text, p_owner_email, p_due_date, COALESCE(p_priority,'medium')
  )
  RETURNING id INTO v_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'retro_action_add',
    jsonb_build_object('action_id', v_id, 'retro_id', p_retro_id, 'owner', p_owner_email, 'due', p_due_date));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_retro_action_complete(
  p_action_id uuid,
  p_completion_notes text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_team_retro_actions_v2
  SET status = 'completed',
      completion_notes = p_completion_notes,
      completed_at = now(),
      updated_at = now()
  WHERE id = p_action_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'retro_action_complete',
    jsonb_build_object('action_id', p_action_id, 'notes', p_completion_notes));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_retro_archive(
  p_retro_id uuid
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_team_retros_v2
  SET is_archived = true, updated_at = now()
  WHERE id = p_retro_id;

  SELECT p.email INTO v_email FROM profiles p WHERE p.id = auth.uid();

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'retro_archive',
    jsonb_build_object('retro_id', p_retro_id));
END;
$$;

-- ============================================================
-- GRANTS
-- ============================================================

REVOKE EXECUTE ON FUNCTION founder_team_retro_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_retro_list() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_team_retro_actions_v2_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_retro_actions_v2_overdue() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_team_retro_actions_v2_open() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_retro_actions_v2_open() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_team_retro_owner_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_retro_owner_scorecard() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_team_retro_stale() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_retro_stale() TO authenticated;

REVOKE EXECUTE ON FUNCTION founder_team_retro_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_team_retro_summary() TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_retro_create(date,text,text,int,jsonb,jsonb,jsonb,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retro_create(date,text,text,int,jsonb,jsonb,jsonb,int,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_retro_action_add(uuid,text,text,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retro_action_add(uuid,text,text,date,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_retro_action_complete(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retro_action_complete(uuid,text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_retro_archive(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_retro_archive(uuid) TO authenticated;

COMMIT;