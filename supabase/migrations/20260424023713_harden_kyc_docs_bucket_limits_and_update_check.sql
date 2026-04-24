-- Server-side hardening for the kyc-docs bucket. The client UploadValidator
-- already enforces a 15MB cap and a MIME allowlist (image/jpeg|png|webp +
-- application/pdf), but a caller bypassing the Android client could upload
-- 1 GB binaries or arbitrary content types because the bucket itself had
-- file_size_limit and allowed_mime_types both NULL. Pin them so the storage
-- layer rejects bad uploads even if the client lies. Already applied to
-- the live database via the Supabase MCP.

update storage.buckets
   set file_size_limit = 15728640,  -- 15 MiB, matches UploadValidator policy
       allowed_mime_types = array['image/jpeg','image/png','image/webp','application/pdf']
 where id = 'kyc-docs';

-- Tighten the owner UPDATE policy. The existing policy gates the OLD row by
-- (storage.foldername(name))[1] = auth.uid() but has no WITH_CHECK, so a
-- caller could in principle update the NEW row's name to point under another
-- user's folder. Mirror the predicate into WITH_CHECK so the new row stays
-- in the caller's folder.
drop policy if exists "kyc-docs owner update" on storage.objects;
create policy "kyc-docs owner update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'kyc-docs'
    and (storage.foldername(name))[1] = (auth.uid())::text
  )
  with check (
    bucket_id = 'kyc-docs'
    and (storage.foldername(name))[1] = (auth.uid())::text
  );
