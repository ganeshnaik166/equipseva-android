import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import { runSlotsAndRecord, stableErrorCode } from '../functions/cron-tick/observability.ts';

// Run with Node 24: node --experimental-vm-modules --test cron_observability.test.mjs
// The VM executes the actual Edge entrypoint and helper with only external
// serve/Supabase/fetch/Deno/console dependencies stubbed. No network is used.
const entrySource = await readFile(new URL('../functions/cron-tick/index.ts',import.meta.url),'utf8');
const helperSource = await readFile(new URL('../functions/cron-tick/observability.ts',import.meta.url),'utf8');
const PRIVATE = 'synthetic-sensitive-detail-do-not-log';
const validEnvironment = {
  SUPABASE_URL: 'https://unit-test.invalid',
  SUPABASE_SERVICE_ROLE_KEY: 'synthetic-service-key',
  CRON_TICK_SECRET: 'synthetic-cron-key',
};
const expectedDailyTargets = [
  'purge-notifications','purge-content-reports','purge-device-integrity',
  'purge-virtual-calls','purge-phone-otp-requests','amc-auto-renew',
  'amc-renewal-notify','expire-amc-contracts','purge-spot-audit-invitations',
  'purge-chat-moderation-events','reap-stranded-repair-jobs','daily-reconciliation',
  'schedule-kyc-renewals','reap-expired-kyc-renewals','daily-risk-scoring',
  'scan-collusion-pairs','scan-duplicate-accounts','refresh-tier-cache',
  'recompute-pm-schedules','recompute-certifications','evaluate-referrals',
  'purge-analytics-events','purge-investor-share-views','purge-nabh-export-audit',
  'db-storage-snapshot','invoice-digest',
];
const expectedDailyCalls = [
  'purge_old_notifications','purge_old_content_reports','purge_old_device_integrity_checks',
  'purge_old_virtual_call_sessions','purge_old_phone_otp_requests','auto_renew_expiring_amc_contracts',
  'notify_expiring_amc_contracts','expire_lapsed_amc_contracts','purge_old_spot_audit_invitations',
  'purge_old_chat_moderation_events','reap_stranded_requested_repair_jobs','run_daily_reconciliation',
  'schedule_engineer_kyc_renewals','reap_expired_kyc_renewals','run_daily_risk_scoring',
  'scan_collusion_pairs','scan_duplicate_accounts','refresh_all_engineer_tier_cache',
  'recompute_all_pm_schedules','recompute_all_engineer_certifications','evaluate_all_pending_referrals',
  'analytics_events_retention_sweep','investor_share_view_log_retention_sweep',
  'nabh_export_audit_retention_sweep','db_storage_snapshot_sweep','invoice-digest',
];
const expectedHourlyTargets = [
  'escrow-release','expire-cost-revisions','amc-create-visits','payouts-reaper',
  'amc-sla-sweep','reap-refund-authorizations','reap-stranded-amc-orders','sweep-code-reds',
];
const expectedHourlyCalls = [
  'process_due_repair_job_escrow_releases','expire_stale_cost_revisions',
  'auto_create_due_amc_visits','requeue_stuck_engineer_payouts','sweep_amc_sla_unresponded_visits',
  'reap_expired_refund_authorizations','reap_stranded_pending_payment_amc_contracts','sweep_timed_out_code_reds',
];
const plain = (value) => JSON.parse(JSON.stringify(value));

async function edge(options = {}) {
  const calls = [], records = [], logs = [], fetchResponses = [], fetchRequests = [], clientArguments = [];
  let handler, clients = 0, active = 0, maximumActive = 0;
  const env = { ...validEnvironment, ...options.env };
  const context = vm.createContext({
    URL, Response,
    Deno: { env: { get: (key) => env[key] } },
    console: { error: (...args) => logs.push(plain(args)) },
    fetch: async (url,init) => {
      calls.push('invoice-digest');
      fetchRequests.push({url:String(url),init:plain(init)});
      const response = new Response(PRIVATE,{status:options.fetchStatus ?? 200});
      fetchResponses.push(response);
      return response;
    },
  });
  const server = new vm.SyntheticModule(['serve'],function() {
    this.setExport('serve',(callback)=>{handler=callback;});
  },{context});
  const sdk = new vm.SyntheticModule(['createClient'],function() {
    this.setExport('createClient',(...args)=>{
      clients++;
      clientArguments.push(args);
      return {
        rpc: async (name,args) => {
          calls.push(name);
          active++;
          maximumActive=Math.max(maximumActive,active);
          try {
            await Promise.resolve();
            return options.rpc ? await options.rpc(name,args) : {data:2,error:null};
          } finally { active--; }
        },
        from: (table) => {
          assert.equal(table,'cron_tick_runs');
          return { insert: async (record) => {
            records.push(plain(record));
            return options.persist ? await options.persist(record) : {error:null};
          }};
        },
      };
    });
  },{context});
  const helper = new vm.SourceTextModule(stripTypeScriptTypes(helperSource),{context,identifier:'observability.ts'});
  const entry = new vm.SourceTextModule(stripTypeScriptTypes(entrySource),{context,identifier:'index.ts'});
  await entry.link((specifier)=>{
    if (specifier==='https://deno.land/std@0.224.0/http/server.ts') return server;
    if (specifier==='https://esm.sh/@supabase/supabase-js@2.45.4') return sdk;
    if (specifier==='./observability.ts') return helper;
    throw new Error(`Unexpected dependency: ${specifier}`);
  });
  await entry.evaluate();
  assert.equal(typeof handler,'function');
  return {
    calls, records, logs, fetchResponses, fetchRequests, clientArguments,
    get clients(){return clients;},
    get maximumActive(){return maximumActive;},
    request: async ({method='POST',slot='daily',secret=validEnvironment.CRON_TICK_SECRET,omitSlot=false}={}) => {
      const headers = secret===null ? {} : {'x-cron-secret':secret};
      const query = omitSlot ? '' : `?slot=${encodeURIComponent(slot)}`;
      const response = await handler(new Request(`https://unit-test.invalid/cron-tick${query}`,{method,headers}));
      return {status:response.status, body:await response.json()};
    },
  };
}

for (const code of ['57014','55P03','23502','42501','PGRST002','PGRST116','H401','H500']) {
  test(`retains stable code ${code}`,()=>assert.equal(stableErrorCode({code,message:PRIVATE}),code));
}
for (const code of ['57014\n','PGRST002\r\n','H500\n',' H401','H500 ',
  '57014 '+PRIVATE,'https://unit-test.invalid','pgrst002','H600','H000','PGRST02',
  '<script>','57014\u2028','57014\0',null,57014]) {
  test(`rejects noncanonical code ${JSON.stringify(code)}`,()=>assert.equal(stableErrorCode({code}),undefined));
}
test('malformed errors and throwing code getters are safely omitted',()=>{
  for (const error of [null,undefined,PRIVATE,new Error(PRIVATE),{get code(){throw new Error(PRIVATE);}}]) {
    assert.equal(stableErrorCode(error),undefined);
  }
});

test('mixed jobs preserve order, counts, durations and original error while returned ledger error is separate',async()=>{
  const calls=[],logs=[],records=[];
  let tick=100;
  const outcome=await runSlotsAndRecord({
    slot:'daily',targets:['first','broken','last'],invokedAt:90,now:()=>tick++,
    slots:{
      first:async()=>{calls.push('first');return {rows:3};},
      broken:async()=>{calls.push('broken');throw {code:'57014',message:PRIVATE,details:PRIVATE};},
      last:async()=>{calls.push('last');return {rows:7};},
    },
    persist:async(record)=>{records.push(record);return {error:{code:'PGRST002',message:PRIVATE}};},
    log:(entry)=>logs.push(entry),
  });
  assert.deepEqual(calls,['first','broken','last']);
  assert.equal(records.length,1);
  assert.equal(outcome.ok,false);
  assert.deepEqual(outcome.results,[
    {slot:'first',ok:true,rows:3,duration_ms:1},
    {slot:'broken',ok:false,error:'slot_failed',error_code:'57014',duration_ms:1},
    {slot:'last',ok:true,rows:7,duration_ms:1},
  ]);
  assert.deepEqual(records[0].failed_slots,['broken']);
  assert.equal(records[0].duration_ms,16);
  assert.deepEqual(outcome.persistence,{ok:false,error:'run_persistence_failed',error_code:'PGRST002'});
  assert.equal(JSON.stringify({outcome,records,logs}).includes(PRIVATE),false);
});

test('thrown persistence and logger errors cannot alter successful jobs or provoke retries',async()=>{
  let jobs=0,inserts=0;
  const outcome=await runSlotsAndRecord({
    slot:'single',targets:['single'],invokedAt:0,
    slots:{single:async()=>{jobs++;return {}; }},
    persist:async()=>{inserts++;throw {code:'H401\n'+PRIVATE,message:PRIVATE};},
    log:()=>{throw new Error(PRIVATE);},
  });
  assert.equal(jobs,1);assert.equal(inserts,1);
  assert.equal(outcome.ok,true);assert.equal(outcome.results[0].ok,true);
  assert.deepEqual(plain(outcome.persistence),{ok:false,error:'run_persistence_failed'});
  assert.equal(JSON.stringify(outcome).includes(PRIVATE),false);
});

for (const scenario of [
  {name:'GET',request:{method:'GET'},status:405},
  {name:'PUT',request:{method:'PUT'},status:405},
  {name:'missing URL',env:{SUPABASE_URL:undefined},status:500},
  {name:'missing service key',env:{SUPABASE_SERVICE_ROLE_KEY:undefined},status:500},
  {name:'missing configured cron secret',env:{CRON_TICK_SECRET:undefined},status:500},
  {name:'empty configured cron secret',env:{CRON_TICK_SECRET:''},status:500},
  {name:'missing request secret',request:{secret:null},status:401},
  {name:'wrong-length secret',request:{secret:'wrong'},status:401},
  {name:'same-length wrong secret',request:{secret:'synthetic-cron-keX'},status:401},
]) {
  test(`actual entrypoint ${scenario.name} gate prevents all work`,async()=>{
    const runtime=await edge({env:scenario.env});
    const response=await runtime.request(scenario.request);
    assert.equal(response.status,scenario.status);
    assert.equal(response.body.ok,false);
    assert.equal(runtime.clients,0);
    assert.deepEqual(runtime.calls,[]);assert.deepEqual(runtime.records,[]);assert.deepEqual(runtime.logs,[]);
  });
}

for (const slot of ['','unknown-unit-test-slot','constructor','toString','__proto__','hasOwnProperty']) {
  test(`actual entrypoint unknown or inherited slot ${slot} rejects without invoking jobs or ledger`,async()=>{
    const runtime=await edge();
    const response=await runtime.request({slot});
    assert.equal(response.status,400);
    assert.equal(runtime.clients,1);
    assert.deepEqual(runtime.calls,[]);assert.deepEqual(runtime.records,[]);
  });
}

test('actual daily handler executes all 26 unchanged slots once in order and records success',async()=>{
  const runtime=await edge();
  const {status,body}=await runtime.request();
  assert.equal(status,200);assert.equal(body.ok,true);
  assert.deepEqual(body.targets,expectedDailyTargets);
  assert.deepEqual(body.results.map(r=>r.slot),expectedDailyTargets);
  assert.equal(body.results.length,26);
  assert.deepEqual(runtime.calls,expectedDailyCalls);
  assert.equal(runtime.maximumActive,1);
  assert.equal(runtime.records.length,1);
  assert.deepEqual(runtime.records[0].failed_slots,[]);
  assert.deepEqual(body.persistence,{ok:true});
  assert.deepEqual(runtime.logs,[]);
  assert.deepEqual(runtime.clientArguments,[[validEnvironment.SUPABASE_URL,validEnvironment.SUPABASE_SERVICE_ROLE_KEY]]);
  assert.deepEqual(runtime.fetchRequests,[{
    url:validEnvironment.SUPABASE_URL+'/functions/v1/founder_invoice_digest',
    init:{method:'POST',headers:{
      Authorization:'Bearer '+validEnvironment.SUPABASE_SERVICE_ROLE_KEY,
      'x-webhook-secret':validEnvironment.CRON_TICK_SECRET,
      'content-type':'application/json',
    },body:'{}'},
  }]);
});

test('actual hourly group preserves all 8 selected jobs and order',async()=>{
  const runtime=await edge();
  const {status,body}=await runtime.request({slot:'hourly'});
  assert.equal(status,200);
  assert.deepEqual(body.targets,expectedHourlyTargets);
  assert.deepEqual(runtime.calls,expectedHourlyCalls);
  assert.equal(runtime.maximumActive,1);
  assert.equal(runtime.records.length,1);
  assert.deepEqual(runtime.fetchRequests,[]);
});

test('actual all group executes the complete 34-job registry once',async()=>{
  const runtime=await edge();
  const {status,body}=await runtime.request({slot:'all'});
  assert.equal(status,200);
  assert.equal(body.targets.length,34);
  assert.deepEqual([...body.targets].sort(),[...expectedDailyTargets,...expectedHourlyTargets].sort());
  assert.deepEqual([...runtime.calls].sort(),[...expectedDailyCalls,...expectedHourlyCalls].sort());
  assert.equal(new Set(runtime.calls).size,34);
  assert.equal(runtime.maximumActive,1);
  assert.equal(runtime.records.length,1);
});

test('actual omitted slot keeps the default all group and registry order',async()=>{
  const explicit=await edge(),omitted=await edge();
  const first=await explicit.request({slot:'all'});
  const second=await omitted.request({omitSlot:true});
  assert.equal(second.status,200);
  assert.equal(second.body.slot,'all');
  assert.deepEqual(second.body.targets,first.body.targets);
  assert.deepEqual(omitted.calls,explicit.calls);
  assert.equal(omitted.records.length,1);
});

test('actual invoice wrapper retains H401 without reading or logging the provider body',async()=>{
  const runtime=await edge({fetchStatus:401});
  const {status,body}=await runtime.request({slot:'invoice-digest'});
  assert.equal(status,500);
  assert.equal(body.results[0].error_code,'H401');
  assert.deepEqual(body.persistence,{ok:true});
  assert.deepEqual(runtime.calls,['invoice-digest']);
  assert.equal(runtime.fetchResponses[0].bodyUsed,false);
  assert.equal(JSON.stringify({body,records:runtime.records,logs:runtime.logs}).includes(PRIVATE),false);
});

test('actual daily handler keeps failed snapshot and HTTP digest codes when ledger returns error',async()=>{
  const runtime=await edge({
    rpc:async(name)=>name==='db_storage_snapshot_sweep'
      ? {data:null,error:{code:'57014',message:PRIVATE,hint:PRIVATE}}
      : {data:2,error:null},
    fetchStatus:500,
    persist:async()=>({error:{code:'PGRST002',message:PRIVATE,details:PRIVATE}}),
  });
  const {status,body}=await runtime.request();
  assert.equal(status,500);assert.equal(body.ok,false);
  assert.deepEqual(runtime.calls,expectedDailyCalls);
  assert.equal(runtime.records.length,1);
  assert.deepEqual(body.results.filter(r=>!r.ok).map(r=>[r.slot,r.error_code]),[
    ['db-storage-snapshot','57014'],['invoice-digest','H500'],
  ]);
  assert.deepEqual(body.persistence,{ok:false,error:'run_persistence_failed',error_code:'PGRST002'});
  assert.equal(runtime.fetchResponses[0].bodyUsed,false);
  assert.equal(JSON.stringify({body,records:runtime.records,logs:runtime.logs}).includes(PRIVATE),false);
  assert.deepEqual(runtime.logs.map(args=>args[1].event),['slot_failed','slot_failed','run_persistence_failed']);
});

for (const failure of ['returned','thrown']) {
  test(`actual handler preserves HTTP200 and one job execution on ${failure} ledger failure`,async()=>{
    const runtime=await edge({persist:async()=>{
      const error={code:'55P03',message:PRIVATE};
      if(failure==='thrown') throw error;
      return {error};
    }});
    const {status,body}=await runtime.request({slot:'purge-notifications'});
    assert.equal(status,200);assert.equal(body.ok,true);
    assert.deepEqual(runtime.calls,['purge_old_notifications']);
    assert.equal(runtime.records.length,1);
    assert.deepEqual(body.persistence,{ok:false,error:'run_persistence_failed',error_code:'55P03'});
    assert.equal(JSON.stringify({body,logs:runtime.logs}).includes(PRIVATE),false);
  });
}

test('actual handler omits injected error codes and raw details from response, ledger and console',async()=>{
  const runtime=await edge({
    rpc:async()=>({data:null,error:{code:'H500\n'+PRIVATE,message:PRIVATE,details:PRIVATE,hint:PRIVATE}}),
    persist:async()=>{throw new Error(PRIVATE);},
  });
  const {status,body}=await runtime.request({slot:'purge-notifications'});
  assert.equal(status,500);
  assert.equal(body.results[0].error_code,undefined);
  assert.deepEqual(body.persistence,{ok:false,error:'run_persistence_failed'});
  assert.equal(JSON.stringify({body,records:runtime.records,logs:runtime.logs}).includes(PRIVATE),false);
  assert.equal(runtime.calls.length,1);assert.equal(runtime.records.length,1);
});
