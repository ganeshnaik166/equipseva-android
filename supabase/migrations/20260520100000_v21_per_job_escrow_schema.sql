-- v2.1 PR-D4: per-job escrow + auto-release schema (T1.1 in the
-- anti-disintermediation strategy memo — the actual hard-enforcement
-- moat). Hospital pays into platform wallet at quote-accept, funds
-- sit in escrow, released to engineer 48h after job completion + no
-- dispute (or early on hospital confirm). Engineer must use the app
-- to get paid — the off-platform cash deal is what we're stopping.
--
-- This PR ships SCHEMA + state-machine RPCs + auto-release cron
-- helper only. The Razorpay pay-in edge function and Android UI land
-- in PR-D5 / PR-D6. To keep this mergeable today the pay-in path is
-- represented by `mark_repair_job_escrow_paid` (admin / system RPC)
-- — PR-D5 will swap the caller from "admin manual" to "Razorpay
-- verification webhook".
--
-- State machine:
--   pending     — escrow row created at bid-accept, awaiting pay-in
--   held        — funds in platform wallet, work can proceed
--   in_dispute  — hospital opened dispute within 48h post-completion
--   released    — funds queued for engineer payout (auto or hospital
--                 early-confirm). Actual UPI / IMPS settlement is a
--                 separate outbox the founder runs out-of-band today.
--   refunded    — admin issued a refund (cancelled / dispute won)
--   cancelled   — escrow voided before pay-in (job cancelled / bid
--                 unaccepted before hospital paid)
--
-- Core rule the strategy memo encoded: "Engineer must use the app to
-- get paid, period." The trigger on accept_repair_bid + the
-- repair_job_escrow row are the gate.

-- ---------------------------------------------------------------------
-- 1. repair_job_escrow — one row per accepted bid
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.repair_job_escrow (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id            uuid NOT NULL UNIQUE
                             REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  hospital_user_id         uuid NOT NULL REFERENCES auth.users(id),
  engineer_user_id         uuid NOT NULL REFERENCES auth.users(id),
  amount_rupees            numeric(12,2) NOT NULL CHECK (amount_rupees > 0),
  status                   text NOT NULL DEFAULT 'pending'
                             CHECK (status IN (
                               'pending','held','in_dispute',
                               'released','refunded','cancelled'
                             )),
  -- Razorpay binding (filled by PR-D5 edge fn).
  razorpay_order_id        text,
  razorpay_payment_id      text,
  paid_at                  timestamptz,
  -- Auto-release scheduling.
  scheduled_release_at     timestamptz,
  released_at              timestamptz,
  refunded_at              timestamptz,
  -- Dispute trail.
  dispute_opened_at        timestamptz,
  dispute_reason           text,
  dispute_resolved_at      timestamptz,
  dispute_resolution       text,                  -- 'release' | 'refund' | NULL
  dispute_resolved_by      uuid REFERENCES auth.users(id),
  -- Audit metadata.
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_status
  ON public.repair_job_escrow (status);
CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_release_due
  ON public.repair_job_escrow (scheduled_release_at)
  WHERE status = 'held';
CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_hospital
  ON public.repair_job_escrow (hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_engineer
  ON public.repair_job_escrow (engineer_user_id);

-- ---------------------------------------------------------------------
-- 2. repair_job_escrow_events — append-only audit
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.repair_job_escrow_events (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escrow_id    uuid NOT NULL
                 REFERENCES public.repair_job_escrow(id) ON DELETE CASCADE,
  event_kind   text NOT NULL
                 CHECK (event_kind IN (
                   'created','paid','release_scheduled','released',
                   'refunded','disputed','dispute_resolved','cancelled'
                 )),
  actor_user_id uuid REFERENCES auth.users(id),
  payload       jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_repair_job_escrow_events_escrow
  ON public.repair_job_escrow_events (escrow_id, occurred_at DESC);

-- ---------------------------------------------------------------------
-- 3. RLS — participants can SELECT, all writes go through SECDEF RPCs
-- ---------------------------------------------------------------------
ALTER TABLE public.repair_job_escrow         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repair_job_escrow_events  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rj_escrow_select_party        ON public.repair_job_escrow;
DROP POLICY IF EXISTS rj_escrow_select_admin        ON public.repair_job_escrow;
DROP POLICY IF EXISTS rj_escrow_events_select_party ON public.repair_job_escrow_events;

CREATE POLICY rj_escrow_select_party
  ON public.repair_job_escrow FOR SELECT
  USING (auth.uid() IN (hospital_user_id, engineer_user_id));

CREATE POLICY rj_escrow_select_admin
  ON public.repair_job_escrow FOR SELECT
  USING (public.is_admin(auth.uid()) OR public.is_founder());

CREATE POLICY rj_escrow_events_select_party
  ON public.repair_job_escrow_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1
        FROM public.repair_job_escrow e
       WHERE e.id = repair_job_escrow_events.escrow_id
         AND (
           auth.uid() IN (e.hospital_user_id, e.engineer_user_id)
           OR public.is_admin(auth.uid())
           OR public.is_founder()
         )
    )
  );

GRANT SELECT ON public.repair_job_escrow         TO authenticated;
GRANT SELECT ON public.repair_job_escrow_events  TO authenticated;

-- ---------------------------------------------------------------------
-- 4. updated_at touch trigger
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.repair_job_escrow_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS repair_job_escrow_touch_updated_at_trg
  ON public.repair_job_escrow;
CREATE TRIGGER repair_job_escrow_touch_updated_at_trg
  BEFORE UPDATE ON public.repair_job_escrow
  FOR EACH ROW EXECUTE FUNCTION public.repair_job_escrow_touch_updated_at();

-- ---------------------------------------------------------------------
-- 5. accept_repair_bid extension — create the pending escrow row.
--    Owner stays postgres so the column-guard bypass keeps working.
--    Mirror of PR-C1 trigger pattern: insert row + emit event.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_repair_bid(p_bid_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_bid record;
  v_engineer_id uuid;
  v_job jsonb;
  v_escrow_id uuid;
BEGIN
  SELECT
      b.id,
      b.repair_job_id,
      b.engineer_user_id,
      b.amount_rupees,
      b.status,
      rj.hospital_user_id,
      rj.status AS job_status
    INTO v_bid
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
   WHERE b.id = p_bid_id
   FOR UPDATE OF rj;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bid not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_bid.hospital_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the hospital owner can accept bids' USING ERRCODE = '42501';
  END IF;
  IF v_bid.status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending bids can be accepted' USING ERRCODE = '22023';
  END IF;
  IF v_bid.job_status <> 'requested' THEN
    RAISE EXCEPTION 'Job is no longer open for bids' USING ERRCODE = '22023';
  END IF;

  SELECT e.id INTO v_engineer_id
    FROM public.engineers e
   WHERE e.user_id = v_bid.engineer_user_id
   LIMIT 1;
  IF v_engineer_id IS NULL THEN
    RAISE EXCEPTION 'Engineer profile not found for bid' USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.repair_job_bids
     SET status = 'accepted', updated_at = now()
   WHERE id = p_bid_id;

  UPDATE public.repair_job_bids
     SET status = 'rejected', updated_at = now()
   WHERE repair_job_id = v_bid.repair_job_id
     AND id <> p_bid_id
     AND status = 'pending';

  UPDATE public.repair_jobs
     SET engineer_id = v_engineer_id,
         status = 'assigned',
         contracted_amount_rupees = v_bid.amount_rupees,
         updated_at = now()
   WHERE id = v_bid.repair_job_id
   RETURNING to_jsonb(repair_jobs.*) INTO v_job;

  -- PR-D4: escrow row at quote-accept. Idempotent — if a previous
  -- acceptance already created the row (re-accept after admin reset)
  -- we leave it untouched. Pay-in flips status to 'held' later.
  INSERT INTO public.repair_job_escrow (
    repair_job_id, hospital_user_id, engineer_user_id, amount_rupees, status
  )
  VALUES (
    v_bid.repair_job_id, v_bid.hospital_user_id, v_bid.engineer_user_id,
    v_bid.amount_rupees, 'pending'
  )
  ON CONFLICT (repair_job_id) DO NOTHING
  RETURNING id INTO v_escrow_id;

  IF v_escrow_id IS NOT NULL THEN
    INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
    VALUES (v_escrow_id, 'created', v_bid.hospital_user_id,
            jsonb_build_object('amount_rupees', v_bid.amount_rupees));
  END IF;

  RETURN v_job;
END;
$$;
ALTER FUNCTION public.accept_repair_bid(uuid) OWNER TO postgres;

-- ---------------------------------------------------------------------
-- 6. mark_repair_job_escrow_paid — flips pending→held. Today admin /
--    PR-D5's Razorpay verify edge fn calls this; the JWT context is
--    service-role for both, so we gate on is_admin OR is_founder OR
--    a service-role marker. For now: admin/founder only — PR-D5
--    drops the gate when called from the verify edge fn (which uses
--    the service-role key directly and bypasses RLS anyway).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_repair_job_escrow_paid(
  p_repair_job_id uuid,
  p_razorpay_order_id text,
  p_razorpay_payment_id text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow_id uuid;
  v_status text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  SELECT id, status INTO v_escrow_id, v_status
    FROM public.repair_job_escrow
   WHERE repair_job_id = p_repair_job_id
   FOR UPDATE;
  IF v_escrow_id IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_status NOT IN ('pending') THEN
    RAISE EXCEPTION 'escrow not in pending state (got %)', v_status USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_escrow
     SET status              = 'held',
         razorpay_order_id   = p_razorpay_order_id,
         razorpay_payment_id = p_razorpay_payment_id,
         paid_at             = now()
   WHERE id = v_escrow_id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow_id, 'paid', v_caller,
          jsonb_build_object(
            'razorpay_order_id', p_razorpay_order_id,
            'razorpay_payment_id', p_razorpay_payment_id
          ));

  RETURN v_escrow_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_repair_job_escrow_paid(uuid, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.mark_repair_job_escrow_paid(uuid, text, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 7. Trigger on completion: schedule auto-release 48h out
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.schedule_repair_job_escrow_release_on_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_escrow_id uuid;
  v_status    text;
  v_release_at timestamptz;
BEGIN
  IF NEW.status::text <> 'completed' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;

  SELECT id, status INTO v_escrow_id, v_status
    FROM public.repair_job_escrow
   WHERE repair_job_id = NEW.id
   FOR UPDATE;
  IF v_escrow_id IS NULL THEN RETURN NEW; END IF;
  IF v_status <> 'held' THEN RETURN NEW; END IF;

  v_release_at := COALESCE(NEW.completed_at, now()) + interval '48 hours';
  UPDATE public.repair_job_escrow
     SET scheduled_release_at = v_release_at
   WHERE id = v_escrow_id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, payload)
  VALUES (v_escrow_id, 'release_scheduled',
          jsonb_build_object('scheduled_release_at', v_release_at));

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS schedule_repair_job_escrow_release_on_complete_trg
  ON public.repair_jobs;
CREATE TRIGGER schedule_repair_job_escrow_release_on_complete_trg
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.status::text = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.schedule_repair_job_escrow_release_on_complete();

-- ---------------------------------------------------------------------
-- 8. confirm_repair_job_escrow — hospital releases early
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.confirm_repair_job_escrow(
  p_repair_job_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
  v_job_status text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_escrow
    FROM public.repair_job_escrow
   WHERE repair_job_id = p_repair_job_id
   FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_escrow.hospital_user_id THEN
    RAISE EXCEPTION 'only hospital can confirm release' USING ERRCODE = '42501';
  END IF;
  IF v_escrow.status <> 'held' THEN
    RAISE EXCEPTION 'escrow not in held state (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  SELECT status::text INTO v_job_status
    FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF v_job_status <> 'completed' THEN
    RAISE EXCEPTION 'job must be completed before release' USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_escrow
     SET status = 'released',
         released_at = now(),
         scheduled_release_at = COALESCE(scheduled_release_at, now())
   WHERE id = v_escrow.id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow.id, 'released', v_caller,
          jsonb_build_object('reason','hospital_confirmed_early'));

  RETURN v_escrow.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.confirm_repair_job_escrow(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.confirm_repair_job_escrow(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- 9. dispute_repair_job_escrow — hospital opens dispute (within 48h
--    post-completion, status held)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispute_repair_job_escrow(
  p_repair_job_id uuid,
  p_reason        text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
  v_completed_at timestamptz;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF coalesce(length(trim(p_reason)),0) < 10 THEN
    RAISE EXCEPTION 'dispute reason too short (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow
    FROM public.repair_job_escrow
   WHERE repair_job_id = p_repair_job_id
   FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_escrow.hospital_user_id THEN
    RAISE EXCEPTION 'only hospital can open dispute' USING ERRCODE = '42501';
  END IF;
  IF v_escrow.status <> 'held' THEN
    RAISE EXCEPTION 'escrow not in held state (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  SELECT completed_at INTO v_completed_at
    FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF v_completed_at IS NULL THEN
    RAISE EXCEPTION 'job not completed' USING ERRCODE = '22023';
  END IF;
  IF now() > v_completed_at + interval '48 hours' THEN
    RAISE EXCEPTION 'dispute window closed' USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_escrow
     SET status = 'in_dispute',
         dispute_opened_at = now(),
         dispute_reason = p_reason
   WHERE id = v_escrow.id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow.id, 'disputed', v_caller,
          jsonb_build_object('reason', p_reason));

  RETURN v_escrow.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dispute_repair_job_escrow(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.dispute_repair_job_escrow(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 10. admin_resolve_escrow_dispute — admin/founder picks side
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_resolve_escrow_dispute(
  p_escrow_id uuid,
  p_outcome   text -- 'release' | 'refund'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_outcome NOT IN ('release','refund') THEN
    RAISE EXCEPTION 'outcome must be release or refund' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow FROM public.repair_job_escrow
   WHERE id = p_escrow_id FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_escrow.status <> 'in_dispute' THEN
    RAISE EXCEPTION 'escrow not in dispute (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  IF p_outcome = 'release' THEN
    UPDATE public.repair_job_escrow
       SET status = 'released',
           released_at = now(),
           dispute_resolved_at = now(),
           dispute_resolution = 'release',
           dispute_resolved_by = v_caller
     WHERE id = v_escrow.id;
  ELSE
    UPDATE public.repair_job_escrow
       SET status = 'refunded',
           refunded_at = now(),
           dispute_resolved_at = now(),
           dispute_resolution = 'refund',
           dispute_resolved_by = v_caller
     WHERE id = v_escrow.id;
  END IF;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow.id, 'dispute_resolved', v_caller,
          jsonb_build_object('outcome', p_outcome));

  RETURN v_escrow.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.admin_resolve_escrow_dispute(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_resolve_escrow_dispute(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 11. process_due_repair_job_escrow_releases — cron helper
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_due_repair_job_escrow_releases()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  r record;
BEGIN
  FOR r IN
    SELECT id
      FROM public.repair_job_escrow
     WHERE status = 'held'
       AND scheduled_release_at IS NOT NULL
       AND scheduled_release_at <= now()
       AND dispute_opened_at IS NULL
     FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.repair_job_escrow
       SET status = 'released',
           released_at = now()
     WHERE id = r.id;

    INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, payload)
    VALUES (r.id, 'released', jsonb_build_object('reason','auto_48h_window'));

    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.process_due_repair_job_escrow_releases() FROM PUBLIC;
-- Cron callers run as service-role (bypasses RLS); humans should not call this.

-- ---------------------------------------------------------------------
-- 12. get_repair_job_escrow — participant read for the UI
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_repair_job_escrow(p_repair_job_id uuid)
RETURNS TABLE (
  id                   uuid,
  status               text,
  amount_rupees        numeric,
  paid_at              timestamptz,
  scheduled_release_at timestamptz,
  released_at          timestamptz,
  refunded_at          timestamptz,
  dispute_opened_at    timestamptz,
  dispute_reason       text,
  dispute_resolution   text,
  is_in_dispute_window boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_completed_at timestamptz;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT rj.completed_at INTO v_completed_at
    FROM public.repair_jobs rj WHERE rj.id = p_repair_job_id;

  RETURN QUERY
  SELECT
      e.id,
      e.status,
      e.amount_rupees,
      e.paid_at,
      e.scheduled_release_at,
      e.released_at,
      e.refunded_at,
      e.dispute_opened_at,
      e.dispute_reason,
      e.dispute_resolution,
      (
        e.status = 'held' AND v_completed_at IS NOT NULL
        AND now() <= v_completed_at + interval '48 hours'
      ) AS is_in_dispute_window
    FROM public.repair_job_escrow e
   WHERE e.repair_job_id = p_repair_job_id
     AND (
       v_caller IN (e.hospital_user_id, e.engineer_user_id)
       OR public.is_admin(v_caller)
       OR public.is_founder()
     );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_repair_job_escrow(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_repair_job_escrow(uuid) TO authenticated;
