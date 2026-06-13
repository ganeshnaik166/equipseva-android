-- =====================================================================
-- Round 511 — NABH Vault auto-bundle bucket (v0.4 Phase 4 #5 backbone)
-- =====================================================================
--
-- Private storage bucket for ZIP exports produced by the
-- export_nabh_bundle edge function. ZIPs bundle index.html +
-- per-DSR HTML pages + a summary.json so a NABH auditor can browse
-- 24 months of service evidence from a single download.
--
-- Mirrors round 425 invoices bucket: 25 MB limit (HTML/JSON only —
-- per-DSR pages are tiny), service-role policy, signed URLs for caller
-- fetch.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('nabh-bundles', 'nabh-bundles', false, 26214400,
        ARRAY['application/zip','application/octet-stream'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "service role only on nabh-bundles objects" ON storage.objects;
CREATE POLICY "service role only on nabh-bundles objects"
  ON storage.objects
  FOR ALL
  TO service_role
  USING (bucket_id = 'nabh-bundles')
  WITH CHECK (bucket_id = 'nabh-bundles');

DO $$
BEGIN
  RAISE NOTICE 'round 511 nabh-bundles bucket created (25MB cap, service-role-only RLS)';
END;
$$;
