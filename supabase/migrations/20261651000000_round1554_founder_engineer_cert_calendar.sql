BEGIN;

-- ============================================================
-- r1554 — Founder Engineer Certification Calendar
-- Per-engineer certifications + expiry schedule.
-- Auto-remind 30/60/90 days before expiry.
-- Founder dashboard for upcoming lapses.
-- ============================================================

-- TABLE 1: engineer certifications registry
CREATE TABLE IF NOT EXISTS engineer_certifications_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES engineers(id) ON DELETE CASCADE,
  cert_code text NOT NULL,
  cert_name text NOT NULL,
  cert_authority text,
  issued_on date NOT NULL,
  expires_on date NOT NULL,
  cert_status text NOT NULL DEFAULT 'active' CHECK (cert_status IN ('active','expired','revoked','renewed','pending')),
  evidence_url text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_certs_v2_engineer ON engineer_certifications_v2(engineer_id);
CREATE INDEX IF NOT EXISTS idx_eng_certs_v2_expires ON engineer_certifications_v2(expires_on);
CREATE INDEX IF NOT EXISTS idx_eng_certs_v2_status ON engineer_certifications_v2(cert_status);

ALTER TABLE engineer_certifications_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_eng_certs_v2 ON engineer_certifications_v2;
CREATE POLICY founder_only_eng_certs_v2 ON engineer_certifications_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- TABLE 2: reminder schedule + dispatch log
CREATE TABLE IF NOT EXISTS engineer_cert_reminders_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cert_id uuid NOT NULL REFERENCES engineer_certifications_v2(id) ON DELETE CASCADE,
  reminder_window int NOT NULL CHECK (reminder_window IN (30,60,90)),
  scheduled_for date NOT NULL,
  dispatched_at timestamptz,
  dispatch_status text NOT NULL DEFAULT 'queued' CHECK (dispatch_status IN ('queued','sent','failed','skipped')),
  channel text NOT NULL DEFAULT 'email' CHECK (channel IN ('email','sms','push','whatsapp')),
  payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eng_cert_rem_v2_cert ON engineer_cert_reminders_v2(cert_id);
CREATE INDEX IF NOT EXISTS idx_eng_cert_rem_v2_sched ON engineer_cert_reminders_v2(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_eng_cert_rem_v2_status ON engineer_cert_reminders_v2(dispatch_status);

ALTER TABLE engineer_cert_reminders_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_eng_cert_rem_v2 ON engineer_cert_reminders_v2;
CREATE POLICY founder_only_eng_cert_rem_v2 ON engineer_cert_reminders_v2
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_cert_register(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cert_register', p_after);
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_cert_register(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cert_register(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cert_renew(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cert_renew', p_after);
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_cert_renew(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cert_renew(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cert_revoke(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cert_revoke', p_after);
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_cert_revoke(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cert_revoke(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_cert_reminder_dispatched(p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'cert_reminder_dispatched', p_after);
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_cert_reminder_dispatched(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_cert_reminder_dispatched(jsonb) TO authenticated;

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_cert_calendar_kpis()
RETURNS TABLE (
  total_certs int,
  active_certs int,
  expired_certs int,
  revoked_certs int,
  expiring_30d int,
  expiring_60d int,
  expiring_90d int,
  lapsed_unrenewed int,
  unique_engineers int,
  unique_authorities int,
  reminders_queued int,
  reminders_sent_30d int,
  reminders_failed_30d int,
  avg_days_to_expiry numeric,
  pct_active numeric,
  next_expiry_in_days int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*)::int FROM engineer_certifications_v2),
    (SELECT count(*)::int FROM engineer_certifications_v2 WHERE cert_status='active'),
    (SELECT count(*)::int FROM engineer_certifications_v2 WHERE cert_status='expired'),
    (SELECT count(*)::int FROM engineer_certifications_v2 WHERE cert_status='revoked'),
    (SELECT count(*)::int FROM engineer_certifications_v2 WHERE cert_status='active' AND expires_on BETWEEN current_date AND current_date + 30),
    (SELECT count(*)::int FROM engineer_certifications_v2 WHERE cert_status='active' AND expires_on BETWEEN current_date AND current_date + 60),
    (SELECT count(*)::int FROM engineer_certifications_v2 WHERE cert_status='active' AND expires_on BETWEEN current_date AND current_date + 90),
    (SELECT count(*)::int FROM engineer_certifications_v2 WHERE expires_on < current_date AND cert_status NOT IN ('renewed','revoked')),
    (SELECT count(DISTINCT engineer_id)::int FROM engineer_certifications_v2),
    (SELECT count(DISTINCT cert_authority)::int FROM engineer_certifications_v2 WHERE cert_authority IS NOT NULL),
    (SELECT count(*)::int FROM engineer_cert_reminders_v2 WHERE dispatch_status='queued'),
    (SELECT count(*)::int FROM engineer_cert_reminders_v2 WHERE dispatch_status='sent' AND dispatched_at > now() - interval '30 days'),
    (SELECT count(*)::int FROM engineer_cert_reminders_v2 WHERE dispatch_status='failed' AND created_at > now() - interval '30 days'),
    (SELECT round(avg(EXTRACT(EPOCH FROM (expires_on::timestamp - current_date::timestamp))/86400.0)::numeric, 1) FROM engineer_certifications_v2 WHERE cert_status='active'),
    (SELECT round(100.0 * count(*) FILTER (WHERE cert_status='active') / NULLIF(count(*),0), 1) FROM engineer_certifications_v2),
    (SELECT (EXTRACT(EPOCH FROM (min(expires_on)::timestamp - current_date::timestamp))/86400.0)::int FROM engineer_certifications_v2 WHERE cert_status='active' AND expires_on >= current_date);
END;$$;
REVOKE EXECUTE ON FUNCTION founder_cert_calendar_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cert_calendar_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cert_upcoming_lapses()
RETURNS TABLE (
  id uuid,
  engineer_id uuid,
  engineer_name text,
  cert_code text,
  cert_name text,
  cert_authority text,
  expires_on date,
  days_remaining int,
  cert_status text,
  window_bucket text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.engineer_id,
    COALESCE(p.full_name, e.id::text) AS engineer_name,
    c.cert_code,
    c.cert_name,
    c.cert_authority,
    c.expires_on,
    (EXTRACT(EPOCH FROM (c.expires_on::timestamp - current_date::timestamp))/86400.0)::int AS days_remaining,
    c.cert_status,
    CASE
      WHEN c.expires_on <= current_date + 30 THEN '30d'
      WHEN c.expires_on <= current_date + 60 THEN '60d'
      ELSE '90d'
    END AS window_bucket
  FROM engineer_certifications_v2 c
  JOIN engineers e ON e.id = c.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE c.cert_status = 'active'
    AND c.expires_on BETWEEN current_date AND current_date + 90
  ORDER BY c.expires_on ASC
  LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_cert_upcoming_lapses() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cert_upcoming_lapses() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cert_per_engineer_summary()
RETURNS TABLE (
  engineer_id uuid,
  engineer_name text,
  cached_tier text,
  total_certs int,
  active_certs int,
  expiring_90d int,
  expired_certs int,
  next_expiry date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    COALESCE(p.full_name, e.id::text),
    e.cached_highest_tier::text,
    count(c.*)::int,
    count(*) FILTER (WHERE c.cert_status='active')::int,
    count(*) FILTER (WHERE c.cert_status='active' AND c.expires_on BETWEEN current_date AND current_date + 90)::int,
    count(*) FILTER (WHERE c.cert_status='expired')::int,
    min(c.expires_on) FILTER (WHERE c.cert_status='active')
  FROM engineers e
  LEFT JOIN profiles p ON p.id = e.user_id
  LEFT JOIN engineer_certifications_v2 c ON c.engineer_id = e.id
  GROUP BY e.id, p.full_name, e.cached_highest_tier
  HAVING count(c.*) > 0
  ORDER BY count(*) FILTER (WHERE c.cert_status='active' AND c.expires_on BETWEEN current_date AND current_date + 90) DESC,
           min(c.expires_on) FILTER (WHERE c.cert_status='active') ASC NULLS LAST
  LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_cert_per_engineer_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cert_per_engineer_summary() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cert_reminder_queue()
RETURNS TABLE (
  id uuid,
  cert_id uuid,
  engineer_name text,
  cert_name text,
  reminder_window int,
  scheduled_for date,
  dispatch_status text,
  channel text,
  dispatched_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id,
    r.cert_id,
    COALESCE(p.full_name, e.id::text),
    c.cert_name,
    r.reminder_window,
    r.scheduled_for,
    r.dispatch_status,
    r.channel,
    r.dispatched_at
  FROM engineer_cert_reminders_v2 r
  JOIN engineer_certifications_v2 c ON c.id = r.cert_id
  JOIN engineers e ON e.id = c.engineer_id
  LEFT JOIN profiles p ON p.id = e.user_id
  ORDER BY r.scheduled_for ASC, r.created_at DESC
  LIMIT 200;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_cert_reminder_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cert_reminder_queue() TO authenticated;

CREATE OR REPLACE FUNCTION founder_cert_authority_breakdown()
RETURNS TABLE (
  cert_authority text,
  total_certs int,
  active_certs int,
  expiring_90d int,
  expired_certs int,
  pct_active numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COALESCE(c.cert_authority, 'unspecified'),
    count(*)::int,
    count(*) FILTER (WHERE c.cert_status='active')::int,
    count(*) FILTER (WHERE c.cert_status='active' AND c.expires_on BETWEEN current_date AND current_date + 90)::int,
    count(*) FILTER (WHERE c.cert_status='expired')::int,
    round(100.0 * count(*) FILTER (WHERE c.cert_status='active') / NULLIF(count(*),0), 1)
  FROM engineer_certifications_v2 c
  GROUP BY COALESCE(c.cert_authority, 'unspecified')
  ORDER BY count(*) DESC
  LIMIT 100;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_cert_authority_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cert_authority_breakdown() TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_cert_register(
  p_engineer_id uuid,
  p_cert_code text,
  p_cert_name text,
  p_cert_authority text,
  p_issued_on date,
  p_expires_on date,
  p_evidence_url text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_cert_id uuid;
  v_window int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO engineer_certifications_v2 (engineer_id, cert_code, cert_name, cert_authority, issued_on, expires_on, evidence_url, notes)
  VALUES (p_engineer_id, p_cert_code, p_cert_name, p_cert_authority, p_issued_on, p_expires_on, p_evidence_url, p_notes)
  RETURNING id INTO v_cert_id;

  FOREACH v_window IN ARRAY ARRAY[30,60,90] LOOP
    IF p_expires_on - v_window >= current_date THEN
      INSERT INTO engineer_cert_reminders_v2 (cert_id, reminder_window, scheduled_for, channel)
      VALUES (v_cert_id, v_window, p_expires_on - v_window, 'email');
    END IF;
  END LOOP;

  PERFORM log_founder_cert_register(jsonb_build_object('cert_id', v_cert_id, 'engineer_id', p_engineer_id, 'expires_on', p_expires_on));
  RETURN v_cert_id;
END;$$;
REVOKE EXECUTE ON FUNCTION founder_cert_register(uuid,text,text,text,date,date,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cert_register(uuid,text,text,text,date,date,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_cert_renew(
  p_cert_id uuid,
  p_new_expires_on date,
  p_evidence_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_window int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE engineer_certifications_v2
     SET expires_on = p_new_expires_on,
         cert_status = 'active',
         evidence_url = COALESCE(p_evidence_url, evidence_url),
         updated_at = now()
   WHERE id = p_cert_id;

  DELETE FROM engineer_cert_reminders_v2 WHERE cert_id = p_cert_id AND dispatch_status = 'queued';

  FOREACH v_window IN ARRAY ARRAY[30,60,90] LOOP
    IF p_new_expires_on - v_window >= current_date THEN
      INSERT INTO engineer_cert_reminders_v2 (cert_id, reminder_window, scheduled_for, channel)
      VALUES (p_cert_id, v_window, p_new_expires_on - v_window, 'email');
    END IF;
  END LOOP;

  PERFORM log_founder_cert_renew(jsonb_build_object('cert_id', p_cert_id, 'new_expires_on', p_new_expires_on));
END;$$;
REVOKE EXECUTE ON FUNCTION founder_cert_renew(uuid,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_cert_renew(uuid,date,text) TO authenticated;

COMMIT;