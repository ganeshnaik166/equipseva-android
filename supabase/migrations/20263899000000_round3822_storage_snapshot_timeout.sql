-- A table-by-table storage sweep can exceed the REST connection's short
-- request budget. Keep the larger finite budget on this maintenance function;
-- changing a role-wide limit would also extend unrelated requests.
--
-- The body and access contract are pinned because this is a configuration-only
-- change. Unknown source or settings require review instead of being replaced.
-- Reapplication accepts only the original state or this migration's own state.
BEGIN;
SET LOCAL search_path = pg_catalog, pg_temp;

DO $migration$
DECLARE
  v_proc pg_catalog.pg_proc%ROWTYPE;
  v_before jsonb;
  v_after jsonb;
  v_config text[];
  v_service oid := 'service_role'::regrole;
BEGIN
  SELECT * INTO v_proc
    FROM pg_catalog.pg_proc
   WHERE oid = pg_catalog.to_regprocedure('public.db_storage_snapshot_sweep()');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'storage_snapshot_timeout_precondition_failed'
      USING ERRCODE = '55000', DETAIL = 'missing_function';
  END IF;

  IF pg_catalog.md5(pg_catalog.replace(v_proc.prosrc, E'\r\n', E'\n'))
       IS DISTINCT FROM '22986e7aaaa90b1df353c5b582530840' THEN
    RAISE EXCEPTION 'storage_snapshot_timeout_precondition_failed'
      USING ERRCODE = '55000', DETAIL = 'unexpected_function_body';
  END IF;

  IF v_proc.prokind <> 'f' OR v_proc.pronargs <> 0
     OR v_proc.prorettype <> 'integer'::regtype OR v_proc.proretset
     OR v_proc.prolang <> (SELECT oid FROM pg_catalog.pg_language WHERE lanname = 'plpgsql')
     OR NOT v_proc.prosecdef OR v_proc.provolatile <> 'v'
     OR v_proc.proparallel <> 'u' OR v_proc.proisstrict OR v_proc.proleakproof THEN
    RAISE EXCEPTION 'storage_snapshot_timeout_precondition_failed'
      USING ERRCODE = '55000', DETAIL = 'unexpected_function_contract';
  END IF;

  SELECT array_agg(setting ORDER BY setting) INTO v_config
    FROM unnest(v_proc.proconfig) AS settings(setting);
  IF v_config IS DISTINCT FROM ARRAY['search_path=public, pg_temp']
     AND v_config IS DISTINCT FROM ARRAY['search_path=public, pg_temp', 'statement_timeout=30s'] THEN
    RAISE EXCEPTION 'storage_snapshot_timeout_precondition_failed'
      USING ERRCODE = '55000', DETAIL = 'unexpected_function_settings';
  END IF;

  IF NOT pg_catalog.has_function_privilege(v_service, v_proc.oid, 'EXECUTE')
     OR pg_catalog.has_function_privilege('anon', v_proc.oid, 'EXECUTE')
     OR pg_catalog.has_function_privilege('authenticated', v_proc.oid, 'EXECUTE')
     OR EXISTS (
       SELECT 1
         FROM pg_catalog.aclexplode(coalesce(v_proc.proacl, pg_catalog.acldefault('f', v_proc.proowner))) AS permission
        WHERE permission.privilege_type <> 'EXECUTE'
           OR permission.grantee NOT IN (v_proc.proowner, v_service)
           OR (permission.grantee = v_service AND permission.is_grantable)
     ) THEN
    RAISE EXCEPTION 'storage_snapshot_timeout_precondition_failed'
      USING ERRCODE = '55000', DETAIL = 'unexpected_function_access';
  END IF;

  v_before := to_jsonb(v_proc);
  ALTER FUNCTION public.db_storage_snapshot_sweep() SET statement_timeout = '30s';
  SELECT to_jsonb(p) INTO v_after
    FROM pg_catalog.pg_proc AS p
   WHERE p.oid = v_proc.oid;
  SELECT array_agg(setting ORDER BY setting) INTO v_config
    FROM jsonb_array_elements_text(v_after -> 'proconfig') AS settings(setting);

  IF (v_after - 'proconfig') IS DISTINCT FROM (v_before - 'proconfig')
     OR v_config IS DISTINCT FROM ARRAY['search_path=public, pg_temp', 'statement_timeout=30s'] THEN
    RAISE EXCEPTION 'storage_snapshot_timeout_postcondition_failed'
      USING ERRCODE = '55000', DETAIL = 'unexpected_metadata_change';
  END IF;
END;
$migration$;

-- Requests may keep using old cached settings while a reload is pending.
-- Deployment verification must prove the serving cache has refreshed before
-- relying on the new deadline. A notification alone is not readiness evidence.
NOTIFY pgrst, 'reload schema';

COMMIT;
