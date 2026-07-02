BEGIN;

-- Round 1571: Founder Hospital Lifecycle Stages Tracker
-- Classify hospitals across onboarded -> amc_active -> expansion -> mature -> at_risk -> churned/renewed

CREATE TABLE IF NOT EXISTS founder_hospital_lifecycle_stages_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  stage text NOT NULL CHECK (stage IN ('onboarded','amc_active','expansion','mature','at_risk','churned','renewed')),
  entered_at timestamptz NOT NULL DEFAULT now(),
  exited_at timestamptz,
  dwell_seconds bigint,
  drivers jsonb NOT NULL DEFAULT '{}'::jsonb,
  founder_notes text,
  reviewed_by_founder_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhls_v2_hospital ON founder_hospital_lifecycle_stages_v2(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhls_v2_stage ON founder_hospital_lifecycle_stages_v2(stage);
CREATE INDEX IF NOT EXISTS idx_fhls_v2_entered ON founder_hospital_lifecycle_stages_v2(entered_at DESC);

ALTER TABLE founder_hospital_lifecycle_stages_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhls_v2_founder_all ON founder_hospital_lifecycle_stages_v2;
CREATE POLICY fhls_v2_founder_all ON founder_hospital_lifecycle_stages_v2
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_hospital_lifecycle_transitions_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  from_stage text,
  to_stage text NOT NULL,
  transitioned_at timestamptz NOT NULL DEFAULT now(),
  reason text,
  founder_reviewed boolean NOT NULL DEFAULT false,
  founder_review_notes text,
  founder_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhlt_v2_hospital ON founder_hospital_lifecycle_transitions_v2(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhlt_v2_reviewed ON founder_hospital_lifecycle_transitions_v2(founder_reviewed);
CREATE INDEX IF NOT EXISTS idx_fhlt_v2_when ON founder_hospital_lifecycle_transitions_v2(transitioned_at DESC);

ALTER TABLE founder_hospital_lifecycle_transitions_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhlt_v2_founder_all ON founder_hospital_lifecycle_transitions_v2;
CREATE POLICY fhlt_v2_founder_all ON founder_hospital_lifecycle_transitions_v2
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- READ RPC 1: stage cohort summary
CREATE OR REPLACE FUNCTION founder_lifecycle_stage_cohort_v2()
RETURNS TABLE(stage text, hospital_count bigint, avg_dwell_days numeric, median_dwell_days numeric, oldest_in_stage_days numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.stage,
         COUNT(*)::bigint,
         ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(s.exited_at, now()) - s.entered_at))/86400.0)::numeric, 2),
         ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (COALESCE(s.exited_at, now()) - s.entered_at))/86400.0)::numeric, 2),
         ROUND(MAX(EXTRACT(EPOCH FROM (now() - s.entered_at))/86400.0) FILTER (WHERE s.exited_at IS NULL)::numeric, 2)
  FROM founder_hospital_lifecycle_stages_v2 s
  GROUP BY s.stage
  ORDER BY s.stage;
END; $$;

-- READ RPC 2: current stage per hospital
CREATE OR REPLACE FUNCTION founder_lifecycle_hospital_current_stage_v2()
RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, stage text, days_in_stage numeric, drivers jsonb, reviewed_by_founder_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_org_id, o.name,
         s.stage,
         ROUND(EXTRACT(EPOCH FROM (now() - s.entered_at))/86400.0::numeric, 2),
         s.drivers,
         s.reviewed_by_founder_at
  FROM founder_hospital_lifecycle_stages_v2 s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.exited_at IS NULL
  ORDER BY s.entered_at ASC;
END; $$;

-- READ RPC 3: pending transition reviews
CREATE OR REPLACE FUNCTION founder_lifecycle_pending_reviews_v2()
RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, from_stage text, to_stage text, transitioned_at timestamptz, reason text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_org_id, o.name, t.from_stage, t.to_stage, t.transitioned_at, t.reason
  FROM founder_hospital_lifecycle_transitions_v2 t
  JOIN organizations o ON o.id = t.hospital_org_id
  WHERE NOT t.founder_reviewed
  ORDER BY t.transitioned_at DESC
  LIMIT 100;
END; $$;

-- READ RPC 4: at-risk + churn watchlist
CREATE OR REPLACE FUNCTION founder_lifecycle_at_risk_watch_v2()
RETURNS TABLE(hospital_org_id uuid, hospital_name text, stage text, days_in_stage numeric, drivers jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.hospital_org_id, o.name, s.stage,
         ROUND(EXTRACT(EPOCH FROM (now() - s.entered_at))/86400.0::numeric, 2),
         s.drivers
  FROM founder_hospital_lifecycle_stages_v2 s
  JOIN organizations o ON o.id = s.hospital_org_id
  WHERE s.exited_at IS NULL AND s.stage IN ('at_risk','churned')
  ORDER BY s.entered_at ASC;
END; $$;

-- READ RPC 5: stage funnel (counts by stage entered last 90d)
CREATE OR REPLACE FUNCTION founder_lifecycle_funnel_v2()
RETURNS TABLE(stage text, entered_90d bigint, exited_90d bigint, net_change bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.stage,
         COUNT(*) FILTER (WHERE s.entered_at >= now() - interval '90 days')::bigint,
         COUNT(*) FILTER (WHERE s.exited_at IS NOT NULL AND s.exited_at >= now() - interval '90 days')::bigint,
         (COUNT(*) FILTER (WHERE s.entered_at >= now() - interval '90 days')
            - COUNT(*) FILTER (WHERE s.exited_at IS NOT NULL AND s.exited_at >= now() - interval '90 days'))::bigint
  FROM founder_hospital_lifecycle_stages_v2 s
  GROUP BY s.stage
  ORDER BY s.stage;
END; $$;

-- WRITE RPC 6: review a transition
CREATE OR REPLACE FUNCTION founder_lifecycle_review_transition_v2(p_transition_id uuid, p_notes text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_hospital_lifecycle_transitions_v2
     SET founder_reviewed = true,
         founder_review_notes = p_notes,
         founder_reviewed_at = now()
   WHERE id = p_transition_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_lifecycle_review_transition_v2',
          jsonb_build_object('transition_id', p_transition_id, 'notes', p_notes));
END; $$;

-- WRITE RPC 7: annotate a stage row
CREATE OR REPLACE FUNCTION founder_lifecycle_annotate_stage_v2(p_stage_id uuid, p_notes text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_hospital_lifecycle_stages_v2
     SET founder_notes = p_notes,
         reviewed_by_founder_at = now(),
         updated_at = now()
   WHERE id = p_stage_id;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_lifecycle_annotate_stage_v2',
          jsonb_build_object('stage_id', p_stage_id, 'notes', p_notes));
END; $$;

-- LOG HELPERS
CREATE OR REPLACE FUNCTION log_founder_lifecycle_view_dashboard_v2()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_lifecycle_view_dashboard_v2', '{}'::jsonb);
END; $$;

CREATE OR REPLACE FUNCTION log_founder_lifecycle_export_v2(p_format text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_lifecycle_export_v2', jsonb_build_object('format', p_format));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_lifecycle_filter_v2(p_filter text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_lifecycle_filter_v2', jsonb_build_object('filter', p_filter));
END; $$;

CREATE OR REPLACE FUNCTION log_founder_lifecycle_drilldown_v2(p_hospital_org_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_lifecycle_drilldown_v2', jsonb_build_object('hospital_org_id', p_hospital_org_id));
END; $$;

-- GRANTS
REVOKE EXECUTE ON FUNCTION founder_lifecycle_stage_cohort_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lifecycle_stage_cohort_v2() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_lifecycle_hospital_current_stage_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lifecycle_hospital_current_stage_v2() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_lifecycle_pending_reviews_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lifecycle_pending_reviews_v2() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_lifecycle_at_risk_watch_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lifecycle_at_risk_watch_v2() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_lifecycle_funnel_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lifecycle_funnel_v2() TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_lifecycle_review_transition_v2(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lifecycle_review_transition_v2(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION founder_lifecycle_annotate_stage_v2(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_lifecycle_annotate_stage_v2(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_lifecycle_view_dashboard_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_lifecycle_view_dashboard_v2() TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_lifecycle_export_v2(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_lifecycle_export_v2(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_lifecycle_filter_v2(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_lifecycle_filter_v2(text) TO authenticated;
REVOKE EXECUTE ON FUNCTION log_founder_lifecycle_drilldown_v2(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_lifecycle_drilldown_v2(uuid) TO authenticated;

COMMIT;