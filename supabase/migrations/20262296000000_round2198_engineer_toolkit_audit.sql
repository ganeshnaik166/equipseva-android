BEGIN;

-- ============================================================
-- Round 2198 — Engineer toolkit audit
-- Verify engineers carry right tools/calibrated meters per
-- equipment class; flag missing items + expired calibration.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_toolkit_audits_r2198 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  equipment_class text NOT NULL,
  audit_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  tool_name text NOT NULL,
  required boolean NOT NULL DEFAULT true,
  carried boolean NOT NULL DEFAULT false,
  calibration_due_on date,
  calibration_cert_no text,
  notes text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','passed','failed','waived','remediated')),
  flagged_reason text,
  auditor_user_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eta_r2198_engineer_date
  ON public.engineer_toolkit_audits_r2198 (engineer_id, audit_date DESC);
CREATE INDEX IF NOT EXISTS idx_eta_r2198_status
  ON public.engineer_toolkit_audits_r2198 (status);
CREATE INDEX IF NOT EXISTS idx_eta_r2198_class
  ON public.engineer_toolkit_audits_r2198 (equipment_class);

CREATE TABLE IF NOT EXISTS public.engineer_toolkit_audit_actions_r2198 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.engineer_toolkit_audits_r2198(id) ON DELETE CASCADE,
  action_kind text NOT NULL
    CHECK (action_kind IN ('flagged','remediated','waived','reaudit','note','status_changed')),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_user_id uuid REFERENCES public.profiles(id),
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etaa_r2198_audit
  ON public.engineer_toolkit_audit_actions_r2198 (audit_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_etaa_r2198_created
  ON public.engineer_toolkit_audit_actions_r2198 (created_at DESC);

ALTER TABLE public.engineer_toolkit_audits_r2198 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_toolkit_audit_actions_r2198 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_toolkit_audits_r2198;
CREATE POLICY founder_all ON public.engineer_toolkit_audits_r2198
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.engineer_toolkit_audit_actions_r2198;
CREATE POLICY founder_all ON public.engineer_toolkit_audit_actions_r2198
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- RPC 1: list_engineer_toolkit_audits_r2198
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_engineer_toolkit_audits_r2198()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  equipment_class text,
  audit_date date,
  tool_name text,
  required boolean,
  carried boolean,
  calibration_due_on date,
  calibration_cert_no text,
  status text,
  flagged_reason text,
  days_to_calibration_expiry int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id,
         a.engineer_id,
         COALESCE(p.full_name, p.email, 'unknown') AS engineer_name,
         a.equipment_class,
         a.audit_date,
         a.tool_name,
         a.required,
         a.carried,
         a.calibration_due_on,
         a.calibration_cert_no,
         a.status,
         a.flagged_reason,
         CASE WHEN a.calibration_due_on IS NULL THEN NULL
              ELSE (a.calibration_due_on - CURRENT_DATE)::int END AS days_to_calibration_expiry,
         a.created_at
  FROM public.engineer_toolkit_audits_r2198 a
  LEFT JOIN public.engineers e ON e.id = a.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  ORDER BY a.audit_date DESC, a.created_at DESC
  LIMIT 200;
END;
$$;

-- ============================================================
-- RPC 2: recent_actions_r2198
-- ============================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2198()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  action_kind text,
  payload jsonb,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT x.id, x.audit_id, x.action_kind, x.payload, x.actor_email, x.created_at
  FROM public.engineer_toolkit_audit_actions_r2198 x
  ORDER BY x.created_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================
-- RPC 3: top_equipment_classes_r2198
-- ============================================================
CREATE OR REPLACE FUNCTION public.top_equipment_classes_r2198()
RETURNS TABLE (
  equipment_class text,
  total_audits int,
  failed_count int,
  expired_calibration_count int,
  missing_tool_count int,
  pass_rate_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.equipment_class,
         COUNT(*)::int AS total_audits,
         (COUNT(*) FILTER (WHERE a.status = 'failed'))::int AS failed_count,
         (COUNT(*) FILTER (WHERE a.calibration_due_on IS NOT NULL
                              AND a.calibration_due_on < CURRENT_DATE))::int AS expired_calibration_count,
         (COUNT(*) FILTER (WHERE a.required = true AND a.carried = false))::int AS missing_tool_count,
         ROUND(
           100.0 * (COUNT(*) FILTER (WHERE a.status = 'passed'))::numeric
           / NULLIF(COUNT(*), 0)::numeric,
           1
         ) AS pass_rate_pct
  FROM public.engineer_toolkit_audits_r2198 a
  GROUP BY a.equipment_class
  ORDER BY failed_count DESC, total_audits DESC
  LIMIT 50;
END;
$$;

-- ============================================================
-- RPC 4: log_engineer_toolkit_audit_r2198
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_engineer_toolkit_audit_r2198(
  p_engineer_id uuid,
  p_equipment_class text,
  p_tool_name text,
  p_required boolean,
  p_carried boolean,
  p_calibration_due_on date,
  p_calibration_cert_no text,
  p_notes text,
  p_flagged_reason text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_status text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  v_status := CASE
    WHEN p_required AND NOT p_carried THEN 'failed'
    WHEN p_calibration_due_on IS NOT NULL AND p_calibration_due_on < CURRENT_DATE THEN 'failed'
    ELSE 'open'
  END;

  INSERT INTO public.engineer_toolkit_audits_r2198(
    engineer_id, equipment_class, tool_name, required, carried,
    calibration_due_on, calibration_cert_no, notes, status,
    flagged_reason, auditor_user_id
  ) VALUES (
    p_engineer_id, p_equipment_class, p_tool_name, p_required, p_carried,
    p_calibration_due_on, p_calibration_cert_no, p_notes, v_status,
    p_flagged_reason, auth.uid()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.engineer_toolkit_audit_actions_r2198(
    audit_id, action_kind, payload, actor_user_id, actor_email
  ) VALUES (
    v_id, 'flagged',
    jsonb_build_object(
      'equipment_class', p_equipment_class,
      'tool_name', p_tool_name,
      'status', v_status,
      'flagged_reason', p_flagged_reason
    ),
    auth.uid(), (auth.jwt()->>'email')
  );

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'op_r2198_log_audit',
    jsonb_build_object('audit_id', v_id, 'engineer_id', p_engineer_id, 'status', v_status)
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 5: log_action_r2198
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_action_r2198(
  p_audit_id uuid,
  p_action_kind text,
  p_payload jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.engineer_toolkit_audit_actions_r2198(
    audit_id, action_kind, payload, actor_user_id, actor_email
  ) VALUES (
    p_audit_id, p_action_kind, COALESCE(p_payload, '{}'::jsonb),
    auth.uid(), (auth.jwt()->>'email')
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'op_r2198_log_action',
    jsonb_build_object('action_id', v_id, 'audit_id', p_audit_id, 'action_kind', p_action_kind)
  );

  RETURN v_id;
END;
$$;

-- ============================================================
-- RPC 6: mark_status_r2198
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2198(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_status NOT IN ('open','passed','failed','waived','remediated') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE public.engineer_toolkit_audits_r2198
  SET status = p_status, updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.engineer_toolkit_audit_actions_r2198(
    audit_id, action_kind, payload, actor_user_id, actor_email
  ) VALUES (
    p_id, 'status_changed',
    jsonb_build_object('new_status', p_status),
    auth.uid(), (auth.jwt()->>'email')
  );

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'op_r2198_mark_status',
    jsonb_build_object('audit_id', p_id, 'new_status', p_status)
  );
END;
$$;

-- ============================================================
-- RPC 7: toolkit_audit_summary_r2198
-- ============================================================
CREATE OR REPLACE FUNCTION public.toolkit_audit_summary_r2198()
RETURNS TABLE (
  total_audits int,
  open_count int,
  failed_count int,
  passed_count int,
  waived_count int,
  remediated_count int,
  missing_required_tool_count int,
  expired_calibration_count int,
  expiring_30d_count int,
  distinct_engineers int,
  distinct_classes int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COUNT(*)::int AS total_audits,
         (COUNT(*) FILTER (WHERE a.status = 'open'))::int,
         (COUNT(*) FILTER (WHERE a.status = 'failed'))::int,
         (COUNT(*) FILTER (WHERE a.status = 'passed'))::int,
         (COUNT(*) FILTER (WHERE a.status = 'waived'))::int,
         (COUNT(*) FILTER (WHERE a.status = 'remediated'))::int,
         (COUNT(*) FILTER (WHERE a.required = true AND a.carried = false))::int,
         (COUNT(*) FILTER (WHERE a.calibration_due_on IS NOT NULL
                              AND a.calibration_due_on < CURRENT_DATE))::int,
         (COUNT(*) FILTER (WHERE a.calibration_due_on IS NOT NULL
                              AND a.calibration_due_on >= CURRENT_DATE
                              AND a.calibration_due_on < CURRENT_DATE + INTERVAL '30 days'))::int,
         (COUNT(DISTINCT a.engineer_id))::int,
         (COUNT(DISTINCT a.equipment_class))::int
  FROM public.engineer_toolkit_audits_r2198 a;
END;
$$;

-- ============================================================
-- Permissions: founder-only via is_founder() gate; revoke broad,
-- grant execute only to authenticated.
-- ============================================================
REVOKE ALL ON FUNCTION public.list_engineer_toolkit_audits_r2198() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2198() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_equipment_classes_r2198() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_engineer_toolkit_audit_r2198(uuid, text, text, boolean, boolean, date, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2198(uuid, text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2198(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.toolkit_audit_summary_r2198() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_engineer_toolkit_audits_r2198() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2198() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_equipment_classes_r2198() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engineer_toolkit_audit_r2198(uuid, text, text, boolean, boolean, date, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2198(uuid, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2198(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toolkit_audit_summary_r2198() TO authenticated;

COMMIT;
