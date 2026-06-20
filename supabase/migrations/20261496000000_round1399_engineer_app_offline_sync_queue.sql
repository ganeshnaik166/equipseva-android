BEGIN;
-- r1399 · engineer_app_offline_sync_queue · Engineer App v0.6 offline sync (v0.6 Phase 3)

-- ============================================================================
-- TABLE: engineer_app_offline_events
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_app_offline_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_event_uuid text NOT NULL,
  event_kind text NOT NULL CHECK (event_kind IN (
    'job_started','job_step_completed','photo_uploaded','signature_captured',
    'code_red_dispatched','spare_part_consumed','visit_completed',
    'expense_submitted','equipment_inspection','generic_log'
  )),
  event_payload jsonb NOT NULL,
  captured_at_client timestamptz NOT NULL,
  received_at_server timestamptz DEFAULT now(),
  sync_status text DEFAULT 'pending' CHECK (sync_status IN (
    'pending','applied','conflict','rejected','superseded'
  )),
  conflict_reason text,
  applied_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE (engineer_user_id, client_event_uuid)
);

CREATE INDEX IF NOT EXISTS idx_eng_offline_events_user ON public.engineer_app_offline_events(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_offline_events_status ON public.engineer_app_offline_events(sync_status);
CREATE INDEX IF NOT EXISTS idx_eng_offline_events_kind ON public.engineer_app_offline_events(event_kind);
CREATE INDEX IF NOT EXISTS idx_eng_offline_events_recv ON public.engineer_app_offline_events(received_at_server DESC);
CREATE INDEX IF NOT EXISTS idx_eng_offline_events_captured ON public.engineer_app_offline_events(captured_at_client DESC);

ALTER TABLE public.engineer_app_offline_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_offline_events_self_or_founder ON public.engineer_app_offline_events;
CREATE POLICY eng_offline_events_self_or_founder ON public.engineer_app_offline_events
  FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

DROP POLICY IF EXISTS eng_offline_events_self_insert ON public.engineer_app_offline_events;
CREATE POLICY eng_offline_events_self_insert ON public.engineer_app_offline_events
  FOR INSERT TO authenticated
  WITH CHECK (engineer_user_id = auth.uid());

-- ============================================================================
-- TABLE: engineer_app_offline_conflicts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_app_offline_conflicts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offline_event_id uuid REFERENCES public.engineer_app_offline_events(id) ON DELETE CASCADE,
  conflict_kind text NOT NULL CHECK (conflict_kind IN (
    'stale_state','duplicate_event','validation_failed',
    'permission_denied','race_with_server','schema_mismatch'
  )),
  server_state_snapshot jsonb,
  client_state_snapshot jsonb,
  resolution_kind text DEFAULT 'unresolved' CHECK (resolution_kind IN (
    'unresolved','client_wins','server_wins','manual_review','auto_reconciled'
  )),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_offline_conflicts_event ON public.engineer_app_offline_conflicts(offline_event_id);
CREATE INDEX IF NOT EXISTS idx_eng_offline_conflicts_kind ON public.engineer_app_offline_conflicts(conflict_kind);
CREATE INDEX IF NOT EXISTS idx_eng_offline_conflicts_resolution ON public.engineer_app_offline_conflicts(resolution_kind);
CREATE INDEX IF NOT EXISTS idx_eng_offline_conflicts_created ON public.engineer_app_offline_conflicts(created_at DESC);

ALTER TABLE public.engineer_app_offline_conflicts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_offline_conflicts_founder_all ON public.engineer_app_offline_conflicts;
CREATE POLICY eng_offline_conflicts_founder_all ON public.engineer_app_offline_conflicts
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS eng_offline_conflicts_self_select ON public.engineer_app_offline_conflicts;
CREATE POLICY eng_offline_conflicts_self_select ON public.engineer_app_offline_conflicts
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.engineer_app_offline_events e
    WHERE e.id = offline_event_id AND e.engineer_user_id = auth.uid()
  ));

-- ============================================================================
-- TABLE: engineer_app_sync_sessions
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_app_sync_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_started_at timestamptz NOT NULL,
  session_ended_at timestamptz,
  events_sent_count int DEFAULT 0,
  events_accepted_count int DEFAULT 0,
  events_rejected_count int DEFAULT 0,
  bytes_transferred bigint DEFAULT 0,
  client_version text,
  network_kind text CHECK (network_kind IN ('2g','3g','4g','5g','wifi','satellite','unknown')),
  last_event_received_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_sync_sessions_user ON public.engineer_app_sync_sessions(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eng_sync_sessions_started ON public.engineer_app_sync_sessions(session_started_at DESC);
CREATE INDEX IF NOT EXISTS idx_eng_sync_sessions_network ON public.engineer_app_sync_sessions(network_kind);

ALTER TABLE public.engineer_app_sync_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eng_sync_sessions_self_or_founder ON public.engineer_app_sync_sessions;
CREATE POLICY eng_sync_sessions_self_or_founder ON public.engineer_app_sync_sessions
  FOR SELECT TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

DROP POLICY IF EXISTS eng_sync_sessions_self_write ON public.engineer_app_sync_sessions;
CREATE POLICY eng_sync_sessions_self_write ON public.engineer_app_sync_sessions
  FOR ALL TO authenticated
  USING (engineer_user_id = auth.uid()) WITH CHECK (engineer_user_id = auth.uid());

-- ============================================================================
-- RPC: founder_engineer_app_offline_sync_summary — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_app_offline_sync_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_app_offline_sync_summary()
RETURNS TABLE (
  total_events_30d bigint,
  total_events_lifetime bigint,
  pending_count bigint,
  applied_count bigint,
  conflict_count bigint,
  rejected_count bigint,
  superseded_count bigint,
  conflicts_unresolved bigint,
  sync_lag_p50_seconds numeric,
  sync_lag_p95_seconds numeric,
  bytes_transferred_30d bigint,
  active_engineers_30d bigint,
  sessions_30d bigint,
  top_event_kind text,
  top_event_kind_count bigint,
  top_network_kind text,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_kind text;
  v_top_kind_count bigint;
  v_top_net text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT event_kind, count(*) INTO v_top_kind, v_top_kind_count
  FROM public.engineer_app_offline_events
  WHERE received_at_server >= now() - interval '30 days'
  GROUP BY event_kind
  ORDER BY count(*) DESC NULLS LAST
  LIMIT 1;

  SELECT network_kind INTO v_top_net
  FROM public.engineer_app_sync_sessions
  WHERE session_started_at >= now() - interval '30 days' AND network_kind IS NOT NULL
  GROUP BY network_kind
  ORDER BY count(*) DESC NULLS LAST
  LIMIT 1;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.engineer_app_offline_events WHERE received_at_server >= now() - interval '30 days'),
    (SELECT count(*) FROM public.engineer_app_offline_events),
    (SELECT count(*) FROM public.engineer_app_offline_events WHERE sync_status='pending'),
    (SELECT count(*) FROM public.engineer_app_offline_events WHERE sync_status='applied'),
    (SELECT count(*) FROM public.engineer_app_offline_events WHERE sync_status='conflict'),
    (SELECT count(*) FROM public.engineer_app_offline_events WHERE sync_status='rejected'),
    (SELECT count(*) FROM public.engineer_app_offline_events WHERE sync_status='superseded'),
    (SELECT count(*) FROM public.engineer_app_offline_conflicts WHERE resolution_kind='unresolved'),
    COALESCE((
      SELECT ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (received_at_server - captured_at_client)))::numeric, 2)
      FROM public.engineer_app_offline_events
      WHERE received_at_server >= now() - interval '30 days'
    ), 0),
    COALESCE((
      SELECT ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (received_at_server - captured_at_client)))::numeric, 2)
      FROM public.engineer_app_offline_events
      WHERE received_at_server >= now() - interval '30 days'
    ), 0),
    COALESCE((SELECT sum(bytes_transferred) FROM public.engineer_app_sync_sessions WHERE session_started_at >= now() - interval '30 days'), 0)::bigint,
    (SELECT count(DISTINCT engineer_user_id) FROM public.engineer_app_offline_events WHERE received_at_server >= now() - interval '30 days'),
    (SELECT count(*) FROM public.engineer_app_sync_sessions WHERE session_started_at >= now() - interval '30 days'),
    COALESCE(v_top_kind, '—'),
    COALESCE(v_top_kind_count, 0),
    COALESCE(v_top_net, '—'),
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_app_offline_sync_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_app_offline_sync_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_engineer_app_offline_events_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_app_offline_events_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_app_offline_events_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  client_event_uuid text,
  event_kind text,
  sync_status text,
  conflict_reason text,
  captured_at_client timestamptz,
  received_at_server timestamptz,
  applied_at timestamptz,
  lag_seconds numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id, e.engineer_user_id, e.client_event_uuid, e.event_kind,
    e.sync_status, e.conflict_reason,
    e.captured_at_client, e.received_at_server, e.applied_at,
    ROUND(EXTRACT(EPOCH FROM (e.received_at_server - e.captured_at_client))::numeric, 2)
  FROM public.engineer_app_offline_events e
  ORDER BY e.received_at_server DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_app_offline_events_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_app_offline_events_recent(int) TO authenticated;

-- ============================================================================
-- RPC: founder_engineer_app_offline_conflicts_recent
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_app_offline_conflicts_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_app_offline_conflicts_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  offline_event_id uuid,
  event_kind text,
  engineer_user_id uuid,
  conflict_kind text,
  resolution_kind text,
  resolved_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    c.id, c.offline_event_id, e.event_kind, e.engineer_user_id,
    c.conflict_kind, c.resolution_kind, c.resolved_at, c.created_at
  FROM public.engineer_app_offline_conflicts c
  LEFT JOIN public.engineer_app_offline_events e ON e.id = c.offline_event_id
  ORDER BY c.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_engineer_app_offline_conflicts_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_app_offline_conflicts_recent(int) TO authenticated;

-- ============================================================================
-- RPC: engineer_app_offline_submit_event (auth — engineer client calls)
-- ============================================================================
DROP FUNCTION IF EXISTS public.engineer_app_offline_submit_event(text, text, jsonb, timestamptz);
CREATE OR REPLACE FUNCTION public.engineer_app_offline_submit_event(
  p_client_event_uuid text,
  p_event_kind text,
  p_event_payload jsonb,
  p_captured_at_client timestamptz
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;
  IF p_client_event_uuid IS NULL OR length(p_client_event_uuid) < 8 THEN
    RAISE EXCEPTION 'client_event_uuid required' USING ERRCODE='22023';
  END IF;
  IF p_event_kind NOT IN (
    'job_started','job_step_completed','photo_uploaded','signature_captured',
    'code_red_dispatched','spare_part_consumed','visit_completed',
    'expense_submitted','equipment_inspection','generic_log'
  ) THEN
    RAISE EXCEPTION 'invalid event_kind' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.engineer_app_offline_events(
    engineer_user_id, client_event_uuid, event_kind, event_payload, captured_at_client
  )
  VALUES (v_uid, p_client_event_uuid, p_event_kind, COALESCE(p_event_payload, '{}'::jsonb), p_captured_at_client)
  ON CONFLICT (engineer_user_id, client_event_uuid) DO UPDATE
    SET sync_status = engineer_app_offline_events.sync_status
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_app_offline_submit_event(text, text, jsonb, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_app_offline_submit_event(text, text, jsonb, timestamptz) TO authenticated;

-- ============================================================================
-- RPC: engineer_app_offline_start_sync_session
-- ============================================================================
DROP FUNCTION IF EXISTS public.engineer_app_offline_start_sync_session(text, text);
CREATE OR REPLACE FUNCTION public.engineer_app_offline_start_sync_session(
  p_client_version text DEFAULT NULL,
  p_network_kind text DEFAULT 'unknown'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.engineer_app_sync_sessions(
    engineer_user_id, session_started_at, client_version, network_kind
  )
  VALUES (v_uid, now(), p_client_version,
    CASE WHEN p_network_kind IN ('2g','3g','4g','5g','wifi','satellite','unknown')
         THEN p_network_kind ELSE 'unknown' END)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_app_offline_start_sync_session(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_app_offline_start_sync_session(text, text) TO authenticated;

-- ============================================================================
-- RPC: engineer_app_offline_close_sync_session
-- ============================================================================
DROP FUNCTION IF EXISTS public.engineer_app_offline_close_sync_session(uuid, int, int, int, bigint);
CREATE OR REPLACE FUNCTION public.engineer_app_offline_close_sync_session(
  p_session_id uuid,
  p_events_sent_count int DEFAULT 0,
  p_events_accepted_count int DEFAULT 0,
  p_events_rejected_count int DEFAULT 0,
  p_bytes_transferred bigint DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE='42501';
  END IF;

  UPDATE public.engineer_app_sync_sessions
  SET session_ended_at = now(),
      events_sent_count = COALESCE(p_events_sent_count, 0),
      events_accepted_count = COALESCE(p_events_accepted_count, 0),
      events_rejected_count = COALESCE(p_events_rejected_count, 0),
      bytes_transferred = COALESCE(p_bytes_transferred, 0),
      last_event_received_at = now()
  WHERE id = p_session_id AND engineer_user_id = v_uid;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_app_offline_close_sync_session(uuid, int, int, int, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_app_offline_close_sync_session(uuid, int, int, int, bigint) TO authenticated;

-- ============================================================================
-- RPC: log_founder_engineer_app_resolve_conflict (founder)
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_engineer_app_resolve_conflict(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_engineer_app_resolve_conflict(
  p_conflict_id uuid,
  p_resolution_kind text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;
  IF p_resolution_kind NOT IN ('unresolved','client_wins','server_wins','manual_review','auto_reconciled') THEN
    RAISE EXCEPTION 'invalid resolution_kind' USING ERRCODE='22023';
  END IF;

  UPDATE public.engineer_app_offline_conflicts
  SET resolution_kind = p_resolution_kind,
      resolved_at = now(),
      resolved_by = auth.uid()
  WHERE id = p_conflict_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_engineer_app_resolve_conflict(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_engineer_app_resolve_conflict(uuid, text) TO authenticated;

-- ============================================================================
-- RPC: engineer_app_offline_sync_purge_old_applied (cron)
-- ============================================================================
DROP FUNCTION IF EXISTS public.engineer_app_offline_sync_purge_old_applied();
CREATE OR REPLACE FUNCTION public.engineer_app_offline_sync_purge_old_applied()
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM public.engineer_app_offline_events
  WHERE sync_status = 'applied'
    AND applied_at IS NOT NULL
    AND applied_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_app_offline_sync_purge_old_applied() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_app_offline_sync_purge_old_applied() TO authenticated, authenticated;

COMMIT;