BEGIN;

-- =========================================================================
-- r1667 — Hospital Equipment Audit Log
-- =========================================================================

CREATE TABLE hospital_equipment_audits_r1667 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  hospital_user_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  audit_date date NOT NULL DEFAULT CURRENT_DATE,
  auditor_email text NOT NULL,
  total_units int NOT NULL DEFAULT 0 CHECK (total_units >= 0),
  working_units int NOT NULL DEFAULT 0 CHECK (working_units >= 0),
  non_working_units int NOT NULL DEFAULT 0 CHECK (non_working_units >= 0),
  missing_units int NOT NULL DEFAULT 0 CHECK (missing_units >= 0),
  summary_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_haa_r1667_hospital ON hospital_equipment_audits_r1667(hospital_user_id);
CREATE INDEX idx_haa_r1667_date ON hospital_equipment_audits_r1667(audit_date DESC);

CREATE TABLE hospital_audit_findings_r1667 (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  audit_id uuid NOT NULL REFERENCES hospital_equipment_audits_r1667(id) ON DELETE CASCADE,
  finding_text text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  action_required text,
  action_owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','wont_fix')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_haf_r1667_audit ON hospital_audit_findings_r1667(audit_id);
CREATE INDEX idx_haf_r1667_severity ON hospital_audit_findings_r1667(severity, status);

ALTER TABLE hospital_equipment_audits_r1667 ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_audit_findings_r1667 ENABLE ROW LEVEL SECURITY;

CREATE POLICY haa_r1667_founder_all ON hospital_equipment_audits_r1667
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE POLICY haf_r1667_founder_all ON hospital_audit_findings_r1667
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list_audits
-- =========================================================================
CREATE OR REPLACE FUNCTION list_audits_r1667()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  audit_date date,
  auditor_email text,
  total_units int,
  working_units int,
  non_working_units int,
  missing_units int,
  summary_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.hospital_user_id,
    p.email::text AS hospital_email,
    a.audit_date,
    a.auditor_email,
    a.total_units,
    a.working_units,
    a.non_working_units,
    a.missing_units,
    a.summary_md,
    a.created_at
  FROM hospital_equipment_audits_r1667 a
  LEFT JOIN profiles p ON p.id = a.hospital_user_id
  ORDER BY a.audit_date DESC, a.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_audits_r1667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_audits_r1667() TO authenticated;

-- =========================================================================
-- RPC 2: record_audit
-- =========================================================================
CREATE OR REPLACE FUNCTION record_audit_r1667(
  p_hospital_user_id uuid,
  p_audit_date date,
  p_auditor_email text,
  p_total_units int,
  p_working_units int,
  p_non_working_units int,
  p_missing_units int,
  p_summary_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO hospital_equipment_audits_r1667(
    hospital_user_id, audit_date, auditor_email,
    total_units, working_units, non_working_units, missing_units, summary_md
  )
  VALUES (
    p_hospital_user_id, COALESCE(p_audit_date, CURRENT_DATE), p_auditor_email,
    COALESCE(p_total_units, 0), COALESCE(p_working_units, 0),
    COALESCE(p_non_working_units, 0), COALESCE(p_missing_units, 0), p_summary_md
  )
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1667_record_audit',
    jsonb_build_object(
      'audit_id', v_id,
      'hospital_user_id', p_hospital_user_id,
      'audit_date', p_audit_date,
      'total_units', p_total_units
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION record_audit_r1667(uuid, date, text, int, int, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION record_audit_r1667(uuid, date, text, int, int, int, int, text) TO authenticated;

-- =========================================================================
-- RPC 3: list_findings
-- =========================================================================
CREATE OR REPLACE FUNCTION list_findings_r1667(p_audit_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  finding_text text,
  severity text,
  action_required text,
  action_owner_email text,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.audit_id, f.finding_text, f.severity,
    f.action_required, f.action_owner_email, f.status,
    f.created_at, f.updated_at
  FROM hospital_audit_findings_r1667 f
  WHERE p_audit_id IS NULL OR f.audit_id = p_audit_id
  ORDER BY
    CASE f.severity WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    f.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_findings_r1667(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_findings_r1667(uuid) TO authenticated;

-- =========================================================================
-- RPC 4: add_finding
-- =========================================================================
CREATE OR REPLACE FUNCTION add_finding_r1667(
  p_audit_id uuid,
  p_finding_text text,
  p_severity text,
  p_action_required text,
  p_action_owner_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_severity NOT IN ('p0','p1','p2','p3') THEN
    RAISE EXCEPTION 'invalid severity %', p_severity;
  END IF;

  INSERT INTO hospital_audit_findings_r1667(
    audit_id, finding_text, severity, action_required, action_owner_email, status
  )
  VALUES (
    p_audit_id, p_finding_text, p_severity, p_action_required, p_action_owner_email, 'open'
  )
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1667_add_finding',
    jsonb_build_object(
      'finding_id', v_id,
      'audit_id', p_audit_id,
      'severity', p_severity
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION add_finding_r1667(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION add_finding_r1667(uuid, text, text, text, text) TO authenticated;

-- =========================================================================
-- RPC 5: update_finding
-- =========================================================================
CREATE OR REPLACE FUNCTION update_finding_r1667(
  p_finding_id uuid,
  p_status text,
  p_action_required text DEFAULT NULL,
  p_action_owner_email text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_status NOT IN ('open','in_progress','closed','wont_fix') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;

  UPDATE hospital_audit_findings_r1667
  SET status = p_status,
      action_required = COALESCE(p_action_required, action_required),
      action_owner_email = COALESCE(p_action_owner_email, action_owner_email),
      updated_at = now()
  WHERE id = p_finding_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1667_update_finding',
    jsonb_build_object(
      'finding_id', p_finding_id,
      'status', p_status
    )
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION update_finding_r1667(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION update_finding_r1667(uuid, text, text, text) TO authenticated;

-- =========================================================================
-- RPC 6: audit_summary_by_hospital
-- =========================================================================
CREATE OR REPLACE FUNCTION audit_summary_by_hospital_r1667()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  total_audits int,
  last_audit_date date,
  avg_working_pct numeric,
  total_open_findings int,
  total_p0_findings int
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.hospital_user_id,
    p.email::text AS hospital_email,
    COUNT(DISTINCT a.id)::int AS total_audits,
    MAX(a.audit_date) AS last_audit_date,
    ROUND(
      AVG(
        CASE WHEN a.total_units > 0
          THEN (a.working_units::numeric / a.total_units::numeric) * 100
          ELSE 0
        END
      ), 2
    ) AS avg_working_pct,
    (COUNT(f.id) FILTER (WHERE f.status IN ('open','in_progress')))::int AS total_open_findings,
    (COUNT(f.id) FILTER (WHERE f.severity = 'p0' AND f.status IN ('open','in_progress')))::int AS total_p0_findings
  FROM hospital_equipment_audits_r1667 a
  LEFT JOIN profiles p ON p.id = a.hospital_user_id
  LEFT JOIN hospital_audit_findings_r1667 f ON f.audit_id = a.id
  GROUP BY a.hospital_user_id, p.email
  ORDER BY total_p0_findings DESC, total_open_findings DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION audit_summary_by_hospital_r1667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION audit_summary_by_hospital_r1667() TO authenticated;

-- =========================================================================
-- RPC 7: high_severity_open_findings
-- =========================================================================
CREATE OR REPLACE FUNCTION high_severity_open_findings_r1667()
RETURNS TABLE (
  id uuid,
  audit_id uuid,
  hospital_user_id uuid,
  hospital_email text,
  audit_date date,
  finding_text text,
  severity text,
  action_required text,
  action_owner_email text,
  status text,
  age_days int
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id,
    f.audit_id,
    a.hospital_user_id,
    p.email::text AS hospital_email,
    a.audit_date,
    f.finding_text,
    f.severity,
    f.action_required,
    f.action_owner_email,
    f.status,
    EXTRACT(DAY FROM (now() - f.created_at))::int AS age_days
  FROM hospital_audit_findings_r1667 f
  JOIN hospital_equipment_audits_r1667 a ON a.id = f.audit_id
  LEFT JOIN profiles p ON p.id = a.hospital_user_id
  WHERE f.severity IN ('p0','p1')
    AND f.status IN ('open','in_progress')
  ORDER BY
    CASE f.severity WHEN 'p0' THEN 0 ELSE 1 END,
    f.created_at ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION high_severity_open_findings_r1667() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION high_severity_open_findings_r1667() TO authenticated;

COMMIT;