BEGIN;

-- ============================================================================
-- Round 1561 — Founder Press Kit Assets
-- Central press-kit asset library + per-recipient download tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_press_kit_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_slug text UNIQUE NOT NULL,
  asset_title text NOT NULL,
  asset_category text NOT NULL CHECK (asset_category IN ('bio','logo','screenshot','fact_sheet','announcement','other')),
  description text,
  storage_path text NOT NULL,
  mime_type text,
  byte_size bigint,
  is_embargoed boolean NOT NULL DEFAULT false,
  embargo_until timestamptz,
  is_published boolean NOT NULL DEFAULT true,
  version int NOT NULL DEFAULT 1,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpka_category ON founder_press_kit_assets(asset_category);
CREATE INDEX IF NOT EXISTS idx_fpka_published ON founder_press_kit_assets(is_published);
CREATE INDEX IF NOT EXISTS idx_fpka_embargo ON founder_press_kit_assets(is_embargoed, embargo_until);

ALTER TABLE founder_press_kit_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fpka_founder_only ON founder_press_kit_assets;
CREATE POLICY fpka_founder_only ON founder_press_kit_assets
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_press_kit_downloads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id uuid NOT NULL REFERENCES founder_press_kit_assets(id) ON DELETE CASCADE,
  recipient_name text NOT NULL,
  recipient_email text,
  recipient_org text,
  recipient_role text,
  download_source text NOT NULL DEFAULT 'direct' CHECK (download_source IN ('direct','share_link','email','press_portal','other')),
  share_token text,
  ip_address text,
  user_agent text,
  downloaded_at timestamptz NOT NULL DEFAULT now(),
  notes text
);

CREATE INDEX IF NOT EXISTS idx_fpkd_asset ON founder_press_kit_downloads(asset_id);
CREATE INDEX IF NOT EXISTS idx_fpkd_when ON founder_press_kit_downloads(downloaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_fpkd_email ON founder_press_kit_downloads(recipient_email);

ALTER TABLE founder_press_kit_downloads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fpkd_founder_only ON founder_press_kit_downloads;
CREATE POLICY fpkd_founder_only ON founder_press_kit_downloads
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_press_kit_overview()
RETURNS TABLE(
  total_assets bigint,
  published_assets bigint,
  embargoed_assets bigint,
  bios_count bigint,
  logos_count bigint,
  screenshots_count bigint,
  fact_sheets_count bigint,
  announcements_count bigint,
  total_downloads bigint,
  downloads_7d bigint,
  downloads_30d bigint,
  unique_recipients bigint,
  unique_orgs bigint,
  share_link_downloads bigint,
  email_downloads bigint,
  avg_downloads_per_asset numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_press_kit_assets),
    (SELECT count(*) FROM founder_press_kit_assets WHERE is_published),
    (SELECT count(*) FROM founder_press_kit_assets WHERE is_embargoed AND (embargo_until IS NULL OR embargo_until > now())),
    (SELECT count(*) FROM founder_press_kit_assets WHERE asset_category = 'bio'),
    (SELECT count(*) FROM founder_press_kit_assets WHERE asset_category = 'logo'),
    (SELECT count(*) FROM founder_press_kit_assets WHERE asset_category = 'screenshot'),
    (SELECT count(*) FROM founder_press_kit_assets WHERE asset_category = 'fact_sheet'),
    (SELECT count(*) FROM founder_press_kit_assets WHERE asset_category = 'announcement'),
    (SELECT count(*) FROM founder_press_kit_downloads),
    (SELECT count(*) FROM founder_press_kit_downloads WHERE downloaded_at >= now() - interval '7 days'),
    (SELECT count(*) FROM founder_press_kit_downloads WHERE downloaded_at >= now() - interval '30 days'),
    (SELECT count(DISTINCT recipient_email) FROM founder_press_kit_downloads WHERE recipient_email IS NOT NULL),
    (SELECT count(DISTINCT recipient_org) FROM founder_press_kit_downloads WHERE recipient_org IS NOT NULL),
    (SELECT count(*) FROM founder_press_kit_downloads WHERE download_source = 'share_link'),
    (SELECT count(*) FROM founder_press_kit_downloads WHERE download_source = 'email'),
    COALESCE((SELECT round(count(d.*)::numeric / NULLIF(count(DISTINCT a.id),0), 2)
              FROM founder_press_kit_assets a
              LEFT JOIN founder_press_kit_downloads d ON d.asset_id = a.id), 0);
END $$;

CREATE OR REPLACE FUNCTION founder_press_kit_list_assets()
RETURNS TABLE(
  id uuid,
  asset_slug text,
  asset_title text,
  asset_category text,
  is_embargoed boolean,
  embargo_until timestamptz,
  is_published boolean,
  byte_size bigint,
  download_count bigint,
  last_downloaded_at timestamptz,
  created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id, a.asset_slug, a.asset_title, a.asset_category,
    a.is_embargoed, a.embargo_until, a.is_published, a.byte_size,
    (SELECT count(*) FROM founder_press_kit_downloads d WHERE d.asset_id = a.id),
    (SELECT max(d.downloaded_at) FROM founder_press_kit_downloads d WHERE d.asset_id = a.id),
    a.created_at
  FROM founder_press_kit_assets a
  ORDER BY a.created_at DESC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION founder_press_kit_recent_downloads()
RETURNS TABLE(
  id uuid,
  asset_title text,
  asset_category text,
  recipient_name text,
  recipient_email text,
  recipient_org text,
  download_source text,
  downloaded_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id, a.asset_title, a.asset_category,
    d.recipient_name, d.recipient_email, d.recipient_org,
    d.download_source, d.downloaded_at
  FROM founder_press_kit_downloads d
  JOIN founder_press_kit_assets a ON a.id = d.asset_id
  ORDER BY d.downloaded_at DESC
  LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION founder_press_kit_top_recipients()
RETURNS TABLE(
  recipient_name text,
  recipient_email text,
  recipient_org text,
  download_count bigint,
  distinct_assets bigint,
  last_downloaded_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.recipient_name, d.recipient_email, d.recipient_org,
    count(*) AS download_count,
    count(DISTINCT d.asset_id) AS distinct_assets,
    max(d.downloaded_at) AS last_downloaded_at
  FROM founder_press_kit_downloads d
  GROUP BY d.recipient_name, d.recipient_email, d.recipient_org
  ORDER BY count(*) DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION founder_press_kit_embargo_watch()
RETURNS TABLE(
  id uuid,
  asset_title text,
  asset_category text,
  embargo_until timestamptz,
  hours_until_lift numeric,
  is_published boolean
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.id, a.asset_title, a.asset_category, a.embargo_until,
    round(EXTRACT(EPOCH FROM (a.embargo_until - now()))::numeric / 3600.0, 1) AS hours_until_lift,
    a.is_published
  FROM founder_press_kit_assets a
  WHERE a.is_embargoed AND a.embargo_until IS NOT NULL AND a.embargo_until > now()
  ORDER BY a.embargo_until ASC
  LIMIT 50;
END $$;

-- ============================================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_press_kit_upsert_asset(
  p_slug text,
  p_title text,
  p_category text,
  p_storage_path text,
  p_description text DEFAULT NULL,
  p_mime_type text DEFAULT NULL,
  p_byte_size bigint DEFAULT NULL,
  p_is_embargoed boolean DEFAULT false,
  p_embargo_until timestamptz DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_press_kit_assets(asset_slug, asset_title, asset_category, storage_path, description, mime_type, byte_size, is_embargoed, embargo_until, created_by)
  VALUES (p_slug, p_title, p_category, p_storage_path, p_description, p_mime_type, p_byte_size, p_is_embargoed, p_embargo_until, auth.uid())
  ON CONFLICT (asset_slug) DO UPDATE
    SET asset_title = EXCLUDED.asset_title,
        asset_category = EXCLUDED.asset_category,
        storage_path = EXCLUDED.storage_path,
        description = EXCLUDED.description,
        mime_type = EXCLUDED.mime_type,
        byte_size = EXCLUDED.byte_size,
        is_embargoed = EXCLUDED.is_embargoed,
        embargo_until = EXCLUDED.embargo_until,
        version = founder_press_kit_assets.version + 1,
        updated_at = now()
  RETURNING id INTO v_id;
  PERFORM log_founder_press_kit_asset_upsert(v_id, p_slug, p_category);
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION founder_press_kit_record_download(
  p_asset_id uuid,
  p_recipient_name text,
  p_recipient_email text DEFAULT NULL,
  p_recipient_org text DEFAULT NULL,
  p_recipient_role text DEFAULT NULL,
  p_source text DEFAULT 'direct',
  p_share_token text DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_press_kit_downloads(asset_id, recipient_name, recipient_email, recipient_org, recipient_role, download_source, share_token, notes)
  VALUES (p_asset_id, p_recipient_name, p_recipient_email, p_recipient_org, p_recipient_role, p_source, p_share_token, p_notes)
  RETURNING id INTO v_id;
  PERFORM log_founder_press_kit_download(v_id, p_asset_id, p_recipient_email);
  RETURN v_id;
END $$;

-- ============================================================================
-- LOG HELPERS (VOLATILE, founder-gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_press_kit_asset_upsert(p_asset_id uuid, p_slug text, p_category text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'press_kit_asset_upsert',
          jsonb_build_object('asset_id', p_asset_id, 'slug', p_slug, 'category', p_category));
END $$;

CREATE OR REPLACE FUNCTION log_founder_press_kit_download(p_download_id uuid, p_asset_id uuid, p_recipient_email text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'press_kit_download_recorded',
          jsonb_build_object('download_id', p_download_id, 'asset_id', p_asset_id, 'recipient_email', p_recipient_email));
END $$;

CREATE OR REPLACE FUNCTION log_founder_press_kit_embargo_lift(p_asset_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'press_kit_embargo_lift',
          jsonb_build_object('asset_id', p_asset_id));
END $$;

CREATE OR REPLACE FUNCTION log_founder_press_kit_view(p_section text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'press_kit_view',
          jsonb_build_object('section', p_section, 'viewed_at', now()));
END $$;

-- ============================================================================
-- GRANTS
-- ============================================================================

REVOKE EXECUTE ON FUNCTION founder_press_kit_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_press_kit_list_assets() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_press_kit_recent_downloads() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_press_kit_top_recipients() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_press_kit_embargo_watch() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_press_kit_upsert_asset(text, text, text, text, text, text, bigint, boolean, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION founder_press_kit_record_download(uuid, text, text, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_press_kit_asset_upsert(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_press_kit_download(uuid, uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_press_kit_embargo_lift(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION log_founder_press_kit_view(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION founder_press_kit_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_press_kit_list_assets() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_press_kit_recent_downloads() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_press_kit_top_recipients() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_press_kit_embargo_watch() TO authenticated;
GRANT EXECUTE ON FUNCTION founder_press_kit_upsert_asset(text, text, text, text, text, text, bigint, boolean, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION founder_press_kit_record_download(uuid, text, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_press_kit_asset_upsert(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_press_kit_download(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_press_kit_embargo_lift(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION log_founder_press_kit_view(text) TO authenticated;

COMMIT;