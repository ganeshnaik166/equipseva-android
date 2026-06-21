BEGIN;

-- ============================================================
-- r1566 — Founder Engineer Escalation Queue
-- ============================================================
-- Engineers escalate stuck jobs, customer disputes, payment delays,
-- tool requests to founder/CTO. Track per-engineer escalation counts
-- and founder triage time SLA (target: 4h ack, 24h resolve).
-- ============================================================

-- ---------- TABLE 1: escalations ----------
CREATE TABLE IF NOT EXISTS founder_engineer_escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  engineer_id uuid REFERENCES engineers(id) ON DELETE SET NULL,
  category text NOT NULL CHECK (category IN ('stuck_job','customer_dispute','payment_delay','tool_request','safety_issue','other')),
  severity text NOT NULL DEFAULT 'p2' CHECK (severity IN ('p0','p1','p2','p3')),
  subject text NOT NULL,
  body text NOT NULL,
  repair_job_id uuid REFERENCES repair_jobs(id) ON DELETE SET NULL,
  hospital_org_id uuid REFERENCES organizations(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','acknowledged','in_progress','resolved','rejected')),
  founder_ack_at timestamptz,
  founder_ack_by uuid REFERENCES auth.users(id),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id),
  resolution_note text,
  ack_seconds integer,
  resolve_seconds integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fee_escalations_engineer ON founder_engineer_escalations(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_fee_escalations_status ON founder_engineer_escalations(status);
CREATE INDEX IF NOT EXISTS idx_fee_escalations_severity ON founder_engineer_escalations(severity);
CREATE INDEX IF NOT EXISTS idx_fee_escalations_created ON founder_engineer_escalations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fee_escalations_category ON founder_engineer_escalations(category);

ALTER TABLE founder_engineer_escalations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_fee_escalations" ON founder_engineer_escalations;
CREATE POLICY "founder_only_fee_escalations" ON founder_engineer_escalations
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- TABLE 2: triage notes ----------
CREATE TABLE IF NOT EXISTS founder_engineer_escalation_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escalation_id uuid NOT NULL REFERENCES founder_engineer_escalations(id) ON DELETE CASCADE,
  author_user_id uuid NOT NULL REFERENCES auth.users(id),
  author_email text,
  note text NOT NULL,
  visibility text NOT NULL DEFAULT 'founder' CHECK (visibility IN ('founder','engineer','public')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fee_notes_escalation ON founder_engineer_escalation_notes(escalation_id);
CREATE INDEX IF NOT EXISTS idx_fee_notes_created ON founder_engineer_escalation_notes(created_at DESC);

ALTER TABLE founder_engineer_escalation_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "founder_only_fee_notes" ON founder_engineer_escalation_notes;
CREATE POLICY "founder_only_fee_notes" ON founder_engineer_escalation_notes
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

-- 1) Headline KPIs
DROP FUNCTION IF EXISTS founder_engineer_escalation_kpis();
CREATE OR REPLACE FUNCTION founder_engineer_escalation_kpis()
RETURNS TABLE (
  open_count bigint,
  ack_count bigint,
  in_progress_count bigint,
  resolved_7d bigint,
  rejected_7d bigint,
  p0_open bigint,
  p1_open bigint,
  p2_open bigint,
  p3_open bigint,
  avg_ack_minutes numeric,
  avg_resolve_hours numeric,
  ack_sla_4h_pct numeric,
  resolve_sla_24h_pct numeric,
  unique_engineers_30d bigint,
  escalations_30d bigint,
  median_resolve_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE status='open'),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE status='acknowledged'),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE status='in_progress'),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE status='resolved' AND resolved_at >= now() - interval '7 days'),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE status='rejected' AND updated_at >= now() - interval '7 days'),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE severity='p0' AND status IN ('open','acknowledged','in_progress')),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE severity='p1' AND status IN ('open','acknowledged','in_progress')),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE severity='p2' AND status IN ('open','acknowledged','in_progress')),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE severity='p3' AND status IN ('open','acknowledged','in_progress')),
    COALESCE((SELECT round(avg(ack_seconds)/60.0, 1) FROM founder_engineer_escalations WHERE ack_seconds IS NOT NULL AND founder_ack_at >= now() - interval '30 days'), 0),
    COALESCE((SELECT round(avg(resolve_seconds)/3600.0, 1) FROM founder_engineer_escalations WHERE resolve_seconds IS NOT NULL AND resolved_at >= now() - interval '30 days'), 0),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE ack_seconds <= 14400) / NULLIF(count(*),0), 1) FROM founder_engineer_escalations WHERE ack_seconds IS NOT NULL AND founder_ack_at >= now() - interval '30 days'), 0),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE resolve_seconds <= 86400) / NULLIF(count(*),0), 1) FROM founder_engineer_escalations WHERE resolve_seconds IS NOT NULL AND resolved_at >= now() - interval '30 days'), 0),
    (SELECT COUNT(DISTINCT engineer_user_id) FROM founder_engineer_escalations WHERE created_at >= now() - interval '30 days'),
    (SELECT COUNT(*) FROM founder_engineer_escalations WHERE created_at >= now() - interval '30 days'),
    COALESCE((SELECT round((percentile_cont(0.5) WITHIN GROUP (ORDER BY resolve_seconds))::numeric/3600.0, 1) FROM founder_engineer_escalations WHERE resolve_seconds IS NOT NULL AND resolved_at >= now() - interval '30 days'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_escalation_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_escalation_kpis() TO authenticated;

-- 2) Open queue (FIFO with priority)
DROP FUNCTION IF EXISTS founder_engineer_escalation_open_queue();
CREATE OR REPLACE FUNCTION founder_engineer_escalation_open_queue()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  engineer_tier text,
  category text,
  severity text,
  subject text,
  status text,
  hospital_name text,
  age_hours numeric,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.id,
    p.email,
    eng.cached_highest_tier,
    e.category,
    e.severity,
    e.subject,
    e.status,
    org.name,
    round(EXTRACT(EPOCH FROM (now() - e.created_at))/3600.0, 1),
    e.created_at
  FROM founder_engineer_escalations e
  LEFT JOIN profiles p ON p.id = e.engineer_user_id
  LEFT JOIN engineers eng ON eng.user_id = e.engineer_user_id
  LEFT JOIN organizations org ON org.id = e.hospital_org_id
  WHERE e.status IN ('open','acknowledged','in_progress')
  ORDER BY
    CASE e.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    e.created_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_escalation_open_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_escalation_open_queue() TO authenticated;

-- 3) Per-engineer leaderboard
DROP FUNCTION IF EXISTS founder_engineer_escalation_per_engineer();
CREATE OR REPLACE FUNCTION founder_engineer_escalation_per_engineer()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  tier text,
  total_30d bigint,
  open_now bigint,
  resolved_30d bigint,
  avg_age_hours numeric,
  last_escalation timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.engineer_user_id,
    p.email,
    eng.cached_highest_tier,
    COUNT(*) FILTER (WHERE e.created_at >= now() - interval '30 days'),
    COUNT(*) FILTER (WHERE e.status IN ('open','acknowledged','in_progress')),
    COUNT(*) FILTER (WHERE e.status='resolved' AND e.resolved_at >= now() - interval '30 days'),
    COALESCE(round(avg(EXTRACT(EPOCH FROM (now() - e.created_at))/3600.0) FILTER (WHERE e.status IN ('open','acknowledged','in_progress')), 1), 0),
    MAX(e.created_at)
  FROM founder_engineer_escalations e
  LEFT JOIN profiles p ON p.id = e.engineer_user_id
  LEFT JOIN engineers eng ON eng.user_id = e.engineer_user_id
  GROUP BY e.engineer_user_id, p.email, eng.cached_highest_tier
  ORDER BY COUNT(*) FILTER (WHERE e.created_at >= now() - interval '30 days') DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_escalation_per_engineer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_escalation_per_engineer() TO authenticated;

-- 4) Category breakdown
DROP FUNCTION IF EXISTS founder_engineer_escalation_by_category();
CREATE OR REPLACE FUNCTION founder_engineer_escalation_by_category()
RETURNS TABLE (
  id text,
  category text,
  total_30d bigint,
  open_now bigint,
  avg_resolve_hours numeric,
  resolve_sla_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.category AS id,
    e.category,
    COUNT(*) FILTER (WHERE e.created_at >= now() - interval '30 days'),
    COUNT(*) FILTER (WHERE e.status IN ('open','acknowledged','in_progress')),
    COALESCE(round(avg(e.resolve_seconds)/3600.0, 1) FILTER (WHERE e.resolve_seconds IS NOT NULL), 0),
    COALESCE(round(100.0 * count(*) FILTER (WHERE e.resolve_seconds <= 86400) / NULLIF(count(*) FILTER (WHERE e.resolve_seconds IS NOT NULL), 0), 1), 0)
  FROM founder_engineer_escalations e
  GROUP BY e.category
  ORDER BY COUNT(*) FILTER (WHERE e.created_at >= now() - interval '30 days') DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_escalation_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_escalation_by_category() TO authenticated;

-- 5) Recent activity timeline
DROP FUNCTION IF EXISTS founder_engineer_escalation_recent();
CREATE OR REPLACE FUNCTION founder_engineer_escalation_recent()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  category text,
  severity text,
  status text,
  subject text,
  resolve_hours numeric,
  created_at timestamptz,
  resolved_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.id,
    p.email,
    e.category,
    e.severity,
    e.status,
    e.subject,
    CASE WHEN e.resolve_seconds IS NOT NULL THEN round(e.resolve_seconds/3600.0, 1) ELSE NULL END,
    e.created_at,
    e.resolved_at
  FROM founder_engineer_escalations e
  LEFT JOIN profiles p ON p.id = e.engineer_user_id
  ORDER BY e.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_escalation_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_escalation_recent() TO authenticated;

-- 6) SLA breaches (open > 4h without ack, or > 24h without resolve)
DROP FUNCTION IF EXISTS founder_engineer_escalation_sla_breaches();
CREATE OR REPLACE FUNCTION founder_engineer_escalation_sla_breaches()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  severity text,
  category text,
  subject text,
  status text,
  age_hours numeric,
  breach_type text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    e.id,
    p.email,
    e.severity,
    e.category,
    e.subject,
    e.status,
    round(EXTRACT(EPOCH FROM (now() - e.created_at))/3600.0, 1),
    CASE
      WHEN e.status = 'open' AND e.created_at < now() - interval '4 hours' THEN 'ack_breach'
      WHEN e.status IN ('acknowledged','in_progress') AND e.created_at < now() - interval '24 hours' THEN 'resolve_breach'
      ELSE 'other'
    END
  FROM founder_engineer_escalations e
  LEFT JOIN profiles p ON p.id = e.engineer_user_id
  WHERE
    (e.status = 'open' AND e.created_at < now() - interval '4 hours')
    OR (e.status IN ('acknowledged','in_progress') AND e.created_at < now() - interval '24 hours')
  ORDER BY e.created_at ASC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_escalation_sla_breaches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_escalation_sla_breaches() TO authenticated;

-- 7) Triage notes for a specific escalation
DROP FUNCTION IF EXISTS founder_engineer_escalation_notes_recent();
CREATE OR REPLACE FUNCTION founder_engineer_escalation_notes_recent()
RETURNS TABLE (
  id uuid,
  escalation_id uuid,
  escalation_subject text,
  author_email text,
  visibility text,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    n.id,
    n.escalation_id,
    e.subject,
    n.author_email,
    n.visibility,
    n.note,
    n.created_at
  FROM founder_engineer_escalation_notes n
  LEFT JOIN founder_engineer_escalations e ON e.id = n.escalation_id
  ORDER BY n.created_at DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_engineer_escalation_notes_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_escalation_notes_recent() TO authenticated;

-- ============================================================
-- WRITE / LOG HELPERS (VOLATILE SECDEF)
-- ============================================================

-- log helper 1: acknowledge
CREATE OR REPLACE FUNCTION log_founder_escalation_ack(p_escalation_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_email text := (auth.jwt()->>'email');
  v_created timestamptz;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT created_at INTO v_created FROM founder_engineer_escalations WHERE id = p_escalation_id;
  IF v_created IS NULL THEN RAISE EXCEPTION 'escalation not found'; END IF;

  UPDATE founder_engineer_escalations
  SET status = 'acknowledged',
      founder_ack_at = now(),
      founder_ack_by = v_actor,
      ack_seconds = EXTRACT(EPOCH FROM (now() - v_created))::int,
      updated_at = now()
  WHERE id = p_escalation_id AND status = 'open';

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (v_actor, v_email, 'escalation_ack', jsonb_build_object('id', p_escalation_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_escalation_ack(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_escalation_ack(uuid) TO authenticated;

-- log helper 2: resolve
CREATE OR REPLACE FUNCTION log_founder_escalation_resolve(p_escalation_id uuid, p_note text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_email text := (auth.jwt()->>'email');
  v_created timestamptz;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT created_at INTO v_created FROM founder_engineer_escalations WHERE id = p_escalation_id;
  IF v_created IS NULL THEN RAISE EXCEPTION 'escalation not found'; END IF;

  UPDATE founder_engineer_escalations
  SET status = 'resolved',
      resolved_at = now(),
      resolved_by = v_actor,
      resolution_note = p_note,
      resolve_seconds = EXTRACT(EPOCH FROM (now() - v_created))::int,
      updated_at = now()
  WHERE id = p_escalation_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (v_actor, v_email, 'escalation_resolve', jsonb_build_object('id', p_escalation_id, 'note', p_note));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_escalation_resolve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_escalation_resolve(uuid, text) TO authenticated;

-- log helper 3: reject
CREATE OR REPLACE FUNCTION log_founder_escalation_reject(p_escalation_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_email text := (auth.jwt()->>'email');
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE founder_engineer_escalations
  SET status = 'rejected',
      resolution_note = p_reason,
      resolved_by = v_actor,
      updated_at = now()
  WHERE id = p_escalation_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (v_actor, v_email, 'escalation_reject', jsonb_build_object('id', p_escalation_id, 'reason', p_reason));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_escalation_reject(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_escalation_reject(uuid, text) TO authenticated;

-- log helper 4: add note
CREATE OR REPLACE FUNCTION log_founder_escalation_note(p_escalation_id uuid, p_note text, p_visibility text)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_email text := (auth.jwt()->>'email');
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_engineer_escalation_notes (escalation_id, author_user_id, author_email, note, visibility)
  VALUES (p_escalation_id, v_actor, v_email, p_note, COALESCE(p_visibility, 'founder'))
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (v_actor, v_email, 'escalation_note', jsonb_build_object('escalation_id', p_escalation_id, 'note_id', v_id));

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_escalation_note(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_escalation_note(uuid, text, text) TO authenticated;

COMMIT;