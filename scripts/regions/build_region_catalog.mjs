#!/usr/bin/env node
// Region catalogue generator (WP25.T01 sub-slice B; PRODUCT_PLAN §6, ledger P2.2).
//
// Turns one reviewed snapshot folder into the two artefacts the product uses:
//   * the Android asset (app/src/main/assets/regions/india_regions.json, format 1),
//     read by RegionCatalogParser on the device;
//   * a seed migration for the round3830 tables: it inserts the catalogue version,
//     retires every State/UT and district the snapshot no longer lists, upserts the
//     rest (renames keep their code), adds aliases, makes the version current and
//     re-checks the result in a DO block. Re-running it changes nothing.
//
// Snapshot folder (see scripts/regions/README.md):
//   PROVENANCE.md          "- key: value" lines: version, source_url, retrieved_on
//                          (YYYY-MM-DD), licence, synthetic (true|false), and one
//                          "- sha256 <file>: <hex>" line per CSV (sha256 of the file's
//                          UTF-8 text with CRLF normalised to LF)
//   states.csv             code,name,kind                       (active States/UTs)
//   districts.csv          code,state_code,name                 (active districts)
//   retired_states.csv     code,name,kind                       (optional)
//   retired_districts.csv  code,state_code,name,replaced_by     (optional; replaced_by
//                                                                 is ';'-separated)
//   aliases.csv            state_code,alias,district_code,kind  (optional; alias stored
//                                                                 normalised)
//
// Every rule the server and the device enforce is checked here first; any problem
// stops the build with a message. Nothing is repaired, guessed or fuzzily matched.
// Synthetic snapshots can never be written to the shipped asset path or to
// supabase/migrations.
//
// Usage:
//   node scripts/regions/build_region_catalog.mjs --snapshot <dir> --json-out <file>
//        [--sql-out <file> --migration-version <14 digits> --round <n>]
//   node scripts/regions/build_region_catalog.mjs --hash <dir>   (prints sha256 lines)

import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const FORMAT = 1;
const VERSION = /^[a-z0-9][a-z0-9._-]{2,63}$/;
const STATE_CODE = /^[0-9]{1,3}$/;
const DISTRICT_CODE = /^[0-9]{1,6}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const KINDS = new Set(['state', 'union_territory']);
const ALIAS_KINDS = new Set(['official', 'legacy_bundled', 'renamed', 'common_spelling']);
const CSV_FILES = ['states.csv', 'districts.csv', 'retired_states.csv', 'retired_districts.csv', 'aliases.csv'];
const REQUIRED_FILES = new Set(['states.csv', 'districts.csv']);
const HEADERS = {
  'states.csv': ['code', 'name', 'kind'],
  'districts.csv': ['code', 'state_code', 'name'],
  'retired_states.csv': ['code', 'name', 'kind'],
  'retired_districts.csv': ['code', 'state_code', 'name', 'replaced_by'],
  'aliases.csv': ['state_code', 'alias', 'district_code', 'kind'],
};

export class CatalogError extends Error {}
function fail(message) { throw new CatalogError(message); }

/**
 * Mirrors the server's region_normalize_label and RegionCatalog.normalizeLabel: lower case, and
 * runs of ASCII whitespace (space, tab, newline, carriage return, form feed, vertical tab) collapsed
 * to one space and trimmed. Non-breaking and other Unicode spaces are kept, as on the server.
 */
export function normalizeLabel(raw) {
  if (raw == null) return null;
  const s = String(raw).replace(/[ \t\n\r\f\v]+/g, ' ').replace(/^ | $/g, '').toLowerCase();
  return s === '' ? null : s;
}

const lf = (text) => text.replace(/\r\n/g, '\n');
export const sha256 = (text) => createHash('sha256').update(lf(text), 'utf8').digest('hex');

/** Minimal RFC 4180 reader: quoted fields, doubled quotes, LF or CRLF rows. */
export function parseCsv(text, file) {
  const rows = [];
  let row = [], field = '', i = 0, quoted = false;
  const raw = lf(text);
  const src = raw.charCodeAt(0) === 0xfeff ? raw.slice(1) : raw; // drop a UTF-8 byte-order mark
  while (i < src.length) {
    const c = src[i];
    if (quoted) {
      if (c === '"') {
        if (src[i + 1] === '"') { field += '"'; i += 2; continue; }
        quoted = false; i++; continue;
      }
      field += c; i++; continue;
    }
    if (c === '"') {
      if (field !== '') fail(`${file}: stray quote in row ${rows.length + 1}`);
      quoted = true; i++; continue;
    }
    if (c === ',') { row.push(field); field = ''; i++; continue; }
    if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; i++; continue; }
    field += c; i++;
  }
  if (quoted) fail(`${file}: unterminated quote`);
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  const nonEmpty = rows.filter((r) => !(r.length === 1 && r[0] === ''));
  if (!nonEmpty.length) fail(`${file}: empty`);
  const [header, ...body] = nonEmpty;
  const expected = HEADERS[file];
  if (header.join(',') !== expected.join(',')) fail(`${file}: header must be ${expected.join(',')}`);
  return body.map((r, n) => {
    if (r.length !== expected.length) fail(`${file}: row ${n + 2} has ${r.length} fields, expected ${expected.length}`);
    return Object.fromEntries(expected.map((k, j) => [k, r[j]]));
  });
}

export function parseProvenance(text) {
  const out = { sha256: {} };
  for (const line of lf(text).split('\n')) {
    const hash = /^- sha256 ([a-z_]+\.csv): ([0-9a-f]{64})\s*$/.exec(line);
    if (hash) { out.sha256[hash[1]] = hash[2]; continue; }
    const kv = /^- (version|source_url|retrieved_on|licence|synthetic): (.+?)\s*$/.exec(line);
    if (kv) out[kv[1]] = kv[2];
  }
  for (const key of ['version', 'source_url', 'retrieved_on', 'licence', 'synthetic']) {
    if (!out[key]) fail(`PROVENANCE.md: missing "- ${key}: ..."`);
  }
  if (!VERSION.test(out.version)) fail(`PROVENANCE.md: invalid version ${out.version}`);
  if (!DATE.test(out.retrieved_on) || Number.isNaN(Date.parse(out.retrieved_on))) fail('PROVENANCE.md: retrieved_on must be YYYY-MM-DD');
  if (out.source_url.length > 500) fail('PROVENANCE.md: source_url longer than 500 characters');
  if (out.synthetic !== 'true' && out.synthetic !== 'false') fail('PROVENANCE.md: synthetic must be true or false');
  out.synthetic = out.synthetic === 'true';
  return out;
}

function checkName(name, what) {
  if (typeof name !== 'string' || name.length < 1 || name.length > 64 || name.trim() !== name) {
    fail(`invalid name for ${what}: "${name}"`);
  }
}

/** Reads, verifies and validates one snapshot folder. Returns the normalised catalogue. */
export function loadSnapshot(dir) {
  const provPath = path.join(dir, 'PROVENANCE.md');
  if (!existsSync(provPath)) fail(`${dir}: PROVENANCE.md is missing`);
  const prov = parseProvenance(readFileSync(provPath, 'utf8'));
  const data = {};
  for (const file of CSV_FILES) {
    const p = path.join(dir, file);
    if (!existsSync(p)) {
      if (REQUIRED_FILES.has(file)) fail(`${dir}: ${file} is missing`);
      if (prov.sha256[file]) fail(`PROVENANCE.md lists ${file}, which is missing`);
      data[file] = [];
      continue;
    }
    const text = readFileSync(p, 'utf8');
    if (!prov.sha256[file]) fail(`PROVENANCE.md has no sha256 for ${file}`);
    if (prov.sha256[file] !== sha256(text)) fail(`${file}: sha256 does not match PROVENANCE.md`);
    data[file] = parseCsv(text, file);
  }
  for (const file of Object.keys(prov.sha256)) if (!CSV_FILES.includes(file)) fail(`PROVENANCE.md lists unknown file ${file}`);
  return validate(prov, data);
}

export function validate(prov, data) {
  const states = data['states.csv'];
  const districts = data['districts.csv'];
  const retiredStates = data['retired_states.csv'];
  const retiredDistricts = data['retired_districts.csv'];
  const aliases = data['aliases.csv'];
  if (!states.length || !districts.length) fail('a catalogue needs at least one State/UT and one district');

  const stateCodes = new Set();
  const activeStates = new Set();
  const stateNames = new Set();
  for (const [list, active] of [[states, true], [retiredStates, false]]) {
    for (const s of list) {
      if (!STATE_CODE.test(s.code)) fail(`invalid State/UT code ${s.code}`);
      checkName(s.name, `State/UT ${s.code}`);
      if (!KINDS.has(s.kind)) fail(`invalid kind "${s.kind}" for State/UT ${s.code}`);
      if (stateCodes.has(s.code)) fail(`duplicate State/UT code ${s.code}`);
      stateCodes.add(s.code);
      if (active) {
        activeStates.add(s.code);
        const key = normalizeLabel(s.name);
        if (stateNames.has(key)) fail(`duplicate State/UT name ${s.name}`);
        stateNames.add(key);
      }
    }
  }

  const districtCodes = new Set();
  const activeDistricts = new Map();
  const districtNames = new Set();
  for (const d of districts) {
    if (!DISTRICT_CODE.test(d.code)) fail(`invalid district code ${d.code}`);
    checkName(d.name, `district ${d.code}`);
    if (!activeStates.has(d.state_code)) fail(`district ${d.code} needs an active State/UT, got ${d.state_code}`);
    if (districtCodes.has(d.code)) fail(`duplicate district code ${d.code}`);
    districtCodes.add(d.code);
    activeDistricts.set(d.code, d);
    const key = `${d.state_code}|${normalizeLabel(d.name)}`;
    if (districtNames.has(key)) fail(`duplicate district name ${d.name} in ${d.state_code}`);
    districtNames.add(key);
  }
  const retired = retiredDistricts.map((r) => ({
    ...r,
    replaced_by: r.replaced_by === '' ? [] : r.replaced_by.split(';'),
  }));
  for (const r of retired) {
    if (!DISTRICT_CODE.test(r.code)) fail(`invalid retired district code ${r.code}`);
    checkName(r.name, `retired district ${r.code}`);
    if (!stateCodes.has(r.state_code)) fail(`retired district ${r.code} has unknown State/UT ${r.state_code}`);
    if (districtCodes.has(r.code)) fail(`duplicate district code ${r.code}`);
    districtCodes.add(r.code);
  }
  for (const r of retired) {
    for (const c of r.replaced_by) {
      if (!districtCodes.has(c) || c === r.code) fail(`unknown replacement ${c} for ${r.code}`);
    }
  }

  const aliasKeys = new Set();
  for (const a of aliases) {
    if (!activeStates.has(a.state_code)) fail(`alias "${a.alias}" needs an active State/UT, got ${a.state_code}`);
    if (a.alias.length < 1 || a.alias.length > 64 || normalizeLabel(a.alias) !== a.alias) {
      fail(`alias "${a.alias}" is not stored normalised`);
    }
    if (!ALIAS_KINDS.has(a.kind)) fail(`invalid alias kind "${a.kind}"`);
    const target = activeDistricts.get(a.district_code);
    if (!target || target.state_code !== a.state_code) {
      fail(`alias "${a.alias}" does not point at an active district of ${a.state_code}`);
    }
    const key = `${a.state_code}|${a.alias}|${a.district_code}`;
    if (aliasKeys.has(key)) fail(`duplicate alias "${a.alias}"`);
    aliasKeys.add(key);
  }

  const byCode = (x, y) => Number(x.code) - Number(y.code) || x.code.localeCompare(y.code);
  return {
    version: prov.version,
    synthetic: prov.synthetic,
    source: { url: prov.source_url, retrieved_on: prov.retrieved_on, licence: prov.licence },
    digest: snapshotDigest(prov.sha256),
    states: [...states].sort(byCode),
    retiredStates: [...retiredStates].sort(byCode),
    districts: [...districts].sort(byCode),
    retiredDistricts: retired.sort(byCode),
    aliases: [...aliases].sort((x, y) => x.state_code.localeCompare(y.state_code)
      || x.alias.localeCompare(y.alias) || x.district_code.localeCompare(y.district_code)),
  };
}

/** One checksum for the whole snapshot: sha256 over sorted "file<TAB>sha256" lines. */
export function snapshotDigest(fileHashes) {
  const lines = Object.keys(fileHashes).sort().map((f) => `${f}\t${fileHashes[f]}\n`).join('');
  return createHash('sha256').update(lines, 'utf8').digest('hex');
}

/** The Android asset (format 1), as RegionCatalogParser reads it. */
export function toAssetJson(cat) {
  const asset = {
    format: FORMAT,
    version: cat.version,
    synthetic: cat.synthetic,
    source: { url: cat.source.url, retrieved_on: cat.source.retrieved_on, sha256: cat.digest },
    states: cat.states.map((s) => ({ code: s.code, name: s.name, kind: s.kind })),
    districts: cat.districts.map((d) => ({ code: d.code, state: d.state_code, name: d.name })),
    retired_districts: cat.retiredDistricts.map((r) => ({ code: r.code, state: r.state_code, name: r.name, replaced_by: r.replaced_by })),
    aliases: cat.aliases.map((a) => ({ state: a.state_code, alias: a.alias, district: a.district_code, kind: a.kind })),
  };
  return JSON.stringify(asset, null, 2) + '\n';
}

const q = (v) => (v == null ? 'NULL' : `'${String(v).replace(/'/g, "''")}'`);
const arr = (list) => `ARRAY[${list.map(q).join(', ')}]::text[]`;

/** The seed migration for the round3830 tables. */
export function toSeedSql(cat, { migrationVersion, round }) {
  const v = q(cat.version);
  const activeStateCodes = cat.states.map((s) => s.code);
  const activeDistrictCodes = cat.districts.map((d) => d.code);
  const lines = [];
  const add = (s = '') => lines.push(s);
  add(`-- Round ${round} — region catalogue seed ${cat.version}.`);
  add('--');
  add('-- GENERATED by scripts/regions/build_region_catalog.mjs from a reviewed snapshot; do not edit.');
  add(`-- Source: ${cat.source.url} (retrieved ${cat.source.retrieved_on}; licence: ${cat.source.licence}).`);
  add(`-- Snapshot sha256: ${cat.digest}. ${cat.states.length} States/UTs, ${cat.districts.length} districts,`);
  add(`-- ${cat.retiredDistricts.length} retired districts, ${cat.aliases.length} aliases.`);
  add('--');
  add('-- Retires every State/UT and district this snapshot no longer lists, upserts the rest');
  add('-- (a rename keeps its code), records replacements and aliases, makes this version');
  add('-- current and re-checks the result. Re-running it changes nothing. Needs round3830.');
  add(`-- Migration version ${migrationVersion}.`);
  add('BEGIN;');
  add("SET LOCAL lock_timeout = '5s';");
  add();
  add('INSERT INTO public.region_catalog_versions (version, source_url, retrieved_on, sha256, is_current, accepts_writes, is_synthetic)');
  add(`VALUES (${v}, ${q(cat.source.url)}, DATE ${q(cat.source.retrieved_on)}, ${q(cat.digest)}, false, true, ${cat.synthetic})`);
  add('ON CONFLICT (version) DO NOTHING;');
  add();
  add('-- Retire first, so a name freed by a retirement can be reused in the same seed.');
  add(`UPDATE public.region_districts SET active = false, retired_in = ${v}`);
  add(`  WHERE active AND NOT (code = ANY (${arr(activeDistrictCodes)}));`);
  add(`UPDATE public.region_states SET active = false, retired_in = ${v}`);
  add(`  WHERE active AND NOT (code = ANY (${arr(activeStateCodes)}));`);
  add();
  const stateRows = [
    ...cat.states.map((s) => `  (${q(s.code)}, ${q(s.name)}, ${q(s.kind)}, true, ${v}, NULL)`),
    ...cat.retiredStates.map((s) => `  (${q(s.code)}, ${q(s.name)}, ${q(s.kind)}, false, ${v}, ${v})`),
  ];
  add('INSERT INTO public.region_states (code, name_en, kind, active, introduced_in, retired_in) VALUES');
  add(stateRows.join(',\n'));
  add('ON CONFLICT (code) DO UPDATE SET name_en = EXCLUDED.name_en, kind = EXCLUDED.kind,');
  add('  active = EXCLUDED.active,');
  add('  retired_in = CASE WHEN EXCLUDED.active THEN NULL ELSE coalesce(region_states.retired_in, EXCLUDED.retired_in) END;');
  add();
  const districtRows = [
    ...cat.districts.map((d) => `  (${q(d.code)}, ${q(d.state_code)}, ${q(d.name)}, true, ${v}, NULL, '{}'::text[])`),
    ...cat.retiredDistricts.map((r) => `  (${q(r.code)}, ${q(r.state_code)}, ${q(r.name)}, false, ${v}, ${v}, ${arr(r.replaced_by)})`),
  ];
  add('-- A district may move to another State/UT under the same code (LGD has done this);');
  add('-- round3830 cascades the move to its aliases and stored home pairs.');
  add('INSERT INTO public.region_districts (code, state_code, name_en, active, introduced_in, retired_in, replaced_by) VALUES');
  add(districtRows.join(',\n'));
  add('ON CONFLICT (code) DO UPDATE SET state_code = EXCLUDED.state_code, name_en = EXCLUDED.name_en,');
  add('  active = EXCLUDED.active,');
  add('  retired_in = CASE WHEN EXCLUDED.active THEN NULL ELSE coalesce(region_districts.retired_in, EXCLUDED.retired_in) END,');
  add('  replaced_by = EXCLUDED.replaced_by;');
  add();
  if (cat.aliases.length) {
    add('INSERT INTO public.region_district_aliases (state_code, alias_normalized, district_code, kind, added_in) VALUES');
    add(cat.aliases.map((a) => `  (${q(a.state_code)}, ${q(a.alias)}, ${q(a.district_code)}, ${q(a.kind)}, ${v})`).join(',\n'));
    add('ON CONFLICT (state_code, alias_normalized, district_code) DO NOTHING;');
    add();
  }
  add(`UPDATE public.region_catalog_versions SET is_current = false WHERE is_current AND version <> ${v};`);
  add(`UPDATE public.region_catalog_versions SET is_current = true, accepts_writes = true WHERE version = ${v};`);
  add();
  add('DO $$');
  add('DECLARE');
  add('  v_bad text[] := ARRAY[]::text[];');
  add('BEGIN');
  add(`  IF public.region_current_version() IS DISTINCT FROM ${v} THEN v_bad := v_bad || 'current version'::text; END IF;`);
  add(`  IF (SELECT coalesce(array_agg(code ORDER BY code), '{}') FROM public.region_states WHERE active)`);
  add(`     IS DISTINCT FROM (SELECT array_agg(c ORDER BY c) FROM unnest(${arr(activeStateCodes)}) c) THEN`);
  add("    v_bad := v_bad || 'active States/UTs'::text;");
  add('  END IF;');
  add(`  IF (SELECT coalesce(array_agg(code ORDER BY code), '{}') FROM public.region_districts WHERE active)`);
  add(`     IS DISTINCT FROM (SELECT array_agg(c ORDER BY c) FROM unnest(${arr(activeDistrictCodes)}) c) THEN`);
  add("    v_bad := v_bad || 'active districts'::text;");
  add('  END IF;');
  const pairs = cat.districts.map((d) => `${d.code}:${d.state_code}`);
  add(`  IF EXISTS (SELECT 1 FROM unnest(${arr(pairs)}) p`);
  add('             WHERE NOT EXISTS (SELECT 1 FROM public.region_districts d');
  add("                                WHERE d.code || ':' || d.state_code = p AND d.active)) THEN");
  add("    v_bad := v_bad || 'a district did not land under its State/UT'::text;");
  add('  END IF;');
  add('  IF EXISTS (SELECT 1 FROM public.region_districts d JOIN public.region_states s ON s.code = d.state_code');
  add('             WHERE d.active AND NOT s.active) THEN');
  add("    v_bad := v_bad || 'active district under a retired State/UT'::text;");
  add('  END IF;');
  add('  IF EXISTS (SELECT 1 FROM public.region_districts d, unnest(d.replaced_by) r');
  add('             WHERE NOT EXISTS (SELECT 1 FROM public.region_districts x WHERE x.code = r)) THEN');
  add("    v_bad := v_bad || 'unknown replacement code'::text;");
  add('  END IF;');
  add('  IF array_length(v_bad, 1) IS NOT NULL THEN');
  add(`    RAISE EXCEPTION 'region seed ${cat.version}: not as intended: %', v_bad USING ERRCODE = 'P0001';`);
  add('  END IF;');
  add('END $$;');
  add();
  add('COMMIT;');
  return lines.join('\n') + '\n';
}

const MAIN_ASSET = path.join('app', 'src', 'main', 'assets');
const MIGRATIONS = path.join('supabase', 'migrations');
const under = (file, dir) => path.resolve(file).toLowerCase().startsWith(path.resolve(dir).toLowerCase() + path.sep);

export function seedFileName(cat, { migrationVersion, round }) {
  if (!/^\d{14}$/.test(String(migrationVersion))) fail('--migration-version must be 14 digits');
  if (!/^\d+$/.test(String(round))) fail('--round must be a number');
  return `${migrationVersion}_round${round}_region_catalog_seed_${cat.version.replace(/[^a-z0-9]+/g, '_')}.sql`;
}

/** Writes the requested artefacts; refuses to put synthetic data where it would ship. */
export function build({ snapshot, jsonOut, sqlOut, migrationVersion, round, repoRoot = process.cwd() }) {
  const cat = loadSnapshot(snapshot);
  if (cat.synthetic && jsonOut && under(jsonOut, path.join(repoRoot, MAIN_ASSET))) {
    fail('a synthetic catalogue can never be written to the shipped asset path');
  }
  const sqlTarget = sqlOut
    ? (sqlOut.endsWith('.sql') ? sqlOut : path.join(sqlOut, seedFileName(cat, { migrationVersion, round })))
    : null;
  if (cat.synthetic && sqlTarget && under(sqlTarget, path.join(repoRoot, MIGRATIONS))) {
    fail('a synthetic catalogue can never be written to supabase/migrations');
  }
  const written = [];
  if (jsonOut) {
    mkdirSync(path.dirname(jsonOut), { recursive: true });
    writeFileSync(jsonOut, toAssetJson(cat));
    written.push(jsonOut);
  }
  if (sqlTarget) {
    seedFileName(cat, { migrationVersion, round });
    mkdirSync(path.dirname(sqlTarget), { recursive: true });
    writeFileSync(sqlTarget, toSeedSql(cat, { migrationVersion, round }));
    written.push(sqlTarget);
  }
  return { catalog: cat, written };
}

function cli(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (!k.startsWith('--')) fail(`unexpected argument ${k}`);
    args[k.slice(2)] = argv[i + 1];
    i++;
  }
  if (args.hash) {
    for (const file of CSV_FILES) {
      const p = path.join(args.hash, file);
      if (existsSync(p)) console.log(`- sha256 ${file}: ${sha256(readFileSync(p, 'utf8'))}`);
    }
    return;
  }
  if (!args.snapshot || (!args['json-out'] && !args['sql-out'])) {
    fail('usage: --snapshot <dir> --json-out <file> [--sql-out <file|dir> --migration-version <14 digits> --round <n>]');
  }
  const { catalog, written } = build({
    snapshot: args.snapshot,
    jsonOut: args['json-out'],
    sqlOut: args['sql-out'],
    migrationVersion: args['migration-version'],
    round: args.round,
  });
  console.log(`catalogue ${catalog.version}: ${catalog.states.length} States/UTs, ${catalog.districts.length} districts`);
  for (const w of written) console.log(`wrote ${w}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { cli(process.argv.slice(2)); }
  catch (e) {
    if (e instanceof CatalogError) { console.error(`error: ${e.message}`); process.exit(1); }
    throw e;
  }
}
