-- Round 2558: engineer-incident-near-miss-learning
-- Incident × near-miss × root cause × shared lessons × incorporated into runbook × follow-up audit

BEGIN;

-- ============================================================================
-- TABLE 1: engineer_near_misses_r2558
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.engineer_near_misses_r2558 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  incident_at timestamptz NOT NULL DEFAULT now(),
  near_miss_kind text NOT NULL CHECK (near_miss_kind IN ('slip','equipment_failure','safety_lapse','communication_breakdown','data_breach')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  root_cause_md text,
  shared_lessons_md text,
  incorporated_into_runbook boolean NOT NULL DEFAULT false,
  follow_up_audit_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','under_review','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_near_misses_r2558 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.engineer_near_misses_r2558;
CREATE POLICY founder_all ON public.engineer_near_misses_r2558
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: near_miss_runbook_updates_r2558
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.near_miss_runbook_updates_r2558 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  near_miss_id uuid REFERENCES public.engineer_near_misses_r2558(id) ON DELETE CASCADE,
  update_kind text NOT NULL CHECK (update_kind IN ('sop_change','training','equipment_check','policy_change','escalation_protocol')),
  update_summary_md text,
  owner_email text,
  target_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.near_miss_runbook_updates_r2558 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.near_miss_runbook_updates_r2558;
CREATE POLICY founder_all ON public.near_miss_runbook_updates_r2558
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_engineer uuid;
  v_nm1 uuid;
  v_nm2 uuid;
  v_nm3 uuid;
  v_nm4 uuid;
BEGIN
  SELECT id INTO v_engineer FROM public.engineers LIMIT 1;

  INSERT INTO public.engineer_near_misses_r2558
    (engineer_user_id, incident_at, near_miss_kind, severity, root_cause_md, shared_lessons_md, incorporated_into_runbook, follow_up_audit_at, owner_email, status, notes)
  VALUES (v_engineer, now() - interval '40 days', 'slip', 'medium', '# Slipped on wet floor in OT
- No wet-floor sign present
- Rushing to next ticket', '# Lesson
- Always place wet-floor sign before mopping
- Slow down between tickets', true, now() + interval '20 days', 'safety@equipseva.in', 'closed', 'No injury; runbook updated')
  RETURNING id INTO v_nm1;

  INSERT INTO public.engineer_near_misses_r2558
    (engineer_user_id, incident_at, near_miss_kind, severity, root_cause_md, shared_lessons_md, incorporated_into_runbook, follow_up_audit_at, owner_email, status, notes)
  VALUES (v_engineer, now() - interval '25 days', 'equipment_failure', 'high', '# Defib cap nearly came loose
- Inspection check skipped
- Cap thread worn', '# Lesson
- Mandatory pre-use thread inspection
- Replace caps every 90 days', true, now() + interval '30 days', 'qa@equipseva.in', 'closed', 'Cap replaced; SOP changed')
  RETURNING id INTO v_nm2;

  INSERT INTO public.engineer_near_misses_r2558
    (engineer_user_id, incident_at, near_miss_kind, severity, root_cause_md, shared_lessons_md, incorporated_into_runbook, follow_up_audit_at, owner_email, status, notes)
  VALUES (v_engineer, now() - interval '12 days', 'communication_breakdown', 'medium', '# Engineer escalated to wrong WhatsApp group
- Group naming ambiguous
- Time lost 22 min', '# Lesson
- Rename groups with city prefix
- Pin escalation matrix in each group', false, now() + interval '15 days', 'ops@equipseva.in', 'under_review', 'Renaming pending')
  RETURNING id INTO v_nm3;

  INSERT INTO public.engineer_near_misses_r2558
    (engineer_user_id, incident_at, near_miss_kind, severity, root_cause_md, shared_lessons_md, incorporated_into_runbook, follow_up_audit_at, owner_email, status, notes)
  VALUES (v_engineer, now() - interval '5 days', 'data_breach', 'critical', '# Photo of patient ID visible in ticket attachment
- Engineer did not crop
- Auto-blur not enabled in app', '# Lesson
- Enable auto-blur of patient ID region
- Mandatory crop step before upload', false, now() + interval '7 days', 'security@equipseva.in', 'open', 'DPDP risk; engineer coached')
  RETURNING id INTO v_nm4;

  INSERT INTO public.near_miss_runbook_updates_r2558 (near_miss_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
  VALUES (v_nm1, 'sop_change', '# Wet-floor sign mandatory
- SOP v3.2 published
- Trained all 42 engineers', 'safety@equipseva.in', now() - interval '30 days', 'done', 'Closed in weekly review');

  INSERT INTO public.near_miss_runbook_updates_r2558 (near_miss_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
  VALUES (v_nm2, 'equipment_check', '# Defib cap inspection
- Added to daily checklist
- 90-day replacement cycle', 'qa@equipseva.in', now() - interval '15 days', 'done', 'Tracker live in app');

  INSERT INTO public.near_miss_runbook_updates_r2558 (near_miss_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
  VALUES (v_nm3, 'escalation_protocol', '# WhatsApp group rename + pinned matrix
- City prefix
- Pin escalation matrix', 'ops@equipseva.in', now() + interval '5 days', 'open', 'Rollout in progress');

  INSERT INTO public.near_miss_runbook_updates_r2558 (near_miss_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
  VALUES (v_nm4, 'policy_change', '# Patient ID auto-blur
- App update v0.5.3
- Mandatory crop modal', 'security@equipseva.in', now() + interval '14 days', 'open', 'Eng ticket #2914');

  INSERT INTO public.near_miss_runbook_updates_r2558 (near_miss_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
  VALUES (v_nm4, 'training', '# DPDP refresher for all engineers
- 30-min module
- Quiz mandatory', 'training@equipseva.in', now() + interval '21 days', 'open', 'Scheduled for next Mon');
END
$seed$;

-- ============================================================================
-- RPC 1: list_near_misses_r2558
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_near_misses_r2558()
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  incident_at timestamptz,
  near_miss_kind text,
  severity text,
  root_cause_md text,
  shared_lessons_md text,
  incorporated_into_runbook boolean,
  follow_up_audit_at timestamptz,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.engineer_user_id, n.incident_at, n.near_miss_kind, n.severity,
         n.root_cause_md, n.shared_lessons_md, n.incorporated_into_runbook,
         n.follow_up_audit_at, n.owner_email, n.status, n.notes, n.created_at
  FROM public.engineer_near_misses_r2558 n
  ORDER BY n.incident_at DESC NULLS LAST
  LIMIT 200;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_near_misses_r2558() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_near_misses_r2558() TO authenticated;

-- ============================================================================
-- RPC 2: list_runbook_updates_r2558
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_runbook_updates_r2558()
RETURNS TABLE(
  id uuid,
  near_miss_id uuid,
  update_kind text,
  update_summary_md text,
  owner_email text,
  target_at timestamptz,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.near_miss_id, u.update_kind, u.update_summary_md,
         u.owner_email, u.target_at, u.status, u.notes, u.created_at
  FROM public.near_miss_runbook_updates_r2558 u
  ORDER BY u.created_at DESC NULLS LAST
  LIMIT 200;
END
$$;
REVOKE EXECUTE ON FUNCTION public.list_runbook_updates_r2558() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_runbook_updates_r2558() TO authenticated;

-- ============================================================================
-- RPC 3: top_severity_focus_r2558
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_severity_focus_r2558()
RETURNS TABLE(
  id uuid,
  incident_at timestamptz,
  near_miss_kind text,
  severity text,
  incorporated_into_runbook boolean,
  status text,
  owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.incident_at, n.near_miss_kind, n.severity,
         n.incorporated_into_runbook, n.status, n.owner_email
  FROM public.engineer_near_misses_r2558 n
  ORDER BY
    CASE n.severity
      WHEN 'critical' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END ASC,
    n.incident_at DESC NULLS LAST
  LIMIT 50;
END
$$;
REVOKE EXECUTE ON FUNCTION public.top_severity_focus_r2558() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_severity_focus_r2558() TO authenticated;

-- ============================================================================
-- RPC 4: root_cause_breakdown_r2558
-- ============================================================================
CREATE OR REPLACE FUNCTION public.root_cause_breakdown_r2558()
RETURNS TABLE(
  near_miss_kind text,
  incident_count bigint,
  critical_count bigint,
  high_count bigint,
  incorporated_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.near_miss_kind,
         count(*)::bigint AS incident_count,
         count(*) FILTER (WHERE n.severity = 'critical')::bigint AS critical_count,
         count(*) FILTER (WHERE n.severity = 'high')::bigint AS high_count,
         count(*) FILTER (WHERE n.incorporated_into_runbook = true)::bigint AS incorporated_count
  FROM public.engineer_near_misses_r2558 n
  GROUP BY n.near_miss_kind
  ORDER BY incident_count DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.root_cause_breakdown_r2558() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_cause_breakdown_r2558() TO authenticated;

-- ============================================================================
-- RPC 5: runbook_incorporation_rate_r2558
-- ============================================================================
CREATE OR REPLACE FUNCTION public.runbook_incorporation_rate_r2558()
RETURNS TABLE(
  total_incidents bigint,
  incorporated_count bigint,
  not_incorporated_count bigint,
  incorporation_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT count(*)::bigint AS total_incidents,
         count(*) FILTER (WHERE n.incorporated_into_runbook = true)::bigint AS incorporated_count,
         count(*) FILTER (WHERE n.incorporated_into_runbook = false)::bigint AS not_incorporated_count,
         CASE WHEN count(*) > 0
              THEN round(100.0 * count(*) FILTER (WHERE n.incorporated_into_runbook = true) / count(*), 2)
              ELSE 0 END AS incorporation_rate_pct
  FROM public.engineer_near_misses_r2558 n;
END
$$;
REVOKE EXECUTE ON FUNCTION public.runbook_incorporation_rate_r2558() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.runbook_incorporation_rate_r2558() TO authenticated;

-- ============================================================================
-- RPC 6: monthly_near_miss_trend_r2558
-- ============================================================================
CREATE OR REPLACE FUNCTION public.monthly_near_miss_trend_r2558()
RETURNS TABLE(
  month_label text,
  incident_count bigint,
  critical_count bigint,
  high_count bigint,
  incorporated_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', n.incident_at), 'YYYY-MM') AS month_label,
         count(*)::bigint AS incident_count,
         count(*) FILTER (WHERE n.severity = 'critical')::bigint AS critical_count,
         count(*) FILTER (WHERE n.severity = 'high')::bigint AS high_count,
         count(*) FILTER (WHERE n.incorporated_into_runbook = true)::bigint AS incorporated_count
  FROM public.engineer_near_misses_r2558 n
  GROUP BY date_trunc('month', n.incident_at)
  ORDER BY date_trunc('month', n.incident_at) ASC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_near_miss_trend_r2558() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_near_miss_trend_r2558() TO authenticated;

-- ============================================================================
-- RPC 7: owner_load_r2558
-- ============================================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2558()
RETURNS TABLE(
  owner_email text,
  open_updates bigint,
  done_updates bigint,
  dropped_updates bigint,
  total_updates bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(u.owner_email, '(unassigned)') AS owner_email,
         count(*) FILTER (WHERE u.status = 'open')::bigint AS open_updates,
         count(*) FILTER (WHERE u.status = 'done')::bigint AS done_updates,
         count(*) FILTER (WHERE u.status = 'dropped')::bigint AS dropped_updates,
         count(*)::bigint AS total_updates
  FROM public.near_miss_runbook_updates_r2558 u
  GROUP BY coalesce(u.owner_email, '(unassigned)')
  ORDER BY open_updates DESC NULLS LAST;
END
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2558() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2558() TO authenticated;

