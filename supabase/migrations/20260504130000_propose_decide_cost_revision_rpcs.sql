-- Two SECURITY DEFINER RPCs that drive the cost-revision lifecycle.
-- Both notify the counterparty via public.notifications so the
-- existing notifications_dispatch_push trigger fans out to FCM.
--
-- propose_cost_revision: engineer-only, only on a job they're
-- assigned to + currently in en_route/in_progress. Caps total
-- proposals per job at 3 (across statuses) to prevent harassment.
--
-- decide_cost_revision: hospital-only. On approve, overwrites the
-- repair_jobs.contracted_amount_rupees (allowed because this RPC is
-- definer-owned and the column-guard bypasses session_user='postgres').

CREATE OR REPLACE FUNCTION public.propose_cost_revision(
  p_job_id uuid,
  p_revised_amount numeric,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_job repair_jobs%ROWTYPE;
  v_engineer_user_id uuid;
  v_existing_count int;
  v_revision public.repair_job_cost_revisions%ROWTYPE;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Sign-in required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_job_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Job not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_job.engineer_id IS NULL THEN
    RAISE EXCEPTION 'Job has no assigned engineer' USING ERRCODE = '22023';
  END IF;

  -- Caller must be the assigned engineer (resolved via engineers.user_id).
  SELECT user_id INTO v_engineer_user_id FROM public.engineers WHERE id = v_job.engineer_id;
  IF v_engineer_user_id IS DISTINCT FROM v_caller THEN
    RAISE EXCEPTION 'Only the assigned engineer can propose a revision' USING ERRCODE = '42501';
  END IF;

  IF v_job.status::text NOT IN ('en_route', 'in_progress') THEN
    RAISE EXCEPTION
      'Revisions can only be proposed while the engineer is en-route or working (status=%)',
      v_job.status
      USING ERRCODE = '22023';
  END IF;

  IF v_job.contracted_amount_rupees IS NULL THEN
    RAISE EXCEPTION 'Job has no contracted amount' USING ERRCODE = '22023';
  END IF;

  IF p_revised_amount <= v_job.contracted_amount_rupees THEN
    RAISE EXCEPTION 'Revised amount must exceed current contracted amount'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(coalesce(p_reason, '')) NOT BETWEEN 50 AND 500 THEN
    RAISE EXCEPTION 'Reason must be 50-500 characters' USING ERRCODE = '22023';
  END IF;

  -- Cap total proposals per job at 3 to prevent harassment loops.
  SELECT count(*) INTO v_existing_count
    FROM public.repair_job_cost_revisions
   WHERE repair_job_id = p_job_id;

  IF v_existing_count >= 3 THEN
    RAISE EXCEPTION 'Maximum 3 cost revisions per job reached' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.repair_job_cost_revisions (
    repair_job_id,
    engineer_user_id,
    original_amount_rupees,
    revised_amount_rupees,
    reason,
    status
  ) VALUES (
    p_job_id,
    v_caller,
    v_job.contracted_amount_rupees,
    p_revised_amount,
    p_reason,
    'proposed'
  )
  RETURNING * INTO v_revision;

  -- Notify the hospital so the next-step push deep-links to the job
  -- detail screen where the CostRevisionBanner waits.
  INSERT INTO public.notifications (user_id, kind, title, body, data)
  VALUES (
    v_job.hospital_user_id,
    'cost_revision_proposed',
    'Engineer requested a revised quote',
    concat(
      'Original ₹', to_char(v_job.contracted_amount_rupees, 'FM999G999G999D00'),
      ' → revised ₹', to_char(p_revised_amount, 'FM999G999G999D00'),
      '. Tap to review.'
    ),
    jsonb_build_object(
      'repair_job_id', p_job_id,
      'revision_id',   v_revision.id,
      'original',      v_job.contracted_amount_rupees,
      'revised',       p_revised_amount
    )
  );

  RETURN to_jsonb(v_revision);
END;
$$;

ALTER FUNCTION public.propose_cost_revision(uuid, numeric, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.propose_cost_revision(uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.propose_cost_revision(uuid, numeric, text) TO authenticated;

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
