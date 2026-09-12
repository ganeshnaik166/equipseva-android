const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const sourcePath = path.join(__dirname, '../../website/progress-dashboard.js');
const code = fs.readFileSync(sourcePath, 'utf8');
const { validate, duration, usageView } = require(sourcePath);
const fixture = () => JSON.parse(fs.readFileSync(path.join(__dirname, '../../website/progress-dashboard-data.json'), 'utf8'));

test('committed snapshot has the supported schema and excludes account identifiers', () => {
  const value = fixture();
  assert.equal(validate(value), value);
  assert.equal(JSON.stringify(value).includes('fc5371cf'), false);
  assert.equal('account' in value.usage, false);
});
test('null, missing fields and malformed collections fail closed', () => {
  for (const value of [null, [], {}, {...fixture(), milestones:{}}, {...fixture(), agents:[null]}, {...fixture(), changes:[null]}, {...fixture(), verification:[null]}]) {
    assert.throws(() => validate(value));
  }
});
test('valid missing usage is not represented as zero', () => {
  const value = fixture();
  value.usage.windows[0].usedPercent = null;
  assert.doesNotThrow(() => validate(value));
  assert.equal(usageView(value.usage.windows[0]).remaining, null);
});
test('percent range and type violations are rejected', () => {
  for (const percent of [-1, 101, '0', NaN, Infinity]) {
    const value = fixture(); value.usage.windows[0].usedPercent = percent;
    assert.throws(() => validate(value));
  }
});
test('five-hour and seven-day windows have correct labels', () => {
  assert.equal(duration(300), '5-hour'); assert.equal(duration(10080), '7-day'); assert.equal(duration(5), '5-minute');
});
test('used percentage is subtracted to show remaining; expired windows are unavailable', () => {
  const window = {usedPercent:62, resetsAt:'2030-01-01T00:00:00Z'};
  assert.equal(usageView(window, 0).remaining, 38);
  assert.equal(usageView({...window,usedPercent:0}, 0).remaining, 100);
  assert.equal(usageView({...window,usedPercent:100}, 0).remaining, 0);
  assert.equal(usageView(window, Date.parse(window.resetsAt)).remaining, null);
});

// Minimal DOM boundary double: any HTML-parsing write throws. This checks the
// injection boundary and controller behavior; actual layout is checked in Chrome.
class Element {
  constructor(tag='div') { this.tagName=tag; this.children=[]; this.textContent=''; this.hidden=false; this.events={}; this.attrs={}; this.classes=new Set(); this.classList={add:x=>this.classes.add(x),toggle:(x,on)=>{const enabled=on??!this.classes.has(x); enabled?this.classes.add(x):this.classes.delete(x);return enabled;}}; }
  set innerHTML(_) { throw new Error('HTML parsing sink used'); }
  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children=[...children]; }
  setAttribute(key,value) { this.attrs[key]=value; }
  addEventListener(key,fn) { this.events[key]=fn; }
}
function harness(fetchImpl) {
  const elements = new Map();
  const doc = {hidden:false,body:new Element('body'),getElementById(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id);},createElement:tag=>new Element(tag),addEventListener(){}};
  doc.getElementById('load-status').parentElement=new Element();
  doc.getElementById('dashboard').hidden=true;
  let calls=0;
  const window = {document:doc,fetch:async(...args)=>{calls++;return fetchImpl(...args);},setTimeout,clearTimeout,setInterval(){},matchMedia:()=>({matches:false,addEventListener(){}})};
  vm.runInNewContext(code,{window,AbortController,console});
  return {doc,element:id=>doc.getElementById(id),calls:()=>calls};
}
const flush = () => new Promise(resolve=>setImmediate(resolve));
const ok = value => ({ok:true,json:async()=>value});
function texts(element) { return [element.textContent,...element.children.flatMap(texts)]; }
test('successful fetch renders actual quota and all milestones', async () => {
  const value=fixture(); value.usage.windows[0]={name:'Codex',minutes:300,usedPercent:62,resetsAt:'2030-01-01T00:00:00Z'};
  const page=harness(async()=>ok(value)); await flush();
  assert.equal(page.element('dashboard').hidden,false);
  assert.equal(page.element('milestones').children.length,value.milestones.length);
  assert.ok(texts(page.element('usage')).includes('38% remaining'));
  assert.equal(page.element('refresh').disabled,false);
});
test('network and invalid JSON failures show unavailable without fabricated fallback', async () => {
  for (const implementation of [async()=>{throw Error('offline');},async()=>({ok:false}),async()=>({ok:true,json:async()=>{throw Error('bad JSON');}}),async()=>ok(null)]) {
    const page=harness(implementation); await flush();
    assert.equal(page.element('dashboard').hidden,true);
    assert.match(page.element('load-status').textContent,/Snapshot unavailable/);
    assert.equal(page.element('refresh').disabled,false);
  }
});
test('failed refresh preserves a real last snapshot with a visible warning', async () => {
  let fail=false;
  const page=harness(async()=>{if(fail)throw Error('offline');return ok(fixture());}); await flush();
  const saved=page.element('commits').textContent; fail=true;
  await page.element('refresh').events.click();
  assert.equal(page.element('commits').textContent,saved);
  assert.equal(page.element('dashboard').hidden,false);
  assert.match(page.element('load-status').textContent,/Update unavailable.*Showing snapshot/);
});
test('untrusted snapshot text remains literal and creates no HTML elements', async () => {
  const value=fixture(); const hostile='<img src=x onerror="alert(1)">';
  value.milestones[0].name=hostile; value.agents[0].name=hostile;
  value.changes=[{sha:'abc12345',time:'2026-09-12T00:00:00Z',summary:hostile}];
  const page=harness(async()=>ok(value)); await flush();
  assert.equal(page.element('dashboard').hidden,false);
  assert.ok(texts(page.element('milestones')).includes(value.milestones[0].id+' · '+hostile));
  assert.ok(texts(page.element('changes')).includes(hostile));
});
test('repeat refresh replaces lists instead of duplicating entries', async () => {
  const value=fixture(); const page=harness(async()=>ok(value)); await flush();
  await page.element('refresh').events.click();
  assert.equal(page.element('milestones').children.length,value.milestones.length);
  assert.equal(page.element('agents').children.length,value.agents.length);
});
test('refresh never launches a competing request while one is pending', async () => {
  let resolve;
  const page=harness(()=>new Promise(r=>{resolve=r;}));
  await page.element('refresh').events.click();
  assert.equal(page.calls(),1);
  resolve(ok(fixture())); await flush();
  assert.equal(page.element('refresh').disabled,false);
});
test('illustration pause button updates its announced state', async () => {
  const page=harness(async()=>ok(fixture())); await flush();
  const button=page.element('motion-toggle'); button.events.click();
  assert.equal(button.attrs['aria-pressed'],'true'); assert.equal(button.textContent,'Resume illustration');
  button.events.click(); assert.equal(button.attrs['aria-pressed'],'false');
});
test('implemented slices awaiting verification are counted independently', async () => {
  const value=fixture();
  value.milestones=[{id:'A2',name:'Role selection',notes:'Code exists; review pending',owner:'Team',status:'verification',implementationComplete:true},
    {id:'A3',name:'Routing',notes:'Partial code',owner:'Team',status:'in_progress',implementationComplete:false}];
  const page=harness(async()=>ok(value)); await flush();
  assert.equal(page.element('slices').textContent,'1 / 2');
  assert.match(page.element('slice-note').textContent,/50%/);
  assert.ok(texts(page.element('milestones')).includes('Verification pending'));
});
test('project feed includes Android changes without exporting raw subjects or paths', () => {
  const summarize=require('../progress-change-summary.cjs');
  assert.equal(summarize([], '16b405b882b859c6085450ad6fe4370434df8970'), 'Isolate engineer verification status across account changes');
  const files=['app/src/main/kotlin/SensitiveAuthIssue.kt','app/src/test/kotlin/AuthTest.kt','docs/private-security-findings.md'];
  const summary=summarize(files);
  assert.match(summary,/Android implementation/); assert.match(summary,/Android regression tests/);
  assert.match(summary,/Project handoff and review/); assert.equal(summary.includes('SensitiveAuthIssue'),false);
  assert.equal(summary.includes('private-security'),false);
  const exporter=fs.readFileSync(path.join(__dirname,'../refresh_progress_snapshot.mjs'),'utf8');
  assert.equal(exporter.includes('%s'),false);
});
