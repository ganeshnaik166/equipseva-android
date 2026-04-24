-- DPDP (Digital Personal Data Protection Act, India) right-to-erasure surface.
-- A signed-in user calls public.delete_my_account() which:
--   1. Writes an audit row to account_deletions (pending).
--   2. Scrubs PII on public.profiles and flips is_active=false so RLS-gated
--      reads stop surfacing the user.
--   3. Deletes their FCM device_tokens so we stop pushing to them.
-- The auth.users row is left intact so a service-role sweeper can hard-delete
-- after the 30-day DPDP grace window. No direct client INSERT path exists --
-- the RPC is the only writer, which is why there's no INSERT policy below.

create table if not exists public.account_deletions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    reason text,
    requested_at timestamptz not null default now(),
    processed_at timestamptz,
    status text not null default 'pending',
    constraint account_deletions_status_check check (status in ('pending', 'processed', 'cancelled')),
    constraint account_deletions_reason_len check (reason is null or char_length(reason) <= 500)
);

create index if not exists idx_account_deletions_user on public.account_deletions(user_id);
create index if not exists idx_account_deletions_status on public.account_deletions(status) where status = 'pending';

alter table public.account_deletions enable row level security;

drop policy if exists account_deletions_select_own on public.account_deletions;
create policy account_deletions_select_own on public.account_deletions
for select to authenticated
using (auth.uid() = user_id);

create or replace function public.delete_my_account(p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user uuid := auth.uid();
begin
    if v_user is null then
        raise exception 'Not authenticated' using errcode = '42501';
    end if;

    insert into public.account_deletions(user_id, reason, status)
    values (v_user, p_reason, 'pending');

    update public.profiles
       set full_name = null,
           phone = null,
           avatar_url = null,
           is_active = false,
           onboarding_completed = false,
           organization_id = null
     where id = v_user;

    delete from public.device_tokens where user_id = v_user;
end;
$$;

revoke all on function public.delete_my_account(text) from public;
grant execute on function public.delete_my_account(text) to authenticated;
