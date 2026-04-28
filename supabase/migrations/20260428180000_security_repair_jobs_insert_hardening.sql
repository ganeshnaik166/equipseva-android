-- repair_jobs INSERT was wide-open: WITH CHECK = (auth.uid() IS NOT NULL).
-- Any signed-in user could submit a job carrying any hospital_user_id /
-- hospital_org_id, including someone else's org, which leaks subsequent
-- engineer chat / bid traffic to the wrong tenant. Audit also flagged that
-- status / issue_photos length were unconstrained server-side.
--
-- Tighten the INSERT policy and add a defence-in-depth CHECK constraint
-- on photo count. repair_jobs is empty today so the constraint is safe.

DROP POLICY IF EXISTS "Hospitals can create repair jobs" ON public.repair_jobs;

CREATE POLICY "Hospitals can create repair jobs"
  ON public.repair_jobs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND hospital_user_id = auth.uid()
    -- New jobs must enter the open feed; status transitions happen via
    -- the existing UPDATE policy + accept_repair_bid RPC.
    AND status::text = 'requested'
    -- hospital_org_id is optional (some hospitals don't have an org row
    -- yet) but when provided must be the org the caller belongs to.
    AND (
      hospital_org_id IS NULL
      OR hospital_org_id = (
        SELECT p.organization_id
        FROM public.profiles p
        WHERE p.id = auth.uid()
      )
    )
    AND (
      issue_photos IS NULL
      OR coalesce(array_length(issue_photos, 1), 0) <= 5
    )
  );

ALTER TABLE public.repair_jobs
  ADD CONSTRAINT repair_jobs_max_5_issue_photos
  CHECK (
    issue_photos IS NULL
    OR coalesce(array_length(issue_photos, 1), 0) <= 5
  );
