const INVALID_LINK = 'This link is invalid or has expired. Open the EquipSeva app and request a new reset email.';
const VERIFY_FAILED = 'We could not verify this reset link. Check your connection and reopen the link from your reset email. If that does not work, request a new reset email in the EquipSeva app.';
const SAVE_FAILED = 'Could not save password. Try again.';

// The implicit recovery redirect carries credentials in the URL fragment. Capture
// only the required pair, then remove the entire fragment before creating a client.
export function takeRecoveryLink(location, history) {
  const params = new URLSearchParams(location.hash.replace(/^#/, ''));
  history.replaceState(history.state, '', location.pathname + location.search);
  if (
    params.has('error') || params.has('error_description') ||
    params.getAll('type').length !== 1 || params.get('type') !== 'recovery' ||
    params.getAll('access_token').length !== 1 || !params.get('access_token') ||
    params.getAll('refresh_token').length !== 1 || !params.get('refresh_token')
  ) return null;
  return { accessToken: params.get('access_token'), refreshToken: params.get('refresh_token') };
}

export async function mountResetPage({ doc, client, recovery, signal }) {
  const alertEl = doc.getElementById('alert');
  const form = doc.getElementById('form');
  const btn = doc.getElementById('submit');
  const pw1 = doc.getElementById('pw1');
  const pw2 = doc.getElementById('pw2');
  btn.disabled = true;
  if (signal?.aborted) return;

  function show(kind, message) {
    if (signal?.aborted) return;
    alertEl.className = 'alert ' + kind;
    alertEl.textContent = message;
  }

  if (!recovery) {
    show('error', INVALID_LINK);
    return;
  }

  show('info', 'Checking your reset link…');
  try {
    const { data: sessionData, error: sessionError } = await client.auth.setSession({
      access_token: recovery.accessToken,
      refresh_token: recovery.refreshToken,
    });
    if (signal?.aborted) return;
    if (sessionError || !sessionData?.session?.user?.id) throw new Error('Recovery session rejected');
    // getUser checks with Auth, whereas a locally decoded session alone is not proof.
    const { data: userData, error: userError } = await client.auth.getUser();
    if (signal?.aborted) return;
    if (userError || !userData?.user?.id || userData.user.id !== sessionData.session.user.id) {
      throw new Error('Recovery user rejected');
    }
  } catch {
    if (signal?.aborted) return;
    show('error', VERIFY_FAILED);
    try { await client.auth.signOut({ scope: 'local' }); } catch { /* The form remains disabled. */ }
    return;
  }

  alertEl.className = 'alert';
  alertEl.textContent = '';
  btn.disabled = false;
  let inFlight = false;
  let completed = false;

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (signal?.aborted || inFlight || completed) return;
    if (pw1.value !== pw2.value) {
      show('error', 'Passwords do not match.');
      return;
    }
    if (pw1.value.length < 8) {
      show('error', 'Use at least 8 characters.');
      return;
    }

    inFlight = true;
    btn.disabled = true;
    btn.textContent = 'Saving…';
    alertEl.className = 'alert';
    alertEl.textContent = '';
    try {
      const { error } = await client.auth.updateUser({ password: pw1.value });
      if (signal?.aborted) return;
      if (error) throw error;
      completed = true;
      pw1.value = '';
      pw2.value = '';
      try { await client.auth.signOut({ scope: 'local' }); } catch { /* No persisted session exists. */ }
      show('success', 'Password updated. Open the EquipSeva app and sign in with your new password.');
      btn.textContent = 'Done';
    } catch {
      if (signal?.aborted) return;
      show('error', SAVE_FAILED);
      btn.disabled = false;
      btn.textContent = 'Update password';
    } finally {
      inFlight = false;
    }
  }, signal ? { signal } : undefined);
}
