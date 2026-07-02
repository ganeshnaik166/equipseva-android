BEGIN;

-- =====================================================================
-- r1489 — Hospital VIP escalation routing
-- Tier-A hospitals get dedicated founder/CTO escalation paths.
-- Track each escalation, SLA response, resolution, satisfaction.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.hospital_vip_escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  vip_tier text NOT NULL CHECK (vip_tier IN ('tier_a','tier_a_plus','strategic')),
  routed_to text NOT NULL CHECK (routed_to IN ('founder','cto','vp_ops','head_clinical')),
  category text NOT NULL CHECK (category IN ('downtime','billing','engineer','parts','amc','compliance','other')),
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  title text NOT NULL,
  details text,
  related_repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  related_amc_contract_id uuid REFERENCES public.amc_contracts(id) ON DELETE SET NULL,
  opened_at timestamptz NOT NULL DEFAULT now(),
  first_response_at timestamptz,
  resolved_at timestamptz,
  sla_response_minutes int NOT NULL DEFAULT 30,
  sla_resolution_hours int NOT NULL DEFAULT 24,
  satisfaction_score int CHECK (satisfaction_score BETWEEN 1 AND 5),
  satisfaction_comment text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','acknowledged','in_progress','resolved','escalated_again','dropped')),
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hve_org ON public.hospital_vip_escalations(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hve_status ON public.hospital_vip_escalations(status);
CREATE INDEX IF NOT EXISTS idx_hve_opened ON public.hospital_vip_escalations(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_hve_severity ON public.hospital_vip_escalations(severity);

ALTER TABLE public.hospital_vip_escalations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hve_founder_all ON public.hospital_vip_escalations;
CREATE POLICY hve_founder_all ON public.hospital_vip_escalations
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_vip_escalation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escalation_id uuid NOT NULL REFERENCES public.hospital_vip_escalations(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('opened','acknowledged','responded','reassigned','resolved','reopened','satisfaction_recorded','note')),
  actor uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hve_events_esc ON public.hospital_vip_escalation_events(escalation_id);
CREATE INDEX IF NOT EXISTS idx_hve_events_created ON public.hospital_vip_escalation_events(created_at DESC);

ALTER TABLE public.hospital_vip_escalation_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hve_events_founder_all ON public.hospital_vip_escalation_events;
CREATE POLICY hve_events_founder_all ON public.hospital_vip_escalation_events
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

DROP FUNCTION IF EXISTS public.founder_vip_escalation_overview();
CREATE OR REPLACE FUNCTION public.founder_vip_escalation_overview()
RETURNS TABLE (
  total_escalations bigint,
  open_escalations bigint,
  resolved_escalations bigint,
  p0_open bigint,
  p1_open bigint,
  avg_response_minutes numeric,
  avg_resolution_hours numeric,
  sla_response_breaches bigint,
  sla_resolution_breaches bigint,
  avg_satisfaction numeric,
  satisfaction_responses bigint,
  routed_founder bigint,
  routed_cto bigint,
  tier_a_plus_count bigint,
  strategic_count bigint,
  last_7d_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE status IN ('open','acknowledged','in_progress'))::bigint,
    count(*) FILTER (WHERE status='resolved')::bigint,
    count(*) FILTER (WHERE severity='p0' AND status <> 'resolved')::bigint,
    count(*) FILTER (WHERE severity='p1' AND status <> 'resolved')::bigint,
    avg(extract(epoch FROM (first_response_at - opened_at))/60.0) FILTER (WHERE first_response_at IS NOT NULL),
    avg(extract(epoch FROM (resolved_at - opened_at))/3600.0) FILTER (WHERE resolved_at IS NOT NULL),
    count(*) FILTER (WHERE first_response_at IS NOT NULL AND extract(epoch FROM (first_response_at - opened_at))/60.0 > sla_response_minutes)::bigint,
    count(*) FILTER (WHERE resolved_at IS NOT NULL AND extract(epoch FROM (resolved_at - opened_at))/3600.0 > sla_resolution_hours)::bigint,
    avg(satisfaction_score::numeric) FILTER (WHERE satisfaction_score IS NOT NULL),
    count(*) FILTER (WHERE satisfaction_score IS NOT NULL)::bigint,
    count(*) FILTER (WHERE routed_to='founder')::bigint,
    count(*) FILTER (WHERE routed_to='cto')::bigint,
    count(*) FILTER (WHERE vip_tier='tier_a_plus')::bigint,
    count(*) FILTER (WHERE vip_tier='strategic')::bigint,
    count(*) FILTER (WHERE opened_at > now() - interval '7 days')::bigint
  FROM hospital_vip_escalations;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_escalation_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_escalation_overview() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_vip_escalation_list(int);
CREATE OR REPLACE FUNCTION public.founder_vip_escalation_list(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  vip_tier text,
  routed_to text,
  category text,
  severity text,
  title text,
  status text,
  opened_at timestamptz,
  first_response_at timestamptz,
  resolved_at timestamptz,
  response_minutes numeric,
  resolution_hours numeric,
  satisfaction_score int,
  sla_response_minutes int,
  sla_resolution_hours int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id, e.hospital_org_id, o.name,
    e.vip_tier, e.routed_to, e.category, e.severity, e.title, e.status,
    e.opened_at, e.first_response_at, e.resolved_at,
    CASE WHEN e.first_response_at IS NOT NULL THEN round((extract(epoch FROM (e.first_response_at - e.opened_at))/60.0)::numeric, 1) END,
    CASE WHEN e.resolved_at IS NOT NULL THEN round((extract(epoch FROM (e.resolved_at - e.opened_at))/3600.0)::numeric, 2) END,
    e.satisfaction_score,
    e.sla_response_minutes,
    e.sla_resolution_hours
  FROM hospital_vip_escalations e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  ORDER BY e.opened_at DESC
  LIMIT p_limit;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_escalation_list(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_escalation_list(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_vip_escalation_by_hospital();
CREATE OR REPLACE FUNCTION public.founder_vip_escalation_by_hospital()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  total_escalations bigint,
  open_count bigint,
  resolved_count bigint,
  avg_response_minutes numeric,
  avg_resolution_hours numeric,
  avg_satisfaction numeric,
  last_escalation_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.hospital_org_id,
    o.name,
    count(*)::bigint,
    count(*) FILTER (WHERE e.status IN ('open','acknowledged','in_progress'))::bigint,
    count(*) FILTER (WHERE e.status='resolved')::bigint,
    round((avg(extract(epoch FROM (e.first_response_at - e.opened_at))/60.0) FILTER (WHERE e.first_response_at IS NOT NULL))::numeric, 1),
    round((avg(extract(epoch FROM (e.resolved_at - e.opened_at))/3600.0) FILTER (WHERE e.resolved_at IS NOT NULL))::numeric, 2),
    round((avg(e.satisfaction_score::numeric) FILTER (WHERE e.satisfaction_score IS NOT NULL))::numeric, 2),
    max(e.opened_at)
  FROM hospital_vip_escalations e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  GROUP BY e.hospital_org_id, o.name
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_escalation_by_hospital() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_escalation_by_hospital() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_vip_escalation_sla_breaches();
CREATE OR REPLACE FUNCTION public.founder_vip_escalation_sla_breaches()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  title text,
  severity text,
  breach_type text,
  minutes_over numeric,
  opened_at timestamptz,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    o.name,
    e.title,
    e.severity,
    CASE
      WHEN e.first_response_at IS NULL AND extract(epoch FROM (now() - e.opened_at))/60.0 > e.sla_response_minutes THEN 'response_overdue'
      WHEN e.first_response_at IS NOT NULL AND extract(epoch FROM (e.first_response_at - e.opened_at))/60.0 > e.sla_response_minutes THEN 'response_breached'
      WHEN e.resolved_at IS NULL AND extract(epoch FROM (now() - e.opened_at))/3600.0 > e.sla_resolution_hours THEN 'resolution_overdue'
      WHEN e.resolved_at IS NOT NULL AND extract(epoch FROM (e.resolved_at - e.opened_at))/3600.0 > e.sla_resolution_hours THEN 'resolution_breached'
      ELSE 'unknown'
    END,
    GREATEST(
      COALESCE(extract(epoch FROM (COALESCE(e.first_response_at, now()) - e.opened_at))/60.0 - e.sla_response_minutes, 0),
      COALESCE((extract(epoch FROM (COALESCE(e.resolved_at, now()) - e.opened_at))/3600.0 - e.sla_resolution_hours) * 60, 0)
    )::numeric,
    e.opened_at,
    e.status
  FROM hospital_vip_escalations e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  WHERE
    (e.first_response_at IS NULL AND extract(epoch FROM (now() - e.opened_at))/60.0 > e.sla_response_minutes)
    OR (e.first_response_at IS NOT NULL AND extract(epoch FROM (e.first_response_at - e.opened_at))/60.0 > e.sla_response_minutes)
    OR (e.resolved_at IS NULL AND extract(epoch FROM (now() - e.opened_at))/3600.0 > e.sla_resolution_hours)
    OR (e.resolved_at IS NOT NULL AND extract(epoch FROM (e.resolved_at - e.opened_at))/3600.0 > e.sla_resolution_hours)
  ORDER BY e.opened_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_escalation_sla_breaches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_escalation_sla_breaches() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_vip_escalation_by_category();
CREATE OR REPLACE FUNCTION public.founder_vip_escalation_by_category()
RETURNS TABLE (
  category text,
  total bigint,
  open_count bigint,
  avg_response_minutes numeric,
  avg_resolution_hours numeric,
  avg_satisfaction numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.category,
    count(*)::bigint,
    count(*) FILTER (WHERE e.status IN ('open','acknowledged','in_progress'))::bigint,
    round((avg(extract(epoch FROM (e.first_response_at - e.opened_at))/60.0) FILTER (WHERE e.first_response_at IS NOT NULL))::numeric, 1),
    round((avg(extract(epoch FROM (e.resolved_at - e.opened_at))/3600.0) FILTER (WHERE e.resolved_at IS NOT NULL))::numeric, 2),
    round((avg(e.satisfaction_score::numeric) FILTER (WHERE e.satisfaction_score IS NOT NULL))::numeric, 2)
  FROM hospital_vip_escalations e
  GROUP BY e.category
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_escalation_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_escalation_by_category() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_vip_escalation_recent_events(int);
CREATE OR REPLACE FUNCTION public.founder_vip_escalation_recent_events(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  escalation_id uuid,
  hospital_name text,
  title text,
  event_type text,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    ev.id, ev.escalation_id, o.name, e.title,
    ev.event_type, ev.note, ev.created_at
  FROM hospital_vip_escalation_events ev
  JOIN hospital_vip_escalations e ON e.id = ev.escalation_id
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  ORDER BY ev.created_at DESC
  LIMIT p_limit;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_escalation_recent_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_escalation_recent_events(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_vip_escalation_routing_perf();
CREATE OR REPLACE FUNCTION public.founder_vip_escalation_routing_perf()
RETURNS TABLE (
  routed_to text,
  total bigint,
  resolved bigint,
  avg_response_minutes numeric,
  avg_resolution_hours numeric,
  avg_satisfaction numeric,
  sla_response_breaches bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.routed_to,
    count(*)::bigint,
    count(*) FILTER (WHERE e.status='resolved')::bigint,
    round((avg(extract(epoch FROM (e.first_response_at - e.opened_at))/60.0) FILTER (WHERE e.first_response_at IS NOT NULL))::numeric, 1),
    round((avg(extract(epoch FROM (e.resolved_at - e.opened_at))/3600.0) FILTER (WHERE e.resolved_at IS NOT NULL))::numeric, 2),
    round((avg(e.satisfaction_score::numeric) FILTER (WHERE e.satisfaction_score IS NOT NULL))::numeric, 2),
    count(*) FILTER (WHERE e.first_response_at IS NOT NULL AND extract(epoch FROM (e.first_response_at - e.opened_at))/60.0 > e.sla_response_minutes)::bigint
  FROM hospital_vip_escalations e
  GROUP BY e.routed_to
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_escalation_routing_perf() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_escalation_routing_perf() TO authenticated;

-- =====================================================================
-- WRITE-LAYER log_founder_* helpers (VOLATILE)
-- =====================================================================

DROP FUNCTION IF EXISTS public.log_founder_vip_escalation_open(uuid, text, text, text, text, text, text, int, int);
CREATE OR REPLACE FUNCTION public.log_founder_vip_escalation_open(
  p_hospital_org_id uuid,
  p_vip_tier text,
  p_routed_to text,
  p_category text,
  p_severity text,
  p_title text,
  p_details text DEFAULT NULL,
  p_sla_response_minutes int DEFAULT 30,
  p_sla_resolution_hours int DEFAULT 24
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_vip_escalations(hospital_org_id, vip_tier, routed_to, category, severity, title, details, sla_response_minutes, sla_resolution_hours, created_by)
  VALUES (p_hospital_org_id, p_vip_tier, p_routed_to, p_category, p_severity, p_title, p_details, p_sla_response_minutes, p_sla_resolution_hours, auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO hospital_vip_escalation_events(escalation_id, event_type, actor, note)
  VALUES (v_id, 'opened', auth.uid(), p_title);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_escalation_open(uuid, text, text, text, text, text, text, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_escalation_open(uuid, text, text, text, text, text, text, int, int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_vip_escalation_respond(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_vip_escalation_respond(
  p_id uuid,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_vip_escalations
  SET first_response_at = COALESCE(first_response_at, now()),
      status = CASE WHEN status='open' THEN 'acknowledged' ELSE status END,
      updated_at = now()
  WHERE id = p_id;
  INSERT INTO hospital_vip_escalation_events(escalation_id, event_type, actor, note)
  VALUES (p_id, 'responded', auth.uid(), p_note);
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_escalation_respond(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_escalation_respond(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_vip_escalation_resolve(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_vip_escalation_resolve(
  p_id uuid,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_vip_escalations
  SET resolved_at = now(),
      status = 'resolved',
      first_response_at = COALESCE(first_response_at, now()),
      updated_at = now()
  WHERE id = p_id;
  INSERT INTO hospital_vip_escalation_events(escalation_id, event_type, actor, note)
  VALUES (p_id, 'resolved', auth.uid(), p_note);
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_escalation_resolve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_escalation_resolve(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_vip_escalation_satisfaction(uuid, int, text);
CREATE OR REPLACE FUNCTION public.log_founder_vip_escalation_satisfaction(
  p_id uuid,
  p_score int,
  p_comment text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_score < 1 OR p_score > 5 THEN RAISE EXCEPTION 'score must be 1..5'; END IF;
  UPDATE hospital_vip_escalations
  SET satisfaction_score = p_score,
      satisfaction_comment = p_comment,
      updated_at = now()
  WHERE id = p_id;
  INSERT INTO hospital_vip_escalation_events(escalation_id, event_type, actor, note)
  VALUES (p_id, 'satisfaction_recorded', auth.uid(), 'score=' || p_score);
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_escalation_satisfaction(uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_escalation_satisfaction(uuid, int, text) TO authenticated;

COMMIT;