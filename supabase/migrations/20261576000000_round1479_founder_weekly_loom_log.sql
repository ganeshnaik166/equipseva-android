BEGIN;

-- =========================================================================
-- r1479 — Founder Weekly Loom Log
-- Tracks founder-recorded Loom videos by week + audience, view counts,
-- and surfaces stale-no-loom-this-week alerts.
-- =========================================================================

CREATE TABLE IF NOT EXISTS founder_weekly_loom_videos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iso_week date NOT NULL,                       -- Monday of the ISO week
  topic text NOT NULL,
  audience text NOT NULL CHECK (audience IN ('investors','team','hospitals','public','engineers')),
  loom_url text NOT NULL,
  duration_seconds int,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  recorded_by_user_id uuid NOT NULL REFERENCES auth.users(id),
  notes text,
  is_published boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fwll_videos_iso_week ON founder_weekly_loom_videos (iso_week DESC);
CREATE INDEX IF NOT EXISTS idx_fwll_videos_audience ON founder_weekly_loom_videos (audience);
CREATE INDEX IF NOT EXISTS idx_fwll_videos_recorded_at ON founder_weekly_loom_videos (recorded_at DESC);

ALTER TABLE founder_weekly_loom_videos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fwll_videos_founder_only ON founder_weekly_loom_videos;
CREATE POLICY fwll_videos_founder_only ON founder_weekly_loom_videos
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

CREATE TABLE IF NOT EXISTS founder_weekly_loom_view_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id uuid NOT NULL REFERENCES founder_weekly_loom_videos(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  viewer_label text NOT NULL,                   -- free text: investor name / team member / hospital code
  viewer_audience text NOT NULL CHECK (viewer_audience IN ('investors','team','hospitals','public','engineers')),
  watch_seconds int,
  completed boolean NOT NULL DEFAULT false,
  source text
);

CREATE INDEX IF NOT EXISTS idx_fwll_views_video ON founder_weekly_loom_view_events (video_id);
CREATE INDEX IF NOT EXISTS idx_fwll_views_when ON founder_weekly_loom_view_events (viewed_at DESC);

ALTER TABLE founder_weekly_loom_view_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS fwll_views_founder_only ON founder_weekly_loom_view_events;
CREATE POLICY fwll_views_founder_only ON founder_weekly_loom_view_events
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- =========================================================================
-- READ RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION fwll_recent_videos_30d()
RETURNS TABLE (
  id uuid,
  iso_week date,
  topic text,
  audience text,
  loom_url text,
  duration_seconds int,
  recorded_at timestamptz,
  view_count bigint,
  unique_viewers bigint,
  completion_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.iso_week, v.topic, v.audience, v.loom_url, v.duration_seconds, v.recorded_at,
    COALESCE(COUNT(e.id),0)::bigint AS view_count,
    COALESCE(COUNT(DISTINCT e.viewer_label),0)::bigint AS unique_viewers,
    CASE WHEN COUNT(e.id) > 0
         THEN ROUND( 100.0 * SUM(CASE WHEN e.completed THEN 1 ELSE 0 END)::numeric / COUNT(e.id)::numeric, 1)
         ELSE 0 END AS completion_rate
  FROM founder_weekly_loom_videos v
  LEFT JOIN founder_weekly_loom_view_events e ON e.video_id = v.id
  WHERE v.recorded_at >= now() - interval '30 days'
  GROUP BY v.id
  ORDER BY v.recorded_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION fwll_recent_videos_30d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fwll_recent_videos_30d() TO authenticated;

CREATE OR REPLACE FUNCTION fwll_audience_breakdown_90d()
RETURNS TABLE (
  audience text,
  video_count bigint,
  total_views bigint,
  avg_views_per_video numeric,
  avg_completion_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.audience,
    COUNT(DISTINCT v.id)::bigint AS video_count,
    COALESCE(COUNT(e.id),0)::bigint AS total_views,
    CASE WHEN COUNT(DISTINCT v.id) > 0
         THEN ROUND(COUNT(e.id)::numeric / COUNT(DISTINCT v.id)::numeric, 1) ELSE 0 END AS avg_views_per_video,
    CASE WHEN COUNT(e.id) > 0
         THEN ROUND(100.0 * SUM(CASE WHEN e.completed THEN 1 ELSE 0 END)::numeric / COUNT(e.id)::numeric, 1)
         ELSE 0 END AS avg_completion_rate
  FROM founder_weekly_loom_videos v
  LEFT JOIN founder_weekly_loom_view_events e ON e.video_id = v.id
  WHERE v.recorded_at >= now() - interval '90 days'
  GROUP BY v.audience
  ORDER BY total_views DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION fwll_audience_breakdown_90d() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fwll_audience_breakdown_90d() TO authenticated;

CREATE OR REPLACE FUNCTION fwll_weekly_cadence_12wk()
RETURNS TABLE (
  iso_week date,
  video_count bigint,
  audiences_covered bigint,
  total_views bigint,
  stale boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(
      date_trunc('week', now() - interval '12 weeks')::date,
      date_trunc('week', now())::date,
      interval '1 week'
    )::date AS wk
  )
  SELECT w.wk AS iso_week,
    COALESCE(COUNT(DISTINCT v.id),0)::bigint AS video_count,
    COALESCE(COUNT(DISTINCT v.audience),0)::bigint AS audiences_covered,
    COALESCE(COUNT(e.id),0)::bigint AS total_views,
    (COUNT(DISTINCT v.id) = 0) AS stale
  FROM weeks w
  LEFT JOIN founder_weekly_loom_videos v ON date_trunc('week', v.recorded_at)::date = w.wk
  LEFT JOIN founder_weekly_loom_view_events e ON e.video_id = v.id
  GROUP BY w.wk
  ORDER BY w.wk DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION fwll_weekly_cadence_12wk() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fwll_weekly_cadence_12wk() TO authenticated;

CREATE OR REPLACE FUNCTION fwll_stale_audience_alerts()
RETURNS TABLE (
  audience text,
  last_video_at timestamptz,
  days_since_last numeric,
  severity text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH all_aud AS (
    SELECT unnest(ARRAY['investors','team','hospitals','public','engineers']) AS audience
  )
  SELECT a.audience,
    MAX(v.recorded_at) AS last_video_at,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(MAX(v.recorded_at), now() - interval '999 days'))) / 86400.0, 1) AS days_since_last,
    CASE
      WHEN MAX(v.recorded_at) IS NULL THEN 'critical'
      WHEN now() - MAX(v.recorded_at) > interval '21 days' THEN 'critical'
      WHEN now() - MAX(v.recorded_at) > interval '14 days' THEN 'warning'
      WHEN now() - MAX(v.recorded_at) > interval '7 days'  THEN 'stale'
      ELSE 'ok'
    END AS severity
  FROM all_aud a
  LEFT JOIN founder_weekly_loom_videos v ON v.audience = a.audience
  GROUP BY a.audience
  ORDER BY days_since_last DESC NULLS FIRST;
END;$$;
REVOKE EXECUTE ON FUNCTION fwll_stale_audience_alerts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fwll_stale_audience_alerts() TO authenticated;

CREATE OR REPLACE FUNCTION fwll_top_videos_by_views(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  topic text,
  audience text,
  recorded_at timestamptz,
  view_count bigint,
  unique_viewers bigint,
  loom_url text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.topic, v.audience, v.recorded_at,
    COALESCE(COUNT(e.id),0)::bigint AS view_count,
    COALESCE(COUNT(DISTINCT e.viewer_label),0)::bigint AS unique_viewers,
    v.loom_url
  FROM founder_weekly_loom_videos v
  LEFT JOIN founder_weekly_loom_view_events e ON e.video_id = v.id
  GROUP BY v.id
  ORDER BY view_count DESC, v.recorded_at DESC
  LIMIT GREATEST(COALESCE(p_limit,20),1);
END;$$;
REVOKE EXECUTE ON FUNCTION fwll_top_videos_by_views(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fwll_top_videos_by_views(int) TO authenticated;

CREATE OR REPLACE FUNCTION fwll_recent_view_events_50()
RETURNS TABLE (
  id uuid,
  video_id uuid,
  topic text,
  viewer_label text,
  viewer_audience text,
  viewed_at timestamptz,
  watch_seconds int,
  completed boolean,
  source text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.video_id, v.topic, e.viewer_label, e.viewer_audience,
         e.viewed_at, e.watch_seconds, e.completed, e.source
  FROM founder_weekly_loom_view_events e
  JOIN founder_weekly_loom_videos v ON v.id = e.video_id
  ORDER BY e.viewed_at DESC
  LIMIT 50;
END;$$;
REVOKE EXECUTE ON FUNCTION fwll_recent_view_events_50() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fwll_recent_view_events_50() TO authenticated;

CREATE OR REPLACE FUNCTION fwll_kpi_snapshot()
RETURNS TABLE (
  total_videos bigint,
  videos_this_week bigint,
  videos_last_week bigint,
  videos_30d bigint,
  videos_90d bigint,
  total_views bigint,
  views_30d bigint,
  unique_viewers_30d bigint,
  avg_duration_seconds numeric,
  avg_completion_rate numeric,
  stale_audience_count bigint,
  last_video_at timestamptz,
  days_since_last_video numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM founder_weekly_loom_videos)::bigint,
    (SELECT COUNT(*) FROM founder_weekly_loom_videos WHERE recorded_at >= date_trunc('week', now()))::bigint,
    (SELECT COUNT(*) FROM founder_weekly_loom_videos
        WHERE recorded_at >= date_trunc('week', now()) - interval '1 week'
          AND recorded_at <  date_trunc('week', now()))::bigint,
    (SELECT COUNT(*) FROM founder_weekly_loom_videos WHERE recorded_at >= now() - interval '30 days')::bigint,
    (SELECT COUNT(*) FROM founder_weekly_loom_videos WHERE recorded_at >= now() - interval '90 days')::bigint,
    (SELECT COUNT(*) FROM founder_weekly_loom_view_events)::bigint,
    (SELECT COUNT(*) FROM founder_weekly_loom_view_events WHERE viewed_at >= now() - interval '30 days')::bigint,
    (SELECT COUNT(DISTINCT viewer_label) FROM founder_weekly_loom_view_events WHERE viewed_at >= now() - interval '30 days')::bigint,
    COALESCE((SELECT ROUND(AVG(duration_seconds)::numeric,1) FROM founder_weekly_loom_videos),0),
    COALESCE((SELECT ROUND(100.0 * SUM(CASE WHEN completed THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*),0), 1)
              FROM founder_weekly_loom_view_events),0),
    (SELECT COUNT(*) FROM fwll_stale_audience_alerts() WHERE severity IN ('warning','critical'))::bigint,
    (SELECT MAX(recorded_at) FROM founder_weekly_loom_videos),
    COALESCE((SELECT ROUND(EXTRACT(EPOCH FROM (now() - MAX(recorded_at))) / 86400.0, 1)
              FROM founder_weekly_loom_videos),0);
END;$$;
REVOKE EXECUTE ON FUNCTION fwll_kpi_snapshot() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION fwll_kpi_snapshot() TO authenticated;

-- =========================================================================
-- WRITE / LOG HELPERS (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION log_founder_loom_video_added(
  p_topic text,
  p_audience text,
  p_loom_url text,
  p_duration_seconds int DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_weekly_loom_videos (iso_week, topic, audience, loom_url, duration_seconds, recorded_by_user_id, notes)
  VALUES (date_trunc('week', now())::date, p_topic, p_audience, p_loom_url, p_duration_seconds, auth.uid(), p_notes)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'fwll_video_added',
          jsonb_build_object('id', v_id, 'topic', p_topic, 'audience', p_audience, 'loom_url', p_loom_url));
  RETURN v_id;
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_loom_video_added(text,text,text,int,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loom_video_added(text,text,text,int,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_loom_view_recorded(
  p_video_id uuid,
  p_viewer_label text,
  p_viewer_audience text,
  p_watch_seconds int DEFAULT NULL,
  p_completed boolean DEFAULT false,
  p_source text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_weekly_loom_view_events (video_id, viewer_label, viewer_audience, watch_seconds, completed, source)
  VALUES (p_video_id, p_viewer_label, p_viewer_audience, p_watch_seconds, p_completed, p_source)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'fwll_view_recorded',
          jsonb_build_object('id', v_id, 'video_id', p_video_id, 'viewer_label', p_viewer_label, 'audience', p_viewer_audience, 'completed', p_completed));
  RETURN v_id;
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_loom_view_recorded(uuid,text,text,int,boolean,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loom_view_recorded(uuid,text,text,int,boolean,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_loom_video_unpublished(
  p_video_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_weekly_loom_videos
     SET is_published = false, updated_at = now()
   WHERE id = p_video_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'fwll_video_unpublished',
          jsonb_build_object('id', p_video_id, 'reason', p_reason));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_loom_video_unpublished(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loom_video_unpublished(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_loom_topic_updated(
  p_video_id uuid,
  p_new_topic text,
  p_new_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_weekly_loom_videos
     SET topic = COALESCE(p_new_topic, topic),
         notes = COALESCE(p_new_notes, notes),
         updated_at = now()
   WHERE id = p_video_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (SELECT email FROM auth.users WHERE id = auth.uid()),
          'fwll_topic_updated',
          jsonb_build_object('id', p_video_id, 'new_topic', p_new_topic, 'new_notes', p_new_notes));
END;$$;
REVOKE EXECUTE ON FUNCTION log_founder_loom_topic_updated(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_loom_topic_updated(uuid,text,text) TO authenticated;

COMMIT;