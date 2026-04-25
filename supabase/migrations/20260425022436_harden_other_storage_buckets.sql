-- Mirror the kyc-docs bucket hardening (PR #140) onto every other Supabase
-- Storage bucket the EquipSeva Android client uploads to. Pin file_size_limit
-- and allowed_mime_types on the bucket so a caller bypassing the on-device
-- UploadValidator still gets rejected at the storage layer, and ensure every
-- per-bucket UPDATE policy has a WITH_CHECK that mirrors USING so an owner
-- cannot rename a row into another user's folder (ownership-transfer gap).
--
-- Buckets covered (caps chosen >= the client UploadValidator caps so existing
-- uploads are never broken):
--   * avatars            ->  2 MiB, image/jpeg|png|webp
--   * chat-attachments   -> 10 MiB, image/jpeg|png|webp
--   * repair-photos      -> 15 MiB, image/jpeg|png|webp
--
-- Some of these buckets are created on-demand by ops/console rather than by a
-- migration, so the bucket row may not yet exist in storage.buckets at the
-- time this migration runs. The UPDATE statements below are guarded by
-- `where id = '<bucket>'` and silently no-op when the row is missing; the
-- policy blocks are wrapped in DO ... IF EXISTS so they only attempt to
-- recreate the policy when the bucket has been provisioned. Once a missing
-- bucket gets created later, ops should rerun the relevant statements (or
-- re-apply this migration in a one-shot) to inherit the hardening.

-- ---------------------------------------------------------------------------
-- avatars (profile pictures, 1 image per user)
-- ---------------------------------------------------------------------------
update storage.buckets
   set file_size_limit = 2097152,  -- 2 MiB
       allowed_mime_types = array['image/jpeg','image/png','image/webp']
 where id = 'avatars';

do $$
begin
  if exists (select 1 from storage.buckets where id = 'avatars') then
    -- Owner UPDATE: gate both OLD and NEW row to caller's own folder.
    drop policy if exists "avatars owner update" on storage.objects;
    create policy "avatars owner update"
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = (auth.uid())::text
      )
      with check (
        bucket_id = 'avatars'
        and (storage.foldername(name))[1] = (auth.uid())::text
      );
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- chat-attachments (images shared in chat threads)
-- ---------------------------------------------------------------------------
update storage.buckets
   set file_size_limit = 10485760,  -- 10 MiB
       allowed_mime_types = array['image/jpeg','image/png','image/webp']
 where id = 'chat-attachments';

do $$
begin
  if exists (select 1 from storage.buckets where id = 'chat-attachments') then
    drop policy if exists "chat-attachments owner update" on storage.objects;
    create policy "chat-attachments owner update"
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'chat-attachments'
        and (storage.foldername(name))[1] = (auth.uid())::text
      )
      with check (
        bucket_id = 'chat-attachments'
        and (storage.foldername(name))[1] = (auth.uid())::text
      );
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- repair-photos (engineer before/after photos for a service request)
-- ---------------------------------------------------------------------------
-- Client UploadValidator caps repair-photos at 10 MiB; we pin the bucket at
-- 15 MiB so a tighter client policy is the limiting factor and any later cap
-- bump on-device does not need a paired DB migration.
update storage.buckets
   set file_size_limit = 15728640,  -- 15 MiB
       allowed_mime_types = array['image/jpeg','image/png','image/webp']
 where id = 'repair-photos';

do $$
begin
  if exists (select 1 from storage.buckets where id = 'repair-photos') then
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
  end if;
end
$$;
