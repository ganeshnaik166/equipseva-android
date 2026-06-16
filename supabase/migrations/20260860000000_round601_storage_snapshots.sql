-- =====================================================================
-- Round 601 — DB storage snapshots (history of table growth)
-- =====================================================================
--
-- r600 ships a point-in-time storage view. But "is the engineer_
-- certification_progress table growing 5% a week?" needs history.
-- r601 plants a daily snapshot ledger + a sweep function that the
-- pg_cron (or edge fn fallback) runs each morning.
--
-- Schema kept tiny: (table_name, snapshot_at, total_bytes,
-- est_row_count). 90-day retention so the ledger itself doesn't
-- balloon.

BEGIN;

CREATE TABLE IF NOT EXISTS public.db_storage_snapshots (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name    text NOT NULL,
  snapshot_at   timestamptz NOT NULL DEFAULT now(),
  total_bytes   bigint NOT NULL,
  est_row_count bigint NOT NULL
);

CREATE INDEX IF NOT EXISTS db_storage_snapshots_table_time_idx
  ON public.db_storage_snapshots (table_name, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS db_storage_snapshots_time_idx
  ON public.db_storage_snapshots (snapshot_at DESC);

ALTER TABLE public.db_storage_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.db_storage_snapshots
  FROM anon, authenticated;

-- ----------------------------------------------------------------
-- Snapshot writer — called by daily cron (or edge fn).
-- Writes one row per public table at call time + prunes >90d rows.
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.db_storage_snapshot_sweep();
CREATE OR REPLACE FUNCTION public.db_storage_snapshot_sweep()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inserted int := 0;
  v_pruned   int := 0;
BEGIN
  INSERT INTO public.db_storage_snapshots
    (table_name, total_bytes, est_row_count)
  SELECT
    c.relname::text,
    pg_total_relation_size(c.oid),
    c.reltuples::bigint
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r';
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  -- 90-day retention.
  DELETE FROM public.db_storage_snapshots
   WHERE snapshot_at < now() - interval '90 days';
  GET DIAGNOSTICS v_pruned = ROW_COUNT;

  RETURN v_inserted;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.db_storage_snapshot_sweep()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.db_storage_snapshot_sweep()
  TO service_role;

-- ----------------------------------------------------------------
-- founder read RPC: current + 7-day-old snapshot per table.
-- Returns delta_bytes + delta_pct for the WoW column on /db-storage.
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_db_storage_with_delta();
CREATE OR REPLACE FUNCTION public.founder_db_storage_with_delta()
RETURNS TABLE (
  table_name     text,
  est_row_count  bigint,
  total_bytes    bigint,
  total_pretty   text,
  table_bytes    bigint,
  table_pretty   text,
  index_bytes    bigint,
  index_pretty   text,
  prior_bytes    bigint,
  delta_bytes    bigint,
  delta_pct      numeric
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
  WITH live AS (
    SELECT
      c.relname::text                                          AS table_name,
      c.reltuples::bigint                                      AS est_row_count,
      pg_total_relation_size(c.oid)                            AS total_bytes,
      pg_size_pretty(pg_total_relation_size(c.oid))            AS total_pretty,
      pg_relation_size(c.oid)                                  AS table_bytes,
      pg_size_pretty(pg_relation_size(c.oid))                  AS table_pretty,
      (pg_total_relation_size(c.oid) - pg_relation_size(c.oid)
        - coalesce(pg_relation_size(c.reltoastrelid), 0))      AS index_bytes,
      pg_size_pretty(
        pg_total_relation_size(c.oid) - pg_relation_size(c.oid)
          - coalesce(pg_relation_size(c.reltoastrelid), 0)
      )                                                        AS index_pretty
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
  ),
  prior AS (
    SELECT DISTINCT ON (s.table_name)
      s.table_name,
      s.total_bytes AS prior_bytes
    FROM public.db_storage_snapshots s
    WHERE s.snapshot_at <= now() - interval '7 days'
    ORDER BY s.table_name, s.snapshot_at DESC
  )
  SELECT
    l.table_name,
    l.est_row_count,
    l.total_bytes,
    l.total_pretty,
    l.table_bytes,
    l.table_pretty,
    l.index_bytes,
    l.index_pretty,
    p.prior_bytes,
    CASE WHEN p.prior_bytes IS NULL THEN NULL
         ELSE l.total_bytes - p.prior_bytes END  AS delta_bytes,
    CASE
      WHEN p.prior_bytes IS NULL OR p.prior_bytes = 0 THEN NULL
      ELSE round(
        ((l.total_bytes - p.prior_bytes)::numeric / p.prior_bytes::numeric) * 100.0,
        1
      )
    END                                          AS delta_pct
  FROM live l
  LEFT JOIN prior p ON p.table_name = l.table_name
  ORDER BY l.total_bytes DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_db_storage_with_delta() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_db_storage_with_delta() TO authenticated;

-- Schedule the daily snapshot at 03:13 UTC. Soft-fall-through if
-- pg_cron isn't enabled (edge-fn fallback per project convention).
DO $$
BEGIN
  PERFORM cron.schedule(
    'db_storage_snapshot_sweep',
    '13 3 * * *',
    $cron$SELECT public.db_storage_snapshot_sweep();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron unavailable; db_storage_snapshot_sweep must be triggered by edge fn';
END;
$$;

COMMIT;
