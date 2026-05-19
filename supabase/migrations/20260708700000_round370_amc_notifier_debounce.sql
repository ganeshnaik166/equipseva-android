-- Round 370 — debounce notify_expiring_amc_contracts.
--
-- Current behaviour (r326 3-stage cadence): scans every active contract
-- with end_date in the next 7d, fires whichever stage matches. The
-- daily cron is idempotent because each stage records itself in
-- renewal_notifications_sent and a stage is never re-fired.
--
-- Edge case: if the cron is triggered twice in rapid succession (manual
-- ops invocation, retry-after-failure, or pg_cron + cron-tick both
-- ticking on the same minute — round 296 + 300 wiring), two different
-- stages can fire within seconds, e.g. stage 1 advances to stage 2
-- because the date math says "≤3 days" on the second run that was
-- already true on the first. Hospital + engineer get two pushes
-- back-to-back which reads as spam.
--
-- Guard: skip a stage advance if last_renewal_notification_at is within
-- the last 6 hours. The natural cadence is daily; 6h leaves room for
-- timezone-adjacent retries but blocks back-to-back fires.

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
           renewal_notifications_sent,
           last_renewal_notification_at
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

    -- Round 326 invariant: stage never re-fires.
    IF v_target_stage <= v_contract.renewal_notifications_sent THEN
      CONTINUE;
    END IF;

    -- Round 370 — debounce. If we paged within the last 6h, defer this
    -- stage to the next cron tick. Prevents back-to-back spam when the
    -- cron is invoked twice in rapid succession.
    IF v_contract.last_renewal_notification_at IS NOT NULL
       AND v_contract.last_renewal_notification_at > now() - interval '6 hours' THEN
      CONTINUE;
    END IF;

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
    ELSE
      v_title := 'AMC renewal tomorrow';
      v_body := 'Your AMC contract expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Renew now to keep service active.';
      v_engineer_title := 'Hospital AMC expires tomorrow';
      v_engineer_body := 'AMC for a hospital you serve expires on '
        || to_char(v_contract.end_date, 'DD Mon YYYY')
        || '. Last chance to follow up before lapse.';
    END IF;

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
  'Round 326 3-stage AMC renewal reminders (7d / 3d / 1d). Round 370 '
  'adds a 6h debounce so back-to-back cron invocations cannot fire '
  'consecutive stages within the same hour. v2 swaps in auto-charge '
  'worker once Razorpay subscriptions land.';
