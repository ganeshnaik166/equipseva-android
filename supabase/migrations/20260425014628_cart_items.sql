-- Cart server sync (PENDING.md #17). Today the cart is Room-only, so a user
-- who reinstalls the app or switches device loses everything in their basket.
-- Land a per-user `cart_items` table with strict RLS so the Android client
-- can persist mutations through the existing CART_MUTATION outbox handler
-- (PR #161) and reconcile on session start.
--
-- Shape:
--   - Composite PK (user_id, spare_part_id) so an upsert "add same part twice"
--     collapses to a quantity update — required for handler idempotency.
--   - quantity bounded 1..99. Removals are DELETEs, never qty=0 rows.
--   - updated_at lets the client tell server-newer from local-newer; we keep
--     the server-wins reconcile policy simple by sorting on this index.
--   - Cascading FKs to auth.users and spare_parts so that a deleted account or
--     delisted part doesn't leave dangling cart rows.
--
-- RLS: only the row's owner can read/write their own cart. All four policies
-- carry WITH_CHECK where applicable, in line with the recent
-- "round*_close_with_check_gaps" hardening passes — prevents an UPDATE from
-- transferring a row to a different user_id.

create table if not exists public.cart_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  spare_part_id uuid not null references public.spare_parts(id) on delete cascade,
  quantity integer not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, spare_part_id),
  constraint cart_items_quantity_bounded check (quantity > 0 and quantity <= 99)
);

create index if not exists cart_items_user_updated_idx
  on public.cart_items (user_id, updated_at desc);

alter table public.cart_items enable row level security;

drop policy if exists "cart_items owner select" on public.cart_items;
create policy "cart_items owner select"
  on public.cart_items
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "cart_items owner insert" on public.cart_items;
create policy "cart_items owner insert"
  on public.cart_items
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "cart_items owner update" on public.cart_items;
create policy "cart_items owner update"
  on public.cart_items
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "cart_items owner delete" on public.cart_items;
create policy "cart_items owner delete"
  on public.cart_items
  for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.cart_items is
  'Per-user shopping cart. Local Room is primary on Android; this table is the persistence backstop so cart survives reinstall and roams across devices.';
