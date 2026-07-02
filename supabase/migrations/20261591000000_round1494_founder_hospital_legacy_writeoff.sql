BEGIN;

-- ============================================================
-- r1494 — Hospital Legacy-Equipment Write-Off Tracker
-- Log equipment write-offs at hospitals; per-hospital write-off
-- rate; surface high-write-off accounts as churn-risk.
-- ============================================================

-- --- TABLE 1: write-off events --------------------------------
CREATE TABLE IF NOT EXISTS hospital_writeoff_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  asset_label text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('imaging','ventilator','monitor','dental','laboratory','surgical','other')),
  original_value_rupees integer NOT NULL CHECK (original_value_rupees >= 0),
  depreciated_value_rupees integer NOT NULL CHECK (depreciated_value_rupees >= 0),
  writeoff_reason text NOT NULL CHECK (writeoff_reason IN ('depreciated','retired','obsolete','beyond_repair','amc_stopped','replaced')),
  amc_was_active boolean NOT NULL DEFAULT false,
  retired_at timestamptz NOT NULL DEFAULT now(),
  logged_at timestamptz NOT NULL DEFAULT now(),
  logged_by uuid REFERENCES auth.users(id),
  notes text
);

CREATE INDEX IF NOT EXISTS hospital_writeoff_events_hospital_idx ON hospital_writeoff_events(hospital_org_id);
CREATE INDEX IF NOT EXISTS hospital_writeoff_events_retired_idx ON hospital_writeoff_events(retired_at DESC);
CREATE INDEX IF NOT EXISTS hospital_writeoff_events_reason_idx ON hospital_writeoff_events(writeoff_reason);

ALTER TABLE hospital_writeoff_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_writeoff_events ON hospital_writeoff_events;
CREATE POLICY founder_only_writeoff_events ON hospital_writeoff_events
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- --- TABLE 2: per-hospital churn-risk snapshots ---------------
CREATE TABLE IF NOT EXISTS hospital_writeoff_risk_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  writeoff_count_90d integer NOT NULL DEFAULT 0,
  writeoff_value_rupees_90d integer NOT NULL DEFAULT 0,
  amc_stopped_count integer NOT NULL DEFAULT 0,
  risk_band text NOT NULL CHECK (risk_band IN ('low','medium','high','critical')),
  risk_score integer NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
  notes text
);

CREATE INDEX IF NOT EXISTS hospital_writeoff_risk_snapshots_hosp_idx ON hospital_writeoff_risk_snapshots(hospital_org_id, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS hospital_writeoff_risk_snapshots_band_idx ON hospital_writeoff_risk_snapshots(risk_band);

ALTER TABLE hospital_writeoff_risk_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_writeoff_risk ON hospital_writeoff_risk_snapshots;
CREATE POLICY founder_only_writeoff_risk ON hospital_writeoff_risk_snapshots
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- LOG HELPERS — VOLATILE SECDEF, is_founder gated
-- ============================================================
CREATE OR REPLACE FUNCTION log_founder_writeoff_logged(p_event_id uuid, p_hospital_org_id uuid, p_value_rupees integer)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'writeoff_logged',
         jsonb_build_object('event_id', p_event_id, 'hospital_org_id', p_hospital_org_id, 'value_rupees', p_value_rupees)
  FROM profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_writeoff_logged(uuid, uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_writeoff_logged(uuid, uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_writeoff_voided(p_event_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'writeoff_voided', jsonb_build_object('event_id', p_event_id)
  FROM profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_writeoff_voided(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_writeoff_voided(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_writeoff_risk_snapshot(p_snapshot_id uuid, p_hospital_org_id uuid, p_band text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'writeoff_risk_snapshot',
         jsonb_build_object('snapshot_id', p_snapshot_id, 'hospital_org_id', p_hospital_org_id, 'band', p_band)
  FROM profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_writeoff_risk_snapshot(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_writeoff_risk_snapshot(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_writeoff_note_added(p_event_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'writeoff_note_added', jsonb_build_object('event_id', p_event_id)
  FROM profiles p WHERE p.id = auth.uid();
END; $$;
REVOKE EXECUTE ON FUNCTION log_founder_writeoff_note_added(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_writeoff_note_added(uuid) TO authenticated;

-- ============================================================
-- READ RPCs — STABLE SECDEF
-- ============================================================

-- 1. KPI rollup
CREATE OR REPLACE FUNCTION founder_writeoff_kpis()
RETURNS TABLE (
  total_events bigint,
  events_90d bigint,
  events_30d bigint,
  events_7d bigint,
  total_value_rupees bigint,
  value_90d_rupees bigint,
  hospitals_with_writeoffs bigint,
  amc_stopped_events bigint,
  retired_events bigint,
  obsolete_events bigint,
  beyond_repair_events bigint,
  critical_risk_hospitals bigint,
  high_risk_hospitals bigint,
  medium_risk_hospitals bigint,
  avg_writeoff_value_rupees numeric,
  max_writeoff_value_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ev AS (SELECT * FROM hospital_writeoff_events),
       latest_snap AS (
         SELECT DISTINCT ON (hospital_org_id) hospital_org_id, risk_band
         FROM hospital_writeoff_risk_snapshots
         ORDER BY hospital_org_id, snapshot_at DESC
       )
  SELECT
    (SELECT count(*) FROM ev),
    (SELECT count(*) FROM ev WHERE retired_at >= now() - interval '90 days'),
    (SELECT count(*) FROM ev WHERE retired_at >= now() - interval '30 days'),
    (SELECT count(*) FROM ev WHERE retired_at >= now() - interval '7 days'),
    (SELECT COALESCE(sum(depreciated_value_rupees),0)::bigint FROM ev),
    (SELECT COALESCE(sum(depreciated_value_rupees),0)::bigint FROM ev WHERE retired_at >= now() - interval '90 days'),
    (SELECT count(DISTINCT hospital_org_id) FROM ev),
    (SELECT count(*) FROM ev WHERE writeoff_reason = 'amc_stopped'),
    (SELECT count(*) FROM ev WHERE writeoff_reason = 'retired'),
    (SELECT count(*) FROM ev WHERE writeoff_reason = 'obsolete'),
    (SELECT count(*) FROM ev WHERE writeoff_reason = 'beyond_repair'),
    (SELECT count(*) FROM latest_snap WHERE risk_band = 'critical'),
    (SELECT count(*) FROM latest_snap WHERE risk_band = 'high'),
    (SELECT count(*) FROM latest_snap WHERE risk_band = 'medium'),
    (SELECT COALESCE(avg(depreciated_value_rupees),0)::numeric FROM ev),
    (SELECT COALESCE(max(depreciated_value_rupees),0)::bigint FROM ev);
END; $$;
REVOKE EXECUTE ON FUNCTION founder_writeoff_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_writeoff_kpis() TO authenticated;

-- 2. Recent events
CREATE OR REPLACE FUNCTION founder_writeoff_recent_events(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_name text,
  asset_label text,
  asset_category text,
  original_value_rupees integer,
  depreciated_value_rupees integer,
  writeoff_reason text,
  amc_was_active boolean,
  retired_at timestamptz,
  days_ago numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, o.name, e.asset_label, e.asset_category,
         e.original_value_rupees, e.depreciated_value_rupees,
         e.writeoff_reason, e.amc_was_active, e.retired_at,
         ROUND((EXTRACT(EPOCH FROM (now() - e.retired_at)) / 86400.0)::numeric, 1)
  FROM hospital_writeoff_events e
  JOIN organizations o ON o.id = e.hospital_org_id
  ORDER BY e.retired_at DESC
  LIMIT p_limit;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_writeoff_recent_events(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_writeoff_recent_events(integer) TO authenticated;

-- 3. Per-hospital writeoff rate
CREATE OR REPLACE FUNCTION founder_writeoff_hospital_rates()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  events_total bigint,
  events_90d bigint,
  value_total_rupees bigint,
  value_90d_rupees bigint,
  amc_stopped_count bigint,
  last_writeoff_at timestamptz,
  rate_per_month numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.name,
         count(e.*)::bigint,
         count(e.*) FILTER (WHERE e.retired_at >= now() - interval '90 days')::bigint,
         COALESCE(sum(e.depreciated_value_rupees),0)::bigint,
         COALESCE(sum(e.depreciated_value_rupees) FILTER (WHERE e.retired_at >= now() - interval '90 days'),0)::bigint,
         count(*) FILTER (WHERE e.writeoff_reason = 'amc_stopped')::bigint,
         max(e.retired_at),
         ROUND((count(*) FILTER (WHERE e.retired_at >= now() - interval '90 days'))::numeric / 3.0, 2)
  FROM organizations o
  JOIN hospital_writeoff_events e ON e.hospital_org_id = o.id
  GROUP BY o.id, o.name
  ORDER BY count(e.*) DESC
  LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_writeoff_hospital_rates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_writeoff_hospital_rates() TO authenticated;

-- 4. Churn-risk leaderboard (latest snapshot per hospital)
CREATE OR REPLACE FUNCTION founder_writeoff_churn_risk()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  risk_band text,
  risk_score integer,
  writeoff_count_90d integer,
  writeoff_value_rupees_90d integer,
  amc_stopped_count integer,
  snapshot_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, o.name, s.risk_band, s.risk_score,
         s.writeoff_count_90d, s.writeoff_value_rupees_90d,
         s.amc_stopped_count, s.snapshot_at
  FROM (
    SELECT DISTINCT ON (hospital_org_id) *
    FROM hospital_writeoff_risk_snapshots
    ORDER BY hospital_org_id, snapshot_at DESC
  ) s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.risk_band IN ('high','critical','medium')
  ORDER BY s.risk_score DESC
  LIMIT 50;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_writeoff_churn_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_writeoff_churn_risk() TO authenticated;

-- 5. Category breakdown
CREATE OR REPLACE FUNCTION founder_writeoff_by_category()
RETURNS TABLE (
  id text,
  category text,
  events bigint,
  total_value_rupees bigint,
  amc_stopped_count bigint,
  avg_value_rupees numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.asset_category, e.asset_category, count(*)::bigint,
         COALESCE(sum(e.depreciated_value_rupees),0)::bigint,
         count(*) FILTER (WHERE e.writeoff_reason = 'amc_stopped')::bigint,
         ROUND(COALESCE(avg(e.depreciated_value_rupees),0)::numeric, 0)
  FROM hospital_writeoff_events e
  GROUP BY e.asset_category
  ORDER BY count(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_writeoff_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_writeoff_by_category() TO authenticated;

-- 6. Reason breakdown
CREATE OR REPLACE FUNCTION founder_writeoff_by_reason()
RETURNS TABLE (
  id text,
  reason text,
  events bigint,
  pct_of_total numeric,
  total_value_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM hospital_writeoff_events;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
  SELECT e.writeoff_reason, e.writeoff_reason, count(*)::bigint,
         ROUND((count(*)::numeric / v_total::numeric) * 100, 1),
         COALESCE(sum(e.depreciated_value_rupees),0)::bigint
  FROM hospital_writeoff_events e
  GROUP BY e.writeoff_reason
  ORDER BY count(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_writeoff_by_reason() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_writeoff_by_reason() TO authenticated;

-- 7. Write-layer: log a write-off event (VOLATILE)
CREATE OR REPLACE FUNCTION founder_writeoff_log_event(
  p_hospital_org_id uuid,
  p_asset_label text,
  p_asset_category text,
  p_original_value_rupees integer,
  p_depreciated_value_rupees integer,
  p_writeoff_reason text,
  p_amc_was_active boolean,
  p_notes text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_writeoff_events (
    hospital_org_id, asset_label, asset_category,
    original_value_rupees, depreciated_value_rupees,
    writeoff_reason, amc_was_active, notes, logged_by
  ) VALUES (
    p_hospital_org_id, p_asset_label, p_asset_category,
    p_original_value_rupees, p_depreciated_value_rupees,
    p_writeoff_reason, p_amc_was_active, p_notes, auth.uid()
  ) RETURNING id INTO v_id;
  PERFORM log_founder_writeoff_logged(v_id, p_hospital_org_id, p_depreciated_value_rupees);
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION founder_writeoff_log_event(uuid,text,text,integer,integer,text,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_writeoff_log_event(uuid,text,text,integer,integer,text,boolean,text) TO authenticated;

COMMIT;