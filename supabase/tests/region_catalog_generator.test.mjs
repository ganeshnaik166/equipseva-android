// Region catalogue generator (scripts/regions/build_region_catalog.mjs).
//
// 1. Refusals: every snapshot rule the server and the device enforce stops the
//    build (copies of the synthetic fixtures are mutated in a temp folder).
// 2. Parity: the generated Android asset for synthetic-v2 is byte-identical (LF)
//    to app/src/test/resources/regions/synthetic_catalog.json, which the Kotlin
//    tests use, so device and server tests share one source.
// 3. Seeds: the generated synthetic-v1 then synthetic-v2 seed SQL, each applied
//    twice over round3830 in PGlite, produce the intended history (rename keeps
//    its code, split with replaced_by, retired State/UT and district, aliases,
//    version switch), and the RPCs behave on it. A district that later moves to
//    another State/UT under the same code carries its aliases and stored pairs.
//
// Run: EQS_PGLITE_PACKAGE=<extracted @electric-sql/pglite@0.5.8/package> \
//        node supabase/tests/region_catalog_generator.test.mjs

import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as gen from '../../scripts/regions/build_region_catalog.mjs';

const require = createRequire(import.meta.url);
const { PGlite } = require(process.env.EQS_PGLITE_PACKAGE || '@electric-sql/pglite');

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../..');
const fixtures = path.join(repo, 'scripts/regions/fixtures');
const read = (p) => readFileSync(p, 'utf8');
const lf = (t) => t.replace(/\r\n/g, '\n');
const baseFixture = read(path.join(here, 'engineer_location_privacy.fixture.sql'));
const regionFixture = read(path.join(here, 'region_catalog.fixture.sql'));
const migration = read(path.join(repo, 'supabase/migrations/20263915000000_round3830_region_catalog_v1.sql'));

const results = [];
async function property(name, run) {
  try { await run(); results.push(true); console.log(`PASS  ${name}`); }
  catch (e) { results.push(false); console.log(`FAIL  ${name}: ${e.message}`); }
}

// A temp copy of a fixture folder; edit(files) may rewrite CSV text, then hashes are refreshed
// unless keepHashes is set (to test checksum refusals).
function variant(name, edit, { keepHashes = false } = {}) {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'region-gen-'));
  cpSync(path.join(fixtures, name), dir, { recursive: true });
  const files = {};
  for (const f of ['states.csv', 'districts.csv', 'retired_states.csv', 'retired_districts.csv', 'aliases.csv']) {
    try { files[f] = lf(read(path.join(dir, f))); } catch { /* optional file */ }
  }
  const prov = { text: lf(read(path.join(dir, 'PROVENANCE.md'))) };
  edit(files, prov);
  for (const [f, text] of Object.entries(files)) {
    if (text == null) { rmSync(path.join(dir, f), { force: true }); continue; }
    writeFileSync(path.join(dir, f), text);
    if (!keepHashes) {
      prov.text = prov.text.replace(new RegExp(`^- sha256 ${f.replace('.', '[.]')}: [0-9a-f]{64}$`, 'm'), `- sha256 ${f}: ${gen.sha256(text)}`);
    }
  }
  writeFileSync(path.join(dir, 'PROVENANCE.md'), prov.text);
  return dir;
}
function refuses(dir, pattern) {
  assert.throws(() => gen.loadSnapshot(dir), (e) => {
    assert.ok(e instanceof gen.CatalogError, `not a CatalogError: ${e}`);
    assert.match(e.message, pattern);
    return true;
  });
  rmSync(dir, { recursive: true, force: true });
}

await property('both synthetic snapshots load', async () => {
  const v1 = gen.loadSnapshot(path.join(fixtures, 'synthetic-v1'));
  const v2 = gen.loadSnapshot(path.join(fixtures, 'synthetic-v2'));
  assert.deepEqual([v1.version, v1.states.length, v1.districts.length], ['synthetic-v1', 3, 6]);
  assert.deepEqual([v2.version, v2.states.length, v2.districts.length, v2.retiredDistricts.length, v2.aliases.length], ['synthetic-v2', 2, 6, 2, 4]);
  assert.equal(v2.synthetic, true);
});

await property('snapshot rules refuse bad input, never repair it', async () => {
  const v2 = 'synthetic-v2';
  refuses(variant(v2, (f) => { f['districts.csv'] += '90101,901,Duplicate Code\n'; }), /duplicate district code 90101/);
  refuses(variant(v2, (f) => { f['districts.csv'] += '90199,999,Orphan\n'; }), /needs an active State\/UT, got 999/);
  refuses(variant(v2, (f) => { f['districts.csv'] += '90199,901,northfield\n'; }), /duplicate district name/);
  refuses(variant(v2, (f) => { f['districts.csv'] += '90399,903,Under Retired\n'; }), /needs an active State\/UT, got 903/);
  refuses(variant(v2, (f) => { f['states.csv'] += '9011,Bad Code,state\n'; }), /invalid State\/UT code 9011/);
  refuses(variant(v2, (f) => { f['states.csv'] += '909,Gamma,province\n'; }), /invalid kind/);
  refuses(variant(v2, (f) => { f['states.csv'] += '909,  alpha state,state\n'; }), /invalid name/);
  refuses(variant(v2, (f) => { f['states.csv'] += '909,ALPHA STATE,state\n'; }), /duplicate State\/UT name/);
  refuses(variant(v2, (f) => { f['retired_districts.csv'] = f['retired_districts.csv'].replace('90104;90105', '90104;99999'); }), /unknown replacement 99999/);
  refuses(variant(v2, (f) => { f['retired_districts.csv'] += '90101,901,Also Active,\n'; }), /duplicate district code 90101/);
  refuses(variant(v2, (f) => { f['aliases.csv'] += '901,Old Town,90101,renamed\n'; }), /not stored normalised/);
  refuses(variant(v2, (f) => { f['aliases.csv'] += '901,hill crest,90202,common_spelling\n'; }), /does not point at an active district of 901/);
  refuses(variant(v2, (f) => { f['aliases.csv'] += '901,lake,90103,legacy_bundled\n'; }), /does not point at an active district/);
  refuses(variant(v2, (f) => { f['aliases.csv'] += '901,lake,90104,guess\n'; }), /invalid alias kind/);
  refuses(variant(v2, (f) => { f['districts.csv'] = f['districts.csv'].replace('code,state_code,name', 'code,state,name'); }), /header must be/);
  refuses(variant(v2, (f) => { f['districts.csv'] += '90199,901\n'; }), /has 2 fields/);
  refuses(variant(v2, (f) => { f['districts.csv'] += '90199,901,"Unclosed\n'; }), /unterminated quote/);
  refuses(variant(v2, (f) => { f['districts.csv'] += '90199,901,Tampered\n'; }, { keepHashes: true }), /sha256 does not match/);
  refuses(variant(v2, (f) => { f['aliases.csv'] = null; }), /lists aliases\.csv, which is missing/);
  refuses(variant(v2, (f, p) => { p.text = p.text.replace(/^- licence: .*$/m, ''); }), /missing "- licence/);
  refuses(variant(v2, (f, p) => { p.text = p.text.replace(/^- sha256 states\.csv: .*$/m, ''); }), /no sha256 for states\.csv/);
  refuses(variant(v2, (f, p) => { p.text = p.text.replace('- retrieved_on: 2026-06-01', '- retrieved_on: 1 June 2026'); }), /retrieved_on must be a real YYYY-MM-DD date/);
  refuses(variant(v2, (f, p) => { p.text = p.text.replace('- version: synthetic-v2', '- version: Synthetic V2'); }), /invalid version/);
  refuses(variant(v2, (f, p) => { p.text = p.text.replace('- synthetic: true', '- synthetic: maybe'); }), /synthetic must be true or false/);
  // Duplicated provenance lines are refused instead of "last one wins".
  refuses(variant(v2, (f, p) => { p.text += '- version: synthetic-v9\n'; }), /more than one "- version:" line/);
  refuses(variant(v2, (f, p) => { p.text += `${p.text.match(/^- sha256 states\.csv: .*$/m)[0]}\n`; }), /more than one sha256 line for states\.csv/);
  // Every file is required, so a missing aliases.csv can never withdraw the server's aliases...
  refuses(variant(v2, (f, p) => { f['aliases.csv'] = null; p.text = p.text.replace(/^- sha256 aliases\.csv: .*\n/m, ''); }), /aliases\.csv is missing/);
  // ...and a misspelled file name is refused rather than ignored.
  const misspelled = variant(v2, () => {});
  writeFileSync(path.join(misspelled, 'retired_district.csv'), 'code,state_code,name,replaced_by\n');
  refuses(misspelled, /unexpected file retired_district\.csv/);
  // A row holding only "" is a row with one empty field, not a blank line.
  refuses(variant(v2, (f) => { f['districts.csv'] += '""\n'; }), /row 8 has 1 fields/);
  // Letters the device, the server and this script would lower-case differently.
  refuses(variant(v2, (f) => { f['districts.csv'] += `90199,901,${String.fromCodePoint(0x130)}stanbul\n`; }), /unsupported character U\+0130/);
  refuses(variant(v2, (f) => { f['states.csv'] += `909,${String.fromCodePoint(0x3a3)}OFO${String.fromCodePoint(0x3a3)},state\n`; }), /unsupported character U\+03A3/);
});

await property('quoted fields, CRLF files and a byte-order mark are read exactly', async () => {
  const rows = gen.parseCsv(String.fromCharCode(0xfeff) + 'code,state_code,name\r\n90199,901,"Comma, Quoted ""Name"""\r\n', 'districts.csv');
  assert.deepEqual(rows, [{ code: '90199', state_code: '901', name: 'Comma, Quoted "Name"' }]);
  assert.equal(gen.sha256('a\r\nb\n'), gen.sha256('a\nb\n'), 'checksums ignore CRLF versus LF');
});

// The path guard is exercised in a throwaway copy of the repository layout, so a regression in
// it can never leave synthetic data in this working tree.
const SHIPPING_DIRS = ['app/src/main/assets', 'app/src/release/assets', 'app/src/debug/assets', 'supabase/migrations'];
function fakeRepo() {
  const root = mkdtempSync(path.join(os.tmpdir(), 'region-repo-'));
  cpSync(path.join(repo, 'scripts/regions'), path.join(root, 'scripts/regions'), { recursive: true });
  for (const d of SHIPPING_DIRS) mkdirSync(path.join(root, d), { recursive: true });
  return root;
}
const shippedFiles = (root) => SHIPPING_DIRS.flatMap((d) => readdirSync(path.join(root, d), { recursive: true }));

await property('synthetic catalogues can never be written where they would ship', async () => {
  const root = fakeRepo();
  try {
    const snapshot = path.join(root, 'scripts/regions/fixtures/synthetic-v2');
    for (const set of ['main', 'release', 'debug']) {
      assert.throws(() => gen.build({ snapshot, jsonOut: path.join(root, `app/src/${set}/assets/regions/india_regions.json`) }), /shipped asset path/);
    }
    for (const sqlOut of ['supabase/migrations', 'supabase/migrations/x.sql']) {
      assert.throws(() => gen.build({ snapshot, sqlOut: path.join(root, sqlOut), migrationVersion: '20263999000000', round: '9999' }), /supabase\/migrations/);
    }
    assert.deepEqual(shippedFiles(root), [], 'nothing was written to a shipping path');
    assert.throws(() => gen.build({ snapshot, sqlOut: os.tmpdir(), migrationVersion: '2026', round: '1' }), /14 digits/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

await property('the --hash lines printed for an Excel CSV (byte-order mark, CRLF) are the ones the build accepts', async () => {
  const dir = variant('synthetic-v2', () => {});
  try {
    const bom = String.fromCharCode(0xfeff);
    for (const f of ['states.csv', 'districts.csv', 'aliases.csv']) {
      writeFileSync(path.join(dir, f), bom + lf(read(path.join(dir, f))).replace(/\n/g, '\r\n'));
    }
    const printed = execFileSync(process.execPath, [path.join(repo, 'scripts/regions/build_region_catalog.mjs'), '--hash', dir],
      { env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' } }).toString();
    const kept = lf(read(path.join(dir, 'PROVENANCE.md'))).split('\n').filter((l) => !l.startsWith('- sha256 '));
    writeFileSync(path.join(dir, 'PROVENANCE.md'), [...kept, ...lf(printed).trim().split('\n')].join('\n') + '\n');
    const fromExcel = gen.loadSnapshot(dir);
    const plain = gen.loadSnapshot(path.join(fixtures, 'synthetic-v2'));
    for (const k of ['states', 'districts', 'retiredDistricts', 'aliases']) assert.deepEqual(fromExcel[k], plain[k], k);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

await property('the generated synthetic-v2 asset is the Android test fixture, byte for byte', async () => {
  const generated = gen.toAssetJson(gen.loadSnapshot(path.join(fixtures, 'synthetic-v2')));
  const committed = lf(read(path.join(repo, 'app/src/test/resources/regions/synthetic_catalog.json')));
  assert.equal(generated, committed, 'regenerate it with: node scripts/regions/build_region_catalog.mjs --snapshot scripts/regions/fixtures/synthetic-v2 --json-out app/src/test/resources/regions/synthetic_catalog.json');
  const again = gen.toAssetJson(gen.loadSnapshot(path.join(fixtures, 'synthetic-v2')));
  assert.equal(again, generated, 'output is deterministic');
});

const v1 = gen.loadSnapshot(path.join(fixtures, 'synthetic-v1'));
const v2 = gen.loadSnapshot(path.join(fixtures, 'synthetic-v2'));
const seed1 = gen.toSeedSql(v1, { migrationVersion: '20263990000000', round: '9990' });
const seed2 = gen.toSeedSql(v2, { migrationVersion: '20263991000000', round: '9991' });

async function freshDb() {
  const db = await PGlite.create();
  await db.exec(baseFixture);
  await db.exec(regionFixture);
  await db.exec(migration);
  return db;
}
const one = async (db, sql, params = []) => (await db.query(sql, params)).rows[0];
async function asUser(db, sub, sql, params = []) {
  return db.transaction(async (tx) => {
    await tx.exec('SET LOCAL ROLE authenticated');
    await tx.query("SELECT set_config('request.jwt.claim.sub', $1, true)", [sub]);
    return tx.query(sql, params);
  });
}

const db = await freshDb();
await property('the synthetic-v1 seed applies twice and becomes current', async () => {
  await db.exec(seed1);
  await db.exec(seed1);
  assert.equal((await one(db, 'SELECT public.region_current_version() AS v')).v, 'synthetic-v1');
  assert.equal((await one(db, 'SELECT count(*)::int AS n FROM public.region_districts WHERE active')).n, 6);
  assert.equal((await one(db, "SELECT name_en FROM public.region_districts WHERE code = '90102'")).name_en, 'Old Riverton');
  // Backfill on v1, so the v2 seed below has rows from an older catalogue to re-stamp.
  await db.query('SELECT * FROM public.region_legacy_backfill_report(true)');
  assert.equal((await one(db, "SELECT catalog_version FROM public.profile_regions WHERE user_id = 'c0000000-0000-0000-0000-000000000001'")).catalog_version, 'synthetic-v1');
  assert.equal((await one(db, "SELECT catalog_version FROM public.engineer_service_districts WHERE engineer_id = 'e0000000-0000-0000-0000-000000000012' AND district_code = '90101'")).catalog_version, 'synthetic-v1');
});

await property('the synthetic-v2 seed renames, splits and retires as intended, twice over', async () => {
  await db.exec(seed2);
  await db.exec(seed2);
  const versions = (await db.query('SELECT version, is_current, accepts_writes, is_synthetic FROM public.region_catalog_versions ORDER BY ordinal')).rows;
  assert.deepEqual(versions, [
    { version: 'synthetic-v1', is_current: false, accepts_writes: true, is_synthetic: true },
    { version: 'synthetic-v2', is_current: true, accepts_writes: true, is_synthetic: true },
  ]);
  const d = async (code) => one(db, 'SELECT state_code, name_en, active, introduced_in, retired_in, replaced_by FROM public.region_districts WHERE code = $1', [code]);
  assert.deepEqual(await d('90102'), { state_code: '901', name_en: 'Riverton', active: true, introduced_in: 'synthetic-v1', retired_in: null, replaced_by: [] });
  assert.deepEqual(await d('90103'), { state_code: '901', name_en: 'Lakeside', active: false, introduced_in: 'synthetic-v1', retired_in: 'synthetic-v2', replaced_by: ['90104', '90105'] });
  assert.deepEqual(await d('90104'), { state_code: '901', name_en: 'Lakeside East', active: true, introduced_in: 'synthetic-v2', retired_in: null, replaced_by: [] });
  assert.deepEqual(await d('90301'), { state_code: '903', name_en: 'Old Town', active: false, introduced_in: 'synthetic-v1', retired_in: 'synthetic-v2', replaced_by: [] });
  assert.deepEqual(await one(db, "SELECT active, retired_in FROM public.region_states WHERE code = '903'"), { active: false, retired_in: 'synthetic-v2' });
  assert.equal((await one(db, 'SELECT count(*)::int AS n FROM public.region_district_aliases')).n, 4);
  assert.equal((await one(db, "SELECT added_in FROM public.region_district_aliases WHERE alias_normalized = 'hill crest'")).added_in, 'synthetic-v1');
});

await property('the RPCs work on the generated catalogue, including version membership', async () => {
  const home = 'a0000000-0000-0000-0000-000000000001';
  const cur = (await asUser(db, home, 'SELECT * FROM public.region_catalog_current()')).rows[0];
  assert.deepEqual(cur, { current_version: 'synthetic-v2', supported_versions: ['synthetic-v1', 'synthetic-v2'], is_synthetic: true, state_count: 2, district_count: 6 });
  assert.equal((await asUser(db, home, 'SELECT public.set_my_home_region($1, $2, $3) AS r', ['901', '90104', 'synthetic-v2'])).rows[0].r.district_name, 'Lakeside East');
  await assert.rejects(() => asUser(db, home, 'SELECT public.set_my_home_region($1, $2, $3)', ['901', '90104', 'synthetic-v1']), /region_code_unknown/);
  assert.equal((await asUser(db, home, 'SELECT public.set_my_home_region($1, $2, $3) AS r', ['901', '90102', 'synthetic-v1'])).rows[0].r.district_name, 'Riverton');
  const report = (await db.query('SELECT * FROM public.region_legacy_backfill_report(true)')).rows[0];
  assert.ok(report.profiles_resolved > 0);
  // Rows written on v1 move to the current catalogue on the next run.
  assert.equal((await one(db, "SELECT catalog_version FROM public.profile_regions WHERE user_id = 'c0000000-0000-0000-0000-000000000001'")).catalog_version, 'synthetic-v2');
  assert.equal((await one(db, "SELECT catalog_version FROM public.engineer_service_districts WHERE engineer_id = 'e0000000-0000-0000-0000-000000000012' AND district_code = '90101'")).catalog_version, 'synthetic-v2');
  assert.equal((await one(db, "SELECT district_code FROM public.profile_regions WHERE user_id = 'c0000000-0000-0000-0000-000000000003'")).district_code, '90102', 'Old Riverton resolves through the generated renamed alias');
});

await property('a district that moves to another State/UT under the same code carries its aliases and stored home pairs', async () => {
  const other = await freshDb();
  await other.exec(seed1);
  await other.exec(seed2);
  const home = 'a0000000-0000-0000-0000-000000000002';
  await asUser(other, home, 'SELECT public.set_my_home_region($1, $2, $3)', ['902', '90202', 'synthetic-v2']);
  // synthetic-v3: Hillcrest (90202) now belongs to Alpha State (901).
  const moved = variant('synthetic-v2', (f, p) => {
    f['districts.csv'] = f['districts.csv'].replace('90202,902,Hillcrest', '90202,901,Hillcrest');
    f['aliases.csv'] = f['aliases.csv'].replace('902,hill crest,90202,common_spelling', '901,hill crest,90202,common_spelling');
    p.text = p.text.replace('- version: synthetic-v2', '- version: synthetic-v3').replace('- retrieved_on: 2026-06-01', '- retrieved_on: 2026-09-01');
  });
  const seed3 = gen.toSeedSql(gen.loadSnapshot(moved), { migrationVersion: '20263992000000', round: '9992' });
  rmSync(moved, { recursive: true, force: true });
  await other.exec(seed3);
  await other.exec(seed3);
  assert.equal((await one(other, 'SELECT public.region_current_version() AS v')).v, 'synthetic-v3');
  assert.equal((await one(other, "SELECT state_code FROM public.region_districts WHERE code = '90202'")).state_code, '901');
  assert.equal((await one(other, "SELECT state_code FROM public.region_district_aliases WHERE alias_normalized = 'hill crest'")).state_code, '901');
  assert.deepEqual(await one(other, 'SELECT state_code, district_code FROM public.profile_regions WHERE user_id = $1', [home]), { state_code: '901', district_code: '90202' });
  assert.deepEqual((await other.query("SELECT public.region_district_candidates('901', 'Hill Crest') AS c")).rows[0].c, ['90202']);
});

await property('labels normalise exactly like the server: ASCII whitespace only', async () => {
  const nbsp = String.fromCharCode(0xa0);
  const tab = String.fromCharCode(9), nl = String.fromCharCode(10), vt = String.fromCharCode(11);
  const mixed = ` Alpha${tab}${nl}State${vt} `;
  assert.equal(gen.normalizeLabel(mixed), 'alpha state');
  assert.equal(gen.normalizeLabel(`Alpha${nbsp}State`), `alpha${nbsp}state`);
  assert.equal(gen.normalizeLabel(`${nbsp}Alpha`), `${nbsp}alpha`);
  for (const label of [mixed, `Alpha${nbsp}State`, `${nbsp}Alpha `, 'North  field', 'Dist.', '   ']) {
    const server = (await db.query('SELECT public.region_normalize_label($1) AS n', [label])).rows[0].n;
    assert.equal(gen.normalizeLabel(label), server, `label ${JSON.stringify(label)}`);
  }
});

await property('no current directory, path form or partial run lets synthetic data reach a shipping path', async () => {
  const root = fakeRepo();
  const script = path.join(root, 'scripts/regions/build_region_catalog.mjs');
  const node = process.execPath;
  const run = (cwd, args) => {
    try {
      execFileSync(node, [script, ...args], { cwd, env: { ...process.env, ELECTRON_RUN_AS_NODE: '1' }, stdio: 'pipe' });
      return 0;
    } catch (e) { return e.status ?? 1; }
  };
  // From scripts/regions of a copy of the repository, with relative paths into it.
  const regionsDir = path.join(root, 'scripts/regions');
  assert.equal(run(regionsDir, ['--snapshot', 'fixtures/synthetic-v2', '--json-out', '../../app/src/main/assets/regions/india_regions.json']), 1);
  assert.equal(run(regionsDir, ['--snapshot', 'fixtures/synthetic-v2', '--json-out', '../../app/src/release/assets/regions/india_regions.json']), 1);
  assert.equal(run(regionsDir, ['--snapshot', 'fixtures/synthetic-v2', '--json-out', path.join(os.tmpdir(), 'r.json'),
    '--sql-out', '../../supabase/migrations', '--migration-version', '20263999000000', '--round', '9999']), 1);
  assert.deepEqual(shippedFiles(root), [], 'nothing was written to a shipping path');
  rmSync(root, { recursive: true, force: true });
  // Any repository's shipping paths are refused by path segment.
  const elsewhere = mkdtempSync(path.join(os.tmpdir(), 'region-elsewhere-'));
  const snapshot = path.join(fixtures, 'synthetic-v2');
  assert.throws(() => gen.build({ snapshot, jsonOut: path.join(elsewhere, 'mod/src/main/assets/regions/x.json') }), /shipped asset path/);
  assert.throws(() => gen.build({ snapshot, sqlOut: path.join(elsewhere, 'supabase/migrations'), migrationVersion: '20263999000000', round: '9999' }), /supabase\/migrations/);
  // A refusal leaves nothing behind: the asset is not written when the seed arguments are bad.
  const jsonOut = path.join(elsewhere, 'out/a.json');
  assert.throws(() => gen.build({ snapshot, jsonOut, sqlOut: path.join(elsewhere, 'out/b.sql'), migrationVersion: '123', round: '1' }), /14 digits/);
  assert.equal(existsSync(jsonOut), false, 'a refused run wrote a partial result');
  rmSync(elsewhere, { recursive: true, force: true });
});

await property('bytes and text that would be repaired or read differently elsewhere are refused', async () => {
  // Invalid UTF-8 (a Windows-1252 byte) is refused, never decoded to a replacement character.
  const badBytes = variant('synthetic-v2', () => {});
  writeFileSync(path.join(badBytes, 'districts.csv'), Buffer.concat([
    Buffer.from('code,state_code,name\n90101,901,My'), Buffer.from([0xfb]), Buffer.from('sore\n'),
  ]));
  refuses(badBytes, /not valid UTF-8/);
  refuses(variant('synthetic-v2', (f) => { f['districts.csv'] += '90199,901,"Kurnool"x\n'; }), /text after a closing quote/);
  const tab = String.fromCharCode(9), zwsp = String.fromCharCode(0x200b), fs1c = String.fromCharCode(0x1c);
  refuses(variant('synthetic-v2', (f) => { f['districts.csv'] += `90199,901,North${tab}Gate\n`; }), /invalid name/);
  refuses(variant('synthetic-v2', (f) => { f['districts.csv'] += `90199,901,${zwsp}\n`; }), /invalid name/);
  refuses(variant('synthetic-v2', (f) => { f['districts.csv'] += `90199,901,East Gate${fs1c}\n`; }), /invalid name/);
  refuses(variant('synthetic-v2', (f, p) => { p.text = p.text.replace('- retrieved_on: 2026-06-01', '- retrieved_on: 2026-02-30'); }), /real YYYY-MM-DD date/);
  refuses(variant('synthetic-v2', (f, p) => { p.text = p.text.replace('- retrieved_on: 2026-06-01', '- retrieved_on: 1899-12-31'); }), /real YYYY-MM-DD date/);
  refuses(variant('synthetic-v2', (f, p) => { p.text = p.text.replace('- synthetic: true', '- synthetic: false'); }), /must be marked "synthetic: true"/);
  refuses(variant('synthetic-v2', (f) => { f['states.csv'] += '909,Empty Territory,union_territory\n'; }), /State\/UT 909 has no active district/);
});

// Seeds for variants of synthetic-v2, applied over a database already at v1 then v2.
async function atV2() {
  const db2 = await freshDb();
  await db2.exec(seed1);
  await db2.exec(seed2);
  return db2;
}
function seedOf(edit, round) {
  const dir = variant('synthetic-v2', edit);
  try { return gen.toSeedSql(gen.loadSnapshot(dir), { migrationVersion: `2026399${round}000000`.slice(0, 14), round }); }
  finally { rmSync(dir, { recursive: true, force: true }); }
}
const asV3 = (p) => { p.text = p.text.replace('- version: synthetic-v2', '- version: synthetic-v3').replace('- retrieved_on: 2026-06-01', '- retrieved_on: 2026-09-01'); };

await property('aliases converge on the snapshot: a dropped alias stops resolving and a retargeted one moves', async () => {
  const db3 = await atV2();
  const seed3 = seedOf((f, p) => {
    asV3(p);
    f['aliases.csv'] = f['aliases.csv'].replace('901,old riverton,90102,renamed\n', '').replace('902,hill crest,90202,common_spelling', '902,hill crest,90201,common_spelling');
  }, '9993');
  await db3.exec(seed3);
  await db3.exec(seed3);
  const cand = async (st, label) => (await db3.query('SELECT public.region_district_candidates($1, $2) AS c', [st, label])).rows[0].c;
  assert.deepEqual(await cand('901', 'Old Riverton'), [], 'the dropped alias no longer resolves');
  assert.deepEqual(await cand('902', 'Hill crest'), ['90201'], 'the retargeted alias follows the snapshot');
  assert.equal((await one(db3, 'SELECT count(*)::int AS n FROM public.region_district_aliases')).n, 3);
});

await property('a seed refuses to retire anything the snapshot does not list, and changes nothing', async () => {
  const db3 = await atV2();
  const truncated = seedOf((f, p) => {
    asV3(p);
    f['districts.csv'] = f['districts.csv'].replace('90202,902,Hillcrest\n', '');
    f['aliases.csv'] = f['aliases.csv'].replace('902,hill crest,90202,common_spelling\n', '');
  }, '9994');
  await assert.rejects(() => db3.exec(truncated), /districts would be retired without being listed in retired_districts\.csv: \{90202\}/);
  await db3.exec('ROLLBACK');
  assert.equal((await one(db3, 'SELECT public.region_current_version() AS v')).v, 'synthetic-v2');
  assert.equal((await one(db3, "SELECT active FROM public.region_districts WHERE code = '90202'")).active, true);
});

await property('a seed refuses different data under an existing version label', async () => {
  const db3 = await atV2();
  const sneaky = seedOf((f) => { f['districts.csv'] = f['districts.csv'].replace('90202,902,Hillcrest', '90202,902,Hillcrest Town'); }, '9995');
  await assert.rejects(() => db3.exec(sneaky), /synthetic-v2: this version already exists with different data/);
  await db3.exec('ROLLBACK');
  assert.equal((await one(db3, "SELECT name_en FROM public.region_districts WHERE code = '90202'")).name_en, 'Hillcrest');
});

await property('names and aliases holding quote characters or two dollar signs seed safely', async () => {
  const db3 = await atV2();
  const dollar = '$' + '$';
  const seed3 = seedOf((f, p) => {
    asV3(p);
    // The second alias holds the default tag itself, so the seed must pick another one.
    f['aliases.csv'] += `901,lake${dollar}side,90104,common_spelling\n901,the $seed$ end,90105,common_spelling\n`;
    // A function replacement: a replacement string would turn the two dollar signs into one.
    f['districts.csv'] = f['districts.csv'].replace('90202,902,Hillcrest', () => `90202,902,"Hill's ${dollar}crest"`);
  }, '9997');
  await db3.exec(seed3);
  await db3.exec(seed3);
  const cand = async (st, label) => (await db3.query('SELECT public.region_district_candidates($1, $2) AS c', [st, label])).rows[0].c;
  assert.deepEqual(await cand('901', `Lake${dollar}side`), ['90104']);
  assert.deepEqual(await cand('901', 'The $seed$ End'), ['90105']);
  assert.ok(seed3.includes('DO $seed1$'), 'the seed chose a tag no alias contains');
  assert.equal((await one(db3, "SELECT name_en FROM public.region_districts WHERE code = '90202'")).name_en, `Hill's ${dollar}crest`);
  assert.equal((await one(db3, 'SELECT public.region_current_version() AS v')).v, 'synthetic-v3');
});

await property('renames that swap or reuse names apply in one seed', async () => {
  const db3 = await atV2();
  const swapped = seedOf((f, p) => {
    asV3(p);
    f['districts.csv'] = f['districts.csv'].replace('90104,901,Lakeside East', '90104,901,Lakeside West TMP')
      .replace('90105,901,Lakeside West', '90105,901,Lakeside East').replace('90104,901,Lakeside West TMP', '90104,901,Lakeside West');
  }, '9996');
  await db3.exec(swapped);
  await db3.exec(swapped);
  const names = (await db3.query("SELECT code, name_en FROM public.region_districts WHERE code IN ('90104', '90105') ORDER BY code")).rows;
  assert.deepEqual(names.map((r) => r.name_en), ['Lakeside West', 'Lakeside East']);
});

const passed = results.filter(Boolean).length;
console.log(`\n==== summary ====\ngenerator: ${passed}/${results.length} properties pass`);
if (passed !== results.length) process.exitCode = 1;
else console.log('\nALL EXPECTATIONS MET');
