BEGIN;

-- Round 1575: Founder Hospital Chain Expansion Playbook
-- When 1 hospital in chain becomes active, surface other locations in same chain.
-- Templated outreach sequence + success rate tracking.

CREATE TABLE IF NOT EXISTS founder_chain_expansion_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  anchor_org_id uuid REFERENCES organizations(id),
  target_org_id uuid REFERENCES organizations(id),
  target_hospital_name text NOT NULL,
  target_city text,
  target_state text,
  status text NOT NULL DEFAULT 'identified' CHECK (status IN ('identified','contacted','meeting_scheduled','demo_done','negotiating','won','lost','dormant')),
  outreach_template text,
  current_step int NOT NULL DEFAULT 0,
  last_touch_at timestamptz,
  next_touch_due timestamptz,
  converted_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_chain_expansion_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chain_exp_targets_founder ON founder_chain_expansion_targets;
CREATE POLICY chain_exp_targets_founder ON founder_chain_expansion_targets
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_chain_outreach_touches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_id uuid NOT NULL REFERENCES founder_chain_expansion_targets(id) ON DELETE CASCADE,
  step_number int NOT NULL,
  channel text NOT NULL CHECK (channel IN ('email','call','whatsapp','in_person','linkedin')),
  template_used text,
  outcome text NOT NULL DEFAULT 'sent' CHECK (outcome IN ('sent','replied','no_response','positive','negative','meeting_booked')),
  notes text,
  touched_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_chain_outreach_touches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chain_outreach_touches_founder ON founder_chain_outreach_touches;
CREATE POLICY chain_outreach_touches_founder ON founder_chain_outreach_touches
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_chain_exp_targets_status ON founder_chain_expansion_targets(status);
CREATE INDEX IF NOT EXISTS idx_chain_exp_targets_next_touch ON founder_chain_expansion_targets(next_touch_due);
CREATE INDEX IF NOT EXISTS idx_chain_outreach_touches_target ON founder_chain_outreach_touches(target_id);

-- ====== READ RPCs (STABLE) ======

CREATE OR REPLACE FUNCTION founder_chain_expansion_kpis()
RETURNS TABLE(
  total_targets bigint,
  active_chains bigint,
  identified bigint,
  contacted bigint,
  meeting_scheduled bigint,
  demo_done bigint,
  negotiating bigint,
  won bigint,
  lost bigint,
  dormant bigint,
  total_touches bigint,
  positive_touches bigint,
  reply_rate_pct numeric,
  conversion_rate_pct numeric,
  avg_days_to_convert numeric,
  overdue_touches bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH t AS (SELECT * FROM founder_chain_expansion_targets),
       o AS (SELECT * FROM founder_chain_outreach_touches)
  SELECT
    (SELECT count(*) FROM t),
    (SELECT count(DISTINCT chain_name) FROM t),
    (SELECT count(*) FROM t WHERE status='identified'),
    (SELECT count(*) FROM t WHERE status='contacted'),
    (SELECT count(*) FROM t WHERE status='meeting_scheduled'),
    (SELECT count(*) FROM t WHERE status='demo_done'),
    (SELECT count(*) FROM t WHERE status='negotiating'),
    (SELECT count(*) FROM t WHERE status='won'),
    (SELECT count(*) FROM t WHERE status='lost'),
    (SELECT count(*) FROM t WHERE status='dormant'),
    (SELECT count(*) FROM o),
    (SELECT count(*) FROM o WHERE outcome IN ('positive','replied','meeting_booked')),
    COALESCE(ROUND(100.0 * (SELECT count(*) FROM o WHERE outcome IN ('replied','positive','meeting_booked'))::numeric / NULLIF((SELECT count(*) FROM o),0), 2), 0),
    COALESCE(ROUND(100.0 * (SELECT count(*) FROM t WHERE status='won')::numeric / NULLIF((SELECT count(*) FROM t),0), 2), 0),
    COALESCE(ROUND((SELECT AVG(EXTRACT(EPOCH FROM (converted_at - created_at))/86400.0) FROM t WHERE converted_at IS NOT NULL), 2), 0),
    (SELECT count(*) FROM t WHERE next_touch_due IS NOT NULL AND next_touch_due < now() AND status NOT IN ('won','lost'));
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_chain_expansion_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_expansion_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_chain_expansion_active_chains()
RETURNS TABLE(
  id text,
  chain_name text,
  anchor_hospital text,
  total_locations bigint,
  identified bigint,
  won bigint,
  last_activity timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    t.chain_name AS id,
    t.chain_name,
    COALESCE((SELECT o.name FROM organizations o WHERE o.id = MIN(t.anchor_org_id)), '—'),
    count(*),
    count(*) FILTER (WHERE t.status='identified'),
    count(*) FILTER (WHERE t.status='won'),
    MAX(t.last_touch_at)
  FROM founder_chain_expansion_targets t
  GROUP BY t.chain_name
  ORDER BY count(*) DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_chain_expansion_active_chains() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_expansion_active_chains() TO authenticated;

CREATE OR REPLACE FUNCTION founder_chain_expansion_targets_list()
RETURNS TABLE(
  id uuid,
  chain_name text,
  target_hospital_name text,
  target_city text,
  target_state text,
  status text,
  current_step int,
  last_touch_at timestamptz,
  next_touch_due timestamptz,
  overdue boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.chain_name, t.target_hospital_name, t.target_city, t.target_state,
         t.status, t.current_step, t.last_touch_at, t.next_touch_due,
         (t.next_touch_due IS NOT NULL AND t.next_touch_due < now() AND t.status NOT IN ('won','lost'))
  FROM founder_chain_expansion_targets t
  ORDER BY (t.next_touch_due IS NOT NULL AND t.next_touch_due < now()) DESC NULLS LAST,
           t.next_touch_due NULLS LAST,
           t.created_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_chain_expansion_targets_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_expansion_targets_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_chain_expansion_recent_touches()
RETURNS TABLE(
  id uuid,
  chain_name text,
  target_hospital_name text,
  step_number int,
  channel text,
  outcome text,
  touched_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT o.id, t.chain_name, t.target_hospital_name, o.step_number, o.channel, o.outcome, o.touched_at
  FROM founder_chain_outreach_touches o
  JOIN founder_chain_expansion_targets t ON t.id = o.target_id
  ORDER BY o.touched_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_chain_expansion_recent_touches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_expansion_recent_touches() TO authenticated;

CREATE OR REPLACE FUNCTION founder_chain_expansion_template_performance()
RETURNS TABLE(
  id text,
  template_used text,
  sent_count bigint,
  reply_count bigint,
  positive_count bigint,
  reply_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(o.template_used, 'unspecified') AS id,
    COALESCE(o.template_used, 'unspecified'),
    count(*),
    count(*) FILTER (WHERE o.outcome IN ('replied','positive','meeting_booked')),
    count(*) FILTER (WHERE o.outcome IN ('positive','meeting_booked')),
    COALESCE(ROUND(100.0 * count(*) FILTER (WHERE o.outcome IN ('replied','positive','meeting_booked'))::numeric / NULLIF(count(*),0), 2), 0)
  FROM founder_chain_outreach_touches o
  GROUP BY COALESCE(o.template_used, 'unspecified')
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_chain_expansion_template_performance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_expansion_template_performance() TO authenticated;

CREATE OR REPLACE FUNCTION founder_chain_expansion_funnel()
RETURNS TABLE(
  id text,
  stage text,
  cnt bigint,
  pct_of_total numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*) INTO v_total FROM founder_chain_expansion_targets;
  RETURN QUERY
  SELECT s.stage AS id, s.stage,
         (SELECT count(*) FROM founder_chain_expansion_targets t WHERE t.status = s.stage),
         COALESCE(ROUND(100.0 * (SELECT count(*) FROM founder_chain_expansion_targets t WHERE t.status = s.stage)::numeric / NULLIF(v_total,0), 2), 0)
  FROM (VALUES ('identified'),('contacted'),('meeting_scheduled'),('demo_done'),('negotiating'),('won'),('lost'),('dormant')) AS s(stage);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_chain_expansion_funnel() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_expansion_funnel() TO authenticated;

-- ====== WRITE RPC (VOLATILE) ======

CREATE OR REPLACE FUNCTION founder_chain_expansion_log_touch(
  p_target_id uuid,
  p_channel text,
  p_template text,
  p_outcome text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_step int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(MAX(step_number),0) + 1 INTO v_step FROM founder_chain_outreach_touches WHERE target_id = p_target_id;
  INSERT INTO founder_chain_outreach_touches(target_id, step_number, channel, template_used, outcome, notes)
  VALUES (p_target_id, v_step, p_channel, p_template, p_outcome, p_notes)
  RETURNING id INTO v_id;
  UPDATE founder_chain_expansion_targets
    SET last_touch_at = now(),
        current_step = v_step,
        updated_at = now()
    WHERE id = p_target_id;
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_chain_expansion_log_touch(uuid,text,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_chain_expansion_log_touch(uuid,text,text,text,text) TO authenticated;

-- ====== log_founder_* helpers (VOLATILE SECDEF) ======

CREATE OR REPLACE FUNCTION log_founder_chain_target_added(p_target_id uuid, p_chain_name text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'chain_target_added',
          jsonb_build_object('target_id', p_target_id, 'chain_name', p_chain_name));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_chain_target_added(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_chain_target_added(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_chain_touch_logged(p_target_id uuid, p_channel text, p_outcome text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'chain_touch_logged',
          jsonb_build_object('target_id', p_target_id, 'channel', p_channel, 'outcome', p_outcome));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_chain_touch_logged(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_chain_touch_logged(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_chain_status_changed(p_target_id uuid, p_new_status text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'chain_status_changed',
          jsonb_build_object('target_id', p_target_id, 'new_status', p_new_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_chain_status_changed(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_chain_status_changed(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_chain_playbook_viewed(p_chain_name text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'chain_playbook_viewed',
          jsonb_build_object('chain_name', p_chain_name));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_chain_playbook_viewed(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_chain_playbook_viewed(text) TO authenticated;

COMMIT;