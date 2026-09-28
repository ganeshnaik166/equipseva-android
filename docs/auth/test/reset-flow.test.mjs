import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { mountResetPage, takeRecoveryLink } from '../src/reset-page.mjs';

function page() {
  const elements = Object.fromEntries(['alert', 'form', 'submit', 'pw1', 'pw2'].map((id) => [id, {
    id, value: '', textContent: '', className: 'alert', disabled: id === 'submit',
    listeners: {},
    addEventListener(event, listener) { this.listeners[event] = listener; },
  }]));
  return {
    elements,
    doc: { getElementById: (id) => elements[id] },
    async submit() {
      const handler = elements.form.listeners.submit;
      assert.ok(handler, 'submit must only be wired after recovery verification');
      await handler({ preventDefault() {} });
    },
  };
}

function client({ sessionId = 'recovery-account', userId = sessionId, setError = null, getError = null, updateError = null } = {}) {
  const calls = [];
  const auth = {
    async setSession(tokens) {
      calls.push(['setSession', tokens]);
      return { data: { session: setError ? null : { user: { id: sessionId } } }, error: setError };
    },
    async getUser() {
      calls.push(['getUser']);
      return { data: { user: getError ? null : { id: userId } }, error: getError };
    },
    async updateUser(value) {
      calls.push(['updateUser', value]);
      return { data: {}, error: updateError };
    },
    async signOut(value) { calls.push(['signOut', value]); return { error: null }; },
  };
  return { auth, calls };
}

function link(hash) {
  const location = { pathname: '/auth/reset', search: '?source=email', hash };
  const replacements = [];
  const history = { state: null, replaceState: (...args) => replacements.push(args) };
  return { recovery: takeRecoveryLink(location, history), replacements };
}

test('fragment is removed and only an exact recovery token pair is accepted', () => {
  const valid = link('#access_token=synthetic-access&refresh_token=synthetic-refresh&type=recovery');
  assert.deepEqual(valid.recovery, { accessToken: 'synthetic-access', refreshToken: 'synthetic-refresh' });
  assert.equal(valid.replacements[0][2], '/auth/reset?source=email');
  for (const hash of [
    '#type=recovery',
    '#access_token=synthetic-access&refresh_token=synthetic-refresh&type=signup',
    '#access_token=synthetic-access&type=recovery',
    '#refresh_token=synthetic-refresh&type=recovery',
    '#error_description=private-provider-detail',
  ]) {
    const result = link(hash);
    assert.equal(result.recovery, null);
    assert.equal(result.replacements[0][2], '/auth/reset?source=email');
  }
});

test('invalid link cannot reuse a preloaded same-origin session', async () => {
  const existingStorage = new Map([['supabase-auth-token', 'different-account']]);
  const ui = page();
  const sb = client({ sessionId: existingStorage.get('supabase-auth-token') });
  await mountResetPage({ doc: ui.doc, client: sb, recovery: link('#type=recovery').recovery });
  assert.equal(ui.elements.submit.disabled, true);
  assert.equal(ui.elements.form.listeners.submit, undefined);
  assert.equal(sb.calls.length, 0);
  assert.doesNotMatch(ui.elements.alert.textContent, /different-account|private-provider-detail/);
  const entry = readFileSync(new URL('../src/entry.mjs', import.meta.url), 'utf8');
  assert.match(entry, /persistSession:\s*false/);
  assert.match(entry, /detectSessionInUrl:\s*false/);
  assert.match(entry, /autoRefreshToken:\s*false/);
});

test('failed, expired, or mismatched recovery sessions leave form disabled', async () => {
  for (const options of [
    { setError: new Error('expired synthetic token') },
    { getError: new Error('invalid synthetic token') },
    { userId: 'different-account' },
  ]) {
    const ui = page();
    const sb = client(options);
    await mountResetPage({ doc: ui.doc, client: sb, recovery: link('#access_token=synthetic-access&refresh_token=synthetic-refresh&type=recovery').recovery });
    assert.equal(ui.elements.submit.disabled, true);
    assert.equal(ui.elements.form.listeners.submit, undefined);
    assert.ok(sb.calls.some(([name]) => name === 'setSession'));
    assert.ok(!sb.calls.some(([name]) => name === 'updateUser'));
    assert.doesNotMatch(ui.elements.alert.textContent, /expired synthetic token|invalid synthetic token|different-account/);
  }
});

test('verification transport failure gives safe next steps after removing the fragment', async () => {
  for (const failingMethod of ['setSession', 'getUser']) {
    const ui = page();
    const sb = client();
    sb.auth[failingMethod] = async () => { throw new TypeError('synthetic-provider-network-detail'); };
    const parsed = link('#access_token=synthetic-access&refresh_token=synthetic-refresh&type=recovery');
    await mountResetPage({ doc: ui.doc, client: sb, recovery: parsed.recovery });
    assert.equal(parsed.replacements[0][2], '/auth/reset?source=email');
    assert.equal(ui.elements.submit.disabled, true);
    assert.equal(ui.elements.form.listeners.submit, undefined);
    assert.ok(!sb.calls.some(([name]) => name === 'updateUser'));
    assert.match(ui.elements.alert.textContent, /connection/i);
    assert.match(ui.elements.alert.textContent, /reset email/i);
    assert.doesNotMatch(ui.elements.alert.textContent, /synthetic-provider-network-detail|synthetic-access|synthetic-refresh/);
  }
});

test('verified link enables one password update and attempts local sign-out', async () => {
  const ui = page();
  const sb = client();
  await mountResetPage({ doc: ui.doc, client: sb, recovery: link('#access_token=synthetic-access&refresh_token=synthetic-refresh&type=recovery').recovery });
  assert.equal(ui.elements.submit.disabled, false);
  assert.deepEqual(sb.calls.map(([name]) => name), ['setSession', 'getUser']);
  ui.elements.pw1.value = 'strong-synthetic-password';
  ui.elements.pw2.value = 'strong-synthetic-password';
  await ui.submit();
  assert.deepEqual(sb.calls.filter(([name]) => name === 'updateUser'), [['updateUser', { password: 'strong-synthetic-password' }]]);
  assert.ok(sb.calls.some(([name, value]) => name === 'signOut' && value.scope === 'local'));
  assert.match(ui.elements.alert.textContent, /Password updated/);
  assert.equal(ui.elements.submit.disabled, true);
});

test('mismatch and provider failure never claim success', async () => {
  const ui = page();
  const sb = client({ updateError: new Error('private-provider-detail') });
  await mountResetPage({ doc: ui.doc, client: sb, recovery: link('#access_token=synthetic-access&refresh_token=synthetic-refresh&type=recovery').recovery });
  ui.elements.pw1.value = 'strong-synthetic-password';
  ui.elements.pw2.value = 'different-synthetic-password';
  await ui.submit();
  assert.ok(!sb.calls.some(([name]) => name === 'updateUser'));
  ui.elements.pw2.value = ui.elements.pw1.value;
  await ui.submit();
  assert.equal(sb.calls.filter(([name]) => name === 'updateUser').length, 1);
  assert.doesNotMatch(ui.elements.alert.textContent, /private-provider-detail|Password updated/);
  assert.equal(ui.elements.submit.disabled, false);
});

test('double submit while a request is pending sends one update', async () => {
  let finishUpdate;
  const ui = page();
  const sb = client();
  sb.auth.updateUser = async (value) => {
    sb.calls.push(['updateUser', value]);
    return new Promise((resolve) => { finishUpdate = resolve; });
  };
  await mountResetPage({ doc: ui.doc, client: sb, recovery: link('#access_token=synthetic-access&refresh_token=synthetic-refresh&type=recovery').recovery });
  ui.elements.pw1.value = ui.elements.pw2.value = 'strong-synthetic-password';
  const first = ui.submit();
  const second = ui.submit();
  assert.equal(sb.calls.filter(([name]) => name === 'updateUser').length, 1);
  finishUpdate({ data: {}, error: null });
  await Promise.all([first, second]);
});
