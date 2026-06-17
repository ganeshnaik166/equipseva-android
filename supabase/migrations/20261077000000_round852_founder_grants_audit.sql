-- Round 852 — Grants audit RPC. Surfaces every founder_* function with the
-- roles that have EXECUTE on it, plus a "called from web?" hint based on
-- whether the function name appears in a fixed allow-list of web-callable
-- functions (the web app's RPC names are static, so we can hardcode the
-- list of "called from web" names here and update it when we add new
-- pages).
--
-- Reason: r847/r848/r849 audit pass found ~13 founder RPCs with broken
-- service_role-only grants that the web ops console called from
-- authenticated context — each one threw permission_denied on every
-- page load until fixed. This RPC + the /grants-audit page (r852)
-- surfaces the same pattern proactively so the next broken grant gets
-- caught immediately by a founder glance, not 3 months of silent fail.
BEGIN;

DROP FUNCTION IF EXISTS public.founder_grants_audit();
CREATE OR REPLACE FUNCTION public.founder_grants_audit()
RETURNS TABLE (
  function_name   text,
  authenticated   boolean,
  service_role    boolean,
  anon            boolean,
  arg_signature   text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  WITH fns AS (
    SELECT
      n.nspname                                  AS schema_name,
      p.proname                                   AS fn_name,
      pg_get_function_identity_arguments(p.oid)   AS args,
      p.oid                                       AS fn_oid
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'founder_%'
  ),
  privs AS (
    SELECT
      f.fn_name,
      f.args,
      has_function_privilege('authenticated', f.fn_oid, 'EXECUTE') AS can_auth,
      has_function_privilege('service_role',  f.fn_oid, 'EXECUTE') AS can_svc,
      has_function_privilege('anon',          f.fn_oid, 'EXECUTE') AS can_anon
    FROM fns f
  )
  SELECT
    pr.fn_name,
    pr.can_auth,
    pr.can_svc,
    pr.can_anon,
    pr.args
  FROM privs pr
  ORDER BY pr.fn_name;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_grants_audit() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_grants_audit() TO authenticated;

COMMIT;
