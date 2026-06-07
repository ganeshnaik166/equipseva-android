-- Round 452 — AMC state-machine + notification hardening (6 HIGH).
--
-- All from the 2026-06-07 adversarial audit:
--
--   1. HIGH — process_amc_renewal_outcome failure branch UPDATEs
--      amc_contracts.status='renewal_failed' with no current-status
--      guard. Cancelled/expired/paused contracts can race in and get
--      flipped to renewal_failed, losing the original termination
--      cause from the dashboard.
--
--   2. HIGH — process_amc_renewal_outcome success branch UPDATEs
--      end_date with no status guard. Expired/cancelled contracts get
--      their end_date pushed forward but status stays terminal: hospital
--      pays, pool gets credited, but no visits ever auto-create. Zombie
--      paid-but-not-active contract.
--
--   3. HIGH — repair_jobs_status_transition_guard regression. Round 234
--      (20260626170000) accidentally re-added `(en_route → completed)`
--      and `(in_progress → completed)` to the non-admin allow-list.
--      Round 237 (20260627005000) preserved the regression. Engineers
--      can now PATCH status='completed' directly via PostgREST,
--      bypassing the complete_repair_job SECDEF RPC (which is meant to
--      enforce check-in/photo-upload gates + stamp completed_at).
--      Restore the PR-D45 intent: drop 'completed' from non-admin
--      en_route/in_progress branches.
--
--   4. HIGH — notify_on_repair_job_completed_for_cash_survey_trg fires
--      for AMC maintenance visits even though those are paid from the
--      contract pool, not cash. Hospital gets a "How did payment go
--      for AMC-XXX?" survey CTA for a job that was never paid in cash.
--      Add kind='maintenance' early-return.
--
--   5. HIGH — engineer_payout_push_on_status_change does INSERT INTO
--      public.notifications at top scope with no BEGIN/EXCEPTION wrap.
--      If the notifications insert fails (engineer_user_id orphaned,
--      RLS race), the AFTER UPDATE trigger throws and the engineer_
--      payouts.status UPDATE rolls back — payout silently stays at
--      'processing' forever even though Cashfree actually succeeded.
--
--   6. HIGH — notify_expiring_amc_contracts iterates active contracts
--      in a FOR loop and does INSERT INTO notifications without
--      per-iteration BEGIN/EXCEPTION. One bad row strands the whole
--      batch. Same shape as round 442/446 fix.

-- ---------------------------------------------------------------------
-- 1 + 2. process_amc_renewal_outcome — status guards on both branches
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_amc_renewal_outcome(
  p_attempt_id    uuid,
  p_succeeded     boolean,
  p_payment_id    text DEFAULT NULL,
  p_error_message text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract_id    uuid;
  v_attempt_number int;
  v_attempt_status text;
  v_amount         numeric(10,2);
  v_monthly_fee    numeric(10,2);
  v_renewal_months int;
  v_payment_order  uuid;
  v_contract_status text;
  v_extend_rows    int;
BEGIN
  SELECT amc_contract_id, attempt_number, status, amount_rupees
    INTO v_contract_id, v_attempt_number, v_attempt_status, v_amount
    FROM public.amc_renewal_attempts
   WHERE id = p_attempt_id
   FOR UPDATE;

  IF v_contract_id IS NULL THEN
    RAISE EXCEPTION 'renewal attempt % not found', p_attempt_id USING ERRCODE = '42704';
  END IF;

  IF v_attempt_status <> 'pending' THEN
    RETURN;
  END IF;

  SELECT monthly_fee_rupees, renewal_term_months, status::text
    INTO v_monthly_fee, v_renewal_months, v_contract_status
    FROM public.amc_contracts
   WHERE id = v_contract_id
   FOR UPDATE;

  IF v_monthly_fee IS NULL THEN
    RAISE EXCEPTION 'parent contract % missing', v_contract_id USING ERRCODE = '42704';
  END IF;

  IF p_succeeded THEN
    -- Round 452 fix #2: guard end_date push on current status. Terminal
    -- contracts (expired/cancelled/renewal_failed) must not silently
    -- extend — that creates a paid-but-not-active zombie row.
    UPDATE public.amc_renewal_attempts
       SET status              = 'succeeded',
           razorpay_payment_id = p_payment_id,
           resolved_at         = now()
     WHERE id = p_attempt_id;

    UPDATE public.amc_contracts
       SET end_date   = (end_date + make_interval(months => v_renewal_months))::date,
           updated_at = now()
     WHERE id = v_contract_id
       AND status IN ('active', 'paused');
    GET DIAGNOSTICS v_extend_rows = ROW_COUNT;

    IF v_extend_rows = 0 THEN
      -- Late-arriving success on a terminal contract. Mark the attempt
      -- as succeeded for audit, but do NOT extend end_date and do NOT
      -- credit the pool — that money needs operator-driven refund
      -- (charge-back via Razorpay or manual settlement) instead of
      -- silently disappearing into a zombie contract. Surface clearly
      -- so ops can investigate.
      RAISE NOTICE 'process_amc_renewal_outcome: contract % is terminal (%); attempt % succeeded but skipped end_date+pool credit (refund required)',
        v_contract_id, v_contract_status, p_attempt_id;

      -- Still persist the amc_payment_orders row in a non-paid status
      -- so finance / refund flows can find the money trail.
      INSERT INTO public.amc_payment_orders (
        amc_contract_id, months_paid, amount_rupees,
        razorpay_payment_id, status, updated_at
      ) VALUES (
        v_contract_id, v_renewal_months,
        coalesce(v_amount, (v_monthly_fee * v_renewal_months)::numeric(10,2)),
        p_payment_id, 'refund_required', now()
      );
      RETURN;
    END IF;

    INSERT INTO public.amc_payment_orders (
      amc_contract_id, months_paid, amount_rupees,
      razorpay_payment_id, status, updated_at
    ) VALUES (
      v_contract_id, v_renewal_months,
      coalesce(v_amount, (v_monthly_fee * v_renewal_months)::numeric(10,2)),
      p_payment_id, 'paid', now()
    ) RETURNING id INTO v_payment_order;

    PERFORM public.apply_amc_pool_credit(v_payment_order);
  ELSE
    IF v_attempt_number < 3 THEN
      UPDATE public.amc_renewal_attempts
         SET status        = 'failed',
             error_message = p_error_message,
             resolved_at   = now()
       WHERE id = p_attempt_id;
    ELSE
      UPDATE public.amc_renewal_attempts
         SET status        = 'abandoned',
             error_message = p_error_message,
             resolved_at   = now()
       WHERE id = p_attempt_id;

      -- Round 452 fix #1: guard renewal_failed flip on current status.
      -- Don't clobber cancelled / expired / renewal_failed contracts —
      -- their termination cause must survive in the audit trail.
      UPDATE public.amc_contracts
         SET status     = 'renewal_failed',
             auto_renew = false,
             updated_at = now()
       WHERE id = v_contract_id
         AND status IN ('active', 'paused');
    END IF;
  END IF;
END;
$$;

ALTER FUNCTION public.process_amc_renewal_outcome(uuid, boolean, text, text)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.process_amc_renewal_outcome(uuid, boolean, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_amc_renewal_outcome(uuid, boolean, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 3. repair_jobs_status_transition_guard — drop 'completed' from
-- non-admin en_route + in_progress allow-lists. Engineers must go
-- through complete_repair_job SECDEF (which bypasses via current_user=
-- 'postgres' clause).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.repair_jobs_status_transition_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
  v_old text := OLD.status::text;
  v_new text := NEW.status::text;
BEGIN
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF v_new = v_old THEN
    RETURN NEW;
  END IF;

  -- Round 452 fix #3: drop 'completed' from en_route + in_progress
  -- non-admin paths. PR-D45 intent restored — engineers must call
  -- complete_repair_job (SECDEF, bypasses via current_user='postgres')
  -- which enforces check-in / photo gates and stamps completed_at +
  -- triggers the 48h escrow auto-release schedule.
  IF NOT (
    (v_old = 'requested'   AND v_new IN ('assigned','cancelled')) OR
    (v_old = 'assigned'    AND v_new IN ('en_route','in_progress','cancelled','disputed')) OR
    (v_old = 'en_route'    AND v_new IN ('in_progress','cancelled','disputed')) OR
    (v_old = 'in_progress' AND v_new IN ('disputed')) OR
    (v_old = 'completed'   AND v_new IN ('disputed'))
  ) THEN
    RAISE EXCEPTION 'invalid status transition % -> %', v_old, v_new
      USING ERRCODE = '22023';
  END IF;

  IF v_new = 'cancelled' AND auth.uid() IS NOT NULL
     AND auth.uid() <> NEW.hospital_user_id THEN
    RAISE EXCEPTION 'only the hospital can cancel a job'
      USING ERRCODE = '42501';
  END IF;

  IF v_new = 'disputed' AND auth.uid() IS NOT NULL
     AND auth.uid() <> NEW.hospital_user_id THEN
    RAISE EXCEPTION 'only the hospital can open a dispute'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------
-- 4. notify_on_repair_job_completed_for_cash_survey — skip AMC visits.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_on_repair_job_completed_for_cash_survey()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job_number text;
BEGIN
  IF NEW.status::text <> 'completed' THEN
    RETURN NEW;
  END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;
  IF NEW.hospital_user_id IS NULL OR NEW.engineer_id IS NULL THEN
    RETURN NEW;
  END IF;
  -- Round 452 fix #4: skip AMC visits. They're pre-paid via the
  -- contract pool, so the cash-vs-cashfree survey question is
  -- nonsensical and any 'asked_cash' response would feed
  -- maybe_auto_suspend_engineer_on_cash_flag spuriously.
  IF NEW.kind::text = 'maintenance' THEN
    RETURN NEW;
  END IF;

  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'cash_survey',
      'Quick check-in',
      concat('How did payment go for job ', v_job_number, '?'),
      jsonb_build_object('repair_job_id', NEW.id, 'job_number', v_job_number)
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'cash_survey notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_on_repair_job_completed_for_cash_survey() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_on_repair_job_completed_for_cash_survey() FROM PUBLIC;

-- ---------------------------------------------------------------------
-- 5. engineer_payout_push_on_status_change — EXCEPTION wrap.
-- ---------------------------------------------------------------------
-- Read the existing function shape and re-create with the INSERT inside
-- a BEGIN/EXCEPTION block.

CREATE OR REPLACE FUNCTION public.engineer_payout_push_on_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_title text;
  v_body  text;
  v_job_number text;
BEGIN
  -- Only fire on status flips into terminal states; mirror the round 433
  -- intent (push when engineer would care about a state change).
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status NOT IN ('processed', 'failed') THEN
    RETURN NEW;
  END IF;
  IF NEW.engineer_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT job_number INTO v_job_number
    FROM public.repair_jobs WHERE id = NEW.repair_job_id;
  v_job_number := COALESCE(v_job_number, substring(coalesce(NEW.repair_job_id::text, NEW.id::text), 1, 8));

  IF NEW.status = 'processed' THEN
    v_title := 'Payment received';
    v_body := concat(
      'Your payout for ', v_job_number, ' is in your account.',
      CASE WHEN NEW.utr IS NOT NULL THEN ' UTR ' || NEW.utr ELSE '' END
    );
  ELSE
    v_title := 'Payout failed';
    v_body := concat(
      'Payout for ', v_job_number, ' didn''t go through. Tap to update your UPI or bank.',
      CASE WHEN NEW.failure_reason IS NOT NULL THEN ' (' || NEW.failure_reason || ')' ELSE '' END
    );
  END IF;

  -- Round 452 fix #5: wrap in BEGIN/EXCEPTION. If the notifications
  -- insert fails (engineer_user_id orphaned via auth.users delete,
  -- RLS race, kind-guard collision), the parent UPDATE on
  -- engineer_payouts.status would otherwise roll back — payout
  -- silently stays at 'processing' forever even though Cashfree
  -- actually delivered the money. The push is a fan-out; the state
  -- machine must never depend on it.
  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.engineer_user_id,
      CASE WHEN NEW.status = 'processed' THEN 'engineer_payout_processed'
           ELSE 'engineer_payout_failed' END,
      v_title,
      v_body,
      jsonb_build_object(
        'engineer_payout_id', NEW.id,
        'repair_job_id',      NEW.repair_job_id,
        'job_number',         v_job_number,
        'status',             NEW.status,
        'utr',                NEW.utr,
        'failure_reason',     NEW.failure_reason
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'engineer_payout_push_on_status_change notify failed: % / %',
      SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.engineer_payout_push_on_status_change() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.engineer_payout_push_on_status_change() FROM PUBLIC;

-- ---------------------------------------------------------------------
-- 6. notify_expiring_amc_contracts — per-row EXCEPTION wrap.
-- ---------------------------------------------------------------------
-- Replace the function body with the existing logic wrapped in per-
-- iteration BEGIN/EXCEPTION so one bad contract doesn't strand the
-- whole batch. Same shape as round 446 fix on auto_create_due_amc_visits.

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
    BEGIN
      v_days_left := (v_contract.end_date - CURRENT_DATE)::int;
      v_target_stage := CASE
        WHEN v_days_left <= 1 THEN 3
        WHEN v_days_left <= 3 THEN 2
        ELSE 1
      END;

      IF v_target_stage <= v_contract.renewal_notifications_sent THEN
        CONTINUE;
      END IF;

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
    EXCEPTION WHEN OTHERS THEN
      -- Round 452 fix #6: one bad contract doesn't strand the batch.
      -- renewal_notifications_sent + last_renewal_notification_at were
      -- never advanced on the failed iteration, so the next tick retries.
      RAISE NOTICE 'notify_expiring_amc_contracts: skipped contract % (%): %',
        v_contract.id, SQLSTATE, SQLERRM;
    END;
  END LOOP;

  RETURN v_count;
END;
$$;

ALTER FUNCTION public.notify_expiring_amc_contracts() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_expiring_amc_contracts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_expiring_amc_contracts() TO service_role;
