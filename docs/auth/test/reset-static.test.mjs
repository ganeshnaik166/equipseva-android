import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const html = readFileSync(new URL('../reset.html', import.meta.url), 'utf8');

function policy() {
  const value = html.match(/<meta\s+http-equiv="Content-Security-Policy"\s+content="([^"]+)"\s*\/?\s*>/i)?.[1];
  assert.ok(value, 'the reset page needs a CSP before loading assets');
  return new Map(value.split(';').map((part) => part.trim()).filter(Boolean).map((part) => {
    const [name, ...sources] = part.split(/\s+/);
    return [name, sources];
  }));
}

test('reset page permits only self-hosted static assets and the Supabase API', () => {
  const csp = policy();
  assert.deepEqual(csp.get('default-src'), ["'none'"]);
  assert.deepEqual(csp.get('script-src'), ["'self'"]);
  assert.deepEqual(csp.get('style-src'), ["'self'"]);
  assert.deepEqual(csp.get('img-src'), ["'self'"]);
  assert.deepEqual(csp.get('connect-src'), ['https://eyswaywvtartpvtoxtdr.supabase.co']);
  assert.deepEqual(csp.get('base-uri'), ["'none'"]);
  assert.deepEqual(csp.get('form-action'), ["'none'"]);
  assert.deepEqual(csp.get('object-src'), ["'none'"]);
  assert.deepEqual(csp.get('frame-src'), ["'none'"]);
  assert.deepEqual(csp.get('worker-src'), ["'none'"]);
  assert.ok(html.indexOf('Content-Security-Policy') < html.indexOf('<link rel="stylesheet"'));
  assert.ok(!/unsafe-inline|unsafe-eval|\bhttps?:\/\/esm\.sh\b/i.test(html));
});

test('reset page has no inline code or style and starts with submit disabled', () => {
  const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
  assert.equal(scripts.length, 1);
  assert.match(scripts[0][1], /\bsrc="\/auth\/reset\.js"/);
  assert.equal(scripts[0][2].trim(), '');
  assert.match(html, /<link\s+rel="stylesheet"\s+href="\/auth\/reset\.css"/);
  assert.doesNotMatch(html, /<style\b|\sstyle=/i);
  assert.match(html, /<button\b[^>]*\bid="submit"[^>]*\bdisabled\b/);
  assert.match(html, /<div\b[^>]*\bid="alert"[^>]*\baria-live="polite"/);
  assert.match(html, /<meta\s+name="referrer"\s+content="no-referrer"/);
});

test('committed browser bundle has no external imports or runtime CDN', () => {
  const bundle = readFileSync(new URL('../reset.js', import.meta.url), 'utf8');
  assert.equal(/https?:\/\/(?:esm\.sh|cdn\.|unpkg\.com|jsdelivr\.net)/i.test(bundle), false);
  assert.equal(/\bimport\s*\(\s*['"`]https?:\/\//.test(bundle), false);
  assert.equal(/\brequire\s*\(/.test(bundle), false);
});
