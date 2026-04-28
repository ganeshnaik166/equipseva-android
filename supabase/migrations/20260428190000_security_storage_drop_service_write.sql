-- Storage RLS audit found `catalog_reference_images_service_write` granting
-- ALL operations on the catalog-reference-images bucket to anyone whose
-- bucket_id matches — no role qualifier, no auth check. The intent appears
-- to have been a service_role escape hatch, but service_role already
-- bypasses RLS in Supabase, so this policy is dead for service_role and
-- only opens write access to every authenticated user.
--
-- Drop it. The companion `catalog_reference_images_founder_write` policy
-- still covers founder-driven admin tooling, and service_role bypass
-- handles any backend-managed seeding.

DROP POLICY IF EXISTS catalog_reference_images_service_write
  ON storage.objects;
