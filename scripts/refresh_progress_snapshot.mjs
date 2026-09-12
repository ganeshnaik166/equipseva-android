// Refresh only facts obtainable from Git. Quota, agent and verification observations
// retain their own capture times and must be supplied from actual tool/test results.
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import summarizeFiles from './progress-change-summary.cjs';
const repo = fileURLToPath(new URL('../', import.meta.url));
const file = new URL('../website/progress-dashboard-data.json', import.meta.url);
const git = (...args) => execFileSync('git', args, { cwd: repo, encoding: 'utf8' }).trim();
const data = JSON.parse(readFileSync(file, 'utf8'));
const { base } = data.source;
if (!/^[a-f0-9]{40}$/.test(base)) throw new Error('A full base commit is required');
data.source = { branch: git('branch', '--show-current'), head: git('rev-parse', 'HEAD'), base, commits: Number(git('rev-list', '--count', base + '..HEAD')) };
// Commit subjects are intentionally not exported: they can contain private
// operational findings. Classify app, test, website, docs and delivery paths.
const commits = git('log', '-12', '--format=%H%x09%cI', base + '..HEAD');
data.changes = commits ? commits.split('\n').map(line => {
  const [sha, time] = line.split('\t');
  const files = git('diff-tree', '--root', '--no-commit-id', '--name-only', '-r', sha).split('\n');
  return { sha, time, summary: summarizeFiles(files, sha) };
}) : [];
// generatedAt covers the authored status observation; Git-only refresh does not
// change that timestamp or imply that quota/agent information was re-observed.
writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
console.log('Updated Git facts. Agent status and quota capture timestamps preserved.');
