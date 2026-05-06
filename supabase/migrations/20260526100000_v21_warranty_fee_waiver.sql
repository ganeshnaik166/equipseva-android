-- v2.1 PR-D12: warranty fee-waiver (PR-D9 follow-up).
--
-- PR-D9 (#278) shipped detection — repair_jobs.is_warranty_covered
-- gets stamped on insert. But the commission computation
-- (compute_repair_job_commission_on_complete from #259, refined by
-- PR-D2 commission-tier loyalty in #272) was still running normally
-- on warranty jobs. Hospital pays for the re-visit, engineer gets
-- their cut, platform takes commission — that's what we *promised
-- not to do*.
--
-- Strategy memo T3.12: "every job done in-app gets 30-day platform-
-- backed warranty. Off-platform = no warranty." For the promise to
-- be real, the platform has to actually eat the cost. This migration
-- makes that automatic at completion time:
--
--   1. compute_repair_job_commission_on_complete extended: when the
--      row has is_warranty_covered=true, set platform_commission=0
--      and engineer_payout=full contracted amount. Engineer gets
--      paid fully; platform absorbs the entire cost.
--   2. Trigger on status='completed' for warranty rows: emit a
--      notification kind='warranty_fee_waived' to the engineer so
--      they know the platform covered them.
--
-- Hospital-side waiver:
--   Today the hospital still pays the contracted_amount via per-job
--   escrow (PR-D5). The escrow flow doesn't yet zero the hospital
--   side. v2.2 will refund the hospital's escrow contribution OR
--   skip pay-in entirely on warranty jobs. For v1 the platform's
--   end of the deal is on the engineer-payout side — engineer
--   doesn't get penalized for re-doing their own work.
--
-- Backfill: existing completed warranty rows are not retroactively
-- waived (avoids surprise commission reversals). Going forward only.

CREATE OR REPLACE FUNCTION public.compute_repair_job_commission_on_complete()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_commission_rate numeric;
  v_amount          numeric;
BEGIN
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
    RETURN NEW;
  END IF;

  -- PR-D12: warranty fee-waiver. Engineer gets full payout, platform
  -- absorbs the entire cost. Idempotent via the same zero-check we
  -- use elsewhere (manual admin overrides survive).
  IF COALESCE(NEW.is_warranty_covered, false) THEN
    IF COALESCE(NEW.platform_commission, 0) = 0 THEN
      NEW.platform_commission := 0;
    END IF;
    IF COALESCE(NEW.engineer_payout, 0) = 0 THEN
      NEW.engineer_payout := v_amount;
    END IF;
    RETURN NEW;
  END IF;

  -- Standard path — loyalty tier (PR-D2).
  v_commission_rate := public.commission_rate_for_hospital(NEW.hospital_user_id);

  IF COALESCE(NEW.platform_commission, 0) = 0 THEN
    NEW.platform_commission := ROUND(v_amount * v_commission_rate, 2);
  END IF;
  IF COALESCE(NEW.engineer_payout, 0) = 0 THEN
    NEW.engineer_payout := ROUND(v_amount - COALESCE(NEW.platform_commission, 0), 2);
  END IF;

  RETURN NEW;
END;
$$;

-- Notification — engineer learns the platform covered them.
CREATE OR REPLACE FUNCTION public.notify_warranty_fee_waived()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_engineer_user uuid;
  v_job_number    text;
BEGIN
  IF NOT COALESCE(NEW.is_warranty_covered, false) THEN RETURN NEW; END IF;
  IF NEW.status::text <> 'completed' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  IF NEW.engineer_id IS NULL THEN RETURN NEW; END IF;

  SELECT user_id INTO v_engineer_user
    FROM public.engineers WHERE id = NEW.engineer_id;
  IF v_engineer_user IS NULL THEN RETURN NEW; END IF;

  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      v_engineer_user,
      'warranty_fee_waived',
      'Platform covered this re-visit',
      concat(
        'Job ', v_job_number,
        ' was within 30-day warranty. EquipSeva covered the platform fee — you''ll get the full ₹',
        round(COALESCE(NEW.contracted_amount_rupees, 0))::text, '.'
      ),
      jsonb_build_object(
        'repair_job_id', NEW.id,
        'job_number',    v_job_number,
        'engineer_payout', COALESCE(NEW.engineer_payout, 0)
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'warranty_fee_waived notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.notify_warranty_fee_waived() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_warranty_fee_waived() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_warranty_fee_waived_trg ON public.repair_jobs;
CREATE TRIGGER notify_warranty_fee_waived_trg
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.status::text = 'completed'
        AND OLD.status IS DISTINCT FROM NEW.status
        AND NEW.is_warranty_covered = true)
  EXECUTE FUNCTION public.notify_warranty_fee_waived();
