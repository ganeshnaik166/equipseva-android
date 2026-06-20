BEGIN;

-- Round r1518: Hospital incident reasons taxonomy + per-reason frequency + root-cause clusters

CREATE TABLE IF NOT EXISTS founder_hospital_incident_reasons_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reason_code text NOT NULL UNIQUE,
  reason_label text NOT NULL,
  cluster text NOT NULL CHECK (cluster IN ('engineer_quality','parts_delay','sla_miss','communication','billing','tooling','training','process','external','other')),
  severity_default text NOT NULL DEFAULT 'p2' CHECK (severity_default IN ('p0','p1','p2','p3')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS founder_hospital_incident_log_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL,
  reason_id uuid NOT NULL REFERENCES founder_hospital_incident_reasons_v2(id),
  incident_kind text NOT NULL CHECK (incident_kind IN ('escalation','downtime','complaint','rework','no_show','dispute')),
  severity text NOT NULL DEFAULT 'p2' CHECK (severity IN ('p0','p1','p2','p3')),
  repair_job_id uuid,
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  notes text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhir_log_opened_v2 ON founder_hospital_incident_log_v2(opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_fhir_log_reason_v2 ON founder_hospital_incident_log_v2(reason_id);
CREATE INDEX IF NOT EXISTS idx_fhir_log_hospital_v2 ON founder_hospital_incident_log_v2(hospital_org_id);

ALTER TABLE founder_hospital_incident_reasons_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_hospital_incident_log_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_reasons_v2 ON founder_hospital_incident_reasons_v2;
CREATE POLICY founder_only_reasons_v2 ON founder_hospital_incident_reasons_v2
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_log_v2 ON founder_hospital_incident_log_v2;
CREATE POLICY founder_only_log_v2 ON founder_hospital_incident_log_v2
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- Seed core taxonomy
INSERT INTO founder_hospital_incident_reasons_v2 (reason_code, reason_label, cluster, severity_default) VALUES
  ('ENG_LATE','Engineer arrived late','engineer_quality','p2'),
  ('ENG_NO_SHOW','Engineer no-show','engineer_quality','p1'),
  ('PART_DELAY','Spare part delayed','parts_delay','p2'),
  ('PART_WRONG','Wrong spare part shipped','parts_delay','p1'),
  ('SLA_BREACH','SLA breached','sla_miss','p1'),
  ('COMM_GAP','Communication breakdown','communication','p2'),
  ('BILL_DISPUTE','Billing dispute','billing','p2'),
  ('TOOL_MISSING','Tool missing onsite','tooling','p3'),
  ('TRAIN_GAP','Training gap','training','p3'),
  ('PROC_DEVIATE','Process deviation','process','p2'),
  ('EXT_POWER','External power outage','external','p3'),
  ('OTHER','Other / uncategorised','other','p3')
ON CONFLICT (reason_code) DO NOTHING;

-- RPC 1: KPI summary
CREATE OR REPLACE FUNCTION founder_hospital_incident_kpi_v2()
RETURNS TABLE(
  total_incidents bigint,
  open_incidents bigint,
  closed_incidents bigint,
  p0_count bigint,
  p1_count bigint,
  p2_count bigint,
  p3_count bigint,
  unique_hospitals bigint,
  unique_reasons bigint,
  active_reasons bigint,
  inactive_reasons bigint,
  last_7d bigint,
  last_30d bigint,
  last_90d bigint,
  avg_resolution_hours numeric,
  top_cluster text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_hospital_incident_log_v2),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE resolved_at IS NULL),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE resolved_at IS NOT NULL),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE severity='p0'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE severity='p1'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE severity='p2'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE severity='p3'),
    (SELECT count(DISTINCT hospital_org_id) FROM founder_hospital_incident_log_v2),
    (SELECT count(DISTINCT reason_id) FROM founder_hospital_incident_log_v2),
    (SELECT count(*) FROM founder_hospital_incident_reasons_v2 WHERE is_active),
    (SELECT count(*) FROM founder_hospital_incident_reasons_v2 WHERE NOT is_active),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE opened_at >= now() - interval '7 days'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE opened_at >= now() - interval '30 days'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 WHERE opened_at >= now() - interval '90 days'),
    (SELECT round(avg(EXTRACT(EPOCH FROM (resolved_at - opened_at))/3600.0)::numeric, 2) FROM founder_hospital_incident_log_v2 WHERE resolved_at IS NOT NULL),
    (SELECT r.cluster FROM founder_hospital_incident_log_v2 l JOIN founder_hospital_incident_reasons_v2 r ON r.id = l.reason_id GROUP BY r.cluster ORDER BY count(*) DESC LIMIT 1);
END;
$$;

-- RPC 2: reasons taxonomy list
CREATE OR REPLACE FUNCTION founder_hospital_incident_reason_list_v2()
RETURNS TABLE(
  id uuid,
  reason_code text,
  reason_label text,
  cluster text,
  severity_default text,
  is_active boolean,
  use_count bigint,
  last_used_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.reason_code, r.reason_label, r.cluster, r.severity_default, r.is_active,
         (SELECT count(*) FROM founder_hospital_incident_log_v2 l WHERE l.reason_id = r.id),
         (SELECT max(l.opened_at) FROM founder_hospital_incident_log_v2 l WHERE l.reason_id = r.id)
  FROM founder_hospital_incident_reasons_v2 r
  ORDER BY r.cluster, r.reason_code;
END;
$$;

-- RPC 3: per-reason frequency (last 90d)
CREATE OR REPLACE FUNCTION founder_hospital_incident_frequency_v2()
RETURNS TABLE(
  id uuid,
  reason_code text,
  cluster text,
  freq_7d bigint,
  freq_30d bigint,
  freq_90d bigint,
  open_count bigint,
  avg_hours_to_close numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.reason_code, r.cluster,
    (SELECT count(*) FROM founder_hospital_incident_log_v2 l WHERE l.reason_id = r.id AND l.opened_at >= now() - interval '7 days'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 l WHERE l.reason_id = r.id AND l.opened_at >= now() - interval '30 days'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 l WHERE l.reason_id = r.id AND l.opened_at >= now() - interval '90 days'),
    (SELECT count(*) FROM founder_hospital_incident_log_v2 l WHERE l.reason_id = r.id AND l.resolved_at IS NULL),
    (SELECT round(avg(EXTRACT(EPOCH FROM (l.resolved_at - l.opened_at))/3600.0)::numeric, 2) FROM founder_hospital_incident_log_v2 l WHERE l.reason_id = r.id AND l.resolved_at IS NOT NULL)
  FROM founder_hospital_incident_reasons_v2 r
  ORDER BY 6 DESC NULLS LAST, 5 DESC;
END;
$$;

-- RPC 4: root-cause clusters
CREATE OR REPLACE FUNCTION founder_hospital_incident_clusters_v2()
RETURNS TABLE(
  cluster text,
  reason_count bigint,
  incident_count bigint,
  open_count bigint,
  p0p1_count bigint,
  unique_hospitals bigint,
  avg_hours_to_close numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.cluster,
    count(DISTINCT r.id),
    count(l.id),
    count(*) FILTER (WHERE l.resolved_at IS NULL),
    count(*) FILTER (WHERE l.severity IN ('p0','p1')),
    count(DISTINCT l.hospital_org_id),
    round(avg(EXTRACT(EPOCH FROM (l.resolved_at - l.opened_at))/3600.0)::numeric, 2)
  FROM founder_hospital_incident_reasons_v2 r
  LEFT JOIN founder_hospital_incident_log_v2 l ON l.reason_id = r.id
  GROUP BY r.cluster
  ORDER BY 3 DESC NULLS LAST;
END;
$$;

-- RPC 5: per-hospital incident summary
CREATE OR REPLACE FUNCTION founder_hospital_incident_by_hospital_v2()
RETURNS TABLE(
  hospital_org_id uuid,
  hospital_name text,
  city text,
  incident_count bigint,
  open_count bigint,
  p0p1_count bigint,
  distinct_reasons bigint,
  last_incident_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.hospital_org_id,
    o.name,
    o.city,
    count(*),
    count(*) FILTER (WHERE l.resolved_at IS NULL),
    count(*) FILTER (WHERE l.severity IN ('p0','p1')),
    count(DISTINCT l.reason_id),
    max(l.opened_at)
  FROM founder_hospital_incident_log_v2 l
  LEFT JOIN organizations o ON o.id = l.hospital_org_id
  GROUP BY l.hospital_org_id, o.name, o.city
  ORDER BY 4 DESC
  LIMIT 100;
END;
$$;

-- RPC 6: recent incidents feed
CREATE OR REPLACE FUNCTION founder_hospital_incident_recent_v2()
RETURNS TABLE(
  id uuid,
  opened_at timestamptz,
  resolved_at timestamptz,
  hospital_name text,
  reason_code text,
  cluster text,
  incident_kind text,
  severity text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.opened_at, l.resolved_at, o.name, r.reason_code, r.cluster, l.incident_kind, l.severity, l.notes
  FROM founder_hospital_incident_log_v2 l
  LEFT JOIN organizations o ON o.id = l.hospital_org_id
  LEFT JOIN founder_hospital_incident_reasons_v2 r ON r.id = l.reason_id
  ORDER BY l.opened_at DESC
  LIMIT 200;
END;
$$;

-- RPC 7: cluster trend by week (last 12w)
CREATE OR REPLACE FUNCTION founder_hospital_incident_trend_v2()
RETURNS TABLE(
  week_start date,
  cluster text,
  incident_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', l.opened_at)::date,
         r.cluster,
         count(*)
  FROM founder_hospital_incident_log_v2 l
  JOIN founder_hospital_incident_reasons_v2 r ON r.id = l.reason_id
  WHERE l.opened_at >= now() - interval '84 days'
  GROUP BY 1, 2
  ORDER BY 1 DESC, 3 DESC;
END;
$$;

-- Write helpers (VOLATILE)
CREATE OR REPLACE FUNCTION log_founder_hir_log_incident_v2(
  p_hospital_org_id uuid,
  p_reason_code text,
  p_incident_kind text,
  p_severity text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_reason_id uuid;
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id INTO v_reason_id FROM founder_hospital_incident_reasons_v2 WHERE reason_code = p_reason_code;
  IF v_reason_id IS NULL THEN RAISE EXCEPTION 'unknown reason_code %', p_reason_code; END IF;
  INSERT INTO founder_hospital_incident_log_v2 (hospital_org_id, reason_id, incident_kind, severity, notes, created_by)
  VALUES (p_hospital_org_id, v_reason_id, p_incident_kind, p_severity, p_notes, auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hir_log_incident_v2',
          jsonb_build_object('id', v_id, 'hospital_org_id', p_hospital_org_id, 'reason_code', p_reason_code, 'severity', p_severity));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_hir_resolve_incident_v2(p_incident_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_hospital_incident_log_v2 SET resolved_at = now() WHERE id = p_incident_id AND resolved_at IS NULL;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hir_resolve_incident_v2', jsonb_build_object('id', p_incident_id));
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_hir_upsert_reason_v2(
  p_reason_code text,
  p_reason_label text,
  p_cluster text,
  p_severity_default text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_hospital_incident_reasons_v2 (reason_code, reason_label, cluster, severity_default)
  VALUES (p_reason_code, p_reason_label, p_cluster, p_severity_default)
  ON CONFLICT (reason_code) DO UPDATE
    SET reason_label = EXCLUDED.reason_label,
        cluster = EXCLUDED.cluster,
        severity_default = EXCLUDED.severity_default,
        updated_at = now()
  RETURNING id INTO v_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hir_upsert_reason_v2',
          jsonb_build_object('id', v_id, 'reason_code', p_reason_code, 'cluster', p_cluster));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_hir_toggle_reason_v2(p_reason_id uuid, p_active boolean)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_hospital_incident_reasons_v2 SET is_active = p_active, updated_at = now() WHERE id = p_reason_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'hir_toggle_reason_v2',
          jsonb_build_object('id', p_reason_id, 'is_active', p_active));
END;
$$;

-- Lockdown grants
REVOKE EXECUTE ON FUNCTION founder_hospital_incident_kpi_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hospital_incident_reason_list_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hospital_incident_frequency_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hospital_incident_clusters_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hospital_incident_by_hospital_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hospital_incident_recent_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_hospital_incident_trend_v2() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_hir_log_incident_v2(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_hir_resolve_incident_v2(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_hir_upsert_reason_v2(text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_hir_toggle_reason_v2(uuid, boolean) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_hospital_incident_kpi_v2() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hospital_incident_reason_list_v2() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hospital_incident_frequency_v2() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hospital_incident_clusters_v2() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hospital_incident_by_hospital_v2() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hospital_incident_recent_v2() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_hospital_incident_trend_v2() TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_hir_log_incident_v2(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_hir_resolve_incident_v2(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_hir_upsert_reason_v2(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_hir_toggle_reason_v2(uuid, boolean) TO authenticated;

COMMIT;