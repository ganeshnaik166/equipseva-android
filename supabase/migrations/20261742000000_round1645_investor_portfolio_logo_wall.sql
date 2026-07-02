BEGIN;

-- Investor portfolio company logo wall (r1645)
-- Curate per-investor top portfolio company logos for fundraise pitch decks.

CREATE TABLE IF NOT EXISTS investor_portfolio_logos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_slug text NOT NULL,
  investor_display_name text NOT NULL,
  company_name text NOT NULL,
  company_sector text,
  logo_url text,
  marquee_rank int NOT NULL DEFAULT 99,
  is_active boolean NOT NULL DEFAULT true,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT investor_portfolio_logos_uniq UNIQUE (investor_slug, company_name)
);

CREATE INDEX IF NOT EXISTS investor_portfolio_logos_investor_idx
  ON investor_portfolio_logos (investor_slug, marquee_rank);
CREATE INDEX IF NOT EXISTS investor_portfolio_logos_active_idx
  ON investor_portfolio_logos (is_active);

ALTER TABLE investor_portfolio_logos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_investor_portfolio_logos ON investor_portfolio_logos;
CREATE POLICY founder_only_investor_portfolio_logos
  ON investor_portfolio_logos
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS investor_portfolio_logo_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  logo_id uuid REFERENCES investor_portfolio_logos(id) ON DELETE SET NULL,
  investor_slug text NOT NULL,
  event_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS investor_portfolio_logo_events_investor_idx
  ON investor_portfolio_logo_events (investor_slug, created_at DESC);
CREATE INDEX IF NOT EXISTS investor_portfolio_logo_events_type_idx
  ON investor_portfolio_logo_events (event_type, created_at DESC);

ALTER TABLE investor_portfolio_logo_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_investor_portfolio_logo_events ON investor_portfolio_logo_events;
CREATE POLICY founder_only_investor_portfolio_logo_events
  ON investor_portfolio_logo_events
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- helper: founder action log writer (table founder_action_log
-- already exists from r482; we only INSERT)
-- ============================================================
CREATE OR REPLACE FUNCTION log_founder_investor_logo_action(
  p_op text,
  p_after jsonb
) RETURNS void
LANGUAGE plpgsql
VOLATILE
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

REVOKE EXECUTE ON FUNCTION log_founder_investor_logo_action(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_investor_logo_action(text, jsonb) TO authenticated;

-- ============================================================
-- RPC 1: list curated logo wall per investor
-- ============================================================
CREATE OR REPLACE FUNCTION founder_investor_logo_wall(p_limit int DEFAULT 200)
RETURNS TABLE (
  investor_slug text,
  investor_display_name text,
  company_count int,
  active_count int,
  inactive_count int,
  top_companies text,
  last_updated timestamptz
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
  WITH ranked AS (
    SELECT
      l.investor_slug,
      l.investor_display_name,
      l.company_name,
      l.is_active,
      l.updated_at,
      l.marquee_rank,
      ROW_NUMBER() OVER (PARTITION BY l.investor_slug ORDER BY l.marquee_rank, l.company_name) AS rn
    FROM investor_portfolio_logos l
  )
  SELECT
    r.investor_slug,
    MAX(r.investor_display_name) AS investor_display_name,
    (COUNT(*))::int AS company_count,
    (COUNT(*) FILTER (WHERE r.is_active))::int AS active_count,
    (COUNT(*) FILTER (WHERE NOT r.is_active))::int AS inactive_count,
    string_agg(r.company_name, ', ' ORDER BY r.marquee_rank) FILTER (WHERE r.rn <= 5) AS top_companies,
    MAX(r.updated_at) AS last_updated
  FROM ranked r
  GROUP BY r.investor_slug
  ORDER BY company_count DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_logo_wall(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_logo_wall(int) TO authenticated;

-- ============================================================
-- RPC 2: detail rows for a given investor
-- ============================================================
CREATE OR REPLACE FUNCTION founder_investor_logo_detail(p_investor_slug text)
RETURNS TABLE (
  id uuid,
  company_name text,
  company_sector text,
  logo_url text,
  marquee_rank int,
  is_active boolean,
  note text,
  updated_at timestamptz
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
  SELECT
    l.id,
    l.company_name,
    l.company_sector,
    l.logo_url,
    l.marquee_rank,
    l.is_active,
    l.note,
    l.updated_at
  FROM investor_portfolio_logos l
  WHERE l.investor_slug = p_investor_slug
  ORDER BY l.marquee_rank, l.company_name;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_logo_detail(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_logo_detail(text) TO authenticated;

-- ============================================================
-- RPC 3: upsert a curated logo entry (VOLATILE write)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_investor_logo_upsert(
  p_investor_slug text,
  p_investor_display_name text,
  p_company_name text,
  p_company_sector text,
  p_logo_url text,
  p_marquee_rank int,
  p_is_active boolean,
  p_note text
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

  INSERT INTO investor_portfolio_logos (
    investor_slug, investor_display_name, company_name, company_sector,
    logo_url, marquee_rank, is_active, note, updated_at
  )
  VALUES (
    p_investor_slug, p_investor_display_name, p_company_name, p_company_sector,
    p_logo_url, COALESCE(p_marquee_rank, 99), COALESCE(p_is_active, true), p_note, now()
  )
  ON CONFLICT (investor_slug, company_name) DO UPDATE
  SET investor_display_name = EXCLUDED.investor_display_name,
      company_sector = EXCLUDED.company_sector,
      logo_url = EXCLUDED.logo_url,
      marquee_rank = EXCLUDED.marquee_rank,
      is_active = EXCLUDED.is_active,
      note = EXCLUDED.note,
      updated_at = now()
  RETURNING id INTO v_id;

  PERFORM log_founder_investor_logo_action(
    'investor_logo_upsert',
    jsonb_build_object(
      'id', v_id,
      'investor_slug', p_investor_slug,
      'company_name', p_company_name,
      'is_active', p_is_active
    )
  );

  INSERT INTO investor_portfolio_logo_events (logo_id, investor_slug, event_type, payload)
  VALUES (v_id, p_investor_slug, 'upsert',
    jsonb_build_object('company_name', p_company_name, 'rank', p_marquee_rank));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_logo_upsert(text, text, text, text, text, int, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_logo_upsert(text, text, text, text, text, int, boolean, text) TO authenticated;

-- ============================================================
-- RPC 4: toggle a logo on/off (VOLATILE write)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_investor_logo_toggle(
  p_id uuid,
  p_is_active boolean
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_slug text;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE investor_portfolio_logos
  SET is_active = p_is_active,
      updated_at = now()
  WHERE id = p_id
  RETURNING investor_slug INTO v_slug;

  IF v_slug IS NULL THEN
    RAISE EXCEPTION 'logo not found';
  END IF;

  PERFORM log_founder_investor_logo_action(
    'investor_logo_toggle',
    jsonb_build_object('id', p_id, 'is_active', p_is_active)
  );

  INSERT INTO investor_portfolio_logo_events (logo_id, investor_slug, event_type, payload)
  VALUES (p_id, v_slug, 'toggle', jsonb_build_object('is_active', p_is_active));
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_logo_toggle(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_logo_toggle(uuid, boolean) TO authenticated;

-- ============================================================
-- RPC 5: reorder marquee ranks for one investor (VOLATILE)
-- ============================================================
CREATE OR REPLACE FUNCTION founder_investor_logo_reorder(
  p_investor_slug text,
  p_ordered_ids uuid[]
)
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_idx int := 1;
  v_id uuid;
  v_count int := 0;
BEGIN
  IF NOT is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  FOREACH v_id IN ARRAY p_ordered_ids LOOP
    UPDATE investor_portfolio_logos
    SET marquee_rank = v_idx,
        updated_at = now()
    WHERE id = v_id AND investor_slug = p_investor_slug;
    v_idx := v_idx + 1;
    v_count := v_count + 1;
  END LOOP;

  PERFORM log_founder_investor_logo_action(
    'investor_logo_reorder',
    jsonb_build_object('investor_slug', p_investor_slug, 'count', v_count)
  );

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_logo_reorder(text, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_logo_reorder(text, uuid[]) TO authenticated;

-- ============================================================
-- RPC 6: stats across all investors
-- ============================================================
CREATE OR REPLACE FUNCTION founder_investor_logo_stats()
RETURNS TABLE (
  total_investors int,
  total_companies int,
  active_companies int,
  inactive_companies int,
  sectors_covered int,
  last_curated_at timestamptz
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
  SELECT
    (COUNT(DISTINCT l.investor_slug))::int AS total_investors,
    (COUNT(*))::int AS total_companies,
    (COUNT(*) FILTER (WHERE l.is_active))::int AS active_companies,
    (COUNT(*) FILTER (WHERE NOT l.is_active))::int AS inactive_companies,
    (COUNT(DISTINCT l.company_sector) FILTER (WHERE l.company_sector IS NOT NULL))::int AS sectors_covered,
    MAX(l.updated_at) AS last_curated_at
  FROM investor_portfolio_logos l;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_logo_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_logo_stats() TO authenticated;

-- ============================================================
-- RPC 7: recent curation events feed
-- ============================================================
CREATE OR REPLACE FUNCTION founder_investor_logo_recent_events(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  investor_slug text,
  event_type text,
  payload jsonb,
  created_at timestamptz
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
  SELECT
    e.id,
    e.investor_slug,
    e.event_type,
    e.payload,
    e.created_at
  FROM investor_portfolio_logo_events e
  ORDER BY e.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_investor_logo_recent_events(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_investor_logo_recent_events(int) TO authenticated;

COMMIT;