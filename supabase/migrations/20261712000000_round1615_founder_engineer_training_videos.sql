BEGIN;

-- ============================================================================
-- r1615 — Founder Engineer Training Video Library
-- Central library of training videos curated by founder + masters
-- Per-video view count + completion rate + founder review queue
-- ============================================================================

-- Library of videos
CREATE TABLE IF NOT EXISTS founder_training_videos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  video_url text NOT NULL,
  thumbnail_url text,
  duration_seconds int NOT NULL DEFAULT 0,
  category text NOT NULL DEFAULT 'general',
  difficulty text NOT NULL DEFAULT 'beginner' CHECK (difficulty IN ('beginner','intermediate','advanced','master')),
  curated_by_user_id uuid REFERENCES auth.users(id),
  status text NOT NULL DEFAULT 'pending_review' CHECK (status IN ('pending_review','approved','rejected','archived')),
  reviewed_by_user_id uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  review_notes text,
  required_for_tier text CHECK (required_for_tier IN ('none','aadhaar','pan','gst','bgc','pro')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ftv_status ON founder_training_videos(status);
CREATE INDEX IF NOT EXISTS idx_ftv_category ON founder_training_videos(category);
CREATE INDEX IF NOT EXISTS idx_ftv_created ON founder_training_videos(created_at DESC);

ALTER TABLE founder_training_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ftv_founder_only ON founder_training_videos;
CREATE POLICY ftv_founder_only ON founder_training_videos
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- View / completion events per engineer per video
CREATE TABLE IF NOT EXISTS founder_training_video_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id uuid NOT NULL REFERENCES founder_training_videos(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id),
  watched_seconds int NOT NULL DEFAULT 0,
  completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  last_viewed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ftvv_video ON founder_training_video_views(video_id);
CREATE INDEX IF NOT EXISTS idx_ftvv_eng ON founder_training_video_views(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ftvv_completed ON founder_training_video_views(completed) WHERE completed = true;

ALTER TABLE founder_training_video_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ftvv_founder_only ON founder_training_video_views;
CREATE POLICY ftvv_founder_only ON founder_training_video_views
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ============================================================================
-- Helpers: log_founder_*
-- ============================================================================

CREATE OR REPLACE FUNCTION log_founder_video_approved(p_video_id uuid, p_notes text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'training_video_approved',
    jsonb_build_object('video_id', p_video_id, 'notes', p_notes), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_video_approved(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_video_approved(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_video_rejected(p_video_id uuid, p_notes text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'training_video_rejected',
    jsonb_build_object('video_id', p_video_id, 'notes', p_notes), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_video_rejected(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_video_rejected(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_video_archived(p_video_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'training_video_archived',
    jsonb_build_object('video_id', p_video_id), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_video_archived(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_video_archived(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_video_curated(p_video_id uuid, p_title text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'training_video_curated',
    jsonb_build_object('video_id', p_video_id, 'title', p_title), now());
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_video_curated(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_video_curated(uuid, text) TO authenticated;

-- ============================================================================
-- READ RPCs (STABLE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_training_video_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH v AS (
    SELECT
      count(*) FILTER (WHERE status='approved') AS approved_videos,
      count(*) FILTER (WHERE status='pending_review') AS pending_videos,
      count(*) FILTER (WHERE status='rejected') AS rejected_videos,
      count(*) FILTER (WHERE status='archived') AS archived_videos,
      count(*) AS total_videos,
      count(*) FILTER (WHERE status='approved' AND difficulty='beginner') AS beginner_videos,
      count(*) FILTER (WHERE status='approved' AND difficulty='intermediate') AS intermediate_videos,
      count(*) FILTER (WHERE status='approved' AND difficulty='advanced') AS advanced_videos,
      count(*) FILTER (WHERE status='approved' AND difficulty='master') AS master_videos,
      coalesce(sum(duration_seconds) FILTER (WHERE status='approved'),0) AS total_seconds_approved
    FROM founder_training_videos
  ),
  vw AS (
    SELECT
      count(*) AS total_views,
      count(*) FILTER (WHERE completed) AS total_completions,
      count(DISTINCT engineer_user_id) AS unique_engineers,
      count(DISTINCT video_id) AS videos_watched,
      count(*) FILTER (WHERE last_viewed_at > now() - interval '7 days') AS views_7d,
      count(*) FILTER (WHERE completed AND completed_at > now() - interval '7 days') AS completions_7d
    FROM founder_training_video_views
  )
  SELECT jsonb_build_object(
    'approved_videos', v.approved_videos,
    'pending_videos', v.pending_videos,
    'rejected_videos', v.rejected_videos,
    'archived_videos', v.archived_videos,
    'total_videos', v.total_videos,
    'beginner_videos', v.beginner_videos,
    'intermediate_videos', v.intermediate_videos,
    'advanced_videos', v.advanced_videos,
    'master_videos', v.master_videos,
    'total_minutes_approved', round(v.total_seconds_approved/60.0)::int,
    'total_views', vw.total_views,
    'total_completions', vw.total_completions,
    'unique_engineers', vw.unique_engineers,
    'videos_watched', vw.videos_watched,
    'views_7d', vw.views_7d,
    'completions_7d', vw.completions_7d,
    'completion_rate_pct', CASE WHEN vw.total_views > 0 THEN round((vw.total_completions::numeric/vw.total_views)*100,1) ELSE 0 END
  ) INTO r FROM v, vw;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION founder_training_video_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_video_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_video_review_queue()
RETURNS TABLE(id uuid, title text, category text, difficulty text, duration_seconds int, curated_by text, created_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.title, v.category, v.difficulty, v.duration_seconds,
    coalesce(p.full_name, p.email, 'unknown'),
    v.created_at
  FROM founder_training_videos v
  LEFT JOIN profiles p ON p.id = v.curated_by_user_id
  WHERE v.status = 'pending_review'
  ORDER BY v.created_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_training_video_review_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_video_review_queue() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_video_top_watched()
RETURNS TABLE(id uuid, title text, category text, difficulty text, view_count bigint, completion_count bigint, completion_rate_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH stats AS (
    SELECT video_id,
      count(*) AS vc,
      count(*) FILTER (WHERE completed) AS cc
    FROM founder_training_video_views
    GROUP BY video_id
  )
  SELECT v.id, v.title, v.category, v.difficulty,
    coalesce(s.vc,0), coalesce(s.cc,0),
    CASE WHEN coalesce(s.vc,0) > 0 THEN round((s.cc::numeric/s.vc)*100,1) ELSE 0 END
  FROM founder_training_videos v
  LEFT JOIN stats s ON s.video_id = v.id
  WHERE v.status = 'approved'
  ORDER BY coalesce(s.vc,0) DESC, v.created_at DESC
  LIMIT 50;
END $$;
REVOKE EXECUTE ON FUNCTION founder_training_video_top_watched() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_video_top_watched() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_video_engineer_progress()
RETURNS TABLE(engineer_user_id uuid, engineer_name text, videos_watched bigint, videos_completed bigint, total_seconds bigint, last_viewed_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT vw.engineer_user_id AS eu,
      count(DISTINCT vw.video_id) AS vw_count,
      count(DISTINCT vw.video_id) FILTER (WHERE vw.completed) AS cmp_count,
      sum(vw.watched_seconds) AS total_s,
      max(vw.last_viewed_at) AS last_v
    FROM founder_training_video_views vw
    GROUP BY vw.engineer_user_id
  )
  SELECT a.eu,
    coalesce(p.full_name, p.email, 'engineer'),
    a.vw_count, a.cmp_count, coalesce(a.total_s,0), a.last_v
  FROM agg a
  LEFT JOIN profiles p ON p.id = a.eu
  ORDER BY a.cmp_count DESC NULLS LAST, a.vw_count DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_training_video_engineer_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_video_engineer_progress() TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_video_category_breakdown()
RETURNS TABLE(category text, video_count bigint, total_views bigint, total_completions bigint, completion_rate_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH cats AS (
    SELECT v.category AS cat, count(*) AS vc
    FROM founder_training_videos v
    WHERE v.status='approved'
    GROUP BY v.category
  ),
  views AS (
    SELECT v.category AS cat,
      count(vw.*) AS views_c,
      count(vw.*) FILTER (WHERE vw.completed) AS cmp_c
    FROM founder_training_videos v
    JOIN founder_training_video_views vw ON vw.video_id = v.id
    WHERE v.status='approved'
    GROUP BY v.category
  )
  SELECT c.cat, c.vc,
    coalesce(vws.views_c,0), coalesce(vws.cmp_c,0),
    CASE WHEN coalesce(vws.views_c,0) > 0 THEN round((vws.cmp_c::numeric/vws.views_c)*100,1) ELSE 0 END
  FROM cats c
  LEFT JOIN views vws ON vws.cat = c.cat
  ORDER BY c.vc DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_training_video_category_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_video_category_breakdown() TO authenticated;

-- ============================================================================
-- WRITE RPCs (VOLATILE)
-- ============================================================================

CREATE OR REPLACE FUNCTION founder_training_video_approve(p_video_id uuid, p_notes text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_training_videos
     SET status='approved',
         reviewed_by_user_id=auth.uid(),
         reviewed_at=now(),
         review_notes=p_notes,
         updated_at=now()
   WHERE id=p_video_id;
  PERFORM log_founder_video_approved(p_video_id, p_notes);
END $$;
REVOKE EXECUTE ON FUNCTION founder_training_video_approve(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_video_approve(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_training_video_reject(p_video_id uuid, p_notes text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_training_videos
     SET status='rejected',
         reviewed_by_user_id=auth.uid(),
         reviewed_at=now(),
         review_notes=p_notes,
         updated_at=now()
   WHERE id=p_video_id;
  PERFORM log_founder_video_rejected(p_video_id, p_notes);
END $$;
REVOKE EXECUTE ON FUNCTION founder_training_video_reject(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_training_video_reject(uuid, text) TO authenticated;

COMMIT;