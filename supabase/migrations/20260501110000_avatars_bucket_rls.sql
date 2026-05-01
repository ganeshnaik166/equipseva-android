-- avatars bucket — public read, owner-only insert/update/delete keyed
-- on the first folder segment matching auth.uid(). Mirrors the pattern
-- used by repair-photos / kyc-docs for owner gating.
--
-- Path convention: <auth.uid()>/<filename>.<ext>

-- Public read for everything in the bucket (avatars are visible on
-- engineer public profiles, hospital "assigned engineer" cards, etc.).
drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Insert: signed-in user can upload only inside their own folder.
drop policy if exists "avatars_owner_insert" on storage.objects;
create policy "avatars_owner_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Update: same gate (storage.objects.update fires on upsert too).
drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Delete: owner only.
drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
