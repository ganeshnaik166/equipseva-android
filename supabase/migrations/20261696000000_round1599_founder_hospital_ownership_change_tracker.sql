BEGIN;

-- =========================================================================
-- Round 1599 — Founder Hospital Ownership Change Tracker (HEAVY)
-- Logs hospital ownership/management transitions; surfaces AMC continuation
-- risk; queues founder reach-out to new decision makers.
-- =========================================================================

CREATE TABLE IF NOT EXISTS hospital_ownership_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('ownership_sale','management_change','merger','acquisition','closure','rebrand','board_change')),
  previous_owner_name text,
  previous_owner_contact text,
  new_owner_name text,
  new_owner_contact text,
  new_owner_email text,
  new_owner_phone text,
  effective_date date NOT NULL,
  detected_at timestamptz NOT NULL DEFAULT now(),
  source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','news_alert','engineer_report','amc_signal','gst_change','other')),
  source_url text,
  notes text,
  amc_continuation_risk text NOT NULL DEFAULT 'unknown' CHECK (amc_continuation_risk IN ('low','medium','high','critical','unknown')),
  active_amc_count int NOT NULL DEFAULT 0,
  active_amc_value_rupees bigint NOT NULL DEFAULT 0,
  recorded_by uuid REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hoe_hospital ON hospital_ownership_events(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hoe_effective ON hospital_ownership_events(effective_date DESC);
CREATE INDEX IF NOT EXISTS idx_hoe_risk ON hospital_ownership_events(amc_continuation_risk);

ALTER TABLE hospital_ownership_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hoe_founder_all ON hospital_ownership_events;
CREATE POLICY hoe_founder_all ON hospital_ownership_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_ownership_outreach (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES hospital_ownership_events(id) ON DELETE CASCADE,
  outreach_channel text NOT NULL CHECK (outreach_channel IN ('email','phone','whatsapp','in_person','letter')),
  outreach_status text NOT NULL DEFAULT 'queued' CHECK (outreach_status IN ('queued','sent','responded','no_response','meeting_scheduled','renewed','lost')),
  contacted_at timestamptz,
  responded_at timestamptz,
  response_summary text,
  amc_renewed boolean NOT NULL DEFAULT false,
  next_step text,
  next_step_due date,
  owner_user_id uuid REFERENCES profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hoo_event ON hospital_ownership_outreach(event_id);
CREATE INDEX IF NOT EXISTS idx_hoo_status ON hospital_ownership_outreach(outreach_status);

ALTER TABLE hospital_ownership_outreach ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hoo_founder_all ON hospital_ownership_outreach;
CREATE POLICY hoo_founder_all ON hospital_ownership_outreach
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_ownership_events_recent()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  event_type text,
  previous_owner_name text,
  new_owner_name text,
  effective_date date,
  amc_continuation_risk text,
  active_amc_count int,
  active_amc_value_rupees bigint,
  source text,
  detected_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_org_id, o.name, e.event_type, e.previous_owner_name, e.new_owner_name,
         e.effective_date, e.amc_continuation_risk, e.active_amc_count, e.active_amc_value_rupees,
         e.source, e.detected_at
  FROM hospital_ownership_events e
  JOIN organizations o ON o.id = e.hospital_org_id
  ORDER BY e.effective_date DESC, e.detected_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ownership_events_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ownership_events_recent() TO authenticated;

CREATE OR REPLACE FUNCTION founder_ownership_kpis()
RETURNS TABLE (
  total_events int,
  events_30d int,
  events_90d int,
  critical_risk int,
  high_risk int,
  medium_risk int,
  low_risk int,
  unknown_risk int,
  at_risk_amc_value_rupees bigint,
  outreach_queued int,
  outreach_sent int,
  outreach_responded int,
  outreach_renewed int,
  outreach_lost int,
  unique_hospitals int,
  outreach_no_response int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM hospital_ownership_events),
    (SELECT COUNT(*)::int FROM hospital_ownership_events WHERE effective_date >= current_date - 30),
    (SELECT COUNT(*)::int FROM hospital_ownership_events WHERE effective_date >= current_date - 90),
    (SELECT COUNT(*)::int FROM hospital_ownership_events WHERE amc_continuation_risk = 'critical'),
    (SELECT COUNT(*)::int FROM hospital_ownership_events WHERE amc_continuation_risk = 'high'),
    (SELECT COUNT(*)::int FROM hospital_ownership_events WHERE amc_continuation_risk = 'medium'),
    (SELECT COUNT(*)::int FROM hospital_ownership_events WHERE amc_continuation_risk = 'low'),
    (SELECT COUNT(*)::int FROM hospital_ownership_events WHERE amc_continuation_risk = 'unknown'),
    (SELECT COALESCE(SUM(active_amc_value_rupees),0)::bigint FROM hospital_ownership_events WHERE amc_continuation_risk IN ('high','critical')),
    (SELECT COUNT(*)::int FROM hospital_ownership_outreach WHERE outreach_status = 'queued'),
    (SELECT COUNT(*)::int FROM hospital_ownership_outreach WHERE outreach_status = 'sent'),
    (SELECT COUNT(*)::int FROM hospital_ownership_outreach WHERE outreach_status = 'responded'),
    (SELECT COUNT(*)::int FROM hospital_ownership_outreach WHERE outreach_status = 'renewed'),
    (SELECT COUNT(*)::int FROM hospital_ownership_outreach WHERE outreach_status = 'lost'),
    (SELECT COUNT(DISTINCT hospital_org_id)::int FROM hospital_ownership_events),
    (SELECT COUNT(*)::int FROM hospital_ownership_outreach WHERE outreach_status = 'no_response');
END $$;
REVOKE EXECUTE ON FUNCTION founder_ownership_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ownership_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_ownership_at_risk_amcs()
RETURNS TABLE (
  event_id uuid,
  hospital_org_id uuid,
  hospital_name text,
  event_type text,
  effective_date date,
  amc_continuation_risk text,
  active_amc_count int,
  active_amc_value_rupees bigint,
  new_owner_name text,
  new_owner_email text,
  new_owner_phone text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_org_id, o.name, e.event_type, e.effective_date,
         e.amc_continuation_risk, e.active_amc_count, e.active_amc_value_rupees,
         e.new_owner_name, e.new_owner_email, e.new_owner_phone
  FROM hospital_ownership_events e
  JOIN organizations o ON o.id = e.hospital_org_id
  WHERE e.amc_continuation_risk IN ('high','critical')
  ORDER BY e.active_amc_value_rupees DESC NULLS LAST
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ownership_at_risk_amcs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ownership_at_risk_amcs() TO authenticated;

CREATE OR REPLACE FUNCTION founder_ownership_outreach_queue()
RETURNS TABLE (
  outreach_id uuid,
  event_id uuid,
  hospital_name text,
  new_owner_name text,
  outreach_channel text,
  outreach_status text,
  contacted_at timestamptz,
  responded_at timestamptz,
  next_step text,
  next_step_due date,
  amc_renewed boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ot.id, ot.event_id, o.name, e.new_owner_name, ot.outreach_channel,
         ot.outreach_status, ot.contacted_at, ot.responded_at, ot.next_step,
         ot.next_step_due, ot.amc_renewed
  FROM hospital_ownership_outreach ot
  JOIN hospital_ownership_events e ON e.id = ot.event_id
  JOIN organizations o ON o.id = e.hospital_org_id
  ORDER BY
    CASE ot.outreach_status
      WHEN 'queued' THEN 1 WHEN 'sent' THEN 2 WHEN 'responded' THEN 3
      WHEN 'meeting_scheduled' THEN 4 WHEN 'no_response' THEN 5
      WHEN 'renewed' THEN 6 WHEN 'lost' THEN 7 ELSE 8 END,
    ot.created_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ownership_outreach_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ownership_outreach_queue() TO authenticated;

CREATE OR REPLACE FUNCTION founder_ownership_by_event_type()
RETURNS TABLE (event_type text, n int, total_amc_value_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_type, COUNT(*)::int, COALESCE(SUM(e.active_amc_value_rupees),0)::bigint
  FROM hospital_ownership_events e
  GROUP BY e.event_type
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_ownership_by_event_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_ownership_by_event_type() TO authenticated;

-- =========================================================================
-- WRITE RPCs (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION founder_log_ownership_event(
  p_hospital_org_id uuid,
  p_event_type text,
  p_previous_owner_name text,
  p_new_owner_name text,
  p_new_owner_email text,
  p_new_owner_phone text,
  p_effective_date date,
  p_amc_continuation_risk text,
  p_source text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_count int;
  v_value bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::int, COALESCE(SUM(monthly_fee_rupees*12),0)::bigint
  INTO v_count, v_value
  FROM amc_contracts ac
  JOIN profiles p ON p.id = ac.client_user_id
  WHERE p.organization_id = p_hospital_org_id
    AND ac.status = 'active';

  INSERT INTO hospital_ownership_events (
    hospital_org_id, event_type, previous_owner_name, new_owner_name,
    new_owner_email, new_owner_phone, effective_date, amc_continuation_risk,
    source, notes, active_amc_count, active_amc_value_rupees, recorded_by
  ) VALUES (
    p_hospital_org_id, p_event_type, p_previous_owner_name, p_new_owner_name,
    p_new_owner_email, p_new_owner_phone, p_effective_date,
    COALESCE(p_amc_continuation_risk,'unknown'), COALESCE(p_source,'manual'),
    p_notes, v_count, v_value, auth.uid()
  ) RETURNING id INTO v_id;

  PERFORM log_founder_ownership_event_created(v_id, p_hospital_org_id, p_event_type);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_log_ownership_event(uuid,text,text,text,text,text,date,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_log_ownership_event(uuid,text,text,text,text,text,date,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_queue_ownership_outreach(
  p_event_id uuid,
  p_channel text,
  p_next_step text,
  p_next_step_due date
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_ownership_outreach (event_id, outreach_channel, next_step, next_step_due)
  VALUES (p_event_id, p_channel, p_next_step, p_next_step_due)
  RETURNING id INTO v_id;
  PERFORM log_founder_ownership_outreach_queued(v_id, p_event_id, p_channel);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_queue_ownership_outreach(uuid,text,text,date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_queue_ownership_outreach(uuid,text,text,date) TO authenticated;

-- =========================================================================
-- log_founder_* helpers (VOLATILE SECDEF)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_ownership_event_created(
  p_event_id uuid, p_hospital_org_id uuid, p_event_type text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_log_ownership_event',
    jsonb_build_object('event_id', p_event_id, 'hospital_org_id', p_hospital_org_id, 'event_type', p_event_type)
  );
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ownership_event_created(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ownership_event_created(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ownership_outreach_queued(
  p_outreach_id uuid, p_event_id uuid, p_channel text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_queue_ownership_outreach',
    jsonb_build_object('outreach_id', p_outreach_id, 'event_id', p_event_id, 'channel', p_channel)
  );
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ownership_outreach_queued(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ownership_outreach_queued(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ownership_outreach_updated(
  p_outreach_id uuid, p_status text, p_amc_renewed boolean
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_update_ownership_outreach',
    jsonb_build_object('outreach_id', p_outreach_id, 'status', p_status, 'amc_renewed', p_amc_renewed)
  );
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ownership_outreach_updated(uuid,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ownership_outreach_updated(uuid,text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_ownership_risk_changed(
  p_event_id uuid, p_new_risk text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_ownership_risk_changed',
    jsonb_build_object('event_id', p_event_id, 'risk', p_new_risk)
  );
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_ownership_risk_changed(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_ownership_risk_changed(uuid,text) TO authenticated;

COMMIT;