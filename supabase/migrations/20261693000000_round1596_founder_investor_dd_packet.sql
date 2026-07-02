BEGIN;

-- =============================================================
-- r1596 — Founder Investor Due Diligence Packet
-- centralized Q&A + supporting docs + access log
-- per-investor packet status; founder approval before send
-- =============================================================

-- ---------- TABLES ----------

CREATE TABLE IF NOT EXISTS founder_dd_packets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text NOT NULL,
  investor_firm text,
  packet_status text NOT NULL DEFAULT 'draft'
    CHECK (packet_status IN ('draft','founder_review','approved','sent','revoked')),
  qa_payload jsonb NOT NULL DEFAULT '[]'::jsonb,
  doc_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
  access_token text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  sent_at timestamptz,
  revoked_at timestamptz,
  approved_by_email text,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_founder_dd_packets_status
  ON founder_dd_packets(packet_status);
CREATE INDEX IF NOT EXISTS idx_founder_dd_packets_created
  ON founder_dd_packets(created_at DESC);

CREATE TABLE IF NOT EXISTS founder_dd_packet_access_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  packet_id uuid NOT NULL REFERENCES founder_dd_packets(id) ON DELETE CASCADE,
  accessed_at timestamptz NOT NULL DEFAULT now(),
  ip_address text,
  user_agent text,
  action text NOT NULL DEFAULT 'view'
    CHECK (action IN ('view','download','qa_open','doc_open'))
);

CREATE INDEX IF NOT EXISTS idx_founder_dd_packet_access_log_packet
  ON founder_dd_packet_access_log(packet_id, accessed_at DESC);

ALTER TABLE founder_dd_packets ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_dd_packet_access_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_dd_packets ON founder_dd_packets;
CREATE POLICY founder_only_dd_packets ON founder_dd_packets
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_dd_packet_access_log ON founder_dd_packet_access_log;
CREATE POLICY founder_only_dd_packet_access_log ON founder_dd_packet_access_log
  FOR ALL TO authenticated
  USING (is_founder()) WITH CHECK (is_founder());

-- ---------- READ RPCs (STABLE) ----------

CREATE OR REPLACE FUNCTION rpc_founder_dd_packet_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_packets', (SELECT count(*) FROM founder_dd_packets),
    'draft', (SELECT count(*) FROM founder_dd_packets WHERE packet_status='draft'),
    'in_review', (SELECT count(*) FROM founder_dd_packets WHERE packet_status='founder_review'),
    'approved', (SELECT count(*) FROM founder_dd_packets WHERE packet_status='approved'),
    'sent', (SELECT count(*) FROM founder_dd_packets WHERE packet_status='sent'),
    'revoked', (SELECT count(*) FROM founder_dd_packets WHERE packet_status='revoked'),
    'sent_24h', (SELECT count(*) FROM founder_dd_packets WHERE sent_at > now() - interval '24 hours'),
    'sent_7d', (SELECT count(*) FROM founder_dd_packets WHERE sent_at > now() - interval '7 days'),
    'sent_30d', (SELECT count(*) FROM founder_dd_packets WHERE sent_at > now() - interval '30 days'),
    'access_24h', (SELECT count(*) FROM founder_dd_packet_access_log WHERE accessed_at > now() - interval '24 hours'),
    'access_7d', (SELECT count(*) FROM founder_dd_packet_access_log WHERE accessed_at > now() - interval '7 days'),
    'unique_investors_30d', (SELECT count(DISTINCT investor_email) FROM founder_dd_packets WHERE created_at > now() - interval '30 days'),
    'avg_qa_items', (SELECT COALESCE(round(avg(jsonb_array_length(qa_payload))::numeric, 1), 0) FROM founder_dd_packets),
    'avg_docs', (SELECT COALESCE(round(avg(jsonb_array_length(doc_refs))::numeric, 1), 0) FROM founder_dd_packets),
    'awaiting_approval', (SELECT count(*) FROM founder_dd_packets WHERE packet_status='founder_review'),
    'never_accessed', (SELECT count(*) FROM founder_dd_packets p WHERE packet_status='sent' AND NOT EXISTS (SELECT 1 FROM founder_dd_packet_access_log l WHERE l.packet_id=p.id))
  ) INTO r;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_dd_packet_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_dd_packet_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_dd_packet_list()
RETURNS TABLE(id uuid, investor_name text, investor_email text, investor_firm text, packet_status text, qa_count int, doc_count int, created_at timestamptz, approved_at timestamptz, sent_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.investor_email, p.investor_firm, p.packet_status,
         jsonb_array_length(p.qa_payload)::int AS qa_count,
         jsonb_array_length(p.doc_refs)::int AS doc_count,
         p.created_at, p.approved_at, p.sent_at
  FROM founder_dd_packets p
  ORDER BY p.created_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_dd_packet_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_dd_packet_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_dd_packet_pending_approval()
RETURNS TABLE(id uuid, investor_name text, investor_firm text, qa_count int, doc_count int, created_at timestamptz, age_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.investor_firm,
         jsonb_array_length(p.qa_payload)::int,
         jsonb_array_length(p.doc_refs)::int,
         p.created_at,
         round((EXTRACT(EPOCH FROM (now() - p.created_at))/3600.0)::numeric, 1)
  FROM founder_dd_packets p
  WHERE p.packet_status = 'founder_review'
  ORDER BY p.created_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_dd_packet_pending_approval() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_dd_packet_pending_approval() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_dd_packet_access_recent()
RETURNS TABLE(packet_id uuid, investor_name text, investor_firm text, action text, accessed_at timestamptz, ip_address text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.packet_id, p.investor_name, p.investor_firm, l.action, l.accessed_at, l.ip_address
  FROM founder_dd_packet_access_log l
  JOIN founder_dd_packets p ON p.id = l.packet_id
  ORDER BY l.accessed_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_dd_packet_access_recent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_dd_packet_access_recent() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_dd_packet_engagement()
RETURNS TABLE(id uuid, investor_name text, investor_firm text, sent_at timestamptz, access_count bigint, last_access timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.investor_name, p.investor_firm, p.sent_at,
         COUNT(l.id), MAX(l.accessed_at)
  FROM founder_dd_packets p
  LEFT JOIN founder_dd_packet_access_log l ON l.packet_id = p.id
  WHERE p.packet_status IN ('sent','approved')
  GROUP BY p.id, p.investor_name, p.investor_firm, p.sent_at
  ORDER BY p.sent_at DESC NULLS LAST
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_dd_packet_engagement() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_dd_packet_engagement() TO authenticated;

-- ---------- WRITE RPCs (VOLATILE) ----------

CREATE OR REPLACE FUNCTION rpc_founder_dd_packet_approve(p_packet_id uuid)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_email text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  UPDATE founder_dd_packets
    SET packet_status='approved', approved_at=now(), approved_by_email=v_email
    WHERE id = p_packet_id AND packet_status='founder_review';
  PERFORM log_founder_dd_packet_approve(p_packet_id);
  RETURN jsonb_build_object('ok', true, 'packet_id', p_packet_id);
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_dd_packet_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_dd_packet_approve(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_dd_packet_revoke(p_packet_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_dd_packets
    SET packet_status='revoked', revoked_at=now(), notes=COALESCE(notes,'') || E'\nREVOKE: ' || COALESCE(p_reason,'')
    WHERE id = p_packet_id;
  PERFORM log_founder_dd_packet_revoke(p_packet_id, p_reason);
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_dd_packet_revoke(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_dd_packet_revoke(uuid, text) TO authenticated;

-- ---------- log_founder_* HELPERS (VOLATILE) ----------

CREATE OR REPLACE FUNCTION log_founder_dd_packet_create(p_packet_id uuid, p_investor text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'dd_packet_create',
          jsonb_build_object('packet_id', p_packet_id, 'investor', p_investor));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dd_packet_create(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dd_packet_create(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_dd_packet_approve(p_packet_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'dd_packet_approve',
          jsonb_build_object('packet_id', p_packet_id));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dd_packet_approve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dd_packet_approve(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_dd_packet_revoke(p_packet_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'dd_packet_revoke',
          jsonb_build_object('packet_id', p_packet_id, 'reason', p_reason));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dd_packet_revoke(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dd_packet_revoke(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_dd_packet_send(p_packet_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'dd_packet_send',
          jsonb_build_object('packet_id', p_packet_id));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_dd_packet_send(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_dd_packet_send(uuid) TO authenticated;

COMMIT;