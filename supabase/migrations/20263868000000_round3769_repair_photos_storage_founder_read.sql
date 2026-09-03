-- Round 3769 — same discovery pass as round3766/3767/3768, one more
-- instance: storage.objects' "repair-photos job participant read" SELECT
-- policy has NO admin/founder bypass of any kind (not even the broken
-- is_admin() pattern — it simply never had one). Found while auditing
-- every storage.objects policy for the round3766 bug class (the other
-- storage policies either already used is_founder() correctly, or used
-- is_admin(auth.uid()) — the latter already fixed automatically by
-- round3766's function widening, since it's the same public.is_admin()
-- regardless of which schema's policy calls it; verified live:
-- storage.objects WHERE bucket_id='kyc-docs' now returns 61/61 for the
-- founder's simulated session, matching the unrestricted count).
--
-- repair-photos holds repair_jobs.issue_photos / before_photos /
-- after_photos — exactly the evidence a founder would need to
-- adjudicate a quality dispute or a parts-cost-outlier investigation
-- (list_parts_cost_outliers already flags these; there was previously
-- no way to actually SEE the photos without being the hospital or
-- assigned engineer on that specific job). Currently no confirmed
-- active founder-console page reads this bucket directly (so, unlike
-- round3766, this is a latent gap, not a proven-broken one) — fixed
-- anyway per this session's standing rule (round3763/3765): close
-- defensive gaps the moment they're found rather than leave them for
-- the next feature that needs them.
BEGIN;

DROP POLICY IF EXISTS "repair-photos job participant read" ON storage.objects;
CREATE POLICY "repair-photos job participant read" ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'repair-photos'
    AND (
      public.is_founder()
      OR EXISTS (
        SELECT 1
          FROM public.repair_jobs rj
          LEFT JOIN public.engineers e ON e.id = rj.engineer_id
         WHERE (
                 rj.issue_photos @> ARRAY[objects.name]
              OR rj.before_photos @> ARRAY[objects.name]
              OR rj.after_photos @> ARRAY[objects.name]
             )
           AND (rj.hospital_user_id = auth.uid() OR e.user_id = auth.uid())
           AND (
                 (storage.foldername(objects.name))[1] = (rj.hospital_user_id)::text
              OR (storage.foldername(objects.name))[1] = (e.user_id)::text
           )
      )
    )
  );

COMMIT;
