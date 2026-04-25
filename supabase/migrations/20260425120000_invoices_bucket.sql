-- Private 'invoices' Storage bucket. Files are HTML invoices uploaded by the
-- send_invoice edge function under service-role and surfaced to the buyer
-- via 30-day signed URLs only. RLS keeps random callers out of object reads.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('invoices', 'invoices', false, 5242880, ARRAY['text/html','application/pdf'])
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Service-role-only RLS on the underlying objects table; signed URLs bypass
-- this so buyers can fetch their own invoice over HTTPS.
DROP POLICY IF EXISTS "service role only on invoices objects" ON storage.objects;
CREATE POLICY "service role only on invoices objects"
  ON storage.objects
  FOR ALL
  TO service_role
  USING (bucket_id = 'invoices')
  WITH CHECK (bucket_id = 'invoices');
