-- =====================================================================
-- Round 600 — Founder DB storage / table-size ops view
-- =====================================================================
--
-- 600th migration. Surfaces what every operator eventually wants:
-- "which tables are growing fastest, and how much disk are we sitting
-- on?" Without this view we only see storage pressure when Supabase
-- sends a quota email — too late to plan.
--
-- One founder-only SECDEF RPC that aggregates pg_class + pg_relation_
-- size for the public schema tables, returning a curated set with row
-- count estimate, total size (incl. indexes/toast), and table-only
-- size. Sorted by total_bytes DESC so the biggest tables surface
-- first.
--
-- Excludes Supabase internal schemas + extensions; we want public
-- application tables only.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_db_storage();

CREATE OR REPLACE FUNCTION public.founder_db_storage()
RETURNS TABLE (
  table_name     text,
  est_row_count  bigint,
  total_bytes    bigint,
  total_pretty   text,
  table_bytes    bigint,
  table_pretty   text,
  index_bytes    bigint,
  index_pretty   text
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
    c.relname::text                                          AS table_name,
    c.reltuples::bigint                                      AS est_row_count,
    pg_total_relation_size(c.oid)                            AS total_bytes,
    pg_size_pretty(pg_total_relation_size(c.oid))            AS total_pretty,
    pg_relation_size(c.oid)                                  AS table_bytes,
    pg_size_pretty(pg_relation_size(c.oid))                  AS table_pretty,
    (pg_total_relation_size(c.oid) - pg_relation_size(c.oid) - coalesce(pg_relation_size(c.reltoastrelid), 0)) AS index_bytes,
    pg_size_pretty(
      pg_total_relation_size(c.oid) - pg_relation_size(c.oid) - coalesce(pg_relation_size(c.reltoastrelid), 0)
    )                                                        AS index_pretty
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'  -- ordinary tables only (no views, sequences, indexes)
  ORDER BY pg_total_relation_size(c.oid) DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_db_storage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_db_storage() TO authenticated;

COMMENT ON FUNCTION public.founder_db_storage() IS
  'r600: founder-only DB storage breakdown — pg_class + pg_total_relation_size per public table, sorted by total size DESC, capped 100.';

COMMIT;
