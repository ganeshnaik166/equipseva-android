-- =====================================================================
-- Round 610 — Founder slow-RPC leaderboard (pg_stat_statements wrapper)
-- =====================================================================
--
-- pg_stat_statements (if enabled) accumulates per-statement counters:
-- total_exec_time, mean_exec_time, calls. r610 wraps it as a
-- founder-only view of "which RPCs are eating wall-clock?" Without
-- this view, performance hotspots are invisible until they cause an
-- outage.
--
-- Degrades gracefully when pg_stat_statements isn't enabled (Supabase
-- tier varies). Returns empty + the page renders a docs notice.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_slow_rpcs();

CREATE OR REPLACE FUNCTION public.founder_slow_rpcs()
RETURNS TABLE (
  query_fingerprint    text,
  calls                bigint,
  total_exec_time_ms   numeric,
  mean_exec_time_ms    numeric,
  rows_returned        bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_has_ext boolean := false;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
  ) INTO v_has_ext;
  IF NOT v_has_ext THEN
    RETURN;
  END IF;

  BEGIN
    RETURN QUERY
    SELECT
      -- Truncate to 200 chars to keep response sane; full query
      -- available via psql for the founder.
      left(s.query, 200)                              AS query_fingerprint,
      s.calls,
      round(s.total_exec_time::numeric, 2)            AS total_exec_time_ms,
      round(s.mean_exec_time::numeric, 2)             AS mean_exec_time_ms,
      s.rows                                          AS rows_returned
    FROM pg_stat_statements s
    -- Skip our own EXEC + the SECDEF wrapper call so we don't pollute
    -- the listing with the query that's reading the listing.
    WHERE s.query NOT ILIKE '%pg_stat_statements%'
      AND s.query NOT ILIKE '%founder_slow_rpcs%'
      AND s.calls > 5  -- ignore one-off setup queries
    ORDER BY s.total_exec_time DESC
    LIMIT 50;
  EXCEPTION WHEN OTHERS THEN
    -- Don't blow up the cockpit if pg_stat_statements schema shifts.
    RETURN;
  END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_slow_rpcs() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_slow_rpcs() TO authenticated;

COMMIT;
