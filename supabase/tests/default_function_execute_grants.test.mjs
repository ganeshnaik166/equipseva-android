// Disposable PostgreSQL-compatible proof for future function EXECUTE defaults.
// The legacy and schema-only databases are negative controls. No production
// catalog, credentials, functions, or customer rows are used.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { PGlite } = require(process.env.EQS_PGLITE_PACKAGE || '@electric-sql/pglite');
const here = path.dirname(fileURLToPath(import.meta.url));
const migrationPath = path.resolve(here, '../migrations/20263906000000_round3829_restrict_future_function_execute.sql');
// Before the implementation is written, run the same candidate assertions
// against the legacy state. They must fail, establishing a test-first RED.
const migration = await readFile(migrationPath, 'utf8').catch((e) => {
  if (e.code === 'ENOENT') return '';
  throw e;
});

const fixture = `
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='supabase_admin') THEN CREATE ROLE supabase_admin NOLOGIN; END IF;
END $$;
CREATE SCHEMA extensions;
CREATE SCHEMA storage;
GRANT USAGE ON SCHEMA public, extensions, storage TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA storage
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;
CREATE FUNCTION public.existing_client_rpc() RETURNS integer
  LANGUAGE sql AS $$ SELECT 7 $$;
REVOKE ALL ON FUNCTION public.existing_client_rpc() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.existing_client_rpc() TO authenticated, service_role;
CREATE FUNCTION public.existing_worker_rpc() RETURNS integer
  LANGUAGE sql SECURITY DEFINER AS $$ SELECT 9 $$;
REVOKE ALL ON FUNCTION public.existing_worker_rpc() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.existing_worker_rpc() TO service_role;
`;
const schemaOnly = `
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated;
`;

const currentAcl = (db) => db.query(`
  SELECT p.oid::regprocedure::text AS sig, p.proacl::text AS acl
  FROM pg_proc p WHERE p.oid IN (
    'public.existing_client_rpc()'::regprocedure,
    'public.existing_worker_rpc()'::regprocedure
  ) ORDER BY 1
`).then((r) => r.rows);
const defaultAcl = (db, owner, schema) => db.query(`
  SELECT d.defaclacl::text AS acl
  FROM pg_default_acl d
  WHERE d.defaclrole=$1::regrole AND d.defaclnamespace=$2::regnamespace
    AND d.defaclobjtype='f'
`, [owner, schema]).then((r) => r.rows[0]?.acl ?? null);
const grant = (db, role, signature) => db.query(
  `SELECT has_function_privilege($1,$2,'EXECUTE') AS allowed`, [role, signature],
).then((r) => r.rows[0].allowed);
async function as(db, role, sql) {
  return db.transaction(async (tx) => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    return tx.query(sql);
  });
}
async function denied(action) {
  await assert.rejects(action, (e) => e.code === '42501');
}
async function makeProbes(db) {
  await db.exec(`
    CREATE FUNCTION public.new_unlisted_rpc() RETURNS integer LANGUAGE sql AS $$ SELECT 11 $$;
    CREATE FUNCTION public.new_client_rpc() RETURNS integer LANGUAGE sql AS $$ SELECT 12 $$;
    GRANT EXECUTE ON FUNCTION public.new_client_rpc() TO authenticated;
    CREATE FUNCTION extensions.new_extension_helper() RETURNS integer LANGUAGE sql AS $$ SELECT 13 $$;
    CREATE FUNCTION storage.new_storage_helper() RETURNS integer LANGUAGE sql AS $$ SELECT 14 $$;
  `);
}
async function build(extra = '') {
  const db = await PGlite.create();
  await db.exec(fixture);
  const oldAcl = await currentAcl(db);
  const adminAcl = await defaultAcl(db, 'supabase_admin', 'public');
  if (extra) await db.exec(extra);
  await makeProbes(db);
  return { db, oldAcl, adminAcl };
}

const legacy = await build();
const limited = await build(schemaOnly);
const candidate = await build(migration);
let passed = 0;
const failures = [];
async function check(name, fn) {
  try { await fn(); passed++; console.log(`PASS ${name}`); }
  catch (e) { failures.push(`${name}: ${e.message}`); console.log(`FAIL ${name}: ${e.message}`); }
}

await check('legacy control: PUBLIC plus direct client grants expose a new RPC', async () => {
  for (const role of ['anon', 'authenticated', 'service_role'])
    assert.equal(await grant(legacy.db, role, 'public.new_unlisted_rpc()'), true);
  assert.match((await defaultAcl(legacy.db, 'postgres', 'public')), /anon=X/);
});
await check('schema-only REVOKE control: implicit global PUBLIC EXECUTE still exposes RPC', async () => {
  assert.equal(await grant(limited.db, 'anon', 'public.new_unlisted_rpc()'), true);
  assert.equal(await grant(limited.db, 'authenticated', 'public.new_unlisted_rpc()'), true);
  assert.doesNotMatch((await defaultAcl(limited.db, 'postgres', 'public')), /anon=X/);
});
await check('candidate catalog: postgres global PUBLIC and public client defaults are absent', async () => {
  const r = await candidate.db.query(`
    SELECT d.defaclnamespace, a.grantee, a.privilege_type
    FROM pg_default_acl d CROSS JOIN LATERAL aclexplode(d.defaclacl) a
    WHERE d.defaclrole='postgres'::regrole AND d.defaclobjtype='f'
      AND d.defaclnamespace IN (0, 'public'::regnamespace)
  `);
  const global = r.rows.filter((x) => x.defaclnamespace === 0);
  assert(global.length > 0, 'global override is missing');
  assert(!global.some((x) => x.grantee === 0 && x.privilege_type === 'EXECUTE'));
  const publicAcl = await defaultAcl(candidate.db, 'postgres', 'public');
  assert(publicAcl, 'postgres/public default ACL is missing');
  assert.doesNotMatch(publicAcl, /anon=X|authenticated=X/);
  assert.match(publicAcl, /service_role=X/);
});
await check('candidate new unlisted public RPC denies both client roles and retains service_role', async () => {
  await denied(() => as(candidate.db, 'anon', 'SELECT public.new_unlisted_rpc()'));
  await denied(() => as(candidate.db, 'authenticated', 'SELECT public.new_unlisted_rpc()'));
  assert.equal((await as(candidate.db, 'service_role', 'SELECT public.new_unlisted_rpc() AS n')).rows[0].n, 11);
});
await check('explicit authenticated grant restores only the intended new client RPC', async () => {
  assert.equal((await as(candidate.db, 'authenticated', 'SELECT public.new_client_rpc() AS n')).rows[0].n, 12);
  await denied(() => as(candidate.db, 'anon', 'SELECT public.new_client_rpc()'));
});
await check('existing client and worker ACLs are byte-identical and callable by their prior roles', async () => {
  assert.deepEqual(await currentAcl(candidate.db), candidate.oldAcl);
  assert.equal((await as(candidate.db, 'authenticated', 'SELECT public.existing_client_rpc() AS n')).rows[0].n, 7);
  await denied(() => as(candidate.db, 'anon', 'SELECT public.existing_client_rpc()'));
  assert.equal((await as(candidate.db, 'service_role', 'SELECT public.existing_worker_rpc() AS n')).rows[0].n, 9);
  await denied(() => as(candidate.db, 'authenticated', 'SELECT public.existing_worker_rpc()'));
});
await check('CREATE OR REPLACE keeps old client ACL; DROP + CREATE needs a new grant', async () => {
  await candidate.db.exec(`CREATE OR REPLACE FUNCTION public.existing_client_rpc() RETURNS integer LANGUAGE sql AS $$ SELECT 8 $$;`);
  assert.equal((await as(candidate.db, 'authenticated', 'SELECT public.existing_client_rpc() AS n')).rows[0].n, 8);
  await candidate.db.exec(`DROP FUNCTION public.existing_client_rpc();
    CREATE FUNCTION public.existing_client_rpc() RETURNS integer LANGUAGE sql AS $$ SELECT 10 $$;`);
  await denied(() => as(candidate.db, 'authenticated', 'SELECT public.existing_client_rpc()'));
  assert.equal((await as(candidate.db, 'service_role', 'SELECT public.existing_client_rpc() AS n')).rows[0].n, 10);
  await candidate.db.exec(`GRANT EXECUTE ON FUNCTION public.existing_client_rpc() TO authenticated;`);
  assert.equal((await as(candidate.db, 'authenticated', 'SELECT public.existing_client_rpc() AS n')).rows[0].n, 10);
});
await check('global PUBLIC revoke also protects future extensions-schema helpers', async () => {
  await denied(() => as(candidate.db, 'anon', 'SELECT extensions.new_extension_helper()'));
  await denied(() => as(candidate.db, 'authenticated', 'SELECT extensions.new_extension_helper()'));
  await denied(() => as(candidate.db, 'service_role', 'SELECT extensions.new_extension_helper()'));
  await candidate.db.exec(`GRANT EXECUTE ON FUNCTION extensions.new_extension_helper() TO authenticated, service_role;`);
  assert.equal((await as(candidate.db, 'authenticated', 'SELECT extensions.new_extension_helper() AS n')).rows[0].n, 13);
});
await check('additive storage-schema defaults still grant client EXECUTE', async () => {
  for (const role of ['anon', 'authenticated', 'service_role'])
    assert.equal((await as(candidate.db, role, 'SELECT storage.new_storage_helper() AS n')).rows[0].n, 14);
});
await check('supabase_admin defaults remain untouched', async () => {
  assert.equal(await defaultAcl(candidate.db, 'supabase_admin', 'public'), candidate.adminAcl);
});
await check('forward migration is idempotent', async () => {
  assert(migration, 'migration file is absent');
  await candidate.db.exec(migration);
  assert.equal(await defaultAcl(candidate.db, 'supabase_admin', 'public'), candidate.adminAcl);
  assert.equal(await grant(candidate.db, 'anon', 'public.new_unlisted_rpc()'), false);
});
await check('catalog gate rejects reintroduced direct anon EXECUTE', async () => {
  const tampered = migration.replace('DO $gate$', `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO anon;\nDO $gate$`);
  assert.notEqual(tampered, migration, 'catalog gate is missing');
  const { db } = await build();
  await assert.rejects(() => db.exec(tampered), /round3829: postgres\/public client function EXECUTE remains/);
});
await check('catalog gate rejects reintroduced global PUBLIC EXECUTE', async () => {
  const tampered = migration.replace('DO $gate$', `ALTER DEFAULT PRIVILEGES FOR ROLE postgres
    GRANT EXECUTE ON FUNCTIONS TO PUBLIC;\nDO $gate$`);
  assert.notEqual(tampered, migration, 'catalog gate is missing');
  const { db } = await build();
  // PostgreSQL may collapse the restored built-in ACL to "no override";
  // either representation must fail the gate.
  await assert.rejects(() => db.exec(tampered), /round3829: postgres global (function default override missing|PUBLIC function EXECUTE remains)/);
});

console.log(`\ndefault-function-grants: ${passed}/13 checks passed; ${failures.length} failed`);
if (failures.length) { console.log(failures.join('\n')); process.exitCode = 1; }
