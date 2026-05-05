-- Device integrity audit log — every Play Integrity verification result the
-- server obtains is appended here, keyed by user_id + action. Used for:
--   * post-hoc fraud forensics ("did this user submit KYC from a tampered build?")
--   * telemetry on how dirty the install base is
--   * future server-side gating ("refuse payout release if last verdict is dirty")
--
-- The table is *insert-only from the server*. Clients never write here directly:
-- the verify-play-integrity Edge Function (running with the service role) is
-- the only writer. Clients can read their own rows for transparency / debug.

create table if not exists public.device_integrity_checks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    action text not null,
    device_verdict text,
    app_verdict text,
    licensing_verdict text,
    raw_token_hash text not null,
    pass boolean not null,
    created_at timestamptz not null default now(),

    -- action is a free-form label like "kyc_submit", "payout_release",
    -- "checkout"; cap to keep the index small and reject silly inputs.
    constraint device_integrity_checks_action_len
        check (char_length(action) between 1 and 64),
    -- raw_token_hash is sha256 hex (64 chars). We store only the hash so
    -- a leak of this table can't be replayed against Google.
    constraint device_integrity_checks_token_hash_fmt
        check (raw_token_hash ~ '^[a-f0-9]{64}$')
);

create index if not exists device_integrity_checks_user_idx
    on public.device_integrity_checks (user_id, created_at desc);
create index if not exists device_integrity_checks_dirty_idx
    on public.device_integrity_checks (created_at desc) where pass = false;

alter table public.device_integrity_checks enable row level security;

-- Owner can read their own audit rows (debug / transparency).
create policy device_integrity_checks_select_own
    on public.device_integrity_checks
    for select
    to authenticated
    using (user_id = auth.uid());

-- Deliberately NO insert/update/delete policy for authenticated or anon.
-- The verify-play-integrity Edge Function uses the service role to write,
-- which bypasses RLS. We do not want clients fabricating "pass=true" rows.

comment on table public.device_integrity_checks is
    'Audit log of Google Play Integrity verifications. Server-only writes via verify-play-integrity Edge Function; clients can select-own.';
