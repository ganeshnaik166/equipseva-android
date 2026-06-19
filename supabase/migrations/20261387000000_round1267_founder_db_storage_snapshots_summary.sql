BEGIN;
-- =====================================================================
-- Round 1267 — Founder DB storage snapshots summary
-- =====================================================================
-- Surfaces Postgres-footprint pulse from public.db_storage_snapshots
-- (r601 ledger, 90-day retention, daily 03:13 UTC sweep) + live
-- pg_class lookups. Answers: how big is the DB, top tables, which
-- tables grew fastest WoW, oldest sample, total samples in window.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_db_storage_snapshots_summary();
CREATE OR REPLACE FUNCTION public.founder_db_storage_snapshots_summary()
RETURNS TABLE (
  snapshots_total           bigint,
  distinct_tables_tracked   bigint,
  latest_snapshot_at        timestamptz,
  earliest_snapshot_at      timestamptz,
  snapshot_age_hours        numeric,
  live_total_bytes          bigint,
  live_total_pretty         text,
  live_table_count          bigint,
  largest_table_name        text,
  largest_table_bytes       bigint,
  largest_table_pretty      text,
  prior_total_bytes_7d      bigint,
  delta_bytes_7d            bigint,
  delta_pct_7d              numeric,
  fastest_grower_name       text,
  fastest_grower_delta_pct  numeric,
  bloat_candidate_name      text,
  bloat_bytes_per_row       numeric,
  snapshots_24h             bigint,
  snapshots_7d              bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_snapshots_total         bigint := 0;
  v_distinct_tables         bigint := 0;
  v_latest                  timestamptz;
  v_earliest                timestamptz;
  v_age_hours               numeric := 0;
  v_live_total              bigint := 0;
  v_live_count              bigint := 0;
  v_largest_name            text;
  v_largest_bytes           bigint := 0;
  v_prior_total             bigint := 0;
  v_delta_bytes             bigint := 0;
  v_delta_pct               numeric;
  v_fast_name               text;
  v_fast_pct                numeric;
  v_bloat_name              text;
  v_bloat_ratio             numeric;
  v_snap_24h                bigint := 0;
  v_snap_7d                 bigint := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*), count(DISTINCT table_name), max(snapshot_at), min(snapshot_at)
    INTO v_snapshots_total, v_distinct_tables, v_latest, v_earliest
    FROM public.db_storage_snapshots;

  IF v_latest IS NOT NULL THEN
    v_age_hours := round(EXTRACT(EPOCH FROM (now() - v_latest))::numeric / 3600.0, 2);
  END IF;

  SELECT count(*) INTO v_snap_24h
    FROM public.db_storage_snapshots
    WHERE snapshot_at >= now() - interval '24 hours';

  SELECT count(*) INTO v_snap_7d
    FROM public.db_storage_snapshots
    WHERE snapshot_at >= now() - interval '7 days';

  SELECT
    coalesce(sum(pg_total_relation_size(c.oid)), 0)::bigint,
    count(*)::bigint
  INTO v_live_total, v_live_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind = 'r';

  SELECT c.relname::text, pg_total_relation_size(c.oid)
    INTO v_largest_name, v_largest_bytes
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relkind = 'r'
   ORDER BY pg_total_relation_size(c.oid) DESC
   LIMIT 1;

  -- 7-day-ago snapshot total (sum of per-table latest <= now-7d).
  WITH prior AS (
    SELECT DISTINCT ON (s.table_name)
      s.table_name, s.total_bytes
    FROM public.db_storage_snapshots s
    WHERE s.snapshot_at <= now() - interval '7 days'
    ORDER BY s.table_name, s.snapshot_at DESC
  )
  SELECT coalesce(sum(total_bytes), 0)::bigint INTO v_prior_total FROM prior;

  IF v_prior_total > 0 THEN
    v_delta_bytes := v_live_total - v_prior_total;
    v_delta_pct   := round(((v_live_total - v_prior_total)::numeric / v_prior_total::numeric) * 100.0, 2);
  ELSE
    v_delta_bytes := 0;
    v_delta_pct   := NULL;
  END IF;

  -- Fastest-grower WoW: per table compare live vs 7d-ago snapshot,
  -- filter to tables that had >= 1 MB then so % is meaningful.
  WITH prior AS (
    SELECT DISTINCT ON (s.table_name)
      s.table_name, s.total_bytes AS prior_bytes
    FROM public.db_storage_snapshots s
    WHERE s.snapshot_at <= now() - interval '7 days'
    ORDER BY s.table_name, s.snapshot_at DESC
  ),
  live AS (
    SELECT c.relname::text AS table_name, pg_total_relation_size(c.oid) AS live_bytes
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'r'
  )
  SELECT l.table_name,
         round(((l.live_bytes - p.prior_bytes)::numeric / p.prior_bytes::numeric) * 100.0, 2)
    INTO v_fast_name, v_fast_pct
  FROM live l
  JOIN prior p ON p.table_name = l.table_name
  WHERE p.prior_bytes >= 1048576
    AND l.live_bytes > p.prior_bytes
  ORDER BY ((l.live_bytes - p.prior_bytes)::numeric / p.prior_bytes::numeric) DESC
  LIMIT 1;

  -- Bloat candidate: live bytes-per-row anomaly. Filter to tables
  -- with >= 100 rows + >= 1 MB total. Highest bytes/row wins (often
  -- JSONB payload columns or large TOAST tables).
  SELECT c.relname::text,
         round(pg_total_relation_size(c.oid)::numeric / NULLIF(c.reltuples, 0), 1)
    INTO v_bloat_name, v_bloat_ratio
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public'
     AND c.relkind = 'r'
     AND c.reltuples >= 100
     AND pg_total_relation_size(c.oid) >= 1048576
   ORDER BY pg_total_relation_size(c.oid)::numeric / NULLIF(c.reltuples, 0) DESC NULLS LAST
   LIMIT 1;

  RETURN QUERY SELECT
    v_snapshots_total,
    v_distinct_tables,
    v_latest,
    v_earliest,
    v_age_hours,
    v_live_total,
    pg_size_pretty(v_live_total),
    v_live_count,
    v_largest_name,
    v_largest_bytes,
    pg_size_pretty(v_largest_bytes),
    v_prior_total,
    v_delta_bytes,
    v_delta_pct,
    v_fast_name,
    v_fast_pct,
    v_bloat_name,
    v_bloat_ratio,
    v_snap_24h,
    v_snap_7d;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_db_storage_snapshots_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_db_storage_snapshots_summary() TO authenticated;

COMMIT;
