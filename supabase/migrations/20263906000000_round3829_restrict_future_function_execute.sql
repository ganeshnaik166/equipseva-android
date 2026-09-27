-- Round 3829: future postgres-created functions must not inherit client EXECUTE.
--
-- Round 3828 restricted nine existing money RPCs, but the production catalog
-- still has direct anon/authenticated default EXECUTE grants for functions
-- created by postgres in public. PostgreSQL also grants function EXECUTE to
-- PUBLIC by default. A per-schema REVOKE from PUBLIC cannot remove that global
-- default; it must be revoked globally for the creating role.
--
-- Existing function ACLs are deliberately unchanged. service_role retains its
-- public-schema default so new server callers keep their current grant model.
-- New client RPCs and DROP+CREATE recreations must explicitly GRANT EXECUTE to
-- authenticated (or anon, only after an intentional public-access review).
-- The global PUBLIC change also affects other schemas, but additive per-schema
-- grants still apply (production currently has them in storage). In a schema
-- without such grants (currently extensions), grant required callers explicitly.
-- supabase_admin is a separate creator role and is not modified here.
BEGIN;

CREATE TEMP TABLE _r3829_existing_public_acl ON COMMIT DROP AS
SELECT p.oid, p.proacl
  FROM pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace;

CREATE TEMP TABLE _r3829_admin_default_acl ON COMMIT DROP AS
SELECT d.oid, d.defaclacl
  FROM pg_default_acl d
 WHERE d.defaclrole = 'supabase_admin'::regrole
   AND d.defaclobjtype = 'f'
   AND d.defaclnamespace = 'public'::regnamespace;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;

DO $gate$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
     WHERE d.defaclrole = 'postgres'::regrole
       AND d.defaclnamespace = 0
       AND d.defaclobjtype = 'f'
  ) THEN
    RAISE EXCEPTION 'round3829: postgres global function default override missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) a
     WHERE d.defaclrole = 'postgres'::regrole
       AND d.defaclnamespace = 0
       AND d.defaclobjtype = 'f'
       AND a.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole)
       AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'round3829: postgres global client or PUBLIC function EXECUTE remains';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) a
     WHERE d.defaclrole = 'postgres'::regrole
       AND d.defaclnamespace = 'public'::regnamespace
       AND d.defaclobjtype = 'f'
       AND a.privilege_type = 'EXECUTE'
       AND a.grantee IN (0, 'anon'::regrole, 'authenticated'::regrole)
  ) THEN
    RAISE EXCEPTION 'round3829: postgres/public client function EXECUTE remains';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
    CROSS JOIN LATERAL aclexplode(d.defaclacl) a
     WHERE d.defaclrole = 'postgres'::regrole
       AND d.defaclnamespace = 'public'::regnamespace
       AND d.defaclobjtype = 'f'
       AND a.grantee = 'service_role'::regrole
       AND a.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'round3829: postgres/public service_role function EXECUTE lost';
  END IF;

  IF EXISTS (
    SELECT 1 FROM _r3829_existing_public_acl before_acl
    LEFT JOIN pg_proc p ON p.oid = before_acl.oid
     WHERE p.oid IS NULL OR p.proacl IS DISTINCT FROM before_acl.proacl
  ) THEN
    RAISE EXCEPTION 'round3829: existing public function ACL changed';
  END IF;

  IF EXISTS (
    SELECT 1 FROM _r3829_admin_default_acl before_acl
    LEFT JOIN pg_default_acl d ON d.oid = before_acl.oid
     WHERE d.oid IS NULL OR d.defaclacl IS DISTINCT FROM before_acl.defaclacl
  ) THEN
    RAISE EXCEPTION 'round3829: supabase_admin/public function defaults changed';
  END IF;
END
$gate$;

COMMIT;
