BEGIN;
-- r1443 HEAVY ★★★★ — Founder marketing content calendar.
--
-- Centralizes planning + execution + measurement for blog + social + email + PR.
-- Founder sees: what's planned, what shipped, what shipped well, who owns each
-- piece, and which pieces actually moved leads.
--
-- 2 tables:
--   founder_marketing_content_pieces                — calendar row per piece
--   founder_marketing_content_engagement_metrics    — append-only metric snapshots
--
-- 7 RPCs:
--   founder_marketing_content_calendar_summary    — 16 KPIs
--   founder_marketing_content_pieces_recent       — 40 most recent pieces
--   founder_marketing_content_engagement_recent   — 60 most recent metric snapshots
--   founder_marketing_content_upcoming            — next 14 days banner
--   log_founder_content_register_piece            — create calendar row
--   log_founder_content_record_engagement         — append metric snapshot
--   log_founder_content_status                    — move status forward

-- ============================================================================
-- 1. TABLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_marketing_content_pieces (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  piece_label           text NOT NULL UNIQUE,
  channel               text NOT NULL CHECK (channel IN (
    'blog','linkedin_post','twitter_post','email_newsletter','press_release',
    'podcast_episode','youtube_video','case_study','whitepaper','webinar'
  )),
  topic_category        text NOT NULL CHECK (topic_category IN (
    'product_announcement','customer_story','industry_insight','founder_story',
    'engineering_deepdive','market_intel','hiring','milestone'
  )),
  planned_publish_date  date NOT NULL,
  status                text NOT NULL DEFAULT 'idea' CHECK (status IN (
    'idea','draft','review','scheduled','published','retired'
  )),
  published_at          timestamptz,
  published_url         text,
  target_audience       text,
  author_user_id        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  expected_reach_count  int NOT NULL DEFAULT 0 CHECK (expected_reach_count >= 0),
  actual_reach_count    int NOT NULL DEFAULT 0 CHECK (actual_reach_count >= 0),
  leads_generated       int NOT NULL DEFAULT 0 CHECK (leads_generated >= 0),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_mkt_content_status
  ON public.founder_marketing_content_pieces (status, planned_publish_date);
CREATE INDEX IF NOT EXISTS idx_founder_mkt_content_channel
  ON public.founder_marketing_content_pieces (channel, planned_publish_date DESC);
CREATE INDEX IF NOT EXISTS idx_founder_mkt_content_planned
  ON public.founder_marketing_content_pieces (planned_publish_date)
  WHERE status NOT IN ('published','retired');
CREATE INDEX IF NOT EXISTS idx_founder_mkt_content_author
  ON public.founder_marketing_content_pieces (author_user_id, planned_publish_date DESC);

ALTER TABLE public.founder_marketing_content_pieces ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_mkt_content_pieces ON public.founder_marketing_content_pieces;
CREATE POLICY founder_only_mkt_content_pieces
  ON public.founder_marketing_content_pieces
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_marketing_content_engagement_metrics (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  piece_id            uuid NOT NULL REFERENCES public.founder_marketing_content_pieces(id) ON DELETE CASCADE,
  snapshot_at         timestamptz NOT NULL DEFAULT now(),
  views               int NOT NULL DEFAULT 0 CHECK (views >= 0),
  likes               int NOT NULL DEFAULT 0 CHECK (likes >= 0),
  shares              int NOT NULL DEFAULT 0 CHECK (shares >= 0),
  comments            int NOT NULL DEFAULT 0 CHECK (comments >= 0),
  link_clicks         int NOT NULL DEFAULT 0 CHECK (link_clicks >= 0),
  leads_attributed    int NOT NULL DEFAULT 0 CHECK (leads_attributed >= 0),
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_mkt_engagement_piece
  ON public.founder_marketing_content_engagement_metrics (piece_id, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_mkt_engagement_snapshot
  ON public.founder_marketing_content_engagement_metrics (snapshot_at DESC);

ALTER TABLE public.founder_marketing_content_engagement_metrics ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_mkt_engagement ON public.founder_marketing_content_engagement_metrics;
CREATE POLICY founder_only_mkt_engagement
  ON public.founder_marketing_content_engagement_metrics
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- 2. SUMMARY — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_marketing_content_calendar_summary();
CREATE OR REPLACE FUNCTION public.founder_marketing_content_calendar_summary()
RETURNS TABLE (
  total_pieces            int,
  idea_count              int,
  draft_count             int,
  review_count            int,
  scheduled_count         int,
  published_count         int,
  retired_count           int,
  upcoming_14d_count      int,
  overdue_count           int,
  published_last_30d      int,
  total_expected_reach    bigint,
  total_actual_reach      bigint,
  total_leads_generated   bigint,
  avg_actual_reach        numeric,
  reach_attainment_pct    numeric,
  top_channel_label       text,
  generated_at            timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int;
  v_idea int;
  v_draft int;
  v_review int;
  v_scheduled int;
  v_pub int;
  v_retired int;
  v_upcoming int;
  v_overdue int;
  v_pub30 int;
  v_exp_reach bigint;
  v_act_reach bigint;
  v_leads bigint;
  v_avg_reach numeric;
  v_attain numeric;
  v_top_channel text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT count(*)::int,
         count(*) FILTER (WHERE status = 'idea')::int,
         count(*) FILTER (WHERE status = 'draft')::int,
         count(*) FILTER (WHERE status = 'review')::int,
         count(*) FILTER (WHERE status = 'scheduled')::int,
         count(*) FILTER (WHERE status = 'published')::int,
         count(*) FILTER (WHERE status = 'retired')::int,
         count(*) FILTER (
           WHERE status NOT IN ('published','retired')
             AND planned_publish_date BETWEEN current_date AND (current_date + INTERVAL '14 days')::date
         )::int,
         count(*) FILTER (
           WHERE status NOT IN ('published','retired')
             AND planned_publish_date < current_date
         )::int,
         count(*) FILTER (
           WHERE status = 'published'
             AND published_at >= (now() - INTERVAL '30 days')
         )::int,
         coalesce(sum(expected_reach_count), 0)::bigint,
         coalesce(sum(actual_reach_count), 0)::bigint,
         coalesce(sum(leads_generated), 0)::bigint
    INTO v_total, v_idea, v_draft, v_review, v_scheduled, v_pub, v_retired,
         v_upcoming, v_overdue, v_pub30, v_exp_reach, v_act_reach, v_leads
    FROM public.founder_marketing_content_pieces;

  SELECT round(avg(actual_reach_count)::numeric, 1)
    INTO v_avg_reach
    FROM public.founder_marketing_content_pieces
   WHERE status = 'published' AND actual_reach_count > 0;

  IF coalesce(v_exp_reach, 0) > 0 THEN
    v_attain := round((coalesce(v_act_reach, 0)::numeric / v_exp_reach::numeric) * 100.0, 1);
  ELSE
    v_attain := 0;
  END IF;

  SELECT channel
    INTO v_top_channel
    FROM public.founder_marketing_content_pieces
   WHERE status = 'published'
   GROUP BY channel
   ORDER BY count(*) DESC, channel
   LIMIT 1;

  RETURN QUERY SELECT
    coalesce(v_total, 0),
    coalesce(v_idea, 0),
    coalesce(v_draft, 0),
    coalesce(v_review, 0),
    coalesce(v_scheduled, 0),
    coalesce(v_pub, 0),
    coalesce(v_retired, 0),
    coalesce(v_upcoming, 0),
    coalesce(v_overdue, 0),
    coalesce(v_pub30, 0),
    coalesce(v_exp_reach, 0::bigint),
    coalesce(v_act_reach, 0::bigint),
    coalesce(v_leads, 0::bigint),
    coalesce(v_avg_reach, 0),
    coalesce(v_attain, 0),
    coalesce(v_top_channel, '—'::text),
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_content_calendar_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_marketing_content_calendar_summary() TO authenticated;

-- ============================================================================
-- 3. RECENT PIECES (40)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_marketing_content_pieces_recent();
CREATE OR REPLACE FUNCTION public.founder_marketing_content_pieces_recent()
RETURNS TABLE (
  id                    uuid,
  piece_label           text,
  channel               text,
  topic_category        text,
  status                text,
  planned_publish_date  date,
  published_at          timestamptz,
  published_url         text,
  target_audience       text,
  author_label          text,
  expected_reach_count  int,
  actual_reach_count    int,
  leads_generated       int,
  is_overdue            boolean,
  created_at            timestamptz,
  updated_at            timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id,
         p.piece_label,
         p.channel,
         p.topic_category,
         p.status,
         p.planned_publish_date,
         p.published_at,
         p.published_url,
         p.target_audience,
         coalesce(prof.full_name, 'unassigned'::text) AS author_label,
         p.expected_reach_count,
         p.actual_reach_count,
         p.leads_generated,
         (p.status NOT IN ('published','retired')
          AND p.planned_publish_date < current_date) AS is_overdue,
         p.created_at,
         p.updated_at
    FROM public.founder_marketing_content_pieces p
    LEFT JOIN public.profiles prof ON prof.user_id = p.author_user_id
   ORDER BY
     CASE p.status
       WHEN 'retired' THEN 9
       WHEN 'published' THEN 8
       ELSE 0
     END,
     p.planned_publish_date ASC,
     p.updated_at DESC
   LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_content_pieces_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_marketing_content_pieces_recent() TO authenticated;

-- ============================================================================
-- 4. RECENT ENGAGEMENT (60)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_marketing_content_engagement_recent();
CREATE OR REPLACE FUNCTION public.founder_marketing_content_engagement_recent()
RETURNS TABLE (
  id                  uuid,
  piece_id            uuid,
  piece_label         text,
  channel             text,
  snapshot_at         timestamptz,
  views               int,
  likes               int,
  shares              int,
  comments            int,
  link_clicks         int,
  leads_attributed    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT m.id,
         m.piece_id,
         p.piece_label,
         p.channel,
         m.snapshot_at,
         m.views,
         m.likes,
         m.shares,
         m.comments,
         m.link_clicks,
         m.leads_attributed
    FROM public.founder_marketing_content_engagement_metrics m
    JOIN public.founder_marketing_content_pieces p ON p.id = m.piece_id
   ORDER BY m.snapshot_at DESC
   LIMIT 60;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_content_engagement_recent() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_marketing_content_engagement_recent() TO authenticated;

-- ============================================================================
-- 5. UPCOMING (14d horizon)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_marketing_content_upcoming();
CREATE OR REPLACE FUNCTION public.founder_marketing_content_upcoming()
RETURNS TABLE (
  id                    uuid,
  piece_label           text,
  channel               text,
  topic_category        text,
  status                text,
  planned_publish_date  date,
  days_until            int,
  is_overdue            boolean,
  author_label          text,
  expected_reach_count  int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT p.id,
         p.piece_label,
         p.channel,
         p.topic_category,
         p.status,
         p.planned_publish_date,
         (p.planned_publish_date - current_date)::int AS days_until,
         (p.planned_publish_date < current_date) AS is_overdue,
         coalesce(prof.full_name, 'unassigned'::text) AS author_label,
         p.expected_reach_count
    FROM public.founder_marketing_content_pieces p
    LEFT JOIN public.profiles prof ON prof.user_id = p.author_user_id
   WHERE p.status NOT IN ('published','retired')
     AND p.planned_publish_date <= (current_date + INTERVAL '14 days')::date
   ORDER BY p.planned_publish_date ASC, p.updated_at DESC
   LIMIT 40;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_marketing_content_upcoming() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_marketing_content_upcoming() TO authenticated;

-- ============================================================================
-- 6. REGISTER PIECE
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_content_register_piece(text, text, text, date, text, uuid, int);
CREATE OR REPLACE FUNCTION public.log_founder_content_register_piece(
  p_piece_label          text,
  p_channel              text,
  p_topic_category       text,
  p_planned_publish_date date,
  p_target_audience      text DEFAULT NULL,
  p_author_user_id       uuid DEFAULT NULL,
  p_expected_reach       int  DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_marketing_content_pieces (
    piece_label, channel, topic_category, planned_publish_date,
    target_audience, author_user_id, expected_reach_count, status
  ) VALUES (
    p_piece_label, p_channel, p_topic_category, p_planned_publish_date,
    p_target_audience, p_author_user_id, coalesce(p_expected_reach, 0), 'idea'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_content_register_piece(text, text, text, date, text, uuid, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_content_register_piece(text, text, text, date, text, uuid, int) TO authenticated;

-- ============================================================================
-- 7. RECORD ENGAGEMENT
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_content_record_engagement(uuid, int, int, int, int, int, int);
CREATE OR REPLACE FUNCTION public.log_founder_content_record_engagement(
  p_piece_id          uuid,
  p_views             int DEFAULT 0,
  p_likes             int DEFAULT 0,
  p_shares            int DEFAULT 0,
  p_comments          int DEFAULT 0,
  p_link_clicks       int DEFAULT 0,
  p_leads_attributed  int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.founder_marketing_content_pieces WHERE id = p_piece_id) THEN
    RAISE EXCEPTION 'piece not found' USING ERRCODE='P0002';
  END IF;
  INSERT INTO public.founder_marketing_content_engagement_metrics (
    piece_id, views, likes, shares, comments, link_clicks, leads_attributed
  ) VALUES (
    p_piece_id,
    coalesce(p_views, 0),
    coalesce(p_likes, 0),
    coalesce(p_shares, 0),
    coalesce(p_comments, 0),
    coalesce(p_link_clicks, 0),
    coalesce(p_leads_attributed, 0)
  )
  RETURNING id INTO v_id;

  -- Roll cumulative reach + leads onto the parent piece for fast summary.
  UPDATE public.founder_marketing_content_pieces
     SET actual_reach_count = actual_reach_count + coalesce(p_views, 0),
         leads_generated    = leads_generated + coalesce(p_leads_attributed, 0),
         updated_at         = now()
   WHERE id = p_piece_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_content_record_engagement(uuid, int, int, int, int, int, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_content_record_engagement(uuid, int, int, int, int, int, int) TO authenticated;

-- ============================================================================
-- 8. STATUS TRANSITION
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_content_status(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_content_status(
  p_piece_id      uuid,
  p_new_status    text,
  p_published_url text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_new_status NOT IN ('idea','draft','review','scheduled','published','retired') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE='22023';
  END IF;
  UPDATE public.founder_marketing_content_pieces
     SET status        = p_new_status,
         published_at  = CASE WHEN p_new_status = 'published' AND published_at IS NULL THEN now() ELSE published_at END,
         published_url = coalesce(p_published_url, published_url),
         updated_at    = now()
   WHERE id = p_piece_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'piece not found' USING ERRCODE='P0002';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_content_status(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_content_status(uuid, text, text) TO authenticated;

COMMIT;