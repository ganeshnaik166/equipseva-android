-- Round 326 — 3-stage AMC renewal reminder cadence.
--
-- Round 313 fired exactly one notification per contract when end_date
-- entered the 7-day window. If the hospital ignored it, no follow-up.
-- Real cadence research (and round-313's own deferred carry-over)
-- says urgency should escalate as expiry nears:
--
--   stage 1 — 7d window — "AMC renewal due soon"
--   stage 2 — 3d window — "AMC renewal in 3 days"
--   stage 3 — 1d window — "AMC renewal tomorrow"
--
-- Schema: add renewal_notifications_sent int counter (0..3). The
-- existing last_renewal_notification_at column stays for backwards
-- compatibility + observability (admins can see when the latest stage
-- fired). Backfill existing contracts that already had stage 1 fired.
--
-- The notify RPC's existing scan now fires whichever stage the
-- contract's days-until-end maps to, provided that stage hasn't
-- fired yet. Each cron run can fire at most one stage per contract.
-- The engineer-side notification (round 317) mirrors the stage so
-- both sides stay synchronized.

ALTER TABLE public.amc_contracts
  ADD COLUMN IF NOT EXISTS renewal_notifications_sent int NOT NULL DEFAULT 0;

-- Backfill: anyone who already received a round-313 notification
-- counts as stage 1 sent. They'll progress to stage 2/3 as their
-- end_date crosses the 3d/1d thresholds.
UPDATE public.amc_contracts
   SET renewal_notifications_sent = 1
 WHERE last_renewal_notification_at IS NOT NULL
   AND renewal_notifications_sent = 0;

-- Tighten the partial index to scan only contracts that still have
-- pending stages. End_date guards the candidate set; the
-- renewal_notifications_sent < 3 keeps the index small.
DROP INDEX IF EXISTS amc_contracts_renewal_notify_idx;
CREATE INDEX amc_contracts_renewal_notify_idx
  ON public.amc_contracts (end_date)
 WHERE status = 'active'
   AND renewal_notifications_sent < 3;

CREATE OR REPLACE FUNCTION public.notify_expiring_amc_contracts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract record;
  v_engineer_user_id uuid;
  v_target_stage int;
  v_days_left int;
  v_title text;
  v_body text;
  v_engineer_title text;
  v_engineer_body text;
  v_count int := 0;
BEGIN
  FOR v_contract IN
    SELECT id, hospital_user_id, primary_engineer_id, end_date,
           monthly_fee_rupees, renewal_term_months,
           renewal_notifications_sent
      FROM public.amc_contracts
     WHERE status = 'active'
       AND end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
       AND renewal_notifications_sent < 3
     FOR UPDATE SKIP LOCKED
  LOOP
    v_days_left := (v_contract.end_date - CURRENT_DATE)::int;
    v_target_stage := CASE
      WHEN v_days_left <= 1 THEN 3
      WHEN v_days_left <= 3 THEN 2
      ELSE 1
    END;

    -- Only fire if this stage hasn't already been delivered.
    IF v_target_stage <= v_contract.renewal_notifications_sent THEN
      CONTINUE;
    END IF;

    -- Per-stage copy. Body shows the literal date so the hospital can
    -- diary it; the urgency escalates with each stage.
    IF v_target_stage = 1 THEN
      v_title := 'AMC renewal due soon';
      v_body := 'Your AMC contract expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Tap to renew before service pauses.';
      v_engineer_title := 'Hospital AMC renewal due';
      v_engineer_body := 'A hospital you serve has an AMC expiring on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Follow up so the contract doesn''t lapse.';
    ELSIF v_target_stage = 2 THEN
      v_title := 'AMC renewal in 3 days';
      v_body := 'Your AMC contract expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Renew today so engineer visits don''t stop.';
      v_engineer_title := 'Hospital AMC expiring in 3 days';
      v_engineer_body := 'AMC for a hospital you serve expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Nudge them to renew — visits will pause otherwise.';
    ELSE -- stage 3
      v_title := 'AMC renewal tomorrow';
      v_body := 'Your AMC contract expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Renew now to keep service active.';
      v_engineer_title := 'Hospital AMC expires tomorrow';
      v_engineer_body := 'AMC for a hospital you serve expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Last chance to follow up before lapse.';
    END IF;

    -- Hospital-side notification.
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      v_contract.hospital_user_id,
      'amc_renewal_due',
      v_title,
      v_body,
      jsonb_build_object(
        'amc_contract_id', v_contract.id,
        'end_date',        v_contract.end_date,
        'stage',           v_target_stage,
        'amount_rupees',   (v_contract.monthly_fee_rupees
                              * v_contract.renewal_term_months)::numeric(10,2)
      )
    );

    -- Engineer-side notification (round 317).
    SELECT e.user_id
      INTO v_engineer_user_id
      FROM public.engineers e
     WHERE e.id = v_contract.primary_engineer_id;

    IF v_engineer_user_id IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user_id,
        'amc_renewal_due',
        v_engineer_title,
        v_engineer_body,
        jsonb_build_object(
          'amc_contract_id', v_contract.id,
          'end_date',        v_contract.end_date,
          'stage',           v_target_stage
        )
      );
    END IF;

    UPDATE public.amc_contracts
       SET renewal_notifications_sent = v_target_stage,
           last_renewal_notification_at = now()
     WHERE id = v_contract.id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

ALTER FUNCTION public.notify_expiring_amc_contracts() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_expiring_amc_contracts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_expiring_amc_contracts() TO service_role;

COMMENT ON FUNCTION public.notify_expiring_amc_contracts() IS
  'Round 326 — 3-stage AMC renewal reminders (7d / 3d / 1d). Fires '
  'both hospital and engineer notifications per stage; each contract '
  'can advance through stages 1->2->3 across daily cron runs, but '
  'never re-fires a completed stage. Stage stored in '
  'amc_contracts.renewal_notifications_sent. v2 swaps in an '
  'auto-charge worker once Razorpay subscriptions land.';
