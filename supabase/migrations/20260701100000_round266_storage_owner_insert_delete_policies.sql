-- Round 266 — fill in missing storage.objects policies for kyc-docs
-- and chat-attachments so a fresh deploy from migrations alone has
-- the same gate the live Supabase project picked up implicitly when
-- the buckets were first created via dashboard.
--
-- State on main before this PR:
--   • avatars            — SELECT/INSERT/UPDATE/DELETE policies (PR #143)
--   • repair-photos      — SELECT/INSERT/UPDATE/DELETE policies (PR #100)
--   • kyc-docs           — SELECT (PR #146) + UPDATE (PR #140); no INSERT, no DELETE
--   • chat-attachments   — UPDATE only (PR #144); no SELECT, no INSERT, no DELETE
--
-- PostgreSQL RLS default is deny-all when no matching policy exists.
-- Production works today because the dashboard auto-created default
-- "owner only" insert policies when the buckets were provisioned, but
-- those policies don't appear in source-controlled migrations — a
-- fresh project rebuilt from `supabase db reset` would have no INSERT
-- gate and the engineer KYC + chat-attachment flows would 403.
--
-- Mirror the repair-photos / avatars shape: owner-folder gate on the
-- first path segment matching auth.uid(). kyc-docs DELETE also allows
-- founder via is_founder() so the admin queue can clean up tampered /
-- revoked documents during review.
--
-- All policies guarded by DROP ... IF EXISTS so re-applying this
-- migration on a project that already has the dashboard-created
-- versions is a clean swap, not a duplicate-policy error.

-- ---------------------------------------------------------------------
-- kyc-docs
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'kyc-docs') THEN
    DROP POLICY IF EXISTS "kyc-docs owner insert" ON storage.objects;
    CREATE POLICY "kyc-docs owner insert"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'kyc-docs'
        AND (storage.foldername(name))[1] = (auth.uid())::text
      );

    DROP POLICY IF EXISTS "kyc-docs owner delete" ON storage.objects;
    CREATE POLICY "kyc-docs owner delete"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'kyc-docs'
        AND (
          (storage.foldername(name))[1] = (auth.uid())::text
          OR public.is_founder()
        )
      );
  END IF;
END
$$;

-- ---------------------------------------------------------------------
-- chat-attachments
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'chat-attachments') THEN
    -- SELECT: signed-in users can read their own folder. Cross-user
    -- chat reads should happen via signed URLs minted server-side
    -- (storage.createSignedUrl), not via this policy.
    DROP POLICY IF EXISTS "chat-attachments owner select" ON storage.objects;
    CREATE POLICY "chat-attachments owner select"
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (
        bucket_id = 'chat-attachments'
        AND (storage.foldername(name))[1] = (auth.uid())::text
      );

    DROP POLICY IF EXISTS "chat-attachments owner insert" ON storage.objects;
    CREATE POLICY "chat-attachments owner insert"
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'chat-attachments'
        AND (storage.foldername(name))[1] = (auth.uid())::text
      );

    DROP POLICY IF EXISTS "chat-attachments owner delete" ON storage.objects;
    CREATE POLICY "chat-attachments owner delete"
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'chat-attachments'
        AND (storage.foldername(name))[1] = (auth.uid())::text
      );
  END IF;
END
$$;
