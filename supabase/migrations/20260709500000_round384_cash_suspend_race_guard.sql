-- Round 384 — close the concurrent-notify race on
-- maybe_auto_suspend_engineer_on_cash_flag.
--
-- The trigger short-circuits if cash_auto_suspended_at IS NOT NULL,
-- which is correct for the serial case. Under READ COMMITTED two
-- concurrent INSERTs into cash_survey_responses can both see
-- cash_auto_suspended_at = NULL because neither has committed yet,
-- both pass the guard, both UPDATE the engineer + INSERT notifications.
-- Result: engineer + every admin get duplicate "Engineer auto-suspended"
-- pushes back-to-back, reading as bot-spam.
--
-- Fix: lock the engineer row FOR UPDATE before the guard. The second
-- concurrent trigger blocks until the first commits, then sees
-- cash_auto_suspended_at IS NOT NULL and short-circuits cleanly.
--
-- Same SECDEF + trigger plumbing as the previous version
-- (20260614100000_v21_cash_auto_suspend_distinct_hospitals.sql).
-- Body change is the SELECT ... FOR UPDATE block before the guard.

CREATE OR REPLACE FUNCTION public.maybe_auto_suspend_engineer_on_cash_flag()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_distinct_hospitals int;
  v_total_flags        int;
  v_engineer_user      uuid;
  v_admin_user         uuid;
  v_already_suspended  boolean;
BEGIN
  IF NEW.response IS DISTINCT FROM 'asked_cash' THEN RETURN NEW; END IF;

  -- Round 384 — row-lock the engineer first so concurrent triggers
  -- serialize. Without this, two simultaneous flags both pass the
  -- "already suspended" guard and fire duplicate notification fan-outs.
  SELECT (cash_auto_suspended_at IS NOT NULL)
    INTO v_already_suspended
    FROM public.engineers
   WHERE id = NEW.engineer_id
     FOR UPDATE;

  IF v_already_suspended THEN RETURN NEW; END IF;

  SELECT
    count(DISTINCT hospital_user_id),
    count(*)
    INTO v_distinct_hospitals, v_total_flags
    FROM public.cash_survey_responses
   WHERE engineer_id = NEW.engineer_id
     AND response = 'asked_cash'
     AND responded_at >= now() - interval '90 days';

  IF v_distinct_hospitals < 3 THEN RETURN NEW; END IF;

  UPDATE public.engineers
     SET cash_auto_suspended_at      = now(),
         cash_auto_suspension_reason = concat(
           v_total_flags::text,
           ' cash-payment flags from ',
           v_distinct_hospitals::text,
           ' independent hospitals in the last 90 days. Awaiting admin review.'
         ),
         is_available = false
   WHERE id = NEW.engineer_id;

  SELECT user_id INTO v_engineer_user
    FROM public.engineers WHERE id = NEW.engineer_id;
  IF v_engineer_user IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user,
        'engineer_auto_suspended',
        'Account paused pending review',
        'Multiple hospitals reported off-platform cash requests. Reach out to support to re-activate.',
        jsonb_build_object(
          'reason',              'cash_payment_flags',
          'flag_count',           v_total_flags,
          'distinct_hospitals',   v_distinct_hospitals
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'engineer_auto_suspended notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;

  FOR v_admin_user IN
    SELECT id FROM auth.users u
     WHERE EXISTS (
       SELECT 1 FROM public.profiles p
        WHERE p.id = u.id
          AND (p.role::text = 'admin' OR p.is_founder = true)
     )
  LOOP
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_admin_user,
        'admin_engineer_auto_suspended',
        'Engineer auto-suspended (cash flags)',
        concat(
          v_total_flags::text, ' cash-flags from ',
          v_distinct_hospitals::text, ' hospitals in 90 days — review queue.'
        ),
        jsonb_build_object(
          'engineer_id',          NEW.engineer_id,
          'flag_count',           v_total_flags,
          'distinct_hospitals',   v_distinct_hospitals
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'admin auto-suspend notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END LOOP;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.maybe_auto_suspend_engineer_on_cash_flag() OWNER TO postgres;
