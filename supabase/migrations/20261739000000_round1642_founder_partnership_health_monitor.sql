BEGIN;

-- ============================================================================
-- r1642 — Founder Partnership Health Monitor
-- Extends r1456 strategic-partnerships with health-score per partnership:
--   touchpoint cadence + revenue delivered + relationship sentiment
-- Surfaces at-risk partnerships for founder action.
-- ============================================================================

CREATE TABLE IF NOT EXISTS founder_partnership_health_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partnership_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  touchpoint_kind text NOT NULL CHECK (touchpoint_kind IN ('call','email','meeting','site_visit','qbr','escalation','social')),
  touchpoint_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  sentiment text NOT NULL DEFAULT 'neutral' CHECK (sentiment IN ('positive','neutral','negative','at_risk')),
  logged_by_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fph_touchpoints_org ON founder_partnership_health_touchpoints(partnership_org_id, touchpoint_at DESC);
CREATE INDEX IF NOT EXISTS idx_fph_touchpoints_sentiment ON founder_partnership_health_touchpoints(sentiment, touchpoint_at DESC);

ALTER TABLE founder_partnership_health_touchpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fph_touchpoints_founder_only ON founder_partnership_health_touchpoints;
CREATE POLICY fph_touchpoints_founder_only ON founder_partnership_health_touchpoints
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_partnership_health_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  partnership_org_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  score_as_of timestamptz NOT NULL DEFAULT now(),
  touchpoint_score int NOT NULL DEFAULT 0 CHECK (touchpoint_score BETWEEN 0 AND 100),
  revenue_score int NOT NULL DEFAULT 0 CHECK (revenue_score BETWEEN 0 AND 100),
  sentiment_score int NOT NULL DEFAULT 0 CHECK (sentiment_score BETWEEN 0 AND 100),
  composite_score int NOT NULL DEFAULT 0 CHECK (composite_score BETWEEN 0 AND 100),
  risk_band text NOT NULL DEFAULT 'healthy' CHECK (risk_band IN ('healthy','watch','at_risk','critical')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fph_scores_org ON founder_partnership_health_scores(partnership_org_id, score_as_of DESC);
CREATE INDEX IF NOT EXISTS idx_fph_scores_band ON founder_partnership_health_scores(risk_band, composite_score);

ALTER TABLE founder_partnership_health_scores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fph_scores_founder_only ON founder_partnership_health_scores;
CREATE POLICY fph_scores_founder_only ON founder_partnership_health_scores
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- RPC 1: portfolio summary
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_partnership_health_portfolio()
RETURNS TABLE (
  total_partnerships int,
  healthy_count int,
  watch_count int,
  at_risk_count int,
  critical_count int,
  avg_composite numeric,
  touchpoints_last_30d int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (partnership_org_id) partnership_org_id, composite_score, risk_band
    FROM founder_partnership_health_scores
    ORDER BY partnership_org_id, score_as_of DESC
  )
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'healthy'))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'watch'))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'at_risk'))::int,
    (COUNT(*) FILTER (WHERE risk_band = 'critical'))::int,
    ROUND(AVG(composite_score)::numeric, 1),
    (SELECT COUNT(*)::int FROM founder_partnership_health_touchpoints
      WHERE touchpoint_at > now() - interval '30 days')
  FROM latest;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_partnership_health_portfolio() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_partnership_health_portfolio() TO authenticated;

-- ============================================================================
-- RPC 2: per-partnership latest scores list
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_partnership_health_list()
RETURNS TABLE (
  partnership_org_id uuid,
  org_name text,
  state text,
  composite_score int,
  touchpoint_score int,
  revenue_score int,
  sentiment_score int,
  risk_band text,
  last_touchpoint_at timestamptz,
  scored_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.partnership_org_id)
      s.partnership_org_id, s.composite_score, s.touchpoint_score, s.revenue_score,
      s.sentiment_score, s.risk_band, s.score_as_of
    FROM founder_partnership_health_scores s
    ORDER BY s.partnership_org_id, s.score_as_of DESC
  ),
  last_tp AS (
    SELECT t.partnership_org_id, MAX(t.touchpoint_at) AS last_at
    FROM founder_partnership_health_touchpoints t
    GROUP BY t.partnership_org_id
  )
  SELECT l.partnership_org_id, o.name, o.state,
         l.composite_score, l.touchpoint_score, l.revenue_score, l.sentiment_score,
         l.risk_band, lt.last_at, l.score_as_of
  FROM latest l
  JOIN organizations o ON o.id = l.partnership_org_id
  LEFT JOIN last_tp lt ON lt.partnership_org_id = l.partnership_org_id
  ORDER BY l.composite_score ASC, l.score_as_of DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_partnership_health_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_partnership_health_list() TO authenticated;

-- ============================================================================
-- RPC 3: at-risk surface (composite < 60 OR risk_band in at_risk/critical)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_partnership_health_at_risk()
RETURNS TABLE (
  partnership_org_id uuid,
  org_name text,
  state text,
  composite_score int,
  risk_band text,
  days_since_touchpoint int,
  revenue_last_90d_rupees bigint,
  scored_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.partnership_org_id)
      s.partnership_org_id, s.composite_score, s.risk_band, s.score_as_of
    FROM founder_partnership_health_scores s
    ORDER BY s.partnership_org_id, s.score_as_of DESC
  ),
  last_tp AS (
    SELECT t.partnership_org_id, MAX(t.touchpoint_at) AS last_at
    FROM founder_partnership_health_touchpoints t
    GROUP BY t.partnership_org_id
  ),
  rev AS (
    SELECT rj.hospital_org_id AS org_id,
           COALESCE(SUM(rj.contracted_amount_rupees), 0)::bigint AS rupees
    FROM repair_jobs rj
    WHERE rj.created_at > now() - interval '90 days'
    GROUP BY rj.hospital_org_id
  )
  SELECT l.partnership_org_id, o.name, o.state, l.composite_score, l.risk_band,
         GREATEST(0, EXTRACT(DAY FROM (now() - lt.last_at))::int) AS days_since,
         COALESCE(r.rupees, 0)::bigint,
         l.score_as_of
  FROM latest l
  JOIN organizations o ON o.id = l.partnership_org_id
  LEFT JOIN last_tp lt ON lt.partnership_org_id = l.partnership_org_id
  LEFT JOIN rev r ON r.org_id = l.partnership_org_id
  WHERE l.risk_band IN ('at_risk','critical') OR l.composite_score < 60
  ORDER BY l.composite_score ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_partnership_health_at_risk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_partnership_health_at_risk() TO authenticated;

-- ============================================================================
-- RPC 4: recent touchpoints feed
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_partnership_health_recent_touchpoints()
RETURNS TABLE (
  id uuid,
  partnership_org_id uuid,
  org_name text,
  touchpoint_kind text,
  sentiment text,
  notes text,
  touchpoint_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT t.id, t.partnership_org_id, o.name, t.touchpoint_kind, t.sentiment, t.notes, t.touchpoint_at
  FROM founder_partnership_health_touchpoints t
  JOIN organizations o ON o.id = t.partnership_org_id
  ORDER BY t.touchpoint_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_partnership_health_recent_touchpoints() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_partnership_health_recent_touchpoints() TO authenticated;

-- ============================================================================
-- RPC 5: sentiment mix breakdown (last 90d)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_partnership_health_sentiment_mix()
RETURNS TABLE (
  sentiment text,
  touchpoint_count int,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT COUNT(*)::int INTO v_total
  FROM founder_partnership_health_touchpoints
  WHERE touchpoint_at > now() - interval '90 days';

  IF v_total = 0 THEN v_total := 1; END IF;

  RETURN QUERY
  SELECT t.sentiment,
         (COUNT(*))::int,
         ROUND((COUNT(*) * 100.0 / v_total)::numeric, 1)
  FROM founder_partnership_health_touchpoints t
  WHERE t.touchpoint_at > now() - interval '90 days'
  GROUP BY t.sentiment
  ORDER BY (COUNT(*)) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_partnership_health_sentiment_mix() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_partnership_health_sentiment_mix() TO authenticated;

-- ============================================================================
-- RPC 6: revenue-vs-score scatter (per partnership)
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_partnership_health_revenue_vs_score()
RETURNS TABLE (
  partnership_org_id uuid,
  org_name text,
  composite_score int,
  revenue_last_90d_rupees bigint,
  amc_active_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (s.partnership_org_id)
      s.partnership_org_id, s.composite_score
    FROM founder_partnership_health_scores s
    ORDER BY s.partnership_org_id, s.score_as_of DESC
  ),
  rev AS (
    SELECT rj.hospital_org_id AS org_id,
           COALESCE(SUM(rj.contracted_amount_rupees), 0)::bigint AS rupees
    FROM repair_jobs rj
    WHERE rj.created_at > now() - interval '90 days'
    GROUP BY rj.hospital_org_id
  ),
  amc AS (
    SELECT p.organization_id AS org_id, COUNT(*)::int AS active_count
    FROM amc_contracts c
    JOIN profiles p ON p.id = c.hospital_user_id
    GROUP BY p.organization_id
  )
  SELECT l.partnership_org_id, o.name, l.composite_score,
         COALESCE(r.rupees, 0)::bigint,
         COALESCE(a.active_count, 0)
  FROM latest l
  JOIN organizations o ON o.id = l.partnership_org_id
  LEFT JOIN rev r ON r.org_id = l.partnership_org_id
  LEFT JOIN amc a ON a.org_id = l.partnership_org_id
  ORDER BY l.composite_score ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_partnership_health_revenue_vs_score() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_partnership_health_revenue_vs_score() TO authenticated;

-- ============================================================================
-- RPC 7: touchpoint cadence stats
-- ============================================================================
CREATE OR REPLACE FUNCTION founder_partnership_health_cadence_stats()
RETURNS TABLE (
  bucket_label text,
  partnership_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  WITH last_tp AS (
    SELECT t.partnership_org_id, MAX(t.touchpoint_at) AS last_at
    FROM founder_partnership_health_touchpoints t
    GROUP BY t.partnership_org_id
  ),
  bucketed AS (
    SELECT CASE
      WHEN last_at > now() - interval '7 days'  THEN '0-7d'
      WHEN last_at > now() - interval '30 days' THEN '8-30d'
      WHEN last_at > now() - interval '60 days' THEN '31-60d'
      WHEN last_at > now() - interval '90 days' THEN '61-90d'
      ELSE '90d+'
    END AS b
    FROM last_tp
  )
  SELECT b, (COUNT(*))::int
  FROM bucketed
  GROUP BY b
  ORDER BY CASE b
    WHEN '0-7d' THEN 1 WHEN '8-30d' THEN 2 WHEN '31-60d' THEN 3
    WHEN '61-90d' THEN 4 ELSE 5 END;
END;
$$;

REVOKE EXECUTE ON FUNCTION founder_partnership_health_cadence_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_partnership_health_cadence_stats() TO authenticated;

-- ============================================================================
-- WRITE helper — log a touchpoint (VOLATILE)
-- ============================================================================
CREATE OR REPLACE FUNCTION log_founder_partnership_health_touchpoint(
  p_partnership_org_id uuid,
  p_kind text,
  p_sentiment text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO founder_partnership_health_touchpoints
    (partnership_org_id, touchpoint_kind, sentiment, notes, logged_by_user_id)
  VALUES (p_partnership_org_id, p_kind, COALESCE(p_sentiment, 'neutral'), p_notes, auth.uid())
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_founder_partnership_health_touchpoint',
    jsonb_build_object('id', v_id, 'partnership_org_id', p_partnership_org_id, 'kind', p_kind, 'sentiment', p_sentiment),
    now()
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_partnership_health_touchpoint(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_partnership_health_touchpoint(uuid, text, text, text) TO authenticated;

COMMIT;