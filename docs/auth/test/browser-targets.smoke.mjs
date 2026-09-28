import assert from 'node:assert/strict';
import { createReadStream } from 'node:fs';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

// Optional local smoke. Supply installed Playwright and Chrome paths explicitly;
// the offline CI suite does not download or require a browser runtime.
const require = createRequire(import.meta.url);
const playwrightPath = process.env.EQUIPSEVA_PLAYWRIGHT_PATH;
const chromePath = process.env.EQUIPSEVA_CHROME_PATH;
if (!playwrightPath || !chromePath) {
  throw new Error('Set EQUIPSEVA_PLAYWRIGHT_PATH and EQUIPSEVA_CHROME_PATH for this optional local smoke.');
}
const { chromium } = require(playwrightPath);

const assetDir = fileURLToPath(new URL('../', import.meta.url));
const assets = new Map([
  ['/auth/reset', ['reset.html', 'text/html; charset=utf-8']],
  ['/auth/reset.css', ['reset.css', 'text/css; charset=utf-8']],
  ['/auth/reset.js', ['reset.js', 'text/javascript; charset=utf-8']],
]);

test('real Chrome touch targets and compact viewport remain reachable', async () => {
  const server = createServer((request, response) => {
    const asset = assets.get(request.url);
    if (!asset) { response.writeHead(404); response.end(); return; }
    response.writeHead(200, { 'content-type': asset[1] });
    createReadStream(join(assetDir, asset[0])).pipe(response);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ executablePath: chromePath, headless: true });
    const base = `http://127.0.0.1:${server.address().port}`;
    const measurements = [];
    for (const viewport of [{ width: 1024, height: 768 }, { width: 320, height: 420 }]) {
      const page = await browser.newPage({ viewport });
      const externalRequests = [];
      page.on('request', (request) => { if (!request.url().startsWith(base)) externalRequests.push(request.url()); });
      await page.goto(`${base}/auth/reset#type=recovery`);
      await page.locator('#alert.error').waitFor();
      const sizes = await page.evaluate(() => {
        const box = (selector) => {
          const bounds = document.querySelector(selector).getBoundingClientRect();
          return { width: bounds.width, height: bounds.height, top: bounds.top };
        };
        return {
          firstField: box('#pw1'), secondField: box('#pw2'),
          submit: box('#submit'), support: box('.support-link'), card: box('.card'),
          viewportWidth: innerWidth, viewportHeight: innerHeight,
          documentWidth: document.documentElement.scrollWidth,
          documentHeight: document.documentElement.scrollHeight,
        };
      });
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      const supportReachable = await page.evaluate(() => {
        const bounds = document.querySelector('.support-link').getBoundingClientRect();
        return bounds.top >= 0 && bounds.bottom <= innerHeight + 1;
      });
      measurements.push({ viewport, sizes, supportReachable, externalRequestCount: externalRequests.length });
      await page.close();
    }
    // These measurements intentionally contain no recovery credentials or account data.
    console.log(JSON.stringify(measurements));
    for (const result of measurements) {
      const { sizes } = result;
      assert.ok(sizes.firstField.height >= 48, 'new-password field must be at least 48 CSS px high');
      assert.ok(sizes.secondField.height >= 48, 'confirmation field must be at least 48 CSS px high');
      assert.ok(sizes.submit.height >= 52, 'primary action must be at least 52 CSS px high');
      assert.ok(sizes.support.width >= 48 && sizes.support.height >= 48, 'support link target must be at least 48 by 48 CSS px');
      assert.ok(sizes.documentWidth <= sizes.viewportWidth + 1, 'page must not scroll horizontally');
      assert.ok(sizes.card.top >= 0, 'card top must remain reachable');
      assert.equal(result.supportReachable, true, 'support link must be reachable after scrolling');
      assert.equal(result.externalRequestCount, 0, 'invalid link must issue no external request');
    }
    assert.ok(measurements[1].sizes.documentHeight > measurements[1].sizes.viewportHeight, 'compact viewport must scroll');
  } finally {
    if (browser) await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
});

test('a second same-tab recovery link replaces the verified account and clears its fragment', async () => {
  const server = createServer((request, response) => {
    const asset = assets.get(request.url);
    if (!asset) { response.writeHead(404); response.end(); return; }
    response.writeHead(200, { 'content-type': asset[1] });
    createReadStream(join(assetDir, asset[0])).pipe(response);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ executablePath: chromePath, headless: true });
    const base = `http://127.0.0.1:${server.address().port}`;
    const page = await browser.newPage();
    const userA = '00000000-0000-4000-8000-000000000001';
    const userB = '00000000-0000-4000-8000-000000000002';
    const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
    const token = (id) => [
      encode({ alg: 'HS256', typ: 'JWT' }),
      encode({ sub: id, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 }),
      'synthetic-signature',
    ].join('.');
    const tokenA = token(userA);
    const tokenB = token(userB);
    const authRequests = [];
    await page.route('https://eyswaywvtartpvtoxtdr.supabase.co/**', async (route) => {
      const request = route.request();
      const authorization = request.headers().authorization;
      const id = authorization === `Bearer ${tokenA}` ? userA : authorization === `Bearer ${tokenB}` ? userB : null;
      assert.equal(request.headers().apikey?.startsWith('sb_publishable_'), true);
      assert.ok(id, 'Auth must receive a synthetic recovery access token');
      assert.equal(new URL(request.url()).pathname, '/auth/v1/user');
      authRequests.push(id);
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({
        id, aud: 'authenticated', role: 'authenticated',
        email: 'synthetic@example.invalid', app_metadata: {}, user_metadata: {},
        created_at: '2026-01-01T00:00:00.000Z',
      }) });
    });
    const recoveryUrl = (accessToken) => `${base}/auth/reset#access_token=${accessToken}&refresh_token=synthetic-refresh&type=recovery`;
    await page.goto(recoveryUrl(tokenA));
    await page.waitForFunction(() => !document.querySelector('#submit').disabled && location.hash === '');
    const firstCount = authRequests.length;
    assert.ok(firstCount > 0 && authRequests.every((id) => id === userA));

    await page.goto(recoveryUrl(tokenB));
    await page.waitForFunction(() => !document.querySelector('#submit').disabled && location.hash === '', undefined, { timeout: 5000 });
    assert.ok(authRequests.length > firstCount, 'second link must be verified with Auth');
    assert.ok(authRequests.slice(firstCount).every((id) => id === userB), 'old account must not verify second link');

    const verifiedCount = authRequests.length;
    await page.goto(`${base}/auth/reset#type=recovery`);
    await page.locator('#alert.error').waitFor();
    assert.equal(await page.evaluate(() => location.hash), '', 'invalid second link must also be cleared');
    assert.equal(await page.locator('#submit').isDisabled(), true, 'invalid second link must disable the old form');
    assert.equal(authRequests.length, verifiedCount, 'invalid second link must not call Auth');

    await page.goto(recoveryUrl(tokenB));
    await page.waitForFunction(() => !document.querySelector('#submit').disabled && location.hash === '');
    await page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })));
    await page.locator('#alert.error').waitFor();
    assert.equal(await page.locator('#submit').isDisabled(), true, 'restored document must not retain a verified form');
    assert.equal(await page.evaluate(() => location.hash), '', 'restored document must not retain a token fragment');
    await page.close();
  } finally {
    if (browser) await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
});
