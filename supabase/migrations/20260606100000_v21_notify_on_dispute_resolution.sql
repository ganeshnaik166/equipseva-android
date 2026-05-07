-- v2.1 PR-D28: notify both parties when admin resolves an escrow dispute.
--
-- PR-D22 added the open-dispute push (engineer + admin fan-out). The
-- close-dispute side was missed: today admin_resolve_escrow_dispute
-- updates status (released | refunded), inserts the dispute_resolved
-- event, and... that's it. Hospital + engineer get no notification.
--
-- This trigger fires on UPDATE of repair_job_escrow when status flips
-- from in_dispute -> released | refunded. Pushes are role-aware:
--   * Released  -> engineer "Funds released to you"
--                  hospital "Dispute closed in engineer's favour"
--   * Refunded  -> engineer "Dispute closed - funds refunded"
--                  hospital "Refund issued"
-- kind=`escrow_dispute_resolved` for both, with payload encoding the
-- outcome so the receiving client can render the right copy locally.
--
-- Best-effort fan-out (mirrors PR-D22 pattern). EXCEPTION clause keeps
-- the resolve UPDATE atomic.

CREATE OR REPLACE FUNCTION public.notify_on_escrow_dispute_resolved()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_outcome text;
BEGIN
  IF TG_OP <> 'UPDATE' THEN RETURN NEW; END IF;
  IF OLD.status <> 'in_dispute' THEN RETURN NEW; END IF;
  IF NEW.status NOT IN ('released', 'refunded') THEN RETURN NEW; END IF;

  v_outcome := NEW.status;  -- 'released' or 'refunded'

  -- Engineer side.
  IF NEW.engineer_user_id IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        NEW.engineer_user_id,
        'escrow_dispute_resolved',
        CASE v_outcome
          WHEN 'released' THEN 'Funds released to you'
          ELSE 'Dispute closed - funds refunded'
        END,
        CASE v_outcome
          WHEN 'released' THEN 'EquipSeva resolved the dispute in your favour. Settlement to your bank account is queued.'
          ELSE 'EquipSeva resolved the dispute in the hospital''s favour. Funds were refunded.'
        END,
        jsonb_build_object(
          'repair_job_id', NEW.repair_job_id,
          'escrow_id',     NEW.id,
          'outcome',       v_outcome,
          'amount_rupees', NEW.amount_rupees
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'escrow_dispute_resolved engineer notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;

  -- Hospital side.
  IF NEW.hospital_user_id IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        NEW.hospital_user_id,
        'escrow_dispute_resolved',
        CASE v_outcome
          WHEN 'released' THEN 'Dispute closed in engineer''s favour'
          ELSE 'Refund issued'
        END,
        CASE v_outcome
          WHEN 'released' THEN 'EquipSeva reviewed the dispute and released funds to the engineer.'
          ELSE 'EquipSeva refunded ' || ('₹' || trim(to_char(NEW.amount_rupees, 'FM999G999G999D00'))) || ' to your account.'
        END,
        jsonb_build_object(
          'repair_job_id', NEW.repair_job_id,
          'escrow_id',     NEW.id,
          'outcome',       v_outcome,
          'amount_rupees', NEW.amount_rupees
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'escrow_dispute_resolved hospital notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$;
ALTER FUNCTION public.notify_on_escrow_dispute_resolved() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_on_escrow_dispute_resolved() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_escrow_dispute_resolved_trg ON public.repair_job_escrow;
CREATE TRIGGER notify_on_escrow_dispute_resolved_trg
  AFTER UPDATE ON public.repair_job_escrow
  FOR EACH ROW
  WHEN (
    OLD.status = 'in_dispute'
    AND NEW.status IN ('released', 'refunded')
  )
  EXECUTE FUNCTION public.notify_on_escrow_dispute_resolved();
