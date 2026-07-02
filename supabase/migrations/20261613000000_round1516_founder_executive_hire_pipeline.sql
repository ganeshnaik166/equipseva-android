BEGIN;

-- =====================================================================
-- r1516 — Founder Executive Hire Pipeline
-- VP/C-level role tracking separate from engineer hiring (r1346/r1432).
-- 7-stage funnel: source -> screen -> onsite -> offer -> signed -> ramped -> departed
-- =====================================================================

CREATE TABLE IF NOT EXISTS founder_exec_candidates_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_name text NOT NULL,
  candidate_email text,
  target_role text NOT NULL,           -- e.g. 'VP Eng', 'CTO', 'COO', 'VP Sales'
  role_level text NOT NULL CHECK (role_level IN ('vp','svp','c_level')),
  source_channel text NOT NULL CHECK (source_channel IN ('inbound','referral','recruiter','outbound','network')),
  stage text NOT NULL DEFAULT 'source' CHECK (stage IN ('source','screen','onsite','offer','signed','ramped','departed')),
  comp_target_lakhs numeric(10,2),     -- expected annual comp in lakhs INR
  comp_offered_lakhs numeric(10,2),
  equity_bps int,                      -- basis points of equity offered
  calibration_score int CHECK (calibration_score BETWEEN 1 AND 5),
  calibration_notes text,
  sourced_at timestamptz NOT NULL DEFAULT now(),
  screened_at timestamptz,
  onsite_at timestamptz,
  offered_at timestamptz,
  signed_at timestamptz,
  ramped_at timestamptz,
  departed_at timestamptz,
  departure_reason text,
  recruiter_owner_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exec_cand_v2_stage ON founder_exec_candidates_v2 (stage);
CREATE INDEX IF NOT EXISTS idx_exec_cand_v2_role_level ON founder_exec_candidates_v2 (role_level);
CREATE INDEX IF NOT EXISTS idx_exec_cand_v2_sourced_at ON founder_exec_candidates_v2 (sourced_at DESC);

ALTER TABLE founder_exec_candidates_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS exec_cand_v2_founder_only ON founder_exec_candidates_v2;
CREATE POLICY exec_cand_v2_founder_only ON founder_exec_candidates_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_exec_stage_events_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES founder_exec_candidates_v2(id) ON DELETE CASCADE,
  from_stage text,
  to_stage text NOT NULL,
  event_at timestamptz NOT NULL DEFAULT now(),
  actor_email text,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_exec_stage_v2_cand ON founder_exec_stage_events_v2 (candidate_id, event_at DESC);
CREATE INDEX IF NOT EXISTS idx_exec_stage_v2_to ON founder_exec_stage_events_v2 (to_stage);

ALTER TABLE founder_exec_stage_events_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS exec_stage_v2_founder_only ON founder_exec_stage_events_v2;
CREATE POLICY exec_stage_v2_founder_only ON founder_exec_stage_events_v2
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());


-- =====================================================================
-- READ RPCs (STABLE)
-- =====================================================================

CREATE OR REPLACE FUNCTION rpc_founder_exec_pipeline_funnel_v2()
RETURNS TABLE (
  stage text,
  cand_count bigint,
  avg_calibration numeric,
  median_days_in_stage numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH s AS (
    SELECT unnest(ARRAY['source','screen','onsite','offer','signed','ramped','departed']) AS st
  )
  SELECT
    s.st,
    COUNT(c.id)::bigint,
    ROUND(AVG(c.calibration_score)::numeric, 2),
    ROUND(
      percentile_cont(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (now() - c.sourced_at)) / 86400.0
      )::numeric, 1
    )
  FROM s
  LEFT JOIN founder_exec_candidates_v2 c ON c.stage = s.st
  GROUP BY s.st
  ORDER BY array_position(ARRAY['source','screen','onsite','offer','signed','ramped','departed'], s.st);
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_exec_pipeline_funnel_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exec_pipeline_funnel_v2() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_exec_kpis_v2()
RETURNS TABLE (
  total_candidates bigint,
  active_pipeline bigint,
  in_source bigint,
  in_screen bigint,
  in_onsite bigint,
  in_offer bigint,
  signed_total bigint,
  ramped_total bigint,
  departed_total bigint,
  vp_count bigint,
  c_level_count bigint,
  avg_comp_offered numeric,
  max_equity_bps int,
  avg_calibration numeric,
  offer_acceptance_pct numeric,
  ramp_success_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE stage NOT IN ('departed','ramped'))::bigint,
    COUNT(*) FILTER (WHERE stage = 'source')::bigint,
    COUNT(*) FILTER (WHERE stage = 'screen')::bigint,
    COUNT(*) FILTER (WHERE stage = 'onsite')::bigint,
    COUNT(*) FILTER (WHERE stage = 'offer')::bigint,
    COUNT(*) FILTER (WHERE signed_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE ramped_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE departed_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE role_level = 'vp')::bigint,
    COUNT(*) FILTER (WHERE role_level = 'c_level')::bigint,
    ROUND(AVG(comp_offered_lakhs)::numeric, 2),
    COALESCE(MAX(equity_bps), 0),
    ROUND(AVG(calibration_score)::numeric, 2),
    CASE WHEN COUNT(*) FILTER (WHERE offered_at IS NOT NULL) > 0
      THEN ROUND(
        100.0 * COUNT(*) FILTER (WHERE signed_at IS NOT NULL)::numeric
             / COUNT(*) FILTER (WHERE offered_at IS NOT NULL)::numeric, 1)
      ELSE 0 END,
    CASE WHEN COUNT(*) FILTER (WHERE signed_at IS NOT NULL) > 0
      THEN ROUND(
        100.0 * COUNT(*) FILTER (WHERE ramped_at IS NOT NULL)::numeric
             / COUNT(*) FILTER (WHERE signed_at IS NOT NULL)::numeric, 1)
      ELSE 0 END
  FROM founder_exec_candidates_v2;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_exec_kpis_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exec_kpis_v2() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_exec_active_pipeline_v2()
RETURNS TABLE (
  id uuid,
  candidate_name text,
  target_role text,
  role_level text,
  stage text,
  source_channel text,
  calibration_score int,
  days_in_pipeline numeric,
  comp_target_lakhs numeric,
  recruiter_owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.candidate_name,
    c.target_role,
    c.role_level,
    c.stage,
    c.source_channel,
    c.calibration_score,
    ROUND((EXTRACT(EPOCH FROM (now() - c.sourced_at)) / 86400.0)::numeric, 1),
    c.comp_target_lakhs,
    c.recruiter_owner_email
  FROM founder_exec_candidates_v2 c
  WHERE c.stage NOT IN ('departed','ramped')
  ORDER BY array_position(ARRAY['offer','onsite','screen','source','signed'], c.stage),
           c.sourced_at DESC
  LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_exec_active_pipeline_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exec_active_pipeline_v2() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_exec_offers_v2()
RETURNS TABLE (
  id uuid,
  candidate_name text,
  target_role text,
  comp_offered_lakhs numeric,
  equity_bps int,
  offered_at timestamptz,
  signed_at timestamptz,
  days_to_sign numeric,
  outcome text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.candidate_name,
    c.target_role,
    c.comp_offered_lakhs,
    c.equity_bps,
    c.offered_at,
    c.signed_at,
    CASE WHEN c.signed_at IS NOT NULL AND c.offered_at IS NOT NULL
      THEN ROUND((EXTRACT(EPOCH FROM (c.signed_at - c.offered_at)) / 86400.0)::numeric, 1)
      ELSE NULL END,
    CASE
      WHEN c.signed_at IS NOT NULL THEN 'accepted'
      WHEN c.departed_at IS NOT NULL AND c.signed_at IS NULL THEN 'declined'
      ELSE 'pending'
    END
  FROM founder_exec_candidates_v2 c
  WHERE c.offered_at IS NOT NULL
  ORDER BY c.offered_at DESC
  LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_exec_offers_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exec_offers_v2() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_exec_ramped_v2()
RETURNS TABLE (
  id uuid,
  candidate_name text,
  target_role text,
  role_level text,
  signed_at timestamptz,
  ramped_at timestamptz,
  days_to_ramp numeric,
  departed_at timestamptz,
  tenure_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.candidate_name,
    c.target_role,
    c.role_level,
    c.signed_at,
    c.ramped_at,
    CASE WHEN c.ramped_at IS NOT NULL AND c.signed_at IS NOT NULL
      THEN ROUND((EXTRACT(EPOCH FROM (c.ramped_at - c.signed_at)) / 86400.0)::numeric, 1)
      ELSE NULL END,
    c.departed_at,
    CASE WHEN c.departed_at IS NOT NULL AND c.signed_at IS NOT NULL
      THEN ROUND((EXTRACT(EPOCH FROM (c.departed_at - c.signed_at)) / 86400.0)::numeric, 1)
      ELSE NULL END
  FROM founder_exec_candidates_v2 c
  WHERE c.signed_at IS NOT NULL
  ORDER BY c.signed_at DESC
  LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_exec_ramped_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exec_ramped_v2() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_exec_calibration_v2()
RETURNS TABLE (
  role_level text,
  cand_count bigint,
  avg_calibration numeric,
  high_calibration_pct numeric,
  signed_count bigint,
  ramped_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.role_level,
    COUNT(*)::bigint,
    ROUND(AVG(c.calibration_score)::numeric, 2),
    CASE WHEN COUNT(*) > 0
      THEN ROUND(100.0 * COUNT(*) FILTER (WHERE c.calibration_score >= 4)::numeric / COUNT(*)::numeric, 1)
      ELSE 0 END,
    COUNT(*) FILTER (WHERE c.signed_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE c.ramped_at IS NOT NULL)::bigint
  FROM founder_exec_candidates_v2 c
  GROUP BY c.role_level
  ORDER BY c.role_level;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_exec_calibration_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exec_calibration_v2() TO authenticated;


CREATE OR REPLACE FUNCTION rpc_founder_exec_recent_events_v2()
RETURNS TABLE (
  id uuid,
  candidate_name text,
  target_role text,
  from_stage text,
  to_stage text,
  event_at timestamptz,
  actor_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, c.candidate_name, c.target_role,
         e.from_stage, e.to_stage, e.event_at, e.actor_email, e.notes
  FROM founder_exec_stage_events_v2 e
  JOIN founder_exec_candidates_v2 c ON c.id = e.candidate_id
  ORDER BY e.event_at DESC
  LIMIT 50;
END; $$;

REVOKE EXECUTE ON FUNCTION rpc_founder_exec_recent_events_v2() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_exec_recent_events_v2() TO authenticated;


-- =====================================================================
-- WRITE / LOG helpers (VOLATILE)
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_exec_candidate_add_v2(
  p_name text,
  p_role text,
  p_role_level text,
  p_source text,
  p_comp_target numeric,
  p_calibration int,
  p_recruiter_email text,
  p_email text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_exec_candidates_v2
    (candidate_name, target_role, role_level, source_channel,
     comp_target_lakhs, calibration_score, recruiter_owner_email, candidate_email)
  VALUES
    (p_name, p_role, p_role_level, p_source,
     p_comp_target, p_calibration, p_recruiter_email, p_email)
  RETURNING id INTO v_id;

  INSERT INTO founder_exec_stage_events_v2
    (candidate_id, from_stage, to_stage, actor_email, notes)
  VALUES (v_id, NULL, 'source', (auth.jwt()->>'email'), 'candidate added');

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'exec_candidate_add_v2',
          jsonb_build_object('id', v_id, 'name', p_name, 'role', p_role, 'level', p_role_level));
  RETURN v_id;
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_exec_candidate_add_v2(text, text, text, text, numeric, int, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exec_candidate_add_v2(text, text, text, text, numeric, int, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_exec_stage_advance_v2(
  p_cand_id uuid,
  p_to_stage text,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_from text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_to_stage NOT IN ('source','screen','onsite','offer','signed','ramped','departed') THEN
    RAISE EXCEPTION 'invalid stage';
  END IF;

  SELECT stage INTO v_from FROM founder_exec_candidates_v2 WHERE id = p_cand_id;
  IF v_from IS NULL THEN RAISE EXCEPTION 'candidate not found'; END IF;

  UPDATE founder_exec_candidates_v2
     SET stage = p_to_stage,
         updated_at = now(),
         screened_at = CASE WHEN p_to_stage = 'screen'   AND screened_at IS NULL THEN now() ELSE screened_at END,
         onsite_at   = CASE WHEN p_to_stage = 'onsite'   AND onsite_at   IS NULL THEN now() ELSE onsite_at   END,
         offered_at  = CASE WHEN p_to_stage = 'offer'    AND offered_at  IS NULL THEN now() ELSE offered_at  END,
         signed_at   = CASE WHEN p_to_stage = 'signed'   AND signed_at   IS NULL THEN now() ELSE signed_at   END,
         ramped_at   = CASE WHEN p_to_stage = 'ramped'   AND ramped_at   IS NULL THEN now() ELSE ramped_at   END,
         departed_at = CASE WHEN p_to_stage = 'departed' AND departed_at IS NULL THEN now() ELSE departed_at END
   WHERE id = p_cand_id;

  INSERT INTO founder_exec_stage_events_v2
    (candidate_id, from_stage, to_stage, actor_email, notes)
  VALUES (p_cand_id, v_from, p_to_stage, (auth.jwt()->>'email'), p_notes);

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'exec_stage_advance_v2',
          jsonb_build_object('id', p_cand_id, 'from', v_from, 'to', p_to_stage));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_exec_stage_advance_v2(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exec_stage_advance_v2(uuid, text, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_exec_offer_extend_v2(
  p_cand_id uuid,
  p_comp_offered numeric,
  p_equity_bps int
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_exec_candidates_v2
     SET comp_offered_lakhs = p_comp_offered,
         equity_bps = p_equity_bps,
         stage = 'offer',
         offered_at = COALESCE(offered_at, now()),
         updated_at = now()
   WHERE id = p_cand_id;

  INSERT INTO founder_exec_stage_events_v2
    (candidate_id, from_stage, to_stage, actor_email, notes)
  VALUES (p_cand_id, 'onsite', 'offer', (auth.jwt()->>'email'),
          'offer extended: ' || p_comp_offered::text || 'L + ' || COALESCE(p_equity_bps::text,'0') || 'bps');

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'exec_offer_extend_v2',
          jsonb_build_object('id', p_cand_id, 'comp_lakhs', p_comp_offered, 'equity_bps', p_equity_bps));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_exec_offer_extend_v2(uuid, numeric, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exec_offer_extend_v2(uuid, numeric, int) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_exec_calibration_set_v2(
  p_cand_id uuid,
  p_score int,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_score < 1 OR p_score > 5 THEN RAISE EXCEPTION 'score must be 1..5'; END IF;

  UPDATE founder_exec_candidates_v2
     SET calibration_score = p_score,
         calibration_notes = p_notes,
         updated_at = now()
   WHERE id = p_cand_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'exec_calibration_set_v2',
          jsonb_build_object('id', p_cand_id, 'score', p_score));
END; $$;

REVOKE EXECUTE ON FUNCTION log_founder_exec_calibration_set_v2(uuid, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_exec_calibration_set_v2(uuid, int, text) TO authenticated;

COMMIT;