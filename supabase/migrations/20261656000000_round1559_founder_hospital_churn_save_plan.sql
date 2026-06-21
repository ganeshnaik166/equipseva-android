BEGIN;

-- ============================================================
-- r1559 — Hospital churn save-plan workflow
-- When hospital flagged at risk -> spin up save plan with steps
-- (founder call, discount, engineer swap, exec visit), track
-- success rate.
-- ============================================================

-- ---------- Tables ----------
CREATE TABLE IF NOT EXISTS hospital_save_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  risk_score numeric(5,2) NOT NULL DEFAULT 0,
  risk_reason text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','saved','lost','cancelled')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  outcome_notes text,
  owner_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  amc_contract_id uuid REFERENCES amc_contracts(id) ON DELETE SET NULL,
  expected_arr_rupees numeric(14,2) NOT NULL DEFAULT 0,
  saved_arr_rupees numeric(14,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsp_status ON hospital_save_plans(status);
CREATE INDEX IF NOT EXISTS idx_hsp_hospital ON hospital_save_plans(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_hsp_opened ON hospital_save_plans(opened_at DESC);

CREATE TABLE IF NOT EXISTS hospital_save_plan_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES hospital_save_plans(id) ON DELETE CASCADE,
  step_kind text NOT NULL CHECK (step_kind IN ('founder_call','discount','engineer_swap','exec_visit','escalation','followup')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done','skipped','failed')),
  scheduled_for timestamptz,
  done_at timestamptz,
  notes text,
  assignee_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsps_plan ON hospital_save_plan_steps(plan_id);
CREATE INDEX IF NOT EXISTS idx_hsps_status ON hospital_save_plan_steps(status);
CREATE INDEX IF NOT EXISTS idx_hsps_kind ON hospital_save_plan_steps(step_kind);

ALTER TABLE hospital_save_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_save_plan_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hsp_founder_all ON hospital_save_plans;
CREATE POLICY hsp_founder_all ON hospital_save_plans
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS hsps_founder_all ON hospital_save_plan_steps;
CREATE POLICY hsps_founder_all ON hospital_save_plan_steps
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- log_founder_* helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_save_plan_opened(
  p_plan_id uuid,
  p_hospital_org_id uuid,
  p_risk_score numeric,
  p_risk_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_plan_opened',
    jsonb_build_object('plan_id', p_plan_id, 'hospital_org_id', p_hospital_org_id,
      'risk_score', p_risk_score, 'risk_reason', p_risk_reason));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_save_plan_opened(uuid, uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_plan_opened(uuid, uuid, numeric, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_save_plan_step_added(
  p_plan_id uuid,
  p_step_id uuid,
  p_step_kind text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_plan_step_added',
    jsonb_build_object('plan_id', p_plan_id, 'step_id', p_step_id, 'step_kind', p_step_kind));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_save_plan_step_added(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_plan_step_added(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_save_plan_step_completed(
  p_plan_id uuid,
  p_step_id uuid,
  p_status text,
  p_notes text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_plan_step_completed',
    jsonb_build_object('plan_id', p_plan_id, 'step_id', p_step_id,
      'status', p_status, 'notes', p_notes));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_save_plan_step_completed(uuid, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_plan_step_completed(uuid, uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_save_plan_closed(
  p_plan_id uuid,
  p_status text,
  p_saved_arr numeric
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_plan_closed',
    jsonb_build_object('plan_id', p_plan_id, 'status', p_status, 'saved_arr', p_saved_arr));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_save_plan_closed(uuid, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_save_plan_closed(uuid, text, numeric) TO authenticated;

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_save_plan_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_plans', (SELECT count(*) FROM hospital_save_plans),
    'open_plans', (SELECT count(*) FROM hospital_save_plans WHERE status = 'open'),
    'in_progress_plans', (SELECT count(*) FROM hospital_save_plans WHERE status = 'in_progress'),
    'saved_plans', (SELECT count(*) FROM hospital_save_plans WHERE status = 'saved'),
    'lost_plans', (SELECT count(*) FROM hospital_save_plans WHERE status = 'lost'),
    'cancelled_plans', (SELECT count(*) FROM hospital_save_plans WHERE status = 'cancelled'),
    'save_rate_pct', COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE status = 'saved') / NULLIF(count(*) FILTER (WHERE status IN ('saved','lost')), 0), 1) FROM hospital_save_plans), 0),
    'plans_last_30d', (SELECT count(*) FROM hospital_save_plans WHERE opened_at > now() - interval '30 days'),
    'saved_last_30d', (SELECT count(*) FROM hospital_save_plans WHERE status = 'saved' AND closed_at > now() - interval '30 days'),
    'lost_last_30d', (SELECT count(*) FROM hospital_save_plans WHERE status = 'lost' AND closed_at > now() - interval '30 days'),
    'total_arr_at_risk_rupees', COALESCE((SELECT sum(expected_arr_rupees) FROM hospital_save_plans WHERE status IN ('open','in_progress')), 0),
    'total_arr_saved_rupees', COALESCE((SELECT sum(saved_arr_rupees) FROM hospital_save_plans WHERE status = 'saved'), 0),
    'total_arr_lost_rupees', COALESCE((SELECT sum(expected_arr_rupees) FROM hospital_save_plans WHERE status = 'lost'), 0),
    'avg_close_hours', COALESCE((SELECT round(avg(EXTRACT(EPOCH FROM (closed_at - opened_at))/3600.0)::numeric, 1) FROM hospital_save_plans WHERE closed_at IS NOT NULL), 0),
    'steps_total', (SELECT count(*) FROM hospital_save_plan_steps),
    'steps_pending', (SELECT count(*) FROM hospital_save_plan_steps WHERE status = 'pending')
  ) INTO r;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_plan_list_open()
RETURNS TABLE(id uuid, hospital_org_id uuid, hospital_name text, risk_score numeric, risk_reason text, status text, opened_at timestamptz, expected_arr_rupees numeric, steps_done int, steps_total int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.hospital_org_id, o.name, p.risk_score, p.risk_reason, p.status, p.opened_at, p.expected_arr_rupees,
    (SELECT count(*)::int FROM hospital_save_plan_steps s WHERE s.plan_id = p.id AND s.status = 'done'),
    (SELECT count(*)::int FROM hospital_save_plan_steps s WHERE s.plan_id = p.id)
  FROM hospital_save_plans p
  JOIN organizations o ON o.id = p.hospital_org_id
  WHERE p.status IN ('open','in_progress')
  ORDER BY p.risk_score DESC, p.opened_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_list_open() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_list_open() TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_plan_list_closed(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, hospital_name text, status text, opened_at timestamptz, closed_at timestamptz, expected_arr_rupees numeric, saved_arr_rupees numeric, close_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, o.name, p.status, p.opened_at, p.closed_at, p.expected_arr_rupees, p.saved_arr_rupees,
    round(EXTRACT(EPOCH FROM (p.closed_at - p.opened_at))/3600.0, 1)
  FROM hospital_save_plans p
  JOIN organizations o ON o.id = p.hospital_org_id
  WHERE p.status IN ('saved','lost','cancelled')
  ORDER BY p.closed_at DESC NULLS LAST
  LIMIT p_limit;
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_list_closed(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_list_closed(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_plan_step_breakdown()
RETURNS TABLE(step_kind text, total int, done int, pending int, failed int, success_rate_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.step_kind,
    count(*)::int,
    count(*) FILTER (WHERE s.status = 'done')::int,
    count(*) FILTER (WHERE s.status IN ('pending','in_progress'))::int,
    count(*) FILTER (WHERE s.status = 'failed')::int,
    round(100.0 * count(*) FILTER (WHERE s.status = 'done') / NULLIF(count(*) FILTER (WHERE s.status IN ('done','failed','skipped')), 0), 1)
  FROM hospital_save_plan_steps s
  GROUP BY s.step_kind
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_step_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_step_breakdown() TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_plan_recent_steps(p_limit int DEFAULT 30)
RETURNS TABLE(step_id uuid, plan_id uuid, hospital_name text, step_kind text, status text, scheduled_for timestamptz, done_at timestamptz, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.plan_id, o.name, s.step_kind, s.status, s.scheduled_for, s.done_at, s.notes
  FROM hospital_save_plan_steps s
  JOIN hospital_save_plans p ON p.id = s.plan_id
  JOIN organizations o ON o.id = p.hospital_org_id
  ORDER BY COALESCE(s.done_at, s.scheduled_for, s.created_at) DESC NULLS LAST
  LIMIT p_limit;
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_recent_steps(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_recent_steps(int) TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_save_plan_open(
  p_hospital_org_id uuid,
  p_risk_score numeric,
  p_risk_reason text,
  p_expected_arr_rupees numeric
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_save_plans(hospital_org_id, risk_score, risk_reason, expected_arr_rupees, owner_user_id)
  VALUES (p_hospital_org_id, p_risk_score, COALESCE(p_risk_reason,'unspecified'), COALESCE(p_expected_arr_rupees,0), auth.uid())
  RETURNING id INTO v_id;
  PERFORM log_founder_save_plan_opened(v_id, p_hospital_org_id, p_risk_score, p_risk_reason);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_open(uuid, numeric, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_open(uuid, numeric, text, numeric) TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_plan_add_step(
  p_plan_id uuid,
  p_step_kind text,
  p_scheduled_for timestamptz,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO hospital_save_plan_steps(plan_id, step_kind, scheduled_for, notes, assignee_user_id)
  VALUES (p_plan_id, p_step_kind, p_scheduled_for, p_notes, auth.uid())
  RETURNING id INTO v_id;
  UPDATE hospital_save_plans SET status = CASE WHEN status = 'open' THEN 'in_progress' ELSE status END, updated_at = now() WHERE id = p_plan_id;
  PERFORM log_founder_save_plan_step_added(p_plan_id, v_id, p_step_kind);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_add_step(uuid, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_add_step(uuid, text, timestamptz, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_plan_complete_step(
  p_step_id uuid,
  p_status text,
  p_notes text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_plan uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE hospital_save_plan_steps
     SET status = p_status, done_at = now(), notes = COALESCE(p_notes, notes), updated_at = now()
   WHERE id = p_step_id
   RETURNING plan_id INTO v_plan;
  PERFORM log_founder_save_plan_step_completed(v_plan, p_step_id, p_status, p_notes);
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_complete_step(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_complete_step(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_save_plan_close(
  p_plan_id uuid,
  p_status text,
  p_saved_arr_rupees numeric,
  p_outcome_notes text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('saved','lost','cancelled') THEN RAISE EXCEPTION 'invalid close status'; END IF;
  UPDATE hospital_save_plans
     SET status = p_status,
         closed_at = now(),
         saved_arr_rupees = COALESCE(p_saved_arr_rupees, 0),
         outcome_notes = p_outcome_notes,
         updated_at = now()
   WHERE id = p_plan_id;
  PERFORM log_founder_save_plan_closed(p_plan_id, p_status, COALESCE(p_saved_arr_rupees,0));
END $$;
REVOKE EXECUTE ON FUNCTION founder_save_plan_close(uuid, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_save_plan_close(uuid, text, numeric, text) TO authenticated;

COMMIT;