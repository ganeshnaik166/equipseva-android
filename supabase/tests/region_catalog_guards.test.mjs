// Round 3830 under the production guard triggers and a PostgREST-shaped session.
//
// region_catalog.test.mjs runs RPCs with session_user = postgres, which some
// guard functions treat as trusted. This suite installs the latest public
// guard bodies on profiles and engineers (copied verbatim from their
// migrations), emulates a PostgREST request (session_user = authenticator,
// role = authenticated, request.jwt.claims set) and proves:
//   * set_my_home_region and set_my_service_districts still mirror their label
//     text through every guard, without touching guarded columns;
//   * the guards are live (a direct client self-promotion is still refused);
//   * round3830 leaves the catalogue predicates that other migrations pin on
//     profiles and engineers unchanged (user triggers, constraints owned by
//     those tables, indexes, policies, columns, table and schema ACLs, enums).
//
// Run: EQS_PGLITE_PACKAGE=<extracted @electric-sql/pglite@0.5.8/package> \
//        node supabase/tests/region_catalog_guards.test.mjs

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { PGlite } = require(process.env.EQS_PGLITE_PACKAGE || '@electric-sql/pglite');

const here = path.dirname(fileURLToPath(import.meta.url));
const migrations = path.resolve(here, '../migrations');
const read = (p) => readFile(p, 'utf8');
const mig = (name) => read(path.join(migrations, name));
const baseFixture = await read(path.join(here, 'engineer_location_privacy.fixture.sql'));
const fixture = await read(path.join(here, 'region_catalog.fixture.sql'));
const newSql = await mig('20263915000000_round3830_region_catalog_v1.sql');

function block(src, startRe, endMarker) {
  const i = src.search(startRe);
  assert.ok(i >= 0, `guard body not found: ${startRe}`);
  const j = src.indexOf(endMarker, i);
  assert.ok(j > i, `end of guard body not found: ${startRe}`);
  return src.slice(i, j + endMarker.length);
}

// Latest public definitions of each guard (the newest migration that defines it).
const selfEscalation = await mig('20260425063000_allow_self_role_change_except_admin.sql');
const m622 = await mig('20260622100000_v21_medium_six_fixes.sql');
const m428 = await mig('20260428140000_security_trigger_fns_search_path.sql');
const m3806 = await mig('20263891000000_round3806_engineers_verification_timestamp.sql');
const guards = [
  selfEscalation,
  block(m622, /CREATE OR REPLACE FUNCTION public\.profiles_verification_columns_guard\(\)/, '\n$$;'),
  block(m428, /CREATE OR REPLACE FUNCTION public\._sync_profile_roles\(\)/, '\n$$;'),
  block(m3806, /CREATE OR REPLACE FUNCTION public\.stamp_engineer_verification_status_change\(\)/, '\n$fn$;'),
  block(m3806, /CREATE OR REPLACE FUNCTION public\.engineers_trust_columns_guard\(\)/, '\n$function$;'),
].join('\n');

// Columns the guard bodies read, added with production types.
const productionShape = `
ALTER TABLE public.profiles
  ADD COLUMN email_verified boolean DEFAULT false, ADD COLUMN phone_verified boolean DEFAULT false,
  ADD COLUMN role_confirmed boolean DEFAULT false, ADD COLUMN organization_id uuid,
  ADD COLUMN buyer_kyc_status text, ADD COLUMN is_active boolean DEFAULT true, ADD COLUMN updated_at timestamptz;
ALTER TABLE public.engineers
  ADD COLUMN background_check_status text, ADD COLUMN verification_notes text, ADD COLUMN rejected_doc_types text[],
  ADD COLUMN total_earnings numeric, ADD COLUMN cash_auto_suspended_at timestamptz,
  ADD COLUMN cash_auto_suspension_reason text, ADD COLUMN verification_status_updated_at timestamptz;
UPDATE public.engineers SET verification_status = 'pending', verification_status_updated_at = TIMESTAMPTZ '2026-01-01 00:00:00+00';
${guards}
CREATE TRIGGER trg_guard_profile_self_escalation BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_self_escalation();
CREATE TRIGGER profiles_verification_columns_guard_trg BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.profiles_verification_columns_guard();
CREATE TRIGGER trg_sync_profile_roles BEFORE INSERT OR UPDATE OF role, roles, active_role ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public._sync_profile_roles();
CREATE TRIGGER engineers_trust_columns_guard_trg BEFORE INSERT OR UPDATE ON public.engineers
  FOR EACH ROW EXECUTE FUNCTION public.engineers_trust_columns_guard();
CREATE TRIGGER stamp_engineer_verification_status_trg BEFORE INSERT OR UPDATE ON public.engineers
  FOR EACH ROW EXECUTE FUNCTION public.stamp_engineer_verification_status_change();
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator LOGIN NOINHERIT;
  END IF;
END $$;
GRANT anon, authenticated, service_role TO authenticator;
`;

const V = 'synthetic-v2';
const seedSql = `
INSERT INTO public.region_catalog_versions (version, source_url, retrieved_on, sha256, is_current, accepts_writes, is_synthetic) VALUES
  ('${V}', 'synthetic://fixture/v2', DATE '2026-06-01', '${'b'.repeat(64)}', true, true, true);
INSERT INTO public.region_states (code, name_en, kind) VALUES ('901', 'Alpha State', 'state'), ('902', 'Beta Territory', 'union_territory');
INSERT INTO public.region_districts (code, state_code, name_en) VALUES
  ('90101', '901', 'Northfield'), ('90102', '901', 'Riverton'), ('90201', '902', 'Northfield'),
  ('90202', '902', '${'X'.repeat(64)}');
`;

// Catalogue predicates that migrations pinning profiles/engineers read.
const SNAPSHOT = `
SELECT jsonb_build_object(
 'user_triggers', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT tgrelid::regclass::text || ':' || tgname || ':' || pg_get_triggerdef(oid, true) AS x FROM pg_trigger WHERE NOT tgisinternal AND tgrelid IN ('public.profiles'::regclass, 'public.engineers'::regclass)) t),
 'own_constraints', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT conrelid::regclass::text || ':' || conname || ':' || pg_get_constraintdef(oid, true) AS x FROM pg_constraint WHERE conrelid IN ('public.profiles'::regclass, 'public.engineers'::regclass)) t),
 'indexes', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT pg_get_indexdef(indexrelid, 0, true) AS x FROM pg_index WHERE indrelid IN ('public.profiles'::regclass, 'public.engineers'::regclass)) t),
 'policies', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT polrelid::regclass::text || ':' || polname AS x FROM pg_policy WHERE polrelid IN ('public.profiles'::regclass, 'public.engineers'::regclass)) t),
 'columns', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT attrelid::regclass::text || ':' || attnum || ':' || attname || ':' || format_type(atttypid, atttypmod) AS x FROM pg_attribute WHERE attrelid IN ('public.profiles'::regclass, 'public.engineers'::regclass) AND attnum > 0 AND NOT attisdropped) t),
 'table_acl', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT oid::regclass::text || ':' || coalesce(relacl::text, '') AS x FROM pg_class WHERE oid IN ('public.profiles'::regclass, 'public.engineers'::regclass)) t),
 'schema_acl', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT nspname || ':' || coalesce(nspacl::text, '') AS x FROM pg_namespace WHERE nspname IN ('public', 'auth')) t),
 'enums', (SELECT coalesce(jsonb_agg(x ORDER BY x), '[]') FROM (SELECT typname::text AS x FROM pg_type WHERE typnamespace = 'public'::regnamespace AND typtype = 'e') t)
) AS s`;

// One PostgREST-shaped request.
async function rest(db, sub, sql, params = []) {
  try {
    return await db.transaction(async (tx) => {
      await tx.exec('SET LOCAL SESSION AUTHORIZATION authenticator');
      await tx.exec('SET LOCAL ROLE authenticated');
      await tx.query("SELECT set_config('request.jwt.claims', $1, true)", [JSON.stringify({ sub, role: 'authenticated' })]);
      await tx.query("SELECT set_config('request.jwt.claim.sub', $1, true)", [sub]);
      return tx.query(sql, params);
    });
  } finally {
    // PGlite keeps SESSION AUTHORIZATION after commit; restore it explicitly.
    await db.exec('SET SESSION AUTHORIZATION postgres; RESET ROLE');
  }
}

const HOME_USER = 'a0000000-0000-0000-0000-000000000001';
const ENG_USER = 'b0000000-0000-0000-0000-000000000001';
const ENG_ID = 'e0000000-0000-0000-0000-000000000001';

const db = await PGlite.create();
await db.exec(baseFixture);
await db.exec(fixture);
await db.exec(productionShape);
const before = (await db.query(SNAPSHOT)).rows[0].s;
await db.exec(newSql);
await db.exec(newSql);
const after = (await db.query(SNAPSHOT)).rows[0].s;
await db.exec(seedSql);

const results = [];
async function property(name, run) {
  try { await run(); results.push(true); console.log(`PASS  ${name}`); }
  catch (e) { results.push(false); console.log(`FAIL  ${name}: ${e.message}`); }
}

await property('round3830 leaves every pinned catalogue predicate on profiles and engineers unchanged', async () => {
  for (const key of Object.keys(before)) assert.deepEqual(after[key], before[key], `predicate ${key} changed`);
});

await property('the emulated request really is PostgREST-shaped (session authenticator, role authenticated)', async () => {
  const who = (await rest(db, HOME_USER, 'SELECT session_user::text AS su, current_user::text AS cu, auth.uid()::text AS uid')).rows[0];
  assert.deepEqual(who, { su: 'authenticator', cu: 'authenticated', uid: HOME_USER });
});

await property('set_my_home_region mirrors profiles.state/district through the guards', async () => {
  const r = (await rest(db, HOME_USER, 'SELECT public.set_my_home_region($1, $2, $3) AS r', ['901', '90102', V])).rows[0].r;
  assert.equal(r.status, 'resolved');
  const p = (await db.query('SELECT state, district, role FROM public.profiles WHERE id = $1', [HOME_USER])).rows[0];
  assert.deepEqual(p, { state: 'Alpha State', district: 'Riverton', role: 'hospital_admin' });
});

await property('set_my_service_districts mirrors service_areas in order, including a 64-character name, without touching guarded columns', async () => {
  const before = (await db.query('SELECT verification_status, verification_status_updated_at FROM public.engineers WHERE id = $1', [ENG_ID])).rows[0];
  await rest(db, ENG_USER, 'SELECT public.set_my_service_districts($1::text[], $2) AS r', [['90202', '90101'], V]);
  const e = (await db.query('SELECT service_areas, verification_status, verification_status_updated_at FROM public.engineers WHERE id = $1', [ENG_ID])).rows[0];
  assert.deepEqual(e.service_areas, ['X'.repeat(64), 'Northfield']);
  assert.equal(e.verification_status, before.verification_status);
  assert.deepEqual(e.verification_status_updated_at, before.verification_status_updated_at);
});

await property('the guards are live: a direct client self-promotion is still refused', async () => {
  await assert.rejects(
    () => rest(db, HOME_USER, "UPDATE public.profiles SET role = 'admin' WHERE id = $1", [HOME_USER]),
    (e) => { assert.equal(e.code, '42501', `${e.code} ${e.message}`); return true; },
  );
});

const passed = results.filter(Boolean).length;
console.log(`\n==== summary ====\nguards: ${passed}/${results.length} properties pass`);
if (passed !== results.length) process.exitCode = 1;
else console.log('\nALL EXPECTATIONS MET');
