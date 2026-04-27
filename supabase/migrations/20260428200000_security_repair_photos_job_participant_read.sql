-- repair-photos bucket today only lets the uploading user read back.
-- Workflow needs the hospital to upload issue_photos and the engineer
-- working that job to view them (and vice versa for after_photos /
-- before_photos). Without this, AsyncImage requests for photos uploaded
-- by the counterpart return 403 once the storage SDK tries to mint a
-- signed URL.
--
-- Approach: add a permissive SELECT policy on storage.objects that
-- allows any participant of a repair_jobs row whose photo arrays
-- contain this object's name. The existing owner-only insert/update/
-- delete policies stay — only read access expands.
--
-- Index the photo arrays with GIN so the EXISTS subquery on each
-- storage read stays bounded.

CREATE INDEX IF NOT EXISTS idx_repair_jobs_hospital_user_id
  ON public.repair_jobs (hospital_user_id);

CREATE INDEX IF NOT EXISTS idx_repair_jobs_issue_photos_gin
  ON public.repair_jobs USING GIN (issue_photos);

CREATE INDEX IF NOT EXISTS idx_repair_jobs_before_photos_gin
  ON public.repair_jobs USING GIN (before_photos);

CREATE INDEX IF NOT EXISTS idx_repair_jobs_after_photos_gin
  ON public.repair_jobs USING GIN (after_photos);

DROP POLICY IF EXISTS "repair-photos job participant read" ON storage.objects;

CREATE POLICY "repair-photos job participant read"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'repair-photos'
    AND EXISTS (
      SELECT 1
      FROM public.repair_jobs rj
      LEFT JOIN public.engineers e ON e.id = rj.engineer_id
      WHERE (
        rj.issue_photos  @> ARRAY[storage.objects.name]
        OR rj.before_photos @> ARRAY[storage.objects.name]
        OR rj.after_photos  @> ARRAY[storage.objects.name]
      )
      AND (
        rj.hospital_user_id = auth.uid()
        OR e.user_id = auth.uid()
      )
    )
  );
