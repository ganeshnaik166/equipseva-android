BEGIN;

-- ============================================================================
-- r1580 — Founder Investor Portfolio NDA Tracker
-- Per-investor NDA status (signed/pending/declined); covers data room access;
-- auto-expire after 1 year; founder counter-sign queue.
-- ============================================================================

-- Table 1: investor NDA records
CREATE TABLE IF NOT EXISTS founder_investor_nda_records_v4 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name   text NOT NULL,
  investor_email  text NOT NULL,
  firm_name       text,
  nda_status      text NOT NULL DEFAULT 'pending' CHECK (nda_status IN ('pending','signed','declined','expired','countersigned')),
  investor_signed_at        timestamptz,
  founder_countersigned_at  timestamptz,
  declined_at     timestamptz,
  expires_at      timestamptz,
  data_room_url   text,
  data_room_access_granted boolean NOT NULL DEFAULT false,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_finr_v4_status ON founder_investor_nda_records_v4(nda_status);
CREATE INDEX IF NOT EXISTS idx_finr_v4_expires ON founder_investor_nda_records_v4(expires_at);
CREATE INDEX IF NOT EXISTS idx_finr_v4_email ON founder_investor_nda_records_v4(investor_email);

ALTER TABLE founder_investor_nda_records_v4 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_finr_v4 ON founder_investor_nda_records_v4;
CREATE POLICY founder_only_finr_v4 ON founder_investor_nda_records_v4
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: data room access events
CREATE TABLE IF NOT EXISTS founder_investor_nda_access_events_v4 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nda_id          uuid NOT NULL REFERENCES founder_investor_nda_records_v4(id) ON DELETE CASCADE,
  event_type      text NOT NULL CHECK (event_type IN ('granted','revoked','viewed','expired')),
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  details         jsonb
);

CREATE INDEX IF NOT EXISTS idx_finae_v4_nda ON founder_investor_nda_access_events_v4(nda_id);
CREATE INDEX IF NOT EXISTS idx_finae_v4_occurred ON founder_investor_nda_access_events_v4(occurred_at DESC);

ALTER TABLE founder_investor_nda_access_events_v4 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_finae_v4 ON founder_investor_nda_access_events_v4;
CREATE POLICY founder_only_finae_v4 ON founder_investor_nda_access_events_v4
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- log helpers (VOLATILE SECDEF)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_nda_created_r1580(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nda_created_r1580', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_nda_created_r1580(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nda_created_r1580(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_nda_countersigned_r1580(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nda_countersigned_r1580', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_nda_countersigned_r1580(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nda_countersigned_r1580(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_nda_access_changed_r1580(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nda_access_changed_r1580', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_nda_access_changed_r1580(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nda_access_changed_r1580(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_nda_expired_r1580(p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'nda_expired_r1580', p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_nda_expired_r1580(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_nda_expired_r1580(jsonb) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_nda_kpis_r1580()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_records', (SELECT COUNT(*) FROM founder_investor_nda_records_v4),
    'pending', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE nda_status='pending'),
    'signed', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE nda_status='signed'),
    'countersigned', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE nda_status='countersigned'),
    'declined', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE nda_status='declined'),
    'expired', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE nda_status='expired'),
    'access_granted', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE data_room_access_granted),
    'access_revoked', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE NOT data_room_access_granted),
    'expiring_30d', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE expires_at IS NOT NULL AND expires_at > now() AND expires_at < now() + interval '30 days'),
    'expiring_7d', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE expires_at IS NOT NULL AND expires_at > now() AND expires_at < now() + interval '7 days'),
    'overdue_countersign', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE nda_status='signed' AND investor_signed_at < now() - interval '3 days'),
    'awaiting_countersign', (SELECT COUNT(*) FROM founder_investor_nda_records_v4 WHERE nda_status='signed'),
    'access_events_total', (SELECT COUNT(*) FROM founder_investor_nda_access_events_v4),
    'access_events_7d', (SELECT COUNT(*) FROM founder_investor_nda_access_events_v4 WHERE occurred_at > now() - interval '7 days'),
    'firms_distinct', (SELECT COUNT(DISTINCT firm_name) FROM founder_investor_nda_records_v4 WHERE firm_name IS NOT NULL),
    'avg_days_to_countersign', COALESCE((SELECT ROUND(AVG(EXTRACT(EPOCH FROM (founder_countersigned_at - investor_signed_at))/86400.0)::numeric, 2) FROM founder_investor_nda_records_v4 WHERE founder_countersigned_at IS NOT NULL AND investor_signed_at IS NOT NULL), 0)
  ) INTO v_result;
  RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_nda_kpis_r1580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_nda_kpis_r1580() TO authenticated;

CREATE OR REPLACE FUNCTION founder_nda_list_records_r1580()
RETURNS TABLE(id uuid, investor_name text, investor_email text, firm_name text, nda_status text, investor_signed_at timestamptz, founder_countersigned_at timestamptz, expires_at timestamptz, data_room_access_granted boolean, created_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.investor_email, r.firm_name, r.nda_status,
         r.investor_signed_at, r.founder_countersigned_at, r.expires_at,
         r.data_room_access_granted, r.created_at
  FROM founder_investor_nda_records_v4 r
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_nda_list_records_r1580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_nda_list_records_r1580() TO authenticated;

CREATE OR REPLACE FUNCTION founder_nda_countersign_queue_r1580()
RETURNS TABLE(id uuid, investor_name text, firm_name text, investor_signed_at timestamptz, days_waiting numeric)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.firm_name, r.investor_signed_at,
         ROUND(EXTRACT(EPOCH FROM (now() - r.investor_signed_at))/86400.0, 2) AS days_waiting
  FROM founder_investor_nda_records_v4 r
  WHERE r.nda_status = 'signed'
  ORDER BY r.investor_signed_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_nda_countersign_queue_r1580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_nda_countersign_queue_r1580() TO authenticated;

CREATE OR REPLACE FUNCTION founder_nda_expiring_soon_r1580()
RETURNS TABLE(id uuid, investor_name text, firm_name text, expires_at timestamptz, days_to_expire numeric)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.investor_name, r.firm_name, r.expires_at,
         ROUND(EXTRACT(EPOCH FROM (r.expires_at - now()))/86400.0, 2) AS days_to_expire
  FROM founder_investor_nda_records_v4 r
  WHERE r.expires_at IS NOT NULL
    AND r.expires_at > now()
    AND r.expires_at < now() + interval '60 days'
  ORDER BY r.expires_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_nda_expiring_soon_r1580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_nda_expiring_soon_r1580() TO authenticated;

CREATE OR REPLACE FUNCTION founder_nda_access_events_r1580()
RETURNS TABLE(id uuid, nda_id uuid, investor_name text, event_type text, occurred_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.nda_id, r.investor_name, e.event_type, e.occurred_at
  FROM founder_investor_nda_access_events_v4 e
  JOIN founder_investor_nda_records_v4 r ON r.id = e.nda_id
  ORDER BY e.occurred_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_nda_access_events_r1580() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_nda_access_events_r1580() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_nda_create_record_r1580(p_name text, p_email text, p_firm text, p_data_room_url text)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_nda_records_v4(investor_name, investor_email, firm_name, data_room_url)
  VALUES (p_name, p_email, p_firm, p_data_room_url)
  RETURNING id INTO v_id;
  PERFORM log_founder_nda_created_r1580(jsonb_build_object('id', v_id, 'name', p_name, 'email', p_email));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_nda_create_record_r1580(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_nda_create_record_r1580(text, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_nda_countersign_r1580(p_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_nda_records_v4
  SET nda_status = 'countersigned',
      founder_countersigned_at = now(),
      expires_at = COALESCE(expires_at, now() + interval '365 days'),
      data_room_access_granted = true,
      updated_at = now()
  WHERE id = p_id;
  INSERT INTO founder_investor_nda_access_events_v4(nda_id, event_type, details)
  VALUES (p_id, 'granted', jsonb_build_object('reason','countersigned'));
  PERFORM log_founder_nda_countersigned_r1580(jsonb_build_object('id', p_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION founder_nda_countersign_r1580(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_nda_countersign_r1580(uuid) TO authenticated;

COMMIT;