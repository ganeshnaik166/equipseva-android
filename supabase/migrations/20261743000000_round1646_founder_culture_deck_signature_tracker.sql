BEGIN;

-- r1646 founder culture-deck signature tracker (extends r1496)
-- Per-team-member status, deadline alerts, founder follow-up, per-version comparison.

CREATE TABLE IF NOT EXISTS culture_deck_signature_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deck_version text NOT NULL,
  assignee_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  deadline_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','signed','declined','overdue','waived')),
  signed_at timestamptz,
  declined_reason text,
  followup_count int NOT NULL DEFAULT 0,
  last_followup_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (deck_version, assignee_user_id)
);

CREATE INDEX IF NOT EXISTS culture_deck_sig_assign_version_idx
  ON culture_deck_signature_assignments(deck_version);
CREATE INDEX IF NOT EXISTS culture_deck_sig_assign_status_idx
  ON culture_deck_signature_assignments(status);
CREATE INDEX IF NOT EXISTS culture_deck_sig_assign_deadline_idx
  ON culture_deck_signature_assignments(deadline_at);

ALTER TABLE culture_deck_signature_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS culture_deck_sig_assign_founder_all
  ON culture_deck_signature_assignments;
CREATE POLICY culture_deck_sig_assign_founder_all
  ON culture_deck_signature_assignments
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS culture_deck_signature_followups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid NOT NULL REFERENCES culture_deck_signature_assignments(id) ON DELETE CASCADE,
  followup_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL CHECK (channel IN ('email','slack','in_person','phone','other')),
  outcome text,
  notes text,
  created_by_email text
);

CREATE INDEX IF NOT EXISTS culture_deck_sig_followup_assignment_idx
  ON culture_deck_signature_followups(assignment_id);
CREATE INDEX IF NOT EXISTS culture_deck_sig_followup_at_idx
  ON culture_deck_signature_followups(followup_at);

ALTER TABLE culture_deck_signature_followups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS culture_deck_sig_followup_founder_all
  ON culture_deck_signature_followups;
CREATE POLICY culture_deck_sig_followup_founder_all
  ON culture_deck_signature_followups
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- RPC 1: per-version rollup
CREATE OR REPLACE FUNCTION rpc_r1646_signature_version_rollup()
RETURNS TABLE (
  deck_version text,
  total_assigned int,
  total_signed int,
  total_pending int,
  total_overdue int,
  total_declined int,
  total_waived int,
  pct_signed numeric,
  earliest_deadline timestamptz,
  latest_signed_at timestamptz
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
    a.deck_version,
    (COUNT(*))::int AS total_assigned,
    (COUNT(*) FILTER (WHERE a.status = 'signed'))::int AS total_signed,
    (COUNT(*) FILTER (WHERE a.status = 'pending'))::int AS total_pending,
    (COUNT(*) FILTER (WHERE a.status = 'overdue' OR (a.status='pending' AND a.deadline_at < now())))::int AS total_overdue,
    (COUNT(*) FILTER (WHERE a.status = 'declined'))::int AS total_declined,
    (COUNT(*) FILTER (WHERE a.status = 'waived'))::int AS total_waived,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE a.status = 'signed'))::numeric / NULLIF(COUNT(*), 0), 1) AS pct_signed,
    MIN(a.deadline_at) AS earliest_deadline,
    MAX(a.signed_at) AS latest_signed_at
  FROM culture_deck_signature_assignments a
  GROUP BY a.deck_version
  ORDER BY a.deck_version DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r1646_signature_version_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r1646_signature_version_rollup() TO authenticated;

-- RPC 2: per-member detail for a version
CREATE OR REPLACE FUNCTION rpc_r1646_member_status(p_deck_version text)
RETURNS TABLE (
  id uuid,
  assignee_user_id uuid,
  assignee_email text,
  assignee_name text,
  status text,
  assigned_at timestamptz,
  deadline_at timestamptz,
  signed_at timestamptz,
  followup_count int,
  last_followup_at timestamptz,
  days_overdue int,
  declined_reason text
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
    a.assignee_user_id,
    p.email AS assignee_email,
    p.full_name AS assignee_name,
    a.status,
    a.assigned_at,
    a.deadline_at,
    a.signed_at,
    a.followup_count,
    a.last_followup_at,
    GREATEST(0, EXTRACT(DAY FROM (now() - a.deadline_at)))::int AS days_overdue,
    a.declined_reason
  FROM culture_deck_signature_assignments a
  LEFT JOIN profiles p ON p.id = a.assignee_user_id
  WHERE a.deck_version = p_deck_version
  ORDER BY
    CASE a.status WHEN 'overdue' THEN 1 WHEN 'pending' THEN 2 WHEN 'declined' THEN 3 WHEN 'signed' THEN 4 ELSE 5 END,
    a.deadline_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r1646_member_status(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r1646_member_status(text) TO authenticated;

-- RPC 3: deadline alerts (overdue + due-soon)
CREATE OR REPLACE FUNCTION rpc_r1646_deadline_alerts()
RETURNS TABLE (
  id uuid,
  deck_version text,
  assignee_email text,
  assignee_name text,
  status text,
  deadline_at timestamptz,
  hours_to_deadline numeric,
  followup_count int,
  bucket text
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
    a.deck_version,
    p.email,
    p.full_name,
    a.status,
    a.deadline_at,
    ROUND(EXTRACT(EPOCH FROM (a.deadline_at - now())) / 3600.0, 1) AS hours_to_deadline,
    a.followup_count,
    CASE
      WHEN a.deadline_at < now() THEN 'overdue'
      WHEN a.deadline_at < now() + interval '24 hours' THEN 'due_24h'
      WHEN a.deadline_at < now() + interval '72 hours' THEN 'due_72h'
      ELSE 'future'
    END AS bucket
  FROM culture_deck_signature_assignments a
  LEFT JOIN profiles p ON p.id = a.assignee_user_id
  WHERE a.status IN ('pending','overdue')
    AND a.deadline_at < now() + interval '7 days'
  ORDER BY a.deadline_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r1646_deadline_alerts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r1646_deadline_alerts() TO authenticated;

-- RPC 4: per-version comparison (two versions side-by-side)
CREATE OR REPLACE FUNCTION rpc_r1646_version_comparison(p_version_a text, p_version_b text)
RETURNS TABLE (
  metric text,
  version_a_value numeric,
  version_b_value numeric,
  delta numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT
      a.deck_version,
      (COUNT(*))::numeric AS total,
      (COUNT(*) FILTER (WHERE a.status = 'signed'))::numeric AS signed_n,
      (COUNT(*) FILTER (WHERE a.status = 'declined'))::numeric AS declined_n,
      (COUNT(*) FILTER (WHERE a.status IN ('pending','overdue')))::numeric AS open_n,
      (AVG(EXTRACT(EPOCH FROM (a.signed_at - a.assigned_at))/86400.0) FILTER (WHERE a.signed_at IS NOT NULL))::numeric AS avg_days_to_sign,
      (SUM(a.followup_count))::numeric AS total_followups
    FROM culture_deck_signature_assignments a
    WHERE a.deck_version IN (p_version_a, p_version_b)
    GROUP BY a.deck_version
  )
  SELECT m.metric,
         COALESCE(av.val, 0) AS version_a_value,
         COALESCE(bv.val, 0) AS version_b_value,
         ROUND(COALESCE(bv.val,0) - COALESCE(av.val,0), 2) AS delta
  FROM (
    VALUES ('total_assigned'), ('signed'), ('declined'), ('open'), ('avg_days_to_sign'), ('total_followups')
  ) AS m(metric)
  LEFT JOIN LATERAL (
    SELECT CASE m.metric
      WHEN 'total_assigned' THEN total
      WHEN 'signed' THEN signed_n
      WHEN 'declined' THEN declined_n
      WHEN 'open' THEN open_n
      WHEN 'avg_days_to_sign' THEN avg_days_to_sign
      WHEN 'total_followups' THEN total_followups
    END AS val
    FROM agg WHERE deck_version = p_version_a
  ) av ON TRUE
  LEFT JOIN LATERAL (
    SELECT CASE m.metric
      WHEN 'total_assigned' THEN total
      WHEN 'signed' THEN signed_n
      WHEN 'declined' THEN declined_n
      WHEN 'open' THEN open_n
      WHEN 'avg_days_to_sign' THEN avg_days_to_sign
      WHEN 'total_followups' THEN total_followups
    END AS val
    FROM agg WHERE deck_version = p_version_b
  ) bv ON TRUE;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r1646_version_comparison(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r1646_version_comparison(text, text) TO authenticated;

-- RPC 5: follow-up timeline for an assignment
CREATE OR REPLACE FUNCTION rpc_r1646_followup_timeline(p_assignment_id uuid)
RETURNS TABLE (
  id uuid,
  followup_at timestamptz,
  channel text,
  outcome text,
  notes text,
  created_by_email text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.followup_at, f.channel, f.outcome, f.notes, f.created_by_email
  FROM culture_deck_signature_followups f
  WHERE f.assignment_id = p_assignment_id
  ORDER BY f.followup_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r1646_followup_timeline(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r1646_followup_timeline(uuid) TO authenticated;

-- RPC 6 (VOLATILE write): record follow-up
CREATE OR REPLACE FUNCTION rpc_r1646_record_followup(
  p_assignment_id uuid,
  p_channel text,
  p_outcome text,
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
  v_email text := (auth.jwt()->>'email');
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO culture_deck_signature_followups(assignment_id, channel, outcome, notes, created_by_email)
  VALUES (p_assignment_id, p_channel, p_outcome, p_notes, v_email)
  RETURNING id INTO v_id;

  UPDATE culture_deck_signature_assignments
     SET followup_count = followup_count + 1,
         last_followup_at = now(),
         updated_at = now()
   WHERE id = p_assignment_id;

  INSERT INTO founder_action_log(action_type, payload)
  VALUES ('r1646_record_followup', jsonb_build_object('assignment_id', p_assignment_id, 'channel', p_channel, 'actor_email', v_email));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r1646_record_followup(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r1646_record_followup(uuid, text, text, text) TO authenticated;

-- RPC 7 (VOLATILE write): mark assignment status
CREATE OR REPLACE FUNCTION rpc_r1646_mark_status(
  p_assignment_id uuid,
  p_new_status text,
  p_declined_reason text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text := (auth.jwt()->>'email');
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('pending','signed','declined','overdue','waived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE culture_deck_signature_assignments
     SET status = p_new_status,
         signed_at = CASE WHEN p_new_status = 'signed' THEN COALESCE(signed_at, now()) ELSE signed_at END,
         declined_reason = CASE WHEN p_new_status = 'declined' THEN p_declined_reason ELSE declined_reason END,
         updated_at = now()
   WHERE id = p_assignment_id;

  INSERT INTO founder_action_log(action_type, payload)
  VALUES ('r1646_mark_status', jsonb_build_object('assignment_id', p_assignment_id, 'new_status', p_new_status, 'actor_email', v_email));
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_r1646_mark_status(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_r1646_mark_status(uuid, text, text) TO authenticated;

COMMIT;