-- v2 monetization: compute platform_commission + engineer_payout when a
-- repair_job transitions to completed.
--
-- Per the v2 spec: 7% platform commission on contracted_amount_rupees,
-- 93% engineer_payout. Both columns existed since the v2 schema landed
-- but no trigger or RPC was populating them — so engineer Earnings UI
-- and admin dashboards saw 0 for every completed job.
--
-- Trigger fires BEFORE UPDATE of status so the row is written with the
-- final values in one shot (no second UPDATE round-trip). Re-runs are
-- safe: if commission/payout are already set we leave them alone, so a
-- mass status flip (admin re-completion, backfill) won't double-charge.
--
-- Cost revision edge case: if contracted_amount_rupees changes AFTER
-- completion via decide_cost_revision, this trigger does NOT recompute.
-- That path is rare and the RPC can call refresh_completed_commission()
-- directly — left as a v2.1 follow-up.

CREATE OR REPLACE FUNCTION public.compute_repair_job_commission_on_complete()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_commission_rate numeric := 0.07;
  v_amount numeric;
BEGIN
  -- Only act on the status -> completed transition. Don't fire on
  -- inserts (defensive — repair_jobs always starts at 'requested' per
  -- the status_transition_guard).
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status::text <> 'completed' THEN
    RETURN NEW;
  END IF;

  v_amount := COALESCE(NEW.contracted_amount_rupees, 0);
  IF v_amount <= 0 THEN
    -- No contract amount → nothing to split. Leave both columns at
    -- their existing values (typically 0). Admin can patch if needed.
    RETURN NEW;
  END IF;

  -- Idempotency: only populate when commission is unset / zero. Lets
  -- admins backfill manually without the trigger overwriting later.
  IF COALESCE(NEW.platform_commission, 0) = 0 THEN
    NEW.platform_commission := ROUND(v_amount * v_commission_rate, 2);
  END IF;
  IF COALESCE(NEW.engineer_payout, 0) = 0 THEN
    NEW.engineer_payout := ROUND(v_amount - COALESCE(NEW.platform_commission, 0), 2);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS compute_repair_job_commission_on_complete_trg
  ON public.repair_jobs;
CREATE TRIGGER compute_repair_job_commission_on_complete_trg
  BEFORE UPDATE ON public.repair_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.compute_repair_job_commission_on_complete();

-- Backfill: existing completed rows where commission/payout are still
-- 0 but contracted_amount is set. Restricted by WHERE so it touches
-- only the rows that actually need it; the trigger's idempotency check
-- protects us if a future migration re-runs this.
UPDATE public.repair_jobs
   SET platform_commission = ROUND(contracted_amount_rupees * 0.07, 2),
       engineer_payout = ROUND(contracted_amount_rupees - ROUND(contracted_amount_rupees * 0.07, 2), 2)
 WHERE status::text = 'completed'
   AND COALESCE(contracted_amount_rupees, 0) > 0
   AND COALESCE(platform_commission, 0) = 0
   AND COALESCE(engineer_payout, 0) = 0;
