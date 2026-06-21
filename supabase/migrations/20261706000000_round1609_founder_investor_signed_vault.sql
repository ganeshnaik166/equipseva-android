BEGIN;

-- ============================================================
-- r1609 — Founder Investor Signed Agreements Vault
-- Central vault for SAFEs, term sheets, share-purchase agreements.
-- Tracks per-doc PDF link, signing date, parties, founder counter-sign queue.
-- ============================================================

-- Tables
CREATE TABLE IF NOT EXISTS founder_investor_signed_vault (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  doc_type text NOT NULL CHECK (doc_type IN ('safe','term_sheet','spa','sha','nda','side_letter','convertible_note','other')),
  doc_title text NOT NULL,
  investor_name text NOT NULL,
  investor_email text,
  pdf_url text NOT NULL,
  amount_rupees bigint,
  signing_date date,
  counterparties text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending_counter_sign' CHECK (status IN ('pending_counter_sign','counter_signed','executed','rejected','draft','archived')),
  is_counter_signed boolean NOT NULL DEFAULT false,
  counter_signed_at timestamptz,
  counter_signed_by uuid,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isv_status ON founder_investor_signed_vault(status);
CREATE INDEX IF NOT EXISTS idx_isv_doc_type ON founder_investor_signed_vault(doc_type);
CREATE INDEX IF NOT EXISTS idx_isv_signing_date ON founder_investor_signed_vault(signing_date);
CREATE INDEX IF NOT EXISTS idx_isv_created_at ON founder_investor_signed_vault(created_at);

CREATE TABLE IF NOT EXISTS founder_investor_signed_vault_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vault_id uuid NOT NULL REFERENCES founder_investor_signed_vault(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','viewed','counter_signed','rejected','executed','archived','note_added','updated')),
  event_notes text,
  actor_user_id uuid,
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isve_vault_id ON founder_investor_signed_vault_events(vault_id);
CREATE INDEX IF NOT EXISTS idx_isve_created_at ON founder_investor_signed_vault_events(created_at);

-- RLS
ALTER TABLE founder_investor_signed_vault ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_investor_signed_vault_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_isv ON founder_investor_signed_vault;
CREATE POLICY founder_only_isv ON founder_investor_signed_vault
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_isve ON founder_investor_signed_vault_events;
CREATE POLICY founder_only_isve ON founder_investor_signed_vault_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- log helpers (VOLATILE SECDEF)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_isv_action(
  p_op_name text,
  p_after jsonb
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op_name, p_after);
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isv_action(text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isv_action(text,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_isv_view(
  p_vault_id uuid
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_signed_vault_events(vault_id, event_type, actor_user_id, actor_email)
  VALUES (p_vault_id, 'viewed', auth.uid(), (auth.jwt()->>'email'));
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'isv_view', jsonb_build_object('vault_id', p_vault_id));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isv_view(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isv_view(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_isv_event(
  p_vault_id uuid,
  p_event_type text,
  p_notes text
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_signed_vault_events(vault_id, event_type, event_notes, actor_user_id, actor_email)
  VALUES (p_vault_id, p_event_type, p_notes, auth.uid(), (auth.jwt()->>'email'));
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'isv_event_' || p_event_type, jsonb_build_object('vault_id', p_vault_id, 'notes', p_notes));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isv_event(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isv_event(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_isv_audit(
  p_op_name text,
  p_vault_id uuid,
  p_payload jsonb
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op_name, jsonb_build_object('vault_id', p_vault_id) || COALESCE(p_payload, '{}'::jsonb));
END;
$$;
REVOKE EXECUTE ON FUNCTION log_founder_isv_audit(text,uuid,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_isv_audit(text,uuid,jsonb) TO authenticated;

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_isv_overview()
RETURNS TABLE(
  total_docs bigint,
  pending_counter_sign bigint,
  counter_signed bigint,
  executed bigint,
  rejected bigint,
  draft_count bigint,
  archived_count bigint,
  safe_count bigint,
  term_sheet_count bigint,
  spa_count bigint,
  sha_count bigint,
  nda_count bigint,
  total_capital_rupees bigint,
  signed_last_30d bigint,
  pending_over_7d bigint,
  avg_days_to_countersign numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (SELECT * FROM founder_investor_signed_vault)
  SELECT
    (SELECT count(*) FROM base)::bigint,
    (SELECT count(*) FROM base WHERE status='pending_counter_sign')::bigint,
    (SELECT count(*) FROM base WHERE status='counter_signed')::bigint,
    (SELECT count(*) FROM base WHERE status='executed')::bigint,
    (SELECT count(*) FROM base WHERE status='rejected')::bigint,
    (SELECT count(*) FROM base WHERE status='draft')::bigint,
    (SELECT count(*) FROM base WHERE status='archived')::bigint,
    (SELECT count(*) FROM base WHERE doc_type='safe')::bigint,
    (SELECT count(*) FROM base WHERE doc_type='term_sheet')::bigint,
    (SELECT count(*) FROM base WHERE doc_type='spa')::bigint,
    (SELECT count(*) FROM base WHERE doc_type='sha')::bigint,
    (SELECT count(*) FROM base WHERE doc_type='nda')::bigint,
    COALESCE((SELECT sum(amount_rupees) FROM base WHERE status IN ('counter_signed','executed')),0)::bigint,
    (SELECT count(*) FROM base WHERE signing_date >= (now()::date - 30))::bigint,
    (SELECT count(*) FROM base WHERE status='pending_counter_sign' AND created_at < now() - interval '7 days')::bigint,
    COALESCE((SELECT avg(EXTRACT(EPOCH FROM (counter_signed_at - created_at))/86400.0) FROM base WHERE counter_signed_at IS NOT NULL), 0)::numeric;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_isv_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_isv_overview() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_isv_pending_queue()
RETURNS TABLE(
  id uuid,
  doc_type text,
  doc_title text,
  investor_name text,
  amount_rupees bigint,
  pdf_url text,
  signing_date date,
  days_pending numeric,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.doc_type, v.doc_title, v.investor_name, v.amount_rupees, v.pdf_url, v.signing_date,
         ROUND(EXTRACT(EPOCH FROM (now() - v.created_at))/86400.0, 1)::numeric AS days_pending,
         v.created_at
  FROM founder_investor_signed_vault v
  WHERE v.status = 'pending_counter_sign'
  ORDER BY v.created_at ASC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_isv_pending_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_isv_pending_queue() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_isv_recent_docs()
RETURNS TABLE(
  id uuid,
  doc_type text,
  doc_title text,
  investor_name text,
  pdf_url text,
  signing_date date,
  status text,
  amount_rupees bigint,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.doc_type, v.doc_title, v.investor_name, v.pdf_url, v.signing_date, v.status, v.amount_rupees, v.created_at
  FROM founder_investor_signed_vault v
  ORDER BY v.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_isv_recent_docs() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_isv_recent_docs() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_isv_by_doc_type()
RETURNS TABLE(
  doc_type text,
  doc_count bigint,
  total_rupees bigint,
  pending_count bigint,
  executed_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.doc_type,
         count(*)::bigint,
         COALESCE(sum(v.amount_rupees),0)::bigint,
         count(*) FILTER (WHERE v.status='pending_counter_sign')::bigint,
         count(*) FILTER (WHERE v.status='executed')::bigint
  FROM founder_investor_signed_vault v
  GROUP BY v.doc_type
  ORDER BY count(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_isv_by_doc_type() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_isv_by_doc_type() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_isv_recent_events()
RETURNS TABLE(
  id uuid,
  vault_id uuid,
  doc_title text,
  event_type text,
  event_notes text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.vault_id, v.doc_title, e.event_type, e.event_notes, e.actor_email, e.created_at
  FROM founder_investor_signed_vault_events e
  LEFT JOIN founder_investor_signed_vault v ON v.id = e.vault_id
  ORDER BY e.created_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_isv_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_isv_recent_events() TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_isv_register_doc(
  p_doc_type text,
  p_doc_title text,
  p_investor_name text,
  p_investor_email text,
  p_pdf_url text,
  p_amount_rupees bigint,
  p_signing_date date,
  p_counterparties text[],
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_investor_signed_vault(doc_type, doc_title, investor_name, investor_email, pdf_url, amount_rupees, signing_date, counterparties, notes)
  VALUES (p_doc_type, p_doc_title, p_investor_name, p_investor_email, p_pdf_url, p_amount_rupees, p_signing_date, COALESCE(p_counterparties,'{}'), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO founder_investor_signed_vault_events(vault_id, event_type, actor_user_id, actor_email)
  VALUES (v_id, 'created', auth.uid(), (auth.jwt()->>'email'));

  PERFORM log_founder_isv_audit('isv_register_doc', v_id, jsonb_build_object('doc_type', p_doc_type, 'investor', p_investor_name));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_isv_register_doc(text,text,text,text,text,bigint,date,text[],text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_isv_register_doc(text,text,text,text,text,bigint,date,text[],text) TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_isv_counter_sign(
  p_vault_id uuid,
  p_notes text
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_signed_vault
  SET status='counter_signed', is_counter_signed=true, counter_signed_at=now(), counter_signed_by=auth.uid(), updated_at=now()
  WHERE id=p_vault_id;

  INSERT INTO founder_investor_signed_vault_events(vault_id, event_type, event_notes, actor_user_id, actor_email)
  VALUES (p_vault_id, 'counter_signed', p_notes, auth.uid(), (auth.jwt()->>'email'));

  PERFORM log_founder_isv_audit('isv_counter_sign', p_vault_id, jsonb_build_object('notes', p_notes));
END;
$$;
REVOKE EXECUTE ON FUNCTION rpc_founder_isv_counter_sign(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_isv_counter_sign(uuid,text) TO authenticated;

COMMIT;