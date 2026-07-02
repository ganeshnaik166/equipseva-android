BEGIN;

-- ============================================================
-- r1610 — Founder Market Intel Feed
-- Aggregated biomedical equipment market news + founder action queue
-- ============================================================

-- Table 1: market intel items (news/events surfaced to founder)
CREATE TABLE IF NOT EXISTS founder_market_intel_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  headline text NOT NULL,
  body text,
  source_url text,
  source_name text,
  category text NOT NULL CHECK (category IN ('tariff','regulation','oem_move','competitor','supply_chain','macro','other')),
  priority text NOT NULL DEFAULT 'p2' CHECK (priority IN ('p0','p1','p2','p3')),
  relevance_tag text NOT NULL DEFAULT 'general' CHECK (relevance_tag IN ('imaging','dental','endoscopy','lab','icu','general','franchise','amc')),
  region text NOT NULL DEFAULT 'india',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','triaged','dismissed','escalated')),
  published_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmi_items_priority ON founder_market_intel_items(priority, status);
CREATE INDEX IF NOT EXISTS idx_fmi_items_published ON founder_market_intel_items(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_fmi_items_relevance ON founder_market_intel_items(relevance_tag, category);

ALTER TABLE founder_market_intel_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fmi_items_founder_only ON founder_market_intel_items;
CREATE POLICY fmi_items_founder_only ON founder_market_intel_items
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Table 2: founder action queue tied to intel items
CREATE TABLE IF NOT EXISTS founder_market_intel_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intel_id uuid NOT NULL REFERENCES founder_market_intel_items(id) ON DELETE CASCADE,
  action_title text NOT NULL,
  action_notes text,
  due_at timestamptz,
  priority text NOT NULL DEFAULT 'p2' CHECK (priority IN ('p0','p1','p2','p3')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done','cancelled')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fmi_actions_status ON founder_market_intel_actions(status, due_at);
CREATE INDEX IF NOT EXISTS idx_fmi_actions_intel ON founder_market_intel_actions(intel_id);

ALTER TABLE founder_market_intel_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fmi_actions_founder_only ON founder_market_intel_actions;
CREATE POLICY fmi_actions_founder_only ON founder_market_intel_actions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_market_intel_ingest(p_intel_id uuid, p_headline text, p_priority text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'market_intel_ingest',
          jsonb_build_object('intel_id', p_intel_id, 'headline', p_headline, 'priority', p_priority), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_market_intel_ingest(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_market_intel_ingest(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_market_intel_triage(p_intel_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'market_intel_triage',
          jsonb_build_object('intel_id', p_intel_id, 'status', p_status), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_market_intel_triage(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_market_intel_triage(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_market_intel_action_create(p_action_id uuid, p_intel_id uuid, p_title text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'market_intel_action_create',
          jsonb_build_object('action_id', p_action_id, 'intel_id', p_intel_id, 'title', p_title), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_market_intel_action_create(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_market_intel_action_create(uuid, uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_market_intel_action_complete(p_action_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'market_intel_action_complete',
          jsonb_build_object('action_id', p_action_id), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_market_intel_action_complete(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_market_intel_action_complete(uuid) TO authenticated;

-- ============================================================
-- READ RPCs (STABLE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_market_intel_kpis()
RETURNS TABLE(
  total_items bigint,
  open_items bigint,
  p0_open bigint,
  p1_open bigint,
  triaged_today bigint,
  dismissed_count bigint,
  escalated_count bigint,
  actions_pending bigint,
  actions_in_progress bigint,
  actions_done bigint,
  actions_overdue bigint,
  tariff_count bigint,
  regulation_count bigint,
  oem_move_count bigint,
  competitor_count bigint,
  last_7d_items bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH items AS (SELECT * FROM founder_market_intel_items),
       actions AS (SELECT * FROM founder_market_intel_actions)
  SELECT
    (SELECT count(*) FROM items),
    (SELECT count(*) FROM items WHERE status = 'open'),
    (SELECT count(*) FROM items WHERE status = 'open' AND priority = 'p0'),
    (SELECT count(*) FROM items WHERE status = 'open' AND priority = 'p1'),
    (SELECT count(*) FROM items WHERE status = 'triaged' AND created_at >= now() - interval '1 day'),
    (SELECT count(*) FROM items WHERE status = 'dismissed'),
    (SELECT count(*) FROM items WHERE status = 'escalated'),
    (SELECT count(*) FROM actions WHERE status = 'pending'),
    (SELECT count(*) FROM actions WHERE status = 'in_progress'),
    (SELECT count(*) FROM actions WHERE status = 'done'),
    (SELECT count(*) FROM actions WHERE status IN ('pending','in_progress') AND due_at IS NOT NULL AND due_at < now()),
    (SELECT count(*) FROM items WHERE category = 'tariff'),
    (SELECT count(*) FROM items WHERE category = 'regulation'),
    (SELECT count(*) FROM items WHERE category = 'oem_move'),
    (SELECT count(*) FROM items WHERE category = 'competitor'),
    (SELECT count(*) FROM items WHERE published_at >= now() - interval '7 days');
END $$;
REVOKE EXECUTE ON FUNCTION founder_market_intel_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_market_intel_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_market_intel_open_feed()
RETURNS TABLE(id uuid, headline text, category text, priority text, relevance_tag text, source_name text, published_at timestamptz, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.id, i.headline, i.category, i.priority, i.relevance_tag, i.source_name, i.published_at, i.status
  FROM founder_market_intel_items i
  WHERE i.status = 'open'
  ORDER BY CASE i.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
           i.published_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_market_intel_open_feed() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_market_intel_open_feed() TO authenticated;

CREATE OR REPLACE FUNCTION founder_market_intel_by_category()
RETURNS TABLE(category text, total bigint, open_count bigint, p0_p1_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.category, count(*)::bigint,
         count(*) FILTER (WHERE i.status = 'open')::bigint,
         count(*) FILTER (WHERE i.priority IN ('p0','p1'))::bigint
  FROM founder_market_intel_items i
  GROUP BY i.category
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_market_intel_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_market_intel_by_category() TO authenticated;

CREATE OR REPLACE FUNCTION founder_market_intel_by_relevance()
RETURNS TABLE(relevance_tag text, total bigint, open_count bigint, escalated bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT i.relevance_tag, count(*)::bigint,
         count(*) FILTER (WHERE i.status = 'open')::bigint,
         count(*) FILTER (WHERE i.status = 'escalated')::bigint
  FROM founder_market_intel_items i
  GROUP BY i.relevance_tag
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_market_intel_by_relevance() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_market_intel_by_relevance() TO authenticated;

CREATE OR REPLACE FUNCTION founder_market_intel_action_queue()
RETURNS TABLE(id uuid, intel_id uuid, action_title text, priority text, status text, due_at timestamptz, headline text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.intel_id, a.action_title, a.priority, a.status, a.due_at, i.headline
  FROM founder_market_intel_actions a
  JOIN founder_market_intel_items i ON i.id = a.intel_id
  WHERE a.status IN ('pending','in_progress')
  ORDER BY CASE a.priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
           COALESCE(a.due_at, now() + interval '30 days') ASC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_market_intel_action_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_market_intel_action_queue() TO authenticated;

-- ============================================================
-- WRITE RPCs (VOLATILE SECDEF, founder-gated)
-- ============================================================

CREATE OR REPLACE FUNCTION founder_market_intel_ingest(
  p_headline text, p_body text, p_source_url text, p_source_name text,
  p_category text, p_priority text, p_relevance_tag text, p_region text
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_market_intel_items(headline, body, source_url, source_name, category, priority, relevance_tag, region)
  VALUES (p_headline, p_body, p_source_url, p_source_name, p_category, COALESCE(p_priority, 'p2'), COALESCE(p_relevance_tag, 'general'), COALESCE(p_region, 'india'))
  RETURNING id INTO v_id;
  PERFORM log_founder_market_intel_ingest(v_id, p_headline, COALESCE(p_priority, 'p2'));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_market_intel_ingest(text, text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_market_intel_ingest(text, text, text, text, text, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_market_intel_triage(p_intel_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','triaged','dismissed','escalated') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE founder_market_intel_items SET status = p_status WHERE id = p_intel_id;
  PERFORM log_founder_market_intel_triage(p_intel_id, p_status);
END $$;
REVOKE EXECUTE ON FUNCTION founder_market_intel_triage(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_market_intel_triage(uuid, text) TO authenticated;

COMMIT;