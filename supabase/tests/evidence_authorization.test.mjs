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

const old = await setup();
try {
  const noBid = await seedLedger(old, jid(2), ENGINEER, 'private no-bid record');
  const orphan = await seedLedger(old, jid(1), null, 'orphan record');
  await test('baseline reproduces authenticated arbitrary-source evidence insertion', async () => {
    const id = await register(old, OUTSIDER, receipt({ job: jid(99), source: 'invented_source', kind: 'signature_hospital', producer: 'founder', url: 'https://untrusted.invalid/fake' }));
    assert(id);
  });
  await test('baseline reproduces populated no-bid evidence disclosure', async () => {
    assert((await rowsFor(old,OUTSIDER,jid(2))).some((row) => row.id === noBid));
  });
  await test('baseline reproduces nullable-producer verification disclosure', async () => {
    assert.equal((await verify(old,OUTSIDER,orphan,digest('orphan record'))).length,1);
  });
} finally { await old.close(); }

const db = await setup();
try {
  const originalCanonical = (await db.query("SELECT pg_get_functiondef('public.register_canonical_evidence(text,uuid,jsonb,uuid,text,timestamptz,text)'::regprocedure) AS body")).rows[0].body;
  await db.exec(migrationSql); // exact forward migration; never a rewritten test copy
  const beforeUrl = await seedPhoto(db,ENGINEER,jid(1),'before-photo.jpg');
  const afterUrl = await seedPhoto(db,ENGINEER,jid(1),'after-photo.jpg','after_photos');
  const amcUrl = await seedPhoto(db,ENGINEER,jid(3),'before-amc.jpg');
  const staleUrl = await seedPhoto(db,ENGINEER,jid(4),'before-stale.jpg');
  const clearUrl = await seedPhoto(db,ENGINEER,jid(5),'before-cleared.jpg');
  const newAssignedUrl = await seedPhoto(db,ENGINEER_B,jid(4),'before-current.jpg');
  const noBid = await seedLedger(db,jid(2),ENGINEER,'private no-bid record');
  const amc = await seedLedger(db,jid(3),ENGINEER,'private AMC record');
  const reassigned = await seedLedger(db,jid(4),ENGINEER_B,'reassigned record');
  const cleared = await seedLedger(db,jid(5),ENGINEER,'cleared assignment record');
  const orphan = await seedLedger(db,jid(1),uid(8),'deleted user record');
  await db.query('DELETE FROM auth.users WHERE id=$1::uuid',[uid(8)]);
  let photoId;

  await test('assigned engineer registers attached owned photo with server-owned provenance markers', async () => {
    photoId = await register(db,ENGINEER,receipt({ metadata: { hash_verification: 'server_verified', fixture: 'original' } }));
    const row = (await db.query('SELECT * FROM public.evidence_ledger WHERE id=$1::uuid',[photoId])).rows[0];
    assert.equal(row.producer_user_id,ENGINEER);
    assert.equal(row.producer_kind,'engineer');
    assert.equal(row.storage_url,beforeUrl);
    assert.equal(row.metadata.hash_verification,'client_asserted');
    assert.equal(row.metadata.registration_authority,'assigned_engineer');
    assert(row.metadata.storage_object_id);
  });
  await test('legitimate retry returns same id and preserves original metadata/capture time', async () => {
    assert.equal(await register(db,ENGINEER,receipt({ captured: '2026-09-08T00:00:00Z', metadata: { fixture: 'replacement' } })),photoId);
    const row = (await db.query('SELECT metadata,captured_at FROM public.evidence_ledger WHERE id=$1::uuid',[photoId])).rows[0];
    assert.equal(row.metadata.fixture,'original');
    assert.equal(new Date(row.captured_at).toISOString(),'2026-09-07T06:00:00.000Z');
  });
  await test('after photo registers only from the matching attachment array', async () => {
    assert(await register(db,ENGINEER,receipt({ kind:'photo_after',url:afterUrl,hash:digest('after') })));
    await denied(() => register(db,ENGINEER,receipt({ url:afterUrl,hash:digest('wrong-array') })));
  });
  await test('direct-assigned AMC engineer registers and reads without a bid', async () => {
    assert(await register(db,ENGINEER,receipt({ job:jid(3),url:amcUrl,hash:digest('AMC photo') })));
    assert((await rowsFor(db,ENGINEER,jid(3))).some((row) => row.id === amc));
  });
  await test('hospital owner and founder read populated job evidence', async () => {
    assert((await rowsFor(db,HOSPITAL,jid(2))).some((row) => row.id === noBid));
    assert((await rowsFor(db,FOUNDER,jid(4))).some((row) => row.id === reassigned));
  });
  for (const [label,actor,job] of [
    ['foreign hospital on no-bid job',OUTSIDER,jid(2)],
    ['foreign engineer on no-bid job',ENGINEER_B,jid(2)],
    ['outsider on AMC job',OUTSIDER,jid(3)],
    ['former engineer with stale accepted bid',ENGINEER,jid(4)],
    ['engineer with cleared assignment and stale accepted bid',ENGINEER,jid(5)]
  ]) await test(`reader denies ${label}`, () => denied(() => rowsFor(db,actor,job)));
  await test('new canonical engineer reads populated reassigned job', async () => {
    assert((await rowsFor(db,ENGINEER_B,jid(4))).some((row) => row.id === reassigned));
  });
  await test('cleared-assignment hospital still reads retained evidence', async () => {
    assert((await rowsFor(db,HOSPITAL,jid(5))).some((row) => row.id === cleared));
  });
  for (const [label,actor,r] of [
    ['foreign hospital',OUTSIDER,receipt()],
    ['hospital claiming engineer producer',HOSPITAL,receipt()],
    ['unassigned engineer',ENGINEER_B,receipt()],
    ['former engineer after reassignment',ENGINEER,receipt({job:jid(4),url:staleUrl})],
    ['cleared assignment despite accepted bid',ENGINEER,receipt({job:jid(5),url:clearUrl})],
    ['foreign source using owned object',ENGINEER,receipt({job:jid(4)})],
    ['arbitrary nonrepair source',ENGINEER,receipt({source:'chat'})],
    ['null source kind',ENGINEER,receipt({source:null})],
    ['forged signature kind',ENGINEER,receipt({kind:'signature_hospital'})],
    ['unknown evidence kind',ENGINEER,receipt({kind:'invented'})],
    ['null evidence kind',ENGINEER,receipt({kind:null})],
    ['forged system producer',ENGINEER,receipt({producer:'system'})],
    ['forged founder producer',ENGINEER,receipt({producer:'founder'})],
    ['null producer kind',ENGINEER,receipt({producer:null})]
  ]) await test(`registration denies ${label}`, () => denied(() => register(db,actor,r)));
  await test('new canonical engineer registers despite another engineer stale bid', async () => {
    assert(await register(db,ENGINEER_B,receipt({job:jid(4),url:newAssignedUrl,hash:digest('new assigned')})));
  });
  await test('missing or null job is denied, including founder reader', async () => {
    for (const job of [jid(99),null]) {
      await denied(() => register(db,ENGINEER,receipt({job})), '02000');
      await denied(() => rowsFor(db,FOUNDER,job), '02000');
    }
  });
  for (const [label,url] of [
    ['foreign owner prefix',beforeUrl.replace(ENGINEER,ENGINEER_B)],
    ['foreign job prefix',beforeUrl.replace(jid(1),jid(3))],
    ['absolute URL',`https://example.invalid/${beforeUrl}`],
    ['wrong bucket',beforeUrl.replace('repair-photos','kyc-docs')],
    ['case-folded bucket',beforeUrl.replace('repair-photos','REPAIR-PHOTOS')],
    ['parent traversal',`repair-photos/${ENGINEER}/${jid(1)}/..`],
    ['nested path',`repair-photos/${ENGINEER}/${jid(1)}/nested/photo.jpg`],
    ['query token',`${beforeUrl}?token=synthetic`],
    ['encoded slash',`${beforeUrl}%2fextra`],
    ['backslash',`${beforeUrl}\\extra`],
    ['null path',null]
  ]) await test(`registration denies ${label}`, () => denied(() => register(db,ENGINEER,receipt({url}))));
  await test('existing but unattached object is denied', async () => {
    const object = `${ENGINEER}/${jid(1)}/unattached.jpg`;
    await db.query("INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES('repair-photos',$1,$2,'{\"size\":3}')",[object,ENGINEER]);
    await denied(() => register(db,ENGINEER,receipt({url:`repair-photos/${object}`})));
  });
  await test('attached but missing object is denied', async () => {
    const object = `${ENGINEER}/${jid(1)}/missing.jpg`;
    await db.query('UPDATE public.repair_jobs SET before_photos = before_photos || ARRAY[$1::text] WHERE id=$2::uuid',[object,jid(1)]);
    await denied(() => register(db,ENGINEER,receipt({url:`repair-photos/${object}`})),'02000');
  });
  await test('object with absent or different stored owner is denied', async () => {
    for (const owner of [null,ENGINEER_B]) {
      const url = await seedPhoto(db,ENGINEER,jid(1),`owner-${owner ?? 'null'}.jpg`,'before_photos',owner);
      await denied(() => register(db,ENGINEER,receipt({url})));
    }
  });
  await test('legacy Storage owner column is accepted only for the actual owner', async () => {
    const url = await seedPhoto(db,ENGINEER,jid(1),'legacy-owner.jpg','before_photos',null);
    await db.query('UPDATE storage.objects SET owner=$1::uuid WHERE name=$2',[ENGINEER,url.slice('repair-photos/'.length)]);
    assert(await register(db,ENGINEER,receipt({url,hash:digest('legacy-owner')})));
    await db.query('UPDATE storage.objects SET owner_id=$1 WHERE name=$2',[ENGINEER_B,url.slice('repair-photos/'.length)]);
    await denied(() => register(db,ENGINEER,receipt({url,hash:digest('legacy-owner')})));
  });
  await test('missing/mismatched storage size and invalid client hash/size are rejected', async () => {
    await denied(() => register(db,ENGINEER,receipt({size:4})),'22023');
    for (const change of [{size:null},{size:0},{hash:null},{hash:'NOT-A-HASH'}])
      await denied(() => register(db,ENGINEER,receipt(change)),'22023');
    const url = await seedPhoto(db,ENGINEER,jid(1),'missing-size.jpg');
    await db.query("UPDATE storage.objects SET metadata='{}' WHERE name=$1",[url.slice('repair-photos/'.length)]);
    await denied(() => register(db,ENGINEER,receipt({url})),'22023');
  });
  await test('non-object client metadata is rejected', () => denied(() => register(db,ENGINEER,receipt({metadata:[]})),'22023'));
  await test('auth check precedes idempotency for an already registered digest', () => denied(() => register(db,OUTSIDER)));
  await test('idempotency cannot claim a foreign or deleted producer record', async () => {
    for (const producer of [ENGINEER_B,null]) {
      const text = `existing-${producer}`;
      const id = await seedLedger(db,jid(1),producer,text,'photo_before',beforeUrl);
      await denied(() => register(db,ENGINEER,receipt({hash:digest(text)})));
      assert.equal((await db.query('SELECT producer_user_id FROM public.evidence_ledger WHERE id=$1::uuid',[id])).rows[0].producer_user_id,producer);
    }
  });
  await test('same digest for a different object cannot replace original evidence', async () => {
    const url = await seedPhoto(db,ENGINEER,jid(1),'second-object.jpg');
    await denied(() => register(db,ENGINEER,receipt({url})));
    assert.equal((await db.query('SELECT storage_url FROM public.evidence_ledger WHERE id=$1::uuid',[photoId])).rows[0].storage_url,beforeUrl);
  });
  await test('producer verifies own digest, mismatch returns false, outsiders deny', async () => {
    assert.equal((await verify(db,ENGINEER,photoId,digest('base-photo')))[0].matches,true);
    assert.equal((await verify(db,ENGINEER,photoId,digest('other-bytes')))[0].matches,false);
    await denied(() => verify(db,OUTSIDER,photoId,digest('base-photo')));
    await denied(() => verify(db,HOSPITAL,photoId,digest('base-photo'))); // prior producer-only contract
  });
  await test('deleted producer cannot authorize another user; privileged retention reads explicit', async () => {
    assert.equal((await db.query('SELECT producer_user_id FROM public.evidence_ledger WHERE id=$1::uuid',[orphan])).rows[0].producer_user_id,null);
    await denied(() => verify(db,OUTSIDER,orphan,digest('deleted user record')));
    assert.equal((await verify(db,FOUNDER,orphan,digest('deleted user record')))[0].matches,true);
    assert.equal((await verify(db,null,orphan,digest('deleted user record'),'service_role'))[0].matches,true);
  });
  await test('missing evidence and null hash are rejected', async () => {
    await denied(() => verify(db,ENGINEER,jid(99),digest('base-photo')),'02000');
    await denied(() => verify(db,ENGINEER,photoId,null),'22023');
  });
  await test('missing UID and missing role do not bypass authenticated RPC gates', async () => {
    for (const claimRole of [null,'authenticated']) {
      await denied(() => register(db,null,receipt(),'authenticated',claimRole));
      await denied(() => verify(db,null,photoId,digest('base-photo'),'authenticated',claimRole));
    }
    await denied(() => rowsFor(db,null,jid(1)));
  });
  await test('anonymous EXECUTE is revoked for all three RPCs', async () => {
    await denied(() => register(db,null,receipt(),'anon'));
    await denied(() => rowsFor(db,null,jid(1),'anon'));
    await denied(() => verify(db,null,photoId,digest('base-photo'),'anon'));
  });
  await test('trusted service-role nonrepair producer contract remains usable and idempotent', async () => {
    const r = receipt({source:'chat',job:jid(90),kind:'chat_archive',producer:'system',url:null,hash:digest('trusted archive')});
    const id = await register(db,null,r,'service_role');
    assert.equal(await register(db,null,r,'service_role'),id);
    assert.equal((await verify(db,null,id,r.hash,'service_role'))[0].matches,true);
    await denied(() => register(db,ENGINEER,r));
  });
  await test('existing internal canonical signature writer is unchanged and still gated', async () => {
    const body = (await db.query("SELECT pg_get_functiondef('public.register_canonical_evidence(text,uuid,jsonb,uuid,text,timestamptz,text)'::regprocedure) AS body")).rows[0].body;
    assert.equal(body,originalCanonical);
    const sql = `SELECT public.register_canonical_evidence('signature_hospital',$1::uuid,$2::jsonb,$3::uuid,'hospital',now(),'fixture') AS id`;
    const params = [jid(1),JSON.stringify({fixture:'trusted countersign'}),HOSPITAL];
    await denied(() => as(db,ENGINEER,sql,params));
    const id = (await as(db,null,sql,params,'service_role')).rows[0].id;
    const row = (await db.query("SELECT content_sha256,encode(extensions.digest(convert_to(metadata::text,'UTF8'),'sha256'),'hex') AS recomputed FROM public.evidence_ledger WHERE id=$1::uuid",[id])).rows[0];
    assert.equal(row.content_sha256,row.recomputed);
  });
  await test('rapid queued duplicate calls return one id (single PGlite connection, not a multi-session race test)', async () => {
    const ids = await Promise.all(Array.from({length:5},() => register(db,ENGINEER)));
    assert.deepEqual([...new Set(ids)],[photoId]);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM public.evidence_ledger WHERE source_id=$1::uuid AND content_sha256=$2',[jid(1),digest('base-photo')])).rows[0].n,1);
  });
  await test('forward migration is reapplicable without changing existing records', async () => {
    const before = (await db.query('SELECT row_to_json(e) AS row FROM public.evidence_ledger e ORDER BY id')).rows;
    await db.exec(migrationSql);
    assert.deepEqual((await db.query('SELECT row_to_json(e) AS row FROM public.evidence_ledger e ORDER BY id')).rows,before);
    assert.equal(await register(db,ENGINEER),photoId);
  });
} finally { await db.close(); }

console.log(`Evidence authorization: ${passed} passed, ${failures.length} failed.`);
console.log('Scope: populated focused PostgreSQL fixture, actual r492 RPC migration and exact forward migration; not full Supabase replay, deployed-state verification, storage byte validation, real multi-session lock testing, or Android/device execution.');
if (failures.length) process.exitCode = 1;
