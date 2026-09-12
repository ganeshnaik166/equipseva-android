import { copyFileSync, existsSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
const output = process.argv[2];
if (!output) throw new Error('Pass a new staging-directory path');
const target = resolve(output);
if (existsSync(target) && readdirSync(target).length) throw new Error('Staging directory must be empty; no existing files are removed');
mkdirSync(target, {recursive:true});
const source = fileURLToPath(new URL('../website/', import.meta.url));
// Explicit public allow-list: never copy the repository, configs, or internal docs.
const files = ['progress-dashboard.html','progress-dashboard.css','progress-dashboard.js','progress-dashboard-data.json',
  'progress-hq.css','progress-hq.js',
  ...['equipseva-headquarters.glb','hq-poster.webp','equipsevalogo.svg','scene-manifest.json',
    'vendor/three.module.js','vendor/three.core.js','vendor/GLTFLoader.js','vendor/OrbitControls.js',
    'vendor/BufferGeometryUtils.js','vendor/THREE-LICENSE.txt'].map(file=>'progress-assets/'+file)];
for (const file of files) {
  mkdirSync(resolve(target,file,'..'),{recursive:true});
  copyFileSync(join(source,file),join(target,file));
}
copyFileSync(join(source,'progress-dashboard.html'),join(target,'index.html'));
writeFileSync(join(target,'404.html'),'<!doctype html><html lang="en"><meta charset="utf-8"><title>Page not found</title><h1>Page not found</h1><a href="/progress-dashboard">Open EquipSeva development</a></html>');
writeFileSync(join(target,'_headers'), `/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: no-referrer
  X-Robots-Tag: noindex, nofollow
  Cache-Control: no-store
  Content-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self' blob:; img-src 'self' blob: data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
`);
console.log('Packaged '+(files.length+3)+' public files into '+target);
