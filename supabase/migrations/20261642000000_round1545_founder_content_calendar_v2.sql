BEGIN;

-- ============================================================================
-- r1545 — Founder Content Calendar v2
-- Plan content publishing across LinkedIn / blog / newsletter
-- Per-piece status (draft/scheduled/published) + topic + author + reach prediction
-- Founder review queue
-- ============================================================================

-- ---- Table 1: founder_content_calendar_v2_pieces -------------------------
CREATE TABLE IF NOT EXISTS founder_content_calendar_v2_pieces (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel      text NOT NULL CHECK (channel IN ('linkedin','blog','newsletter')),
  topic        text NOT NULL,
  headline     text NOT NULL,
  body_md      text,
  author_email text NOT NULL,
  status       text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','scheduled','published','spiked')),
  scheduled_for timestamptz,
  published_at  timestamptz,
  reach_predicted_n int NOT NULL DEFAULT 0,
  reach_actual_n    int,
  review_state text NOT NULL DEFAULT 'pending' CHECK (review_state IN ('pending','approved','changes_requested','rejected')),
  review_notes text,
  reviewed_by  text,
  reviewed_at  timestamptz,
  tags         text[] NOT NULL DEFAULT ARRAY[]::text[],
  created_by   uuid REFERENCES auth.users(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fccv2_pieces_status   ON founder_content_calendar_v2_pieces(status);
CREATE INDEX IF NOT EXISTS idx_fccv2_pieces_channel  ON founder_content_calendar_v2_pieces(channel);
CREATE INDEX IF NOT EXISTS idx_fccv2_pieces_sched    ON founder_content_calendar_v2_pieces(scheduled_for);
CREATE INDEX IF NOT EXISTS idx_fccv2_pieces_review   ON founder_content_calendar_v2_pieces(review_state);

ALTER TABLE founder_content_calendar_v2_pieces ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fccv2_pieces_founder_only ON founder_content_calendar_v2_pieces;
CREATE POLICY fccv2_pieces_founder_only ON founder_content_calendar_v2_pieces
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ---- Table 2: founder_content_calendar_v2_events -------------------------
CREATE TABLE IF NOT EXISTS founder_content_calendar_v2_events (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  piece_id   uuid REFERENCES founder_content_calendar_v2_pieces(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('created','status_change','review_action','schedule_set','published','spiked','metric_update')),
  detail     jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_email text,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fccv2_events_piece ON founder_content_calendar_v2_events(piece_id);
CREATE INDEX IF NOT EXISTS idx_fccv2_events_when  ON founder_content_calendar_v2_events(occurred_at DESC);

ALTER TABLE founder_content_calendar_v2_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fccv2_events_founder_only ON founder_content_calendar_v2_events;
CREATE POLICY fccv2_events_founder_only ON founder_content_calendar_v2_events
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

-- 1. Pipeline summary
CREATE OR REPLACE FUNCTION rpc_fccv2_pipeline_summary()
RETURNS TABLE(
  total_pieces bigint,
  draft_n bigint,
  in_review_n bigint,
  scheduled_n bigint,
  published_n bigint,
  spiked_n bigint,
  pending_review_n bigint,
  approved_n bigint,
  changes_requested_n bigint,
  rejected_n bigint,
  total_reach_predicted bigint,
  total_reach_actual bigint,
  scheduled_next_7d bigint,
  scheduled_next_30d bigint,
  published_last_30d bigint,
  authors_active bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'draft'),
    count(*) FILTER (WHERE status = 'in_review'),
    count(*) FILTER (WHERE status = 'scheduled'),
    count(*) FILTER (WHERE status = 'published'),
    count(*) FILTER (WHERE status = 'spiked'),
    count(*) FILTER (WHERE review_state = 'pending'),
    count(*) FILTER (WHERE review_state = 'approved'),
    count(*) FILTER (WHERE review_state = 'changes_requested'),
    count(*) FILTER (WHERE review_state = 'rejected'),
    COALESCE(sum(reach_predicted_n),0),
    COALESCE(sum(reach_actual_n),0),
    count(*) FILTER (WHERE scheduled_for BETWEEN now() AND now() + INTERVAL '7 days'),
    count(*) FILTER (WHERE scheduled_for BETWEEN now() AND now() + INTERVAL '30 days'),
    count(*) FILTER (WHERE published_at >= now() - INTERVAL '30 days'),
    (SELECT count(DISTINCT author_email) FROM founder_content_calendar_v2_pieces)
  FROM founder_content_calendar_v2_pieces;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_fccv2_pipeline_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_fccv2_pipeline_summary() TO authenticated;

-- 2. Upcoming schedule
CREATE OR REPLACE FUNCTION rpc_fccv2_upcoming_schedule()
RETURNS TABLE(
  id uuid,
  channel text,
  topic text,
  headline text,
  author_email text,
  scheduled_for timestamptz,
  status text,
  reach_predicted_n int,
  review_state text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.channel, p.topic, p.headline, p.author_email,
         p.scheduled_for, p.status, p.reach_predicted_n, p.review_state
  FROM founder_content_calendar_v2_pieces p
  WHERE p.scheduled_for IS NOT NULL
    AND p.scheduled_for >= now()
    AND p.status IN ('scheduled','in_review')
  ORDER BY p.scheduled_for ASC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_fccv2_upcoming_schedule() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_fccv2_upcoming_schedule() TO authenticated;

-- 3. Review queue
CREATE OR REPLACE FUNCTION rpc_fccv2_review_queue()
RETURNS TABLE(
  id uuid,
  channel text,
  topic text,
  headline text,
  author_email text,
  status text,
  review_state text,
  reach_predicted_n int,
  scheduled_for timestamptz,
  created_at timestamptz,
  hours_in_queue numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.channel, p.topic, p.headline, p.author_email,
         p.status, p.review_state, p.reach_predicted_n, p.scheduled_for, p.created_at,
         ROUND(EXTRACT(EPOCH FROM (now() - p.created_at)) / 3600.0, 1) AS hours_in_queue
  FROM founder_content_calendar_v2_pieces p
  WHERE p.review_state IN ('pending','changes_requested')
  ORDER BY p.created_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_fccv2_review_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_fccv2_review_queue() TO authenticated;

-- 4. Channel breakdown
CREATE OR REPLACE FUNCTION rpc_fccv2_channel_breakdown()
RETURNS TABLE(
  channel text,
  total bigint,
  drafts bigint,
  scheduled bigint,
  published bigint,
  avg_predicted_reach numeric,
  total_actual_reach bigint,
  pending_review bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.channel,
         count(*),
         count(*) FILTER (WHERE p.status = 'draft'),
         count(*) FILTER (WHERE p.status = 'scheduled'),
         count(*) FILTER (WHERE p.status = 'published'),
         ROUND(AVG(p.reach_predicted_n)::numeric, 1),
         COALESCE(sum(p.reach_actual_n),0),
         count(*) FILTER (WHERE p.review_state = 'pending')
  FROM founder_content_calendar_v2_pieces p
  GROUP BY p.channel
  ORDER BY count(*) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_fccv2_channel_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_fccv2_channel_breakdown() TO authenticated;

-- 5. Author leaderboard
CREATE OR REPLACE FUNCTION rpc_fccv2_author_leaderboard()
RETURNS TABLE(
  author_email text,
  pieces_total bigint,
  pieces_published bigint,
  pieces_pending bigint,
  total_predicted_reach bigint,
  total_actual_reach bigint,
  approval_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.author_email,
         count(*),
         count(*) FILTER (WHERE p.status = 'published'),
         count(*) FILTER (WHERE p.review_state = 'pending'),
         COALESCE(sum(p.reach_predicted_n),0),
         COALESCE(sum(p.reach_actual_n),0),
         CASE WHEN count(*) FILTER (WHERE p.review_state IN ('approved','rejected')) > 0
              THEN ROUND(100.0 * count(*) FILTER (WHERE p.review_state = 'approved')
                         / NULLIF(count(*) FILTER (WHERE p.review_state IN ('approved','rejected')), 0), 1)
              ELSE 0 END
  FROM founder_content_calendar_v2_pieces p
  GROUP BY p.author_email
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_fccv2_author_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_fccv2_author_leaderboard() TO authenticated;

-- 6. Recently published
CREATE OR REPLACE FUNCTION rpc_fccv2_recently_published()
RETURNS TABLE(
  id uuid,
  channel text,
  topic text,
  headline text,
  author_email text,
  published_at timestamptz,
  reach_predicted_n int,
  reach_actual_n int,
  delta_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.channel, p.topic, p.headline, p.author_email,
         p.published_at, p.reach_predicted_n, p.reach_actual_n,
         CASE WHEN p.reach_predicted_n > 0 AND p.reach_actual_n IS NOT NULL
              THEN ROUND(100.0 * (p.reach_actual_n - p.reach_predicted_n) / p.reach_predicted_n::numeric, 1)
              ELSE NULL END
  FROM founder_content_calendar_v2_pieces p
  WHERE p.status = 'published'
  ORDER BY p.published_at DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_fccv2_recently_published() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_fccv2_recently_published() TO authenticated;

-- 7. Recent events feed
CREATE OR REPLACE FUNCTION rpc_fccv2_recent_events()
RETURNS TABLE(
  id uuid,
  piece_id uuid,
  headline text,
  channel text,
  event_type text,
  actor_email text,
  occurred_at timestamptz,
  detail jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.piece_id, p.headline, p.channel, e.event_type, e.actor_email, e.occurred_at, e.detail
  FROM founder_content_calendar_v2_events e
  LEFT JOIN founder_content_calendar_v2_pieces p ON p.id = e.piece_id
  ORDER BY e.occurred_at DESC
  LIMIT 80;
END;
$$;

REVOKE EXECUTE ON FUNCTION rpc_fccv2_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION rpc_fccv2_recent_events() TO authenticated;

-- ============================================================================
-- WRITE / LOG helpers (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_fccv2_piece_upsert(
  p_piece_id uuid,
  p_after jsonb
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fccv2_piece_upsert',
          jsonb_build_object('piece_id', p_piece_id, 'after', p_after));
  INSERT INTO founder_content_calendar_v2_events (piece_id, event_type, detail, actor_email)
  VALUES (p_piece_id, 'created', p_after, (auth.jwt()->>'email'));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_fccv2_piece_upsert(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_fccv2_piece_upsert(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_fccv2_review_action(
  p_piece_id uuid,
  p_review_state text,
  p_notes text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_content_calendar_v2_pieces
     SET review_state = p_review_state,
         review_notes = p_notes,
         reviewed_by  = (auth.jwt()->>'email'),
         reviewed_at  = now(),
         updated_at   = now()
   WHERE id = p_piece_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fccv2_review_action',
          jsonb_build_object('piece_id', p_piece_id, 'review_state', p_review_state, 'notes', p_notes));
  INSERT INTO founder_content_calendar_v2_events (piece_id, event_type, detail, actor_email)
  VALUES (p_piece_id, 'review_action',
          jsonb_build_object('review_state', p_review_state, 'notes', p_notes),
          (auth.jwt()->>'email'));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_fccv2_review_action(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_fccv2_review_action(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_fccv2_schedule_set(
  p_piece_id uuid,
  p_scheduled_for timestamptz
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_content_calendar_v2_pieces
     SET scheduled_for = p_scheduled_for,
         status = 'scheduled',
         updated_at = now()
   WHERE id = p_piece_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fccv2_schedule_set',
          jsonb_build_object('piece_id', p_piece_id, 'scheduled_for', p_scheduled_for));
  INSERT INTO founder_content_calendar_v2_events (piece_id, event_type, detail, actor_email)
  VALUES (p_piece_id, 'schedule_set',
          jsonb_build_object('scheduled_for', p_scheduled_for),
          (auth.jwt()->>'email'));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_fccv2_schedule_set(uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_fccv2_schedule_set(uuid, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_fccv2_publish_mark(
  p_piece_id uuid,
  p_reach_actual int
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_content_calendar_v2_pieces
     SET status = 'published',
         published_at = COALESCE(published_at, now()),
         reach_actual_n = p_reach_actual,
         updated_at = now()
   WHERE id = p_piece_id;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'fccv2_publish_mark',
          jsonb_build_object('piece_id', p_piece_id, 'reach_actual', p_reach_actual));
  INSERT INTO founder_content_calendar_v2_events (piece_id, event_type, detail, actor_email)
  VALUES (p_piece_id, 'published',
          jsonb_build_object('reach_actual', p_reach_actual),
          (auth.jwt()->>'email'));
END;
$$;

REVOKE EXECUTE ON FUNCTION log_founder_fccv2_publish_mark(uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_fccv2_publish_mark(uuid, int) TO authenticated;

COMMIT;