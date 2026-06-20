BEGIN;

-- =====================================================================
-- r1496 — Founder Culture Deck Versioning
-- Log culture deck versions + acknowledgement signatures from team;
-- track who hasn't signed; new-hire onboarding ladder.
-- =====================================================================

CREATE TABLE IF NOT EXISTS founder_culture_deck_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_label text NOT NULL UNIQUE,
  title text NOT NULL,
  summary text,
  doc_url text,
  word_count integer DEFAULT 0,
  is_active boolean NOT NULL DEFAULT false,
  requires_signature boolean NOT NULL DEFAULT true,
  published_at timestamptz NOT NULL DEFAULT now(),
  retired_at timestamptz,
  published_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcdv_active ON founder_culture_deck_versions(is_active);
CREATE INDEX IF NOT EXISTS idx_fcdv_published ON founder_culture_deck_versions(published_at DESC);

ALTER TABLE founder_culture_deck_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcdv_founder_only ON founder_culture_deck_versions;
CREATE POLICY fcdv_founder_only ON founder_culture_deck_versions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


CREATE TABLE IF NOT EXISTS founder_culture_deck_signatures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id uuid NOT NULL REFERENCES founder_culture_deck_versions(id) ON DELETE CASCADE,
  signer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  signer_email text,
  signer_role text,
  signed_at timestamptz NOT NULL DEFAULT now(),
  is_new_hire boolean NOT NULL DEFAULT false,
  onboarding_step integer DEFAULT 0,
  notes text,
  UNIQUE (version_id, signer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_fcds_version ON founder_culture_deck_signatures(version_id);
CREATE INDEX IF NOT EXISTS idx_fcds_signer ON founder_culture_deck_signatures(signer_user_id);
CREATE INDEX IF NOT EXISTS idx_fcds_signed_at ON founder_culture_deck_signatures(signed_at DESC);

ALTER TABLE founder_culture_deck_signatures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcds_founder_only ON founder_culture_deck_signatures;
CREATE POLICY fcds_founder_only ON founder_culture_deck_signatures
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());


-- =====================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION log_founder_culture_deck_published(p_version text, p_title text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'culture_deck_published',
          jsonb_build_object('version', p_version, 'title', p_title, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_culture_deck_published(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_culture_deck_published(text, text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_culture_deck_retired(p_version text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'culture_deck_retired',
          jsonb_build_object('version', p_version, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_culture_deck_retired(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_culture_deck_retired(text) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_culture_deck_signed(p_version_id uuid, p_signer uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'culture_deck_signed',
          jsonb_build_object('version_id', p_version_id, 'signer', p_signer, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_culture_deck_signed(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_culture_deck_signed(uuid, uuid) TO authenticated;


CREATE OR REPLACE FUNCTION log_founder_culture_deck_nudge(p_version_id uuid, p_count integer)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'culture_deck_nudge',
          jsonb_build_object('version_id', p_version_id, 'pending_count', p_count, 'at', now()));
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_culture_deck_nudge(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_culture_deck_nudge(uuid, integer) TO authenticated;


-- =====================================================================
-- READ RPCs (STABLE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION founder_culture_deck_versions_list()
RETURNS TABLE (
  id uuid,
  version_label text,
  title text,
  is_active boolean,
  requires_signature boolean,
  word_count integer,
  published_at timestamptz,
  retired_at timestamptz,
  days_since_publish numeric,
  signature_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.version_label, v.title, v.is_active, v.requires_signature,
         v.word_count, v.published_at, v.retired_at,
         ROUND((EXTRACT(EPOCH FROM (now() - v.published_at))/86400.0)::numeric, 1) AS days_since_publish,
         (SELECT COUNT(*) FROM founder_culture_deck_signatures s WHERE s.version_id = v.id) AS signature_count
  FROM founder_culture_deck_versions v
  ORDER BY v.published_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_culture_deck_versions_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_culture_deck_versions_list() TO authenticated;


CREATE OR REPLACE FUNCTION founder_culture_deck_recent_signatures()
RETURNS TABLE (
  id uuid,
  version_label text,
  signer_email text,
  signer_role text,
  is_new_hire boolean,
  onboarding_step integer,
  signed_at timestamptz,
  hours_since numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, v.version_label, s.signer_email, s.signer_role,
         s.is_new_hire, s.onboarding_step, s.signed_at,
         ROUND((EXTRACT(EPOCH FROM (now() - s.signed_at))/3600.0)::numeric, 1) AS hours_since
  FROM founder_culture_deck_signatures s
  JOIN founder_culture_deck_versions v ON v.id = s.version_id
  ORDER BY s.signed_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_culture_deck_recent_signatures() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_culture_deck_recent_signatures() TO authenticated;


CREATE OR REPLACE FUNCTION founder_culture_deck_unsigned_team()
RETURNS TABLE (
  user_id uuid,
  email text,
  full_name text,
  active_version text,
  days_overdue numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_active_id uuid;
  v_active_label text;
  v_published_at timestamptz;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT id, version_label, published_at INTO v_active_id, v_active_label, v_published_at
  FROM founder_culture_deck_versions WHERE is_active = true ORDER BY published_at DESC LIMIT 1;

  IF v_active_id IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT p.id AS user_id,
         p.email,
         p.full_name,
         v_active_label AS active_version,
         ROUND((EXTRACT(EPOCH FROM (now() - v_published_at))/86400.0)::numeric, 1) AS days_overdue
  FROM profiles p
  WHERE p.role IN ('founder','admin','engineer','dispatcher')
    AND NOT EXISTS (
      SELECT 1 FROM founder_culture_deck_signatures s
      WHERE s.version_id = v_active_id AND s.signer_user_id = p.id
    )
  ORDER BY p.created_at ASC NULLS LAST
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_culture_deck_unsigned_team() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_culture_deck_unsigned_team() TO authenticated;


CREATE OR REPLACE FUNCTION founder_culture_deck_new_hire_ladder()
RETURNS TABLE (
  signer_email text,
  signer_role text,
  onboarding_step integer,
  version_label text,
  signed_at timestamptz,
  days_since_signing numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.signer_email, s.signer_role, s.onboarding_step, v.version_label, s.signed_at,
         ROUND((EXTRACT(EPOCH FROM (now() - s.signed_at))/86400.0)::numeric, 1) AS days_since_signing
  FROM founder_culture_deck_signatures s
  JOIN founder_culture_deck_versions v ON v.id = s.version_id
  WHERE s.is_new_hire = true
  ORDER BY s.signed_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_culture_deck_new_hire_ladder() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_culture_deck_new_hire_ladder() TO authenticated;


CREATE OR REPLACE FUNCTION founder_culture_deck_signatures_by_role()
RETURNS TABLE (
  signer_role text,
  total_signatures bigint,
  new_hire_signatures bigint,
  avg_onboarding_step numeric,
  latest_signed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(s.signer_role,'unspecified') AS signer_role,
         COUNT(*) AS total_signatures,
         COUNT(*) FILTER (WHERE s.is_new_hire) AS new_hire_signatures,
         ROUND(AVG(s.onboarding_step)::numeric, 2) AS avg_onboarding_step,
         MAX(s.signed_at) AS latest_signed_at
  FROM founder_culture_deck_signatures s
  GROUP BY COALESCE(s.signer_role,'unspecified')
  ORDER BY total_signatures DESC
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION founder_culture_deck_signatures_by_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_culture_deck_signatures_by_role() TO authenticated;


CREATE OR REPLACE FUNCTION founder_culture_deck_summary()
RETURNS TABLE (
  total_versions bigint,
  active_versions bigint,
  retired_versions bigint,
  total_signatures bigint,
  signatures_last_30d bigint,
  new_hire_signatures bigint,
  unsigned_team_count bigint,
  avg_word_count numeric,
  latest_publish_at timestamptz,
  latest_sign_at timestamptz,
  days_since_publish numeric,
  hours_since_sign numeric,
  active_version_label text,
  pct_team_signed numeric,
  total_team_members bigint,
  onboarding_ladder_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_active_id uuid;
  v_active_label text;
  v_team_total bigint;
  v_signed bigint;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT id, version_label INTO v_active_id, v_active_label
  FROM founder_culture_deck_versions WHERE is_active = true ORDER BY published_at DESC LIMIT 1;

  SELECT COUNT(*) INTO v_team_total FROM profiles WHERE role IN ('founder','admin','engineer','dispatcher');

  IF v_active_id IS NULL THEN v_signed := 0; ELSE
    SELECT COUNT(*) INTO v_signed FROM founder_culture_deck_signatures WHERE version_id = v_active_id;
  END IF;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM founder_culture_deck_versions),
    (SELECT COUNT(*) FROM founder_culture_deck_versions WHERE is_active),
    (SELECT COUNT(*) FROM founder_culture_deck_versions WHERE retired_at IS NOT NULL),
    (SELECT COUNT(*) FROM founder_culture_deck_signatures),
    (SELECT COUNT(*) FROM founder_culture_deck_signatures WHERE signed_at > now() - interval '30 days'),
    (SELECT COUNT(*) FROM founder_culture_deck_signatures WHERE is_new_hire),
    GREATEST(v_team_total - v_signed, 0),
    (SELECT ROUND(AVG(word_count)::numeric, 0) FROM founder_culture_deck_versions),
    (SELECT MAX(published_at) FROM founder_culture_deck_versions),
    (SELECT MAX(signed_at) FROM founder_culture_deck_signatures),
    (SELECT ROUND((EXTRACT(EPOCH FROM (now() - MAX(published_at)))/86400.0)::numeric, 1) FROM founder_culture_deck_versions),
    (SELECT ROUND((EXTRACT(EPOCH FROM (now() - MAX(signed_at)))/3600.0)::numeric, 1) FROM founder_culture_deck_signatures),
    v_active_label,
    CASE WHEN v_team_total > 0 THEN ROUND((v_signed::numeric / v_team_total::numeric) * 100, 1) ELSE 0 END,
    v_team_total,
    (SELECT COUNT(DISTINCT signer_user_id) FROM founder_culture_deck_signatures WHERE is_new_hire);
END $$;
REVOKE EXECUTE ON FUNCTION founder_culture_deck_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_culture_deck_summary() TO authenticated;


CREATE OR REPLACE FUNCTION founder_culture_deck_version_timeline()
RETURNS TABLE (
  publish_week date,
  versions_published bigint,
  total_signatures bigint,
  new_hire_signatures bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', v.published_at)::date AS publish_week,
         COUNT(DISTINCT v.id) AS versions_published,
         (SELECT COUNT(*) FROM founder_culture_deck_signatures s
            WHERE date_trunc('week', s.signed_at) = date_trunc('week', v.published_at)) AS total_signatures,
         (SELECT COUNT(*) FROM founder_culture_deck_signatures s
            WHERE date_trunc('week', s.signed_at) = date_trunc('week', v.published_at)
              AND s.is_new_hire) AS new_hire_signatures
  FROM founder_culture_deck_versions v
  WHERE v.published_at > now() - interval '180 days'
  GROUP BY date_trunc('week', v.published_at)
  ORDER BY publish_week DESC
  LIMIT 26;
END $$;
REVOKE EXECUTE ON FUNCTION founder_culture_deck_version_timeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_culture_deck_version_timeline() TO authenticated;

COMMIT;