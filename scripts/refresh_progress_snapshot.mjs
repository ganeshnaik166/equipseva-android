// New major records require an explicit command; routine commits do not publish.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, renameSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import summarizeFiles from './progress-change-summary.cjs';
import dashboard from '../website/progress-dashboard.js';

export function advanceSnapshot(current, facts, milestone, now=new Date().toISOString()) {
  dashboard.validate(current);
  if (!milestone || !/^[A-Z0-9][A-Z0-9_-]{1,63}$/.test(milestone.id) || !milestone.title?.trim())
    throw new Error('Provide a new major milestone ID and title; routine refresh is disabled');
  if (current.majorMilestone.id===milestone.id) throw new Error('An existing milestone is immutable');
  const next=structuredClone(current);
  next.source=facts.source;next.changes=facts.changes;
  next.generatedAt=now;
  next.majorMilestone={id:milestone.id,title:milestone.title.trim(),sequence:current.majorMilestone.sequence+1,major:true,recordedAt:now};
  return dashboard.nextMilestone(current,next);
}

if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const args=process.argv.slice(2);
  if(args.length!==4 || args[0]!=='--major-milestone' || args[2]!=='--title')
    throw new Error('Usage: node scripts/refresh_progress_snapshot.mjs --major-milestone HQ-02 --title "Reviewed headquarters milestone"');
  const repo=fileURLToPath(new URL('../',import.meta.url));
  const file=fileURLToPath(new URL('../website/progress-dashboard-data.json',import.meta.url));
  const git=(...values)=>execFileSync('git',values,{cwd:repo,encoding:'utf8'}).trim();
  const data=JSON.parse(readFileSync(file,'utf8'));
  const {base}=data.source;
  if(!/^[a-f0-9]{40}$/.test(base))throw new Error('A full base commit is required');
  const source={branch:git('branch','--show-current'),head:git('rev-parse','HEAD'),base,commits:Number(git('rev-list','--count',base+'..HEAD'))};
  // Never export commit subjects or raw paths: operational details can be private.
  const commits=git('log','-12','--format=%H%x09%cI',base+'..HEAD');
  const changes=commits?commits.split('\n').map(line=>{
    const [sha,time]=line.split('\t');
    const files=git('diff-tree','--root','--no-commit-id','--name-only','-r',sha).split('\n');
    return {sha,time,summary:summarizeFiles(files,sha)};
  }):[];
  const next=advanceSnapshot(data,{source,changes},{id:args[1],title:args[3]});
  // Same-directory rename publishes a complete validated record atomically.
  const pending=file+'.pending';
  writeFileSync(pending,JSON.stringify(next,null,2)+'\n',{flag:'wx'});
  renameSync(pending,file);
  console.log('Saved major milestone '+next.majorMilestone.id+'. Quota and agent capture times preserved.');
}
