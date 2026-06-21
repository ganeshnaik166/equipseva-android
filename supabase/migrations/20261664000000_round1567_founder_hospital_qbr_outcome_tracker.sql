BEGIN;

-- Round 1567: Hospital QBR Outcome Tracker
-- After each QBR (r1534), log outcomes: action items, commitments, satisfaction, NPS delta
-- Founder follow-up SLA per action item

CREATE TABLE IF NOT EXISTS hospital_qbr_outcomes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  qbr_session_id uuid,
  hospital_org_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  qbr_date date NOT NULL DEFAULT CURRENT_DATE,
  satisfaction_signal text NOT NULL CHECK (satisfaction_signal IN ('delighted','satisfied','neutral','concerned','at_risk')),
  nps_before smallint CHECK (nps_before BETWEEN 0 AND 10),
  nps_after smallint CHECK (nps_after BETWEEN 0 AND 10),
  nps_delta smallint,
  summary_notes text,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hospital_qbr_outcomes_org ON hospital_qbr_outcomes(hospital_org_id, qbr_date DESC);
CREATE INDEX IF NOT EXISTS idx_hospital_qbr_outcomes_signal ON hospital_qbr_outcomes(satisfaction_signal);

CREATE TABLE IF NOT EXISTS hospital_qbr_action_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outcome_id uuid REFERENCES hospital_qbr_outcomes(id) ON DELETE CASCADE,
  hospital_org_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
  item_type text NOT NULL CHECK (item_type IN ('action_item','commitment','escalation','follow_up')),
  description text NOT NULL,
  owner_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  sla_due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','missed','cancelled')),
  closed_at timestamptz,
  priority smallint NOT NULL DEFAULT 2 CHECK (priority BETWEEN 1 AND 4),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qbr_action_items_outcome ON hospital_qbr_action_items(outcome_id);
CREATE INDEX IF NOT EXISTS idx_qbr_action_items_sla ON hospital_qbr_action_items(sla_due_at) WHERE status IN ('open','in_progress');
CREATE INDEX IF NOT EXISTS idx_qbr_action_items_status ON hospital_qbr_action_items(status);

ALTER TABLE hospital_qbr_outcomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE hospital_qbr_action_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS qbr_outcomes_founder_only ON hospital_qbr_outcomes;
CREATE POLICY qbr_outcomes_founder_only ON hospital_qbr_outcomes FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS qbr_action_items_founder_only ON hospital_qbr_action_items;
CREATE POLICY qbr_action_items_founder_only ON hospital_qbr_action_items FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- Helper: log to founder action log
CREATE OR REPLACE FUNCTION log_founder_qbr_outcome_recorded(p_outcome_id uuid, p_org_id uuid, p_signal text, p_nps_delta smallint)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'qbr_outcome_recorded',
    jsonb_build_object('outcome_id', p_outcome_id, 'org_id', p_org_id, 'signal', p_signal, 'nps_delta', p_nps_delta));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_qbr_outcome_recorded(uuid, uuid, text, smallint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_qbr_outcome_recorded(uuid, uuid, text, smallint) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_qbr_action_added(p_item_id uuid, p_outcome_id uuid, p_item_type text, p_sla_due_at timestamptz)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'qbr_action_added',
    jsonb_build_object('item_id', p_item_id, 'outcome_id', p_outcome_id, 'type', p_item_type, 'sla_due_at', p_sla_due_at));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_qbr_action_added(uuid, uuid, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_qbr_action_added(uuid, uuid, text, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_qbr_action_closed(p_item_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'qbr_action_closed',
    jsonb_build_object('item_id', p_item_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_qbr_action_closed(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_qbr_action_closed(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_qbr_sla_escalation(p_item_id uuid, p_hours_overdue numeric)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'qbr_sla_escalation',
    jsonb_build_object('item_id', p_item_id, 'hours_overdue', p_hours_overdue));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_qbr_sla_escalation(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_qbr_sla_escalation(uuid, numeric) TO authenticated;

-- RPC 1: KPI snapshot (READ - STABLE)
CREATE OR REPLACE FUNCTION founder_qbr_outcome_kpis()
RETURNS TABLE(
  total_qbrs_90d bigint,
  unique_hospitals_90d bigint,
  delighted_count bigint,
  satisfied_count bigint,
  neutral_count bigint,
  concerned_count bigint,
  at_risk_count bigint,
  avg_nps_delta_90d numeric,
  total_action_items bigint,
  open_action_items bigint,
  overdue_action_items bigint,
  done_action_items bigint,
  missed_action_items bigint,
  sla_compliance_pct numeric,
  avg_resolution_hours numeric,
  qbrs_this_month bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM hospital_qbr_outcomes WHERE qbr_date >= CURRENT_DATE - INTERVAL '90 days'),
    (SELECT count(DISTINCT hospital_org_id) FROM hospital_qbr_outcomes WHERE qbr_date >= CURRENT_DATE - INTERVAL '90 days'),
    (SELECT count(*) FROM hospital_qbr_outcomes WHERE satisfaction_signal = 'delighted' AND qbr_date >= CURRENT_DATE - INTERVAL '90 days'),
    (SELECT count(*) FROM hospital_qbr_outcomes WHERE satisfaction_signal = 'satisfied' AND qbr_date >= CURRENT_DATE - INTERVAL '90 days'),
    (SELECT count(*) FROM hospital_qbr_outcomes WHERE satisfaction_signal = 'neutral' AND qbr_date >= CURRENT_DATE - INTERVAL '90 days'),
    (SELECT count(*) FROM hospital_qbr_outcomes WHERE satisfaction_signal = 'concerned' AND qbr_date >= CURRENT_DATE - INTERVAL '90 days'),
    (SELECT count(*) FROM hospital_qbr_outcomes WHERE satisfaction_signal = 'at_risk' AND qbr_date >= CURRENT_DATE - INTERVAL '90 days'),
    COALESCE((SELECT round(avg(nps_delta)::numeric, 2) FROM hospital_qbr_outcomes WHERE qbr_date >= CURRENT_DATE - INTERVAL '90 days' AND nps_delta IS NOT NULL), 0),
    (SELECT count(*) FROM hospital_qbr_action_items),
    (SELECT count(*) FROM hospital_qbr_action_items WHERE status IN ('open','in_progress')),
    (SELECT count(*) FROM hospital_qbr_action_items WHERE status IN ('open','in_progress') AND sla_due_at < now()),
    (SELECT count(*) FROM hospital_qbr_action_items WHERE status = 'done'),
    (SELECT count(*) FROM hospital_qbr_action_items WHERE status = 'missed'),
    COALESCE((SELECT round(100.0 * count(*) FILTER (WHERE status = 'done' AND closed_at <= sla_due_at) / NULLIF(count(*) FILTER (WHERE status IN ('done','missed')), 0), 1) FROM hospital_qbr_action_items), 0),
    COALESCE((SELECT round(avg(EXTRACT(EPOCH FROM (closed_at - created_at))/3600.0)::numeric, 1) FROM hospital_qbr_action_items WHERE status = 'done' AND closed_at IS NOT NULL), 0),
    (SELECT count(*) FROM hospital_qbr_outcomes WHERE qbr_date >= date_trunc('month', CURRENT_DATE));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_qbr_outcome_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qbr_outcome_kpis() TO authenticated;

-- RPC 2: Recent QBR outcomes (READ)
CREATE OR REPLACE FUNCTION founder_qbr_recent_outcomes()
RETURNS TABLE(
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  qbr_date date,
  satisfaction_signal text,
  nps_before smallint,
  nps_after smallint,
  nps_delta smallint,
  action_item_count bigint,
  open_items bigint,
  recorded_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, o.hospital_org_id,
    COALESCE(org.name, 'Unknown'),
    o.qbr_date, o.satisfaction_signal, o.nps_before, o.nps_after, o.nps_delta,
    (SELECT count(*) FROM hospital_qbr_action_items ai WHERE ai.outcome_id = o.id),
    (SELECT count(*) FROM hospital_qbr_action_items ai WHERE ai.outcome_id = o.id AND ai.status IN ('open','in_progress')),
    o.recorded_at
  FROM hospital_qbr_outcomes o
  LEFT JOIN organizations org ON org.id = o.hospital_org_id
  ORDER BY o.qbr_date DESC, o.recorded_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_qbr_recent_outcomes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qbr_recent_outcomes() TO authenticated;

-- RPC 3: Overdue action items (READ)
CREATE OR REPLACE FUNCTION founder_qbr_overdue_actions()
RETURNS TABLE(
  id uuid,
  hospital_name text,
  item_type text,
  description text,
  priority smallint,
  sla_due_at timestamptz,
  hours_overdue numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ai.id, COALESCE(org.name, 'Unknown'),
    ai.item_type, ai.description, ai.priority, ai.sla_due_at,
    round(EXTRACT(EPOCH FROM (now() - ai.sla_due_at))/3600.0, 1),
    ai.status
  FROM hospital_qbr_action_items ai
  LEFT JOIN organizations org ON org.id = ai.hospital_org_id
  WHERE ai.status IN ('open','in_progress') AND ai.sla_due_at < now()
  ORDER BY ai.priority ASC, ai.sla_due_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_qbr_overdue_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qbr_overdue_actions() TO authenticated;

-- RPC 4: Hospital satisfaction trend (READ)
CREATE OR REPLACE FUNCTION founder_qbr_hospital_trend()
RETURNS TABLE(
  hospital_org_id uuid,
  hospital_name text,
  qbr_count bigint,
  latest_signal text,
  latest_nps_delta smallint,
  avg_nps_delta numeric,
  open_action_items bigint,
  last_qbr_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.hospital_org_id,
    COALESCE(org.name, 'Unknown'),
    count(*),
    (SELECT o2.satisfaction_signal FROM hospital_qbr_outcomes o2 WHERE o2.hospital_org_id = o.hospital_org_id ORDER BY o2.qbr_date DESC LIMIT 1),
    (SELECT o3.nps_delta FROM hospital_qbr_outcomes o3 WHERE o3.hospital_org_id = o.hospital_org_id ORDER BY o3.qbr_date DESC LIMIT 1),
    COALESCE(round(avg(o.nps_delta)::numeric, 2), 0),
    (SELECT count(*) FROM hospital_qbr_action_items ai WHERE ai.hospital_org_id = o.hospital_org_id AND ai.status IN ('open','in_progress')),
    max(o.qbr_date)
  FROM hospital_qbr_outcomes o
  LEFT JOIN organizations org ON org.id = o.hospital_org_id
  GROUP BY o.hospital_org_id, org.name
  ORDER BY max(o.qbr_date) DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_qbr_hospital_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qbr_hospital_trend() TO authenticated;

-- RPC 5: Action item type breakdown (READ)
CREATE OR REPLACE FUNCTION founder_qbr_action_breakdown()
RETURNS TABLE(
  item_type text,
  total_count bigint,
  open_count bigint,
  done_count bigint,
  missed_count bigint,
  avg_resolution_hours numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT ai.item_type,
    count(*),
    count(*) FILTER (WHERE ai.status IN ('open','in_progress')),
    count(*) FILTER (WHERE ai.status = 'done'),
    count(*) FILTER (WHERE ai.status = 'missed'),
    COALESCE(round(avg(EXTRACT(EPOCH FROM (ai.closed_at - ai.created_at))/3600.0) FILTER (WHERE ai.status = 'done' AND ai.closed_at IS NOT NULL), 1), 0)
  FROM hospital_qbr_action_items ai
  GROUP BY ai.item_type
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_qbr_action_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qbr_action_breakdown() TO authenticated;

-- RPC 6: Record QBR outcome (WRITE - VOLATILE)
CREATE OR REPLACE FUNCTION founder_qbr_record_outcome(
  p_hospital_org_id uuid,
  p_qbr_date date,
  p_signal text,
  p_nps_before smallint,
  p_nps_after smallint,
  p_summary text
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_delta smallint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_delta := COALESCE(p_nps_after, 0) - COALESCE(p_nps_before, 0);
  INSERT INTO hospital_qbr_outcomes(hospital_org_id, qbr_date, satisfaction_signal, nps_before, nps_after, nps_delta, summary_notes, recorded_by)
  VALUES (p_hospital_org_id, p_qbr_date, p_signal, p_nps_before, p_nps_after, v_delta, p_summary, auth.uid())
  RETURNING id INTO v_id;
  PERFORM log_founder_qbr_outcome_recorded(v_id, p_hospital_org_id, p_signal, v_delta);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_qbr_record_outcome(uuid, date, text, smallint, smallint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qbr_record_outcome(uuid, date, text, smallint, smallint, text) TO authenticated;

-- RPC 7: Close action item (WRITE - VOLATILE)
CREATE OR REPLACE FUNCTION founder_qbr_close_action(p_item_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('done','missed','cancelled') THEN RAISE EXCEPTION 'invalid_status'; END IF;
  UPDATE hospital_qbr_action_items SET status = p_status, closed_at = now() WHERE id = p_item_id;
  PERFORM log_founder_qbr_action_closed(p_item_id, p_status);
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_qbr_close_action(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_qbr_close_action(uuid, text) TO authenticated;

COMMIT;