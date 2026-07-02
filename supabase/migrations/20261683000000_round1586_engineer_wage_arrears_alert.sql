BEGIN;

-- ============================================================================
-- r1586 Engineer Wage Arrears Alert
-- Detect engineers with payout backlog >30d; auto-create alert with amount
-- and age; founder must clear within 48h SLA; clearance log.
-- ============================================================================

-- Table 1: wage arrears alerts (one per engineer, open until cleared)
CREATE TABLE IF NOT EXISTS engineer_wage_arrears_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  oldest_payout_id uuid REFERENCES engineer_payouts(id) ON DELETE SET NULL,
  backlog_amount_rupees numeric(14,2) NOT NULL DEFAULT 0,
  oldest_age_days integer NOT NULL DEFAULT 0,
  payout_count integer NOT NULL DEFAULT 0,
  detected_at timestamptz NOT NULL DEFAULT now(),
  sla_due_at timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
  cleared_at timestamptz,
  cleared_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  clearance_note text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','cleared','escalated')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_engineer_wage_arrears_open
  ON engineer_wage_arrears_alerts(engineer_id)
  WHERE status = 'open';

CREATE INDEX IF NOT EXISTS idx_engineer_wage_arrears_status
  ON engineer_wage_arrears_alerts(status, sla_due_at);

ALTER TABLE engineer_wage_arrears_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_engineer_wage_arrears_founder ON engineer_wage_arrears_alerts;
CREATE POLICY p_engineer_wage_arrears_founder ON engineer_wage_arrears_alerts
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: clearance log (audit trail of every clearance action)
CREATE TABLE IF NOT EXISTS engineer_wage_arrears_clearance_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_id uuid NOT NULL REFERENCES engineer_wage_arrears_alerts(id) ON DELETE CASCADE,
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('cleared','escalated','reopened','note_added')),
  amount_at_action_rupees numeric(14,2) NOT NULL DEFAULT 0,
  age_days_at_action integer NOT NULL DEFAULT 0,
  note text,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_arrears_clearance_log_alert
  ON engineer_wage_arrears_clearance_log(alert_id, created_at DESC);

ALTER TABLE engineer_wage_arrears_clearance_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_arrears_clearance_founder ON engineer_wage_arrears_clearance_log;
CREATE POLICY p_arrears_clearance_founder ON engineer_wage_arrears_clearance_log
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_engineer_wage_arrears_overview()
RETURNS TABLE(
  open_alerts bigint,
  cleared_alerts bigint,
  escalated_alerts bigint,
  total_backlog_rupees numeric,
  avg_age_days numeric,
  max_age_days integer,
  sla_breached bigint,
  cleared_last_7d bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE status = 'open'),
    COUNT(*) FILTER (WHERE status = 'cleared'),
    COUNT(*) FILTER (WHERE status = 'escalated'),
    COALESCE(SUM(backlog_amount_rupees) FILTER (WHERE status = 'open'), 0),
    COALESCE(AVG(oldest_age_days) FILTER (WHERE status = 'open'), 0),
    COALESCE(MAX(oldest_age_days) FILTER (WHERE status = 'open'), 0)::integer,
    COUNT(*) FILTER (WHERE status = 'open' AND sla_due_at < now()),
    COUNT(*) FILTER (WHERE status = 'cleared' AND cleared_at >= now() - interval '7 days')
  FROM engineer_wage_arrears_alerts;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_wage_arrears_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wage_arrears_overview() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_wage_arrears_open_alerts()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  engineer_phone text,
  backlog_amount_rupees numeric,
  oldest_age_days integer,
  payout_count integer,
  detected_at timestamptz,
  sla_due_at timestamptz,
  sla_breached boolean,
  hours_until_sla numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.engineer_id,
    p.full_name,
    p.phone,
    a.backlog_amount_rupees,
    a.oldest_age_days,
    a.payout_count,
    a.detected_at,
    a.sla_due_at,
    (a.sla_due_at < now()) AS sla_breached,
    EXTRACT(EPOCH FROM (a.sla_due_at - now())) / 3600.0 AS hours_until_sla
  FROM engineer_wage_arrears_alerts a
  JOIN engineers e ON e.id = a.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE a.status = 'open'
  ORDER BY a.oldest_age_days DESC, a.backlog_amount_rupees DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_wage_arrears_open_alerts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wage_arrears_open_alerts() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_wage_arrears_breaches()
RETURNS TABLE(
  id uuid,
  engineer_id uuid,
  engineer_name text,
  backlog_amount_rupees numeric,
  oldest_age_days integer,
  sla_due_at timestamptz,
  hours_past_sla numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id,
    a.engineer_id,
    p.full_name,
    a.backlog_amount_rupees,
    a.oldest_age_days,
    a.sla_due_at,
    EXTRACT(EPOCH FROM (now() - a.sla_due_at)) / 3600.0 AS hours_past_sla
  FROM engineer_wage_arrears_alerts a
  JOIN engineers e ON e.id = a.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE a.status = 'open' AND a.sla_due_at < now()
  ORDER BY a.sla_due_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_wage_arrears_breaches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wage_arrears_breaches() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_wage_arrears_recent_clearances()
RETURNS TABLE(
  id uuid,
  alert_id uuid,
  engineer_name text,
  action text,
  amount_at_action_rupees numeric,
  age_days_at_action integer,
  actor_email text,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.id,
    l.alert_id,
    p.full_name,
    l.action,
    l.amount_at_action_rupees,
    l.age_days_at_action,
    l.actor_email,
    l.note,
    l.created_at
  FROM engineer_wage_arrears_clearance_log l
  JOIN engineers e ON e.id = l.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY l.created_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_wage_arrears_recent_clearances() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wage_arrears_recent_clearances() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_engineer_wage_arrears_scan()
RETURNS TABLE(detected integer, refreshed integer)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_detected integer := 0;
  v_refreshed integer := 0;
  r record;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  FOR r IN
    SELECT
      ep.engineer_user_id,
      MIN(ep.created_at) AS oldest_created_at,
      SUM(ep.amount_rupees) AS total_owed,
      COUNT(*)::integer AS pcount,
      (SELECT id FROM engineer_payouts ep2
        WHERE ep2.engineer_user_id = ep.engineer_user_id
          AND ep2.paid_at IS NULL
        ORDER BY ep2.created_at ASC LIMIT 1) AS oldest_id
    FROM engineer_payouts ep
    WHERE ep.paid_at IS NULL
      AND ep.created_at < now() - interval '30 days'
    GROUP BY ep.engineer_user_id
  LOOP
    DECLARE
      v_eng_id uuid;
      v_age_days integer;
      v_existing uuid;
    BEGIN
      SELECT id INTO v_eng_id FROM engineers WHERE user_id = r.engineer_user_id LIMIT 1;
      IF v_eng_id IS NULL THEN CONTINUE; END IF;

      v_age_days := FLOOR(EXTRACT(EPOCH FROM (now() - r.oldest_created_at)) / 86400.0)::integer;

      SELECT id INTO v_existing
      FROM engineer_wage_arrears_alerts
      WHERE engineer_id = v_eng_id AND status = 'open';

      IF v_existing IS NULL THEN
        INSERT INTO engineer_wage_arrears_alerts(
          engineer_id, oldest_payout_id, backlog_amount_rupees,
          oldest_age_days, payout_count
        ) VALUES (
          v_eng_id, r.oldest_id, r.total_owed, v_age_days, r.pcount
        );
        v_detected := v_detected + 1;
      ELSE
        UPDATE engineer_wage_arrears_alerts
        SET backlog_amount_rupees = r.total_owed,
            oldest_age_days = v_age_days,
            payout_count = r.pcount,
            oldest_payout_id = r.oldest_id,
            updated_at = now()
        WHERE id = v_existing;
        v_refreshed := v_refreshed + 1;
      END IF;
    END;
  END LOOP;

  RETURN QUERY SELECT v_detected, v_refreshed;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_wage_arrears_scan() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wage_arrears_scan() TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_wage_arrears_clear(
  p_alert_id uuid,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_alert engineer_wage_arrears_alerts%ROWTYPE;
  v_log_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT * INTO v_alert FROM engineer_wage_arrears_alerts WHERE id = p_alert_id;
  IF v_alert.id IS NULL THEN RAISE EXCEPTION 'alert not found'; END IF;

  v_email := auth.jwt()->>'email';

  UPDATE engineer_wage_arrears_alerts
  SET status = 'cleared',
      cleared_at = now(),
      cleared_by_user_id = auth.uid(),
      clearance_note = p_note,
      updated_at = now()
  WHERE id = p_alert_id;

  INSERT INTO engineer_wage_arrears_clearance_log(
    alert_id, engineer_id, action, amount_at_action_rupees,
    age_days_at_action, note, actor_user_id, actor_email
  ) VALUES (
    p_alert_id, v_alert.engineer_id, 'cleared',
    v_alert.backlog_amount_rupees, v_alert.oldest_age_days,
    p_note, auth.uid(), v_email
  ) RETURNING id INTO v_log_id;

  PERFORM log_founder_engineer_wage_arrears_clear(p_alert_id, v_alert.backlog_amount_rupees, p_note);

  RETURN v_log_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_wage_arrears_clear(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wage_arrears_clear(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_engineer_wage_arrears_escalate(
  p_alert_id uuid,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_alert engineer_wage_arrears_alerts%ROWTYPE;
  v_log_id uuid;
  v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT * INTO v_alert FROM engineer_wage_arrears_alerts WHERE id = p_alert_id;
  IF v_alert.id IS NULL THEN RAISE EXCEPTION 'alert not found'; END IF;

  v_email := auth.jwt()->>'email';

  UPDATE engineer_wage_arrears_alerts
  SET status = 'escalated', updated_at = now()
  WHERE id = p_alert_id;

  INSERT INTO engineer_wage_arrears_clearance_log(
    alert_id, engineer_id, action, amount_at_action_rupees,
    age_days_at_action, note, actor_user_id, actor_email
  ) VALUES (
    p_alert_id, v_alert.engineer_id, 'escalated',
    v_alert.backlog_amount_rupees, v_alert.oldest_age_days,
    p_note, auth.uid(), v_email
  ) RETURNING id INTO v_log_id;

  PERFORM log_founder_engineer_wage_arrears_escalate(p_alert_id, p_note);

  RETURN v_log_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_engineer_wage_arrears_escalate(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_engineer_wage_arrears_escalate(uuid, text) TO authenticated;

-- ============================================================================
-- log_founder_* helpers (VOLATILE SECDEF, founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_engineer_wage_arrears_scan(
  p_detected integer,
  p_refreshed integer
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    auth.jwt()->>'email',
    'engineer_wage_arrears_scan',
    jsonb_build_object('detected', p_detected, 'refreshed', p_refreshed)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_scan(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_scan(integer, integer) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_engineer_wage_arrears_clear(
  p_alert_id uuid,
  p_amount numeric,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    auth.jwt()->>'email',
    'engineer_wage_arrears_clear',
    jsonb_build_object('alert_id', p_alert_id, 'amount_rupees', p_amount, 'note', p_note)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_clear(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_clear(uuid, numeric, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_engineer_wage_arrears_escalate(
  p_alert_id uuid,
  p_note text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    auth.jwt()->>'email',
    'engineer_wage_arrears_escalate',
    jsonb_build_object('alert_id', p_alert_id, 'note', p_note)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_escalate(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_escalate(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_engineer_wage_arrears_view(
  p_open_count integer,
  p_breach_count integer
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    auth.jwt()->>'email',
    'engineer_wage_arrears_view',
    jsonb_build_object('open_count', p_open_count, 'breach_count', p_breach_count)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_view(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_engineer_wage_arrears_view(integer, integer) TO authenticated;

COMMIT;