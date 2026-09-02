-- Round 3764 — decide_cost_revision() approves a revised quote by updating
-- repair_jobs.contracted_amount_rupees, but never touches the sibling
-- repair_job_escrow row's amount_rupees. Found by hand while on-device
-- verifying round3762 (the enum-literal fix): bid ₹2,500 → engineer
-- proposed revision to ₹3,500 → hospital approved → job detail still
-- showed "Pay ₹2,500 to escrow" for the *unpaid* escrow row.
--
-- Why this is a real financial-integrity bug, not just a stale-copy one:
--   * compute_repair_job_commission_on_complete() (round #, v2 spec)
--     computes repair_jobs.engineer_payout as 93% of contracted_amount_
--     rupees — correctly picks up the revised ₹3,500 → payout ₹3,255.
--   * enqueue_engineer_payout_on_escrow_release() (round422) enqueues
--     that SAME repair_jobs.engineer_payout into engineer_payouts on
--     escrow release — it does NOT re-derive from escrow.amount_rupees.
--   * create-repair-job-payment-order (edge fn) charges the hospital
--     escrow.amount_rupees via Razorpay — the stale PRE-revision amount.
-- Net effect: hospital pays ₹2,500, platform later wires the engineer
-- ₹3,255 — a ₹755 shortfall the founder eats on every approved
-- upward revision, silently, with no error anywhere in the pipeline.
--
-- Fix, scoped to the case that's actually safe to auto-correct:
--   * escrow.status = 'pending' (bid accepted, hospital hasn't paid
--     yet — the exact state my on-device test job was in, and the
--     common case since Revise-quote only unlocks at En route/In
--     progress, routinely before payment) → sync amount_rupees to the
--     revised amount. No money has moved; nothing to reconcile.
--   * escrow.status IN ('held','in_dispute','released','refunded',
--     'cancelled') → money has already moved (or the window's closed).
--     Silently approving here would recreate the exact mismatch this
--     migration exists to close, just via a different door. Fail
--     closed: block the approval with a clear error instead, same
--     defensive posture as round465's "cannot decide after completed"
--     guard already in this function. A late revision on an already-
--     funded job needs a supplemental-payment flow this migration does
--     NOT attempt to build — out of scope for tonight's fix, flagged
--     as a follow-up.
--
-- Function body otherwise byte-identical to round3762.
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
  v_escrow   public.repair_job_escrow%ROWTYPE;
  v_kind     text;
  v_title    text;
  v_body     text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Sign in required' USING ERRCODE = '42501';
  END IF;

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

  IF v_job.status::text = 'completed' THEN
    RAISE EXCEPTION 'Cost revisions cannot be decided after the job is completed' USING ERRCODE = '22023';
  END IF;

  -- Round 3764: lock the escrow row (if any) before deciding so an
  -- approval can safely sync it, or refuse before writing anything if
  -- funds have already moved.
  SELECT * INTO v_escrow
    FROM public.repair_job_escrow
   WHERE repair_job_id = v_revision.repair_job_id
   FOR UPDATE;

  IF p_approve AND FOUND AND v_escrow.status <> 'pending' THEN
    RAISE EXCEPTION 'Cannot approve — escrow is already % for this job; a revision after pay-in needs a supplemental payment (contact support)', v_escrow.status
      USING ERRCODE = '22023';
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

    -- Round 3764: keep the not-yet-paid escrow row in sync with the
    -- new contract so the hospital is charged (and the payout math
    -- upstream, which already reads contracted_amount_rupees, agrees
    -- with) the revised amount, not the stale pre-revision bid.
    IF v_escrow.id IS NOT NULL THEN
      UPDATE public.repair_job_escrow
         SET amount_rupees = v_revision.revised_amount_rupees,
             updated_at = now()
       WHERE id = v_escrow.id;
    END IF;

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

COMMENT ON FUNCTION public.decide_cost_revision IS
  'Round 3764 (fixed from round3762) — on approval, syncs the still-unpaid escrow row''s amount_rupees to the revised contracted amount so the hospital is charged (and the payout math agrees with) the new figure, not the stale pre-revision bid. Refuses the approval outright if escrow has already moved past pending (held/released/refunded/in_dispute/cancelled) rather than silently create a ledger mismatch.';

COMMIT;
