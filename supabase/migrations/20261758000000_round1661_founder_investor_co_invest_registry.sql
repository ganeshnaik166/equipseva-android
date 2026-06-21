BEGIN;

-- ============================================================
-- r1661 — Founder Investor Co-Invest Registry
-- Log when investor brings co-investors to our round;
-- per-co-investor source attribution; founder thank-you log.
-- ============================================================

-- Table 1: co-invest entries (one row per co-investor brought in)
CREATE TABLE IF NOT EXISTS founder_investor_co_invest_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_investor_name text NOT NULL,
  source_investor_email text,
  co_investor_name text NOT NULL,
  co_investor_email text,
  co_investor_firm text,
  round_label text NOT NULL DEFAULT 'seed',
  commitment_rupees bigint NOT NULL DEFAULT 0 CHECK (commitment_rupees >= 0),
  status text NOT NULL DEFAULT 'introduced' CHECK (status IN ('introduced','meeting_set','term_sheet','committed','wired','passed')),
  intro_at timestamptz NOT NULL DEFAULT now(),
  committed_at timestamptz,
  wired_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_co_invest_entries_source ON founder_investor_co_invest_entries(source_investor_email);
CREATE INDEX IF NOT EXISTS idx_co_invest_entries_status ON founder_investor_co_invest_entries(status);
CREATE INDEX IF NOT EXISTS idx_co_invest_entries_intro_at ON founder_investor_co_invest_entries(intro_at DESC);

ALTER TABLE founder_investor_co_invest_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_co_invest_entries_founder ON founder_investor_co_invest_entries;
CREATE POLICY p_co_invest_entries_founder ON founder_investor_co_invest_entries
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- Table 2: founder thank-you log (per source investor)
CREATE TABLE IF NOT EXISTS founder_investor_co_invest_thanks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_investor_name text NOT NULL,
  source_investor_email text,
  channel text NOT NULL DEFAULT 'email' CHECK (channel IN ('email','call','whatsapp','in_person','gift')),
  message_excerpt text,
  sent_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_co_invest_thanks_source ON founder_investor_co_invest_thanks(source_investor_email);
CREATE INDEX IF NOT EXISTS idx_co_invest_thanks_sent_at ON founder_investor_co_invest_thanks(sent_at DESC);

ALTER TABLE founder_investor_co_invest_thanks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_co_invest_thanks_founder ON founder_investor_co_invest_thanks;
CREATE POLICY p_co_invest_thanks_founder ON founder_investor_co_invest_thanks
  FOR ALL USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================
-- Helper: log founder action
-- ============================================================
CREATE OR REPLACE FUNCTION log_founder_co_invest_action(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_co_invest_action(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_co_invest_action(text, jsonb) TO authenticated;

-- ============================================================
-- RPC 1: list_co_invest_entries — STABLE
-- ============================================================
CREATE OR REPLACE FUNCTION list_co_invest_entries()
RETURNS TABLE (
  id uuid,
  source_investor_name text,
  source_investor_email text,
  co_investor_name text,
  co_investor_firm text,
  round_label text,
  commitment_rupees bigint,
  status text,
  intro_at timestamptz,
  committed_at timestamptz,
  wired_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.id, e.source_investor_name, e.source_investor_email,
         e.co_investor_name, e.co_investor_firm, e.round_label,
         e.commitment_rupees, e.status, e.intro_at, e.committed_at, e.wired_at
  FROM founder_investor_co_invest_entries e
  ORDER BY e.intro_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_co_invest_entries() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_co_invest_entries() TO authenticated;

-- ============================================================
-- RPC 2: list_co_invest_by_source — STABLE
-- Aggregates per source investor
-- ============================================================
CREATE OR REPLACE FUNCTION list_co_invest_by_source()
RETURNS TABLE (
  source_investor_name text,
  source_investor_email text,
  intros_count int,
  committed_count int,
  wired_count int,
  total_committed_rupees bigint,
  total_wired_rupees bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT e.source_investor_name,
         e.source_investor_email,
         (COUNT(*))::int AS intros_count,
         (COUNT(*) FILTER (WHERE e.status IN ('committed','wired')))::int AS committed_count,
         (COUNT(*) FILTER (WHERE e.status = 'wired'))::int AS wired_count,
         COALESCE(SUM(e.commitment_rupees) FILTER (WHERE e.status IN ('committed','wired')), 0)::bigint AS total_committed_rupees,
         COALESCE(SUM(e.commitment_rupees) FILTER (WHERE e.status = 'wired'), 0)::bigint AS total_wired_rupees
  FROM founder_investor_co_invest_entries e
  GROUP BY e.source_investor_name, e.source_investor_email
  ORDER BY total_wired_rupees DESC NULLS LAST, intros_count DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_co_invest_by_source() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_co_invest_by_source() TO authenticated;

-- ============================================================
-- RPC 3: list_co_invest_thanks — STABLE
-- ============================================================
CREATE OR REPLACE FUNCTION list_co_invest_thanks()
RETURNS TABLE (
  id uuid,
  source_investor_name text,
  source_investor_email text,
  channel text,
  message_excerpt text,
  sent_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT t.id, t.source_investor_name, t.source_investor_email,
         t.channel, t.message_excerpt, t.sent_at
  FROM founder_investor_co_invest_thanks t
  ORDER BY t.sent_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION list_co_invest_thanks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION list_co_invest_thanks() TO authenticated;

-- ============================================================
-- RPC 4: co_invest_summary — STABLE
-- ============================================================
CREATE OR REPLACE FUNCTION co_invest_summary()
RETURNS TABLE (
  total_entries int,
  unique_sources int,
  committed_entries int,
  wired_entries int,
  total_committed_rupees bigint,
  total_wired_rupees bigint,
  thanks_sent int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT (SELECT COUNT(*) FROM founder_investor_co_invest_entries)::int,
         (SELECT COUNT(DISTINCT source_investor_email) FROM founder_investor_co_invest_entries)::int,
         (SELECT COUNT(*) FILTER (WHERE status IN ('committed','wired')) FROM founder_investor_co_invest_entries)::int,
         (SELECT COUNT(*) FILTER (WHERE status = 'wired') FROM founder_investor_co_invest_entries)::int,
         (SELECT COALESCE(SUM(commitment_rupees) FILTER (WHERE status IN ('committed','wired')), 0) FROM founder_investor_co_invest_entries)::bigint,
         (SELECT COALESCE(SUM(commitment_rupees) FILTER (WHERE status = 'wired'), 0) FROM founder_investor_co_invest_entries)::bigint,
         (SELECT COUNT(*) FROM founder_investor_co_invest_thanks)::int;
END;
$$;

REVOKE EXECUTE ON FUNCTION co_invest_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION co_invest_summary() TO authenticated;

-- ============================================================
-- RPC 5: record_co_invest_entry — VOLATILE (write)
-- ============================================================
CREATE OR REPLACE FUNCTION record_co_invest_entry(
  p_source_name text,
  p_source_email text,
  p_co_investor_name text,
  p_co_investor_email text,
  p_co_investor_firm text,
  p_round_label text,
  p_commitment_rupees bigint,
  p_status text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_investor_co_invest_entries (
    source_investor_name, source_investor_email,
    co_investor_name, co_investor_email, co_investor_firm,
    round_label, commitment_rupees, status, notes
  ) VALUES (
    p_source_name, p_source_email,
    p_co_investor_name, p_co_investor_email, p_co_investor_firm,
    COALESCE(p_round_label, 'seed'),
    COALESCE(p_commitment_rupees, 0),
    COALESCE(p_status, 'introduced'),
    p_notes
  ) RETURNING id INTO v_id;

  PERFORM log_founder_co_invest_action('co_invest_entry_recorded',
    jsonb_build_object('id', v_id, 'source', p_source_name, 'co_investor', p_co_investor_name));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION record_co_invest_entry(text, text, text, text, text, text, bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION record_co_invest_entry(text, text, text, text, text, text, bigint, text, text) TO authenticated;

-- ============================================================
-- RPC 6: update_co_invest_status — VOLATILE (write)
-- ============================================================
CREATE OR REPLACE FUNCTION update_co_invest_status(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE founder_investor_co_invest_entries
  SET status = p_status,
      committed_at = CASE WHEN p_status IN ('committed','wired') AND committed_at IS NULL THEN now() ELSE committed_at END,
      wired_at = CASE WHEN p_status = 'wired' AND wired_at IS NULL THEN now() ELSE wired_at END,
      updated_at = now()
  WHERE id = p_id;

  PERFORM log_founder_co_invest_action('co_invest_status_updated',
    jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION update_co_invest_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION update_co_invest_status(uuid, text) TO authenticated;

-- ============================================================
-- RPC 7: record_co_invest_thanks — VOLATILE (write)
-- ============================================================
CREATE OR REPLACE FUNCTION record_co_invest_thanks(
  p_source_name text,
  p_source_email text,
  p_channel text,
  p_message_excerpt text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO founder_investor_co_invest_thanks (
    source_investor_name, source_investor_email, channel, message_excerpt
  ) VALUES (
    p_source_name, p_source_email, COALESCE(p_channel, 'email'), p_message_excerpt
  ) RETURNING id INTO v_id;

  PERFORM log_founder_co_invest_action('co_invest_thanks_recorded',
    jsonb_build_object('id', v_id, 'source', p_source_name, 'channel', p_channel));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION record_co_invest_thanks(text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION record_co_invest_thanks(text, text, text, text) TO authenticated;

COMMIT;