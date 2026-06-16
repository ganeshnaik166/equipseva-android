-- =====================================================================
-- Round 605 — Founder index health view
-- =====================================================================
--
-- Indexes are a two-sided sword: they speed reads but cost writes +
-- disk. Across 600 migrations we've added many. r605 ships a founder
-- view of:
--   1. Indexes never used (idx_scan = 0) — candidates for DROP
--   2. Tables with high seq_scan vs idx_scan ratio — candidates for
--      a new index
--
-- Both signals come from pg_stat_user_tables / pg_stat_user_indexes
-- which Postgres maintains automatically. Numbers reset on cluster
-- restart, so "0 scans" is a soft signal for old indexes only.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_unused_indexes();
CREATE OR REPLACE FUNCTION public.founder_unused_indexes()
RETURNS TABLE (
  schemaname   text,
  table_name   text,
  index_name   text,
  index_size   text,
  idx_scan     bigint
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
    s.schemaname::text,
    s.relname::text                          AS table_name,
    s.indexrelname::text                     AS index_name,
    pg_size_pretty(pg_relation_size(s.indexrelid))  AS index_size,
    s.idx_scan
  FROM pg_stat_user_indexes s
  JOIN pg_index i ON i.indexrelid = s.indexrelid
  WHERE s.schemaname = 'public'
    -- Exclude UNIQUE / PRIMARY indexes — they enforce constraints
    -- even if "unused" for scans.
    AND NOT i.indisunique
    AND NOT i.indisprimary
    AND s.idx_scan = 0
  ORDER BY pg_relation_size(s.indexrelid) DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_unused_indexes() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_unused_indexes() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_seq_scan_heavy();
CREATE OR REPLACE FUNCTION public.founder_seq_scan_heavy()
RETURNS TABLE (
  schemaname     text,
  table_name     text,
  seq_scan       bigint,
  seq_tup_read   bigint,
  idx_scan       bigint,
  idx_tup_fetch  bigint,
  seq_pct        numeric,
  table_size     text
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
    s.schemaname::text,
    s.relname::text  AS table_name,
    s.seq_scan,
    s.seq_tup_read,
    s.idx_scan,
    s.idx_tup_fetch,
    CASE
      WHEN (s.seq_scan + s.idx_scan) = 0 THEN 0::numeric
      ELSE round(s.seq_scan * 100.0 / (s.seq_scan + s.idx_scan), 1)
    END                                          AS seq_pct,
    pg_size_pretty(pg_relation_size(s.relid))    AS table_size
  FROM pg_stat_user_tables s
  WHERE s.schemaname = 'public'
    AND (s.seq_scan + s.idx_scan) >= 100  -- ignore tables with no traffic
    AND s.seq_scan > s.idx_scan          -- and where seq dominates
  ORDER BY s.seq_tup_read DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_seq_scan_heavy() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_seq_scan_heavy() TO authenticated;

COMMIT;
