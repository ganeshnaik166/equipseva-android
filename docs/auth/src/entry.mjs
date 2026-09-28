import { createClient } from '@supabase/supabase-js';
import { mountResetPage, takeRecoveryLink } from './reset-page.mjs';

const recovery = takeRecoveryLink(window.location, window.history);
const controller = new AbortController();

// A second link to this same path can be a hash-only navigation: the browser
// keeps the old document and its verified Auth client unless we invalidate it.
function invalidateAndReload() {
  controller.abort();
  document.getElementById('submit').disabled = true;
  document.getElementById('pw1').value = '';
  document.getElementById('pw2').value = '';
  window.location.reload();
}
window.addEventListener('hashchange', invalidateAndReload);
// Back/forward cache can likewise restore an already-verified document.
window.addEventListener('pageshow', (event) => {
  if (event.persisted) invalidateAndReload();
});
const client = createClient('https://eyswaywvtartpvtoxtdr.supabase.co', 'sb_publishable_BjgPTUu0myyQJnOddTS0-A_bKlWOtqL', {
  auth: {
    detectSessionInUrl: false,
    persistSession: false,
    autoRefreshToken: false,
    flowType: 'implicit',
  },
});

void mountResetPage({ doc: document, client, recovery, signal: controller.signal });
