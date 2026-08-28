-- Round 3762 — fix decide_cost_revision invalid enum literal (breaks ALL
-- cost-revision approve/reject decisions).
--
-- Confirmed live on THIS database's current function body (round465,
-- 20260721100000_round465_tamper_lockdown.sql, lines 199-293):
--   SELECT * INTO v_revision
--     FROM public.repair_job_cost_revisions
--    WHERE id = p_revision_id AND status = 'pending'
-- `status` is `public.repair_cost_revision_status`
-- (20260504120000_repair_job_cost_revisions_table.sql), an ENUM with labels
-- ONLY proposed / approved / rejected / expired — there is no 'pending'
-- label. Comparing the enum column to the unknown text literal 'pending'
-- forces a coercion via enum_in() and raises 22P02 "invalid input value for
-- enum repair_cost_revision_status: \"pending\"" on EVERY call, before any
-- row is examined. So every hospital Approve/Reject of an engineer's revised
-- quote (CostRevisionRepository.decide -> rpc decide_cost_revision) fails
-- 100% of the time. Same bug class as round3760's
-- length(equipment_category) enum/text mismatch, found in the same audit
-- pass.
--
-- The correct "awaiting decision" label is 'proposed' — it's the table's own
-- DEFAULT (20260504120000) and the partial unique index
-- one_pending_revision_per_job keys on status = 'proposed', confirming
-- 'proposed' (not 'pending') is the intended awaiting-decision state.
--
-- Fix: CREATE OR REPLACE with the single literal corrected to 'proposed';
-- function body otherwise byte-identical to round465. No client change
-- needed (CostRevisionRepository just calls the RPC by id). Transactional
-- (fails safe — a bad run rolls back, live function intact).
BEGIN;

CREATE OR REPLACE FUNCTION public.decide_cost_revision(
  p_revision_id uuid,
  p_approve boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller   uuid := auth.uid();
  v_revision public.repair_job_cost_revisions%ROWTYPE;
  v_job      public.repair_jobs%ROWTYPE;
  v_kind     text;
  v_title    text;
  v_body     text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Sign in required' USING ERRCODE = '42501';
  END IF;

  -- Round 3762: was `status = 'pending'` (not a valid enum label -> 22P02 on
  -- every call). 'proposed' is the awaiting-decision state.
  SELECT * INTO v_revision
    FROM public.repair_job_cost_revisions
   WHERE id = p_revision_id AND status = 'proposed'
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cost revision not found or already decided' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = v_revision.repair_job_id FOR UPDATE;
  IF v_job.hospital_user_id IS DISTINCT FROM v_caller THEN
    RAISE EXCEPTION 'Only the hospital owner can decide' USING ERRCODE = '42501';
  END IF;

  -- Round 465: cost revisions on completed jobs would silently bypass
  -- the compute-on-complete trigger (it only fires on the status
  -- transition into completed). Result: contracted_amount changes but
  -- engineer_payout / platform_commission stay at the OLD amounts,
  -- causing ledger drift between the contract and the payout.
  IF v_job.status::text = 'completed' THEN
    RAISE EXCEPTION 'Cost revisions cannot be decided after the job is completed' USING ERRCODE = '22023';
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

COMMIT;
