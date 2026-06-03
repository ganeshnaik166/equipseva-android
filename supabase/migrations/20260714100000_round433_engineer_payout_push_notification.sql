-- Round 433 — push notification when an engineer's payout state flips.
--
-- The engineer's Earnings screen surfaces status changes (round 427)
-- BUT only when the engineer opens the app. Without a push, an engineer
-- whose payout just landed has no signal — they have to remember to
-- check. The whole point of in-app payouts is for the engineer to feel
-- "EquipSeva pays me reliably"; a silent ₹9.30 landing in their bank
-- account from an unfamiliar reference defeats that.
--
-- Trigger on engineer_payouts UPDATE OF status:
--   * processed → "Payout received" with UTR + mode
--   * failed    → "Payout couldn't go through" with reason + nudge
--
-- Other transitions (queued → processing) are silent — the engineer
-- already knows their work is queued for payout (it's the default
-- state after release) and "we're sending it now" isn't actionable.
-- Cancelled is also silent because admin cancellations come with an
-- out-of-band conversation (founder reaches out before cancelling).
--
-- Uses the existing public.notifications table (drained by the FCM
-- push pipeline in send_push_notification edge fn). Same shape every
-- other notification trigger uses (kind + title + body + data jsonb).

CREATE OR REPLACE FUNCTION public.engineer_payout_push_on_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_amount_rupees numeric(12,2);
  v_job_number    text;
  v_title         text;
  v_body          text;
  v_dest_label    text;
BEGIN
  -- Bail early if not a meaningful transition.
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status NOT IN ('processed', 'failed') THEN
    RETURN NEW;
  END IF;

  v_amount_rupees := (NEW.amount_paise / 100.0)::numeric(12,2);

  SELECT job_number INTO v_job_number
    FROM public.repair_jobs WHERE id = NEW.repair_job_id;

  -- Destination label for the body — mirrors the per-row label the
  -- engineer sees on the Earnings screen. Best-effort; falls back to
  -- mode when method already detached.
  SELECT
    CASE
      WHEN m.kind = 'upi' THEN m.vpa
      WHEN m.kind = 'bank' AND m.bank_name IS NOT NULL
                            THEN m.bank_name || ' ••••' || m.account_number_last4
      WHEN m.kind = 'bank' THEN 'bank ••••' || m.account_number_last4
      ELSE NULL
    END
  INTO v_dest_label
  FROM public.engineer_payout_methods m
  WHERE m.id = NEW.payout_method_id;

  IF NEW.status = 'processed' THEN
    v_title := '₹' || v_amount_rupees || ' received';
    v_body := COALESCE(v_job_number, 'EquipSeva') ||
              ' · ' ||
              CASE
                WHEN NEW.utr IS NOT NULL THEN 'UTR ' || NEW.utr
                WHEN NEW.mode IS NOT NULL THEN 'via ' || NEW.mode
                ELSE 'paid'
              END ||
              CASE
                WHEN v_dest_label IS NOT NULL THEN ' to ' || v_dest_label
                ELSE ''
              END;
  ELSE  -- failed
    v_title := 'Payout failed';
    v_body := COALESCE(v_job_number, 'Your payout') ||
              ' · ₹' || v_amount_rupees || ' — ' ||
              COALESCE(NEW.failure_reason, 'check your payout method and we''ll retry');
  END IF;

  INSERT INTO public.notifications (user_id, kind, title, body, data)
  VALUES (
    NEW.engineer_user_id,
    'engineer_payout_' || NEW.status,  -- 'engineer_payout_processed' / 'engineer_payout_failed'
    v_title,
    v_body,
    jsonb_build_object(
      'payout_id',     NEW.id,
      'repair_job_id', NEW.repair_job_id,
      'job_number',    v_job_number,
      'amount_paise',  NEW.amount_paise,
      'status',        NEW.status,
      'utr',           NEW.utr,
      'mode',          NEW.mode
    )
  );

  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS engineer_payout_push_on_status_change_trg
  ON public.engineer_payouts;
CREATE TRIGGER engineer_payout_push_on_status_change_trg
  AFTER UPDATE OF status ON public.engineer_payouts
  FOR EACH ROW
  EXECUTE FUNCTION public.engineer_payout_push_on_status_change();
