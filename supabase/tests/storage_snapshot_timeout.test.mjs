import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';

const require = createRequire(import.meta.url);
const { PGlite } = require(process.env.EQS_PGLITE_PACKAGE || '@electric-sql/pglite');
const baseline = await readFile(new URL('../migrations/20260860000000_round601_storage_snapshots.sql', import.meta.url), 'utf8');
const candidate = await readFile(new URL('../migrations/20263899000000_round3822_storage_snapshot_timeout.sql', import.meta.url), 'utf8');
console.log(`Snapshot migration SHA256: ${createHash('sha256').update(candidate).digest('hex')}`);

async function setup() {
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE ROLE anon NOLOGIN;
      CREATE ROLE authenticated NOLOGIN;
      CREATE ROLE service_role NOLOGIN;
      CREATE ROLE public_only NOLOGIN;
      CREATE ROLE authenticator NOLOGIN;
      ALTER ROLE authenticator SET statement_timeout = '8s';
      ALTER ROLE authenticator SET lock_timeout = '8s';
      GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role, public_only;
      CREATE FUNCTION public.is_founder() RETURNS boolean LANGUAGE sql AS 'SELECT false';
    `);
    // Execute the whole historical migration, including grants and soft cron fallback.
    await db.exec(baseline);
    return db;
  } catch (error) {
    await db.close();
    throw error;
  }
}

async function metadata(db) {
  return (await db.query(`SELECT p.oid::text, p.proowner::text, p.proacl::text,
    p.prosrc, p.prosecdef, p.provolatile, p.proparallel, p.proisstrict,
    p.proleakproof, p.prorettype::text, p.proargtypes::text, p.prolang::text,
    p.proconfig FROM pg_proc p WHERE p.oid=to_regprocedure('public.db_storage_snapshot_sweep()')`)).rows[0];
}

async function environment(db) {
  return (await db.query(`SELECT 'role' AS kind, rolname AS name, rolconfig::text AS settings
    FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','authenticator')
    UNION ALL SELECT 'database', setdatabase::text || ':' || setrole::text, setconfig::text
    FROM pg_db_role_setting ORDER BY kind,name`)).rows;
}

async function invoke(db, role) {
  assert(['anon', 'authenticated', 'public_only', 'service_role'].includes(role));
  return db.transaction(async tx => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    return (await tx.query('SELECT public.db_storage_snapshot_sweep() AS inserted')).rows[0].inserted;
  });
}

function withoutTimeout(value) {
  return { ...value, proconfig: value.proconfig.filter(s => !s.startsWith('statement_timeout=')) };
}

await test('actual migration changes only the function budget and reapplies without other changes', async () => {
  const db = await setup();
  try {
    const before = await metadata(db);
    const settings = await environment(db);
    const founderBefore = (await db.query("SELECT pg_get_functiondef('public.founder_db_storage_with_delta()'::regprocedure) AS def")).rows;
    assert.equal(before.proconfig.some(s => s.startsWith('statement_timeout=')), false);
    await db.exec(candidate);
    const first = await metadata(db);
    assert.deepEqual(withoutTimeout(first), before);
    assert.deepEqual(first.proconfig.filter(s => s.startsWith('statement_timeout=')), ['statement_timeout=30s']);
    await db.exec(candidate);
    assert.deepEqual(await metadata(db), first);
    assert.deepEqual(await environment(db), settings);
    assert.deepEqual((await db.query("SELECT pg_get_functiondef('public.founder_db_storage_with_delta()'::regprocedure) AS def")).rows, founderBefore);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM public.db_storage_snapshots')).rows[0].n, 0);
  } finally { await db.close(); }
});

await test('reset rollback restores original metadata and ledger, then actual migration can reapply', async () => {
  const db = await setup();
  try {
    const before = await metadata(db);
    await db.exec(`INSERT INTO public.db_storage_snapshots(table_name,total_bytes,est_row_count)
      VALUES ('saved_history',123,4)`);
    const ledger = (await db.query('SELECT * FROM public.db_storage_snapshots')).rows;
    await db.exec(candidate);
    // Recorded prior state has no function timeout. RESET ALL would erase its safe search path.
    await db.exec(`BEGIN;
      ALTER FUNCTION public.db_storage_snapshot_sweep() RESET statement_timeout;
      NOTIFY pgrst, 'reload schema';
      COMMIT;`);
    assert.deepEqual(await metadata(db), before);
    assert.deepEqual((await db.query('SELECT * FROM public.db_storage_snapshots')).rows, ledger);
    await db.exec(candidate);
    assert.deepEqual(withoutTimeout(await metadata(db)), before);
  } finally { await db.close(); }
});

for (const role of ['anon', 'authenticated', 'public_only']) {
  await test(`migrated writer denies actual ${role} execution and preserves ledger`, async () => {
    const db = await setup();
    try {
      await db.exec(candidate);
      await assert.rejects(() => invoke(db, role), error => error.code === '42501');
      assert.equal((await db.query('SELECT count(*)::int AS n FROM public.db_storage_snapshots')).rows[0].n, 0);
    } finally { await db.close(); }
  });
}

await test('service invocation preserves relation selection, measured values, retention and append semantics', async () => {
  const db = await setup();
  try {
    await db.exec(candidate);
    await db.exec(`
      CREATE TABLE public.sample(id int PRIMARY KEY, payload text);
      INSERT INTO public.sample SELECT i, repeat(md5(i::text),100) FROM generate_series(1,50) i;
      ANALYZE public.sample;
      CREATE TABLE public.unknown_estimate(id int);
      CREATE TABLE public.partition_parent(id int) PARTITION BY RANGE(id);
      CREATE TABLE public.partition_leaf PARTITION OF public.partition_parent FOR VALUES FROM(0) TO(100);
      CREATE VIEW public.excluded_view AS SELECT * FROM public.sample;
      CREATE MATERIALIZED VIEW public.excluded_materialized AS SELECT id FROM public.sample;
      CREATE SCHEMA private_fixture;
      CREATE TABLE private_fixture.excluded_table(id int);
    `);
    const expected = ['db_storage_snapshots','partition_leaf','sample','unknown_estimate'];
    // Use one transaction's now() to make the strict ninety-day boundary deterministic.
    await db.transaction(async tx => {
      await tx.exec(`INSERT INTO public.db_storage_snapshots(table_name,snapshot_at,total_bytes,est_row_count)
        VALUES ('expired',now()-interval '90 days 1 microsecond',1,1),
               ('boundary',now()-interval '90 days',2,2),
               ('recent',now()-interval '89 days',3,3)`);
      const expectedValues = (await tx.query(`SELECT c.relname AS name,
        pg_total_relation_size(c.oid)::text AS bytes,c.reltuples::bigint::text AS estimate
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relkind='r' AND c.relname<>'db_storage_snapshots'
        ORDER BY name`)).rows;
      await tx.exec('SET LOCAL ROLE service_role');
      assert.equal((await tx.query('SELECT public.db_storage_snapshot_sweep() AS n')).rows[0].n, expected.length);
      await tx.exec('RESET ROLE');
      const names = (await tx.query('SELECT table_name FROM public.db_storage_snapshots WHERE snapshot_at=now() ORDER BY table_name')).rows.map(r => r.table_name);
      assert.deepEqual(names, expected);
      const actualValues = (await tx.query(`SELECT table_name AS name,total_bytes::text AS bytes,
        est_row_count::text AS estimate FROM public.db_storage_snapshots
        WHERE snapshot_at=now() AND table_name<>'db_storage_snapshots' ORDER BY name`)).rows;
      assert.deepEqual(actualValues, expectedValues);
      assert.equal(actualValues.find(r => r.name==='unknown_estimate').estimate, '-1');
      assert.deepEqual((await tx.query(`SELECT table_name FROM public.db_storage_snapshots
        WHERE table_name IN ('expired','boundary','recent') ORDER BY table_name`)).rows.map(r=>r.table_name), ['boundary','recent']);
      // Each explicit success appends, even when calls share a transaction timestamp.
      await tx.exec('SET LOCAL ROLE service_role');
      assert.equal((await tx.query('SELECT public.db_storage_snapshot_sweep() AS n')).rows[0].n, expected.length);
      await tx.exec('RESET ROLE');
      const batches = (await tx.query(`SELECT table_name,count(*)::int AS n FROM public.db_storage_snapshots
        WHERE snapshot_at=now() GROUP BY table_name ORDER BY table_name`)).rows;
      assert.deepEqual(batches, expected.map(table_name=>({table_name,n:2})));
    });
  } finally { await db.close(); }
});

const driftCases = [
  ['missing writer', 'DROP FUNCTION public.db_storage_snapshot_sweep()', 'missing_function'],
  ['modified body', `CREATE OR REPLACE FUNCTION public.db_storage_snapshot_sweep()
    RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp
    AS 'BEGIN RETURN 0; END;'`, 'unexpected_function_body'],
  ['security invoker', 'ALTER FUNCTION public.db_storage_snapshot_sweep() SECURITY INVOKER', 'unexpected_function_contract'],
  ['stable writer', 'ALTER FUNCTION public.db_storage_snapshot_sweep() STABLE', 'unexpected_function_contract'],
  ['parallel safe writer', 'ALTER FUNCTION public.db_storage_snapshot_sweep() PARALLEL SAFE', 'unexpected_function_contract'],
  ['strict writer', 'ALTER FUNCTION public.db_storage_snapshot_sweep() STRICT', 'unexpected_function_contract'],
  ['leakproof writer', 'ALTER FUNCTION public.db_storage_snapshot_sweep() LEAKPROOF', 'unexpected_function_contract'],
  ['unsafe search path', 'ALTER FUNCTION public.db_storage_snapshot_sweep() SET search_path=public', 'unexpected_function_settings'],
  ['missing search path', 'ALTER FUNCTION public.db_storage_snapshot_sweep() RESET search_path', 'unexpected_function_settings'],
  ['unlimited timeout', "ALTER FUNCTION public.db_storage_snapshot_sweep() SET statement_timeout='0'", 'unexpected_function_settings'],
  ['unreviewed longer timeout', "ALTER FUNCTION public.db_storage_snapshot_sweep() SET statement_timeout='60s'", 'unexpected_function_settings'],
  ['function lock override', "ALTER FUNCTION public.db_storage_snapshot_sweep() SET lock_timeout='30s'", 'unexpected_function_settings'],
  ['public access', 'GRANT EXECUTE ON FUNCTION public.db_storage_snapshot_sweep() TO PUBLIC', 'unexpected_function_access'],
  ['authenticated access', 'GRANT EXECUTE ON FUNCTION public.db_storage_snapshot_sweep() TO authenticated', 'unexpected_function_access'],
  ['anonymous access', 'GRANT EXECUTE ON FUNCTION public.db_storage_snapshot_sweep() TO anon', 'unexpected_function_access'],
  ['extra caller access', 'GRANT EXECUTE ON FUNCTION public.db_storage_snapshot_sweep() TO public_only', 'unexpected_function_access'],
  ['service grant option', 'GRANT EXECUTE ON FUNCTION public.db_storage_snapshot_sweep() TO service_role WITH GRANT OPTION', 'unexpected_function_access'],
  ['missing service access', 'REVOKE EXECUTE ON FUNCTION public.db_storage_snapshot_sweep() FROM service_role', 'unexpected_function_access'],
];

await test('unexpected source, contract, settings and access fail atomically', async t => {
  const db = await setup();
  try {
    await db.exec(`INSERT INTO public.db_storage_snapshots(table_name,total_bytes,est_row_count)
      VALUES ('preserved_history',456,7)`);
    const ledger = (await db.query('SELECT * FROM public.db_storage_snapshots')).rows;
    const settings = await environment(db);
    for (const [name, mutation, detail] of driftCases) {
      await t.test(name, async () => {
        // Reset to the actual original writer; each drift has an independent starting state.
        await db.exec(baseline);
        await db.exec(mutation);
        const before = await metadata(db);
        try {
          await assert.rejects(() => db.exec(candidate), error => {
            assert.equal(error.code, '55000');
            assert.equal(error.message, 'storage_snapshot_timeout_precondition_failed');
            assert.equal(error.detail, detail);
            return true;
          });
        } finally {
          // The actual migration has BEGIN/COMMIT; a failed preflight aborts its transaction.
          await db.exec('ROLLBACK');
        }
        assert.deepEqual(await metadata(db), before);
        assert.deepEqual(await environment(db), settings);
        assert.deepEqual((await db.query('SELECT * FROM public.db_storage_snapshots')).rows, ledger);
      });
    }
  } finally { await db.close(); }
});
