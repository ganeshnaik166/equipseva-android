// Round 3828 — service-only money RPCs executable by anon and authenticated.
//
// Proves supabase/migrations/20263905000000_round3828_service_only_money_rpc_grants.sql
// in two disposable PGlite databases:
//
//   LEGACY — fixtures reproducing the project's default privileges, then the
//            REAL round471 webhook migration (record_razorpay_payment_captured,
//            record_razorpay_refund) and signature-exact stand-ins for the
//            other seven functions with their original grant statements:
//            the production grant state.
//   NEW    — LEGACY plus round3828, applied twice.
//
// CONTROL properties must pass on NEW and fail on LEGACY (on LEGACY the forged
// calls succeed and change money state). REGRESSION properties (the
// legitimate service-role and owner-run paths) must pass on both.
//
// Run: EQS_PGLITE_PACKAGE=<extracted @electric-sql/pglite@0.5.8/package> \
//        node supabase/tests/service_only_money_rpc_grants.test.mjs

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
const fixture = await read(path.join(here, 'service_only_money_rpc_grants.fixture.sql'));
const round471 = await read(path.join(migrations, '20260723000000_round471_razorpay_webhook_events.sql'));
const newSql = await read(path.join(migrations, '20263905000000_round3828_service_only_money_rpc_grants.sql'));

const USER = '10000000-0000-0000-0000-000000000009';
const NINE = [
  'public.record_razorpay_payment_captured(text,text,text,text,bigint,text,jsonb)',
  'public.record_razorpay_refund(text,text,text,text,text,bigint,jsonb)',
  'public.apply_amc_pool_credit(uuid)',
  'public.record_payment_verify_event(text,text,text,uuid,text,text,boolean,boolean,bigint,text,text,uuid,jsonb)',
  'public.pick_engineer_payouts_for_processing(integer)',
  'public.record_engineer_payout_dispatch(uuid,text,text,text,text,text,text)',
  'public.record_engineer_payout_webhook(text,text,text,text,text,text)',
  'public.requeue_stuck_engineer_payouts(interval,integer)',
  'public.process_due_repair_job_escrow_releases()',
];
const STAND_IN_CALLS = [
  "SELECT public.apply_amc_pool_credit('00000000-0000-0000-0000-000000000001'::uuid)",
  "SELECT public.record_payment_verify_event('a','b','c',NULL,'e','f',true,true,1,'j','k',NULL,NULL)",
  'SELECT * FROM public.pick_engineer_payouts_for_processing(100)',
  "SELECT public.record_engineer_payout_dispatch('00000000-0000-0000-0000-000000000002'::uuid,'failed','x','y','z','w','v')",
  "SELECT public.record_engineer_payout_webhook('a','b','c','d','e','f')",
  "SELECT public.requeue_stuck_engineer_payouts(interval '1 second', 99)",
  'SELECT public.process_due_repair_job_escrow_releases()',
];

const seedSql = `
INSERT INTO public.repair_job_escrow(razorpay_order_id, razorpay_payment_id, status) VALUES
  ('order_ESC1', NULL, 'pending'),
  ('order_ESC2', 'pay_real_2', 'held'),
  ('order_ESC3', NULL, 'pending');
INSERT INTO public.amc_payment_orders(razorpay_order_id, status) VALUES ('order_AMC1', 'pending');
`;

async function as(db, role, sql, params = []) {
  return db.transaction(async (tx) => {
    await tx.exec(`SET LOCAL ROLE ${role}`);
    await tx.query("SELECT set_config('request.jwt.claim.sub',$1,true)", [role === 'authenticated' ? USER : '']);
    return tx.query(sql, params);
  });
}
async function denied(action) {
  await assert.rejects(action, (e) => { assert.equal(e.code, '42501', `expected 42501, got ${e.code}: ${e.message}`); return true; });
}
const escrow = async (db, order) => (await db.query('SELECT status FROM public.repair_job_escrow WHERE razorpay_order_id = $1', [order])).rows[0].status;

const CAPTURE = "SELECT public.record_razorpay_payment_captured($1, 'payment.captured', $2, 'pay_forged', 100, 'INR', NULL) AS r";
const REFUND = "SELECT public.record_razorpay_refund($1, 'refund.processed', 'rfnd_forged', $2, $3, 100, NULL) AS r";

const PROPERTIES = [
  { kind: 'control', name: 'anon cannot forge a captured payment: the escrow stays pending', run: async (db) => {
    await denied(() => as(db, 'anon', CAPTURE, ['evt_forged_1', 'order_ESC1']));
    assert.equal(await escrow(db, 'order_ESC1'), 'pending');
  } },
  { kind: 'control', name: 'a signed-in user cannot forge a paid AMC order', run: async (db) => {
    await denied(() => as(db, 'authenticated', CAPTURE, ['evt_forged_2', 'order_AMC1']));
    assert.equal((await db.query("SELECT status FROM public.amc_payment_orders WHERE razorpay_order_id = 'order_AMC1'")).rows[0].status, 'pending');
  } },
  { kind: 'control', name: 'anon cannot forge a refund: the held escrow stays held', run: async (db) => {
    await denied(() => as(db, 'anon', REFUND, ['evt_forged_3', 'pay_real_2', 'order_ESC2']));
    assert.equal(await escrow(db, 'order_ESC2'), 'held');
  } },
  { kind: 'control', name: 'clients cannot invoke the AMC-credit, verify-telemetry, payout-worker, reaper or escrow-release functions', run: async (db) => {
    for (const role of ['anon', 'authenticated']) {
      for (const call of STAND_IN_CALLS) await denied(() => as(db, role, call));
    }
    const leaked = (await db.query("SELECT count(*)::int AS n FROM public.service_rpc_canary WHERE called_by IN ('anon','authenticated')")).rows[0].n;
    assert.equal(leaked, 0);
  } },
  { kind: 'control', name: 'catalog: none of the nine is executable by anon or authenticated; service_role keeps EXECUTE', run: async (db) => {
    for (const sig of NINE) {
      const q = async (role) => (await db.query("SELECT has_function_privilege($1, $2, 'EXECUTE') AS ok", [role, sig])).rows[0].ok;
      assert.equal(await q('anon'), false, `anon can execute ${sig}`);
      assert.equal(await q('authenticated'), false, `authenticated can execute ${sig}`);
      assert.equal(await q('service_role'), true, `service_role lost ${sig}`);
    }
  } },

  { kind: 'regression', name: 'the service-role webhook still records a real captured payment', run: async (db) => {
    // Distinct event id per database run so the idempotency log never short-circuits.
    const evt = `evt_real_${(await db.query('SELECT gen_random_uuid()::text AS u')).rows[0].u}`;
    const r = (await as(db, 'service_role', CAPTURE, [evt, 'order_ESC3'])).rows[0].r;
    assert.equal(r.ok, true);
    assert.equal(r.matched_table, 'repair_job_escrow');
    assert.equal(r.apply_outcome, 'escrow_flipped_to_held');
    assert.equal(await escrow(db, 'order_ESC3'), 'held');
    await db.query("UPDATE public.repair_job_escrow SET status = 'pending', razorpay_payment_id = NULL, paid_at = NULL WHERE razorpay_order_id = 'order_ESC3'");
  } },
  { kind: 'regression', name: 'service_role can still call every worker and credit function', run: async (db) => {
    for (const call of STAND_IN_CALLS) await as(db, 'service_role', call);
  } },
  { kind: 'regression', name: 'owner-run internal callers (SECURITY DEFINER) still reach apply_amc_pool_credit', run: async (db) => {
    await as(db, 'authenticated', "SELECT public.internal_definer_caller('00000000-0000-0000-0000-000000000003'::uuid)");
  } },

  { kind: 'new-only', name: "the migration's self-check aborts if a client grant reappears", run: async (db) => {
    const selfCheck = newSql.slice(newSql.indexOf('DO $$'), newSql.lastIndexOf('END $$;') + 'END $$;'.length);
    assert(selfCheck.startsWith('DO $$'), 'self-check block not found');
    await db.exec('GRANT EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) TO anon');
    try {
      await assert.rejects(() => db.exec(selfCheck), (e) => { assert.equal(e.code, '42501'); assert.match(e.message, /apply_amc_pool_credit/); return true; });
    } finally {
      await db.exec('REVOKE EXECUTE ON FUNCTION public.apply_amc_pool_credit(uuid) FROM anon');
    }
    await db.exec(selfCheck); // clean state passes
  } },
];

async function build(withNew) {
  const db = await PGlite.create();
  await db.exec(baseFixture);
  await db.exec(fixture);
  await db.exec(round471);
  if (withNew) { await db.exec(newSql); await db.exec(newSql); }
  await db.exec(seedSql);
  return db;
}

const legacy = await build(false);
const fresh = await build(true);
const problems = [];
let newPass = 0, controlsFailed = 0, legacyRegressions = 0;
for (const p of PROPERTIES) {
  try { await p.run(fresh); newPass++; console.log(`PASS  new     ${p.kind.padEnd(10)} ${p.name}`); }
  catch (e) { problems.push(`NEW must pass: ${p.name}: ${e.message}`); console.log(`FAIL  new     ${p.kind.padEnd(10)} ${p.name}: ${e.message}`); }
  if (p.kind === 'new-only') continue;
  try {
    await p.run(legacy);
    if (p.kind === 'control') { problems.push(`NEGATIVE CONTROL passed on LEGACY: ${p.name}`); console.log(`UNEXPECTED legacy pass: ${p.name}`); }
    else { legacyRegressions++; console.log(`PASS  legacy  ${p.kind.padEnd(10)} ${p.name}`); }
  } catch (e) {
    if (p.kind === 'control') { controlsFailed++; console.log(`FAIL  legacy  control    ${p.name} (expected: ${e.message.split('\n')[0]})`); }
    else { problems.push(`REGRESSION broken on LEGACY: ${p.name}: ${e.message}`); console.log(`FAIL  legacy  regression ${p.name}: ${e.message}`); }
  }
}
// Show the forged state LEGACY accepted, so the report states what an attacker achieved.
const forged = (await legacy.query("SELECT razorpay_order_id, status FROM public.repair_job_escrow ORDER BY razorpay_order_id")).rows;
const count = (k) => PROPERTIES.filter((p) => p.kind === k).length;
console.log('\n==== summary ====');
console.log(`new:                 ${newPass}/${PROPERTIES.length} properties pass`);
console.log(`negative controls:   ${controlsFailed}/${count('control')} fail on the legacy grants (expected all)`);
console.log(`legacy regressions:  ${legacyRegressions}/${count('regression')} legitimate paths pass on legacy too (expected all)`);
console.log(`legacy escrow state after the forged anon calls: ${forged.map((r) => `${r.razorpay_order_id}=${r.status}`).join(', ')}`);
if (problems.length) { console.log('\nPROBLEMS:\n- ' + problems.join('\n- ')); process.exitCode = 1; }
else console.log('\nALL EXPECTATIONS MET');
