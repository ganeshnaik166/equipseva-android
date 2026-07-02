BEGIN;
-- round1423 — Founder compliance audit vault
-- Combined audit trail + activity log + integrity ledger.
-- 2 tables (audit_events + integrity_violations) + 7 RPCs.
-- All read RPCs: plpgsql STABLE SECURITY DEFINER + is_founder() gate.
-- All write RPCs: plpgsql VOLATILE SECURITY DEFINER + is_founder() gate.



-- ============================================================
-- TABLE 1 · founder_compliance_audit_events
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_compliance_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_kind text NOT NULL CHECK (event_kind IN (
    'founder_action','engineer_status_change','hospital_data_export',
    'payment_anomaly','suspicious_login','rls_policy_change',
    'schema_migration','data_export','privacy_request','integrity_violation'
  )),
  severity text NOT NULL DEFAULT 'info' CHECK (severity IN (
    'info','low','medium','high','critical'
  )),
  source_table text,
  source_record_id uuid,
  performed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ip_hash text,
  user_agent_hash text,
  before_value jsonb,
  after_value jsonb,
  notes text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fc_audit_events_occurred
  ON public.founder_compliance_audit_events (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_fc_audit_events_kind_sev
  ON public.founder_compliance_audit_events (event_kind, severity);
CREATE INDEX IF NOT EXISTS idx_fc_audit_events_performed_by
  ON public.founder_compliance_audit_events (performed_by);
CREATE INDEX IF NOT EXISTS idx_fc_audit_events_source
  ON public.founder_compliance_audit_events (source_table, source_record_id);

ALTER TABLE public.founder_compliance_audit_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fc_audit_events_founder_read ON public.founder_compliance_audit_events;
CREATE POLICY p_fc_audit_events_founder_read
  ON public.founder_compliance_audit_events
  FOR SELECT TO authenticated
  USING (public.is_founder());

REVOKE ALL ON public.founder_compliance_audit_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.founder_compliance_audit_events TO authenticated;

-- ============================================================
-- TABLE 2 · founder_compliance_integrity_violations
-- ============================================================
CREATE TABLE IF NOT EXISTS public.founder_compliance_integrity_violations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_event_id uuid NOT NULL REFERENCES public.founder_compliance_audit_events(id) ON DELETE CASCADE,
  violation_kind text NOT NULL CHECK (violation_kind IN (
    'rls_bypass','privilege_escalation','suspicious_pattern',
    'data_exfil','unsigned_change','timing_anomaly','rate_limit_breach'
  )),
  status text NOT NULL DEFAULT 'detected' CHECK (status IN (
    'detected','investigating','contained','resolved','false_positive'
  )),
  assigned_to uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fc_violations_status
  ON public.founder_compliance_integrity_violations (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fc_violations_kind
  ON public.founder_compliance_integrity_violations (violation_kind);
CREATE INDEX IF NOT EXISTS idx_fc_violations_event
  ON public.founder_compliance_integrity_violations (audit_event_id);

ALTER TABLE public.founder_compliance_integrity_violations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fc_violations_founder_read ON public.founder_compliance_integrity_violations;
CREATE POLICY p_fc_violations_founder_read
  ON public.founder_compliance_integrity_violations
  FOR SELECT TO authenticated
  USING (public.is_founder());

REVOKE ALL ON public.founder_compliance_integrity_violations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.founder_compliance_integrity_violations TO authenticated;

-- ============================================================
-- RPC 1 · founder_compliance_audit_vault_summary (16 KPIs)
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_compliance_audit_vault_summary();
CREATE OR REPLACE FUNCTION public.founder_compliance_audit_vault_summary()
RETURNS TABLE (
  total_events bigint,
  events_24h bigint,
  events_7d bigint,
  events_30d bigint,
  critical_count bigint,
  high_count bigint,
  medium_count bigint,
  by_kind_founder_action bigint,
  by_kind_payment_anomaly bigint,
  by_kind_suspicious_login bigint,
  by_kind_integrity_violation bigint,
  total_violations bigint,
  open_violations bigint,
  resolved_violations bigint,
  false_positive_violations bigint,
  oldest_open_violation_age_days int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_compliance_audit_events)::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE occurred_at > now() - interval '24 hours')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE occurred_at > now() - interval '7 days')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE occurred_at > now() - interval '30 days')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE severity = 'critical')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE severity = 'high')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE severity = 'medium')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE event_kind = 'founder_action')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE event_kind = 'payment_anomaly')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE event_kind = 'suspicious_login')::bigint,
    (SELECT count(*) FROM public.founder_compliance_audit_events
       WHERE event_kind = 'integrity_violation')::bigint,
    (SELECT count(*) FROM public.founder_compliance_integrity_violations)::bigint,
    (SELECT count(*) FROM public.founder_compliance_integrity_violations
       WHERE status IN ('detected','investigating','contained'))::bigint,
    (SELECT count(*) FROM public.founder_compliance_integrity_violations
       WHERE status = 'resolved')::bigint,
    (SELECT count(*) FROM public.founder_compliance_integrity_violations
       WHERE status = 'false_positive')::bigint,
    (SELECT EXTRACT(day FROM (now() - min(created_at)))::int
       FROM public.founder_compliance_integrity_violations
       WHERE status IN ('detected','investigating','contained'));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_compliance_audit_vault_summary() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_compliance_audit_vault_summary() TO authenticated;

-- ============================================================
-- RPC 2 · founder_compliance_audit_events_recent
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_compliance_audit_events_recent(text, text, int);
CREATE OR REPLACE FUNCTION public.founder_compliance_audit_events_recent(
  p_kind text DEFAULT NULL,
  p_severity text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  event_kind text,
  severity text,
  source_table text,
  source_record_id uuid,
  performed_by uuid,
  ip_hash text,
  user_agent_hash text,
  notes text,
  occurred_at timestamptz,
  age_seconds bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.event_kind,
    e.severity,
    e.source_table,
    e.source_record_id,
    e.performed_by,
    e.ip_hash,
    e.user_agent_hash,
    e.notes,
    e.occurred_at,
    EXTRACT(epoch FROM (now() - e.occurred_at))::bigint AS age_seconds
  FROM public.founder_compliance_audit_events e
  WHERE (p_kind IS NULL OR e.event_kind = p_kind)
    AND (p_severity IS NULL OR e.severity = p_severity)
  ORDER BY e.occurred_at DESC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 100), 500));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_compliance_audit_events_recent(text, text, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_compliance_audit_events_recent(text, text, int) TO authenticated;

-- ============================================================
-- RPC 3 · founder_compliance_integrity_violations_recent
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_compliance_integrity_violations_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_compliance_integrity_violations_recent(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  audit_event_id uuid,
  violation_kind text,
  status text,
  assigned_to uuid,
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz,
  age_days int,
  event_kind text,
  event_severity text,
  event_notes text,
  event_occurred_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    v.id,
    v.audit_event_id,
    v.violation_kind,
    v.status,
    v.assigned_to,
    v.resolved_at,
    v.resolution_note,
    v.created_at,
    EXTRACT(day FROM (now() - v.created_at))::int AS age_days,
    e.event_kind,
    e.severity,
    e.notes,
    e.occurred_at
  FROM public.founder_compliance_integrity_violations v
  LEFT JOIN public.founder_compliance_audit_events e ON e.id = v.audit_event_id
  WHERE (p_status IS NULL OR v.status = p_status)
  ORDER BY v.created_at DESC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 100), 500));
END;
$$;

REVOKE ALL ON FUNCTION public.founder_compliance_integrity_violations_recent(text, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_compliance_integrity_violations_recent(text, int) TO authenticated;

-- ============================================================
-- RPC 4 · founder_compliance_open_violations
-- ============================================================
DROP FUNCTION IF EXISTS public.founder_compliance_open_violations();
CREATE OR REPLACE FUNCTION public.founder_compliance_open_violations()
RETURNS TABLE (
  id uuid,
  audit_event_id uuid,
  violation_kind text,
  status text,
  created_at timestamptz,
  age_days int,
  event_kind text,
  event_severity text,
  event_notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    v.id,
    v.audit_event_id,
    v.violation_kind,
    v.status,
    v.created_at,
    EXTRACT(day FROM (now() - v.created_at))::int AS age_days,
    e.event_kind,
    e.severity,
    e.notes
  FROM public.founder_compliance_integrity_violations v
  LEFT JOIN public.founder_compliance_audit_events e ON e.id = v.audit_event_id
  WHERE v.status IN ('detected','investigating','contained')
  ORDER BY
    CASE e.severity
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END,
    v.created_at ASC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_compliance_open_violations() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.founder_compliance_open_violations() TO authenticated;

-- ============================================================
-- RPC 5 · log_founder_audit_record_event (write)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_audit_record_event(text, text, text, uuid, text, text, jsonb, jsonb, text);
CREATE OR REPLACE FUNCTION public.log_founder_audit_record_event(
  p_event_kind text,
  p_severity text DEFAULT 'info',
  p_source_table text DEFAULT NULL,
  p_source_record_id uuid DEFAULT NULL,
  p_ip_hash text DEFAULT NULL,
  p_user_agent_hash text DEFAULT NULL,
  p_before_value jsonb DEFAULT NULL,
  p_after_value jsonb DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  INSERT INTO public.founder_compliance_audit_events (
    event_kind, severity, source_table, source_record_id,
    performed_by, ip_hash, user_agent_hash,
    before_value, after_value, notes
  ) VALUES (
    p_event_kind,
    coalesce(p_severity, 'info'),
    p_source_table,
    p_source_record_id,
    auth.uid(),
    p_ip_hash,
    p_user_agent_hash,
    p_before_value,
    p_after_value,
    p_notes
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_audit_record_event(text, text, text, uuid, text, text, jsonb, jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_audit_record_event(text, text, text, uuid, text, text, jsonb, jsonb, text) TO authenticated;

-- ============================================================
-- RPC 6 · log_founder_audit_record_violation (write)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_audit_record_violation(uuid, text, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_audit_record_violation(
  p_audit_event_id uuid,
  p_violation_kind text,
  p_assigned_to uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF p_audit_event_id IS NULL THEN
    RAISE EXCEPTION 'audit_event_id required' USING ERRCODE='22023';
  END IF;

  INSERT INTO public.founder_compliance_integrity_violations (
    audit_event_id, violation_kind, status, assigned_to
  ) VALUES (
    p_audit_event_id, p_violation_kind, 'detected', p_assigned_to
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_audit_record_violation(uuid, text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_audit_record_violation(uuid, text, uuid) TO authenticated;

-- ============================================================
-- RPC 7 · log_founder_audit_resolve_violation (write)
-- ============================================================
DROP FUNCTION IF EXISTS public.log_founder_audit_resolve_violation(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_audit_resolve_violation(
  p_violation_id uuid,
  p_status text,
  p_resolution_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  IF p_status NOT IN ('investigating','contained','resolved','false_positive') THEN
    RAISE EXCEPTION 'bad status %', p_status USING ERRCODE='22023';
  END IF;

  UPDATE public.founder_compliance_integrity_violations
     SET status = p_status,
         resolution_note = coalesce(p_resolution_note, resolution_note),
         resolved_at = CASE
           WHEN p_status IN ('resolved','false_positive') THEN now()
           ELSE resolved_at
         END
   WHERE id = p_violation_id;

  RETURN p_violation_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_founder_audit_resolve_violation(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_audit_resolve_violation(uuid, text, text) TO authenticated;

COMMIT;