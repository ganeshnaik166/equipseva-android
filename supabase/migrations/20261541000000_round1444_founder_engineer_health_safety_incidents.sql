BEGIN;
-- Round 1444: Founder engineer health & safety incidents tracker
-- 2 tables (incidents + corrective actions) + 7 RPCs



CREATE TABLE IF NOT EXISTS engineer_health_safety_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  incident_kind text NOT NULL CHECK (incident_kind IN ('electrical_shock','radiation_exposure','chemical_exposure','equipment_injury','vehicle_accident','slip_fall','infection_exposure','heatstroke','psychological','other')),
  severity text NOT NULL CHECK (severity IN ('near_miss','minor','moderate','serious','critical','fatal')),
  incident_date date NOT NULL,
  location_label text,
  description text,
  immediate_action_taken text,
  repair_job_id uuid,
  equipment_label text,
  downtime_days int NOT NULL DEFAULT 0,
  medical_cost_rupees numeric NOT NULL DEFAULT 0,
  reported_to_authority boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'reported' CHECK (status IN ('reported','investigating','root_cause_found','closed','escalated_to_authority')),
  reported_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehs_incidents_engineer ON engineer_health_safety_incidents(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ehs_incidents_status ON engineer_health_safety_incidents(status);
CREATE INDEX IF NOT EXISTS idx_ehs_incidents_severity ON engineer_health_safety_incidents(severity);
CREATE INDEX IF NOT EXISTS idx_ehs_incidents_date ON engineer_health_safety_incidents(incident_date DESC);

ALTER TABLE engineer_health_safety_incidents ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS engineer_health_safety_corrective_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id uuid NOT NULL REFERENCES engineer_health_safety_incidents(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('training_required','sop_update','ppe_provided','vendor_replaced','medical_followup','process_change','equipment_inspection')),
  description text,
  owner_user_id uuid,
  due_date date,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','cancelled')),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehs_actions_incident ON engineer_health_safety_corrective_actions(incident_id);
CREATE INDEX IF NOT EXISTS idx_ehs_actions_status ON engineer_health_safety_corrective_actions(status);
CREATE INDEX IF NOT EXISTS idx_ehs_actions_due ON engineer_health_safety_corrective_actions(due_date);

ALTER TABLE engineer_health_safety_corrective_actions ENABLE ROW LEVEL SECURITY;

-- RPC 1: 16-card summary
CREATE OR REPLACE FUNCTION founder_health_safety_summary()
RETURNS TABLE (
  total_incidents bigint,
  reported_incidents bigint,
  investigating_incidents bigint,
  root_cause_incidents bigint,
  closed_incidents bigint,
  escalated_incidents bigint,
  fatal_count bigint,
  critical_count bigint,
  serious_count bigint,
  near_miss_count bigint,
  total_downtime_days bigint,
  total_medical_cost_rupees numeric,
  open_actions bigint,
  overdue_actions bigint,
  incidents_last_30d bigint,
  latest_incident_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM engineer_health_safety_incidents),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE status='reported'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE status='investigating'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE status='root_cause_found'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE status='closed'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE status='escalated_to_authority'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE severity='fatal'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE severity='critical'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE severity='serious'),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE severity='near_miss'),
    COALESCE((SELECT sum(downtime_days)::bigint FROM engineer_health_safety_incidents), 0),
    COALESCE((SELECT sum(medical_cost_rupees) FROM engineer_health_safety_incidents), 0),
    (SELECT count(*) FROM engineer_health_safety_corrective_actions WHERE status IN ('open','in_progress')),
    (SELECT count(*) FROM engineer_health_safety_corrective_actions WHERE status IN ('open','in_progress') AND due_date < current_date),
    (SELECT count(*) FROM engineer_health_safety_incidents WHERE incident_date >= current_date - 30),
    (SELECT max(incident_date) FROM engineer_health_safety_incidents);
END;
$$;

GRANT EXECUTE ON FUNCTION founder_health_safety_summary() TO authenticated;

-- RPC 2: recent incidents
CREATE OR REPLACE FUNCTION founder_health_safety_incidents_recent()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  incident_kind text,
  severity text,
  incident_date date,
  location_label text,
  description text,
  equipment_label text,
  downtime_days int,
  medical_cost_rupees numeric,
  reported_to_authority boolean,
  status text,
  reported_at timestamptz,
  closed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id, i.incident_kind, i.severity, i.incident_date,
         i.location_label, i.description, i.equipment_label, i.downtime_days,
         i.medical_cost_rupees, i.reported_to_authority, i.status, i.reported_at, i.closed_at
  FROM engineer_health_safety_incidents i
  ORDER BY i.incident_date DESC, i.reported_at DESC
  LIMIT 60;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_health_safety_incidents_recent() TO authenticated;

-- RPC 3: recent corrective actions
CREATE OR REPLACE FUNCTION founder_health_safety_corrective_actions_recent()
RETURNS TABLE (
  id uuid,
  incident_id uuid,
  action_kind text,
  description text,
  owner_user_id uuid,
  due_date date,
  status text,
  closed_at timestamptz,
  created_at timestamptz,
  incident_severity text,
  incident_kind text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.incident_id, a.action_kind, a.description, a.owner_user_id,
         a.due_date, a.status, a.closed_at, a.created_at,
         i.severity, i.incident_kind
  FROM engineer_health_safety_corrective_actions a
  LEFT JOIN engineer_health_safety_incidents i ON i.id = a.incident_id
  ORDER BY a.created_at DESC
  LIMIT 80;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_health_safety_corrective_actions_recent() TO authenticated;

-- RPC 4: open critical (severity critical/fatal/serious AND not closed)
CREATE OR REPLACE FUNCTION founder_health_safety_open_critical()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  incident_kind text,
  severity text,
  incident_date date,
  status text,
  description text,
  downtime_days int,
  medical_cost_rupees numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT i.id, i.engineer_user_id, i.incident_kind, i.severity, i.incident_date,
         i.status, i.description, i.downtime_days, i.medical_cost_rupees
  FROM engineer_health_safety_incidents i
  WHERE i.severity IN ('serious','critical','fatal')
    AND i.status NOT IN ('closed')
  ORDER BY
    CASE i.severity WHEN 'fatal' THEN 0 WHEN 'critical' THEN 1 ELSE 2 END,
    i.incident_date DESC
  LIMIT 40;
END;
$$;

GRANT EXECUTE ON FUNCTION founder_health_safety_open_critical() TO authenticated;

-- RPC 5: write — register incident
CREATE OR REPLACE FUNCTION log_founder_health_safety_register_incident(
  p_engineer_user_id uuid,
  p_incident_kind text,
  p_severity text,
  p_incident_date date,
  p_location_label text,
  p_description text,
  p_equipment_label text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO engineer_health_safety_incidents
    (engineer_user_id, incident_kind, severity, incident_date, location_label, description, equipment_label)
  VALUES
    (p_engineer_user_id, p_incident_kind, p_severity, p_incident_date, p_location_label, p_description, p_equipment_label)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION log_founder_health_safety_register_incident(uuid, text, text, date, text, text, text) TO authenticated;

-- RPC 6: write — register corrective action
CREATE OR REPLACE FUNCTION log_founder_health_safety_register_action(
  p_incident_id uuid,
  p_action_kind text,
  p_description text,
  p_owner_user_id uuid,
  p_due_date date
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO engineer_health_safety_corrective_actions
    (incident_id, action_kind, description, owner_user_id, due_date)
  VALUES
    (p_incident_id, p_action_kind, p_description, p_owner_user_id, p_due_date)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION log_founder_health_safety_register_action(uuid, text, text, uuid, date) TO authenticated;

-- RPC 7: write — close incident
CREATE OR REPLACE FUNCTION log_founder_health_safety_close_incident(
  p_incident_id uuid,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE engineer_health_safety_incidents
     SET status='closed', closed_at=now(), notes=COALESCE(p_notes, notes), updated_at=now()
   WHERE id=p_incident_id;
END;
$$;

GRANT EXECUTE ON FUNCTION log_founder_health_safety_close_incident(uuid, text) TO authenticated;

COMMIT;