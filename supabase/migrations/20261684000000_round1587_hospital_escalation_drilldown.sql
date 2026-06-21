BEGIN;

-- ============================================================================
-- Round 1587 — Hospital Escalation Drilldown
-- Per-hospital escalation history, root-cause clustering, repeat-escalator
-- flag, founder action queue.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Table 1: hospital_escalation_events
-- Logs every escalation (incident, complaint, SLA breach, code-red) per org.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_escalation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (source_type IN ('incident','complaint','sla_breach','code_red','rating_low','manual')),
  source_ref_id uuid,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')) DEFAULT 'p2',
  root_cause_cluster text NOT NULL CHECK (root_cause_cluster IN ('engineer_quality','parts_delay','dispatch_miss','billing_dispute','communication','equipment_failure','unknown')) DEFAULT 'unknown',
  summary text NOT NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolution_note text,
  resolved_by_user_id uuid REFERENCES auth.users(id),
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hosp_esc_evt_org_opened ON public.hospital_escalation_events(hospital_org_id, opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_hosp_esc_evt_cluster ON public.hospital_escalation_events(root_cause_cluster, opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_hosp_esc_evt_severity ON public.hospital_escalation_events(severity, resolved_at);

ALTER TABLE public.hospital_escalation_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hosp_esc_evt_founder_only ON public.hospital_escalation_events;
CREATE POLICY hosp_esc_evt_founder_only ON public.hospital_escalation_events
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------------
-- Table 2: founder_escalation_action_queue
-- Founder-only triage queue (next-action per hospital escalation).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_escalation_action_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  escalation_event_id uuid REFERENCES public.hospital_escalation_events(id) ON DELETE SET NULL,
  action_type text NOT NULL CHECK (action_type IN ('call_chairman','dispatch_senior','refund','credit_note','engineer_review','escalate_legal','close_relationship','other')),
  action_note text,
  priority text NOT NULL CHECK (priority IN ('p0','p1','p2','p3')) DEFAULT 'p2',
  state text NOT NULL CHECK (state IN ('pending','in_progress','done','cancelled')) DEFAULT 'pending',
  due_at timestamptz,
  done_at timestamptz,
  done_note text,
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_esc_queue_org ON public.founder_escalation_action_queue(hospital_org_id, state, priority);
CREATE INDEX IF NOT EXISTS idx_founder_esc_queue_state ON public.founder_escalation_action_queue(state, due_at);

ALTER TABLE public.founder_escalation_action_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_esc_queue_founder_only ON public.founder_escalation_action_queue;
CREATE POLICY founder_esc_queue_founder_only ON public.founder_escalation_action_queue
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- ============================================================================

-- 1) Per-hospital escalation summary (KPIs)
CREATE OR REPLACE FUNCTION public.rpc_founder_hospital_esc_summary()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  total_escalations bigint,
  open_escalations bigint,
  p0_p1_count bigint,
  avg_resolution_hours numeric,
  last_escalation_at timestamptz,
  repeat_flag boolean
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
    o.id,
    o.name,
    COUNT(e.*)::bigint AS total_escalations,
    COUNT(e.*) FILTER (WHERE e.resolved_at IS NULL)::bigint AS open_escalations,
    COUNT(e.*) FILTER (WHERE e.severity IN ('p0','p1'))::bigint AS p0_p1_count,
    COALESCE(AVG(EXTRACT(EPOCH FROM (e.resolved_at - e.opened_at)) / 3600.0) FILTER (WHERE e.resolved_at IS NOT NULL), 0)::numeric AS avg_resolution_hours,
    MAX(e.opened_at) AS last_escalation_at,
    (COUNT(e.*) FILTER (WHERE e.opened_at >= now() - interval '90 days') >= 3) AS repeat_flag
  FROM organizations o
  JOIN hospital_escalation_events e ON e.hospital_org_id = o.id
  GROUP BY o.id, o.name
  ORDER BY total_escalations DESC
  LIMIT 200;
END;
$$;

-- 2) Escalation history (all events)
CREATE OR REPLACE FUNCTION public.rpc_founder_hospital_esc_history()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  source_type text,
  severity text,
  root_cause_cluster text,
  summary text,
  opened_at timestamptz,
  resolved_at timestamptz,
  resolution_hours numeric,
  resolution_note text
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
    e.id,
    e.hospital_org_id,
    o.name,
    e.source_type,
    e.severity,
    e.root_cause_cluster,
    e.summary,
    e.opened_at,
    e.resolved_at,
    CASE WHEN e.resolved_at IS NOT NULL
      THEN (EXTRACT(EPOCH FROM (e.resolved_at - e.opened_at)) / 3600.0)::numeric
      ELSE NULL END AS resolution_hours,
    e.resolution_note
  FROM hospital_escalation_events e
  JOIN organizations o ON o.id = e.hospital_org_id
  ORDER BY e.opened_at DESC
  LIMIT 500;
END;
$$;

-- 3) Root-cause cluster breakdown
CREATE OR REPLACE FUNCTION public.rpc_founder_hospital_esc_clusters()
RETURNS TABLE (
  root_cause_cluster text,
  event_count bigint,
  affected_hospitals bigint,
  open_count bigint,
  avg_resolution_hours numeric
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
    e.root_cause_cluster,
    COUNT(*)::bigint AS event_count,
    COUNT(DISTINCT e.hospital_org_id)::bigint AS affected_hospitals,
    COUNT(*) FILTER (WHERE e.resolved_at IS NULL)::bigint AS open_count,
    COALESCE(AVG(EXTRACT(EPOCH FROM (e.resolved_at - e.opened_at)) / 3600.0) FILTER (WHERE e.resolved_at IS NOT NULL), 0)::numeric AS avg_resolution_hours
  FROM hospital_escalation_events e
  GROUP BY e.root_cause_cluster
  ORDER BY event_count DESC;
END;
$$;

-- 4) Repeat-escalator hospitals (>=3 in 90d)
CREATE OR REPLACE FUNCTION public.rpc_founder_hospital_esc_repeat()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  escalations_90d bigint,
  p0_p1_90d bigint,
  dominant_cluster text,
  last_escalation_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT e.hospital_org_id, e.root_cause_cluster, e.severity, e.opened_at
    FROM hospital_escalation_events e
    WHERE e.opened_at >= now() - interval '90 days'
  ),
  dom AS (
    SELECT b.hospital_org_id, b.root_cause_cluster,
      ROW_NUMBER() OVER (PARTITION BY b.hospital_org_id ORDER BY COUNT(*) DESC) AS rn
    FROM base b
    GROUP BY b.hospital_org_id, b.root_cause_cluster
  )
  SELECT
    o.id,
    o.name,
    COUNT(b.*)::bigint AS escalations_90d,
    COUNT(b.*) FILTER (WHERE b.severity IN ('p0','p1'))::bigint AS p0_p1_90d,
    (SELECT d.root_cause_cluster FROM dom d WHERE d.hospital_org_id = o.id AND d.rn = 1) AS dominant_cluster,
    MAX(b.opened_at) AS last_escalation_at
  FROM organizations o
  JOIN base b ON b.hospital_org_id = o.id
  GROUP BY o.id, o.name
  HAVING COUNT(b.*) >= 3
  ORDER BY escalations_90d DESC
  LIMIT 100;
END;
$$;

-- 5) Founder action queue (pending + in_progress)
CREATE OR REPLACE FUNCTION public.rpc_founder_esc_action_queue()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  action_type text,
  action_note text,
  priority text,
  state text,
  due_at timestamptz,
  created_at timestamptz,
  overdue_hours numeric
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
    q.id,
    q.hospital_org_id,
    o.name,
    q.action_type,
    q.action_note,
    q.priority,
    q.state,
    q.due_at,
    q.created_at,
    CASE WHEN q.due_at IS NOT NULL AND q.due_at < now() AND q.state IN ('pending','in_progress')
      THEN (EXTRACT(EPOCH FROM (now() - q.due_at)) / 3600.0)::numeric
      ELSE 0::numeric END AS overdue_hours
  FROM founder_escalation_action_queue q
  JOIN organizations o ON o.id = q.hospital_org_id
  WHERE q.state IN ('pending','in_progress')
  ORDER BY
    CASE q.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    q.due_at NULLS LAST,
    q.created_at DESC
  LIMIT 200;
END;
$$;

-- 6) Severity / open-vs-closed KPIs (single-row digest)
CREATE OR REPLACE FUNCTION public.rpc_founder_esc_kpi_digest()
RETURNS TABLE (
  total_events bigint,
  open_events bigint,
  p0_count bigint,
  p1_count bigint,
  p2_count bigint,
  p3_count bigint,
  events_7d bigint,
  events_30d bigint,
  avg_resolution_hours numeric,
  queue_pending bigint,
  queue_overdue bigint,
  affected_hospitals bigint
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
    (SELECT COUNT(*) FROM hospital_escalation_events)::bigint,
    (SELECT COUNT(*) FROM hospital_escalation_events WHERE resolved_at IS NULL)::bigint,
    (SELECT COUNT(*) FROM hospital_escalation_events WHERE severity='p0')::bigint,
    (SELECT COUNT(*) FROM hospital_escalation_events WHERE severity='p1')::bigint,
    (SELECT COUNT(*) FROM hospital_escalation_events WHERE severity='p2')::bigint,
    (SELECT COUNT(*) FROM hospital_escalation_events WHERE severity='p3')::bigint,
    (SELECT COUNT(*) FROM hospital_escalation_events WHERE opened_at >= now() - interval '7 days')::bigint,
    (SELECT COUNT(*) FROM hospital_escalation_events WHERE opened_at >= now() - interval '30 days')::bigint,
    (SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 3600.0), 0)::numeric FROM hospital_escalation_events WHERE resolved_at IS NOT NULL),
    (SELECT COUNT(*) FROM founder_escalation_action_queue WHERE state='pending')::bigint,
    (SELECT COUNT(*) FROM founder_escalation_action_queue WHERE state IN ('pending','in_progress') AND due_at IS NOT NULL AND due_at < now())::bigint,
    (SELECT COUNT(DISTINCT hospital_org_id) FROM hospital_escalation_events)::bigint;
END;
$$;

-- 7) Top dominant-cluster x hospital pairs (heatmap)
CREATE OR REPLACE FUNCTION public.rpc_founder_esc_cluster_hospital()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  root_cause_cluster text,
  cluster_count bigint,
  last_at timestamptz
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
    o.id,
    o.name,
    e.root_cause_cluster,
    COUNT(*)::bigint AS cluster_count,
    MAX(e.opened_at) AS last_at
  FROM hospital_escalation_events e
  JOIN organizations o ON o.id = e.hospital_org_id
  WHERE e.opened_at >= now() - interval '180 days'
  GROUP BY o.id, o.name, e.root_cause_cluster
  HAVING COUNT(*) >= 2
  ORDER BY cluster_count DESC, last_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- WRITE / LOG RPCs (VOLATILE SECDEF, founder-gated)
-- ============================================================================

-- log helper 1: log queue creation
CREATE OR REPLACE FUNCTION public.log_founder_esc_queue_create(
  p_hospital_org_id uuid,
  p_escalation_event_id uuid,
  p_action_type text,
  p_priority text,
  p_action_note text,
  p_due_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_escalation_action_queue(
    hospital_org_id, escalation_event_id, action_type, priority,
    action_note, due_at, created_by_user_id
  ) VALUES (
    p_hospital_org_id, p_escalation_event_id, p_action_type, COALESCE(p_priority,'p2'),
    p_action_note, p_due_at, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'esc_queue_create',
    jsonb_build_object('queue_id', v_id, 'hospital_org_id', p_hospital_org_id, 'action_type', p_action_type, 'priority', p_priority)
  );
  RETURN v_id;
END;
$$;

-- log helper 2: mark queue done
CREATE OR REPLACE FUNCTION public.log_founder_esc_queue_done(
  p_queue_id uuid,
  p_done_note text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_escalation_action_queue
    SET state='done', done_at=now(), done_note=p_done_note, updated_at=now()
  WHERE id = p_queue_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'esc_queue_done',
    jsonb_build_object('queue_id', p_queue_id, 'done_note', p_done_note)
  );
END;
$$;

-- log helper 3: log escalation event
CREATE OR REPLACE FUNCTION public.log_founder_esc_event_create(
  p_hospital_org_id uuid,
  p_source_type text,
  p_severity text,
  p_root_cause_cluster text,
  p_summary text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_escalation_events(
    hospital_org_id, source_type, severity, root_cause_cluster, summary, created_by_user_id
  ) VALUES (
    p_hospital_org_id, p_source_type, COALESCE(p_severity,'p2'),
    COALESCE(p_root_cause_cluster,'unknown'), p_summary, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'esc_event_create',
    jsonb_build_object('event_id', v_id, 'hospital_org_id', p_hospital_org_id, 'severity', p_severity, 'cluster', p_root_cause_cluster)
  );
  RETURN v_id;
END;
$$;

-- log helper 4: resolve escalation event
CREATE OR REPLACE FUNCTION public.log_founder_esc_event_resolve(
  p_event_id uuid,
  p_resolution_note text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_escalation_events
    SET resolved_at = now(), resolution_note = p_resolution_note, resolved_by_user_id = auth.uid()
  WHERE id = p_event_id AND resolved_at IS NULL;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'esc_event_resolve',
    jsonb_build_object('event_id', p_event_id, 'resolution_note', p_resolution_note)
  );
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_summary() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_history() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_clusters() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_repeat() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_esc_action_queue() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_esc_kpi_digest() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.rpc_founder_esc_cluster_hospital() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_esc_queue_create(uuid,uuid,text,text,text,timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_esc_queue_done(uuid,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_esc_event_create(uuid,text,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_esc_event_resolve(uuid,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_history() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_clusters() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_founder_hospital_esc_repeat() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_founder_esc_action_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_founder_esc_kpi_digest() TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_founder_esc_cluster_hospital() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_esc_queue_create(uuid,uuid,text,text,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_esc_queue_done(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_esc_event_create(uuid,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_esc_event_resolve(uuid,text) TO authenticated;

COMMIT;