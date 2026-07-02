BEGIN;

-- Pitch deck version registry
CREATE TABLE IF NOT EXISTS founder_pitch_deck_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_label text NOT NULL,
  semver text,
  audience text NOT NULL CHECK (audience IN ('investors','customers','press','internal','partners')),
  stage text NOT NULL DEFAULT 'draft' CHECK (stage IN ('draft','review','approved','archived')),
  deck_url text,
  slide_count int,
  raise_target_rupees bigint,
  change_log text,
  thesis_summary text,
  is_canonical boolean NOT NULL DEFAULT false,
  created_by_user_id uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  archived_at timestamptz
);

CREATE TABLE IF NOT EXISTS founder_pitch_deck_shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id uuid NOT NULL REFERENCES founder_pitch_deck_versions(id) ON DELETE CASCADE,
  recipient_name text NOT NULL,
  recipient_org text,
  recipient_email text,
  channel text NOT NULL CHECK (channel IN ('email','link','in_person','call','event')),
  shared_at timestamptz NOT NULL DEFAULT now(),
  opened_at timestamptz,
  feedback text,
  outcome text CHECK (outcome IN ('no_response','interested','passed','term_sheet','wired','followup')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE founder_pitch_deck_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_pitch_deck_shares   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_pdv ON founder_pitch_deck_versions;
CREATE POLICY founder_only_pdv ON founder_pitch_deck_versions FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_pds ON founder_pitch_deck_shares;
CREATE POLICY founder_only_pds ON founder_pitch_deck_shares FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_pdv_audience  ON founder_pitch_deck_versions(audience, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pdv_canonical ON founder_pitch_deck_versions(is_canonical) WHERE is_canonical;
CREATE INDEX IF NOT EXISTS idx_pds_version   ON founder_pitch_deck_shares(version_id, shared_at DESC);
CREATE INDEX IF NOT EXISTS idx_pds_outcome   ON founder_pitch_deck_shares(outcome);

-- ============ LOG HELPERS (VOLATILE SECDEF) ============
CREATE OR REPLACE FUNCTION log_founder_pitch_version_created(p_version_id uuid, p_label text, p_audience text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pitch_version_created',
          jsonb_build_object('version_id', p_version_id, 'label', p_label, 'audience', p_audience));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_pitch_version_created(uuid,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pitch_version_created(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pitch_canonical_set(p_version_id uuid, p_label text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pitch_canonical_set',
          jsonb_build_object('version_id', p_version_id, 'label', p_label));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_pitch_canonical_set(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pitch_canonical_set(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pitch_share_recorded(p_share_id uuid, p_version_id uuid, p_recipient text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pitch_share_recorded',
          jsonb_build_object('share_id', p_share_id, 'version_id', p_version_id, 'recipient', p_recipient));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_pitch_share_recorded(uuid,uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pitch_share_recorded(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_pitch_archived(p_version_id uuid, p_label text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pitch_archived',
          jsonb_build_object('version_id', p_version_id, 'label', p_label));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_pitch_archived(uuid,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION log_founder_pitch_archived(uuid,text) TO authenticated;

-- ============ READ RPCs (STABLE) ============
CREATE OR REPLACE FUNCTION rpc_founder_pitch_versions_list()
RETURNS TABLE(id uuid, version_label text, semver text, audience text, stage text, slide_count int, is_canonical boolean, deck_url text, change_log text, raise_target_rupees bigint, created_at timestamptz, approved_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.version_label, v.semver, v.audience, v.stage, v.slide_count, v.is_canonical,
           v.deck_url, v.change_log, v.raise_target_rupees, v.created_at, v.approved_at
    FROM founder_pitch_deck_versions v
    ORDER BY v.is_canonical DESC, v.created_at DESC
    LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_versions_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_pitch_versions_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_kpis()
RETURNS TABLE(
  total_versions int, canonical_versions int, draft_versions int, approved_versions int, archived_versions int,
  investor_versions int, customer_versions int, press_versions int, partner_versions int, internal_versions int,
  total_shares int, shares_opened int, shares_interested int, shares_passed int, shares_termsheet int, shares_wired int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH v AS (
    SELECT
      count(*)::int AS total_versions,
      count(*) FILTER (WHERE is_canonical)::int AS canonical_versions,
      count(*) FILTER (WHERE stage='draft')::int AS draft_versions,
      count(*) FILTER (WHERE stage='approved')::int AS approved_versions,
      count(*) FILTER (WHERE stage='archived')::int AS archived_versions,
      count(*) FILTER (WHERE audience='investors')::int AS investor_versions,
      count(*) FILTER (WHERE audience='customers')::int AS customer_versions,
      count(*) FILTER (WHERE audience='press')::int AS press_versions,
      count(*) FILTER (WHERE audience='partners')::int AS partner_versions,
      count(*) FILTER (WHERE audience='internal')::int AS internal_versions
    FROM founder_pitch_deck_versions
  ),
  s AS (
    SELECT
      count(*)::int AS total_shares,
      count(*) FILTER (WHERE opened_at IS NOT NULL)::int AS shares_opened,
      count(*) FILTER (WHERE outcome='interested')::int AS shares_interested,
      count(*) FILTER (WHERE outcome='passed')::int AS shares_passed,
      count(*) FILTER (WHERE outcome='term_sheet')::int AS shares_termsheet,
      count(*) FILTER (WHERE outcome='wired')::int AS shares_wired
    FROM founder_pitch_deck_shares
  )
  SELECT v.total_versions, v.canonical_versions, v.draft_versions, v.approved_versions, v.archived_versions,
         v.investor_versions, v.customer_versions, v.press_versions, v.partner_versions, v.internal_versions,
         s.total_shares, s.shares_opened, s.shares_interested, s.shares_passed, s.shares_termsheet, s.shares_wired
  FROM v LEFT JOIN s ON true;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_pitch_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_canonical_by_audience()
RETURNS TABLE(audience text, version_label text, semver text, slide_count int, created_at timestamptz, approved_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.audience, v.version_label, v.semver, v.slide_count, v.created_at, v.approved_at
    FROM founder_pitch_deck_versions v
    WHERE v.is_canonical = true
    ORDER BY v.audience, v.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_canonical_by_audience() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_pitch_canonical_by_audience() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_recent_shares()
RETURNS TABLE(id uuid, version_label text, audience text, recipient_name text, recipient_org text, channel text, shared_at timestamptz, opened_at timestamptz, outcome text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, v.version_label, v.audience, s.recipient_name, s.recipient_org, s.channel, s.shared_at, s.opened_at, s.outcome
    FROM founder_pitch_deck_shares s
    JOIN founder_pitch_deck_versions v ON v.id = s.version_id
    ORDER BY s.shared_at DESC
    LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_recent_shares() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_pitch_recent_shares() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_version_change_log(p_limit int DEFAULT 20)
RETURNS TABLE(id uuid, version_label text, audience text, change_log text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.version_label, v.audience, v.change_log, v.created_at
    FROM founder_pitch_deck_versions v
    WHERE v.change_log IS NOT NULL AND length(v.change_log) > 0
    ORDER BY v.created_at DESC
    LIMIT p_limit;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_version_change_log(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_pitch_version_change_log(int) TO authenticated;

-- ============ WRITE RPCs (VOLATILE) ============
CREATE OR REPLACE FUNCTION rpc_founder_pitch_version_create(
  p_label text, p_semver text, p_audience text, p_deck_url text, p_slide_count int,
  p_raise_target_rupees bigint, p_change_log text, p_thesis_summary text
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_pitch_deck_versions(version_label, semver, audience, deck_url, slide_count, raise_target_rupees, change_log, thesis_summary, created_by_user_id)
  VALUES (p_label, p_semver, p_audience, p_deck_url, p_slide_count, p_raise_target_rupees, p_change_log, p_thesis_summary, auth.uid())
  RETURNING id INTO v_id;
  PERFORM log_founder_pitch_version_created(v_id, p_label, p_audience);
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_version_create(text,text,text,text,int,bigint,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_pitch_version_create(text,text,text,text,int,bigint,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_version_set_canonical(p_version_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_audience text; v_label text;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT audience, version_label INTO v_audience, v_label
    FROM founder_pitch_deck_versions WHERE id = p_version_id;
  IF v_audience IS NULL THEN RAISE EXCEPTION 'version_not_found'; END IF;
  UPDATE founder_pitch_deck_versions SET is_canonical = false WHERE audience = v_audience AND is_canonical = true;
  UPDATE founder_pitch_deck_versions SET is_canonical = true, stage = 'approved', approved_at = COALESCE(approved_at, now())
    WHERE id = p_version_id;
  PERFORM log_founder_pitch_canonical_set(p_version_id, v_label);
END $$;
REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_version_set_canonical(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION rpc_founder_pitch_version_set_canonical(uuid) TO authenticated;

COMMIT;