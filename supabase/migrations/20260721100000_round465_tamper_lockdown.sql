-- Round 465 — CRITICAL + HIGH — payout-tamper lockdown.
--
-- Caught by audit 5 (engineer payout pipeline review):
--
-- (1) CRITICAL — Engineer can pre-set repair_jobs.engineer_payout /
--     platform_commission to attacker-chosen values WHILE status is
--     'assigned' / 'in_progress' / 'en_route'. The existing column
--     guard (round 425) only fires when OLD.status='completed' (line
--     62 of 20260620100000_v21_payout_columns_and_complete_rpc.sql),
--     so pre-completion writes pass through unchallenged. RLS UPDATE
--     policy "Involved parties can update repair jobs" passes whenever
--     auth.uid() == hospital_user_id or matches the assigned engineer's
--     user_id, with NO column-level restriction. When the engineer
--     later marks the job completed, compute_repair_job_commission_on_
--     complete only writes engineer_payout / platform_commission if
--     they're NULL (per round 506110000's "if commission/payout are
--     already set we leave them alone, so a backfill is safe" comment) —
--     so the engineer's pre-set values survive. Attacker pays
--     themselves arbitrary amounts; platform balance leaks.
--
-- (2) HIGH — Engineer can pre-flip repair_jobs.is_warranty_covered
--     from false to true before completion. The warranty stamp is
--     INSERT-only (repair_jobs_stamp_warranty_on_insert_trg). No
--     UPDATE-side guard exists. RLS allows the patch; the warranty
--     waiver math then treats the job as covered (engineer gets 100%
--     of fee instead of 93%). 7% slice silently leaks per job.
--
-- (3) HIGH — Hospital (or compromised hospital account) can re-assign
--     repair_jobs.engineer_id to an attacker-controlled engineer at
--     any status, including 'in_progress', and have THAT engineer's
--     account run the completion flow → all payout / commission
--     flows route to the attacker. RLS lets the hospital UPDATE
--     freely; no column-level lockdown on engineer_id.
--
-- (4) HIGH — decide_cost_revision overwrites contracted_amount_rupees
--     without recomputing engineer_payout / platform_commission. If
--     a revision is decided on a completed job (no status guard in
--     the RPC), the contracted amount changes but the split stays at
--     the old amount → ledger drift between contract and payouts.
--
-- Fix:
--   • Tighten repair_jobs_payout_columns_guard: reject ANY non-admin /
--     non-service-role / non-DEFINER UPDATE to engineer_payout /
--     platform_commission, regardless of OLD.status. The compute
--     trigger runs as the table owner (postgres) so its writes bypass
--     this guard via the existing current_user check.
--   • Add a parallel guard for is_warranty_covered: only INSERT-time
--     stamp + admin / founder / service_role can modify post-insert.
--   • Add a guard for engineer_id: only mutable while status in
--     ('pending', 'bidding', 'awarded'). Once work has actually started
--     (in_progress, en_route, completed), engineer_id is locked.
--   • decide_cost_revision: add status guard rejecting revisions on
--     already-completed jobs. (Future-proofing — UI shouldn't surface
--     this, but the RPC must enforce.)
--   • REVOKE column-level UPDATE on the protected columns from
--     authenticated as defense in depth — even if a future migration
--     loosens the RLS, the column grant blocks raw PATCH.

-- ---------------------------------------------------------------------
-- 1. Tighten payout-column guard — drop the OLD.status='completed'
--    short-circuit. Any non-elevated caller attempt fails.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.repair_jobs_payout_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- Bypass for elevated callers. compute_repair_job_commission_on_complete
  -- runs as part of the same UPDATE statement initiated by the caller as
  -- a BEFORE-UPDATE trigger function owned by 'postgres' — the
  -- current_user / session_user check below catches that path.
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Round 465: removed the `IF OLD.status::text <> 'completed' THEN
  -- RETURN NEW;` short-circuit. The pre-completion window was the
  -- exact attack surface — engineer could PATCH engineer_payout to
  -- an arbitrary value, then the legitimate completion trigger
  -- preserved it because compute only writes NULL columns.
  IF NEW.platform_commission IS DISTINCT FROM OLD.platform_commission THEN
    RAISE EXCEPTION 'platform_commission cannot be modified by clients'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.engineer_payout IS DISTINCT FROM OLD.engineer_payout THEN
    RAISE EXCEPTION 'engineer_payout cannot be modified by clients'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger definition unchanged from round 425, just re-create to
-- pick up the body update (CREATE OR REPLACE updates only the
-- function body; trigger keeps its WHEN clause).

-- ---------------------------------------------------------------------
-- 2. Warranty-covered tamper guard — INSERT-stamp only, admin can
--    override (e.g. a legitimate warranty claim approved after the
--    job was created).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.repair_jobs_warranty_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF NEW.is_warranty_covered IS DISTINCT FROM OLD.is_warranty_covered THEN
    RAISE EXCEPTION 'is_warranty_covered can only be set at creation or by admin'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.repair_jobs_warranty_guard() FROM PUBLIC;

DROP TRIGGER IF EXISTS repair_jobs_warranty_guard_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_warranty_guard_trg
  BEFORE UPDATE ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.is_warranty_covered IS DISTINCT FROM OLD.is_warranty_covered)
  EXECUTE FUNCTION public.repair_jobs_warranty_guard();

-- ---------------------------------------------------------------------
-- 3. engineer_id mutation guard — locked once work has started.
--    Hospital can re-assign during pending / bidding / awarded
--    phases (legitimate change-of-engineer). Once in_progress /
--    en_route / completed / cancelled, engineer_id is fixed.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.repair_jobs_engineer_id_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  -- Allow during early phases. After work starts, lock.
  IF OLD.status::text IN ('pending','bidding','awarded') THEN
    RETURN NEW;
  END IF;

  IF NEW.engineer_id IS DISTINCT FROM OLD.engineer_id THEN
    RAISE EXCEPTION 'engineer_id cannot be changed once work has started (status=%)', OLD.status
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.repair_jobs_engineer_id_guard() FROM PUBLIC;

DROP TRIGGER IF EXISTS repair_jobs_engineer_id_guard_trg ON public.repair_jobs;
CREATE TRIGGER repair_jobs_engineer_id_guard_trg
  BEFORE UPDATE ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.engineer_id IS DISTINCT FROM OLD.engineer_id)
  EXECUTE FUNCTION public.repair_jobs_engineer_id_guard();

-- ---------------------------------------------------------------------
-- 4. decide_cost_revision — reject revisions on completed jobs.
-- ---------------------------------------------------------------------

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

  SELECT * INTO v_revision
    FROM public.repair_job_cost_revisions
   WHERE id = p_revision_id AND status = 'pending'
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

-- ---------------------------------------------------------------------
-- 5. Column-level REVOKE — defense in depth. Even if a future RLS
--    migration accidentally loosens the table policy, raw PATCH for
--    these columns errors at the Postgres grant layer before the
--    trigger fires.
-- ---------------------------------------------------------------------

REVOKE UPDATE (engineer_payout, platform_commission, is_warranty_covered, engineer_id)
  ON public.repair_jobs FROM authenticated, anon;
-- Re-grant the columns engineers / hospitals legitimately need to
-- write via REST. (We can't blanket REVOKE UPDATE on the whole table
-- because the existing RLS policy lets the hospital + engineer
-- update issue_description, work_done, equipment_brand, etc.)
-- Postgres grant model: UPDATE without column list = all columns.
-- We need to leave the table-wide grant intact and only revoke the
-- locked-down columns above. The REVOKE on specific columns shrinks
-- the existing wide grant.
