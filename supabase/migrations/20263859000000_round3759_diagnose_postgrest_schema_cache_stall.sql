-- Round 3759 — diagnostic only, no schema changes. Surfaces pg_stat_activity
-- info via RAISE NOTICE (visible in `supabase db push` output) to check for
-- long-running / blocking sessions that could be starving PostgREST's
-- internal schema-introspection query (the query behind the PGRST002
-- "Could not query the database for the schema cache" error currently
-- being investigated).
DO $$
DECLARE
  v_rec record;
  v_total_relations int;
  v_long_running int;
BEGIN
  SELECT count(*) INTO v_total_relations
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
      AND c.relkind IN ('r', 'v', 'p');
  RAISE NOTICE 'total user-schema relations (tables+views): %', v_total_relations;

  SELECT count(*) INTO v_long_running
    FROM pg_stat_activity
    WHERE state != 'idle'
      AND now() - query_start > interval '10 seconds'
      AND pid != pg_backend_pid();
  RAISE NOTICE 'sessions active >10s (excluding this one): %', v_long_running;

  FOR v_rec IN
    SELECT pid, state, wait_event_type, wait_event,
           now() - query_start AS running_for,
           left(query, 120) AS query_snippet
      FROM pg_stat_activity
     WHERE state != 'idle'
       AND pid != pg_backend_pid()
     ORDER BY query_start
     LIMIT 20
  LOOP
    RAISE NOTICE 'pid=% state=% wait=%/% running_for=% query=%',
      v_rec.pid, v_rec.state, v_rec.wait_event_type, v_rec.wait_event,
      v_rec.running_for, v_rec.query_snippet;
  END LOOP;

  RAISE NOTICE '--- blocking locks ---';
  FOR v_rec IN
    SELECT blocked_locks.pid AS blocked_pid,
           blocking_locks.pid AS blocking_pid,
           left(blocked_activity.query, 80) AS blocked_query,
           left(blocking_activity.query, 80) AS blocking_query
    FROM pg_catalog.pg_locks blocked_locks
    JOIN pg_catalog.pg_stat_activity blocked_activity
      ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_catalog.pg_locks blocking_locks
      ON blocking_locks.locktype = blocked_locks.locktype
     AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
     AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
     AND blocking_locks.pid != blocked_locks.pid
    JOIN pg_catalog.pg_stat_activity blocking_activity
      ON blocking_activity.pid = blocking_locks.pid
    WHERE NOT blocked_locks.granted
  LOOP
    RAISE NOTICE 'blocked_pid=% blocking_pid=% blocked_query=% blocking_query=%',
      v_rec.blocked_pid, v_rec.blocking_pid, v_rec.blocked_query, v_rec.blocking_query;
  END LOOP;
END $$;
