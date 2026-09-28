import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const entryPoint = fileURLToPath(new URL('../src/entry.mjs', import.meta.url));
const outputPath = fileURLToPath(new URL('../reset.js', import.meta.url));
const result = await build({
  entryPoints: [entryPoint],
  bundle: true,
  platform: 'browser',
  format: 'iife',
  target: 'es2020',
  minify: true,
  legalComments: 'eof',
  write: false,
  metafile: true,
});

assert.equal(result.outputFiles.length, 1, 'build must produce one local browser script');
for (const output of Object.values(result.metafile.outputs)) {
  assert.deepEqual(output.imports, [], 'browser script must not import runtime modules');
}

const bundle = result.outputFiles[0].contents;
if (process.argv.includes('--check')) {
  assert.deepEqual(readFileSync(outputPath), Buffer.from(bundle), 'committed browser bundle differs from pinned source build');
  console.log('Committed reset bundle matches the pinned source build.');
} else {
  writeFileSync(outputPath, bundle);
  console.log('Built self-hosted reset bundle.');
}
