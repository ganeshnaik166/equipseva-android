BEGIN;

-- r1630 founder pitch talk tracks
-- central library of memorized pitch versions (1-min, 5-min, 30-min)
-- founder rehearses + tracks usage

CREATE TABLE IF NOT EXISTS founder_pitch_talk_tracks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic text NOT NULL,
  audience text NOT NULL DEFAULT 'investor',
  version text NOT NULL CHECK (version IN ('1min','5min','30min')),
  headline text NOT NULL,
  body_markdown text NOT NULL,
  key_numbers jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','rehearsing','mastered','retired')),
  word_count int NOT NULL DEFAULT 0,
  est_seconds int NOT NULL DEFAULT 0,
  last_rehearsed_at timestamptz,
  mastered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fptt_topic ON founder_pitch_talk_tracks(topic);
CREATE INDEX IF NOT EXISTS idx_fptt_status ON founder_pitch_talk_tracks(status);
CREATE INDEX IF NOT EXISTS idx_fptt_version ON founder_pitch_talk_tracks(version);

CREATE TABLE IF NOT EXISTS founder_pitch_talk_track_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  track_id uuid NOT NULL REFERENCES founder_pitch_talk_tracks(id) ON DELETE CASCADE,
  used_kind text NOT NULL CHECK (used_kind IN ('rehearsal','live_pitch')),
  audience_note text,
  self_score int CHECK (self_score BETWEEN 1 AND 5),
  duration_seconds int,
  notes text,
  used_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fpttu_track ON founder_pitch_talk_track_usage(track_id);
CREATE INDEX IF NOT EXISTS idx_fpttu_used_at ON founder_pitch_talk_track_usage(used_at DESC);

ALTER TABLE founder_pitch_talk_tracks ENABLE ROW LEVEL SECURITY;
ALTER TABLE founder_pitch_talk_track_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fptt_founder ON founder_pitch_talk_tracks;
CREATE POLICY p_fptt_founder ON founder_pitch_talk_tracks
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS p_fpttu_founder ON founder_pitch_talk_track_usage;
CREATE POLICY p_fpttu_founder ON founder_pitch_talk_track_usage
  FOR ALL
  TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================
-- READ RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_pitch_tracks_list()
RETURNS TABLE (
  id uuid,
  topic text,
  audience text,
  version text,
  headline text,
  status text,
  word_count int,
  est_seconds int,
  last_rehearsed_at timestamptz,
  mastered_at timestamptz,
  rehearsal_count bigint,
  avg_self_score numeric,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.topic, t.audience, t.version, t.headline, t.status,
         t.word_count, t.est_seconds, t.last_rehearsed_at, t.mastered_at,
         (SELECT count(*) FROM founder_pitch_talk_track_usage u WHERE u.track_id = t.id) AS rehearsal_count,
         (SELECT round(avg(u.self_score)::numeric, 2) FROM founder_pitch_talk_track_usage u WHERE u.track_id = t.id AND u.self_score IS NOT NULL) AS avg_self_score,
         t.updated_at
  FROM founder_pitch_talk_tracks t
  ORDER BY t.topic ASC, t.version ASC;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_tracks_stats()
RETURNS TABLE (
  total_tracks bigint,
  topics_covered bigint,
  mastered_count bigint,
  draft_count bigint,
  rehearsals_last_7d bigint,
  live_pitches_last_30d bigint,
  avg_score_last_30d numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM founder_pitch_talk_tracks)::bigint,
    (SELECT count(DISTINCT topic) FROM founder_pitch_talk_tracks)::bigint,
    (SELECT count(*) FROM founder_pitch_talk_tracks WHERE status = 'mastered')::bigint,
    (SELECT count(*) FROM founder_pitch_talk_tracks WHERE status = 'draft')::bigint,
    (SELECT count(*) FROM founder_pitch_talk_track_usage WHERE used_kind = 'rehearsal' AND used_at > now() - interval '7 days')::bigint,
    (SELECT count(*) FROM founder_pitch_talk_track_usage WHERE used_kind = 'live_pitch' AND used_at > now() - interval '30 days')::bigint,
    (SELECT round(avg(self_score)::numeric, 2) FROM founder_pitch_talk_track_usage WHERE used_at > now() - interval '30 days' AND self_score IS NOT NULL);
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_tracks_recent_usage()
RETURNS TABLE (
  id uuid,
  track_id uuid,
  topic text,
  version text,
  used_kind text,
  audience_note text,
  self_score int,
  duration_seconds int,
  used_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.track_id, t.topic, t.version, u.used_kind, u.audience_note,
         u.self_score, u.duration_seconds, u.used_at
  FROM founder_pitch_talk_track_usage u
  JOIN founder_pitch_talk_tracks t ON t.id = u.track_id
  ORDER BY u.used_at DESC
  LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_tracks_topic_rollup()
RETURNS TABLE (
  topic text,
  versions_count bigint,
  mastered_versions bigint,
  total_rehearsals bigint,
  last_touched timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.topic,
         count(*)::bigint AS versions_count,
         count(*) FILTER (WHERE t.status = 'mastered')::bigint AS mastered_versions,
         (SELECT count(*) FROM founder_pitch_talk_track_usage u WHERE u.track_id IN (SELECT id FROM founder_pitch_talk_tracks WHERE topic = t.topic))::bigint AS total_rehearsals,
         max(t.updated_at) AS last_touched
  FROM founder_pitch_talk_tracks t
  GROUP BY t.topic
  ORDER BY last_touched DESC NULLS LAST;
END;
$$;

-- ============================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION rpc_founder_pitch_track_upsert(
  p_id uuid,
  p_topic text,
  p_audience text,
  p_version text,
  p_headline text,
  p_body_markdown text,
  p_key_numbers jsonb
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_words int;
  v_seconds int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_words := array_length(regexp_split_to_array(coalesce(p_body_markdown,''), '\s+'), 1);
  v_seconds := CASE p_version WHEN '1min' THEN 60 WHEN '5min' THEN 300 WHEN '30min' THEN 1800 ELSE 0 END;

  IF p_id IS NULL THEN
    INSERT INTO founder_pitch_talk_tracks (topic, audience, version, headline, body_markdown, key_numbers, word_count, est_seconds)
    VALUES (p_topic, coalesce(p_audience,'investor'), p_version, p_headline, p_body_markdown, coalesce(p_key_numbers,'[]'::jsonb), coalesce(v_words,0), v_seconds)
    RETURNING id INTO v_id;
  ELSE
    UPDATE founder_pitch_talk_tracks
       SET topic = p_topic,
           audience = coalesce(p_audience,'investor'),
           version = p_version,
           headline = p_headline,
           body_markdown = p_body_markdown,
           key_numbers = coalesce(p_key_numbers,'[]'::jsonb),
           word_count = coalesce(v_words,0),
           est_seconds = v_seconds,
           updated_at = now()
     WHERE id = p_id
     RETURNING id INTO v_id;
  END IF;

  PERFORM log_founder_pitch_track_upsert(v_id, p_topic, p_version);
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_track_set_status(
  p_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('draft','rehearsing','mastered','retired') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE founder_pitch_talk_tracks
     SET status = p_status,
         mastered_at = CASE WHEN p_status = 'mastered' THEN now() ELSE mastered_at END,
         updated_at = now()
   WHERE id = p_id;
  PERFORM log_founder_pitch_track_status(p_id, p_status);
END;
$$;

CREATE OR REPLACE FUNCTION rpc_founder_pitch_track_log_usage(
  p_track_id uuid,
  p_used_kind text,
  p_audience_note text,
  p_self_score int,
  p_duration_seconds int,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_used_kind NOT IN ('rehearsal','live_pitch') THEN
    RAISE EXCEPTION 'invalid used_kind';
  END IF;
  INSERT INTO founder_pitch_talk_track_usage (track_id, used_kind, audience_note, self_score, duration_seconds, notes)
  VALUES (p_track_id, p_used_kind, p_audience_note, p_self_score, p_duration_seconds, p_notes)
  RETURNING id INTO v_id;

  UPDATE founder_pitch_talk_tracks
     SET last_rehearsed_at = now(),
         status = CASE WHEN status = 'draft' THEN 'rehearsing' ELSE status END,
         updated_at = now()
   WHERE id = p_track_id;

  PERFORM log_founder_pitch_track_usage(v_id, p_track_id, p_used_kind);
  RETURN v_id;
END;
$$;

-- ============================================================
-- log_founder_* helpers (founder-gated + REVOKE PUBLIC, anon)
-- ============================================================

CREATE OR REPLACE FUNCTION log_founder_pitch_track_upsert(
  p_track_id uuid,
  p_topic text,
  p_version text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pitch_track_upsert',
          jsonb_build_object('track_id', p_track_id, 'topic', p_topic, 'version', p_version),
          now());
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_pitch_track_status(
  p_track_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pitch_track_status',
          jsonb_build_object('track_id', p_track_id, 'status', p_status),
          now());
END;
$$;

CREATE OR REPLACE FUNCTION log_founder_pitch_track_usage(
  p_usage_id uuid,
  p_track_id uuid,
  p_used_kind text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'pitch_track_usage',
          jsonb_build_object('usage_id', p_usage_id, 'track_id', p_track_id, 'used_kind', p_used_kind),
          now());
END;
$$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_tracks_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_pitch_tracks_list() TO authenticated;

REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_tracks_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_pitch_tracks_stats() TO authenticated;

REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_tracks_recent_usage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_pitch_tracks_recent_usage() TO authenticated;

REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_tracks_topic_rollup() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_pitch_tracks_topic_rollup() TO authenticated;

REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_track_upsert(uuid, text, text, text, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_pitch_track_upsert(uuid, text, text, text, text, text, jsonb) TO authenticated;

REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_track_set_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_pitch_track_set_status(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION rpc_founder_pitch_track_log_usage(uuid, text, text, int, int, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_founder_pitch_track_log_usage(uuid, text, text, int, int, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_pitch_track_upsert(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pitch_track_upsert(uuid, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_pitch_track_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pitch_track_status(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION log_founder_pitch_track_usage(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_pitch_track_usage(uuid, uuid, text) TO authenticated;

COMMIT;