-- Public `catalog-images` bucket for marketplace listing photos. AddListing
-- writes one or more images per listing under {supplier_org_id}/{file}, then
-- stores the public URLs in spare_parts.images[]. SELECT is open to anyone
-- (public bucket) so unauthenticated browsers can render product cards;
-- write policies are gated on the caller's supplier_org_id matching the
-- folder so a malicious supplier can't poison a competitor's gallery.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'catalog-images',
  'catalog-images',
  true,
  10485760,                                       -- 10 MiB, mirrors UploadValidator
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Helper: caller's supplier org id from profiles. SECURITY DEFINER so the
-- per-row RLS check on profiles doesn't recursively block the lookup.
CREATE OR REPLACE FUNCTION public.current_supplier_org_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT organization_id FROM public.profiles WHERE id = auth.uid()
$$;
GRANT EXECUTE ON FUNCTION public.current_supplier_org_id() TO authenticated;

-- INSERT: any authenticated user can upload, but only into their own
-- supplier-org folder. Supplier without a linked org is blocked (caller must
-- finish onboarding first).
DROP POLICY IF EXISTS catalog_images_insert ON storage.objects;
CREATE POLICY catalog_images_insert
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'catalog-images'
    AND public.current_supplier_org_id() IS NOT NULL
    AND (storage.foldername(name))[1] = public.current_supplier_org_id()::text
  );

-- UPDATE: same gate (in case the SDK calls upsert which routes through
-- UPDATE). Need both USING + WITH CHECK so a row can't be reassigned.
DROP POLICY IF EXISTS catalog_images_update ON storage.objects;
CREATE POLICY catalog_images_update
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'catalog-images'
    AND (storage.foldername(name))[1] = public.current_supplier_org_id()::text
  )
  WITH CHECK (
    bucket_id = 'catalog-images'
    AND (storage.foldername(name))[1] = public.current_supplier_org_id()::text
  );

-- DELETE: lets a supplier remove their own image (used by AddListing's
-- remove-image button before save).
DROP POLICY IF EXISTS catalog_images_delete ON storage.objects;
CREATE POLICY catalog_images_delete
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'catalog-images'
    AND (storage.foldername(name))[1] = public.current_supplier_org_id()::text
  );

-- SELECT: bucket is `public = true`, so the storage layer already serves
-- objects to anonymous HTTP. We still drop any stale gating policy to keep
-- behavior predictable and rely on the bucket flag.
DROP POLICY IF EXISTS catalog_images_select ON storage.objects;
