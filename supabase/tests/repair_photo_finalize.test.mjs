import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

// Execute actual migration files against populated synthetic tables. These
// tests do not claim independent sessions, full-schema replay or Storage HTTP.
const read = (path) => readFile(new URL(path, import.meta.url), 'utf8');
const fixture = await read('./evidence_authorization.fixture.sql');
const baseline = await read('../migrations/20260811000000_round492_evidence_65b_chain.sql');
const authorization = await read('../migrations/20263898000000_round3821_evidence_authorization.sql');
const candidate = await read('../migrations/20263900000000_round3823_finalize_repair_photo.sql');
const uid = (n) => `10000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const ACTOR = uid(3), OTHER = uid(4);
const signature = 'public.finalize_repair_photo(uuid,text,text,text,bigint,timestamptz,text,jsonb)';
const digest = (s) => createHash('sha256').update(s).digest('hex');
let sequence = 100;
const db = new PGlite({ extensions: { pgcrypto } });
await db.exec(fixture);
await db.exec(baseline);
await db.exec(authorization);
const originalCatalog = await catalog();
await db.exec(candidate);

async function catalog() {
  return (await db.query(`SELECT to_jsonb(p) AS routine FROM pg_proc p
    WHERE p.pronamespace='public'::regnamespace
    AND p.proname IN ('register_evidence','verify_evidence_hash','evidence_for_repair_job') ORDER BY p.oid`)).rows;
}
async function seed(kind = 'photo_before') {
  const n = ++sequence;
  const job = `30000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
  const path = `${ACTOR}/${job}/photo.jpg`;
  await db.query(`INSERT INTO public.repair_jobs(id,hospital_user_id,engineer_id,before_photos,after_photos)
    VALUES($1::uuid,$2::uuid,'20000000-0000-0000-0000-000000000001',ARRAY['existing-before'],ARRAY['existing-after'])`, [job, uid(1)]);
  await db.query(`INSERT INTO storage.objects(bucket_id,name,owner,owner_id,metadata)
    VALUES('repair-photos',$1,$2::uuid,$2,'{"size":3,"mimetype":"image/jpeg"}')`, [path, ACTOR]);
  return { job, fixtureJob: job, kind, path, url: `repair-photos/${path}`, hash: digest(job), size: 3,
    captured: '2026-09-09T06:00:00Z', platform: 'android/test', metadata: { fixture: n, hash_verification: 'forged' } };
}
async function invoke(r, actor = ACTOR, role = 'authenticated', claimRole = role) {
  assert(['authenticated', 'anon', 'service_role', 'public_only'].includes(role));
  return db.transaction(async (tx) => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    await tx.query("SELECT set_config('request.jwt.claim.sub',$1,true),set_config('request.jwt.claim.role',$2,true)", [actor ?? '', claimRole ?? '']);
    const result = await tx.query(`SELECT * FROM public.finalize_repair_photo(
      $1::uuid,$2,$3,$4,$5::bigint,$6::timestamptz,$7,$8::jsonb)`,
    [r.job,r.kind,r.url,r.hash,r.size,r.captured,r.platform,JSON.stringify(r.metadata)]);
    assert.equal(result.rows.length, 1);
    assert.match(result.rows[0].ledger_id, /^[0-9a-f-]{36}$/);
    assert.equal(result.rows[0].attachment_path, r.url.slice('repair-photos/'.length));
    return result.rows[0].ledger_id;
  });
}
async function state(r) {
  return (await db.query(`SELECT
    (SELECT to_jsonb(j) FROM public.repair_jobs j WHERE id=$1::uuid) AS job,
    (SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY id),'[]') FROM public.evidence_ledger e WHERE source_id=$1::uuid) AS ledger,
    (SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY id),'[]') FROM storage.objects o WHERE name LIKE $2) AS objects`,
  [r.fixtureJob ?? r.job, `${ACTOR}/${r.fixtureJob ?? r.job}/%`])).rows[0];
}
async function denied(r, code = '42501', actor = ACTOR, role = 'authenticated', claimRole = role) {
  const before = await state(r);
  await assert.rejects(() => invoke(r, actor, role, claimRole), (error) => error.code === code);
  assert.deepEqual(await state(r), before, 'failure preserves full job, objects and ledger');
}

try {
  await test('actual migration reapplies without changing existing RPCs or the new contract', async () => {
    assert.deepEqual(await catalog(), originalCatalog);
    const before = (await db.query('SELECT to_jsonb(p) AS routine FROM pg_proc p WHERE oid=$1::regprocedure', [signature])).rows;
    await db.exec(candidate);
    assert.deepEqual((await db.query('SELECT to_jsonb(p) AS routine FROM pg_proc p WHERE oid=$1::regprocedure', [signature])).rows, before);
    assert.deepEqual(await catalog(), originalCatalog);
  });
  await test('new RPC has explicit safe authenticated-only definer contract', async () => {
    await db.exec('CREATE ROLE public_only; GRANT USAGE ON SCHEMA public TO public_only;');
    const p = (await db.query(`SELECT p.prosecdef,p.provolatile,p.proconfig,pg_get_function_result(p.oid) AS result,
      p.proargtypes::text AS arguments,p.proowner=current_user::regrole::oid AS owned,
      has_function_privilege('authenticated',p.oid,'execute') AS authenticated,
      has_function_privilege('anon',p.oid,'execute') AS anon,
      has_function_privilege('service_role',p.oid,'execute') AS service,
      has_function_privilege('public_only',p.oid,'execute') AS public
      FROM pg_proc p WHERE oid=$1::regprocedure`, [signature])).rows[0];
    assert.deepEqual(p, { prosecdef: true, provolatile: 'v', proconfig: ['search_path=public, pg_temp'], result: 'TABLE(ledger_id uuid, attachment_path text)',
      arguments: '2950 25 25 25 20 1184 25 3802', owned: true, authenticated: true, anon: false, service: false, public: false });
  });
  for (const kind of ['photo_before','photo_after']) await test(`${kind} appends only matching array and registers owned provenance`, async () => {
    const r = await seed(kind), before = await state(r), id = await invoke(r), after = await state(r);
    const column = kind === 'photo_before' ? 'before_photos' : 'after_photos';
    assert.deepEqual(after.job, { ...before.job, [column]: [...before.job[column], r.path] });
    assert.deepEqual(after.objects, before.objects);
    assert.equal(after.ledger.length, 1);
    const row = after.ledger[0];
    assert.equal(row.id, id);
    assert.equal(row.evidence_kind, kind);
    assert.equal(row.source_kind, 'repair_job');
    assert.equal(row.producer_user_id, ACTOR);
    assert.equal(row.producer_kind, 'engineer');
    assert.equal(row.content_sha256, r.hash);
    assert.equal(row.content_size_bytes, 3);
    assert.equal(row.storage_url, r.url);
    assert.equal(row.metadata.hash_verification, 'client_asserted');
    assert.equal(row.metadata.registration_authority, 'assigned_engineer');
    assert.equal(row.metadata.storage_object_id, after.objects[0].id);
    assert.equal(new Date(row.captured_at).toISOString(), '2026-09-09T06:00:00.000Z');
    assert(Number.isFinite(Date.parse(row.created_at)));
    assert.equal(await invoke({ ...r, captured: '2026-09-10T00:00:00Z', metadata: { replacement: true } }), id);
    assert.deepEqual(await state(r), after, 'retry preserves every original ledger/job/object column');
  });
  await test('null array initializes and authorized retry restores removed attachment', async () => {
    const r = await seed();
    await db.query('UPDATE public.repair_jobs SET before_photos=NULL WHERE id=$1', [r.job]);
    const id = await invoke(r), saved = await state(r);
    assert.deepEqual(saved.job.before_photos, [r.path]);
    await db.query("UPDATE public.repair_jobs SET before_photos='{}' WHERE id=$1", [r.job]);
    assert.equal(await invoke(r), id);
    assert.deepEqual(await state(r), saved);
  });
  for (const kind of ['photo_before','photo_after']) for (const value of [null, []]) {
    await test(`${kind} ${value === null ? 'null' : 'empty'} array initializes then retries once`, async () => {
      const r = await seed(kind), column = kind === 'photo_before' ? 'before_photos' : 'after_photos';
      await db.query(`UPDATE public.repair_jobs SET ${column}=$1::text[] WHERE id=$2`, [value,r.job]);
      const id = await invoke(r), saved = await state(r);
      assert.deepEqual(saved.job[column], [r.path]);
      assert.equal(await invoke(r), id);
      assert.deepEqual(await state(r), saved);
    });
  }
  await test('committed response discarded by caller is recovered from the immutable server row', async () => {
    const r = await seed();
    await invoke(r); // Deliberately do not retain the committed response.
    const committed = await state(r);
    assert.equal(await invoke(r), committed.ledger[0].id);
    assert.deepEqual(await state(r), committed);
  });
  for (const status of ['assigned','in_progress','completed','disputed']) await test(`legitimate delayed ${status} photo needs no accepted bid`, async () => {
    const r = await seed();
    await db.query('UPDATE public.repair_jobs SET status=$1 WHERE id=$2', [status,r.job]);
    assert(await invoke(r));
  });
  for (const [label,actor,role,claim] of [
    ['hospital',uid(1),'authenticated','authenticated'], ['outsider',uid(2),'authenticated','authenticated'],
    ['other engineer',OTHER,'authenticated','authenticated'], ['founder',uid(5),'authenticated','authenticated'],
    ['null uid',null,'authenticated','authenticated'], ['null role',ACTOR,'authenticated',null],
    ['spoofed service claim',ACTOR,'authenticated','service_role'], ['anon',ACTOR,'anon','authenticated'],
    ['service',ACTOR,'service_role','authenticated'], ['public',ACTOR,'public_only','authenticated']
  ]) await test(`${label} denied without attachment or evidence`, async () => denied(await seed(), '42501', actor, role, claim));
  for (const [label,patch,code] of [
    ['unknown kind',{kind:'signature_engineer'},'42501'], ['null kind',{kind:null},'42501'],
    ['null hash',{hash:null},'22023'], ['upper hash',{hash:'A'.repeat(64)},'22023'],
    ['bad hash',{hash:'not-a-digest'},'22023'], ['zero size',{size:0},'22023'],
    ['null size',{size:null},'22023'], ['wrong size',{size:4},'22023'],
    ['null job',{job:null},'02000'], ['missing job',{job:'30000000-0000-0000-0000-999999999999'},'02000'],
    ['null URL',{url:null},'42501'], ['URL',{url:'https://invalid.test/photo.jpg'},'42501']
  ]) await test(`${label} receipt rejected atomically`, async () => denied({ ...await seed(), ...patch }, code));
  await test('invalid UUID identity claim denied without mutation', async () => denied(await seed(), '22P02', 'invalid-uuid'));
  for (const prefix of ['wrong-user','wrong-job','wrong-bucket']) await test(`${prefix} canonical path rejected`, async () => {
    const r = await seed();
    const url = prefix === 'wrong-user' ? `repair-photos/${OTHER}/${r.job}/photo.jpg`
      : prefix === 'wrong-job' ? `repair-photos/${ACTOR}/30000000-0000-0000-0000-000000000001/photo.jpg`
      : `kyc-docs/${ACTOR}/${r.job}/photo.jpg`;
    await denied({ ...r, url });
  });
  for (const suffix of ['../photo.jpg','photo.jpg?x=1','photo.jpg#x','nested/photo.jpg','photo name.jpg','photo\\name.jpg','.','..','']) {
    await test(`noncanonical path ${JSON.stringify(suffix)} denied`, async () => {
      const r = await seed();
      await denied({ ...r, url: `repair-photos/${ACTOR}/${r.job}/${suffix}` });
    });
  }
  for (const [label,mutation,code] of [
    ['cleared assignment', r => db.query('UPDATE public.repair_jobs SET engineer_id=NULL WHERE id=$1', [r.job]),'42501'],
    ['reassigned job', r => db.query("UPDATE public.repair_jobs SET engineer_id='20000000-0000-0000-0000-000000000002' WHERE id=$1", [r.job]),'42501'],
    ['object ownership transfer', r => db.query('UPDATE storage.objects SET owner_id=$1 WHERE name=$2', [OTHER,r.path]),'42501'],
    ['null owner', r => db.query('UPDATE storage.objects SET owner_id=NULL,owner=NULL WHERE name=$1', [r.path]),'42501'],
    ['missing object', r => db.query('DELETE FROM storage.objects WHERE name=$1', [r.path]),'02000'],
    ['missing size', r => db.query("UPDATE storage.objects SET metadata='{}' WHERE name=$1", [r.path]),'22023'],
    ['malformed size', r => db.query(`UPDATE storage.objects SET metadata='{"size":"oops"}' WHERE name=$1`, [r.path]),'22023']
  ]) await test(`${label} denies an existing-ID retry before disclosure`, async () => {
    const r = await seed(); await invoke(r); await mutation(r); await denied(r,code);
  });
  for (const value of [null,OTHER]) await test(`engineer mapping ${value === null ? 'clear' : 'rebind'} denies canonical authority`, async () => {
    const r = await seed(); await invoke(r);
    await db.query("UPDATE public.engineers SET user_id=$1 WHERE id='20000000-0000-0000-0000-000000000001'", [value]);
    try { await denied(r); }
    finally { await db.query("UPDATE public.engineers SET user_id=$1 WHERE id='20000000-0000-0000-0000-000000000001'", [ACTOR]); }
  });
  await test('legacy owner fallback works but current owner_id takes precedence', async () => {
    const r = await seed();
    await db.query('UPDATE storage.objects SET owner_id=NULL WHERE name=$1', [r.path]);
    assert(await invoke(r));
    await db.query('UPDATE storage.objects SET owner_id=$1 WHERE name=$2', [OTHER,r.path]);
    await denied(r);
  });
  for (const size of [-3, 3.5, '3.0', null]) await test(`invalid object size ${JSON.stringify(size)} rejected`, async () => {
    const r = await seed();
    await db.query('UPDATE storage.objects SET metadata=$1::jsonb WHERE name=$2', [JSON.stringify({ size }),r.path]);
    await denied(r,'22023');
  });
  await test('authorized different-object digest collision rolls back its new append', async () => {
    const r = await seed(); await invoke(r);
    const path = `${ACTOR}/${r.job}/different.jpg`;
    await db.query(`INSERT INTO storage.objects(bucket_id,name,owner_id,metadata) VALUES('repair-photos',$1,$2,'{"size":3}')`, [path,ACTOR]);
    await denied({ ...r, url: `repair-photos/${path}` });
  });
  await test('downstream metadata rejection rolls back append', async () => {
    await denied({ ...await seed(), metadata: ['not-an-object'] }, '22023');
  });
  for (const producer of [OTHER, null]) await test(`${producer === null ? 'orphan' : 'foreign'} producer collision rolls back new append`, async () => {
    const r = await seed();
    await db.query(`INSERT INTO public.evidence_ledger(evidence_kind,source_kind,source_id,content_sha256,
      content_size_bytes,storage_url,producer_user_id,producer_kind)
      VALUES($1,'repair_job',$2,$3,3,$4,$5,'engineer')`, [r.kind,r.job,r.hash,r.url,producer]);
    await denied(r);
  });
  await test('injected ledger failure after observing append rolls back all effects', async () => {
    const r = await seed();
    await db.exec(`CREATE FUNCTION public.fixture_reject_registered_photo() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NOT EXISTS(SELECT 1 FROM public.repair_jobs WHERE id=NEW.source_id
          AND before_photos @> ARRAY[substr(NEW.storage_url,length('repair-photos/')+1)]) THEN
          RAISE EXCEPTION 'fixture_append_not_seen' USING ERRCODE='P0004';
        END IF;
        RAISE EXCEPTION 'fixture_after_append_failure' USING ERRCODE='P0001';
      END; $$;
      CREATE TRIGGER fixture_reject BEFORE INSERT ON public.evidence_ledger FOR EACH ROW EXECUTE FUNCTION public.fixture_reject_registered_photo();`);
    try { await denied(r,'P0001'); }
    finally { await db.exec('DROP TRIGGER fixture_reject ON public.evidence_ledger; DROP FUNCTION public.fixture_reject_registered_photo();'); }
  });
  await test('original writer metadata and ACLs are unchanged after every finalizer call', async () => assert.deepEqual(await catalog(), originalCatalog));
  await test('actual reapply preserves complete populated successful and failed fixture state', async () => {
    const query = `SELECT (SELECT jsonb_agg(to_jsonb(j) ORDER BY id) FROM public.repair_jobs j) jobs,
      (SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM public.evidence_ledger e) ledger,
      (SELECT jsonb_agg(to_jsonb(o) ORDER BY id) FROM storage.objects o) objects`;
    const before = (await db.query(query)).rows;
    await db.exec(candidate);
    assert.deepEqual((await db.query(query)).rows,before);
    assert.deepEqual(await catalog(), originalCatalog);
  });
  const dependency = 'public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb)';
  for (const [label,sql] of [
    ['dependency owner',`ALTER FUNCTION ${dependency} OWNER TO public_only`],
    ['dependency invoker',`ALTER FUNCTION ${dependency} SECURITY INVOKER`],
    ['dependency volatility',`ALTER FUNCTION ${dependency} STABLE`],
    ['dependency search path',`ALTER FUNCTION ${dependency} SET search_path=public`],
    ['dependency PUBLIC',`GRANT EXECUTE ON FUNCTION ${dependency} TO PUBLIC`],
    ['dependency anon',`GRANT EXECUTE ON FUNCTION ${dependency} TO anon`],
    ['dependency extra role',`GRANT EXECUTE ON FUNCTION ${dependency} TO public_only`],
    ['dependency missing client grant',`REVOKE EXECUTE ON FUNCTION ${dependency} FROM authenticated`],
    ['dependency missing service grant',`REVOKE EXECUTE ON FUNCTION ${dependency} FROM service_role`],
    ['dependency grant option',`GRANT EXECUTE ON FUNCTION ${dependency} TO authenticated WITH GRANT OPTION`],
    ['dependency missing signature',`ALTER FUNCTION ${dependency} RENAME TO fixture_renamed_writer`],
    ['helper owner',`ALTER FUNCTION ${signature} OWNER TO public_only`],
    ['helper extra role',`GRANT EXECUTE ON FUNCTION ${signature} TO public_only`],
    ['helper grant option',`GRANT EXECUTE ON FUNCTION ${signature} TO authenticated WITH GRANT OPTION`],
    ['helper PUBLIC',`GRANT EXECUTE ON FUNCTION ${signature} TO PUBLIC`],
    ['helper service',`GRANT EXECUTE ON FUNCTION ${signature} TO service_role`]
  ]) await test(`reapply refuses ${label} drift atomically`, async () => {
    const query = "SELECT to_jsonb(p) routine FROM pg_proc p WHERE pronamespace='public'::regnamespace ORDER BY oid";
    await db.exec('BEGIN');
    try {
      await db.exec(sql);
      const drifted = (await db.query(query)).rows;
      await db.exec('SAVEPOINT candidate_attempt');
      await assert.rejects(() => db.exec(candidate), e => e.code === '55000');
      await db.exec('ROLLBACK TO SAVEPOINT candidate_attempt');
      assert.deepEqual((await db.query(query)).rows, drifted, 'failed install does not repair/replace unknown routines');
    } finally { await db.exec('ROLLBACK'); }
    assert.deepEqual(await catalog(), originalCatalog);
  });
} finally {
  await db.close();
}

await test('actual migration refuses the historical unguarded registration dependency atomically', async () => {
  const old = new PGlite({ extensions: { pgcrypto } });
  try {
    await old.exec(fixture); await old.exec(baseline);
    const before = (await old.query("SELECT to_jsonb(p) AS p FROM pg_proc p WHERE oid='public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb)'::regprocedure")).rows;
    await assert.rejects(() => old.exec(candidate), e => e.code === '55000');
    await old.exec('ROLLBACK');
    assert.equal((await old.query('SELECT to_regprocedure($1) AS rpc', [signature])).rows[0].rpc, null);
    assert.deepEqual((await old.query("SELECT to_jsonb(p) AS p FROM pg_proc p WHERE oid='public.register_evidence(text,text,uuid,text,bigint,text,text,timestamptz,text,jsonb)'::regprocedure")).rows, before);
  } finally { await old.close(); }
});
