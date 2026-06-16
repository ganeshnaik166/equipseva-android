-- =====================================================================
-- Round 604 — Founder long-running query ops view
-- =====================================================================
--
-- Pathological queries (forgotten EXPLAIN session, runaway cron, a
-- migration that ran past its window) hold locks + spike load. Today
-- only psql can see pg_stat_activity. r604 ships a founder-only
-- SECDEF wrapper that surfaces queries running >5s.
--
-- Privacy: query text is exposed only to founders (is_founder() gate).
-- The application_name + state + age + waiting flag are enough to
-- spot the offender — usr identity intentionally NOT exposed (it's a
-- DB user, not an auth.users id).

BEGIN;

DROP FUNCTION IF EXISTS public.founder_long_running_queries();

CREATE OR REPLACE FUNCTION public.founder_long_running_queries()
RETURNS TABLE (
  pid               int,
  application_name  text,
  state             text,
  wait_event_type   text,
  wait_event        text,
  query_start       timestamptz,
  age_seconds       int,
  query             text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    a.pid,
    coalesce(a.application_name, '(unknown)')::text          AS application_name,
    a.state::text                                            AS state,
    a.wait_event_type::text                                  AS wait_event_type,
    a.wait_event::text                                       AS wait_event,
    a.query_start,
    extract(epoch FROM (now() - a.query_start))::int         AS age_seconds,
    -- Truncate to 500 chars so a multi-page query doesn't blow up the
    -- response shape. The founder can SSH for the full plan.
    left(a.query, 500)                                       AS query
  FROM pg_stat_activity a
  WHERE a.query_start IS NOT NULL
    AND a.state <> 'idle'
    AND a.query_start < now() - interval '5 seconds'
    -- Hide ourselves from the listing — the SECDEF call IS a query.
    AND a.pid <> pg_backend_pid()
  ORDER BY a.query_start ASC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_long_running_queries() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_long_running_queries() TO authenticated;

COMMENT ON FUNCTION public.founder_long_running_queries() IS
  'r604: founder-only pg_stat_activity wrapper — queries >5s, sorted by start time ASC (oldest first), self-excluded.';

COMMIT;
