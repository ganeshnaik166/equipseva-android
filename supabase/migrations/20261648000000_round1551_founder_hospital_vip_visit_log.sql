BEGIN;

-- ============================================================================
-- r1551 — Founder Hospital VIP Visit Log
-- Track every visit founder/CTO/sales made to top-50 hospitals.
-- Purpose taxonomy, outcome, next-visit due cadence.
-- ============================================================================

-- Table 1: visit log
CREATE TABLE IF NOT EXISTS founder_hospital_vip_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  visitor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  visitor_role text NOT NULL CHECK (visitor_role IN ('founder','cto','sales','cs','other')),
  visit_purpose text NOT NULL CHECK (visit_purpose IN (
    'intro_pitch','amc_renewal','escalation_recovery','qbr','tech_demo',
    'kol_relationship','contract_signing','executive_briefing','post_incident','social_courtesy'
  )),
  visit_date date NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 30 CHECK (duration_minutes > 0),
  attendees_count integer NOT NULL DEFAULT 1 CHECK (attendees_count >= 1),
  hospital_attendees text,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','blocker','closed_won','closed_lost')),
  outcome_notes text,
  next_visit_due date,
  follow_up_owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  estimated_revenue_lift_rupees integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_fhvv_hospital ON founder_hospital_vip_visits(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_fhvv_visit_date ON founder_hospital_vip_visits(visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_fhvv_next_due ON founder_hospital_vip_visits(next_visit_due) WHERE next_visit_due IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fhvv_visitor ON founder_hospital_vip_visits(visitor_user_id);

ALTER TABLE founder_hospital_vip_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhvv_founder_only ON founder_hospital_vip_visits;
CREATE POLICY fhvv_founder_only ON founder_hospital_vip_visits
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: top-50 hospital ranking snapshot (cadence target per hospital)
CREATE TABLE IF NOT EXISTS founder_hospital_vip_targets (
  hospital_org_id uuid PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
  vip_rank integer NOT NULL CHECK (vip_rank BETWEEN 1 AND 50),
  target_visit_cadence_days integer NOT NULL DEFAULT 90 CHECK (target_visit_cadence_days > 0),
  account_owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  strategic_notes text,
  added_at timestamptz NOT NULL DEFAULT now(),
  added_by uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_fhvt_rank ON founder_hospital_vip_targets(vip_rank);

ALTER TABLE founder_hospital_vip_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhvt_founder_only ON founder_hospital_vip_targets;
CREATE POLICY fhvt_founder_only ON founder_hospital_vip_targets
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- Logging helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_vip_visit_logged(p_visit_id uuid, p_hospital uuid, p_purpose text, p_outcome text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_visit_logged',
    jsonb_build_object('visit_id', p_visit_id, 'hospital_org_id', p_hospital, 'purpose', p_purpose, 'outcome', p_outcome));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_vip_visit_logged(uuid, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_vip_visit_logged(uuid, uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_vip_target_set(p_hospital uuid, p_rank integer, p_cadence integer)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_target_set',
    jsonb_build_object('hospital_org_id', p_hospital, 'vip_rank', p_rank, 'cadence_days', p_cadence));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_vip_target_set(uuid, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_vip_target_set(uuid, integer, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_vip_visit_deleted(p_visit_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_visit_deleted',
    jsonb_build_object('visit_id', p_visit_id));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_vip_visit_deleted(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_vip_visit_deleted(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_vip_followup_owner_changed(p_visit_id uuid, p_owner uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_followup_owner_changed',
    jsonb_build_object('visit_id', p_visit_id, 'new_owner', p_owner));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_vip_followup_owner_changed(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_vip_followup_owner_changed(uuid, uuid) TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE SECDEF, founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_vip_visit_log_entry(
  p_hospital_org_id uuid,
  p_visitor_role text,
  p_visit_purpose text,
  p_visit_date date,
  p_duration_minutes integer,
  p_attendees_count integer,
  p_hospital_attendees text,
  p_outcome text,
  p_outcome_notes text,
  p_next_visit_due date,
  p_estimated_revenue_lift_rupees integer
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_hospital_vip_visits(
    hospital_org_id, visitor_user_id, visitor_role, visit_purpose, visit_date,
    duration_minutes, attendees_count, hospital_attendees, outcome, outcome_notes,
    next_visit_due, estimated_revenue_lift_rupees
  ) VALUES (
    p_hospital_org_id, auth.uid(), p_visitor_role, p_visit_purpose, p_visit_date,
    COALESCE(p_duration_minutes, 30), COALESCE(p_attendees_count, 1), p_hospital_attendees,
    p_outcome, p_outcome_notes, p_next_visit_due, COALESCE(p_estimated_revenue_lift_rupees, 0)
  ) RETURNING id INTO v_id;
  PERFORM log_founder_vip_visit_logged(v_id, p_hospital_org_id, p_visit_purpose, p_outcome);
  RETURN v_id;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_visit_log_entry(uuid, text, text, date, integer, integer, text, text, text, date, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_visit_log_entry(uuid, text, text, date, integer, integer, text, text, text, date, integer) TO authenticated;

CREATE OR REPLACE FUNCTION founder_vip_target_upsert(
  p_hospital_org_id uuid, p_vip_rank integer, p_cadence_days integer, p_account_owner uuid, p_notes text
)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_hospital_vip_targets(hospital_org_id, vip_rank, target_visit_cadence_days, account_owner_user_id, strategic_notes)
  VALUES (p_hospital_org_id, p_vip_rank, COALESCE(p_cadence_days, 90), p_account_owner, p_notes)
  ON CONFLICT (hospital_org_id) DO UPDATE SET
    vip_rank = EXCLUDED.vip_rank,
    target_visit_cadence_days = EXCLUDED.target_visit_cadence_days,
    account_owner_user_id = EXCLUDED.account_owner_user_id,
    strategic_notes = EXCLUDED.strategic_notes;
  PERFORM log_founder_vip_target_set(p_hospital_org_id, p_vip_rank, COALESCE(p_cadence_days, 90));
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_target_upsert(uuid, integer, integer, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_target_upsert(uuid, integer, integer, uuid, text) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_vip_visit_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_visits', (SELECT count(*) FROM founder_hospital_vip_visits),
    'visits_30d', (SELECT count(*) FROM founder_hospital_vip_visits WHERE visit_date >= current_date - 30),
    'visits_90d', (SELECT count(*) FROM founder_hospital_vip_visits WHERE visit_date >= current_date - 90),
    'visits_ytd', (SELECT count(*) FROM founder_hospital_vip_visits WHERE visit_date >= date_trunc('year', current_date)::date),
    'unique_hospitals_visited', (SELECT count(DISTINCT hospital_org_id) FROM founder_hospital_vip_visits),
    'vip_targets_count', (SELECT count(*) FROM founder_hospital_vip_targets),
    'overdue_visits', (SELECT count(*) FROM founder_hospital_vip_visits WHERE next_visit_due IS NOT NULL AND next_visit_due < current_date),
    'due_next_30d', (SELECT count(*) FROM founder_hospital_vip_visits WHERE next_visit_due BETWEEN current_date AND current_date + 30),
    'positive_outcome_pct', COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE outcome IN ('positive','closed_won')) / NULLIF(count(*),0), 1) FROM founder_hospital_vip_visits WHERE visit_date >= current_date - 90), 0),
    'closed_won_count', (SELECT count(*) FROM founder_hospital_vip_visits WHERE outcome = 'closed_won'),
    'closed_lost_count', (SELECT count(*) FROM founder_hospital_vip_visits WHERE outcome = 'closed_lost'),
    'blocker_count', (SELECT count(*) FROM founder_hospital_vip_visits WHERE outcome = 'blocker' AND visit_date >= current_date - 90),
    'avg_duration_minutes', (SELECT COALESCE(round(avg(duration_minutes)), 0) FROM founder_hospital_vip_visits WHERE visit_date >= current_date - 90),
    'founder_visit_share_pct', COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE visitor_role = 'founder') / NULLIF(count(*),0), 1) FROM founder_hospital_vip_visits WHERE visit_date >= current_date - 90), 0),
    'estimated_pipeline_rupees', (SELECT COALESCE(sum(estimated_revenue_lift_rupees), 0) FROM founder_hospital_vip_visits WHERE visit_date >= current_date - 180 AND outcome IN ('positive','closed_won')),
    'targets_never_visited', (SELECT count(*) FROM founder_hospital_vip_targets t WHERE NOT EXISTS (SELECT 1 FROM founder_hospital_vip_visits v WHERE v.hospital_org_id = t.hospital_org_id))
  ) INTO v;
  RETURN v;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_visit_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_visit_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_vip_recent_visits(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid, hospital_org_id uuid, hospital_name text, visitor_role text, visit_purpose text,
  visit_date date, duration_minutes integer, outcome text, next_visit_due date,
  days_until_due integer, estimated_revenue_lift_rupees integer
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_org_id, o.name, v.visitor_role, v.visit_purpose,
    v.visit_date, v.duration_minutes, v.outcome, v.next_visit_due,
    CASE WHEN v.next_visit_due IS NULL THEN NULL ELSE (v.next_visit_due - current_date)::integer END,
    v.estimated_revenue_lift_rupees
  FROM founder_hospital_vip_visits v
  JOIN organizations o ON o.id = v.hospital_org_id
  ORDER BY v.visit_date DESC, v.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_recent_visits(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_recent_visits(integer) TO authenticated;

CREATE OR REPLACE FUNCTION founder_vip_overdue_followups()
RETURNS TABLE(
  visit_id uuid, hospital_org_id uuid, hospital_name text, last_visit_date date,
  next_visit_due date, days_overdue integer, last_outcome text, last_purpose text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.hospital_org_id, o.name, v.visit_date, v.next_visit_due,
    (current_date - v.next_visit_due)::integer, v.outcome, v.visit_purpose
  FROM founder_hospital_vip_visits v
  JOIN organizations o ON o.id = v.hospital_org_id
  WHERE v.next_visit_due IS NOT NULL AND v.next_visit_due < current_date
  ORDER BY v.next_visit_due ASC
  LIMIT 100;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_overdue_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_overdue_followups() TO authenticated;

CREATE OR REPLACE FUNCTION founder_vip_purpose_breakdown()
RETURNS TABLE(visit_purpose text, visit_count bigint, positive_count bigint, avg_duration integer, total_pipeline_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.visit_purpose,
    count(*)::bigint,
    count(*) FILTER (WHERE v.outcome IN ('positive','closed_won'))::bigint,
    COALESCE(round(avg(v.duration_minutes))::integer, 0),
    COALESCE(sum(v.estimated_revenue_lift_rupees)::bigint, 0)
  FROM founder_hospital_vip_visits v
  WHERE v.visit_date >= current_date - 180
  GROUP BY v.visit_purpose
  ORDER BY count(*) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_purpose_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_purpose_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION founder_vip_hospital_coverage()
RETURNS TABLE(
  hospital_org_id uuid, hospital_name text, vip_rank integer, cadence_days integer,
  last_visit_date date, days_since_last_visit integer, total_visits bigint, cadence_status text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.hospital_org_id, o.name, t.vip_rank, t.target_visit_cadence_days,
    lv.last_visit_date,
    CASE WHEN lv.last_visit_date IS NULL THEN NULL ELSE (current_date - lv.last_visit_date)::integer END,
    COALESCE(lv.total_visits, 0),
    CASE
      WHEN lv.last_visit_date IS NULL THEN 'never_visited'
      WHEN (current_date - lv.last_visit_date) > t.target_visit_cadence_days THEN 'overdue'
      WHEN (current_date - lv.last_visit_date) > (t.target_visit_cadence_days * 0.75)::integer THEN 'due_soon'
      ELSE 'on_track'
    END
  FROM founder_hospital_vip_targets t
  JOIN organizations o ON o.id = t.hospital_org_id
  LEFT JOIN LATERAL (
    SELECT max(v.visit_date) AS last_visit_date, count(*) AS total_visits
    FROM founder_hospital_vip_visits v
    WHERE v.hospital_org_id = t.hospital_org_id
  ) lv ON true
  ORDER BY t.vip_rank ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_hospital_coverage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_hospital_coverage() TO authenticated;

CREATE OR REPLACE FUNCTION founder_vip_visitor_leaderboard()
RETURNS TABLE(
  visitor_user_id uuid, visitor_email text, visitor_role text, visit_count bigint,
  unique_hospitals bigint, positive_outcome_count bigint, total_pipeline_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.visitor_user_id, u.email::text, v.visitor_role,
    count(*)::bigint,
    count(DISTINCT v.hospital_org_id)::bigint,
    count(*) FILTER (WHERE v.outcome IN ('positive','closed_won'))::bigint,
    COALESCE(sum(v.estimated_revenue_lift_rupees)::bigint, 0)
  FROM founder_hospital_vip_visits v
  LEFT JOIN auth.users u ON u.id = v.visitor_user_id
  WHERE v.visit_date >= current_date - 180
  GROUP BY v.visitor_user_id, u.email, v.visitor_role
  ORDER BY count(*) DESC
  LIMIT 25;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_vip_visitor_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_vip_visitor_leaderboard() TO authenticated;

COMMIT;