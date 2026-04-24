-- User-initiated block list. Keeps blocker -> blocked edges with RLS pinning
-- both read + write to auth.uid() = blocker_user_id. Used on the Android client
-- to hide blocked counterparts from conversations and messages, and required by
-- Play Store content policy alongside report flow.

create table if not exists public.user_blocks (
    id uuid primary key default gen_random_uuid(),
    blocker_user_id uuid not null references auth.users(id) on delete cascade,
    blocked_user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint user_blocks_not_self check (blocker_user_id <> blocked_user_id),
    constraint user_blocks_unique unique (blocker_user_id, blocked_user_id)
);

create index if not exists idx_user_blocks_blocker on public.user_blocks(blocker_user_id);
create index if not exists idx_user_blocks_blocked on public.user_blocks(blocked_user_id);

alter table public.user_blocks enable row level security;

drop policy if exists user_blocks_select_own on public.user_blocks;
create policy user_blocks_select_own on public.user_blocks
for select to authenticated
using (auth.uid() = blocker_user_id);

drop policy if exists user_blocks_insert_own on public.user_blocks;
create policy user_blocks_insert_own on public.user_blocks
for insert to authenticated
with check (auth.uid() = blocker_user_id);

drop policy if exists user_blocks_delete_own on public.user_blocks;
create policy user_blocks_delete_own on public.user_blocks
for delete to authenticated
using (auth.uid() = blocker_user_id);
