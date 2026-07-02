BEGIN;

-- ============================================================================
-- r1612 — Founder Hospital Expansion Contracts
-- When hospital expands (new wing, new branch, new floor), trigger AMC contract
-- expansion with per-hospital expansion type + revenue uplift + founder approval.
-- ============================================================================

-- Table 1: hospital_expansion_events (one row per declared expansion)
CREATE TABLE IF NOT EXISTS hospital_expansion_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  source_amc_contract_id uuid REFERENCES amc_contracts(id) ON DELETE SET NULL,
  expansion_type text NOT NULL CHECK (expansion_type IN ('new_wing','new_branch','new_floor','new_specialty','new_equipment_block','capacity_uplift')),
  expansion_label text NOT NULL,
  declared_beds_added int NOT NULL DEFAULT 0 CHECK (declared_beds_added >= 0),
  declared_equipment_count int NOT NULL DEFAULT 0 CHECK (declared_equipment_count >= 0),
  expected_monthly_uplift_rupees int NOT NULL DEFAULT 0 CHECK (expected_monthly_uplift_rupees >= 0),
  proposed_amc_tier text CHECK (proposed_amc_tier IN ('basic','standard','premium','enterprise')),
  proposed_equipment_categories text[] NOT NULL DEFAULT ARRAY[]::text[],
  go_live_target_at timestamptz,
  declared_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  notes text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','contract_issued','cancelled')),
  founder_decision text,
  founder_decided_at timestamptz,
  founder_decided_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  resulting_amc_contract_id uuid REFERENCES amc_contracts(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hee_hospital ON hospital_expansion_events(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hee_status ON hospital_expansion_events(status);
CREATE INDEX IF NOT EXISTS idx_hee_created ON hospital_expansion_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hee_type ON hospital_expansion_events(expansion_type);

ALTER TABLE hospital_expansion_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hee_founder_all ON hospital_expansion_events;
CREATE POLICY hee_founder_all ON hospital_expansion_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: hospital_expansion_uplift_ledger (audit of uplift attribution per month)
CREATE TABLE IF NOT EXISTS hospital_expansion_uplift_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expansion_event_id uuid NOT NULL REFERENCES hospital_expansion_events(id) ON DELETE CASCADE,
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  amc_contract_id uuid REFERENCES amc_contracts(id) ON DELETE SET NULL,
  period_month date NOT NULL,
  baseline_monthly_rupees int NOT NULL DEFAULT 0,
  expanded_monthly_rupees int NOT NULL DEFAULT 0,
  uplift_rupees int NOT NULL DEFAULT 0,
  uplift_realized_pct numeric(6,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_heul_event ON hospital_expansion_uplift_ledger(expansion_event_id);
CREATE INDEX IF NOT EXISTS idx_heul_period ON hospital_expansion_uplift_ledger(period_month DESC);
CREATE INDEX IF NOT EXISTS idx_heul_hospital ON hospital_expansion_uplift_ledger(hospital_org_id);

ALTER TABLE hospital_expansion_uplift_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS heul_founder_all ON hospital_expansion_uplift_ledger;
CREATE POLICY heul_founder_all ON hospital_expansion_uplift_ledger
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_expansion_declared(p_event_id uuid, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_declared', jsonb_build_object('event_id', p_event_id, 'payload', p_payload), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_declared(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_declared(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_expansion_approved(p_event_id uuid, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_approved', jsonb_build_object('event_id', p_event_id, 'payload', p_payload), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_approved(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_approved(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_expansion_rejected(p_event_id uuid, p_reason text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_rejected', jsonb_build_object('event_id', p_event_id, 'reason', p_reason), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_rejected(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_rejected(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_expansion_uplift_recorded(p_ledger_id uuid, p_payload jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'expansion_uplift_recorded', jsonb_build_object('ledger_id', p_ledger_id, 'payload', p_payload), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_expansion_uplift_recorded(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_expansion_uplift_recorded(uuid, jsonb) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_expansion_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total int; v_pending int; v_approved int; v_rejected int; v_issued int;
  v_uplift_pipeline int; v_uplift_approved int; v_uplift_realized int;
  v_new_wing int; v_new_branch int; v_new_floor int; v_new_specialty int;
  v_hospitals int; v_beds int; v_equipment int;
  v_avg_decision_hours numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE status='pending'),
         COUNT(*) FILTER (WHERE status='approved'),
         COUNT(*) FILTER (WHERE status='rejected'),
         COUNT(*) FILTER (WHERE status='contract_issued'),
         COALESCE(SUM(expected_monthly_uplift_rupees) FILTER (WHERE status='pending'),0),
         COALESCE(SUM(expected_monthly_uplift_rupees) FILTER (WHERE status IN ('approved','contract_issued')),0),
         COUNT(*) FILTER (WHERE expansion_type='new_wing'),
         COUNT(*) FILTER (WHERE expansion_type='new_branch'),
         COUNT(*) FILTER (WHERE expansion_type='new_floor'),
         COUNT(*) FILTER (WHERE expansion_type='new_specialty'),
         COUNT(DISTINCT hospital_org_id),
         COALESCE(SUM(declared_beds_added),0),
         COALESCE(SUM(declared_equipment_count),0),
         COALESCE(AVG(EXTRACT(EPOCH FROM (founder_decided_at - created_at))/3600) FILTER (WHERE founder_decided_at IS NOT NULL),0)
  INTO v_total, v_pending, v_approved, v_rejected, v_issued,
       v_uplift_pipeline, v_uplift_approved,
       v_new_wing, v_new_branch, v_new_floor, v_new_specialty,
       v_hospitals, v_beds, v_equipment, v_avg_decision_hours
  FROM hospital_expansion_events;

  SELECT COALESCE(SUM(uplift_rupees),0) INTO v_uplift_realized FROM hospital_expansion_uplift_ledger;

  RETURN jsonb_build_object(
    'total_events', v_total,
    'pending', v_pending,
    'approved', v_approved,
    'rejected', v_rejected,
    'contract_issued', v_issued,
    'pipeline_uplift_rupees', v_uplift_pipeline,
    'approved_uplift_rupees', v_uplift_approved,
    'realized_uplift_rupees', v_uplift_realized,
    'new_wing_count', v_new_wing,
    'new_branch_count', v_new_branch,
    'new_floor_count', v_new_floor,
    'new_specialty_count', v_new_specialty,
    'distinct_hospitals', v_hospitals,
    'declared_beds_added', v_beds,
    'declared_equipment_added', v_equipment,
    'avg_decision_hours', round(v_avg_decision_hours, 2)
  );
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_expansion_pending_queue()
RETURNS TABLE(
  id uuid, hospital_org_id uuid, hospital_name text, expansion_type text,
  expansion_label text, declared_beds_added int, declared_equipment_count int,
  expected_monthly_uplift_rupees int, proposed_amc_tier text,
  go_live_target_at timestamptz, created_at timestamptz, hours_waiting numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.hospital_org_id, o.name, e.expansion_type, e.expansion_label,
         e.declared_beds_added, e.declared_equipment_count,
         e.expected_monthly_uplift_rupees, e.proposed_amc_tier,
         e.go_live_target_at, e.created_at,
         round(EXTRACT(EPOCH FROM (now() - e.created_at))/3600, 1) AS hours_waiting
  FROM hospital_expansion_events e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  WHERE e.status = 'pending'
  ORDER BY e.created_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_pending_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_pending_queue() TO authenticated;

CREATE OR REPLACE FUNCTION founder_expansion_recent_decisions()
RETURNS TABLE(
  id uuid, hospital_name text, expansion_type text, expansion_label text,
  status text, expected_monthly_uplift_rupees int, founder_decision text,
  founder_decided_at timestamptz, decision_hours numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, o.name, e.expansion_type, e.expansion_label, e.status,
         e.expected_monthly_uplift_rupees, e.founder_decision, e.founder_decided_at,
         round(EXTRACT(EPOCH FROM (e.founder_decided_at - e.created_at))/3600, 1) AS decision_hours
  FROM hospital_expansion_events e
  LEFT JOIN organizations o ON o.id = e.hospital_org_id
  WHERE e.founder_decided_at IS NOT NULL
  ORDER BY e.founder_decided_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_recent_decisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_recent_decisions() TO authenticated;

CREATE OR REPLACE FUNCTION founder_expansion_uplift_by_hospital()
RETURNS TABLE(
  hospital_org_id uuid, hospital_name text, hospital_state text,
  expansion_count int, pipeline_uplift_rupees bigint,
  approved_uplift_rupees bigint, realized_uplift_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH ev AS (
    SELECT hospital_org_id,
           COUNT(*)::int AS expansion_count,
           COALESCE(SUM(expected_monthly_uplift_rupees) FILTER (WHERE status='pending'),0)::bigint AS pipeline_uplift,
           COALESCE(SUM(expected_monthly_uplift_rupees) FILTER (WHERE status IN ('approved','contract_issued')),0)::bigint AS approved_uplift
    FROM hospital_expansion_events
    GROUP BY hospital_org_id
  ),
  rl AS (
    SELECT hospital_org_id, COALESCE(SUM(uplift_rupees),0)::bigint AS realized_uplift
    FROM hospital_expansion_uplift_ledger
    GROUP BY hospital_org_id
  )
  SELECT ev.hospital_org_id, o.name, o.state,
         ev.expansion_count, ev.pipeline_uplift, ev.approved_uplift,
         COALESCE(rl.realized_uplift, 0)
  FROM ev
  LEFT JOIN organizations o ON o.id = ev.hospital_org_id
  LEFT JOIN rl ON rl.hospital_org_id = ev.hospital_org_id
  ORDER BY ev.approved_uplift DESC NULLS LAST
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_uplift_by_hospital() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_uplift_by_hospital() TO authenticated;

CREATE OR REPLACE FUNCTION founder_expansion_uplift_ledger_recent()
RETURNS TABLE(
  id uuid, hospital_name text, expansion_label text, period_month date,
  baseline_monthly_rupees int, expanded_monthly_rupees int,
  uplift_rupees int, uplift_realized_pct numeric, created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, o.name, e.expansion_label, l.period_month,
         l.baseline_monthly_rupees, l.expanded_monthly_rupees,
         l.uplift_rupees, l.uplift_realized_pct, l.created_at
  FROM hospital_expansion_uplift_ledger l
  LEFT JOIN hospital_expansion_events e ON e.id = l.expansion_event_id
  LEFT JOIN organizations o ON o.id = l.hospital_org_id
  ORDER BY l.created_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_uplift_ledger_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_uplift_ledger_recent() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_expansion_declare(
  p_hospital_org_id uuid,
  p_source_amc_contract_id uuid,
  p_expansion_type text,
  p_expansion_label text,
  p_declared_beds_added int,
  p_declared_equipment_count int,
  p_expected_monthly_uplift_rupees int,
  p_proposed_amc_tier text,
  p_proposed_equipment_categories text[],
  p_go_live_target_at timestamptz,
  p_notes text
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_expansion_events (
    hospital_org_id, source_amc_contract_id, expansion_type, expansion_label,
    declared_beds_added, declared_equipment_count, expected_monthly_uplift_rupees,
    proposed_amc_tier, proposed_equipment_categories, go_live_target_at,
    declared_by_user_id, notes, status
  ) VALUES (
    p_hospital_org_id, p_source_amc_contract_id, p_expansion_type, p_expansion_label,
    COALESCE(p_declared_beds_added, 0), COALESCE(p_declared_equipment_count, 0),
    COALESCE(p_expected_monthly_uplift_rupees, 0),
    p_proposed_amc_tier, COALESCE(p_proposed_equipment_categories, ARRAY[]::text[]),
    p_go_live_target_at, auth.uid(), p_notes, 'pending'
  ) RETURNING id INTO v_id;

  PERFORM log_founder_expansion_declared(v_id, jsonb_build_object(
    'hospital_org_id', p_hospital_org_id,
    'expansion_type', p_expansion_type,
    'uplift_rupees', p_expected_monthly_uplift_rupees
  ));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_declare(uuid, uuid, text, text, int, int, int, text, text[], timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_declare(uuid, uuid, text, text, int, int, int, text, text[], timestamptz, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_expansion_approve(p_event_id uuid, p_decision text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_expansion_events
  SET status = 'approved',
      founder_decision = p_decision,
      founder_decided_at = now(),
      founder_decided_by = auth.uid(),
      updated_at = now()
  WHERE id = p_event_id AND status = 'pending';

  IF NOT FOUND THEN RAISE EXCEPTION 'event_not_pending'; END IF;

  PERFORM log_founder_expansion_approved(p_event_id, jsonb_build_object('decision', p_decision));
END $$;
REVOKE EXECUTE ON FUNCTION founder_expansion_approve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_expansion_approve(uuid, text) TO authenticated;

COMMIT;