// Round 3826 — engineer location privacy and sealed bids.
//
// Proves supabase/migrations/20263903000000_round3826_engineer_location_privacy_sealed_bids.sql
// in two disposable PGlite databases built from the same fixture:
//
//   LEGACY — the five previous definitions loaded from their own historical
//            migration files (round350, round731, round732, round3761,
//            round3767), i.e. the production state the audit measured.
//   NEW    — LEGACY plus the round3826 migration (applied twice, to prove it
//            re-applies cleanly).
//
// Every PRIVACY property must PASS on NEW and FAIL on LEGACY. The LEGACY
// failures are the negative controls: they show each assertion really detects
// the leak it names. REGRESSION properties must pass on both; STRUCTURE
// properties describe the new catalog shape and run on NEW only.
//
// Run (Node 24, no network, no credentials):
//   EQS_PGLITE_PACKAGE=/path/to/extracted/@electric-sql/pglite@0.5.8/package \
//     node supabase/tests/engineer_location_privacy.test.mjs
// or `npm install @electric-sql/pglite@0.5.8` in supabase/tests and omit the env var.

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
const fixtureSql = await read(path.join(here, 'engineer_location_privacy.fixture.sql'));
const LEGACY_FILES = [
  '20260707600000_round350_directory_min_rating.sql',
  '20260980000000_round731_directory_search_with_tier.sql',
  '20260981000000_round732_recommended_engineers_with_tier.sql',
  '20263861000000_round3761_engineer_public_profile_multirole_and_ambiguous_id_fix.sql',
  '20263867000000_round3767_list_repair_job_bids_with_distance_founder_check.sql',
];
const NEW_FILE = '20263903000000_round3826_engineer_location_privacy_sealed_bids.sql';
const legacySql = await Promise.all(LEGACY_FILES.map((f) => read(path.join(migrations, f))));
const newSql = await read(path.join(migrations, NEW_FILE));

// ---- synthetic identities ----------------------------------------------
const uid = (n) => `10000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const eid = (n) => `20000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const jid = (n) => `30000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const HOSPITAL = uid(1), OUTSIDER = uid(2), FOUNDER = uid(5);
const ENG_A_USER = uid(3), ENG_B_USER = uid(4), ENG_M_USER = uid(6), ENG_U_USER = uid(7);
const ENG_A = eid(3), ENG_B = eid(4), ENG_M = eid(6), ENG_U = eid(7);
const JOB = jid(1);
const A_EXACT = { lat: 17.4234, lng: 78.4731 };   // ~2.6 km / ~2.5 km from its grid point
const B_EXACT = { lat: 17.4849, lng: 78.4138 };
const M_EXACT = { lat: 17.4432, lng: 78.3918 };
const SITE = { lat: 17.3850, lng: 78.4867 };
const A_FULL_CITY = '12 MG Road, Banjara Hills, Hyderabad, Telangana';
const B_FULL_CITY = 'Plot 7, Kukatpally, Hyderabad, Telangana';
const SANITISED = 'Hyderabad, Telangana';

const seedSql = `
INSERT INTO public.profiles(id, full_name, phone, email, role, roles, active_role) VALUES
  ('${HOSPITAL}', 'City Hospital', '+910000000001', 'hospital@fixture.test', 'hospital_admin', '{hospital_admin}', 'hospital_admin'),
  ('${OUTSIDER}', 'Other Hospital', '+910000000002', 'other@fixture.test', 'hospital_admin', '{hospital_admin}', 'hospital_admin'),
  ('${FOUNDER}', 'Founder', '+910000000005', 'founder@fixture.test', 'hospital_admin', '{hospital_admin}', 'hospital_admin'),
  ('${ENG_A_USER}', 'Asha Engineer', '+910000000003', 'asha@fixture.test', 'engineer', '{engineer}', 'engineer'),
  ('${ENG_B_USER}', 'Bala Engineer', '+910000000004', 'bala@fixture.test', 'engineer', '{engineer}', 'engineer'),
  ('${ENG_M_USER}', 'Meena MultiRole', '+910000000006', 'meena@fixture.test', 'hospital_admin', '{hospital_admin,engineer}', 'hospital_admin'),
  ('${ENG_U_USER}', 'Uma Unverified', '+910000000007', 'uma@fixture.test', 'engineer', '{engineer}', 'engineer');
INSERT INTO public.engineers(id, user_id, city, state, service_areas, specializations, brands_serviced, oem_training_badges,
  experience_years, rating_avg, total_jobs, hourly_rate, bio, is_available, latitude, longitude, completion_rate,
  verification_status, service_radius_km) VALUES
  ('${ENG_A}', '${ENG_A_USER}', '${A_FULL_CITY}', 'Telangana', '{Hyderabad}', '{imaging}', '{GE}', '{}',
   8, 4.8, 40, 900, 'MRI and CT', true, ${A_EXACT.lat}, ${A_EXACT.lng}, 97, 'verified', 30),
  ('${ENG_B}', '${ENG_B_USER}', '${B_FULL_CITY}', 'Telangana', '{Rangareddy}', '{monitoring}', '{Philips}', '{}',
   3, 3.9, 12, 700, 'Patient monitors', true, ${B_EXACT.lat}, ${B_EXACT.lng}, 90, 'verified', 25),
  ('${ENG_M}', '${ENG_M_USER}', 'Flat 2, Madhapur, Hyderabad, Telangana', 'Telangana', '{Hyderabad}', '{dental}', '{}', '{}',
   5, 4.1, 9, 800, 'Dental chairs', true, ${M_EXACT.lat}, ${M_EXACT.lng}, 88, 'verified', 20),
  ('${ENG_U}', '${ENG_U_USER}', 'Hidden, Hyderabad, Telangana', 'Telangana', '{Hyderabad}', '{imaging}', '{}', '{}',
   1, 5.0, 1, 500, 'Not verified', true, 17.40, 78.40, 100, 'pending', 10);
INSERT INTO public.engineer_certification_progress(engineer_user_id, current_tier) VALUES ('${ENG_A_USER}', 'gold');
INSERT INTO public.repair_jobs(id, hospital_user_id, engineer_id, status, site_latitude, site_longitude)
  VALUES ('${JOB}', '${HOSPITAL}', '${ENG_A}', 'completed', ${SITE.lat}, ${SITE.lng});
INSERT INTO public.repair_job_bids(repair_job_id, engineer_user_id, amount_rupees, eta_hours, note, status, created_at) VALUES
  ('${JOB}', '${ENG_A_USER}', 5000, 4, 'A private note', 'pending', now() - interval '2 hours'),
  ('${JOB}', '${ENG_B_USER}', 4200, 6, 'B private note', 'pending', now() - interval '1 hour');
`;

// ---- helpers ------------------------------------------------------------
const grid = (x) => Math.round(x / 0.05) * 0.05;
function haversineKm(lat1, lng1, lat2, lng2) {
  const r = (d) => (d * Math.PI) / 180;
  const a = Math.sin(r(lat2 - lat1) / 2) ** 2
    + Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lng2 - lng1) / 2) ** 2;
  return 6371.0 * 2 * Math.asin(Math.sqrt(a));
}
const close = (a, b, eps = 1e-6) => Math.abs(Number(a) - Number(b)) <= eps;

async function as(db, actor, sql, params = []) {
  const { sub = '', role = 'authenticated', email = '' } = actor;
  return db.transaction(async (tx) => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    await tx.query(
      "SELECT set_config('request.jwt.claim.sub',$1,true), set_config('request.jwt.claim.email',$2,true)",
      [sub, email],
    );
    return tx.query(sql, params);
  });
}
const ANON = { role: 'anon' };
const hospital = { sub: HOSPITAL };
const outsider = { sub: OUTSIDER };
const founder = { sub: FOUNDER, email: 'founder@fixture.test' };
const engA = { sub: ENG_A_USER };
const engB = { sub: ENG_B_USER };

async function denied(action, code = '42501') {
  await assert.rejects(action, (e) => { assert.equal(e.code, code, `expected ${code}, got ${e.code}: ${e.message}`); return true; });
}

// The Android app always sends every parameter, p_min_rating included.
const DIR_CALL = `SELECT * FROM public.engineers_directory_search(
  p_query => NULL, p_district => $3::text, p_specialization => NULL, p_brand => NULL,
  p_limit => 50, p_offset => 0, p_hospital_lat => $1::double precision, p_hospital_lng => $2::double precision,
  p_sort_mode => $4::text, p_min_rating => $5::numeric)`;
const dir = (db, actor, { lat = null, lng = null, district = null, sort = 'rating', minRating = null } = {}) =>
  as(db, actor, DIR_CALL, [lat, lng, district, sort, minRating]).then((r) => r.rows);
const recommended = (db, actor, lat, lng) =>
  as(db, actor, 'SELECT * FROM public.recommended_engineers_for_hospital($1::double precision, $2::double precision, NULL, 20)', [lat, lng]).then((r) => r.rows);
const profile = (db, actor, id) =>
  as(db, actor, 'SELECT * FROM public.engineer_public_profile($1::uuid)', [id]).then((r) => r.rows[0]);
const bids = (db, actor) =>
  as(db, actor, 'SELECT * FROM public.list_repair_job_bids_with_distance($1::uuid)', [JOB]).then((r) => r.rows);
const PROBES = [
  { lat: 17.30, lng: 78.30 }, { lat: 17.60, lng: 78.35 }, { lat: 17.45, lng: 78.70 },
];

// ---- properties ---------------------------------------------------------
const PROPERTIES = [
  { kind: 'privacy', name: 'anon cannot recover exact engineer coordinates from engineer_public_profile', run: async (db) => {
    const p = await profile(db, ANON, ENG_A);
    assert(p, 'profile row expected');
    // The attack: subtract the md5-derived offset an attacker can compute from the public engineer id.
    const off = (await db.query(
      `SELECT ((('x' || substr(md5($1::text || ':lat'), 1, 4))::bit(16)::int % 200 - 100) / 10000.0)::float8 AS dlat,
              ((('x' || substr(md5($1::text || ':lng'), 1, 4))::bit(16)::int % 200 - 100) / 10000.0)::float8 AS dlng`, [ENG_A])).rows[0];
    const recLat = Number(p.base_latitude) - Number(off.dlat);
    const recLng = Number(p.base_longitude) - Number(off.dlng);
    assert(!(close(recLat, A_EXACT.lat, 1e-7) && close(recLng, A_EXACT.lng, 1e-7)), 'md5 offset subtraction recovered the exact base location');
    assert(close(p.base_latitude, grid(A_EXACT.lat), 1e-9) && close(p.base_longitude, grid(A_EXACT.lng), 1e-9), 'coordinates must be the 0.05° grid point');
  } },
  { kind: 'privacy', name: 'directory distances trilaterate only the coarse grid point, never the exact base', run: async (db) => {
    for (const pt of PROBES) {
      const row = (await dir(db, ANON, { lat: pt.lat, lng: pt.lng })).find((r) => r.engineer_id === ENG_A);
      assert(row, 'engineer A must be listed');
      assert(close(row.distance_km, haversineKm(pt.lat, pt.lng, grid(A_EXACT.lat), grid(A_EXACT.lng))), `distance ${row.distance_km} is not measured from the grid point`);
      assert(Math.abs(Number(row.distance_km) - haversineKm(pt.lat, pt.lng, A_EXACT.lat, A_EXACT.lng)) > 0.05, 'distance still measured from the exact base');
    }
  } },
  { kind: 'privacy', name: 'recommended distances use the coarse grid point', run: async (db) => {
    for (const pt of PROBES) {
      const row = (await recommended(db, hospital, pt.lat, pt.lng)).find((r) => r.engineer_id === ENG_A);
      assert(row, 'engineer A must be recommended');
      assert(close(row.distance_km, haversineKm(pt.lat, pt.lng, grid(A_EXACT.lat), grid(A_EXACT.lng))), 'recommended distance is not from the grid point');
    }
  } },
  { kind: 'privacy', name: 'recommended returns the sanitised address, not the KYC address', run: async (db) => {
    const row = (await recommended(db, hospital, SITE.lat, SITE.lng)).find((r) => r.engineer_id === ENG_A);
    assert.equal(row.city, SANITISED);
  } },
  { kind: 'privacy', name: 'anon cannot execute recommended_engineers_for_hospital', run: async (db) => {
    await denied(() => recommended(db, ANON, SITE.lat, SITE.lng));
  } },
  { kind: 'privacy', name: 'a bidder sees only their own bid (sealed bids)', run: async (db) => {
    const rows = await bids(db, engB);
    assert.equal(rows.length, 1, `bidder saw ${rows.length} bids`);
    assert.equal(rows[0].engineer_user_id, ENG_B_USER);
    assert(!rows.some((r) => r.note === 'A private note' || Number(r.amount_rupees) === 5000), 'competitor bid leaked');
  } },
  { kind: 'privacy', name: 'bid list gives the hospital the sanitised bidder address', run: async (db) => {
    const rows = await bids(db, hospital);
    assert.equal(rows.length, 2);
    for (const r of rows) assert.equal(r.engineer_city, SANITISED);
  } },
  { kind: 'privacy', name: 'bid distance uses the coarse grid point', run: async (db) => {
    const a = (await bids(db, hospital)).find((r) => r.engineer_user_id === ENG_A_USER);
    assert(close(a.distance_km, haversineKm(SITE.lat, SITE.lng, grid(A_EXACT.lat), grid(A_EXACT.lng))), 'bid distance is not from the grid point');
  } },
  { kind: 'privacy', name: 'directory returns current_tier through the overload the app reaches', run: async (db) => {
    const row = (await dir(db, ANON)).find((r) => r.engineer_id === ENG_A);
    assert.equal(row.current_tier, 'gold');
  } },
  { kind: 'privacy', name: 'verified multi-role engineer appears in directory and recommendations', run: async (db) => {
    assert((await dir(db, ANON)).some((r) => r.engineer_id === ENG_M), 'multi-role engineer missing from directory');
    assert((await recommended(db, hospital, SITE.lat, SITE.lng)).some((r) => r.engineer_id === ENG_M), 'multi-role engineer missing from recommendations');
  } },

  { kind: 'regression', name: 'engineer sees their own exact coordinates and full address', run: async (db) => {
    const p = await profile(db, engA, ENG_A);
    assert(close(p.base_latitude, A_EXACT.lat, 1e-9) && close(p.base_longitude, A_EXACT.lng, 1e-9));
    assert.equal(p.city, A_FULL_CITY);
  } },
  { kind: 'regression', name: 'founder sees exact coordinates, full address and raw bidder address', run: async (db) => {
    const p = await profile(db, founder, ENG_A);
    assert(close(p.base_latitude, A_EXACT.lat, 1e-9));
    assert.equal(p.city, A_FULL_CITY);
    const rows = await bids(db, founder);
    assert.equal(rows.length, 2);
    assert.equal(rows.find((r) => r.engineer_user_id === ENG_A_USER).engineer_city, A_FULL_CITY);
  } },
  { kind: 'regression', name: 'contacts stay gated: anon sees none, the hospital that hired the engineer sees them', run: async (db) => {
    assert.equal((await profile(db, ANON, ENG_A)).phone, null);
    assert.equal((await profile(db, hospital, ENG_A)).phone, '+910000000003');
    assert.equal((await profile(db, outsider, ENG_A)).phone, null);
  } },
  { kind: 'regression', name: 'profile address is sanitised for non-owners', run: async (db) => {
    assert.equal((await profile(db, hospital, ENG_A)).city, SANITISED);
  } },
  { kind: 'regression', name: 'the posting hospital sees every bid on its job', run: async (db) => {
    assert.equal((await bids(db, hospital)).length, 2);
  } },
  { kind: 'regression', name: 'outsiders and anon cannot read bids', run: async (db) => {
    await denied(() => bids(db, outsider));
    await denied(() => bids(db, ANON));
  } },
  { kind: 'regression', name: 'unverified engineers are never listed', run: async (db) => {
    assert(!(await dir(db, ANON)).some((r) => r.engineer_id === ENG_U));
    assert(!(await recommended(db, hospital, SITE.lat, SITE.lng)).some((r) => r.engineer_id === ENG_U));
    assert.equal(await profile(db, ANON, ENG_U), undefined);
  } },
  { kind: 'regression', name: 'directory address is sanitised for anon', run: async (db) => {
    for (const r of await dir(db, ANON)) assert(r.city.split(',').length <= 2, `unsanitised city: ${r.city}`);
  } },
  { kind: 'regression', name: 'min-rating and district filters still apply', run: async (db) => {
    const high = await dir(db, ANON, { minRating: 4.5 });
    assert(high.some((r) => r.engineer_id === ENG_A) && !high.some((r) => r.engineer_id === ENG_B));
    const rr = await dir(db, ANON, { district: 'Rangareddy' });
    assert.deepEqual(rr.map((r) => r.engineer_id), [ENG_B]);
  } },
  { kind: 'regression', name: "'nearest' sort still orders by distance", run: async (db) => {
    const rows = await dir(db, ANON, { lat: B_EXACT.lat + 0.01, lng: B_EXACT.lng, sort: 'nearest' });
    assert.equal(rows[0].engineer_id, ENG_B, `first was ${rows[0].engineer_id}`);
    for (let i = 1; i < rows.length; i++) assert(Number(rows[i - 1].distance_km) <= Number(rows[i].distance_km) + 1e-9);
  } },

  { kind: 'structure', name: 'exactly one directory overload remains and a call without p_min_rating still resolves', run: async (db) => {
    const n = (await db.query("SELECT count(*)::int AS n FROM pg_proc WHERE proname = 'engineers_directory_search'")).rows[0].n;
    assert.equal(n, 1);
    const rows = (await as(db, ANON, `SELECT engineer_id FROM public.engineers_directory_search(
      p_query => NULL, p_district => NULL, p_specialization => NULL, p_brand => NULL,
      p_limit => 50, p_offset => 0, p_hospital_lat => NULL, p_hospital_lng => NULL, p_sort_mode => 'rating')`)).rows;
    assert(rows.length >= 3);
  } },
  { kind: 'structure', name: 'definer and search_path kept; helper internal; grants as intended', run: async (db) => {
    const fns = (await db.query(`SELECT proname, prosecdef, proconfig FROM pg_proc WHERE proname IN
      ('engineer_public_profile','engineers_directory_search','recommended_engineers_for_hospital','list_repair_job_bids_with_distance','engineer_coarse_coord')`)).rows;
    assert.equal(fns.length, 5);
    for (const f of fns) {
      assert((f.proconfig || []).some((c) => c.startsWith('search_path=')), `${f.proname} lost its pinned search_path`);
      if (f.proname !== 'engineer_coarse_coord') assert.equal(f.prosecdef, true, `${f.proname} lost SECURITY DEFINER`);
    }
    const priv = async (role, sig) => (await db.query('SELECT has_function_privilege($1, $2, $3) AS ok', [role, sig, 'EXECUTE'])).rows[0].ok;
    const helper = 'public.engineer_coarse_coord(double precision)';
    const dirSig = 'public.engineers_directory_search(text,text,text,text,int,int,double precision,double precision,text,numeric)';
    const recSig = 'public.recommended_engineers_for_hospital(double precision,double precision,text,int)';
    const bidSig = 'public.list_repair_job_bids_with_distance(uuid)';
    assert.equal(await priv('anon', helper), false);
    assert.equal(await priv('authenticated', helper), false);
    assert.equal(await priv('anon', dirSig), true);
    assert.equal(await priv('authenticated', dirSig), true);
    assert.equal(await priv('anon', recSig), false);
    assert.equal(await priv('authenticated', recSig), true);
    assert.equal(await priv('anon', bidSig), false);
    assert.equal(await priv('authenticated', bidSig), true);
    assert.equal(await priv('anon', 'public.engineer_public_profile(uuid)'), true);
  } },
];

// ---- run ----------------------------------------------------------------
async function build(withNew) {
  const db = await PGlite.create();
  await db.exec(fixtureSql);
  for (const sql of legacySql) await db.exec(sql);
  if (withNew) { await db.exec(newSql); await db.exec(newSql); }
  await db.exec(seedSql);
  return db;
}

const legacy = await build(false);
const fresh = await build(true);
const problems = [];
let newPass = 0, controlsFailed = 0, legacyRegressionPass = 0;
const count = (k) => PROPERTIES.filter((p) => p.kind === k).length;

for (const p of PROPERTIES) {
  try { await p.run(fresh); newPass++; console.log(`PASS  new     ${p.kind.padEnd(10)} ${p.name}`); }
  catch (e) { problems.push(`NEW must pass: ${p.name}: ${e.message}`); console.log(`FAIL  new     ${p.kind.padEnd(10)} ${p.name}: ${e.message}`); }
  if (p.kind === 'structure') continue;
  try {
    await p.run(legacy);
    if (p.kind === 'privacy') { problems.push(`NEGATIVE CONTROL passed on LEGACY (assertion detects nothing): ${p.name}`); console.log(`UNEXPECTED legacy ${p.name} passed`); }
    else { legacyRegressionPass++; console.log(`PASS  legacy  ${p.kind.padEnd(10)} ${p.name}`); }
  } catch (e) {
    if (p.kind === 'privacy') { controlsFailed++; console.log(`FAIL  legacy  privacy    ${p.name} (expected: ${e.message.split('\n')[0]})`); }
    else { problems.push(`REGRESSION broken on LEGACY baseline: ${p.name}: ${e.message}`); console.log(`FAIL  legacy  regression ${p.name}: ${e.message}`); }
  }
}

console.log('\n==== summary ====');
console.log(`new definitions:     ${newPass}/${PROPERTIES.length} properties pass`);
console.log(`negative controls:   ${controlsFailed}/${count('privacy')} privacy properties fail on the legacy definitions (expected all)`);
console.log(`legacy regressions:  ${legacyRegressionPass}/${count('regression')} regression properties pass on legacy (expected all)`);
if (problems.length) { console.log('\nPROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('\nALL EXPECTATIONS MET');
