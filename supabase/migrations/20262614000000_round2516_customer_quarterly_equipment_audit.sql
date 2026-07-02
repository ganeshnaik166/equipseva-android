-- Round r2516: customer-quarterly-equipment-audit
-- Hospital quarterly equipment audit tracker with NABH alignment and corrective actions

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.customer_quarterly_audits_r2516 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  audit_started_at timestamptz,
  audit_completed_at timestamptz,
  total_equipment_audited int NOT NULL DEFAULT 0,
  findings_count int NOT NULL DEFAULT 0,
  compliance_score int NOT NULL DEFAULT 0 CHECK (compliance_score BETWEEN 0 AND 100),
  nabh_alignment text NOT NULL CHECK (nabh_alignment IN ('aligned','partial','not_aligned')),
  owner_email text,
  status text NOT NULL CHECK (status IN ('scheduled','in_progress','completed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_corrective_actions_r2516 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.customer_quarterly_audits_r2516(id) ON DELETE CASCADE,
  finding_kind text NOT NULL CHECK (finding_kind IN ('calibration_gap','safety_violation','maintenance_overdue','documentation_missing','training_gap')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  action_md text,
  owner_email text,
  due_at timestamptz,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============================================================================
-- RLS
-- ============================================================================

ALTER TABLE public.customer_quarterly_audits_r2516 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_corrective_actions_r2516 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_quarterly_audits_r2516;
CREATE POLICY founder_all ON public.customer_quarterly_audits_r2516
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.audit_corrective_actions_r2516;
CREATE POLICY founder_all ON public.audit_corrective_actions_r2516
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================

DO $seed$
DECLARE
  v_hospital_a uuid;
  v_hospital_b uuid;
  v_hospital_c uuid;
  v_audit1 uuid;
  v_audit2 uuid;
  v_audit3 uuid;
  v_audit4 uuid;
BEGIN
  SELECT id INTO v_hospital_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hospital_b FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_hospital_a, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hospital_c FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_hospital_a, '00000000-0000-0000-0000-000000000000'::uuid) AND id <> COALESCE(v_hospital_b, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;

  INSERT INTO public.customer_quarterly_audits_r2516(hospital_user_id, quarter_label, audit_started_at, audit_completed_at, total_equipment_audited, findings_count, compliance_score, nabh_alignment, owner_email, status, notes)
  VALUES (v_hospital_a, 'Q1-2026', '2026-01-12 09:00:00'::timestamptz, '2026-01-14 17:00:00'::timestamptz, 48, 7, 82, 'partial', 'audit-lead@equipseva.in', 'completed', 'Defibrillator calibration overdue · 3 of 7 OT lights flicker')
  RETURNING id INTO v_audit1;

  INSERT INTO public.customer_quarterly_audits_r2516(hospital_user_id, quarter_label, audit_started_at, audit_completed_at, total_equipment_audited, findings_count, compliance_score, nabh_alignment, owner_email, status, notes)
  VALUES (v_hospital_b, 'Q1-2026', '2026-02-03 10:00:00'::timestamptz, '2026-02-05 18:00:00'::timestamptz, 65, 12, 68, 'not_aligned', 'audit-lead@equipseva.in', 'completed', 'Major safety violations on 2 ventilators · NABH gap report sent')
  RETURNING id INTO v_audit2;

  INSERT INTO public.customer_quarterly_audits_r2516(hospital_user_id, quarter_label, audit_started_at, audit_completed_at, total_equipment_audited, findings_count, compliance_score, nabh_alignment, owner_email, status, notes)
  VALUES (v_hospital_c, 'Q2-2026', '2026-04-08 09:30:00'::timestamptz, '2026-04-09 16:00:00'::timestamptz, 32, 2, 94, 'aligned', 'audit-jr@equipseva.in', 'completed', 'Clean audit · Minor documentation refresh only')
  RETURNING id INTO v_audit3;

  INSERT INTO public.customer_quarterly_audits_r2516(hospital_user_id, quarter_label, audit_started_at, audit_completed_at, total_equipment_audited, findings_count, compliance_score, nabh_alignment, owner_email, status, notes)
  VALUES (v_hospital_a, 'Q2-2026', '2026-06-15 09:00:00'::timestamptz, NULL, 25, 0, 0, 'partial', 'audit-lead@equipseva.in', 'in_progress', 'Mid-audit · 25 of 50 walked')
  RETURNING id INTO v_audit4;

  -- Corrective actions for audit1
  INSERT INTO public.audit_corrective_actions_r2516(audit_id, finding_kind, severity, action_md, owner_email, due_at, status, closed_at, notes)
  VALUES (v_audit1, 'calibration_gap', 'high', 'Recalibrate Lifepak-20 defib (S/N LP20-4421) by certified vendor', 'biomed@hospital-a.in', '2026-02-15 18:00:00'::timestamptz, 'done', '2026-02-10 14:30:00'::timestamptz, 'Closed in 5 days');

  INSERT INTO public.audit_corrective_actions_r2516(audit_id, finding_kind, severity, action_md, owner_email, due_at, status, closed_at, notes)
  VALUES (v_audit1, 'maintenance_overdue', 'medium', 'Service 3 OT lights flickering at intensity step-3', 'biomed@hospital-a.in', '2026-02-28 18:00:00'::timestamptz, 'in_progress', NULL, 'Parts ordered');

  -- Corrective actions for audit2
  INSERT INTO public.audit_corrective_actions_r2516(audit_id, finding_kind, severity, action_md, owner_email, due_at, status, closed_at, notes)
  VALUES (v_audit2, 'safety_violation', 'critical', 'Pull 2 ventilators (Hamilton C1 #H-441 #H-447) out of clinical use until vendor inspection', 'admin@hospital-b.in', '2026-02-10 18:00:00'::timestamptz, 'done', '2026-02-06 09:00:00'::timestamptz, 'Same-day quarantine');

  INSERT INTO public.audit_corrective_actions_r2516(audit_id, finding_kind, severity, action_md, owner_email, due_at, status, closed_at, notes)
  VALUES (v_audit2, 'documentation_missing', 'high', 'Reconstruct service logbooks for ICU monitors (28 units)', 'admin@hospital-b.in', '2026-03-15 18:00:00'::timestamptz, 'open', NULL, 'Pending vendor history pull');

  INSERT INTO public.audit_corrective_actions_r2516(audit_id, finding_kind, severity, action_md, owner_email, due_at, status, closed_at, notes)
  VALUES (v_audit2, 'training_gap', 'medium', 'Schedule biomed refresher on infusion-pump alarms (5 staff)', 'admin@hospital-b.in', '2026-04-01 18:00:00'::timestamptz, 'in_progress', NULL, 'Trainer booked Apr-7');

  -- Corrective actions for audit3
  INSERT INTO public.audit_corrective_actions_r2516(audit_id, finding_kind, severity, action_md, owner_email, due_at, status, closed_at, notes)
  VALUES (v_audit3, 'documentation_missing', 'low', 'Update 4 calibration stickers (2024 -> 2026 dates)', 'biomed@hospital-c.in', '2026-05-01 18:00:00'::timestamptz, 'done', '2026-04-12 11:00:00'::timestamptz, 'Trivial fix');
END
$seed$;

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_audits_r2516()
RETURNS TABLE(
  id uuid,
  hospital_email text,
  quarter_label text,
  audit_started_at timestamptz,
  audit_completed_at timestamptz,
  total_equipment_audited int,
  findings_count int,
  compliance_score int,
  nabh_alignment text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, p.email, a.quarter_label, a.audit_started_at, a.audit_completed_at,
         a.total_equipment_audited, a.findings_count, a.compliance_score,
         a.nabh_alignment, a.owner_email, a.status, a.notes, a.created_at
  FROM public.customer_quarterly_audits_r2516 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  ORDER BY a.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_audits_r2516() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_audits_r2516() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_corrective_actions_r2516()
RETURNS TABLE(
  id uuid,
  audit_id uuid,
  quarter_label text,
  hospital_email text,
  finding_kind text,
  severity text,
  action_md text,
  owner_email text,
  due_at timestamptz,
  status text,
  closed_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ca.id, ca.audit_id, a.quarter_label, p.email,
         ca.finding_kind, ca.severity, ca.action_md, ca.owner_email,
         ca.due_at, ca.status, ca.closed_at, ca.notes, ca.created_at
  FROM public.audit_corrective_actions_r2516 ca
  JOIN public.customer_quarterly_audits_r2516 a ON a.id = ca.audit_id
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  ORDER BY ca.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_corrective_actions_r2516() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_corrective_actions_r2516() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_non_compliant_hospitals_r2516()
RETURNS TABLE(
  hospital_email text,
  audits_count bigint,
  avg_compliance_score numeric,
  total_findings bigint,
  worst_alignment text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.email,
         COUNT(*)::bigint,
         ROUND(AVG(a.compliance_score)::numeric, 1),
         SUM(a.findings_count)::bigint,
         CASE
           WHEN BOOL_OR(a.nabh_alignment = 'not_aligned') THEN 'not_aligned'
           WHEN BOOL_OR(a.nabh_alignment = 'partial') THEN 'partial'
           ELSE 'aligned'
         END
  FROM public.customer_quarterly_audits_r2516 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  WHERE a.status = 'completed'
  GROUP BY p.email
  ORDER BY AVG(a.compliance_score) ASC NULLS LAST
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_non_compliant_hospitals_r2516() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_non_compliant_hospitals_r2516() TO authenticated;

CREATE OR REPLACE FUNCTION public.finding_kind_breakdown_r2516()
RETURNS TABLE(
  finding_kind text,
  action_count bigint,
  open_count bigint,
  critical_count bigint,
  done_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ca.finding_kind,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE ca.status IN ('open','in_progress'))::bigint,
         COUNT(*) FILTER (WHERE ca.severity = 'critical')::bigint,
         COUNT(*) FILTER (WHERE ca.status = 'done')::bigint
  FROM public.audit_corrective_actions_r2516 ca
  GROUP BY ca.finding_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.finding_kind_breakdown_r2516() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.finding_kind_breakdown_r2516() TO authenticated;

CREATE OR REPLACE FUNCTION public.nabh_alignment_summary_r2516()
RETURNS TABLE(
  nabh_alignment text,
  audits_count bigint,
  avg_compliance numeric,
  avg_findings numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.nabh_alignment,
         COUNT(*)::bigint,
         ROUND(AVG(a.compliance_score)::numeric, 1),
         ROUND(AVG(a.findings_count)::numeric, 1)
  FROM public.customer_quarterly_audits_r2516 a
  WHERE a.status = 'completed'
  GROUP BY a.nabh_alignment
  ORDER BY
    CASE a.nabh_alignment
      WHEN 'aligned' THEN 1
      WHEN 'partial' THEN 2
      WHEN 'not_aligned' THEN 3
      ELSE 4
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.nabh_alignment_summary_r2516() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nabh_alignment_summary_r2516() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_completion_trend_r2516()
RETURNS TABLE(
  month_label text,
  audits_completed bigint,
  avg_compliance numeric,
  total_findings bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', a.audit_completed_at), 'YYYY-MM'),
         COUNT(*)::bigint,
         ROUND(AVG(a.compliance_score)::numeric, 1),
         SUM(a.findings_count)::bigint
  FROM public.customer_quarterly_audits_r2516 a
  WHERE a.status = 'completed' AND a.audit_completed_at IS NOT NULL
  GROUP BY date_trunc('month', a.audit_completed_at)
  ORDER BY date_trunc('month', a.audit_completed_at) DESC
  LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_completion_trend_r2516() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_completion_trend_r2516() TO authenticated;

CREATE OR REPLACE FUNCTION public.severe_findings_focus_r2516()
RETURNS TABLE(
  id uuid,
  hospital_email text,
  quarter_label text,
  finding_kind text,
  severity text,
  action_md text,
  owner_email text,
  due_at timestamptz,
  status text,
  days_open int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ca.id, p.email, a.quarter_label, ca.finding_kind, ca.severity,
         ca.action_md, ca.owner_email, ca.due_at, ca.status,
         EXTRACT(DAY FROM (now() - ca.created_at))::int
  FROM public.audit_corrective_actions_r2516 ca
  JOIN public.customer_quarterly_audits_r2516 a ON a.id = ca.audit_id
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  WHERE ca.severity IN ('high','critical')
    AND ca.status IN ('open','in_progress')
  ORDER BY
    CASE ca.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 ELSE 3 END,
    ca.due_at ASC NULLS LAST
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION public.severe_findings_focus_r2516() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.severe_findings_focus_r2516() TO authenticated;
