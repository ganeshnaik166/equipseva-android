// INT-04, Node half: the real-shape Android r3820 photo-evidence receipts recorded in
// android_evidence_contract.json (shared with the Kotlin RepairPhotoEvidenceContractTest)
// executed against the ACTUAL round492 and round3821 register_evidence SQL on PGlite.
//
// Harness duplicated from evidence_authorization.test.mjs on purpose (additive rule of the
// helper branch); factoring into a shared module is the plan owner's call. Everything up to
// setup() mirrors that file verbatim; receipt(), denied(), verify(), seedPhoto() and
// seedLedger() are kept for parity and are not used below, because this suite derives every
// receipt, object path, regex and verdict from the JSON fixture instead of retyping them.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

// Default: npm install in this directory. An already provisioned runtime can
// be selected explicitly without committing a machine-specific path.
const require = createRequire(import.meta.url);
const runtime = process.env.EQS_PGLITE_PACKAGE;
const { PGlite } = require(runtime || '@electric-sql/pglite');
const { pgcrypto } = require(runtime
  ? path.join(runtime, 'dist/contrib/pgcrypto.cjs')
  : '@electric-sql/pglite/contrib/pgcrypto');
const here = path.dirname(fileURLToPath(import.meta.url));
const migrations = path.resolve(here, '../migrations');
const readMigration = (name) => readFile(path.join(migrations, name), 'utf8');
const baselineSql = await readMigration('20260811000000_round492_evidence_65b_chain.sql');
const migrationSql = await readMigration('20263898000000_round3821_evidence_authorization.sql');
const canonicalSql = await readMigration('20263897000000_round3819_dsr_signatures_65b_ledger.sql');
const fixtureSql = await readFile(path.join(here, 'evidence_authorization.fixture.sql'), 'utf8');
const canonicalStart = canonicalSql.indexOf('CREATE OR REPLACE FUNCTION public.register_canonical_evidence(');
const canonicalRevoke = canonicalSql.indexOf('REVOKE EXECUTE ON FUNCTION public.register_canonical_evidence(', canonicalStart);
assert(canonicalStart >= 0 && canonicalRevoke > canonicalStart, 'existing canonical writer must be found');
const canonicalWriter = canonicalSql.slice(canonicalStart, canonicalSql.indexOf(';', canonicalRevoke) + 1);

const uid = (n) => `10000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const jid = (n) => `30000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const HOSPITAL = uid(1), OUTSIDER = uid(2), ENGINEER = uid(3), ENGINEER_B = uid(4), FOUNDER = uid(5);
const digest = (text) => createHash('sha256').update(text).digest('hex');
let passed = 0;
const failures = [];
async function test(name, action) {
  try { await action(); passed++; console.log(`PASS ${name}`); }
  catch (error) { failures.push({ name, error }); console.error(`FAIL ${name}: ${error.message}`); }
}

async function as(db, actor, sql, params = [], role = 'authenticated', claimRole = role) {
  assert(['authenticated', 'anon', 'service_role'].includes(role));
  return db.transaction(async (tx) => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    await tx.query("SELECT set_config('request.jwt.claim.sub',$1,true), set_config('request.jwt.claim.role',$2,true)",
      [actor ?? '', claimRole ?? '']);
    return tx.query(sql, params);
  });
}
async function denied(action, expected = '42501') {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, expected, `expected SQLSTATE ${expected}, got ${error.code}: ${error.message}`);
    return true;
  });
}
function receipt(overrides = {}) {
  return { kind: 'photo_before', source: 'repair_job', job: jid(1), hash: digest('base-photo'),
    size: 3, url: `repair-photos/${ENGINEER}/${jid(1)}/before-photo.jpg`, producer: 'engineer',
    captured: '2026-09-07T06:00:00Z', platform: 'android/0.3.6', metadata: { mime_type: 'image/jpeg', captured_from: 'upload_time' },
    ...overrides };
}
async function register(db, actor, r = receipt(), role = 'authenticated', claimRole = role) {
  const result = await as(db, actor, `SELECT public.register_evidence(
    $1,$2,$3::uuid,$4,$5::bigint,$6,$7,$8::timestamptz,$9,$10::jsonb) AS id`,
  [r.kind,r.source,r.job,r.hash,r.size,r.url,r.producer,r.captured,r.platform,JSON.stringify(r.metadata)], role, claimRole);
  return result.rows[0].id;
}
async function rowsFor(db, actor, job, role = 'authenticated') {
  return (await as(db, actor, 'SELECT * FROM public.evidence_for_repair_job($1::uuid)', [job], role)).rows;
}
async function verify(db, actor, id, hash, role = 'authenticated', claimRole = role) {
  return (await as(db, actor, 'SELECT * FROM public.verify_evidence_hash($1::uuid,$2)', [id,hash], role,claimRole)).rows;
}
async function seedPhoto(db, actor, job, filename, column = 'before_photos', ownerId = actor, size = 3) {
  assert(['before_photos', 'after_photos'].includes(column));
  const object = `${actor}/${job}/${filename}`;
  await db.query('INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES($1,$2,$3,$4::jsonb)',
    ['repair-photos', object, ownerId, JSON.stringify({ size, mimetype: 'image/jpeg' })]);
  await db.query(`UPDATE public.repair_jobs SET ${column} = coalesce(${column},'{}') || ARRAY[$1::text] WHERE id=$2::uuid`, [object,job]);
  return `repair-photos/${object}`;
}
async function seedLedger(db, job, producer, text, kind = 'signature_engineer', url = null, size = 3) {
  return (await db.query(`INSERT INTO public.evidence_ledger
    (evidence_kind,source_kind,source_id,content_sha256,content_size_bytes,storage_url,producer_user_id,producer_kind,metadata)
    VALUES($1,'repair_job',$2::uuid,$3,$4,$5,$6::uuid,'engineer',$7::jsonb) RETURNING id`,
  [kind,job,digest(text),size,url,producer,JSON.stringify({ fixture: text })])).rows[0].id;
}
async function setup() {
  const db = new PGlite({ extensions: { pgcrypto } });
  await db.exec(fixtureSql);
  // Execute the actual old migration, including its grants and postconditions.
  await db.exec(baselineSql);
  // Same server-owned canonical writer remains present before and after patch.
  await db.exec(canonicalWriter);
  return db;
}

// ---------------------------------------------------------------------------------------
// Contract suite. Every receipt, object path, regex and verdict below is read from the
// shared JSON fixture; the only literals are the server-owned marker values of r3821.
const fixture = JSON.parse(await readFile(path.join(here, 'android_evidence_contract.json'), 'utf8'));
const rules = fixture.rules;
const JOB = fixture.identities.job_id;
const before = fixture.conforming_example;
const after = fixture.after_example;
const variants = fixture.non_conforming_variants.variants;
const platforms = fixture.platform_version_examples_accepted;
const uuidRe = new RegExp(rules.uuid_regex);
const storageUrlRe = new RegExp(rules.storage_url_regex);
const storedNameRe = new RegExp(rules.client_stored_name_regex);
const filenameRe = new RegExp(rules.filename_regex);
const shaRe = new RegExp(rules.content_sha256_regex);
const platformRe = new RegExp(rules.platform_version_regex);
const bucketPrefix = `${rules.bucket}/`;
// object_path is bucket-relative: <uid>/<job>/<filename>, one segment fewer than storage_url.
function filenameOf(objectPath) {
  const parts = objectPath.split('/');
  assert.equal(parts.length, rules.segment_count - 1, `object path must have ${rules.segment_count - 1} segments: ${objectPath}`);
  return parts[2];
}

// denied() above checks the SQLSTATE only; five different 42501 RAISEs would be
// indistinguishable. This also pins the RAISE literal when the fixture names one.
async function deniedWith(action, sqlstate, literal) {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, sqlstate, `expected SQLSTATE ${sqlstate}, got ${error.code}: ${error.message}`);
    if (literal !== undefined) {
      assert(String(error.message).includes(literal), `expected RAISE literal "${literal}" in: ${error.message}`);
    }
    return true;
  });
}
// Fixture field names -> the register() parameter shape. The actor is always the fixture's
// engineer (== ENGINEER, asserted below); the job is the fixture's job (== jid(1)).
function receiptFrom(example, overrides = {}) {
  return { kind: example.evidence_kind, source: example.source_kind, job: JOB, hash: example.content_sha256,
    size: example.content_size_bytes, url: example.storage_url, producer: example.producer_kind,
    captured: example.captured_at, platform: example.platform_version, metadata: example.metadata,
    ...overrides };
}
// The conforming example with the variant's single fixture-field mutation applied.
function variantReceipt(variant) { return receiptFrom({ ...before, ...variant.mutation }); }
// Seed storage.objects and the job attachment array with the fixture object path verbatim
// (not the copied seedPhoto(), which retypes a filename). Runs as the superuser, outside as().
async function seedFromFixture(db, objectPath, column, size, mimetype) {
  assert(['before_photos', 'after_photos'].includes(column));
  await db.query('INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES($1,$2,$3,$4::jsonb)',
    [rules.bucket, objectPath, ENGINEER, JSON.stringify({ size, mimetype })]);
  await db.query(`UPDATE public.repair_jobs SET ${column} = coalesce(${column},'{}') || ARRAY[$1::text] WHERE id=$2::uuid`, [objectPath, JOB]);
  return `${bucketPrefix}${objectPath}`;
}
async function seedExample(db, example) {
  return seedFromFixture(db, example.object_path, example.attach_to_column, example.content_size_bytes, example.metadata.mime_type);
}
// A sibling of the example's object path that differs only in the sanitized-name suffix, so
// it still has the client's <before|after>-<millis>-<uuid>-<sanitized40> shape.
function siblingObjectPath(example, suffix) {
  const filename = filenameOf(example.object_path);
  const row = fixture.sanitizer_table.find((r) => r.expected !== '' && filename.endsWith(`-${r.expected}`));
  assert(row, `fixture filename must end with a sanitizer_table expected name: ${filename}`);
  const stem = filename.slice(0, filename.length - row.expected.length);
  const sibling = `${stem}${suffix}`;
  assert.match(sibling, storedNameRe);
  assert.match(sibling, filenameRe);
  return `${example.object_path.slice(0, example.object_path.length - filename.length)}${sibling}`;
}
async function objectIdOf(db, objectPath) {
  return (await db.query('SELECT id FROM storage.objects WHERE bucket_id=$1 AND name=$2', [rules.bucket, objectPath])).rows[0].id;
}
async function ledgerCount(db) {
  return (await db.query('SELECT count(*)::int AS n FROM public.evidence_ledger WHERE source_kind=$1 AND source_id=$2::uuid',
    [rules.source_kind, JOB])).rows[0].n;
}
// What both migrations must echo back through evidence_for_repair_job for a registered receipt.
function assertClientFields(row, example) {
  assert(row, 'reader must return the registered row');
  assert.equal(row.evidence_kind, example.evidence_kind);
  assert.equal(row.storage_url, example.storage_url);
  assert.equal(row.content_sha256, example.content_sha256);
  assert.equal(Number(row.content_size_bytes), example.content_size_bytes); // int8 may arrive as BigInt
  assert.equal(row.producer_user_id, ENGINEER);
  assert.equal(row.producer_kind, rules.producer_kind);
  assert.equal(row.metadata.mime_type, example.metadata.mime_type);
  assert.equal(row.metadata.captured_from, rules.metadata_captured_from);
  assert.equal(row.metadata.client, rules.metadata_client);
}
// r3821 only: server-owned provenance markers merged into the client metadata.
function assertServerMarkers(row, objectId) {
  assert.equal(row.metadata.registration_authority, 'assigned_engineer');
  assert.equal(row.metadata.hash_verification, 'client_asserted');
  assert(row.metadata.storage_object_id, 'storage_object_id marker must be present');
  assert.equal(row.metadata.storage_object_id, objectId);
}
const variantName = (variant, half) =>
  `variant ${variant.id}: ${half}${variant.discriminating ? '' : ' (non-discriminating: contract pin, both migrations deny)'}`;

// --- 1. Fixture self-checks (pure JS) --------------------------------------------------
await test('fixture identities bind to the SQL fixture (engineer=uid(3), hospital=uid(1), job=jid(1)) and storage_url is bucket/object_path', () => {
  assert.equal(fixture.identities.engineer_uid, ENGINEER);
  assert.equal(fixture.identities.hospital_uid, HOSPITAL);
  assert.equal(JOB, jid(1));
  // The bucket literal r3821 compares v_parts[1] against.
  assert.equal(rules.bucket, 'repair-photos');
  assert(migrationSql.includes(`'${rules.bucket}'`), 'bucket literal must appear in the r3821 migration text');
  for (const example of [before, after]) {
    assert.equal(example.storage_url, `${bucketPrefix}${example.object_path}`);
    assert(example.storage_url.startsWith(bucketPrefix));
    assert.equal(example.storage_url.slice(bucketPrefix.length), example.object_path);
    const [uidSegment, jobSegment] = example.object_path.split('/');
    assert.equal(uidSegment, ENGINEER);
    assert.equal(jobSegment, JOB);
  }
});
await test('fixture examples conform to the fixture rules (segments, stored-name shape, sha, kinds, metadata, platform)', () => {
  for (const example of [before, after]) {
    assert.match(example.storage_url, storageUrlRe);
    assert.equal(example.storage_url.split('/').length, rules.segment_count);
    const filename = filenameOf(example.object_path);
    assert.match(filename, storedNameRe);
    assert.match(filename, filenameRe);
    assert(!rules.filename_forbidden.includes(filename));
    assert(filename.startsWith(example.evidence_kind === 'photo_before' ? 'before-' : 'after-'));
    assert.match(example.content_sha256, shaRe);
    assert(example.content_size_bytes >= rules.content_size_min);
    assert(rules.evidence_kinds.includes(example.evidence_kind));
    assert.equal(example.source_kind, rules.source_kind);
    assert.equal(example.producer_kind, rules.producer_kind);
    assert.deepEqual(Object.keys(example.metadata).sort(), [...rules.metadata_keys].sort());
    assert.equal(example.metadata.captured_from, rules.metadata_captured_from);
    assert.equal(example.metadata.client, rules.metadata_client);
    assert.match(example.platform_version, platformRe);
    assert(platforms.includes(example.platform_version));
  }
  // The kind -> attachment-array pairing r3821 enforces in its CASE.
  assert.equal(before.evidence_kind, 'photo_before');
  assert.equal(before.attach_to_column, 'before_photos');
  assert.equal(after.evidence_kind, 'photo_after');
  assert.equal(after.attach_to_column, 'after_photos');
  assert(platforms.length > 0);
  for (const platform of platforms) assert.match(platform, platformRe);
});
await test('fixture variants each mutate exactly one known field off-contract, with verdicts drawn from rules.server_sqlstates', () => {
  assert(variants.length > 0);
  const ids = new Set();
  for (const variant of variants) {
    assert(!ids.has(variant.id), `duplicate variant id ${variant.id}`);
    ids.add(variant.id);
    const keys = Object.keys(variant.mutation);
    assert.equal(keys.length, 1, `${variant.id}: exactly one mutation`);
    const [key] = keys;
    assert(key in before, `${variant.id}: ${key} must be a conforming_example field`);
    assert.notEqual(variant.mutation[key], before[key], `${variant.id}: mutation must change the field`);
    if (key === 'storage_url') assert.doesNotMatch(variant.mutation[key], storageUrlRe, variant.id);
    else if (key === 'content_sha256') assert.doesNotMatch(variant.mutation[key], shaRe, variant.id);
    else if (key === 'evidence_kind') assert(!rules.evidence_kinds.includes(variant.mutation[key]), variant.id);
    else if (key === 'producer_kind') assert.notEqual(variant.mutation[key], rules.producer_kind, variant.id);
    else assert.fail(`${variant.id}: unhandled mutation field ${key}`);
    assert(['accepted', 'denied'].includes(variant.r492.outcome), variant.id);
    if (variant.r492.outcome === 'denied') assert.match(variant.r492.sqlstate, /^[0-9A-Z]{5}$/);
    assert.equal(variant.r3821.outcome, 'denied', variant.id);
    assert(typeof variant.r3821.literal === 'string' && variant.r3821.literal.length > 0, variant.id);
    assert(Object.entries(rules.server_sqlstates).some(([name, code]) => name.startsWith(variant.r3821.literal) && code === variant.r3821.sqlstate),
      `${variant.id}: r3821 literal/sqlstate pair must come from rules.server_sqlstates`);
    assert(migrationSql.includes(variant.r3821.literal), `${variant.id}: RAISE literal must exist in the r3821 migration text`);
    assert.equal(variant.discriminating, variant.r492.outcome === 'accepted', `${variant.id}: discriminating means r492 accepts and r3821 denies`);
  }
});
await test('fixture Kotlin sample bytes hash to the conforming content_sha256 and size', () => {
  const bytes = Buffer.from(fixture.kotlin.photo_bytes);
  assert.equal(createHash('sha256').update(bytes).digest('hex'), fixture.kotlin.content_sha256);
  assert.equal(fixture.kotlin.content_sha256, before.content_sha256);
  assert.equal(bytes.length, fixture.kotlin.content_size_bytes);
  assert.equal(fixture.kotlin.content_size_bytes, before.content_size_bytes);
  assert.equal(fixture.kotlin.captured_from, rules.metadata_captured_from);
});
await test('fixture sanitizer table matches take(N)-then-replace over UTF-16 code units', () => {
  const { take, replace_regex: pattern, replacement } = rules.sanitizer;
  const replaceRe = new RegExp(pattern, 'g');
  assert(fixture.sanitizer_table.length > 0);
  for (const row of fixture.sanitizer_table) {
    // String.prototype.slice counts UTF-16 code units, exactly like Kotlin's String.take().
    assert.equal(row.input.slice(0, take).replace(replaceRe, replacement), row.expected, `${JSON.stringify(row.input)}: ${row.why}`);
    if (row.expected !== '') assert.match(row.expected, filenameRe, `sanitized name must satisfy the server filename charset: ${row.expected}`);
  }
});

// --- 2. round492 (what production runs): positive controls and per-variant verdicts -----
const old = await setup();
try {
  let oldBeforeId;
  await test('r492 positive control: conforming before receipt registers with no url validation; hospital and engineer read it bucket-prefixed (reader half is non-discriminating: r3821 grants both too)', async () => {
    oldBeforeId = await register(old, ENGINEER, receiptFrom(before));
    assert.match(oldBeforeId, uuidRe);
    for (const reader of [HOSPITAL, ENGINEER]) {
      assertClientFields((await rowsFor(old, reader, JOB)).find((row) => row.id === oldBeforeId), before);
    }
  });
  await test('r492 positive control: conforming after receipt registers', async () => {
    const id = await register(old, ENGINEER, receiptFrom(after));
    assert.match(id, uuidRe);
    assert.notEqual(id, oldBeforeId);
  });
  // r492 has no url/object checks. A variant that changes only the url or the producer keeps
  // the (kind, source, job, sha) key of the conforming row inserted above, so r492's idempotent
  // path returns that existing id: still 'accepted' (a uuid comes back). A kind change
  // (photo_during) inserts a new row. A denied variant rejects inside as()'s db.transaction,
  // which rolls back, so no aborted transaction stays open on the single PGlite connection.
  for (const variant of variants) {
    const half = `r492 ${variant.r492.outcome}${variant.r492.outcome === 'denied' ? ` ${variant.r492.sqlstate}` : ''}`;
    await test(variantName(variant, half), async () => {
      if (variant.r492.outcome === 'accepted') assert.match(await register(old, ENGINEER, variantReceipt(variant)), uuidRe);
      else await deniedWith(() => register(old, ENGINEER, variantReceipt(variant)), variant.r492.sqlstate, undefined);
    });
  }
  await test('r492 ledger after variants: only mutations of a uniqueness-key column inserted; url/producer variants took the idempotent path', async () => {
    // evidence_ledger_uniq = (evidence_kind, source_kind, source_id, content_sha256); source_id is constant here.
    const inserted = variants.filter((v) => v.r492.outcome === 'accepted'
      && ['evidence_kind', 'source_kind', 'content_sha256'].includes(Object.keys(v.mutation)[0])).length;
    assert.equal(await ledgerCount(old), 2 + inserted);
  });
} finally { await old.close(); }

// --- 3. round3821 (candidate): seeded positive controls and per-variant denials -----------
const db = await setup();
try {
  await db.exec(migrationSql); // exact forward migration; never a rewritten test copy
  assert.equal(await seedExample(db, before), before.storage_url);
  assert.equal(await seedExample(db, after), after.storage_url);
  let beforeId;
  await test('r3821 positive control: seeded conforming before receipt registers with server-owned provenance markers; hospital and engineer read it bucket-prefixed', async () => {
    beforeId = await register(db, ENGINEER, receiptFrom(before));
    assert.match(beforeId, uuidRe);
    const objectId = await objectIdOf(db, before.object_path);
    for (const reader of [HOSPITAL, ENGINEER]) {
      const row = (await rowsFor(db, reader, JOB)).find((r) => r.id === beforeId);
      assertClientFields(row, before);
      assertServerMarkers(row, objectId);
    }
  });
  await test('r3821 positive control: retry with a different captured_at returns the same id and keeps the original capture time', async () => {
    const original = new Date(before.captured_at).toISOString();
    const retryCaptured = new Date(new Date(before.captured_at).getTime() + 60000).toISOString();
    assert.notEqual(retryCaptured, original);
    assert.equal(await register(db, ENGINEER, receiptFrom(before, { captured: retryCaptured })), beforeId);
    const row = (await db.query('SELECT captured_at FROM public.evidence_ledger WHERE id=$1::uuid', [beforeId])).rows[0];
    assert.equal(new Date(row.captured_at).toISOString(), original);
  });
  await test('r3821 positive control: seeded conforming after receipt registers from after_photos and reads back', async () => {
    const id = await register(db, ENGINEER, receiptFrom(after));
    assert.match(id, uuidRe);
    assert.notEqual(id, beforeId);
    const objectId = await objectIdOf(db, after.object_path);
    for (const reader of [HOSPITAL, ENGINEER]) {
      const row = (await rowsFor(db, reader, JOB)).find((r) => r.id === id);
      assertClientFields(row, after);
      assertServerMarkers(row, objectId);
    }
  });
  for (const [index, platform] of platforms.entries()) {
    await test(`r3821 accepts platform_version ${platform} on a sibling conforming object`, async () => {
      const objectPath = siblingObjectPath(before, `platform_${index}.jpg`);
      assert.notEqual(objectPath, before.object_path);
      const url = await seedExample(db, { ...before, object_path: objectPath });
      assert.match(url, storageUrlRe);
      const hash = digest(`platform-${platform}`);
      const id = await register(db, ENGINEER, receiptFrom(before, { url, hash, platform }));
      assert.match(id, uuidRe);
      const row = (await rowsFor(db, ENGINEER, JOB)).find((r) => r.id === id);
      assertClientFields(row, { ...before, storage_url: url, content_sha256: hash });
      assertServerMarkers(row, await objectIdOf(db, objectPath));
      assert.equal((await db.query('SELECT platform_version FROM public.evidence_ledger WHERE id=$1::uuid', [id])).rows[0].platform_version, platform);
    });
  }
  // Every denial below is raised before r3821's INSERT, so the ledger must be unchanged after.
  for (const variant of variants) {
    await test(variantName(variant, `r3821 denied ${variant.r3821.sqlstate} ${variant.r3821.literal}`), () =>
      deniedWith(() => register(db, ENGINEER, variantReceipt(variant)), variant.r3821.sqlstate, variant.r3821.literal));
  }
  await test('r3821 denials wrote nothing: the ledger holds exactly the accepted receipts', async () => {
    assert.equal(await ledgerCount(db), 2 + platforms.length);
  });
} finally { await db.close(); }

// 5 fixture self-checks + r492 (2 positive + 9 variants + 1 ledger) + r3821 (3 positive
// + 2 platform + 9 variants + 1 ledger). Update when the fixture's variants or
// platform_version_examples_accepted arrays change; a silent zero-iteration loop must fail here.
const EXPECTED = 32;
console.log(`Evidence client contract: ${passed} passed, ${failures.length} failed (expected ${EXPECTED}).`);
console.log('Scope: real-shape Android receipts from android_evidence_contract.json executed against the actual r492 and r3821 SQL on PGlite; NOT real Storage owner/metadata semantics, deployed state, or device behaviour.');
if (failures.length) process.exitCode = 1;
assert.equal(passed + failures.length, EXPECTED, `expected-count guard: ${passed + failures.length} test() calls ran, ${EXPECTED} were written`);
