import { createClient } from '@supabase/supabase-js';
import { mountResetPage, takeRecoveryLink } from './reset-page.mjs';

const recovery = takeRecoveryLink(window.location, window.history);
const client = createClient('https://eyswaywvtartpvtoxtdr.supabase.co', 'sb_publishable_BjgPTUu0myyQJnOddTS0-A_bKlWOtqL', {
  auth: {
    detectSessionInUrl: false,
    persistSession: false,
    autoRefreshToken: false,
    flowType: 'implicit',
  },
});

void mountResetPage({ doc: document, client, recovery });
