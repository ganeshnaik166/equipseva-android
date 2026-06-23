BEGIN;

-- =====================================================================
-- Round 2322 — Engineer-App Crash + ANR Tracker
-- Tracks crash/ANR reports from engineer Android app by build version,
-- device model, with prioritized blocking-bug triage queue.
-- =====================================================================

-- Crash / ANR raw reports captured from engineer Android client
CREATE TABLE IF NOT EXISTS public.engineer_app_crash_reports_r2322 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  build_version   text NOT NULL,
  build_code      integer NOT NULL,
  device_model    text NOT NULL,
  device_brand    text NOT NULL,
  android_sdk     integer NOT NULL,
  event_kind      text NOT NULL CHECK (event_kind IN ('crash','anr','fatal_native')),
  stack_hash      text NOT NULL,
  top_frame       text NOT NULL,
  exception_class text,
  message         text,
  thread_state    text,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  session_seconds integer,
  network_state   text,
  battery_pct     integer,
  is_blocking     boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eacr_r2322_occurred ON public.engineer_app_crash_reports_r2322 (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_eacr_r2322_hash     ON public.engineer_app_crash_reports_r2322 (stack_hash);
CREATE INDEX IF NOT EXISTS idx_eacr_r2322_build    ON public.engineer_app_crash_reports_r2322 (build_version);
CREATE INDEX IF NOT EXISTS idx_eacr_r2322_device   ON public.engineer_app_crash_reports_r2322 (device_model);

ALTER TABLE public.engineer_app_crash_reports_r2322 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eacr_r2322 ON public.engineer_app_crash_reports_r2322;
CREATE POLICY founder_all_eacr_r2322 ON public.engineer_app_crash_reports_r2322
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Triage / fix-priority register grouped by stack_hash
CREATE TABLE IF NOT EXISTS public.engineer_app_crash_triage_r2322 (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stack_hash        text UNIQUE NOT NULL,
  signature         text NOT NULL,
  fix_priority      text NOT NULL DEFAULT 'p3' CHECK (fix_priority IN ('p0','p1','p2','p3')),
  status            text NOT NULL DEFAULT 'open' CHECK (status IN ('open','investigating','fix_in_review','fixed','wontfix')),
  assigned_to       uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  first_seen_at     timestamptz NOT NULL DEFAULT now(),
  last_seen_at      timestamptz NOT NULL DEFAULT now(),
  total_occurrences integer NOT NULL DEFAULT 1,
  affected_users    integer NOT NULL DEFAULT 1,
  blocking_release  boolean NOT NULL DEFAULT false,
  fix_notes         text,
  fixed_in_build    text,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  updated_by        uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_eact_r2322_priority ON public.engineer_app_crash_triage_r2322 (fix_priority, status);
CREATE INDEX IF NOT EXISTS idx_eact_r2322_lastseen ON public.engineer_app_crash_triage_r2322 (last_seen_at DESC);

ALTER TABLE public.engineer_app_crash_triage_r2322 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eact_r2322 ON public.engineer_app_crash_triage_r2322;
CREATE POLICY founder_all_eact_r2322 ON public.engineer_app_crash_triage_r2322
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: Overview KPIs
-- =====================================================================
CREATE OR REPLACE FUNCTION public.eacr_r2322_overview()
RETURNS TABLE (
  total_crashes_7d    bigint,
  total_anrs_7d       bigint,
  blocking_open       bigint,
  p0_open             bigint,
  affected_users_7d   bigint,
  distinct_signatures bigint,
  worst_build         text,
  worst_build_count   bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.engineer_app_crash_reports_r2322
    WHERE occurred_at >= now() - interval '7 days'
  ),
  worst AS (
    SELECT build_version, count(*)::bigint AS c
    FROM base
    GROUP BY build_version
    ORDER BY c DESC
    LIMIT 1
  )
  SELECT
    (SELECT count(*)::bigint FROM base WHERE event_kind IN ('crash','fatal_native')),
    (SELECT count(*)::bigint FROM base WHERE event_kind = 'anr'),
    (SELECT count(*)::bigint FROM public.engineer_app_crash_triage_r2322
       WHERE blocking_release = true AND status NOT IN ('fixed','wontfix')),
    (SELECT count(*)::bigint FROM public.engineer_app_crash_triage_r2322
       WHERE fix_priority = 'p0' AND status NOT IN ('fixed','wontfix')),
    (SELECT count(DISTINCT reporter_id)::bigint FROM base WHERE reporter_id IS NOT NULL),
    (SELECT count(DISTINCT stack_hash)::bigint FROM base),
    (SELECT build_version FROM worst),
    (SELECT c FROM worst);
END;
$$;

REVOKE ALL ON FUNCTION public.eacr_r2322_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eacr_r2322_overview() TO authenticated;

-- =====================================================================
-- RPC 2: Crashes by build version
-- =====================================================================
CREATE OR REPLACE FUNCTION public.eacr_r2322_by_build()
RETURNS TABLE (
  build_version   text,
  build_code      integer,
  total_events    bigint,
  crash_count     bigint,
  anr_count       bigint,
  affected_users  bigint,
  blocking_count  bigint,
  first_seen      timestamptz,
  last_seen       timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.build_version,
    max(r.build_code),
    count(*)::bigint,
    count(*) FILTER (WHERE r.event_kind IN ('crash','fatal_native'))::bigint,
    count(*) FILTER (WHERE r.event_kind = 'anr')::bigint,
    count(DISTINCT r.reporter_id)::bigint,
    count(*) FILTER (WHERE r.is_blocking = true)::bigint,
    min(r.occurred_at),
    max(r.occurred_at)
  FROM public.engineer_app_crash_reports_r2322 r
  WHERE r.occurred_at >= now() - interval '30 days'
  GROUP BY r.build_version
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.eacr_r2322_by_build() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eacr_r2322_by_build() TO authenticated;

-- =====================================================================
-- RPC 3: Crashes by device model
-- =====================================================================
CREATE OR REPLACE FUNCTION public.eacr_r2322_by_device()
RETURNS TABLE (
  device_brand   text,
  device_model   text,
  android_sdk    integer,
  total_events   bigint,
  crash_count    bigint,
  anr_count      bigint,
  affected_users bigint,
  last_seen      timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.device_brand,
    r.device_model,
    max(r.android_sdk),
    count(*)::bigint,
    count(*) FILTER (WHERE r.event_kind IN ('crash','fatal_native'))::bigint,
    count(*) FILTER (WHERE r.event_kind = 'anr')::bigint,
    count(DISTINCT r.reporter_id)::bigint,
    max(r.occurred_at)
  FROM public.engineer_app_crash_reports_r2322 r
  WHERE r.occurred_at >= now() - interval '30 days'
  GROUP BY r.device_brand, r.device_model
  ORDER BY count(*) DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.eacr_r2322_by_device() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eacr_r2322_by_device() TO authenticated;

-- =====================================================================
-- RPC 4: Top signatures (group by stack_hash)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.eacr_r2322_top_signatures()
RETURNS TABLE (
  stack_hash        text,
  signature         text,
  exception_class   text,
  event_kind        text,
  total_occurrences bigint,
  affected_users    bigint,
  first_seen        timestamptz,
  last_seen         timestamptz,
  triage_status     text,
  fix_priority      text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.stack_hash,
    max(r.top_frame),
    max(r.exception_class),
    max(r.event_kind),
    count(*)::bigint,
    count(DISTINCT r.reporter_id)::bigint,
    min(r.occurred_at),
    max(r.occurred_at),
    coalesce(t.status, 'untriaged'),
    coalesce(t.fix_priority, 'p3')
  FROM public.engineer_app_crash_reports_r2322 r
  LEFT JOIN public.engineer_app_crash_triage_r2322 t ON t.stack_hash = r.stack_hash
  WHERE r.occurred_at >= now() - interval '30 days'
  GROUP BY r.stack_hash, t.status, t.fix_priority
  ORDER BY count(*) DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.eacr_r2322_top_signatures() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eacr_r2322_top_signatures() TO authenticated;

-- =====================================================================
-- RPC 5: Blocking-bug fix priority queue
-- =====================================================================
CREATE OR REPLACE FUNCTION public.eacr_r2322_priority_queue()
RETURNS TABLE (
  stack_hash       text,
  signature        text,
  fix_priority     text,
  status           text,
  blocking_release boolean,
  total_occurrences integer,
  affected_users   integer,
  first_seen_at    timestamptz,
  last_seen_at     timestamptz,
  assignee_email   text,
  fix_notes        text,
  fixed_in_build   text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.stack_hash,
    t.signature,
    t.fix_priority,
    t.status,
    t.blocking_release,
    t.total_occurrences,
    t.affected_users,
    t.first_seen_at,
    t.last_seen_at,
    p.email,
    t.fix_notes,
    t.fixed_in_build
  FROM public.engineer_app_crash_triage_r2322 t
  LEFT JOIN public.profiles p ON p.id = t.assigned_to
  WHERE t.status NOT IN ('fixed','wontfix')
  ORDER BY
    CASE t.fix_priority WHEN 'p0' THEN 0 WHEN 'p1' THEN 1 WHEN 'p2' THEN 2 ELSE 3 END,
    t.blocking_release DESC,
    t.total_occurrences DESC
  LIMIT 200;
END;
$$;

REVOKE ALL ON FUNCTION public.eacr_r2322_priority_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eacr_r2322_priority_queue() TO authenticated;

-- =====================================================================
-- RPC 6: Recent raw events feed
-- =====================================================================
CREATE OR REPLACE FUNCTION public.eacr_r2322_recent_events()
RETURNS TABLE (
  id              uuid,
  occurred_at     timestamptz,
  event_kind      text,
  build_version   text,
  device_brand    text,
  device_model    text,
  android_sdk     integer,
  exception_class text,
  top_frame       text,
  reporter_email  text,
  is_blocking     boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.occurred_at,
    r.event_kind,
    r.build_version,
    r.device_brand,
    r.device_model,
    r.android_sdk,
    r.exception_class,
    r.top_frame,
    p.email,
    r.is_blocking
  FROM public.engineer_app_crash_reports_r2322 r
  LEFT JOIN public.profiles p ON p.id = r.reporter_id
  ORDER BY r.occurred_at DESC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.eacr_r2322_recent_events() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eacr_r2322_recent_events() TO authenticated;

-- =====================================================================
-- RPC 7: Daily trend last 14 days
-- =====================================================================
CREATE OR REPLACE FUNCTION public.eacr_r2322_daily_trend()
RETURNS TABLE (
  day            date,
  crash_count    bigint,
  anr_count      bigint,
  blocking_count bigint,
  affected_users bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (r.occurred_at AT TIME ZONE 'Asia/Kolkata')::date,
    count(*) FILTER (WHERE r.event_kind IN ('crash','fatal_native'))::bigint,
    count(*) FILTER (WHERE r.event_kind = 'anr')::bigint,
    count(*) FILTER (WHERE r.is_blocking = true)::bigint,
    count(DISTINCT r.reporter_id)::bigint
  FROM public.engineer_app_crash_reports_r2322 r
  WHERE r.occurred_at >= now() - interval '14 days'
  GROUP BY 1
  ORDER BY 1 DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.eacr_r2322_daily_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.eacr_r2322_daily_trend() TO authenticated;

COMMIT;
