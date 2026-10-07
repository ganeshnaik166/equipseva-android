// Round 3830 — region catalogue v1 (State/UT and district codes, server
// validation, home-region and service-district write paths).
//
// Proves supabase/migrations/20263915000000_round3830_region_catalog_v1.sql in
// disposable PGlite databases built from synthetic fixtures:
//
//   LEGACY  — base fixture + region fixture (profiles.state/district, the
//             production table grants, Supabase default privileges, synthetic
//             users with legacy free-text labels). No region objects exist.
//   NEW     — LEGACY plus round3830 applied twice, then a synthetic two-version
//             mini-catalogue seeded as the owner (renamed district with an
//             alias, a split with replaced_by, a retired district, a retired
//             State/UT, one district name shared by two States/UTs, an
//             ambiguous legacy alias).
//   UNSEEDED — LEGACY plus round3830 only: the state production is in until an
//             owner-approved LGD snapshot is seeded.
//   MUTANT  — NEW, but built from round3830 with every REVOKE statement and
//             the self-check removed, so Supabase's default privileges stay in
//             force. The grant-focused controls must FAIL here: this proves
//             they detect permissive grants rather than only missing objects.
//
// CONTROL properties must pass on NEW and fail on LEGACY (the feature is
// missing there). REGRESSION properties must pass on both. NEW-ONLY
// properties exercise the migration itself (idempotency, self-check, the
// unseeded state, cascades). Properties run in order on one database each.
//
// Run: EQS_PGLITE_PACKAGE=<extracted @electric-sql/pglite@0.5.8/package> \
//        node supabase/tests/region_catalog.test.mjs

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
const fixture = await read(path.join(here, 'region_catalog.fixture.sql'));
const newSql = await read(path.join(migrations, '20263915000000_round3830_region_catalog_v1.sql'));

const U = {
  home: 'a0000000-0000-0000-0000-000000000001',
  other: 'a0000000-0000-0000-0000-000000000002',
  eng1: 'b0000000-0000-0000-0000-000000000001',
  eng2: 'b0000000-0000-0000-0000-000000000002',
  leg: (n) => `c0000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`,
};
const ENG1 = 'e0000000-0000-0000-0000-000000000001';
const LEG_ENG12 = 'e0000000-0000-0000-0000-000000000012';
const V1 = 'synthetic-v1';
const V2 = 'synthetic-v2';
const SHA = 'a'.repeat(64);

const seedSql = `
INSERT INTO public.region_catalog_versions (version, source_url, retrieved_on, sha256, is_current, accepts_writes, is_synthetic) VALUES
  ('${V1}', 'synthetic://fixture/v1', DATE '2026-01-01', '${SHA}', false, false, true),
  ('${V2}', 'synthetic://fixture/v2', DATE '2026-06-01', '${'b'.repeat(64)}', true, true, true);
INSERT INTO public.region_states (code, name_en, kind, active, introduced_in, retired_in) VALUES
  ('901', 'Alpha State', 'state', true, '${V1}', NULL),
  ('902', 'Beta Territory', 'union_territory', true, '${V1}', NULL),
  ('903', 'Gamma Former State', 'state', false, '${V1}', '${V2}'),
  ('904', 'Delta Former Territory', 'union_territory', false, '${V1}', '${V2}');
INSERT INTO public.region_districts (code, state_code, name_en, active, introduced_in, retired_in, replaced_by) VALUES
  ('90101', '901', 'Northfield', true, '${V1}', NULL, '{}'),
  ('90102', '901', 'Riverton', true, '${V1}', NULL, '{}'),
  ('90103', '901', 'Lakeside', false, '${V1}', '${V2}', '{90104,90105}'),
  ('90104', '901', 'Lakeside East', true, '${V2}', NULL, '{}'),
  ('90105', '901', 'Lakeside West', true, '${V2}', NULL, '{}'),
  ('90201', '902', 'Northfield', true, '${V1}', NULL, '{}'),
  ('90202', '902', 'Hillcrest', true, '${V1}', NULL, '{}'),
  ('90301', '903', 'Old Town', false, '${V1}', '${V2}', '{}'),
  ('90401', '904', 'Eastgate', true, '${V1}', NULL, '{}');  -- active district left under a retired State/UT
INSERT INTO public.region_district_aliases (state_code, alias_normalized, district_code, kind, added_in) VALUES
  ('901', 'old riverton', '90102', 'renamed', '${V2}'),
  ('901', 'lakeside', '90104', 'legacy_bundled', '${V2}'),
  ('901', 'lakeside', '90105', 'legacy_bundled', '${V2}'),
  ('902', 'hill crest', '90202', 'common_spelling', '${V1}');
`;

const CATALOG_TABLES = ['region_catalog_versions', 'region_states', 'region_districts', 'region_district_aliases'];
const ALL_TABLES = [...CATALOG_TABLES, 'profile_regions', 'engineer_service_districts', 'region_resolution_queue'];
const CLIENT_RPCS = [
  'public.region_catalog_current()',
  'public.set_my_home_region(text,text,text)',
  'public.set_my_service_districts(text[],text)',
  'public.my_region_profile()',
];
const SERVICE_RPC = 'public.region_legacy_backfill_report(boolean)';
const HELPERS = [
  'public.region_normalize_label(text)', 'public.region_current_version()',
  'public.region_resolve_state_label(text)', 'public.region_district_candidates(text,text)',
  'public.region_require_writable_version(text)', 'public.region_resolve_legacy_pair(text,text)',
];

async function as(db, role, sql, params = [], sub = null) {
  return db.transaction(async (tx) => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    await tx.query("SELECT set_config('request.jwt.claim.sub', $1, true)", [sub ?? '']);
    return tx.query(sql, params);
  });
}
const asUser = (db, sub, sql, params = []) => as(db, 'authenticated', sql, params, sub);
async function rejects(action, code, pattern) {
  await assert.rejects(action, (e) => {
    assert.equal(e.code, code, `expected ${code}, got ${e.code}: ${e.message}`);
    if (pattern) assert.match(e.message, pattern);
    return true;
  });
}
const one = async (db, sql, params = []) => (await db.query(sql, params)).rows[0];
const homeRow = (db, user) => one(db, 'SELECT * FROM public.profile_regions WHERE user_id = $1', [user]);
const profile = (db, user) => one(db, 'SELECT state, district FROM public.profiles WHERE id = $1', [user]);
const serviceCodes = async (db, engineer) =>
  (await db.query('SELECT district_code FROM public.engineer_service_districts WHERE engineer_id = $1 ORDER BY district_code', [engineer]))
    .rows.map((r) => r.district_code);
// Extra synthetic users and a 31-district State/UT, created inside the properties that need them.
const userId = (n) => `d0000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
const engId = (n) => `f0000000-0000-0000-0000-0000000000${String(n).padStart(2, '0')}`;
async function addEngineer(db, n, { profileState, kycState, areas }) {
  await db.query('INSERT INTO public.profiles (id, full_name, role, state) VALUES ($1, $2, $3, $4) ON CONFLICT (id) DO NOTHING',
    [userId(n), `Engineer ${n}`, 'engineer', profileState]);
  await db.query('INSERT INTO public.engineers (id, user_id, state, service_areas) VALUES ($1, $2, $3, $4) ON CONFLICT (id) DO NOTHING',
    [engId(n), userId(n), kycState, areas]);
}
const MANY_CODES = Array.from({ length: 31 }, (_, i) => String(90501 + i));
const MANY_NAMES = MANY_CODES.map((_, i) => `Many District ${String(i + 1).padStart(2, '0')}`);
async function addManyDistricts(db) {
  await db.query("INSERT INTO public.region_states (code, name_en, kind, introduced_in) VALUES ('905', 'Many Districts State', 'state', $1) ON CONFLICT (code) DO NOTHING", [V2]);
  for (let i = 0; i < MANY_CODES.length; i++) {
    await db.query("INSERT INTO public.region_districts (code, state_code, name_en, introduced_in) VALUES ($1, '905', $2, $3) ON CONFLICT (code) DO NOTHING",
      [MANY_CODES[i], MANY_NAMES[i], V2]);
  }
}

const SET_HOME = 'SELECT public.set_my_home_region($1, $2, $3) AS r';
const SET_SERVICE = 'SELECT public.set_my_service_districts($1::text[], $2) AS r';
const MY_REGION = 'SELECT public.my_region_profile() AS r';

const PROPERTIES = [
  // ---------------------------------------------------------------- regression
  { kind: 'regression', name: 'legacy labels and engineer columns are untouched by the migration', run: async (db) => {
    assert.deepEqual(await profile(db, U.leg(3)), { state: 'Alpha State', district: 'Old Riverton' });
    assert.deepEqual(await profile(db, U.leg(6)), { state: '  alpha   STATE ', district: 'NORTHFIELD' });
    const e = await one(db, 'SELECT state, city, service_areas FROM public.engineers WHERE id = $1', [LEG_ENG12]);
    assert.deepEqual(e, { state: 'Alpha State', city: 'Riverton, Alpha State', service_areas: ['Northfield', 'Riverton', 'Hill crest'] });
  } },
  { kind: 'regression', name: 'older app versions can still save their own profile state/district text directly', run: async (db) => {
    await asUser(db, U.other, 'UPDATE public.profiles SET state = $1, district = $2 WHERE id = $3', ['Beta Territory', 'Hillcrest', U.other]);
    assert.deepEqual(await profile(db, U.other), { state: 'Beta Territory', district: 'Hillcrest' });
    await db.query('UPDATE public.profiles SET state = NULL, district = NULL WHERE id = $1', [U.other]);
  } },

  // ---------------------------------------------------------------- controls
  { kind: 'control', mutantMustFail: /^anon (INSERT|UPDATE|DELETE) region_/, name: 'catalog_is_public_read_only: anon and signed-in users can read the catalogue but never write it', run: async (db) => {
    for (const role of ['anon', 'authenticated']) {
      for (const t of CATALOG_TABLES) {
        const n = (await as(db, role, `SELECT count(*)::int AS n FROM public.${t}`, [], role === 'authenticated' ? U.home : null)).rows[0].n;
        assert.ok(n > 0, `${role} sees no rows in ${t}`);
        for (const priv of ['INSERT', 'UPDATE', 'DELETE']) {
          assert.equal((await one(db, 'SELECT has_table_privilege($1, $2, $3) AS ok', [role, `public.${t}`, priv])).ok, false, `${role} ${priv} ${t}`);
        }
      }
      const sub = role === 'authenticated' ? U.home : null;
      await rejects(() => as(db, role, "INSERT INTO public.region_states (code, name_en, kind) VALUES ('999', 'Forged', 'state')", [], sub), '42501');
      await rejects(() => as(db, role, "UPDATE public.region_districts SET name_en = 'Forged'", [], sub), '42501');
      await rejects(() => as(db, role, 'DELETE FROM public.region_district_aliases', [], sub), '42501');
      await rejects(() => as(db, role, `UPDATE public.region_catalog_versions SET is_current = false`, [], sub), '42501');
    }
    assert.equal((await one(db, "SELECT count(*)::int AS n FROM public.region_districts")).n, 9);
  } },

  { kind: 'control', name: 'home_region_pair_validation: wrong pairs, unknown and retired codes and unsupported versions are refused; a valid pair is stored with codes and mirrored as labels', run: async (db) => {
    await rejects(() => asUser(db, U.home, SET_HOME, ['901', '90201', V2]), '22023', /region_pair_invalid/);
    await rejects(() => asUser(db, U.home, SET_HOME, ['901', '99999', V2]), '22023', /region_code_unknown/);
    await rejects(() => asUser(db, U.home, SET_HOME, ['999', '90101', V2]), '22023', /region_code_unknown/);
    await rejects(() => asUser(db, U.home, SET_HOME, ['901', '90103', V2]), '22023', /region_district_retired/);
    await rejects(() => asUser(db, U.home, SET_HOME, ['903', '90301', V2]), '22023', /region_district_retired/);
    await rejects(() => asUser(db, U.home, SET_HOME, ['901', '90101', V1]), '22023', /region_catalog_version_unsupported/);
    await rejects(() => asUser(db, U.home, SET_HOME, ['901', '90101', 'synthetic-v9']), '22023', /region_catalog_version_unsupported/);
    await rejects(() => asUser(db, U.home, SET_HOME, ['901', '90101', null]), '22023', /region_catalog_version_unsupported/);
    await rejects(() => as(db, 'anon', SET_HOME, ['901', '90101', V2]), '42501');
    assert.equal(await homeRow(db, U.home), undefined, 'a refused call must not write');

    const r = (await asUser(db, U.home, SET_HOME, ['901', '90104', V2])).rows[0].r;
    assert.deepEqual(r, {
      state_code: '901', state_name: 'Alpha State', district_code: '90104', district_name: 'Lakeside East',
      catalog_version: V2, status: 'resolved',
    });
    const row = await homeRow(db, U.home);
    assert.equal(row.state_code, '901');
    assert.equal(row.district_code, '90104');
    assert.equal(row.catalog_version, V2);
    assert.equal(row.status, 'resolved');
    assert.equal(row.source, 'user');
    assert.deepEqual(await profile(db, U.home), { state: 'Alpha State', district: 'Lakeside East' });

    // Own-row read only.
    assert.equal((await asUser(db, U.home, 'SELECT count(*)::int AS n FROM public.profile_regions')).rows[0].n, 1);
    assert.equal((await asUser(db, U.other, 'SELECT count(*)::int AS n FROM public.profile_regions WHERE user_id = $1', [U.home])).rows[0].n, 0);
    await rejects(() => as(db, 'anon', 'SELECT count(*) FROM public.profile_regions'), '42501');
    await rejects(() => asUser(db, U.home, "UPDATE public.profile_regions SET district_code = '90101'"), '42501');
    await rejects(() => asUser(db, U.other, `INSERT INTO public.profile_regions (user_id, catalog_version, status, source) VALUES ('${U.other}', '${V2}', 'resolved', 'user')`), '42501');
  } },

  { kind: 'control', name: 'legacy_label_exact_only: legacy text maps only on an exact name or alias inside its own State/UT; everything else is queued; the report returns counts only', run: async (db) => {
    const dry = await as(db, 'service_role', 'SELECT * FROM public.region_legacy_backfill_report(false)');
    for (const f of dry.fields) assert.equal(f.dataTypeID, 23, `report column ${f.name} is not an integer count`);
    assert.equal((await one(db, "SELECT count(*)::int AS n FROM public.profile_regions WHERE source = 'legacy_backfill'")).n, 0, 'dry run wrote');
    assert.equal((await one(db, 'SELECT count(*)::int AS n FROM public.region_resolution_queue')).n, 0, 'dry run queued');

    const applied = (await as(db, 'service_role', 'SELECT * FROM public.region_legacy_backfill_report(true)')).rows[0];
    const { queue_rows_added: dryQueued, queue_rows_closed: dryClosed, ...dryCounts } = dry.rows[0];
    const { queue_rows_added: appliedQueued, queue_rows_closed: appliedClosed, ...appliedCounts } = applied;
    assert.deepEqual(appliedCounts, dryCounts, 'apply must resolve exactly what the dry run counted');
    assert.equal(dryQueued + dryClosed, 0, 'a dry run changes no queue rows');
    assert.equal(appliedQueued, applied.profiles_needs_confirmation + applied.service_labels_needs_confirmation);
    assert.equal(appliedClosed, 0);
    assert.deepEqual(appliedCounts, {
      profiles_considered: 12, profiles_already_current: 1, profiles_resolved: 5, profiles_needs_confirmation: 6,
      profiles_cleared: 0, engineers_considered: 2, engineers_already_chosen: 0, engineers_already_current: 0,
      engineers_over_cap: 0, service_labels_resolved: 2, service_labels_needs_confirmation: 2,
    });
    assert.equal((await homeRow(db, U.home)).source, 'user', 'a user-chosen row with unchanged text is never overwritten');

    const expect = async (n, status, state, district) => {
      const row = await homeRow(db, U.leg(n));
      assert.ok(row, `legacy user ${n} has no row`);
      assert.deepEqual([row.status, row.state_code, row.district_code, row.source], [status, state, district, 'legacy_backfill'], `legacy user ${n}`);
      return row;
    };
    await expect(1, 'resolved', '901', '90101');
    await expect(2, 'needs_confirmation', '901', null);              // "Northfield Dist." is not folded
    const renamed = await expect(3, 'resolved', '901', '90102');     // renamed alias -> new code
    assert.equal(renamed.legacy_district_label, 'Old Riverton', 'label snapshot keeps the old text');
    assert.deepEqual(await profile(db, U.leg(3)), { state: 'Alpha State', district: 'Old Riverton' }, 'backfill never rewrites profile text');
    await expect(4, 'resolved', '902', '90201');                     // same name, other State/UT: never crosses
    await expect(5, 'needs_confirmation', '901', null);              // alias with two candidates
    await expect(6, 'resolved', '901', '90101');                     // case and spacing only
    await expect(7, 'needs_confirmation', null, null);               // unknown State/UT
    assert.equal(await homeRow(db, U.leg(8)), undefined, 'no labels, no row');
    await expect(9, 'needs_confirmation', null, null);               // retired State/UT
    await expect(10, 'needs_confirmation', '901', null);             // partial district name
    await expect(11, 'needs_confirmation', null, null);              // partial State/UT name

    const queue = (await db.query(`SELECT subject_user_id, reason, candidate_codes FROM public.region_resolution_queue
                                     WHERE subject_kind = 'profile_home' ORDER BY subject_user_id`)).rows;
    const reasons = Object.fromEntries(queue.map((q) => [q.subject_user_id, q.reason]));
    assert.deepEqual(reasons, {
      [U.leg(2)]: 'no_match', [U.leg(5)]: 'ambiguous', [U.leg(7)]: 'state_unknown',
      [U.leg(9)]: 'state_unknown', [U.leg(10)]: 'no_match', [U.leg(11)]: 'state_unknown',
    });
    assert.deepEqual(queue.find((q) => q.subject_user_id === U.leg(5)).candidate_codes, ['90104', '90105']);

    // Service areas resolve only inside the engineer's own State/UT.
    assert.deepEqual(await serviceCodes(db, LEG_ENG12), ['90101', '90102']);
    const svcQueue = (await db.query(`SELECT subject_user_id, raw_district_label, reason FROM public.region_resolution_queue
                                        WHERE subject_kind = 'engineer_service' ORDER BY subject_user_id, raw_district_label`)).rows;
    assert.deepEqual(svcQueue.map((q) => [q.subject_user_id, q.raw_district_label, q.reason]), [
      [U.leg(12), 'Hill crest', 'no_match'],          // Beta's alias is never used for an Alpha engineer
      [U.leg(13), 'Northfield', 'state_unknown'],
    ]);

    // Re-running is idempotent: nothing new is queued and every profile is current.
    const again = (await as(db, 'service_role', 'SELECT * FROM public.region_legacy_backfill_report(true)')).rows[0];
    assert.equal(again.queue_rows_added + again.queue_rows_closed, 0);
    assert.equal(again.profiles_already_current, again.profiles_considered);
    assert.equal(again.profiles_resolved + again.profiles_needs_confirmation, 0);
    assert.equal(again.engineers_already_current, again.engineers_considered);

    // The caller's view: coded home region, then a stale flag with an exact preview after an old-client edit.
    const mine = (await asUser(db, U.leg(3), MY_REGION)).rows[0].r;
    assert.equal(mine.home.district_code, '90102');
    assert.equal(mine.home_stale, false);
    assert.equal(mine.legacy_preview, null);
    await asUser(db, U.leg(3), 'UPDATE public.profiles SET district = $1 WHERE id = $2', ['Riverton', U.leg(3)]);
    const stale = (await asUser(db, U.leg(3), MY_REGION)).rows[0].r;
    assert.equal(stale.home_stale, true);
    assert.deepEqual([stale.legacy_preview.status, stale.legacy_preview.district_code], ['resolved', '90102']);
    const unresolved = (await asUser(db, U.leg(2), MY_REGION)).rows[0].r;
    assert.equal(unresolved.home.status, 'needs_confirmation');
    assert.equal(unresolved.legacy_district_label, 'Northfield Dist.', 'unresolved text stays visible');

    // The report is service-only.
    await rejects(() => asUser(db, U.home, 'SELECT * FROM public.region_legacy_backfill_report(false)'), '42501');
    await rejects(() => as(db, 'anon', 'SELECT * FROM public.region_legacy_backfill_report(false)'), '42501');
    await rejects(() => asUser(db, U.home, 'SELECT count(*) FROM public.region_resolution_queue'), '42501');
    // Choosing codes later resolves the open queue item.
    await asUser(db, U.leg(2), SET_HOME, ['901', '90101', V2]);
    assert.equal((await one(db, `SELECT status FROM public.region_resolution_queue WHERE subject_user_id = $1`, [U.leg(2)])).status, 'resolved');
  } },

  { kind: 'control', name: 'service_districts_bounds_and_ownership: engineers only, 1..30 unique active codes in any State/UT, atomic replace, own rows only, cascade on engineer delete', run: async (db) => {
    await rejects(() => asUser(db, U.home, SET_SERVICE, [['90101'], V2]), '42501', /not_an_engineer/);
    await rejects(() => as(db, 'anon', SET_SERVICE, [['90101'], V2]), '42501');
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [[], V2]), '22023', /region_service_districts_empty/);
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [null, V2]), '22023', /region_service_districts_empty/);
    const many = Array.from({ length: 31 }, (_, i) => String(80000 + i));
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [many, V2]), '22023', /region_service_districts_too_many/);
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [['90101', '90101'], V2]), '22023', /region_service_districts_duplicate/);
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [['90101', null], V2]), '22023', /region_code_unknown/);
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [['90101', '99999'], V2]), '22023', /region_code_unknown/);
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [['90101', '90103'], V2]), '22023', /region_district_retired/);
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [['90101'], V1]), '22023', /region_catalog_version_unsupported/);

    const cross = (await asUser(db, U.eng1, SET_SERVICE, [['90102', '90202'], V2])).rows[0].r;
    assert.deepEqual(cross, { catalog_version: V2, district_codes: ['90102', '90202'], count: 2 });
    assert.deepEqual(await serviceCodes(db, ENG1), ['90102', '90202']);
    assert.deepEqual((await one(db, 'SELECT service_areas FROM public.engineers WHERE id = $1', [ENG1])).service_areas, ['Riverton', 'Hillcrest']);

    await asUser(db, U.eng1, SET_SERVICE, [['90202'], V2]);
    assert.deepEqual(await serviceCodes(db, ENG1), ['90202'], 'replace, not merge');
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [['90101', '90103'], V2]), '22023');
    assert.deepEqual(await serviceCodes(db, ENG1), ['90202'], 'a refused call leaves the previous set intact');
    assert.deepEqual((await one(db, 'SELECT service_areas FROM public.engineers WHERE id = $1', [ENG1])).service_areas, ['Hillcrest']);
    const six = (await asUser(db, U.eng1, SET_SERVICE, [['90101', '90102', '90104', '90105', '90201', '90202'], V2])).rows[0].r;
    assert.equal(six.count, 6);
    const exactlyThirty = Array.from({ length: 30 }, (_, i) => String(80000 + i));
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [exactlyThirty, V2]), '22023', /region_code_unknown/); // 30 passes the cap; unknown codes are then refused

    await rejects(() => asUser(db, U.eng1, `INSERT INTO public.engineer_service_districts (engineer_id, district_code, catalog_version, source) VALUES ('${ENG1}', '90101', '${V2}', 'engineer')`), '42501');
    await rejects(() => asUser(db, U.eng1, 'DELETE FROM public.engineer_service_districts'), '42501');
    await rejects(() => asUser(db, U.eng1, "UPDATE public.engineer_service_districts SET source = 'engineer'"), '42501');
    assert.equal((await asUser(db, U.eng1, 'SELECT count(*)::int AS n FROM public.engineer_service_districts')).rows[0].n, 6);
    assert.equal((await asUser(db, U.eng2, 'SELECT count(*)::int AS n FROM public.engineer_service_districts WHERE engineer_id = $1', [ENG1])).rows[0].n, 0);
    await rejects(() => as(db, 'anon', 'SELECT count(*) FROM public.engineer_service_districts'), '42501');

    const mine = (await asUser(db, U.eng1, MY_REGION)).rows[0].r;
    assert.equal(mine.is_engineer, true);
    assert.equal(mine.service_districts.length, 6);
    const notMine = (await asUser(db, U.eng2, MY_REGION)).rows[0].r;
    assert.deepEqual(notMine.service_districts, []);

    await db.query('DELETE FROM public.engineers WHERE id = $1', [ENG1]);
    assert.deepEqual(await serviceCodes(db, ENG1), [], 'deleting the engineer cascades');
  } },

  { kind: 'new-only', name: 'the backfill converges on edited text, catalogue changes and the 30-district cap, and never overrides a choice', run: async (db) => {
    const backfill = async () => (await as(db, 'service_role', 'SELECT * FROM public.region_legacy_backfill_report(true)')).rows[0];
    const openItems = async (user, kind) => (await db.query(
      `SELECT raw_district_label, reason FROM public.region_resolution_queue
        WHERE subject_user_id = $1 AND subject_kind = $2 AND status = 'open' ORDER BY raw_district_label`, [user, kind])).rows;

    // An older app shortens the service-area text: the coded set shrinks and the vanished item is dismissed.
    await db.query("UPDATE public.engineers SET service_areas = ARRAY['Riverton'] WHERE id = $1", [LEG_ENG12]);
    const shrink = await backfill();
    assert.deepEqual(await serviceCodes(db, LEG_ENG12), ['90102']);
    assert.deepEqual(await openItems(U.leg(12), 'engineer_service'), []);
    assert.ok(shrink.queue_rows_closed >= 1);

    // A catalogue change (a new alias) re-evaluates rows that needed confirmation.
    await db.query("INSERT INTO public.region_district_aliases (state_code, alias_normalized, district_code, kind, added_in) VALUES ('901', 'north', '90101', 'common_spelling', $1)", [V2]);
    await backfill();
    const north = await homeRow(db, U.leg(10));
    assert.deepEqual([north.status, north.district_code], ['resolved', '90101']);
    assert.deepEqual(await openItems(U.leg(10), 'profile_home'), []);

    // New text replaces old text: the old item is closed and the new text resolves.
    await db.query("UPDATE public.profiles SET state = 'Beta Territory', district = 'Hill crest' WHERE id = $1", [U.leg(11)]);
    await backfill();
    const moved = await homeRow(db, U.leg(11));
    assert.deepEqual([moved.status, moved.state_code, moved.district_code], ['resolved', '902', '90202']);
    assert.deepEqual(await openItems(U.leg(11), 'profile_home'), []);

    // A case or spacing edit is not a change.
    await db.query("UPDATE public.profiles SET state = 'ALPHA  STATE', district = 'northfield' WHERE id = $1", [U.leg(1)]);
    assert.equal((await asUser(db, U.leg(1), MY_REGION)).rows[0].r.home_stale, false);
    const quiet = await backfill();
    assert.equal(quiet.profiles_resolved + quiet.profiles_needs_confirmation + quiet.profiles_cleared, 0);
    assert.equal(quiet.queue_rows_added + quiet.queue_rows_closed, 0);

    // Cleared text removes the derived row and closes its item.
    await db.query('UPDATE public.profiles SET state = NULL, district = NULL WHERE id = $1', [U.leg(9)]);
    const cleared = await backfill();
    assert.equal(cleared.profiles_cleared, 1);
    assert.equal(await homeRow(db, U.leg(9)), undefined);
    assert.deepEqual(await openItems(U.leg(9), 'profile_home'), []);

    // The KYC State/UT scopes service areas; the profile's is used only when the KYC one is blank.
    await addEngineer(db, 15, { profileState: 'Beta Territory', kycState: 'Alpha', areas: ['Northfield'] });
    await addEngineer(db, 16, { profileState: 'Beta Territory', kycState: '  ', areas: ['Northfield'] });
    await backfill();
    assert.deepEqual(await serviceCodes(db, engId(15)), [], 'a partial KYC State/UT never falls back to another State/UT');
    assert.deepEqual(await openItems(userId(15), 'engineer_service'), [{ raw_district_label: 'Northfield', reason: 'state_unknown' }]);
    assert.equal((await one(db, "SELECT raw_state_label FROM public.region_resolution_queue WHERE subject_user_id = $1 AND subject_kind = 'engineer_service'", [userId(15)])).raw_state_label, 'Alpha');
    assert.deepEqual(await serviceCodes(db, engId(16)), ['90201']);

    // More than 30 resolvable districts: no rows and one too_many item; at 30 the set is written and the item closed.
    await addManyDistricts(db);
    await addEngineer(db, 17, { profileState: null, kycState: 'Many Districts State', areas: MANY_NAMES });
    const over = await backfill();
    assert.equal(over.engineers_over_cap, 1);
    assert.deepEqual(await serviceCodes(db, engId(17)), []);
    assert.deepEqual(await openItems(userId(17), 'engineer_service'), [{ raw_district_label: null, reason: 'too_many' }]);
    await db.query('UPDATE public.engineers SET service_areas = $1 WHERE id = $2', [MANY_NAMES.slice(0, 30), engId(17)]);
    await backfill();
    assert.deepEqual(await serviceCodes(db, engId(17)), MANY_CODES.slice(0, 30));
    assert.deepEqual(await openItems(userId(17), 'engineer_service'), []);
    // ...and the engineer can re-save exactly what the server reports.
    await asUser(db, userId(17), SET_SERVICE, [MANY_CODES.slice(0, 30), V2]);
    assert.equal((await one(db, "SELECT count(*)::int AS n FROM public.engineer_service_districts WHERE engineer_id = $1 AND source = 'engineer'", [engId(17)])).n, 30);

    // Converged: nothing left to change, and the user's own choice is untouched.
    const still = await backfill();
    assert.equal(still.queue_rows_added + still.queue_rows_closed, 0);
    assert.equal(still.profiles_already_current, still.profiles_considered);
    assert.equal(still.engineers_already_current + still.engineers_already_chosen, still.engineers_considered);
    assert.equal((await homeRow(db, U.home)).source, 'user');
  } },

  { kind: 'new-only', name: 'write RPC edges: 30 valid codes, multi-dimensional lists, a district of a retired State/UT, codes outside the submitted version, a choice closes open items', run: async (db) => {
    await addManyDistricts(db);
    await addEngineer(db, 18, { profileState: null, kycState: null, areas: [] });
    assert.equal((await asUser(db, userId(18), SET_SERVICE, [MANY_CODES.slice(0, 30), V2])).rows[0].r.count, 30);
    await rejects(() => asUser(db, userId(18), SET_SERVICE, [MANY_CODES, V2]), '22023', /region_service_districts_too_many/);
    assert.equal((await serviceCodes(db, engId(18))).length, 30);
    await rejects(() => asUser(db, userId(18), "SELECT public.set_my_service_districts('{{90101},{90102}}'::text[], $1)", [V2]), '22023', /region_code_unknown/);

    // An active district of a retired State/UT is retired for both RPCs and not counted.
    await rejects(() => asUser(db, U.other, SET_HOME, ['904', '90401', V2]), '22023', /region_district_retired/);
    await rejects(() => asUser(db, userId(18), SET_SERVICE, [['90401'], V2]), '22023', /region_district_retired/);

    // Codes must exist in the catalogue version they claim.
    await db.query('UPDATE public.region_catalog_versions SET accepts_writes = true WHERE version = $1', [V1]);
    try {
      await rejects(() => asUser(db, U.other, SET_HOME, ['901', '90104', V1]), '22023', /region_code_unknown/);
      await rejects(() => asUser(db, userId(18), SET_SERVICE, [['90104'], V1]), '22023', /region_code_unknown/);
      assert.equal((await asUser(db, U.other, SET_HOME, ['901', '90101', V1])).rows[0].r.catalog_version, V1);
    } finally {
      await db.query('UPDATE public.region_catalog_versions SET accepts_writes = false WHERE version = $1', [V1]);
    }

    // Choosing districts closes the engineer's open items.
    const open13 = async () => (await one(db, "SELECT count(*)::int AS n FROM public.region_resolution_queue WHERE subject_user_id = $1 AND subject_kind = 'engineer_service' AND status = 'open'", [U.leg(13)])).n;
    assert.ok(await open13() > 0);
    await asUser(db, U.leg(13), SET_SERVICE, [['90201'], V2]);
    assert.equal(await open13(), 0);
    assert.equal((await one(db, "SELECT status FROM public.region_resolution_queue WHERE subject_user_id = $1 AND subject_kind = 'engineer_service'", [U.leg(13)])).status, 'resolved');
  } },

  { kind: 'new-only', name: 'catalogue integrity: aliases and stored pairs cannot cross States/UTs, aliases are stored normalised, retired targets never resolve', run: async (db) => {
    const fails = (sql, code) => rejects(() => db.query(sql), code);
    await fails("INSERT INTO public.region_district_aliases (state_code, alias_normalized, district_code, kind) VALUES ('901', 'beta hill', '90202', 'common_spelling')", '23503');
    await fails("INSERT INTO public.region_district_aliases (state_code, alias_normalized, district_code, kind) VALUES ('901', 'Old Riverton', '90102', 'renamed')", '23514');
    await fails("INSERT INTO public.region_district_aliases (state_code, alias_normalized, district_code, kind) VALUES ('901', 'old  riverton', '90102', 'renamed')", '23514');
    await fails(`INSERT INTO public.profile_regions (user_id, state_code, district_code, catalog_version, status, source) VALUES ('${U.leg(8)}', '901', '90201', '${V2}', 'resolved', 'user')`, '23503');
    await fails(`INSERT INTO public.profile_regions (user_id, state_code, district_code, catalog_version, status, source) VALUES ('${U.leg(8)}', NULL, '90101', '${V2}', 'needs_confirmation', 'user')`, '23514');
    await fails(`INSERT INTO public.region_catalog_versions (version, source_url, retrieved_on, sha256, is_current) VALUES ('synthetic-v3', 'x', DATE '2026-07-01', '${'c'.repeat(64)}', true)`, '23505');
    // An alias to a retired district is allowed in history but never resolves.
    await db.query("INSERT INTO public.region_district_aliases (state_code, alias_normalized, district_code, kind) VALUES ('901', 'lake old', '90103', 'legacy_bundled')");
    assert.deepEqual((await one(db, "SELECT public.region_district_candidates('901', 'Lake Old') AS c")).c, []);
    assert.deepEqual((await one(db, "SELECT public.region_district_candidates('904', 'Eastgate') AS c")).c, [], 'a retired State/UT resolves nothing');
    assert.deepEqual((await one(db, "SELECT public.region_district_candidates('901', 'Old Riverton') AS c")).c, ['90102']);
  } },

  { kind: 'control', mutantMustFail: /^anon can execute public./, name: 'grants_and_definer_shape: client RPCs are definer with a pinned search_path and signed-in-only EXECUTE; the report is service-only; helpers and tables expose nothing extra', run: async (db) => {
    const exec = async (role, sig) => (await one(db, "SELECT has_function_privilege($1, $2, 'EXECUTE') AS ok", [role, sig])).ok;
    const shape = async (sig) => one(db, 'SELECT p.prosecdef, p.proconfig FROM pg_proc p WHERE p.oid = $1::regprocedure', [sig]);
    for (const sig of [...CLIENT_RPCS, SERVICE_RPC]) {
      const s = await shape(sig);
      assert.equal(s.prosecdef, true, `${sig} is not SECURITY DEFINER`);
      assert.ok((s.proconfig || []).some((c) => c.startsWith('search_path=')), `${sig} has no pinned search_path`);
    }
    for (const sig of CLIENT_RPCS) {
      assert.equal(await exec('anon', sig), false, `anon can execute ${sig}`);
      assert.equal(await exec('authenticated', sig), true, `authenticated cannot execute ${sig}`);
    }
    assert.equal(await exec('anon', SERVICE_RPC), false);
    assert.equal(await exec('authenticated', SERVICE_RPC), false);
    assert.equal(await exec('service_role', SERVICE_RPC), true);
    for (const sig of HELPERS) {
      assert.equal(await exec('anon', sig), false, `anon can execute helper ${sig}`);
      assert.equal(await exec('authenticated', sig), false, `authenticated can execute helper ${sig}`);
    }
    for (const t of ALL_TABLES) {
      assert.equal((await one(db, 'SELECT relrowsecurity FROM pg_class WHERE oid = $1::regclass', [`public.${t}`])).relrowsecurity, true, `RLS off on ${t}`);
      for (const role of ['anon', 'authenticated']) {
        for (const priv of ['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE']) {
          assert.equal((await one(db, 'SELECT has_table_privilege($1, $2, $3) AS ok', [role, `public.${t}`, priv])).ok, false, `${role} ${priv} on ${t}`);
        }
      }
    }
    for (const t of ['profile_regions', 'engineer_service_districts', 'region_resolution_queue']) {
      assert.equal((await one(db, "SELECT has_table_privilege('anon', $1, 'SELECT') AS ok", [`public.${t}`])).ok, false, `anon select on ${t}`);
    }
    assert.equal((await one(db, "SELECT has_table_privilege('authenticated', 'public.region_resolution_queue', 'SELECT') AS ok")).ok, false);
    // No enum, trigger or policy was added to profiles or engineers.
    assert.equal((await one(db, "SELECT count(*)::int AS n FROM pg_trigger WHERE tgrelid IN ('public.profiles'::regclass, 'public.engineers'::regclass) AND NOT tgisinternal")).n, 0);
    assert.equal((await one(db, "SELECT count(*)::int AS n FROM pg_policy WHERE polrelid IN ('public.profiles'::regclass, 'public.engineers'::regclass)")).n, 0);
    assert.equal((await one(db, "SELECT count(*)::int AS n FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace WHERE n.nspname = 'public' AND t.typtype = 'e' AND t.typname LIKE 'region%'")).n, 0);
  } },

  // ---------------------------------------------------------------- new-only
  { kind: 'new-only', name: 're-applying the migration changes nothing (third apply on a used database)', run: async (db) => {
    const counts = async () => one(db, `SELECT (SELECT count(*) FROM public.profile_regions)::int AS pr,
      (SELECT count(*) FROM public.engineer_service_districts)::int AS esd,
      (SELECT count(*) FROM public.region_resolution_queue)::int AS q,
      (SELECT count(*) FROM pg_policy WHERE polrelid::regclass::text LIKE '%region%' OR polrelid::regclass::text LIKE '%service_districts%')::int AS pol`);
    const before = await counts();
    await db.exec(newSql);
    assert.deepEqual(await counts(), before);
  } },
  { kind: 'new-only', name: "the migration's self-check aborts if a client write grant reappears", run: async (db) => {
    const selfCheck = newSql.slice(newSql.lastIndexOf('DO $$'), newSql.lastIndexOf('END $$;') + 'END $$;'.length);
    assert.ok(selfCheck.startsWith('DO $$') && selfCheck.includes('round3830: not as intended'), 'self-check block not found');
    await db.exec(selfCheck);
    for (const [grant, revoke, needle] of [
      ['GRANT INSERT ON public.region_states TO anon', 'REVOKE INSERT ON public.region_states FROM anon', /region_states/],
      ['GRANT SELECT ON public.region_resolution_queue TO authenticated', 'REVOKE SELECT ON public.region_resolution_queue FROM authenticated', /region_resolution_queue/],
      ['GRANT EXECUTE ON FUNCTION public.region_legacy_backfill_report(boolean) TO authenticated', 'REVOKE EXECUTE ON FUNCTION public.region_legacy_backfill_report(boolean) FROM authenticated', /region_legacy_backfill_report/],
      ['GRANT EXECUTE ON FUNCTION public.region_district_candidates(text,text) TO anon', 'REVOKE EXECUTE ON FUNCTION public.region_district_candidates(text,text) FROM anon', /region_district_candidates/],
      ['ALTER TABLE public.profile_regions DISABLE ROW LEVEL SECURITY', 'ALTER TABLE public.profile_regions ENABLE ROW LEVEL SECURITY', /rls off: public.profile_regions/],
      ['GRANT UPDATE ON SEQUENCE public.region_resolution_queue_id_seq TO anon', 'REVOKE UPDATE ON SEQUENCE public.region_resolution_queue_id_seq FROM anon', /update granted to anon on public.region_resolution_queue_id_seq/],
      ['GRANT UPDATE (district_code) ON public.profile_regions TO authenticated', 'REVOKE UPDATE (district_code) ON public.profile_regions FROM authenticated', /column update granted to authenticated on public.profile_regions/],
    ]) {
      await db.exec(grant);
      try {
        await assert.rejects(() => db.exec(selfCheck), (e) => { assert.equal(e.code, '42501'); assert.match(e.message, needle); return true; });
      } finally {
        await db.exec(revoke);
      }
    }
    await db.exec(selfCheck);
  } },
  { kind: 'new-only', name: 'deleting a profile cascades its region row and queue items (never blocks account deletion)', run: async (db) => {
    const user = U.leg(5);
    assert.ok(await homeRow(db, user));
    assert.ok((await one(db, 'SELECT count(*)::int AS n FROM public.region_resolution_queue WHERE subject_user_id = $1', [user])).n > 0);
    await db.query('DELETE FROM public.profiles WHERE id = $1', [user]);
    assert.equal(await homeRow(db, user), undefined);
    assert.equal((await one(db, 'SELECT count(*)::int AS n FROM public.region_resolution_queue WHERE subject_user_id = $1', [user])).n, 0);
  } },
];

const UNSEEDED_PROPERTIES = [
  { name: 'before any owner-approved seed, every write is refused, the preview is empty and the report refuses to run', run: async (db) => {
    const cur = (await asUser(db, U.home, 'SELECT * FROM public.region_catalog_current()')).rows[0];
    assert.deepEqual(cur, { current_version: null, supported_versions: [], is_synthetic: false, state_count: 0, district_count: 0 });
    await rejects(() => asUser(db, U.home, SET_HOME, ['901', '90101', V2]), '22023', /region_catalog_version_unsupported/);
    await rejects(() => asUser(db, U.eng1, SET_SERVICE, [['90101'], V2]), '22023', /region_catalog_version_unsupported/);
    const mine = (await asUser(db, U.leg(1), MY_REGION)).rows[0].r;
    assert.equal(mine.home, null);
    assert.equal(mine.legacy_preview, null);
    assert.equal(mine.current_catalog_version, null);
    assert.equal(mine.legacy_district_label, 'Northfield');
    await rejects(() => as(db, 'service_role', 'SELECT * FROM public.region_legacy_backfill_report(false)'), 'P0001', /region_catalog_missing/);
    await rejects(() => as(db, 'anon', 'SELECT * FROM public.region_catalog_current()'), '42501');
  } },
  { name: 'region_catalog_current reports the seeded current version once a seed lands', run: async (db) => {
    await db.exec(seedSql);
    const cur = (await asUser(db, U.home, 'SELECT * FROM public.region_catalog_current()')).rows[0];
    assert.deepEqual(cur, { current_version: V2, supported_versions: [V2], is_synthetic: true, state_count: 2, district_count: 6 });
  } },
];

// round3830 without its REVOKE statements and without the trailing self-check.
const withoutRevokes = newSql.replace(/^REVOKE [^;]*;$/gm, '-- (mutant: revoke removed)');
const mutantSql = withoutRevokes.slice(0, withoutRevokes.lastIndexOf('DO $$')) + 'COMMIT;';

async function build({ withNew, seed, sql = newSql }) {
  const db = await PGlite.create();
  await db.exec(baseFixture);
  await db.exec(fixture);
  if (withNew) { await db.exec(sql); await db.exec(sql); }
  if (seed) await db.exec(seedSql);
  return db;
}

const legacy = await build({ withNew: false, seed: false });
const fresh = await build({ withNew: true, seed: true });
const unseeded = await build({ withNew: true, seed: false });
assert.ok(!/^REVOKE /m.test(mutantSql) && !mutantSql.includes('round3830: not as intended'), 'mutant still revokes or self-checks');
const mutant = await build({ withNew: true, seed: true, sql: mutantSql });
const problems = [];
let newPass = 0, controlsFailed = 0, legacyRegressions = 0, unseededPass = 0, mutantFailed = 0;
for (const p of PROPERTIES) {
  try { await p.run(fresh); newPass++; console.log(`PASS  new       ${p.kind.padEnd(10)} ${p.name}`); }
  catch (e) { problems.push(`NEW must pass: ${p.name}: ${e.message}`); console.log(`FAIL  new       ${p.kind.padEnd(10)} ${p.name}: ${e.message}`); }
  if (p.kind === 'new-only') continue;
  try {
    await p.run(legacy);
    if (p.kind === 'control') { problems.push(`NEGATIVE CONTROL passed on LEGACY: ${p.name}`); console.log(`UNEXPECTED legacy pass: ${p.name}`); }
    else { legacyRegressions++; console.log(`PASS  legacy    ${p.kind.padEnd(10)} ${p.name}`); }
  } catch (e) {
    if (p.kind === 'control') { controlsFailed++; console.log(`FAIL  legacy    control    ${p.name} (expected: ${e.message.split('\n')[0]})`); }
    else { problems.push(`REGRESSION broken on LEGACY: ${p.name}: ${e.message}`); console.log(`FAIL  legacy    regression ${p.name}: ${e.message}`); }
  }
}
for (const p of PROPERTIES.filter((x) => x.mutantMustFail)) {
  try {
    await p.run(mutant);
    problems.push(`MUTANT control passed with default privileges in force: ${p.name}`);
    console.log(`UNEXPECTED mutant pass: ${p.name}`);
  } catch (e) {
    const reason = e.message.split(String.fromCharCode(10))[0];
    if (p.mutantMustFail.test(reason)) { mutantFailed++; console.log(`FAIL  mutant    control    ${p.name} (expected: ${reason})`); }
    else { problems.push(`MUTANT control failed for the wrong reason: ${p.name}: ${reason}`); console.log(`WRONG mutant failure: ${p.name}: ${reason}`); }
  }
}
for (const p of UNSEEDED_PROPERTIES) {
  try { await p.run(unseeded); unseededPass++; console.log(`PASS  unseeded  new-only   ${p.name}`); }
  catch (e) { problems.push(`UNSEEDED must pass: ${p.name}: ${e.message}`); console.log(`FAIL  unseeded  new-only   ${p.name}: ${e.message}`); }
}
const count = (k) => PROPERTIES.filter((p) => p.kind === k).length;
console.log('\n==== summary ====');
console.log(`new:                 ${newPass}/${PROPERTIES.length} properties pass`);
console.log(`negative controls:   ${controlsFailed}/${count('control')} fail on LEGACY (expected all: the feature is missing there)`);
console.log(`legacy regressions:  ${legacyRegressions}/${count('regression')} pass on LEGACY too (expected all)`);
console.log(`unseeded:            ${unseededPass}/${UNSEEDED_PROPERTIES.length} properties pass`);
console.log(`mutant controls:     ${mutantFailed}/${PROPERTIES.filter((x) => x.mutantMustFail).length} fail with the revokes removed (expected all)`);
if (problems.length) { console.log('\nPROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('\nALL EXPECTATIONS MET');
