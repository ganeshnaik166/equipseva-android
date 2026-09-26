const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const {spawnSync}=require('node:child_process');
const repo=path.resolve(__dirname,'../..');
const snapshotPath=path.join(repo,'website/progress-dashboard-data.json');
const fixture=()=>JSON.parse(fs.readFileSync(snapshotPath,'utf8'));

test('publisher refuses routine invocation without touching the milestone',()=>{
  const before=fs.readFileSync(snapshotPath);
  const result=spawnSync(process.execPath,['scripts/refresh_progress_snapshot.mjs'],{cwd:repo,encoding:'utf8'});
  assert.notEqual(result.status,0);assert.match(result.stderr,/major-milestone/);
  assert.deepEqual(fs.readFileSync(snapshotPath),before);
});

test('publisher advances only a named major record and preserves quota capture',async()=>{
  const {advanceSnapshot}=await import('../refresh_progress_snapshot.mjs');
  const current=fixture(),before=structuredClone(current);
  const facts={source:{...current.source,commits:current.source.commits+1},changes:[]};
  assert.throws(()=>advanceSnapshot(current,facts));
  assert.throws(()=>advanceSnapshot(current,facts,{id:current.majorMilestone.id,title:'Repeated record'}));
  const next=advanceSnapshot(current,facts,{id:'HQ-TEST',title:'Synthetic milestone'},'2030-01-01T00:00:00Z');
  assert.equal(next.majorMilestone.sequence,current.majorMilestone.sequence+1);
  assert.equal(next.source.commits,facts.source.commits);
  assert.deepEqual(next.usage,current.usage);assert.deepEqual(next.agents,current.agents);
  assert.equal(next.agentsObservedAt,current.agentsObservedAt);
  assert.deepEqual(current,before);
  assert.throws(()=>advanceSnapshot(current,facts,{id:'HQ-TEST',title:'Backdated'},'2000-01-01T00:00:00Z'));
});

test('public package contains complete local scene dependencies and excludes editable/private source',()=>{
  const target=fs.mkdtempSync(path.join(os.tmpdir(),'equipseva-hq-package-'));
  // Keep the uniquely named small output for inspection; never remove a shared directory.
  const result=spawnSync(process.execPath,['scripts/package_progress_dashboard.mjs',target],{cwd:repo,encoding:'utf8'});
  assert.equal(result.status,0,result.stderr);
  const list=fs.readdirSync(target,{recursive:true}).filter(file=>fs.statSync(path.join(target,file)).isFile());
  assert.equal(list.length,19);
  assert.equal(list.some(file=>/\.blend\d?$|\.png$|\.md$|\.py$|\.env|credentials/i.test(file)),false);
  for(const file of ['progress-hq.js','progress-hq.css','progress-assets/equipseva-headquarters.glb','progress-assets/hq-poster.webp','progress-assets/vendor/three.core.js'])
    assert.deepEqual(fs.readFileSync(path.join(target,file)),fs.readFileSync(path.join(repo,'website',file)));
  const headers=fs.readFileSync(path.join(target,'_headers'),'utf8');
  assert.match(headers,/connect-src 'self' blob:/);assert.match(headers,/frame-ancestors 'none'/);
  const moduleFiles=list.filter(file=>file.endsWith('.js'));
  for(const file of moduleFiles){
    const code=fs.readFileSync(path.join(target,file),'utf8');
    for(const match of code.matchAll(/(?:from\s*|import\s*)['"]([^'"]+)['"]/g)){
      const specifier=match[1];if(!specifier.startsWith('.'))continue;
      assert.ok(fs.existsSync(path.resolve(target,path.dirname(file),specifier)),file+' missing '+specifier);
    }
  }
  const again=spawnSync(process.execPath,['scripts/package_progress_dashboard.mjs',target],{cwd:repo,encoding:'utf8'});
  assert.notEqual(again.status,0);assert.match(again.stderr,/must be empty/);
});

test('Blender binary scene contains all offices and real animation tracks',()=>{
  const glb=fs.readFileSync(path.join(repo,'website/progress-assets/equipseva-headquarters.glb'));
  assert.equal(glb.toString('ascii',0,4),'glTF');assert.equal(glb.readUInt32LE(4),2);
  const jsonLength=glb.readUInt32LE(12);
  const scene=JSON.parse(glb.toString('utf8',20,20+jsonLength));
  for(const id of ['center','hospital','engineer','admin','login','security','qa','plan','main'])
    assert.ok(scene.nodes.some(node=>node.name==='HQ_'+id&&node.extras?.hq===id),'Missing '+id);
  assert.ok(scene.animations.length>0);
  assert.ok(scene.animations.some(animation=>animation.channels.length>0));
  assert.ok(scene.images.length>0,'Original logo texture is embedded');
  assert.equal((scene.images||[]).some(image=>image.uri?.startsWith('http')),false);
});
