BEGIN;

-- ============================================================
-- r1546: Engineer Accident & Injury Ledger
-- Tracks on-site engineer injuries during repair jobs,
-- medical claim status, lessons-learned ladder, and safety
-- rating impact per engineer.
-- ============================================================

CREATE TABLE IF NOT EXISTS engineer_accident_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES repair_jobs(id) ON DELETE SET NULL,
  incident_at timestamptz NOT NULL DEFAULT now(),
  incident_type text NOT NULL CHECK (incident_type IN ('cut','burn','shock','fall','chemical','strain','equipment_strike','near_miss','other')),
  severity text NOT NULL CHECK (severity IN ('near_miss','minor','moderate','severe','critical')),
  body_part text,
  description text NOT NULL,
  first_aid_given boolean NOT NULL DEFAULT false,
  hospitalized boolean NOT NULL DEFAULT false,
  days_lost integer NOT NULL DEFAULT 0,
  medical_claim_amount_rupees integer NOT NULL DEFAULT 0,
  medical_claim_status text NOT NULL DEFAULT 'none' CHECK (medical_claim_status IN ('none','submitted','approved','paid','rejected')),
  medical_claim_settled_at timestamptz,
  lesson_learned text,
  lesson_ladder_rank integer CHECK (lesson_ladder_rank BETWEEN 1 AND 5),
  safety_rating_delta numeric(4,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','closed')),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eai_engineer ON engineer_accident_incidents(engineer_id);
CREATE INDEX IF NOT EXISTS idx_eai_repair_job ON engineer_accident_incidents(repair_job_id);
CREATE INDEX IF NOT EXISTS idx_eai_incident_at ON engineer_accident_incidents(incident_at DESC);
CREATE INDEX IF NOT EXISTS idx_eai_severity ON engineer_accident_incidents(severity);
CREATE INDEX IF NOT EXISTS idx_eai_status ON engineer_accident_incidents(status);

ALTER TABLE engineer_accident_incidents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eai_founder_all ON engineer_accident_incidents;
CREATE POLICY eai_founder_all ON engineer_accident_incidents
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS engineer_safety_scorecards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  incidents_count integer NOT NULL DEFAULT 0,
  near_misses integer NOT NULL DEFAULT 0,
  days_lost_total integer NOT NULL DEFAULT 0,
  safety_score numeric(5,2) NOT NULL DEFAULT 100,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_essc_engineer ON engineer_safety_scorecards(engineer_id);
CREATE INDEX IF NOT EXISTS idx_essc_period ON engineer_safety_scorecards(period_start, period_end);

ALTER TABLE engineer_safety_scorecards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS essc_founder_all ON engineer_safety_scorecards;
CREATE POLICY essc_founder_all ON engineer_safety_scorecards
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- Helpers (founder_action_log writers)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_accident_logged(p_incident_id uuid, p_engineer_id uuid, p_severity text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'accident_logged',
          jsonb_build_object('incident_id', p_incident_id, 'engineer_id', p_engineer_id, 'severity', p_severity));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_accident_logged(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_accident_logged(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_claim_status_changed(p_incident_id uuid, p_new_status text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'claim_status_changed',
          jsonb_build_object('incident_id', p_incident_id, 'new_status', p_new_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_claim_status_changed(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_claim_status_changed(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_lesson_recorded(p_incident_id uuid, p_rank integer)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'lesson_recorded',
          jsonb_build_object('incident_id', p_incident_id, 'ladder_rank', p_rank));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_lesson_recorded(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_lesson_recorded(uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_scorecard_built(p_engineer_id uuid, p_score numeric)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'safety_scorecard_built',
          jsonb_build_object('engineer_id', p_engineer_id, 'score', p_score));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_scorecard_built(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_scorecard_built(uuid, numeric) TO authenticated;

-- ============================================================
-- Read RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_accident_ledger_kpis()
RETURNS TABLE(
  total_incidents bigint,
  open_incidents bigint,
  near_miss_count bigint,
  critical_count bigint,
  severe_count bigint,
  moderate_count bigint,
  minor_count bigint,
  hospitalized_count bigint,
  days_lost_total bigint,
  claims_submitted bigint,
  claims_approved bigint,
  claims_paid bigint,
  claims_rejected bigint,
  total_claim_payout_rupees bigint,
  engineers_with_incident bigint,
  avg_lesson_rank numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE status = 'open')::bigint,
    COUNT(*) FILTER (WHERE severity = 'near_miss')::bigint,
    COUNT(*) FILTER (WHERE severity = 'critical')::bigint,
    COUNT(*) FILTER (WHERE severity = 'severe')::bigint,
    COUNT(*) FILTER (WHERE severity = 'moderate')::bigint,
    COUNT(*) FILTER (WHERE severity = 'minor')::bigint,
    COUNT(*) FILTER (WHERE hospitalized)::bigint,
    COALESCE(SUM(days_lost), 0)::bigint,
    COUNT(*) FILTER (WHERE medical_claim_status = 'submitted')::bigint,
    COUNT(*) FILTER (WHERE medical_claim_status = 'approved')::bigint,
    COUNT(*) FILTER (WHERE medical_claim_status = 'paid')::bigint,
    COUNT(*) FILTER (WHERE medical_claim_status = 'rejected')::bigint,
    COALESCE(SUM(medical_claim_amount_rupees) FILTER (WHERE medical_claim_status = 'paid'), 0)::bigint,
    COUNT(DISTINCT engineer_id)::bigint,
    AVG(lesson_ladder_rank)::numeric
  FROM engineer_accident_incidents;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_accident_ledger_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_accident_ledger_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_accident_incidents_recent(p_limit integer DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  repair_job_id uuid,
  incident_at timestamptz,
  incident_type text,
  severity text,
  body_part text,
  description text,
  hospitalized boolean,
  days_lost integer,
  medical_claim_amount_rupees integer,
  medical_claim_status text,
  status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id, i.engineer_id, p.full_name AS engineer_name, i.repair_job_id,
    i.incident_at, i.incident_type, i.severity, i.body_part, i.description,
    i.hospitalized, i.days_lost, i.medical_claim_amount_rupees,
    i.medical_claim_status, i.status
  FROM engineer_accident_incidents i
  LEFT JOIN engineers e ON e.id = i.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY i.incident_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_accident_incidents_recent(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_accident_incidents_recent(integer) TO authenticated;

CREATE OR REPLACE FUNCTION founder_accident_by_engineer(p_limit integer DEFAULT 50)
RETURNS TABLE(
  engineer_id uuid,
  engineer_name text,
  cached_highest_tier text,
  incidents_count bigint,
  near_misses bigint,
  hospitalizations bigint,
  days_lost_total bigint,
  total_claims_paid_rupees bigint,
  last_incident_at timestamptz,
  safety_rating_impact numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.engineer_id,
    p.full_name AS engineer_name,
    e.cached_highest_tier,
    COUNT(*)::bigint AS incidents_count,
    COUNT(*) FILTER (WHERE i.severity = 'near_miss')::bigint AS near_misses,
    COUNT(*) FILTER (WHERE i.hospitalized)::bigint AS hospitalizations,
    COALESCE(SUM(i.days_lost), 0)::bigint AS days_lost_total,
    COALESCE(SUM(i.medical_claim_amount_rupees) FILTER (WHERE i.medical_claim_status = 'paid'), 0)::bigint AS total_claims_paid_rupees,
    MAX(i.incident_at) AS last_incident_at,
    COALESCE(SUM(i.safety_rating_delta), 0)::numeric AS safety_rating_impact
  FROM engineer_accident_incidents i
  LEFT JOIN engineers e ON e.id = i.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  GROUP BY i.engineer_id, p.full_name, e.cached_highest_tier
  ORDER BY incidents_count DESC, last_incident_at DESC NULLS LAST
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_accident_by_engineer(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_accident_by_engineer(integer) TO authenticated;

CREATE OR REPLACE FUNCTION founder_accident_claim_pipeline()
RETURNS TABLE(
  medical_claim_status text,
  incident_count bigint,
  total_amount_rupees bigint,
  avg_days_to_settle numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.medical_claim_status,
    COUNT(*)::bigint AS incident_count,
    COALESCE(SUM(i.medical_claim_amount_rupees), 0)::bigint AS total_amount_rupees,
    AVG(EXTRACT(EPOCH FROM (i.medical_claim_settled_at - i.incident_at)) / 86400.0)::numeric AS avg_days_to_settle
  FROM engineer_accident_incidents i
  GROUP BY i.medical_claim_status
  ORDER BY incident_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_accident_claim_pipeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_accident_claim_pipeline() TO authenticated;

CREATE OR REPLACE FUNCTION founder_accident_lesson_ladder()
RETURNS TABLE(
  lesson_ladder_rank integer,
  incident_count bigint,
  hospitalized_count bigint,
  days_lost_total bigint,
  sample_lesson text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.lesson_ladder_rank,
    COUNT(*)::bigint AS incident_count,
    COUNT(*) FILTER (WHERE i.hospitalized)::bigint AS hospitalized_count,
    COALESCE(SUM(i.days_lost), 0)::bigint AS days_lost_total,
    (ARRAY_AGG(i.lesson_learned ORDER BY i.incident_at DESC) FILTER (WHERE i.lesson_learned IS NOT NULL))[1] AS sample_lesson
  FROM engineer_accident_incidents i
  WHERE i.lesson_ladder_rank IS NOT NULL
  GROUP BY i.lesson_ladder_rank
  ORDER BY i.lesson_ladder_rank ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_accident_lesson_ladder() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_accident_lesson_ladder() TO authenticated;

CREATE OR REPLACE FUNCTION founder_accident_by_type_severity()
RETURNS TABLE(
  incident_type text,
  severity text,
  incident_count bigint,
  days_lost_total bigint,
  total_claim_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.incident_type,
    i.severity,
    COUNT(*)::bigint,
    COALESCE(SUM(i.days_lost), 0)::bigint,
    COALESCE(SUM(i.medical_claim_amount_rupees), 0)::bigint
  FROM engineer_accident_incidents i
  GROUP BY i.incident_type, i.severity
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_accident_by_type_severity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_accident_by_type_severity() TO authenticated;

-- ============================================================
-- Write RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_accident_log_incident(
  p_engineer_id uuid,
  p_repair_job_id uuid,
  p_incident_type text,
  p_severity text,
  p_body_part text,
  p_description text,
  p_hospitalized boolean,
  p_days_lost integer,
  p_claim_amount_rupees integer
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_delta numeric;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_delta := CASE p_severity
    WHEN 'near_miss' THEN -0.5
    WHEN 'minor' THEN -1.0
    WHEN 'moderate' THEN -2.5
    WHEN 'severe' THEN -5.0
    WHEN 'critical' THEN -10.0
    ELSE 0
  END;
  INSERT INTO engineer_accident_incidents(
    engineer_id, repair_job_id, incident_type, severity, body_part,
    description, hospitalized, days_lost, medical_claim_amount_rupees,
    medical_claim_status, safety_rating_delta
  ) VALUES (
    p_engineer_id, p_repair_job_id, p_incident_type, p_severity, p_body_part,
    p_description, p_hospitalized, p_days_lost, p_claim_amount_rupees,
    CASE WHEN p_claim_amount_rupees > 0 THEN 'submitted' ELSE 'none' END,
    v_delta
  ) RETURNING id INTO v_id;
  PERFORM log_founder_accident_logged(v_id, p_engineer_id, p_severity);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_accident_log_incident(uuid, uuid, text, text, text, text, boolean, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_accident_log_incident(uuid, uuid, text, text, text, text, boolean, integer, integer) TO authenticated;

COMMIT;