BEGIN;

-- r1466: Fundraise Data Room v2 -- file-level granular access logs,
-- per-investor activity ranking, file viewing-time analytics, expired-link reaper.

CREATE TABLE IF NOT EXISTS public.investor_file_access_log_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  share_token     text NOT NULL,
  investor_email  text,
  investor_name   text,
  file_path       text NOT NULL,
  file_label      text,
  event_type      text NOT NULL CHECK (event_type IN ('view','download','open','close','scroll')),
  view_seconds    integer NOT NULL DEFAULT 0 CHECK (view_seconds >= 0),
  ip_address      inet,
  user_agent      text,
  referer         text,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  session_id      text,
  meta            jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_ifal_v2_token    ON public.investor_file_access_log_v2 (share_token);
CREATE INDEX IF NOT EXISTS idx_ifal_v2_occurred ON public.investor_file_access_log_v2 (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_ifal_v2_file     ON public.investor_file_access_log_v2 (file_path);
CREATE INDEX IF NOT EXISTS idx_ifal_v2_email    ON public.investor_file_access_log_v2 (investor_email);
CREATE INDEX IF NOT EXISTS idx_ifal_v2_event    ON public.investor_file_access_log_v2 (event_type);

ALTER TABLE public.investor_file_access_log_v2 ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.investor_link_reaper_log_v2 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  share_token     text NOT NULL,
  investor_email  text,
  reason          text NOT NULL CHECK (reason IN ('expired','revoked','quota','manual')),
  expired_at      timestamptz,
  reaped_at       timestamptz NOT NULL DEFAULT now(),
  reaped_by       uuid,
  notes           text
);

CREATE INDEX IF NOT EXISTS idx_ilrl_v2_token  ON public.investor_link_reaper_log_v2 (share_token);
CREATE INDEX IF NOT EXISTS idx_ilrl_v2_reaped ON public.investor_link_reaper_log_v2 (reaped_at DESC);

ALTER TABLE public.investor_link_reaper_log_v2 ENABLE ROW LEVEL SECURITY;

-- ===== RPCs (7 SECDEF STABLE) =====

CREATE OR REPLACE FUNCTION public.founder_dataroom_v2_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_events_30d',     (SELECT count(*) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '30 days'),
    'total_events_7d',      (SELECT count(*) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '7 days'),
    'total_events_24h',     (SELECT count(*) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '24 hours'),
    'unique_investors_30d', (SELECT count(DISTINCT investor_email) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '30 days'),
    'unique_investors_7d',  (SELECT count(DISTINCT investor_email) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '7 days'),
    'unique_files_30d',     (SELECT count(DISTINCT file_path) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '30 days'),
    'view_events_30d',      (SELECT count(*) FROM investor_file_access_log_v2 WHERE event_type='view'     AND occurred_at > now() - interval '30 days'),
    'download_events_30d',  (SELECT count(*) FROM investor_file_access_log_v2 WHERE event_type='download' AND occurred_at > now() - interval '30 days'),
    'total_view_seconds_30d', (SELECT coalesce(sum(view_seconds),0) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '30 days'),
    'avg_view_seconds_30d',   (SELECT coalesce(round(avg(NULLIF(view_seconds,0))::numeric,1),0) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '30 days'),
    'p95_view_seconds_30d',   (SELECT coalesce(percentile_cont(0.95) WITHIN GROUP (ORDER BY view_seconds),0)::int FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '30 days' AND view_seconds > 0),
    'links_reaped_30d',     (SELECT count(*) FROM investor_link_reaper_log_v2 WHERE reaped_at > now() - interval '30 days'),
    'links_reaped_expired_30d', (SELECT count(*) FROM investor_link_reaper_log_v2 WHERE reason='expired' AND reaped_at > now() - interval '30 days'),
    'links_reaped_revoked_30d', (SELECT count(*) FROM investor_link_reaper_log_v2 WHERE reason='revoked' AND reaped_at > now() - interval '30 days'),
    'engaged_investors_7d',  (SELECT count(*) FROM (SELECT investor_email FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '7 days' GROUP BY investor_email HAVING sum(view_seconds) > 120) e),
    'sessions_24h',          (SELECT count(DISTINCT session_id) FROM investor_file_access_log_v2 WHERE occurred_at > now() - interval '24 hours' AND session_id IS NOT NULL)
  ) INTO r;
  RETURN r;
END $$;
REVOKE ALL ON FUNCTION public.founder_dataroom_v2_kpis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_dataroom_v2_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dataroom_v2_recent_events(p_limit int DEFAULT 50)
RETURNS TABLE (id uuid, share_token text, investor_email text, investor_name text, file_path text, file_label text, event_type text, view_seconds int, occurred_at timestamptz, ip_address text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.share_token, l.investor_email, l.investor_name, l.file_path, l.file_label,
         l.event_type, l.view_seconds, l.occurred_at, host(l.ip_address)::text
  FROM investor_file_access_log_v2 l
  ORDER BY l.occurred_at DESC
  LIMIT coalesce(p_limit, 50);
END $$;
REVOKE ALL ON FUNCTION public.founder_dataroom_v2_recent_events(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_dataroom_v2_recent_events(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dataroom_v2_investor_ranking(p_days int DEFAULT 30, p_limit int DEFAULT 25)
RETURNS TABLE (id text, investor_email text, investor_name text, total_events bigint, unique_files bigint, total_view_seconds bigint, downloads bigint, last_seen_at timestamptz, engagement_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(l.investor_email, '(anonymous)') AS id,
         l.investor_email,
         max(l.investor_name) AS investor_name,
         count(*)::bigint AS total_events,
         count(DISTINCT l.file_path)::bigint AS unique_files,
         coalesce(sum(l.view_seconds),0)::bigint AS total_view_seconds,
         count(*) FILTER (WHERE l.event_type='download')::bigint AS downloads,
         max(l.occurred_at) AS last_seen_at,
         round((count(DISTINCT l.file_path) * 5 + count(*) FILTER (WHERE l.event_type='download') * 10 + (coalesce(sum(l.view_seconds),0) / 60.0))::numeric, 2) AS engagement_score
  FROM investor_file_access_log_v2 l
  WHERE l.occurred_at > now() - (coalesce(p_days,30) || ' days')::interval
  GROUP BY l.investor_email
  ORDER BY engagement_score DESC NULLS LAST
  LIMIT coalesce(p_limit, 25);
END $$;
REVOKE ALL ON FUNCTION public.founder_dataroom_v2_investor_ranking(int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_dataroom_v2_investor_ranking(int,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dataroom_v2_file_analytics(p_days int DEFAULT 30, p_limit int DEFAULT 25)
RETURNS TABLE (id text, file_path text, file_label text, total_events bigint, unique_investors bigint, total_view_seconds bigint, avg_view_seconds numeric, downloads bigint, last_seen_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.file_path AS id,
         l.file_path,
         max(l.file_label) AS file_label,
         count(*)::bigint AS total_events,
         count(DISTINCT l.investor_email)::bigint AS unique_investors,
         coalesce(sum(l.view_seconds),0)::bigint AS total_view_seconds,
         coalesce(round(avg(NULLIF(l.view_seconds,0))::numeric, 1), 0) AS avg_view_seconds,
         count(*) FILTER (WHERE l.event_type='download')::bigint AS downloads,
         max(l.occurred_at) AS last_seen_at
  FROM investor_file_access_log_v2 l
  WHERE l.occurred_at > now() - (coalesce(p_days,30) || ' days')::interval
  GROUP BY l.file_path
  ORDER BY total_view_seconds DESC NULLS LAST
  LIMIT coalesce(p_limit, 25);
END $$;
REVOKE ALL ON FUNCTION public.founder_dataroom_v2_file_analytics(int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_dataroom_v2_file_analytics(int,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dataroom_v2_daily_trend(p_days int DEFAULT 30)
RETURNS TABLE (id text, day date, events bigint, unique_investors bigint, view_seconds bigint, downloads bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('day', l.occurred_at), 'YYYY-MM-DD') AS id,
         date_trunc('day', l.occurred_at)::date AS day,
         count(*)::bigint AS events,
         count(DISTINCT l.investor_email)::bigint AS unique_investors,
         coalesce(sum(l.view_seconds),0)::bigint AS view_seconds,
         count(*) FILTER (WHERE l.event_type='download')::bigint AS downloads
  FROM investor_file_access_log_v2 l
  WHERE l.occurred_at > now() - (coalesce(p_days,30) || ' days')::interval
  GROUP BY 1, 2
  ORDER BY 2 DESC;
END $$;
REVOKE ALL ON FUNCTION public.founder_dataroom_v2_daily_trend(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_dataroom_v2_daily_trend(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dataroom_v2_reaper_recent(p_limit int DEFAULT 25)
RETURNS TABLE (id uuid, share_token text, investor_email text, reason text, expired_at timestamptz, reaped_at timestamptz, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.share_token, r.investor_email, r.reason, r.expired_at, r.reaped_at, r.notes
  FROM investor_link_reaper_log_v2 r
  ORDER BY r.reaped_at DESC
  LIMIT coalesce(p_limit, 25);
END $$;
REVOKE ALL ON FUNCTION public.founder_dataroom_v2_reaper_recent(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_dataroom_v2_reaper_recent(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dataroom_v2_session_summary(p_days int DEFAULT 14, p_limit int DEFAULT 25)
RETURNS TABLE (id text, session_id text, investor_email text, started_at timestamptz, ended_at timestamptz, events bigint, view_seconds bigint, unique_files bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT coalesce(l.session_id, l.id::text) AS id,
         l.session_id,
         max(l.investor_email) AS investor_email,
         min(l.occurred_at) AS started_at,
         max(l.occurred_at) AS ended_at,
         count(*)::bigint AS events,
         coalesce(sum(l.view_seconds),0)::bigint AS view_seconds,
         count(DISTINCT l.file_path)::bigint AS unique_files
  FROM investor_file_access_log_v2 l
  WHERE l.session_id IS NOT NULL
    AND l.occurred_at > now() - (coalesce(p_days,14) || ' days')::interval
  GROUP BY l.session_id, l.id
  ORDER BY ended_at DESC
  LIMIT coalesce(p_limit, 25);
END $$;
REVOKE ALL ON FUNCTION public.founder_dataroom_v2_session_summary(int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_dataroom_v2_session_summary(int,int) TO authenticated;

-- ===== log_founder_* helpers (VOLATILE SECDEF, is_founder gated) =====

CREATE OR REPLACE FUNCTION public.log_founder_dataroom_v2_event(
  p_share_token text,
  p_investor_email text,
  p_investor_name text,
  p_file_path text,
  p_file_label text,
  p_event_type text,
  p_view_seconds int,
  p_session_id text,
  p_meta jsonb
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_file_access_log_v2 (share_token, investor_email, investor_name, file_path, file_label, event_type, view_seconds, session_id, meta)
  VALUES (p_share_token, p_investor_email, p_investor_name, p_file_path, p_file_label, coalesce(p_event_type,'view'), coalesce(p_view_seconds,0), p_session_id, coalesce(p_meta,'{}'::jsonb))
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_dataroom_v2_event(text,text,text,text,text,text,int,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_dataroom_v2_event(text,text,text,text,text,text,int,text,jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_dataroom_v2_reap(
  p_share_token text,
  p_investor_email text,
  p_reason text,
  p_expired_at timestamptz,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_link_reaper_log_v2 (share_token, investor_email, reason, expired_at, reaped_by, notes)
  VALUES (p_share_token, p_investor_email, coalesce(p_reason,'manual'), p_expired_at, auth.uid(), p_notes)
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_dataroom_v2_reap(text,text,text,timestamptz,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_dataroom_v2_reap(text,text,text,timestamptz,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_dataroom_v2_run_reaper()
RETURNS int
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE n int := 0;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  -- Stub: orchestrator wires expiry detection against existing investor_shares.
  INSERT INTO investor_link_reaper_log_v2 (share_token, reason, expired_at, reaped_by, notes)
  VALUES ('__reaper_tick__', 'manual', now(), auth.uid(), 'reaper manual tick from v2 console');
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_dataroom_v2_run_reaper() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_dataroom_v2_run_reaper() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_dataroom_v2_session_close(
  p_session_id text,
  p_share_token text,
  p_investor_email text,
  p_total_seconds int
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_file_access_log_v2 (share_token, investor_email, file_path, event_type, view_seconds, session_id, meta)
  VALUES (p_share_token, p_investor_email, '__session_close__', 'close', coalesce(p_total_seconds,0), p_session_id, jsonb_build_object('kind','session_close'))
  RETURNING id INTO new_id;
  RETURN new_id;
END $$;
REVOKE ALL ON FUNCTION public.log_founder_dataroom_v2_session_close(text,text,text,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_dataroom_v2_session_close(text,text,text,int) TO authenticated;

COMMIT;