-- v2.1 PR-D37: cash auto-suspend counts DISTINCT hospitals.
--
-- Today maybe_auto_suspend_engineer_on_cash_flag (PR-D11) sums every
-- 'asked_cash' response in 90 days. That's a real weaponization
-- vector: a single hostile hospital can submit 3 surveys against one
-- engineer and trigger auto-suspend single-handedly.
--
-- The intent of the rule from the strategy memo is "3+ INDEPENDENT
-- hospitals reported the engineer for cash payment". Switching to a
-- DISTINCT count of hospital_user_id enforces that intent without
-- new schema or per-hospital rate-limit tables.
--
-- Existing prevention layers stay intact:
--   * cash_survey_responses unique-per-job (PR-D1) prevents the same
--     hospital double-flagging the same job
--   * RLS keeps a hospital from inserting on another hospital's behalf
--
-- After this migration: hostile hospital A files 3 cash flags = 1
-- distinct hospital = no auto-suspend. 3 independent hospitals each
-- file 1 = 3 distinct = auto-suspend fires. The signal is real.

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
BEGIN
  IF NEW.response IS DISTINCT FROM 'asked_cash' THEN RETURN NEW; END IF;

  -- Idempotency: if this engineer is already suspended, no-op.
  PERFORM 1 FROM public.engineers
   WHERE id = NEW.engineer_id
     AND cash_auto_suspended_at IS NOT NULL;
  IF FOUND THEN RETURN NEW; END IF;

  -- Distinct count for the suspension trigger; raw count for the body
  -- copy (admin still wants to know "5 flags from 3 hospitals" not
  -- just "3 hospitals").
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

  -- Notify the engineer.
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

  -- Admin queue notification fan-out.
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
REVOKE ALL ON FUNCTION public.maybe_auto_suspend_engineer_on_cash_flag() FROM PUBLIC;

-- Trigger already exists from 20260525100000; the CREATE OR REPLACE
-- above swapped the function body; no re-binding needed.
