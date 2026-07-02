BEGIN;

CREATE TABLE IF NOT EXISTS public.weekly_inbox_zero_emails_r2389 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  category text NOT NULL CHECK (category IN ('investor','customer','hiring','vendor','legal','press','team','other')),
  sender_email text NOT NULL,
  sender_name text,
  subject text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  replied_at timestamptz,
  deferred_until date,
  status text NOT NULL DEFAULT 'unread' CHECK (status IN ('unread','read','replied','deferred','archived')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('urgent','high','normal','low')),
  reply_latency_minutes int,
  needs_action boolean NOT NULL DEFAULT false,
  thread_id text,
  founder_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wiz_emails_r2389_week ON public.weekly_inbox_zero_emails_r2389(week_start DESC);
CREATE INDEX IF NOT EXISTS idx_wiz_emails_r2389_status ON public.weekly_inbox_zero_emails_r2389(status, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_wiz_emails_r2389_cat ON public.weekly_inbox_zero_emails_r2389(category);

ALTER TABLE public.weekly_inbox_zero_emails_r2389 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.weekly_inbox_zero_emails_r2389;
CREATE POLICY founder_all ON public.weekly_inbox_zero_emails_r2389
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.weekly_inbox_zero_snapshots_r2389 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  received_count int NOT NULL DEFAULT 0,
  replied_count int NOT NULL DEFAULT 0,
  deferred_count int NOT NULL DEFAULT 0,
  unread_count int NOT NULL DEFAULT 0,
  archived_count int NOT NULL DEFAULT 0,
  oldest_unread_hours numeric(10,2) DEFAULT 0,
  avg_reply_latency_minutes numeric(10,2) DEFAULT 0,
  inbox_zero_achieved boolean NOT NULL DEFAULT false,
  founder_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (week_start)
);

CREATE INDEX IF NOT EXISTS idx_wiz_snap_r2389_week ON public.weekly_inbox_zero_snapshots_r2389(week_start DESC);

ALTER TABLE public.weekly_inbox_zero_snapshots_r2389 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.weekly_inbox_zero_snapshots_r2389;
CREATE POLICY founder_all ON public.weekly_inbox_zero_snapshots_r2389
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: weekly summary
DROP FUNCTION IF EXISTS public.wiz_r2389_weekly_summary();
CREATE OR REPLACE FUNCTION public.wiz_r2389_weekly_summary()
RETURNS TABLE (
  week_start date,
  received_count int,
  replied_count int,
  deferred_count int,
  unread_count int,
  reply_rate_pct numeric,
  oldest_unread_hours numeric,
  avg_reply_latency_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.week_start,
    COUNT(*)::int AS received_count,
    COUNT(*) FILTER (WHERE e.status = 'replied')::int AS replied_count,
    COUNT(*) FILTER (WHERE e.status = 'deferred')::int AS deferred_count,
    COUNT(*) FILTER (WHERE e.status = 'unread')::int AS unread_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE e.status = 'replied') / NULLIF(COUNT(*), 0), 2) AS reply_rate_pct,
    ROUND(EXTRACT(EPOCH FROM (now() - MIN(e.received_at) FILTER (WHERE e.status = 'unread'))) / 3600.0, 2) AS oldest_unread_hours,
    ROUND(AVG(e.reply_latency_minutes) FILTER (WHERE e.reply_latency_minutes IS NOT NULL), 2) AS avg_reply_latency_minutes
  FROM public.weekly_inbox_zero_emails_r2389 e
  GROUP BY e.week_start
  ORDER BY e.week_start DESC
  LIMIT 12;
END;
$$;

REVOKE ALL ON FUNCTION public.wiz_r2389_weekly_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wiz_r2389_weekly_summary() TO authenticated;

-- RPC 2: reply latency by category
DROP FUNCTION IF EXISTS public.wiz_r2389_latency_by_category();
CREATE OR REPLACE FUNCTION public.wiz_r2389_latency_by_category()
RETURNS TABLE (
  category text,
  total_emails int,
  replied_emails int,
  avg_latency_minutes numeric,
  median_latency_minutes numeric,
  max_latency_minutes int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.category,
    COUNT(*)::int AS total_emails,
    COUNT(*) FILTER (WHERE e.replied_at IS NOT NULL)::int AS replied_emails,
    ROUND(AVG(e.reply_latency_minutes), 2) AS avg_latency_minutes,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.reply_latency_minutes)::numeric, 2) AS median_latency_minutes,
    MAX(e.reply_latency_minutes) AS max_latency_minutes
  FROM public.weekly_inbox_zero_emails_r2389 e
  WHERE e.reply_latency_minutes IS NOT NULL
  GROUP BY e.category
  ORDER BY avg_latency_minutes DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.wiz_r2389_latency_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wiz_r2389_latency_by_category() TO authenticated;

-- RPC 3: oldest unread emails
DROP FUNCTION IF EXISTS public.wiz_r2389_oldest_unread();
CREATE OR REPLACE FUNCTION public.wiz_r2389_oldest_unread()
RETURNS TABLE (
  id uuid,
  sender_email text,
  subject text,
  category text,
  priority text,
  received_at timestamptz,
  age_hours numeric,
  needs_action boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.sender_email,
    e.subject,
    e.category,
    e.priority,
    e.received_at,
    ROUND(EXTRACT(EPOCH FROM (now() - e.received_at)) / 3600.0, 2) AS age_hours,
    e.needs_action
  FROM public.weekly_inbox_zero_emails_r2389 e
  WHERE e.status = 'unread'
  ORDER BY e.received_at ASC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.wiz_r2389_oldest_unread() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wiz_r2389_oldest_unread() TO authenticated;

-- RPC 4: deferred queue
DROP FUNCTION IF EXISTS public.wiz_r2389_deferred_queue();
CREATE OR REPLACE FUNCTION public.wiz_r2389_deferred_queue()
RETURNS TABLE (
  id uuid,
  sender_email text,
  subject text,
  category text,
  deferred_until date,
  days_until_due int,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.id,
    e.sender_email,
    e.subject,
    e.category,
    e.deferred_until,
    (e.deferred_until - CURRENT_DATE)::int AS days_until_due,
    e.notes
  FROM public.weekly_inbox_zero_emails_r2389 e
  WHERE e.status = 'deferred' AND e.deferred_until IS NOT NULL
  ORDER BY e.deferred_until ASC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.wiz_r2389_deferred_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wiz_r2389_deferred_queue() TO authenticated;

-- RPC 5: snapshot trend
DROP FUNCTION IF EXISTS public.wiz_r2389_snapshot_trend();
CREATE OR REPLACE FUNCTION public.wiz_r2389_snapshot_trend()
RETURNS TABLE (
  week_start date,
  received_count int,
  replied_count int,
  unread_count int,
  oldest_unread_hours numeric,
  avg_reply_latency_minutes numeric,
  inbox_zero_achieved boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.week_start,
    s.received_count,
    s.replied_count,
    s.unread_count,
    s.oldest_unread_hours,
    s.avg_reply_latency_minutes,
    s.inbox_zero_achieved
  FROM public.weekly_inbox_zero_snapshots_r2389 s
  ORDER BY s.week_start DESC
  LIMIT 12;
END;
$$;

REVOKE ALL ON FUNCTION public.wiz_r2389_snapshot_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wiz_r2389_snapshot_trend() TO authenticated;

-- RPC 6: priority breakdown
DROP FUNCTION IF EXISTS public.wiz_r2389_priority_breakdown();
CREATE OR REPLACE FUNCTION public.wiz_r2389_priority_breakdown()
RETURNS TABLE (
  priority text,
  total_count int,
  replied_count int,
  unread_count int,
  avg_latency_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    e.priority,
    COUNT(*)::int AS total_count,
    COUNT(*) FILTER (WHERE e.status = 'replied')::int AS replied_count,
    COUNT(*) FILTER (WHERE e.status = 'unread')::int AS unread_count,
    ROUND(AVG(e.reply_latency_minutes), 2) AS avg_latency_minutes
  FROM public.weekly_inbox_zero_emails_r2389 e
  GROUP BY e.priority
  ORDER BY
    CASE e.priority
      WHEN 'urgent' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
    END;
END;
$$;

REVOKE ALL ON FUNCTION public.wiz_r2389_priority_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wiz_r2389_priority_breakdown() TO authenticated;

-- RPC 7: current week scorecard
DROP FUNCTION IF EXISTS public.wiz_r2389_current_scorecard();
CREATE OR REPLACE FUNCTION public.wiz_r2389_current_scorecard()
RETURNS TABLE (
  metric text,
  value numeric,
  detail text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_week_start date := date_trunc('week', CURRENT_DATE)::date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'Received this week'::text, COUNT(*)::numeric, 'emails arrived'::text
  FROM public.weekly_inbox_zero_emails_r2389
  WHERE week_start = v_week_start
  UNION ALL
  SELECT 'Replied this week'::text, COUNT(*)::numeric, 'replies sent'::text
  FROM public.weekly_inbox_zero_emails_r2389
  WHERE week_start = v_week_start AND status = 'replied'
  UNION ALL
  SELECT 'Deferred this week'::text, COUNT(*)::numeric, 'snoozed'::text
  FROM public.weekly_inbox_zero_emails_r2389
  WHERE week_start = v_week_start AND status = 'deferred'
  UNION ALL
  SELECT 'Unread now'::text, COUNT(*)::numeric, 'all weeks combined'::text
  FROM public.weekly_inbox_zero_emails_r2389
  WHERE status = 'unread'
  UNION ALL
  SELECT 'Oldest unread (hours)'::text,
    ROUND(EXTRACT(EPOCH FROM (now() - MIN(received_at))) / 3600.0, 2),
    'aging signal'::text
  FROM public.weekly_inbox_zero_emails_r2389
  WHERE status = 'unread'
  UNION ALL
  SELECT 'Avg reply latency (min)'::text,
    ROUND(AVG(reply_latency_minutes), 2),
    'lower is better'::text
  FROM public.weekly_inbox_zero_emails_r2389
  WHERE reply_latency_minutes IS NOT NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.wiz_r2389_current_scorecard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wiz_r2389_current_scorecard() TO authenticated;

COMMIT;
