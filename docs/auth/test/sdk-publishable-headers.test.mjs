import assert from 'node:assert/strict';
import test from 'node:test';
import { createClient } from '@supabase/supabase-js';

const projectUrl = 'https://synthetic-project.example.invalid';
const publishableKey = 'sb_publishable_synthetic_test_only';
const userId = '00000000-0000-4000-8000-000000000001';

function syntheticJwt() {
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return [
    encode({ alg: 'HS256', typ: 'JWT' }),
    encode({ sub: userId, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 }),
    'synthetic-signature',
  ].join('.');
}

test('publishable client keeps apikey while authenticated recovery calls bear the access token', async () => {
  const accessToken = syntheticJwt();
  const calls = [];
  const user = {
    id: userId,
    aud: 'authenticated',
    role: 'authenticated',
    email: 'synthetic@example.invalid',
    app_metadata: {},
    user_metadata: {},
    created_at: '2026-01-01T00:00:00.000Z',
  };
  const fakeFetch = async (input, init = {}) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    assert.equal(url.origin, projectUrl, 'no request may leave the synthetic project origin');
    const headers = new Headers(input instanceof Request ? input.headers : undefined);
    new Headers(init.headers).forEach((value, key) => headers.set(key, value));
    const method = init.method ?? (input instanceof Request ? input.method : 'GET');
    assert.equal(url.pathname, '/auth/v1/user', 'only the expected Auth user endpoint is stubbed');
    assert.ok(method === 'GET' || method === 'PUT', 'unexpected Auth method');
    calls.push({ method, pathname: url.pathname, apikey: headers.get('apikey'), authorization: headers.get('authorization') });
    return new Response(JSON.stringify(user), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  const client = createClient(projectUrl, publishableKey, {
    global: { fetch: fakeFetch },
    auth: {
      detectSessionInUrl: false,
      persistSession: false,
      autoRefreshToken: false,
      flowType: 'implicit',
    },
  });

  const setResult = await client.auth.setSession({
    access_token: accessToken,
    refresh_token: 'synthetic-refresh-token',
  });
  assert.equal(setResult.error, null, 'setSession must establish the synthetic recovery session');
  assert.equal(setResult.data.session?.user?.id, userId);
  const setCalls = calls.splice(0);
  assert.ok(setCalls.length > 0, 'setSession must validate the supplied access token with Auth');

  const userResult = await client.auth.getUser();
  assert.equal(userResult.error, null);
  assert.equal(userResult.data.user?.id, userId);
  const getCalls = calls.splice(0);
  assert.ok(getCalls.length > 0, 'getUser must verify the current user with Auth');

  const updateResult = await client.auth.updateUser({ password: 'synthetic-password-123' });
  assert.equal(updateResult.error, null);
  const updateCalls = calls.splice(0);
  assert.ok(updateCalls.some(({ method }) => method === 'PUT'), 'updateUser must send a PUT to Auth');

  for (const [operation, requests] of [
    ['setSession', setCalls],
    ['getUser', getCalls],
    ['updateUser', updateCalls],
  ]) {
    for (const request of requests) {
      assert.equal(request.apikey, publishableKey, `${operation} must use the publishable API key`);
      assert.equal(request.authorization, `Bearer ${accessToken}`, `${operation} must bear the recovery access token`);
      assert.notEqual(request.authorization, `Bearer ${publishableKey}`, `${operation} must not bear the publishable key`);
    }
  }
});
