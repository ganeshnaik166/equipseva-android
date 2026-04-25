-- Add the columns that hospital users actually capture on the request-service
-- form, plus provision the repair-photos bucket so issue photos persist.
--
-- equipment_serial   text   nameplate / asset-tag serial.
-- site_location      text   freeform "Ward · Department · Floor" string.
-- issue_photos       []     already exists on the table.

alter table public.repair_jobs
  add column if not exists equipment_serial text,
  add column if not exists site_location    text;

-- ---------------------------------------------------------------------------
-- repair-photos bucket: provision + per-user RLS policies.
-- ---------------------------------------------------------------------------
-- 15 MiB ceiling; client UploadValidator caps at 10 MiB so the server limit
-- only kicks in if a tampered client tries to bypass it.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'repair-photos',
  'repair-photos',
  false,
  15728640,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
  set file_size_limit   = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Policies are keyed on the first folder segment matching auth.uid() so each
-- user can only read/write their own subtree.
drop policy if exists "repair-photos owner read" on storage.objects;
create policy "repair-photos owner read"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'repair-photos'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists "repair-photos owner insert" on storage.objects;
create policy "repair-photos owner insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'repair-photos'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists "repair-photos owner update" on storage.objects;
create policy "repair-photos owner update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'repair-photos'
    and (storage.foldername(name))[1] = (auth.uid())::text
  )
  with check (
    bucket_id = 'repair-photos'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );

drop policy if exists "repair-photos owner delete" on storage.objects;
create policy "repair-photos owner delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'repair-photos'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );
