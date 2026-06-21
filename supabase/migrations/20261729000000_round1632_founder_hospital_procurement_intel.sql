BEGIN;

-- =========================================================================
-- r1632 — Founder Hospital Procurement Intelligence
-- Per-hospital procurement officer profiles + decision-maker map
-- =========================================================================

CREATE TABLE IF NOT EXISTS hospital_procurement_officers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  officer_name text NOT NULL,
  officer_role text NOT NULL CHECK (officer_role IN ('procurement_head','biomed_lead','finance_lead','administrator','department_head','ceo','cfo','other')),
  decision_authority text NOT NULL CHECK (decision_authority IN ('approver','recommender','influencer','gatekeeper','signer')),
  budget_authority_rupees bigint DEFAULT 0,
  preferred_contact text CHECK (preferred_contact IN ('phone','email','whatsapp','in_person')),
  email text,
  phone text,
  preferences_notes text,
  budget_cycle_month_start int CHECK (budget_cycle_month_start BETWEEN 1 AND 12),
  budget_cycle_month_end int CHECK (budget_cycle_month_end BETWEEN 1 AND 12),
  last_engaged_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpo_hospital ON hospital_procurement_officers(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hpo_authority ON hospital_procurement_officers(decision_authority);
CREATE INDEX IF NOT EXISTS idx_hpo_role ON hospital_procurement_officers(officer_role);

ALTER TABLE hospital_procurement_officers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hpo_founder_only ON hospital_procurement_officers;
CREATE POLICY hpo_founder_only ON hospital_procurement_officers
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS hospital_procurement_signals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  officer_id uuid REFERENCES hospital_procurement_officers(id) ON DELETE SET NULL,
  signal_type text NOT NULL CHECK (signal_type IN ('budget_release','rfp_published','tender_won','renewal_window','equipment_aging','expansion','new_dept','staff_change')),
  signal_strength text NOT NULL CHECK (signal_strength IN ('weak','moderate','strong','confirmed')),
  estimated_value_rupees bigint DEFAULT 0,
  observed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  source text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hps_hospital ON hospital_procurement_signals(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hps_observed ON hospital_procurement_signals(observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_hps_type ON hospital_procurement_signals(signal_type);

ALTER TABLE hospital_procurement_signals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hps_founder_only ON hospital_procurement_signals;
CREATE POLICY hps_founder_only ON hospital_procurement_signals
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION list_hospital_procurement_intel()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  state text,
  officer_count int,
  approver_count int,
  avg_budget_authority_rupees bigint,
  active_signal_count int,
  total_signal_value_rupees bigint,
  last_engaged_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    o.id,
    o.name,
    o.state,
    COALESCE(officer_stats.officer_count, 0)::int,
    COALESCE(officer_stats.approver_count, 0)::int,
    COALESCE(officer_stats.avg_budget, 0)::bigint,
    COALESCE(signal_stats.signal_count, 0)::int,
    COALESCE(signal_stats.total_value, 0)::bigint,
    officer_stats.last_engaged
  FROM organizations o
  LEFT JOIN (
    SELECT
      hpo.hospital_org_id,
      COUNT(*)::int AS officer_count,
      COUNT(*) FILTER (WHERE hpo.decision_authority IN ('approver','signer'))::int AS approver_count,
      AVG(hpo.budget_authority_rupees)::bigint AS avg_budget,
      MAX(hpo.last_engaged_at) AS last_engaged
    FROM hospital_procurement_officers hpo
    GROUP BY hpo.hospital_org_id
  ) officer_stats ON officer_stats.hospital_org_id = o.id
  LEFT JOIN (
    SELECT
      hps.hospital_org_id,
      COUNT(*)::int AS signal_count,
      SUM(hps.estimated_value_rupees)::bigint AS total_value
    FROM hospital_procurement_signals hps
    WHERE hps.expires_at IS NULL OR hps.expires_at > now()
    GROUP BY hps.hospital_org_id
  ) signal_stats ON signal_stats.hospital_org_id = o.id
  WHERE COALESCE(officer_stats.officer_count, 0) > 0 OR COALESCE(signal_stats.signal_count, 0) > 0
  ORDER BY COALESCE(signal_stats.total_value, 0) DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_hospital_procurement_intel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_hospital_procurement_intel() TO authenticated;

CREATE OR REPLACE FUNCTION list_decision_maker_map(p_hospital_org_id uuid)
RETURNS TABLE (
  officer_id uuid,
  officer_name text,
  officer_role text,
  decision_authority text,
  budget_authority_rupees bigint,
  preferred_contact text,
  email text,
  phone text,
  last_engaged_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    hpo.id,
    hpo.officer_name,
    hpo.officer_role,
    hpo.decision_authority,
    hpo.budget_authority_rupees,
    hpo.preferred_contact,
    hpo.email,
    hpo.phone,
    hpo.last_engaged_at
  FROM hospital_procurement_officers hpo
  WHERE hpo.hospital_org_id = p_hospital_org_id
  ORDER BY
    CASE hpo.decision_authority
      WHEN 'signer' THEN 1
      WHEN 'approver' THEN 2
      WHEN 'recommender' THEN 3
      WHEN 'influencer' THEN 4
      WHEN 'gatekeeper' THEN 5
    END,
    hpo.budget_authority_rupees DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_decision_maker_map(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_decision_maker_map(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION list_active_procurement_signals()
RETURNS TABLE (
  signal_id uuid,
  hospital_org_id uuid,
  hospital_name text,
  signal_type text,
  signal_strength text,
  estimated_value_rupees bigint,
  observed_at timestamptz,
  expires_at timestamptz,
  source text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    hps.id,
    hps.hospital_org_id,
    o.name,
    hps.signal_type,
    hps.signal_strength,
    hps.estimated_value_rupees,
    hps.observed_at,
    hps.expires_at,
    hps.source
  FROM hospital_procurement_signals hps
  JOIN organizations o ON o.id = hps.hospital_org_id
  WHERE hps.expires_at IS NULL OR hps.expires_at > now()
  ORDER BY
    CASE hps.signal_strength
      WHEN 'confirmed' THEN 1
      WHEN 'strong' THEN 2
      WHEN 'moderate' THEN 3
      WHEN 'weak' THEN 4
    END,
    hps.estimated_value_rupees DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_active_procurement_signals() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_active_procurement_signals() TO authenticated;

CREATE OR REPLACE FUNCTION summarize_budget_timing_windows()
RETURNS TABLE (
  budget_month int,
  hospital_count int,
  total_budget_authority_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    hpo.budget_cycle_month_start,
    COUNT(DISTINCT hpo.hospital_org_id)::int,
    SUM(hpo.budget_authority_rupees)::bigint
  FROM hospital_procurement_officers hpo
  WHERE hpo.budget_cycle_month_start IS NOT NULL
  GROUP BY hpo.budget_cycle_month_start
  ORDER BY hpo.budget_cycle_month_start;
END;
$$;

REVOKE EXECUTE ON FUNCTION summarize_budget_timing_windows() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION summarize_budget_timing_windows() TO authenticated;

-- =========================================================================
-- WRITE RPCs (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION upsert_procurement_officer(
  p_hospital_org_id uuid,
  p_officer_name text,
  p_officer_role text,
  p_decision_authority text,
  p_budget_authority_rupees bigint,
  p_preferred_contact text,
  p_email text,
  p_phone text,
  p_preferences_notes text,
  p_budget_cycle_month_start int,
  p_budget_cycle_month_end int
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_procurement_officers (
    hospital_org_id, officer_name, officer_role, decision_authority,
    budget_authority_rupees, preferred_contact, email, phone,
    preferences_notes, budget_cycle_month_start, budget_cycle_month_end
  ) VALUES (
    p_hospital_org_id, p_officer_name, p_officer_role, p_decision_authority,
    COALESCE(p_budget_authority_rupees, 0), p_preferred_contact, p_email, p_phone,
    p_preferences_notes, p_budget_cycle_month_start, p_budget_cycle_month_end
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'upsert_procurement_officer',
          jsonb_build_object('officer_id', v_id, 'hospital_org_id', p_hospital_org_id), now());

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION upsert_procurement_officer(uuid, text, text, text, bigint, text, text, text, text, int, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION upsert_procurement_officer(uuid, text, text, text, bigint, text, text, text, text, int, int) TO authenticated;

CREATE OR REPLACE FUNCTION log_procurement_signal(
  p_hospital_org_id uuid,
  p_officer_id uuid,
  p_signal_type text,
  p_signal_strength text,
  p_estimated_value_rupees bigint,
  p_expires_at timestamptz,
  p_source text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_procurement_signals (
    hospital_org_id, officer_id, signal_type, signal_strength,
    estimated_value_rupees, expires_at, source, notes
  ) VALUES (
    p_hospital_org_id, p_officer_id, p_signal_type, p_signal_strength,
    COALESCE(p_estimated_value_rupees, 0), p_expires_at, p_source, p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_procurement_signal',
          jsonb_build_object('signal_id', v_id, 'hospital_org_id', p_hospital_org_id, 'signal_type', p_signal_type), now());

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_procurement_signal(uuid, uuid, text, text, bigint, timestamptz, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_procurement_signal(uuid, uuid, text, text, bigint, timestamptz, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION mark_officer_engaged(p_officer_id uuid, p_notes text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_procurement_officers
  SET last_engaged_at = now(),
      notes = COALESCE(p_notes, notes),
      updated_at = now()
  WHERE id = p_officer_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_officer_engaged',
          jsonb_build_object('officer_id', p_officer_id), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION mark_officer_engaged(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION mark_officer_engaged(uuid, text) TO authenticated;

-- =========================================================================
-- log_founder_* helpers
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_intel_review(p_hospital_org_id uuid, p_summary text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_intel_review',
          jsonb_build_object('hospital_org_id', p_hospital_org_id, 'summary', p_summary), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_intel_review(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_intel_review(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_decision_map_export(p_hospital_org_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_decision_map_export',
          jsonb_build_object('hospital_org_id', p_hospital_org_id), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_decision_map_export(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_decision_map_export(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_signal_followup(p_signal_id uuid, p_action text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_signal_followup',
          jsonb_build_object('signal_id', p_signal_id, 'action', p_action), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_signal_followup(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_signal_followup(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_procurement_brief(p_brief_label text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_founder_procurement_brief',
          jsonb_build_object('label', p_brief_label, 'payload', COALESCE(p_payload, '{}'::jsonb)), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_procurement_brief(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_procurement_brief(text, jsonb) TO authenticated;

COMMIT;