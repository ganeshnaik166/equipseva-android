-- TTL helpers for tables that grow without bound. Each helper is a
-- standalone SECURITY DEFINER function returning the row count it
-- swept; ops can wire any of them to pg_cron OR a Supabase scheduled
-- edge function. Same pattern as expire_stale_cost_revisions in
-- 20260504140000 — repo has no prior pg_cron wiring so we don't
-- assume the extension is loaded.
--
-- Recommended schedule once the app crosses ~10K MAU:
--   purge_old_notifications()        — daily 03:00 UTC
--   purge_old_content_reports()      — weekly Sun 04:00 UTC
--   purge_old_device_integrity_checks() — daily 03:30 UTC
--
-- Conservative retention windows. Tighten later when storage cost is
-- the binding constraint.

-- ---------------------------------------------------------------------------
-- notifications: drop READ rows older than 90 days. Unread rows stay
-- forever — they're the user's inbox. Soft-deleted approach keeps the
-- inbox view intact while letting Postgres reclaim space.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_old_notifications()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  WITH gone AS (
    DELETE FROM public.notifications
     WHERE coalesce(is_read, false) = true
       AND read_at < now() - interval '90 days'
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM gone;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.purge_old_notifications() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_old_notifications() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- content_reports: drop reviewed (non-pending) rows older than 1 year.
-- Pending stays forever (it's the moderator queue). Compliance-style
-- DPDP retention — actioned reports keep their audit trail for a
-- year, then we let them go.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_old_content_reports()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  WITH gone AS (
    DELETE FROM public.content_reports
     WHERE status <> 'pending'
       AND coalesce(reviewed_at, created_at) < now() - interval '1 year'
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM gone;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.purge_old_content_reports() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_old_content_reports() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- device_integrity_checks: keep PASSING checks 30 days, FAILING checks
-- 1 year. Failing checks are forensics — we want the trail when
-- investigating abuse. Passing checks are heartbeats; 30 days of
-- history is plenty for "did this user pass last week?" lookups.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.purge_old_device_integrity_checks()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  WITH gone AS (
    DELETE FROM public.device_integrity_checks
     WHERE (
            coalesce(pass, true) = true
        AND created_at < now() - interval '30 days'
       )
        OR (
            coalesce(pass, true) = false
        AND created_at < now() - interval '1 year'
       )
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM gone;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.purge_old_device_integrity_checks() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_old_device_integrity_checks() FROM PUBLIC, anon, authenticated;
