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
