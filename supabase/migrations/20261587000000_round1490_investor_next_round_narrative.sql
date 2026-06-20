BEGIN;

-- ============================================================================
-- r1490 — Investor Next-Round Narrative Tracker
-- ============================================================================
-- Capture key milestones + metrics + storyline for the next fundraise pitch.
-- Tracks readiness across 12 narrative beats (problem, market, team, traction, etc).
-- Includes founder critique log for self-review of each beat.
-- ============================================================================

CREATE TABLE IF NOT EXISTS investor_next_round_narrative_beats (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beat_slug text NOT NULL UNIQUE,
  beat_order int NOT NULL,
  beat_title text NOT NULL,
  beat_category text NOT NULL CHECK (beat_category IN ('story','market','traction','team','financials','ask')),
  storyline_draft text,
  proof_metric_label text,
  proof_metric_value_rupees bigint,
  proof_metric_value_count bigint,
  readiness_status text NOT NULL DEFAULT 'draft' CHECK (readiness_status IN ('draft','in_review','ready','blocked')),
  readiness_score int NOT NULL DEFAULT 0 CHECK (readiness_score BETWEEN 0 AND 100),
  owner_label text,
  last_edited_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE investor_next_round_narrative_beats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS narrative_beats_founder_only ON investor_next_round_narrative_beats;
CREATE POLICY narrative_beats_founder_only
  ON investor_next_round_narrative_beats
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS investor_next_round_narrative_critique (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beat_id uuid NOT NULL REFERENCES investor_next_round_narrative_beats(id) ON DELETE CASCADE,
  critique_text text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('nit','medium','blocker')),
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE investor_next_round_narrative_critique ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS narrative_critique_founder_only ON investor_next_round_narrative_critique;
CREATE POLICY narrative_critique_founder_only
  ON investor_next_round_narrative_critique
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE INDEX IF NOT EXISTS idx_narrative_critique_beat ON investor_next_round_narrative_critique(beat_id);
CREATE INDEX IF NOT EXISTS idx_narrative_beats_order ON investor_next_round_narrative_beats(beat_order);

-- Seed 12 narrative beats (idempotent — only insert if empty)
INSERT INTO investor_next_round_narrative_beats (beat_slug, beat_order, beat_title, beat_category, readiness_status, readiness_score)
SELECT * FROM (VALUES
  ('problem',          1,  'The Problem',              'story',      'draft', 60),
  ('market_size',      2,  'Market Size (TAM/SAM/SOM)','market',     'draft', 40),
  ('why_now',          3,  'Why Now',                  'story',      'draft', 50),
  ('solution',         4,  'Our Solution',             'story',      'draft', 70),
  ('product_demo',     5,  'Product Demo',             'story',      'draft', 65),
  ('traction',         6,  'Traction & Metrics',       'traction',   'draft', 55),
  ('unit_economics',   7,  'Unit Economics',           'financials', 'draft', 45),
  ('team',             8,  'Team',                     'team',       'draft', 75),
  ('moat',             9,  'Moat & Defensibility',     'story',      'draft', 35),
  ('roadmap',          10, 'Roadmap',                  'story',      'draft', 50),
  ('financials',       11, 'Financials & Projections', 'financials', 'draft', 30),
  ('the_ask',          12, 'The Ask',                  'ask',        'draft', 25)
) AS seed(beat_slug, beat_order, beat_title, beat_category, readiness_status, readiness_score)
WHERE NOT EXISTS (SELECT 1 FROM investor_next_round_narrative_beats);

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION rpc_investor_narrative_beats_list()
RETURNS TABLE (
  id uuid,
  beat_order int,
  beat_title text,
  beat_category text,
  readiness_status text,
  readiness_score int,
  owner_label text,
  storyline_chars int,
  proof_metric_label text,
  last_edited_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.beat_order, b.beat_title, b.beat_category,
         b.readiness_status, b.readiness_score, b.owner_label,
         COALESCE(length(b.storyline_draft), 0) AS storyline_chars,
         b.proof_metric_label, b.last_edited_at
  FROM investor_next_round_narrative_beats b
  ORDER BY b.beat_order;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_narrative_beats_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_narrative_beats_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_investor_narrative_critique_list()
RETURNS TABLE (
  id uuid,
  beat_id uuid,
  beat_title text,
  critique_text text,
  severity text,
  resolved_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.beat_id, b.beat_title, c.critique_text, c.severity, c.resolved_at, c.created_at
  FROM investor_next_round_narrative_critique c
  JOIN investor_next_round_narrative_beats b ON b.id = c.beat_id
  ORDER BY c.created_at DESC
  LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_narrative_critique_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_narrative_critique_list() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_investor_narrative_readiness_summary()
RETURNS TABLE (
  beat_category text,
  beats_total int,
  beats_ready int,
  beats_blocked int,
  avg_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.beat_category,
         COUNT(*)::int AS beats_total,
         SUM(CASE WHEN b.readiness_status='ready' THEN 1 ELSE 0 END)::int AS beats_ready,
         SUM(CASE WHEN b.readiness_status='blocked' THEN 1 ELSE 0 END)::int AS beats_blocked,
         ROUND(AVG(b.readiness_score)::numeric, 1) AS avg_score
  FROM investor_next_round_narrative_beats b
  GROUP BY b.beat_category
  ORDER BY b.beat_category;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_narrative_readiness_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_narrative_readiness_summary() TO authenticated;

CREATE OR REPLACE FUNCTION rpc_investor_narrative_proof_metrics()
RETURNS TABLE (
  beat_title text,
  proof_metric_label text,
  proof_metric_value_rupees bigint,
  proof_metric_value_count bigint,
  readiness_status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.beat_title, b.proof_metric_label, b.proof_metric_value_rupees,
         b.proof_metric_value_count, b.readiness_status
  FROM investor_next_round_narrative_beats b
  WHERE b.proof_metric_label IS NOT NULL
  ORDER BY b.beat_order;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_narrative_proof_metrics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_narrative_proof_metrics() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION rpc_investor_narrative_beat_update(
  p_beat_id uuid,
  p_storyline_draft text,
  p_readiness_status text,
  p_readiness_score int,
  p_owner_label text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_next_round_narrative_beats
  SET storyline_draft = COALESCE(p_storyline_draft, storyline_draft),
      readiness_status = COALESCE(p_readiness_status, readiness_status),
      readiness_score = COALESCE(p_readiness_score, readiness_score),
      owner_label = COALESCE(p_owner_label, owner_label),
      last_edited_at = now()
  WHERE id = p_beat_id;
  RETURN p_beat_id;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_narrative_beat_update(uuid,text,text,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_narrative_beat_update(uuid,text,text,int,text) TO authenticated;

CREATE OR REPLACE FUNCTION rpc_investor_narrative_critique_add(
  p_beat_id uuid,
  p_critique_text text,
  p_severity text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_next_round_narrative_critique (beat_id, critique_text, severity)
  VALUES (p_beat_id, p_critique_text, COALESCE(p_severity, 'medium'))
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_narrative_critique_add(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_narrative_critique_add(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION rpc_investor_narrative_critique_resolve(p_critique_id uuid)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_next_round_narrative_critique
  SET resolved_at = now()
  WHERE id = p_critique_id;
  RETURN p_critique_id;
END $$;

REVOKE EXECUTE ON FUNCTION rpc_investor_narrative_critique_resolve(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_investor_narrative_critique_resolve(uuid) TO authenticated;

-- ============================================================================
-- log_founder_* helpers (VOLATILE SECDEF, is_founder gated)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_narrative_beat_edited(
  p_beat_id uuid,
  p_field_edited text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_next_round_narrative_beats
  SET last_edited_at = now()
  WHERE id = p_beat_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_narrative_beat_edited(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_narrative_beat_edited(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_narrative_review_marked(
  p_beat_id uuid,
  p_reviewer_label text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_next_round_narrative_beats
  SET readiness_status = 'in_review',
      owner_label = COALESCE(p_reviewer_label, owner_label),
      last_edited_at = now()
  WHERE id = p_beat_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_narrative_review_marked(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_narrative_review_marked(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_narrative_beat_blocked(
  p_beat_id uuid,
  p_reason text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_next_round_narrative_beats
  SET readiness_status = 'blocked',
      last_edited_at = now()
  WHERE id = p_beat_id;
  INSERT INTO investor_next_round_narrative_critique (beat_id, critique_text, severity)
  VALUES (p_beat_id, COALESCE(p_reason, 'blocked — reason not given'), 'blocker')
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_narrative_beat_blocked(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_narrative_beat_blocked(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_narrative_pitch_ready(p_note text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_next_round_narrative_beats
  SET last_edited_at = now()
  WHERE readiness_status = 'ready';
END $$;

REVOKE EXECUTE ON FUNCTION log_founder_narrative_pitch_ready(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_narrative_pitch_ready(text) TO authenticated;

COMMIT;