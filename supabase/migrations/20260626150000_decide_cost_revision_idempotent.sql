-- Round 234 — make decide_cost_revision idempotent on the same outcome.
--
-- The previous behaviour raised 22023 "Revision is no longer pending"
-- whenever the hospital tapped Approve / Reject twice (or the client
-- retried after a network blip that actually succeeded server-side).
-- The first call had already done its job; the second showed the user
-- a confusing failure toast.
--
-- New behaviour: when the revision is in a terminal state, compare the
-- requested decision with the recorded outcome. Same decision → return
-- the existing row silently. Different decision (e.g. Approve after a
-- prior Reject) still raises so we don't quietly overwrite history.
--
-- The notification INSERT is wrapped to skip on the idempotent re-entry
-- so we don't double-notify the engineer.

CREATE OR REPLACE FUNCTION public.decide_cost_revision(
  p_revision_id uuid,
  p_approve boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_revision public.repair_job_cost_revisions%ROWTYPE;
  v_job repair_jobs%ROWTYPE;
  v_kind text;
  v_title text;
  v_body text;
  v_expected_status text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Sign-in required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_revision
    FROM public.repair_job_cost_revisions
   WHERE id = p_revision_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Revision not found' USING ERRCODE = 'P0002';
  END IF;

  -- Idempotent re-entry: if the row is already in the terminal state
  -- the caller is requesting, return it without changes. Different
  -- terminal state → preserve the original error so we never silently
  -- flip Approved↔Rejected.
  v_expected_status := CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END;
  IF v_revision.status = v_expected_status THEN
    RETURN to_jsonb(v_revision);
  END IF;
  IF v_revision.status <> 'proposed' THEN
    RAISE EXCEPTION 'Revision is no longer pending (status=%)', v_revision.status
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = v_revision.repair_job_id FOR UPDATE;
  IF v_job.hospital_user_id IS DISTINCT FROM v_caller THEN
    RAISE EXCEPTION 'Only the hospital owner can decide' USING ERRCODE = '42501';
  END IF;

  IF p_approve THEN
    UPDATE public.repair_job_cost_revisions
       SET status = 'approved',
           decided_at = now(),
           decision_by = v_caller
     WHERE id = p_revision_id
    RETURNING * INTO v_revision;

    UPDATE public.repair_jobs
       SET contracted_amount_rupees = v_revision.revised_amount_rupees,
           updated_at = now()
     WHERE id = v_revision.repair_job_id;

    v_kind  := 'cost_revision_approved';
    v_title := 'Hospital approved your revised quote';
    v_body  := concat(
      'New contracted amount ₹',
      to_char(v_revision.revised_amount_rupees, 'FM999G999G999D00'),
      '. Carry on with the repair.'
    );
  ELSE
    UPDATE public.repair_job_cost_revisions
       SET status = 'rejected',
           decided_at = now(),
           decision_by = v_caller
     WHERE id = p_revision_id
    RETURNING * INTO v_revision;

    v_kind  := 'cost_revision_rejected';
    v_title := 'Hospital rejected your revised quote';
    v_body  := 'You can submit a new revision or proceed at the original contracted amount.';
  END IF;

  INSERT INTO public.notifications (user_id, kind, title, body, data)
  VALUES (
    v_revision.engineer_user_id,
    v_kind,
    v_title,
    v_body,
    jsonb_build_object(
      'repair_job_id', v_revision.repair_job_id,
      'revision_id',   v_revision.id
    )
  );

  RETURN to_jsonb(v_revision);
END;
$$;

ALTER FUNCTION public.decide_cost_revision(uuid, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.decide_cost_revision(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decide_cost_revision(uuid, boolean) TO authenticated;
