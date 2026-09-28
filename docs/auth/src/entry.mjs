import { createClient } from '@supabase/supabase-js';
import { mountResetPage, takeRecoveryLink } from './reset-page.mjs';

const recovery = takeRecoveryLink(window.location, window.history);
const client = createClient('https://eyswaywvtartpvtoxtdr.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV5c3dheXd2dGFydHB2dG94dGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwODU3NzEsImV4cCI6MjA5MTY2MTc3MX0.2TMlyW03NJYNHCgVJGsQzkM4zHij-BR3K6HlBoYHHOA', {
  auth: {
    detectSessionInUrl: false,
    persistSession: false,
    autoRefreshToken: false,
    flowType: 'implicit',
  },
});

void mountResetPage({ doc: document, client, recovery });
