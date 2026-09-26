// Round 3827 — engineer nearby-jobs feed restored.
//
// Proves supabase/migrations/20263904000000_round3827_nearby_repair_jobs_definer_restore.sql
// in two disposable PGlite databases built from the same fixtures:
//
//   LEGACY — the three historical definitions of list_nearby_repair_jobs
//            (20260425073000, 20260428160000, 20260627010000) applied in
//            order: the production state, SECURITY INVOKER.
//   NEW    — LEGACY plus round3826 (for engineer_coarse_coord) and round3827,
//            round3827 applied twice to prove it re-applies cleanly.
//
// The CONTROL properties must pass on NEW and fail on LEGACY; the legacy
// failure must be SQLSTATE 42501 (the organizations coordinate-column
// lockdown), proving the regression this migration fixes. NEW-ONLY properties
// cover the visibility rule, clamps and grants that the legacy definition
// cannot be exercised on, because every engineer call to it fails.
//
// Run: EQS_PGLITE_PACKAGE=<extracted @electric-sql/pglite@0.5.8/package> \
//        node supabase/tests/nearby_repair_jobs_feed.test.mjs

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
const baseFixture = await read(path.join(here, 'engineer_location_privacy.fixture.sql'));
const addendum = await read(path.join(here, 'nearby_repair_jobs_feed.fixture.sql'));
const LEGACY = [
  '20260425073000_nearby_repair_jobs_rpc.sql',
  '20260428160000_security_nearby_repair_jobs_definer.sql',
  '20260627010000_nearby_repair_jobs_clamp_radius.sql',
];
const legacySql = await Promise.all(LEGACY.map((f) => read(path.join(migrations, f))));
const s1Sql = await read(path.join(migrations, '20263903000000_round3826_engineer_location_privacy_sealed_bids.sql'));
const s2Sql = await read(path.join(migrations, '20263904000000_round3827_nearby_repair_jobs_definer_restore.sql'));

const uid = (n) => `10000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const eid = (n) => `20000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const jid = (n) => `30000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const oid = (n) => `40000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const HOSPITAL = uid(1), ENG_A_USER = uid(3), ENG_B_USER = uid(4), ENG_N_USER = uid(8);
const ENG_A = eid(3), ENG_B = eid(4), ENG_N = eid(8);
const A_BASE = { lat: 17.4234, lng: 78.4731 };
const ORG_NEAR = { id: oid(1), lat: 17.3850, lng: 78.4867 };   // ~4.5 km from A
const ORG_MID = { id: oid(2), lat: 17.6868, lng: 78.4011 };    // ~30 km from A
const ORG_FAR = { id: oid(3), lat: 19.0760, lng: 72.8777 };    // ~620 km from A (Mumbai)
const J_OPEN_NEAR = jid(1), J_OPEN_MID = jid(2), J_ASSIGNED_A = jid(3), J_ASSIGNED_B = jid(4), J_DONE = jid(5), J_FAR = jid(6);

const seedSql = `
INSERT INTO public.profiles(id, full_name, role, roles, active_role) VALUES
  ('${HOSPITAL}', 'City Hospital', 'hospital_admin', '{hospital_admin}', 'hospital_admin'),
  ('${ENG_A_USER}', 'Asha', 'engineer', '{engineer}', 'engineer'),
  ('${ENG_B_USER}', 'Bala', 'engineer', '{engineer}', 'engineer'),
  ('${ENG_N_USER}', 'Neha (no base)', 'engineer', '{engineer}', 'engineer');
INSERT INTO public.engineers(id, user_id, city, latitude, longitude, verification_status) VALUES
  ('${ENG_A}', '${ENG_A_USER}', 'x', ${A_BASE.lat}, ${A_BASE.lng}, 'verified'),
  ('${ENG_B}', '${ENG_B_USER}', 'x', 17.4849, 78.4138, 'verified'),
  ('${ENG_N}', '${ENG_N_USER}', 'x', NULL, NULL, 'verified');
INSERT INTO public.organizations(id, name, latitude, longitude) VALUES
  ('${ORG_NEAR.id}', 'Near Hospital', ${ORG_NEAR.lat}, ${ORG_NEAR.lng}),
  ('${ORG_MID.id}', 'Mid Hospital', ${ORG_MID.lat}, ${ORG_MID.lng}),
  ('${ORG_FAR.id}', 'Far Hospital', ${ORG_FAR.lat}, ${ORG_FAR.lng});
INSERT INTO public.repair_jobs(id, hospital_user_id, hospital_org_id, engineer_id, status, job_number, created_at) VALUES
  ('${J_OPEN_NEAR}', '${HOSPITAL}', '${ORG_NEAR.id}', NULL, 'requested', 'RPR-1', now() - interval '3 hours'),
  ('${J_OPEN_MID}', '${HOSPITAL}', '${ORG_MID.id}', NULL, 'requested', 'RPR-2', now() - interval '2 hours'),
  ('${J_ASSIGNED_A}', '${HOSPITAL}', '${ORG_NEAR.id}', '${ENG_A}', 'assigned', 'RPR-3', now() - interval '1 hour'),
  ('${J_ASSIGNED_B}', '${HOSPITAL}', '${ORG_NEAR.id}', '${ENG_B}', 'assigned', 'RPR-4', now()),
  ('${J_DONE}', '${HOSPITAL}', '${ORG_NEAR.id}', '${ENG_A}', 'completed', 'RPR-5', now()),
  ('${J_FAR}', '${HOSPITAL}', '${ORG_FAR.id}', NULL, 'requested', 'RPR-6', now());
`;

function haversineKm(lat1, lng1, lat2, lng2) {
  const r = (d) => (d * Math.PI) / 180;
  const a = Math.sin(r(lat2 - lat1) / 2) ** 2 + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lng2 - lng1) / 2) ** 2;
  return 6371.0 * 2 * Math.asin(Math.sqrt(a));
}
const onGrid = (x) => Math.abs(Number(x) / 0.05 - Math.round(Number(x) / 0.05)) < 1e-7;

async function as(db, actor, sql, params = []) {
  const { sub = '', role = 'authenticated' } = actor;
  return db.transaction(async (tx) => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    await tx.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [sub]);
    return tx.query(sql, params);
  });
}
const feed = (db, actor, radius = 50, limit = 100) =>
  as(db, actor, 'SELECT * FROM public.list_nearby_repair_jobs($1::double precision, $2::int)', [radius, limit]).then((r) => r.rows);
const A = { sub: ENG_A_USER }, B = { sub: ENG_B_USER }, N = { sub: ENG_N_USER }, H = { sub: HOSPITAL }, ANON = { role: 'anon' };
const ids = (rows) => rows.map((r) => r.id);

const PROPERTIES = [
  { kind: 'control', name: 'an engineer with a saved base gets open nearby jobs at the default 50 km', run: async (db) => {
    const rows = await feed(db, A);
    assert(ids(rows).includes(J_OPEN_NEAR) && ids(rows).includes(J_OPEN_MID), `got ${ids(rows)}`);
  } },
  { kind: 'control', name: 'hospital coordinates in the feed are on the coarse 0.05° grid', run: async (db) => {
    const rows = await feed(db, A);
    assert(rows.length > 0);
    for (const r of rows) assert(onGrid(r.hospital_latitude) && onGrid(r.hospital_longitude), `exact coordinate leaked: ${r.hospital_latitude},${r.hospital_longitude}`);
  } },

  { kind: 'new-only', name: 'assigned jobs are visible only to the assigned engineer', run: async (db) => {
    const a = ids(await feed(db, A)), b = ids(await feed(db, B));
    assert(a.includes(J_ASSIGNED_A) && !a.includes(J_ASSIGNED_B), `A saw ${a}`);
    assert(b.includes(J_ASSIGNED_B) && !b.includes(J_ASSIGNED_A), `B saw ${b}`);
  } },
  { kind: 'new-only', name: 'completed jobs are never listed', run: async (db) => {
    assert(!ids(await feed(db, A)).includes(J_DONE));
  } },
  { kind: 'new-only', name: 'radius is filtered and clamped to 500 km', run: async (db) => {
    assert(!ids(await feed(db, A, 10)).includes(J_OPEN_MID), '30 km job inside a 10 km radius');
    assert(!ids(await feed(db, A, 99999)).includes(J_FAR), 'radius not clamped: 620 km job returned');
    assert(ids(await feed(db, A, 700)).length === ids(await feed(db, A, 500)).length, 'radius above 500 must behave like 500');
  } },
  { kind: 'new-only', name: 'limit is clamped to 1..200', run: async (db) => {
    assert.equal((await feed(db, A, 50, 0)).length, 1);
    // 250 extra open jobs so the upper clamp is actually exercised, removed afterwards.
    await db.query(`INSERT INTO public.repair_jobs(id, hospital_user_id, hospital_org_id, status, job_number)
      SELECT ('50000000-0000-0000-0000-' || lpad(g::text, 12, '0'))::uuid, $1::uuid, $2::uuid, 'requested', 'BULK-' || g
      FROM generate_series(1, 250) g`, [HOSPITAL, ORG_NEAR.id]);
    try {
      assert.equal((await feed(db, A, 50, 100000)).length, 200, 'upper clamp must cap at exactly 200 rows');
      assert.equal((await feed(db, A, 50, 150)).length, 150, 'limits inside the range are honoured');
    } finally {
      await db.query("DELETE FROM public.repair_jobs WHERE job_number LIKE 'BULK-%'");
    }
  } },
  { kind: 'new-only', name: 'distance is the exact travel distance and the feed is ordered by it', run: async (db) => {
    const rows = await feed(db, A);
    const near = rows.find((r) => r.id === J_OPEN_NEAR);
    assert(Math.abs(Number(near.distance_km) - haversineKm(A_BASE.lat, A_BASE.lng, ORG_NEAR.lat, ORG_NEAR.lng)) < 1e-6);
    for (let i = 1; i < rows.length; i++) assert(Number(rows[i - 1].distance_km) <= Number(rows[i].distance_km) + 1e-9);
  } },
  { kind: 'new-only', name: 'non-engineers and engineers without a base get no rows; anon cannot execute', run: async (db) => {
    assert.equal((await feed(db, H)).length, 0);
    assert.equal((await feed(db, N)).length, 0);
    await assert.rejects(() => feed(db, ANON), (e) => { assert.equal(e.code, '42501'); return true; });
  } },
  { kind: 'new-only', name: 'SECURITY DEFINER with a pinned search_path; authenticated-only EXECUTE', run: async (db) => {
    const f = (await db.query("SELECT prosecdef, proconfig FROM pg_proc WHERE proname = 'list_nearby_repair_jobs'")).rows;
    assert.equal(f.length, 1);
    assert.equal(f[0].prosecdef, true);
    assert((f[0].proconfig || []).some((c) => c.startsWith('search_path=')));
    const priv = async (role) => (await db.query("SELECT has_function_privilege($1, 'public.list_nearby_repair_jobs(double precision,integer)', 'EXECUTE') AS ok", [role])).rows[0].ok;
    assert.equal(await priv('authenticated'), true);
    assert.equal(await priv('anon'), false);
  } },
];

async function build(withNew) {
  const db = await PGlite.create();
  await db.exec(baseFixture);
  await db.exec(addendum);
  for (const sql of legacySql) await db.exec(sql);
  if (withNew) { await db.exec(s1Sql); await db.exec(s2Sql); await db.exec(s2Sql); }
  await db.exec(seedSql);
  return db;
}

const legacy = await build(false);
const fresh = await build(true);
const problems = [];
let newPass = 0, controlsFailed = 0;
for (const p of PROPERTIES) {
  try { await p.run(fresh); newPass++; console.log(`PASS  new     ${p.kind.padEnd(9)} ${p.name}`); }
  catch (e) { problems.push(`NEW must pass: ${p.name}: ${e.message}`); console.log(`FAIL  new     ${p.kind.padEnd(9)} ${p.name}: ${e.message}`); }
  if (p.kind !== 'control') continue;
  try {
    await p.run(legacy);
    problems.push(`NEGATIVE CONTROL passed on LEGACY: ${p.name}`);
    console.log(`UNEXPECTED legacy pass: ${p.name}`);
  } catch (e) {
    if (e.code === '42501') { controlsFailed++; console.log(`FAIL  legacy  control   ${p.name} (expected 42501: ${e.message})`); }
    else { problems.push(`LEGACY failed for an unexpected reason (want 42501): ${p.name}: ${e.code || ''} ${e.message}`); console.log(`FAIL  legacy  control   ${p.name}: unexpected ${e.code} ${e.message}`); }
  }
}
const controls = PROPERTIES.filter((p) => p.kind === 'control').length;
console.log('\n==== summary ====');
console.log(`new definition:     ${newPass}/${PROPERTIES.length} properties pass`);
console.log(`negative controls:  ${controlsFailed}/${controls} fail on the legacy definition with SQLSTATE 42501 (expected all)`);
if (problems.length) { console.log('\nPROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('\nALL EXPECTATIONS MET');
