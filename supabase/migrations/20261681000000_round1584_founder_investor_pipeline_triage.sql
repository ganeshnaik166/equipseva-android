BEGIN;

-- ============================================================================
-- r1584 — Founder Investor Pipeline Triage Queue
-- Every 7 days, founder triages investor pipeline: drop low-fit, push high-heat,
-- add new prospects. Append-only founder action log per triage decision.
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_investor_pipeline_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  firm text,
  stage text NOT NULL DEFAULT 'sourced' CHECK (stage IN ('sourced','contacted','meeting','diligence','term_sheet','closed_won','closed_lost')),
  fit_score int NOT NULL DEFAULT 50 CHECK (fit_score BETWEEN 0 AND 100),
  heat_score int NOT NULL DEFAULT 50 CHECK (heat_score BETWEEN 0 AND 100),
  ticket_size_lakh int,
  geo text,
  last_touch_at timestamptz,
  next_action text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','dropped','paused','won','lost')),
  notes text,
  created_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_investor_triage_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_started_at timestamptz NOT NULL DEFAULT now(),
  session_ended_at timestamptz,
  entries_added int NOT NULL DEFAULT 0,
  entries_dropped int NOT NULL DEFAULT 0,
  entries_pushed int NOT NULL DEFAULT 0,
  founder_notes text,
  created_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fipe_status ON founder_investor_pipeline_entries(status);
CREATE INDEX IF NOT EXISTS idx_fipe_stage ON founder_investor_pipeline_entries(stage);
CREATE INDEX IF NOT EXISTS idx_fipe_heat ON founder_investor_pipeline_entries(heat_score DESC);
CREATE INDEX IF NOT EXISTS idx_fits_started ON founder_investor_triage_sessions(session_started_at DESC);

ALTER TABLE founder_investor_pipeline_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_triage_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fipe_founder_only ON founder_investor_pipeline_entries;
CREATE POLICY fipe_founder_only ON founder_investor_pipeline_entries
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS fits_founder_only ON founder_investor_triage_sessions;
CREATE POLICY fits_founder_only ON founder_investor_triage_sessions
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION rpc_founder_investor_pipeline_overview()
RETURNS TABLE(
  total_active int,
  total_dropped int,
  total_won int,
  total_lost int,
  high_heat_count int,
  low_fit_count int,
  diligence_count int,
  term_sheet_count int,
  avg_fit_score numeric,
  avg_heat_score numeric,
  pipeline_value_lakh numeric,
  last_triage_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE status='active')::int,
    COUNT(*) FILTER (WHERE status='dropped')::int,
    COUNT(*) FILTER (WHERE status='won')::int,
    COUNT(*) FILTER (WHERE status='lost')::int,
    COUNT(*) FILTER (WHERE heat_score >= 70 AND status='active')::int,
    COUNT(*) FILTER (WHERE fit_score < 40 AND status='active')::int,
    COUNT(*) FILTER (WHERE stage='diligence' AND status='active')::int,
    COUNT(*) FILTER (WHERE stage='term_sheet' AND status='active')::int,
    ROUND(AVG(fit_score) FILTER (WHERE status='active'), 1),
    ROUND(AVG(heat_score) FILTER (WHERE status='active'), 1),
    COALESCE(SUM(ticket_size_lakh) FILTER (WHERE status='active'), 0)::numeric,
    (SELECT MAX(session_started_at) FROM founder_investor_triage_sessions)
  FROM founder_investor_pipeline_entries;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_investor_pipeline_active()
RETURNS TABLE(
  id uuid,
  investor_name text,
  firm text,
  stage text,
  fit_score int,
  heat_score int,
  ticket_size_lakh int,
  geo text,
  last_touch_at timestamptz,
  next_action text,
  days_since_touch numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.investor_name, e.firm, e.stage, e.fit_score, e.heat_score,
         e.ticket_size_lakh, e.geo, e.last_touch_at, e.next_action,
         ROUND(EXTRACT(EPOCH FROM (now() - e.last_touch_at))/86400.0, 1)
  FROM founder_investor_pipeline_entries e
  WHERE e.status='active'
  ORDER BY e.heat_score DESC, e.fit_score DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_investor_drop_candidates()
RETURNS TABLE(
  id uuid,
  investor_name text,
  firm text,
  fit_score int,
  heat_score int,
  days_since_touch numeric,
  drop_reason text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.investor_name, e.firm, e.fit_score, e.heat_score,
         ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.last_touch_at, e.created_at)))/86400.0, 1),
         CASE
           WHEN e.fit_score < 30 THEN 'low fit'
           WHEN e.heat_score < 20 THEN 'cold'
           WHEN e.last_touch_at IS NULL OR e.last_touch_at < now() - interval '45 days' THEN 'stale'
           ELSE 'review'
         END
  FROM founder_investor_pipeline_entries e
  WHERE e.status='active'
    AND (e.fit_score < 30 OR e.heat_score < 20
         OR e.last_touch_at IS NULL
         OR e.last_touch_at < now() - interval '45 days')
  ORDER BY e.fit_score ASC, e.heat_score ASC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_investor_push_candidates()
RETURNS TABLE(
  id uuid,
  investor_name text,
  firm text,
  stage text,
  fit_score int,
  heat_score int,
  ticket_size_lakh int,
  next_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.investor_name, e.firm, e.stage, e.fit_score, e.heat_score,
         e.ticket_size_lakh, e.next_action
  FROM founder_investor_pipeline_entries e
  WHERE e.status='active' AND e.heat_score >= 70 AND e.fit_score >= 60
  ORDER BY (e.heat_score + e.fit_score) DESC
  LIMIT 25;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_investor_triage_history()
RETURNS TABLE(
  id uuid,
  session_started_at timestamptz,
  session_ended_at timestamptz,
  entries_added int,
  entries_dropped int,
  entries_pushed int,
  founder_notes text,
  duration_minutes numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.session_started_at, s.session_ended_at,
         s.entries_added, s.entries_dropped, s.entries_pushed, s.founder_notes,
         ROUND(EXTRACT(EPOCH FROM (COALESCE(s.session_ended_at, now()) - s.session_started_at))/60.0, 1)
  FROM founder_investor_triage_sessions s
  ORDER BY s.session_started_at DESC
  LIMIT 20;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_investor_action_log_recent()
RETURNS TABLE(
  id bigint,
  ts timestamptz,
  actor_email text,
  op_name text,
  after_value jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.ts, l.actor_email, l.op_name, l.after_value
  FROM founder_action_log l
  WHERE l.op_name LIKE 'investor_triage_%'
  ORDER BY l.ts DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_investor_stage_breakdown()
RETURNS TABLE(
  stage text,
  cnt int,
  avg_fit numeric,
  avg_heat numeric,
  total_lakh numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.stage,
         COUNT(*)::int,
         ROUND(AVG(e.fit_score), 1),
         ROUND(AVG(e.heat_score), 1),
         COALESCE(SUM(e.ticket_size_lakh), 0)::numeric
  FROM founder_investor_pipeline_entries e
  WHERE e.status='active'
  GROUP BY e.stage
  ORDER BY COUNT(*) DESC;
END;
$$;

-- ============================================================================
-- LOG HELPERS (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_investor_triage_drop(p_entry_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_pipeline_entries
     SET status='dropped', updated_at=now(),
         notes = COALESCE(notes, '') || E'\n[DROP] ' || COALESCE(p_reason, '')
   WHERE id = p_entry_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_triage_drop',
          jsonb_build_object('entry_id', p_entry_id, 'reason', p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_investor_triage_push(p_entry_id uuid, p_next_action text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_pipeline_entries
     SET heat_score = LEAST(100, heat_score + 10),
         next_action = COALESCE(p_next_action, next_action),
         last_touch_at = now(),
         updated_at = now()
   WHERE id = p_entry_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_triage_push',
          jsonb_build_object('entry_id', p_entry_id, 'next_action', p_next_action));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_investor_triage_add(
  p_investor_name text, p_firm text, p_stage text,
  p_fit_score int, p_heat_score int, p_ticket_size_lakh int, p_geo text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_pipeline_entries(
    investor_name, firm, stage, fit_score, heat_score, ticket_size_lakh, geo, created_by_user_id
  ) VALUES (
    p_investor_name, p_firm, COALESCE(p_stage,'sourced'),
    COALESCE(p_fit_score, 50), COALESCE(p_heat_score, 50),
    p_ticket_size_lakh, p_geo, auth.uid()
  ) RETURNING id INTO v_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_triage_add',
          jsonb_build_object('entry_id', v_id, 'investor_name', p_investor_name, 'firm', p_firm));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_investor_triage_session_close(
  p_session_id uuid, p_added int, p_dropped int, p_pushed int, p_notes text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_triage_sessions
     SET session_ended_at = now(),
         entries_added = COALESCE(p_added, 0),
         entries_dropped = COALESCE(p_dropped, 0),
         entries_pushed = COALESCE(p_pushed, 0),
         founder_notes = p_notes
   WHERE id = p_session_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'investor_triage_session_close',
          jsonb_build_object('session_id', p_session_id, 'added', p_added,
                             'dropped', p_dropped, 'pushed', p_pushed));
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION rpc_founder_investor_pipeline_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_pipeline_active() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_drop_candidates() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_push_candidates() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_triage_history() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_action_log_recent() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION rpc_founder_investor_stage_breakdown() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_triage_drop(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_triage_push(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_triage_add(text, text, text, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_investor_triage_session_close(uuid, int, int, int, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION rpc_founder_investor_pipeline_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_pipeline_active() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_drop_candidates() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_push_candidates() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_triage_history() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_action_log_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_founder_investor_stage_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_triage_drop(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_triage_push(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_triage_add(text, text, text, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_investor_triage_session_close(uuid, int, int, int, text) TO authenticated;

COMMIT;