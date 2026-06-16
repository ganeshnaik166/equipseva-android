-- =====================================================================
-- Round 603 — Founder RLS coverage check
-- =====================================================================
--
-- Across 600+ migrations, a new table without ENABLE ROW LEVEL SECURITY
-- is a silent CVE. r603 ships a founder-only RPC that enumerates public
-- tables and flags any with RLS off + zero policies + non-zero
-- anon/authenticated grants. The ops view sorts the riskiest rows
-- first so the founder can patch + REVOKE before the audit catches it.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_rls_coverage();

CREATE OR REPLACE FUNCTION public.founder_rls_coverage()
RETURNS TABLE (
  table_name        text,
  rls_enabled       boolean,
  policy_count      int,
  anon_select       boolean,
  anon_insert       boolean,
  authenticated_select boolean,
  authenticated_insert boolean,
  risk_score        int
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
  WITH tables AS (
    SELECT
      c.relname::text                       AS table_name,
      c.oid                                 AS toid,
      c.relrowsecurity                      AS rls_enabled
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
  ),
  policies AS (
    SELECT p.tablename AS table_name, count(*)::int AS policy_count
    FROM pg_policies p
    WHERE p.schemaname = 'public'
    GROUP BY p.tablename
  ),
  grants AS (
    SELECT
      t.toid                                          AS toid,
      has_table_privilege('anon', t.toid, 'SELECT')   AS anon_select,
      has_table_privilege('anon', t.toid, 'INSERT')   AS anon_insert,
      has_table_privilege('authenticated', t.toid, 'SELECT') AS authenticated_select,
      has_table_privilege('authenticated', t.toid, 'INSERT') AS authenticated_insert
    FROM tables t
  )
  SELECT
    t.table_name,
    t.rls_enabled,
    coalesce(p.policy_count, 0)                AS policy_count,
    g.anon_select,
    g.anon_insert,
    g.authenticated_select,
    g.authenticated_insert,
    -- Risk heuristic. Each contribution stacks.
    (CASE WHEN NOT t.rls_enabled AND coalesce(p.policy_count, 0) = 0
            AND (g.anon_select OR g.authenticated_select) THEN 100 ELSE 0 END) +
    (CASE WHEN NOT t.rls_enabled AND (g.anon_insert OR g.authenticated_insert) THEN 50 ELSE 0 END) +
    (CASE WHEN g.anon_select AND t.rls_enabled AND coalesce(p.policy_count, 0) = 0 THEN 20 ELSE 0 END) +
    (CASE WHEN coalesce(p.policy_count, 0) = 0 AND t.rls_enabled THEN 10 ELSE 0 END)
                                                AS risk_score
  FROM tables t
  LEFT JOIN policies p ON p.table_name = t.table_name
  LEFT JOIN grants g ON g.toid = t.toid
  ORDER BY risk_score DESC, t.table_name ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_rls_coverage() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_rls_coverage() TO authenticated;

COMMENT ON FUNCTION public.founder_rls_coverage() IS
  'r603: founder-only RLS coverage check. Joins pg_class + pg_policies + has_table_privilege per role; computes a risk_score so highest-risk tables surface first.';

COMMIT;
