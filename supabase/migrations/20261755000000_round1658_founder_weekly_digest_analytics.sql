BEGIN;

-- =====================================================================
-- r1658: Founder weekly digest analytics
-- Tracks open/click/reply on weekly digest emails; per-recipient score.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: digest_send_log — one row per (digest_id, recipient_email)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.digest_send_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  digest_id text NOT NULL,
  digest_week_start date NOT NULL,
  recipient_email text NOT NULL,
  recipient_role text,
  sent_at timestamptz NOT NULL DEFAULT now(),
  opened_at timestamptz,
  open_count int NOT NULL DEFAULT 0,
  click_count int NOT NULL DEFAULT 0,
  first_clicked_at timestamptz,
  replied_at timestamptz,
  reply_category text CHECK (reply_category IN ('positive','question','complaint','unsubscribe','other')),
  bounce_flag boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_digest_send_log_week ON public.digest_send_log(digest_week_start DESC);
CREATE INDEX IF NOT EXISTS idx_digest_send_log_recipient ON public.digest_send_log(recipient_email);
CREATE INDEX IF NOT EXISTS idx_digest_send_log_digest ON public.digest_send_log(digest_id);

ALTER TABLE public.digest_send_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS digest_send_log_founder_only ON public.digest_send_log;
CREATE POLICY digest_send_log_founder_only ON public.digest_send_log
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- Table 2: digest_engagement_events — raw event stream (open/click/reply)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.digest_engagement_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  digest_id text NOT NULL,
  recipient_email text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('open','click','reply','bounce')),
  event_at timestamptz NOT NULL DEFAULT now(),
  link_url text,
  user_agent text,
  reply_excerpt text,
  reply_category text CHECK (reply_category IN ('positive','question','complaint','unsubscribe','other')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_digest_eng_events_digest ON public.digest_engagement_events(digest_id);
CREATE INDEX IF NOT EXISTS idx_digest_eng_events_recipient ON public.digest_engagement_events(recipient_email);
CREATE INDEX IF NOT EXISTS idx_digest_eng_events_when ON public.digest_engagement_events(event_at DESC);

ALTER TABLE public.digest_engagement_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS digest_eng_events_founder_only ON public.digest_engagement_events;
CREATE POLICY digest_eng_events_founder_only ON public.digest_engagement_events
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: founder_digest_weekly_trend — 12-week open/click/reply trend
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_digest_weekly_trend();
CREATE OR REPLACE FUNCTION public.founder_digest_weekly_trend()
RETURNS TABLE (
  week_start date,
  sent int,
  opened int,
  clicked int,
  replied int,
  open_rate_pct numeric,
  click_rate_pct numeric,
  reply_rate_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.digest_week_start AS week_start,
    COUNT(*)::int AS sent,
    (COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL))::int AS opened,
    (COUNT(*) FILTER (WHERE d.click_count > 0))::int AS clicked,
    (COUNT(*) FILTER (WHERE d.replied_at IS NOT NULL))::int AS replied,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL))::numeric / NULLIF(COUNT(*),0), 1) AS open_rate_pct,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE d.click_count > 0))::numeric / NULLIF(COUNT(*),0), 1) AS click_rate_pct,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE d.replied_at IS NOT NULL))::numeric / NULLIF(COUNT(*),0), 1) AS reply_rate_pct
  FROM public.digest_send_log d
  WHERE d.digest_week_start >= (now() - interval '12 weeks')::date
  GROUP BY d.digest_week_start
  ORDER BY d.digest_week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_digest_weekly_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_digest_weekly_trend() TO authenticated;

-- =====================================================================
-- RPC 2: founder_digest_latest_digest_summary — last digest snapshot
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_digest_latest_digest_summary();
CREATE OR REPLACE FUNCTION public.founder_digest_latest_digest_summary()
RETURNS TABLE (
  digest_id text,
  week_start date,
  sent int,
  opened int,
  clicked int,
  replied int,
  bounced int,
  open_rate_pct numeric,
  click_through_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT d.digest_id
    FROM public.digest_send_log d
    ORDER BY d.digest_week_start DESC, d.sent_at DESC
    LIMIT 1
  )
  SELECT
    d.digest_id,
    d.digest_week_start AS week_start,
    COUNT(*)::int AS sent,
    (COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL))::int AS opened,
    (COUNT(*) FILTER (WHERE d.click_count > 0))::int AS clicked,
    (COUNT(*) FILTER (WHERE d.replied_at IS NOT NULL))::int AS replied,
    (COUNT(*) FILTER (WHERE d.bounce_flag))::int AS bounced,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL))::numeric / NULLIF(COUNT(*),0), 1) AS open_rate_pct,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE d.click_count > 0))::numeric
      / NULLIF(COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL), 0), 1) AS click_through_pct
  FROM public.digest_send_log d
  JOIN latest l ON l.digest_id = d.digest_id
  GROUP BY d.digest_id, d.digest_week_start;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_digest_latest_digest_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_digest_latest_digest_summary() TO authenticated;

-- =====================================================================
-- RPC 3: founder_digest_reply_categorization — breakdown of reply types
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_digest_reply_categorization();
CREATE OR REPLACE FUNCTION public.founder_digest_reply_categorization()
RETURNS TABLE (
  reply_category text,
  reply_count int,
  pct_of_replies numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT COALESCE(d.reply_category,'other') AS cat
    FROM public.digest_send_log d
    WHERE d.replied_at IS NOT NULL
      AND d.digest_week_start >= (now() - interval '12 weeks')::date
  ),
  total AS (SELECT COUNT(*) AS n FROM base)
  SELECT
    b.cat AS reply_category,
    COUNT(*)::int AS reply_count,
    ROUND(100.0 * COUNT(*)::numeric / NULLIF((SELECT n FROM total),0), 1) AS pct_of_replies
  FROM base b
  GROUP BY b.cat
  ORDER BY reply_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_digest_reply_categorization() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_digest_reply_categorization() TO authenticated;

-- =====================================================================
-- RPC 4: founder_digest_recipient_engagement — per-recipient score
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_digest_recipient_engagement();
CREATE OR REPLACE FUNCTION public.founder_digest_recipient_engagement()
RETURNS TABLE (
  recipient_email text,
  recipient_role text,
  digests_received int,
  digests_opened int,
  digests_clicked int,
  digests_replied int,
  engagement_score int,
  last_opened_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.recipient_email,
    MAX(d.recipient_role) AS recipient_role,
    COUNT(*)::int AS digests_received,
    (COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL))::int AS digests_opened,
    (COUNT(*) FILTER (WHERE d.click_count > 0))::int AS digests_clicked,
    (COUNT(*) FILTER (WHERE d.replied_at IS NOT NULL))::int AS digests_replied,
    LEAST(100, (
      (COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL))::int * 4 +
      (COUNT(*) FILTER (WHERE d.click_count > 0))::int * 8 +
      (COUNT(*) FILTER (WHERE d.replied_at IS NOT NULL))::int * 16
    ))::int AS engagement_score,
    MAX(d.opened_at) AS last_opened_at
  FROM public.digest_send_log d
  WHERE d.digest_week_start >= (now() - interval '12 weeks')::date
  GROUP BY d.recipient_email
  ORDER BY engagement_score DESC, digests_received DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_digest_recipient_engagement() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_digest_recipient_engagement() TO authenticated;

-- =====================================================================
-- RPC 5: founder_digest_top_clicked_links — which links drive engagement
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_digest_top_clicked_links();
CREATE OR REPLACE FUNCTION public.founder_digest_top_clicked_links()
RETURNS TABLE (
  link_url text,
  click_count int,
  unique_clickers int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.link_url,
    COUNT(*)::int AS click_count,
    COUNT(DISTINCT e.recipient_email)::int AS unique_clickers
  FROM public.digest_engagement_events e
  WHERE e.event_type = 'click'
    AND e.link_url IS NOT NULL
    AND e.event_at >= now() - interval '12 weeks'
  GROUP BY e.link_url
  ORDER BY click_count DESC
  LIMIT 25;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_digest_top_clicked_links() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_digest_top_clicked_links() TO authenticated;

-- =====================================================================
-- RPC 6: founder_digest_dormant_recipients — never opened in 4 wks
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_digest_dormant_recipients();
CREATE OR REPLACE FUNCTION public.founder_digest_dormant_recipients()
RETURNS TABLE (
  recipient_email text,
  recipient_role text,
  digests_received int,
  last_opened_at timestamptz,
  weeks_since_open int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.recipient_email,
    MAX(d.recipient_role) AS recipient_role,
    COUNT(*)::int AS digests_received,
    MAX(d.opened_at) AS last_opened_at,
    CASE
      WHEN MAX(d.opened_at) IS NULL THEN 99
      ELSE EXTRACT(epoch FROM (now() - MAX(d.opened_at)))::int / (7*86400)
    END::int AS weeks_since_open
  FROM public.digest_send_log d
  WHERE d.digest_week_start >= (now() - interval '8 weeks')::date
  GROUP BY d.recipient_email
  HAVING COUNT(*) FILTER (WHERE d.opened_at IS NOT NULL AND d.opened_at >= now() - interval '4 weeks') = 0
  ORDER BY digests_received DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_digest_dormant_recipients() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_digest_dormant_recipients() TO authenticated;

-- =====================================================================
-- RPC 7: founder_digest_recent_replies — last 30 replies feed
-- =====================================================================
DROP FUNCTION IF EXISTS public.founder_digest_recent_replies();
CREATE OR REPLACE FUNCTION public.founder_digest_recent_replies()
RETURNS TABLE (
  event_at timestamptz,
  recipient_email text,
  reply_category text,
  reply_excerpt text,
  digest_id text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.event_at,
    e.recipient_email,
    COALESCE(e.reply_category,'other') AS reply_category,
    LEFT(COALESCE(e.reply_excerpt,''), 180) AS reply_excerpt,
    e.digest_id
  FROM public.digest_engagement_events e
  WHERE e.event_type = 'reply'
  ORDER BY e.event_at DESC
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_digest_recent_replies() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_digest_recent_replies() TO authenticated;

-- =====================================================================
-- WRITE helper: log_founder_digest_reply_categorize (VOLATILE)
-- =====================================================================
DROP FUNCTION IF EXISTS public.log_founder_digest_reply_categorize(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_digest_reply_categorize(
  p_event_id uuid,
  p_category text
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_category NOT IN ('positive','question','complaint','unsubscribe','other') THEN
    RAISE EXCEPTION 'invalid reply_category';
  END IF;

  UPDATE public.digest_engagement_events
  SET reply_category = p_category
  WHERE id = p_event_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'founder_digest_reply_categorize',
    jsonb_build_object('event_id', p_event_id, 'category', p_category),
    now()
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_digest_reply_categorize(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_digest_reply_categorize(uuid, text) TO authenticated;

COMMIT;