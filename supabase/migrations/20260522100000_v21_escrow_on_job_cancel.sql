-- v2.1 PR-D7: escrow side-effects on repair_job cancellation (T1.5
-- finalization). The `repair_jobs_status_transition_guard` from
-- 20260428260000 already blocks the most dangerous case — cancel
-- after check-in (in_progress → cancelled) requires admin/founder.
-- What's missing: when a cancellation is allowed (assigned →
-- cancelled, en_route → cancelled, requested → cancelled, or admin
-- cancelling later states), the escrow row needs to follow.
--
-- Mapping:
--   * escrow status 'pending'  (no money in)        → 'cancelled'
--   * escrow status 'held'     (money sat with us)  → 'in_dispute'
--                                                     auto-reason
--                                                     "job cancelled"
--                                                     so admin reviews
--                                                     refund amount.
--   * escrow status 'released' (already paid out)   → leave alone
--                                                     (admin can issue
--                                                     a manual refund
--                                                     out-of-band)
--   * escrow status 'in_dispute' / 'refunded' / 'cancelled' → no-op
--
-- Released-then-job-cancelled is rare (only happens if hospital
-- early-confirmed before realizing they wanted to cancel) — handled
-- by ops, not the trigger.
--
-- Strategy memo notes "Partial refund formula: hospital pays X% even
-- if cancelled to discourage collusion" — that's deferred to v2.2.
-- For now: full refund for pending, admin-reviewed for held.

CREATE OR REPLACE FUNCTION public.escrow_react_to_job_cancel()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_escrow record;
BEGIN
  IF NEW.status::text <> 'cancelled' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;

  SELECT id, status INTO v_escrow
    FROM public.repair_job_escrow
   WHERE repair_job_id = NEW.id
   FOR UPDATE;
  IF v_escrow IS NULL THEN RETURN NEW; END IF;

  IF v_escrow.status = 'pending' THEN
    UPDATE public.repair_job_escrow
       SET status = 'cancelled'
     WHERE id = v_escrow.id;
    INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, payload)
    VALUES (v_escrow.id, 'cancelled',
            jsonb_build_object('reason','job_cancelled_pre_payment'));
  ELSIF v_escrow.status = 'held' THEN
    UPDATE public.repair_job_escrow
       SET status = 'in_dispute',
           dispute_opened_at = now(),
           dispute_reason = 'job_cancelled_post_payment — admin to review refund'
     WHERE id = v_escrow.id;
    INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, payload)
    VALUES (v_escrow.id, 'disputed',
            jsonb_build_object('reason','job_cancelled_post_payment'));
  END IF;
  -- released / refunded / cancelled / in_dispute → leave as-is

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.escrow_react_to_job_cancel() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.escrow_react_to_job_cancel() FROM PUBLIC;

DROP TRIGGER IF EXISTS escrow_react_to_job_cancel_trg ON public.repair_jobs;
CREATE TRIGGER escrow_react_to_job_cancel_trg
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.status::text = 'cancelled' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.escrow_react_to_job_cancel();
