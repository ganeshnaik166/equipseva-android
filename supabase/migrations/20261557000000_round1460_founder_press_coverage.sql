BEGIN;

-- ============================================================
-- r1460 — Founder Press Coverage Tracker
-- Log press mentions, interviews, podcasts, awards.
-- Track sentiment, reach (audience size), media-train flag,
-- and upcoming media commitments.
-- ============================================================

-- Mentions log: anything published / aired / awarded
CREATE TABLE IF NOT EXISTS founder_press_mentions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  outlet text NOT NULL,
  headline text NOT NULL,
  url text,
  mention_type text NOT NULL CHECK (mention_type IN ('mention','interview','podcast','award','op_ed','tv','radio','newsletter')),
  sentiment text NOT NULL DEFAULT 'neutral' CHECK (sentiment IN ('positive','neutral','negative','mixed')),
  reach_audience bigint NOT NULL DEFAULT 0,
  language text NOT NULL DEFAULT 'en',
  region text,
  media_trained boolean NOT NULL DEFAULT false,
  founder_quoted boolean NOT NULL DEFAULT false,
  estimated_value_rupees bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_press_mentions_occurred ON founder_press_mentions(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_press_mentions_type ON founder_press_mentions(mention_type);
CREATE INDEX IF NOT EXISTS idx_press_mentions_sentiment ON founder_press_mentions(sentiment);

ALTER TABLE founder_press_mentions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS press_mentions_founder_all ON founder_press_mentions;
CREATE POLICY press_mentions_founder_all ON founder_press_mentions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- Upcoming media commitments
CREATE TABLE IF NOT EXISTS founder_press_commitments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scheduled_at timestamptz NOT NULL,
  outlet text NOT NULL,
  topic text NOT NULL,
  commitment_type text NOT NULL CHECK (commitment_type IN ('interview','podcast','panel','keynote','press_briefing','tv_show','webinar')),
  prep_required_hours numeric(5,2) NOT NULL DEFAULT 0,
  prep_done boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','confirmed','completed','cancelled','rescheduled')),
  contact_name text,
  contact_email text,
  expected_reach bigint NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES profiles(id)
);

CREATE INDEX IF NOT EXISTS idx_press_commit_scheduled ON founder_press_commitments(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_press_commit_status ON founder_press_commitments(status);

ALTER TABLE founder_press_commitments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS press_commit_founder_all ON founder_press_commitments;
CREATE POLICY press_commit_founder_all ON founder_press_commitments
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (7) — SECDEF STABLE
-- ============================================================

CREATE OR REPLACE FUNCTION founder_press_kpis()
RETURNS TABLE(
  total_mentions bigint,
  mentions_30d bigint,
  mentions_90d bigint,
  mentions_365d bigint,
  interviews_total bigint,
  podcasts_total bigint,
  awards_total bigint,
  op_eds_total bigint,
  positive_share_pct numeric,
  negative_share_pct numeric,
  total_reach bigint,
  reach_30d bigint,
  founder_quoted_share_pct numeric,
  media_trained_share_pct numeric,
  upcoming_commitments bigint,
  prep_pending_commitments bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH m AS (SELECT * FROM founder_press_mentions),
  c AS (SELECT * FROM founder_press_commitments)
  SELECT
    (SELECT COUNT(*) FROM m)::bigint,
    (SELECT COUNT(*) FROM m WHERE occurred_at > now() - interval '30 days')::bigint,
    (SELECT COUNT(*) FROM m WHERE occurred_at > now() - interval '90 days')::bigint,
    (SELECT COUNT(*) FROM m WHERE occurred_at > now() - interval '365 days')::bigint,
    (SELECT COUNT(*) FROM m WHERE mention_type='interview')::bigint,
    (SELECT COUNT(*) FROM m WHERE mention_type='podcast')::bigint,
    (SELECT COUNT(*) FROM m WHERE mention_type='award')::bigint,
    (SELECT COUNT(*) FROM m WHERE mention_type='op_ed')::bigint,
    CASE WHEN (SELECT COUNT(*) FROM m)=0 THEN 0
      ELSE ROUND(100.0*(SELECT COUNT(*) FROM m WHERE sentiment='positive')/(SELECT COUNT(*) FROM m),1) END,
    CASE WHEN (SELECT COUNT(*) FROM m)=0 THEN 0
      ELSE ROUND(100.0*(SELECT COUNT(*) FROM m WHERE sentiment='negative')/(SELECT COUNT(*) FROM m),1) END,
    COALESCE((SELECT SUM(reach_audience) FROM m),0)::bigint,
    COALESCE((SELECT SUM(reach_audience) FROM m WHERE occurred_at > now() - interval '30 days'),0)::bigint,
    CASE WHEN (SELECT COUNT(*) FROM m)=0 THEN 0
      ELSE ROUND(100.0*(SELECT COUNT(*) FROM m WHERE founder_quoted)/(SELECT COUNT(*) FROM m),1) END,
    CASE WHEN (SELECT COUNT(*) FROM m)=0 THEN 0
      ELSE ROUND(100.0*(SELECT COUNT(*) FROM m WHERE media_trained)/(SELECT COUNT(*) FROM m),1) END,
    (SELECT COUNT(*) FROM c WHERE scheduled_at > now() AND status IN ('scheduled','confirmed'))::bigint,
    (SELECT COUNT(*) FROM c WHERE scheduled_at > now() AND NOT prep_done AND status IN ('scheduled','confirmed'))::bigint;
END; $$;

REVOKE ALL ON FUNCTION founder_press_kpis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_press_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_recent(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  occurred_at timestamptz,
  outlet text,
  headline text,
  mention_type text,
  sentiment text,
  reach_audience bigint,
  founder_quoted boolean,
  media_trained boolean,
  estimated_value_rupees bigint,
  url text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.occurred_at, m.outlet, m.headline, m.mention_type, m.sentiment,
         m.reach_audience, m.founder_quoted, m.media_trained, m.estimated_value_rupees, m.url
  FROM founder_press_mentions m
  ORDER BY m.occurred_at DESC
  LIMIT GREATEST(p_limit,1);
END; $$;

REVOKE ALL ON FUNCTION founder_press_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_press_recent(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_by_type()
RETURNS TABLE(
  mention_type text,
  total bigint,
  total_reach bigint,
  positive_count bigint,
  negative_count bigint,
  avg_reach numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.mention_type,
         COUNT(*)::bigint,
         COALESCE(SUM(m.reach_audience),0)::bigint,
         SUM(CASE WHEN m.sentiment='positive' THEN 1 ELSE 0 END)::bigint,
         SUM(CASE WHEN m.sentiment='negative' THEN 1 ELSE 0 END)::bigint,
         ROUND(COALESCE(AVG(m.reach_audience),0),0)
  FROM founder_press_mentions m
  GROUP BY m.mention_type
  ORDER BY COUNT(*) DESC;
END; $$;

REVOKE ALL ON FUNCTION founder_press_by_type() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_press_by_type() TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_by_outlet(p_limit int DEFAULT 20)
RETURNS TABLE(
  outlet text,
  total bigint,
  total_reach bigint,
  positive_count bigint,
  last_occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.outlet,
         COUNT(*)::bigint,
         COALESCE(SUM(m.reach_audience),0)::bigint,
         SUM(CASE WHEN m.sentiment='positive' THEN 1 ELSE 0 END)::bigint,
         MAX(m.occurred_at)
  FROM founder_press_mentions m
  GROUP BY m.outlet
  ORDER BY COUNT(*) DESC, total_reach DESC
  LIMIT GREATEST(p_limit,1);
END; $$;

REVOKE ALL ON FUNCTION founder_press_by_outlet(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_press_by_outlet(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_sentiment_trend_12mo()
RETURNS TABLE(
  month_start date,
  mentions bigint,
  positive_count bigint,
  negative_count bigint,
  neutral_count bigint,
  reach bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', m.occurred_at)::date,
         COUNT(*)::bigint,
         SUM(CASE WHEN m.sentiment='positive' THEN 1 ELSE 0 END)::bigint,
         SUM(CASE WHEN m.sentiment='negative' THEN 1 ELSE 0 END)::bigint,
         SUM(CASE WHEN m.sentiment='neutral'  THEN 1 ELSE 0 END)::bigint,
         COALESCE(SUM(m.reach_audience),0)::bigint
  FROM founder_press_mentions m
  WHERE m.occurred_at > now() - interval '12 months'
  GROUP BY 1
  ORDER BY 1 DESC;
END; $$;

REVOKE ALL ON FUNCTION founder_press_sentiment_trend_12mo() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_press_sentiment_trend_12mo() TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_upcoming(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  scheduled_at timestamptz,
  outlet text,
  topic text,
  commitment_type text,
  prep_required_hours numeric,
  prep_done boolean,
  status text,
  expected_reach bigint,
  contact_name text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.scheduled_at, c.outlet, c.topic, c.commitment_type,
         c.prep_required_hours, c.prep_done, c.status, c.expected_reach, c.contact_name
  FROM founder_press_commitments c
  WHERE c.scheduled_at > now() - interval '7 days'
  ORDER BY c.scheduled_at ASC
  LIMIT GREATEST(p_limit,1);
END; $$;

REVOKE ALL ON FUNCTION founder_press_upcoming(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_press_upcoming(int) TO authenticated;

CREATE OR REPLACE FUNCTION founder_press_top_reach(p_limit int DEFAULT 20)
RETURNS TABLE(
  id uuid,
  occurred_at timestamptz,
  outlet text,
  headline text,
  mention_type text,
  reach_audience bigint,
  sentiment text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.occurred_at, m.outlet, m.headline, m.mention_type, m.reach_audience, m.sentiment
  FROM founder_press_mentions m
  ORDER BY m.reach_audience DESC NULLS LAST, m.occurred_at DESC
  LIMIT GREATEST(p_limit,1);
END; $$;

REVOKE ALL ON FUNCTION founder_press_top_reach(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION founder_press_top_reach(int) TO authenticated;

-- ============================================================
-- WRITE helpers (4) — VOLATILE SECDEF, gated
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_press_mention(
  p_outlet text,
  p_headline text,
  p_mention_type text,
  p_sentiment text DEFAULT 'neutral',
  p_reach bigint DEFAULT 0,
  p_url text DEFAULT NULL,
  p_media_trained boolean DEFAULT false,
  p_founder_quoted boolean DEFAULT false,
  p_estimated_value_rupees bigint DEFAULT 0,
  p_language text DEFAULT 'en',
  p_region text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_occurred_at timestamptz DEFAULT now()
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_press_mentions(
    outlet, headline, mention_type, sentiment, reach_audience, url,
    media_trained, founder_quoted, estimated_value_rupees, language, region, notes,
    occurred_at, created_by
  ) VALUES (
    p_outlet, p_headline, p_mention_type, p_sentiment, p_reach, p_url,
    p_media_trained, p_founder_quoted, p_estimated_value_rupees, p_language, p_region, p_notes,
    p_occurred_at, auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END; $$;

REVOKE ALL ON FUNCTION log_founder_press_mention(text,text,text,text,bigint,text,boolean,boolean,bigint,text,text,text,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_press_mention(text,text,text,text,bigint,text,boolean,boolean,bigint,text,text,text,timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_press_commitment(
  p_scheduled_at timestamptz,
  p_outlet text,
  p_topic text,
  p_commitment_type text,
  p_prep_hours numeric DEFAULT 0,
  p_expected_reach bigint DEFAULT 0,
  p_contact_name text DEFAULT NULL,
  p_contact_email text DEFAULT NULL,
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_press_commitments(
    scheduled_at, outlet, topic, commitment_type, prep_required_hours,
    expected_reach, contact_name, contact_email, notes, created_by
  ) VALUES (
    p_scheduled_at, p_outlet, p_topic, p_commitment_type, p_prep_hours,
    p_expected_reach, p_contact_name, p_contact_email, p_notes, auth.uid()
  ) RETURNING id INTO v_id;
  RETURN v_id;
END; $$;

REVOKE ALL ON FUNCTION log_founder_press_commitment(timestamptz,text,text,text,numeric,bigint,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_press_commitment(timestamptz,text,text,text,numeric,bigint,text,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_press_commitment_status(
  p_id uuid,
  p_status text,
  p_prep_done boolean DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_press_commitments
  SET status = p_status,
      prep_done = COALESCE(p_prep_done, prep_done)
  WHERE id = p_id;
END; $$;

REVOKE ALL ON FUNCTION log_founder_press_commitment_status(uuid,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_press_commitment_status(uuid,text,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_press_mention_sentiment(
  p_id uuid,
  p_sentiment text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_press_mentions
  SET sentiment = p_sentiment
  WHERE id = p_id;
END; $$;

REVOKE ALL ON FUNCTION log_founder_press_mention_sentiment(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION log_founder_press_mention_sentiment(uuid,text) TO authenticated;

COMMIT;