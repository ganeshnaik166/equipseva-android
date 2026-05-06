-- v2.1 PR-D11: auto-suspend engineers on 3 cash-payment-survey flags
-- (T2.6 finalization). Strategy memo: "3 flags on same engineer →
-- suspend." PR-D1 (#271) shipped the survey + flag tracking but kept
-- auto-suspend manual to avoid weaponization (collusive hospitals
-- piling fake flags). User authorized turning it on after a session
-- review of the survey shape.
--
-- Mechanism:
--   * New cash_auto_suspended_at + cash_auto_suspension_reason cols
--     on engineers. Adding to engineers_trust_columns_guard so the
--     engineer themselves can't clear them — admin only.
--   * AFTER INSERT trigger on cash_survey_responses counts asked_cash
--     responses for that engineer in the trailing 90 days. If >= 3,
--     stamps the columns. Idempotent: re-fires don't re-stamp if
--     cash_auto_suspended_at is already set.
--   * Directory + AMC rotation queries already filter is_available =
--     true. Trigger flips is_available to false on suspend so the
--     engineer disappears from directory + bid feeds + rotation
--     pickers without touching those query bodies. (Engineer can't
--     flip is_available back to true via the column guard if the
--     auto-suspension columns are set — added below.)
--   * Notification to admin / founder + the engineer themselves on
--     suspend so neither side is surprised.
--   * Admin RPC clear_cash_auto_suspension(engineer_id) for review
--     unblocking.

ALTER TABLE public.engineers
  ADD COLUMN IF NOT EXISTS cash_auto_suspended_at      timestamptz,
  ADD COLUMN IF NOT EXISTS cash_auto_suspension_reason text;

CREATE INDEX IF NOT EXISTS idx_engineers_cash_auto_suspended
  ON public.engineers (cash_auto_suspended_at)
  WHERE cash_auto_suspended_at IS NOT NULL;

-- ---------------------------------------------------------------------
-- Extend the trust columns guard so engineers can't:
--   1. Clear cash_auto_suspended_at / reason themselves.
--   2. Flip is_available=true while auto-suspended.
-- Admin / founder / service_role / postgres still bypass everything.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.engineers_trust_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role' OR session_user = 'postgres' OR current_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
    IF NEW.verification_status::text <> 'pending' THEN
      RAISE EXCEPTION 'verification_status flip to % requires admin', NEW.verification_status
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.rating_avg IS DISTINCT FROM OLD.rating_avg
       OR NEW.total_jobs IS DISTINCT FROM OLD.total_jobs
       OR NEW.completion_rate IS DISTINCT FROM OLD.completion_rate
       OR NEW.total_earnings IS DISTINCT FROM OLD.total_earnings
       OR NEW.background_check_status IS DISTINCT FROM OLD.background_check_status
       OR NEW.verification_notes IS DISTINCT FROM OLD.verification_notes
       OR NEW.rejected_doc_types IS DISTINCT FROM OLD.rejected_doc_types
       OR NEW.user_id IS DISTINCT FROM OLD.user_id
       OR NEW.cash_auto_suspended_at IS DISTINCT FROM OLD.cash_auto_suspended_at
       OR NEW.cash_auto_suspension_reason IS DISTINCT FROM OLD.cash_auto_suspension_reason
    THEN
      RAISE EXCEPTION 'cannot modify admin / computed engineers columns'
        USING ERRCODE = '42501';
    END IF;
    -- Block engineer from un-pausing themselves while auto-suspended.
    IF OLD.cash_auto_suspended_at IS NOT NULL
       AND NEW.is_available = true
       AND coalesce(OLD.is_available, false) = false THEN
      RAISE EXCEPTION 'engineer is suspended pending review'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.verification_status::text <> 'pending' THEN
      RAISE EXCEPTION 'engineers row must start at verification_status=pending'
        USING ERRCODE = '42501';
    END IF;
    IF coalesce(NEW.rating_avg, 0) <> 0
       OR coalesce(NEW.total_jobs, 0) <> 0
       OR coalesce(NEW.completion_rate, 0) <> 0
       OR coalesce(NEW.total_earnings, 0) <> 0 THEN
      RAISE EXCEPTION 'engineers stats must start at zero'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------
-- The actual suspension trigger.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.maybe_auto_suspend_engineer_on_cash_flag()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count          int;
  v_engineer_user  uuid;
  v_admin_user     uuid;
BEGIN
  IF NEW.response IS DISTINCT FROM 'asked_cash' THEN RETURN NEW; END IF;

  -- Idempotency: if this engineer is already suspended, no-op.
  PERFORM 1 FROM public.engineers
   WHERE id = NEW.engineer_id
     AND cash_auto_suspended_at IS NOT NULL;
  IF FOUND THEN RETURN NEW; END IF;

  SELECT count(*) INTO v_count
    FROM public.cash_survey_responses
   WHERE engineer_id = NEW.engineer_id
     AND response = 'asked_cash'
     AND responded_at >= now() - interval '90 days';

  IF v_count < 3 THEN RETURN NEW; END IF;

  UPDATE public.engineers
     SET cash_auto_suspended_at      = now(),
         cash_auto_suspension_reason = concat(
           v_count::text,
           ' hospital cash-payment flags in the last 90 days. Awaiting admin review.'
         ),
         is_available = false
   WHERE id = NEW.engineer_id;

  -- Notify the engineer + admin queue.
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
        jsonb_build_object('reason','cash_payment_flags', 'flag_count', v_count)
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'engineer_auto_suspended notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;

  -- Admin queue notification — best-effort, fan out to every admin.
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
        concat(v_count::text, ' cash-flags in 90 days — review queue.'),
        jsonb_build_object(
          'engineer_id', NEW.engineer_id,
          'flag_count',  v_count
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

DROP TRIGGER IF EXISTS maybe_auto_suspend_engineer_on_cash_flag_trg
  ON public.cash_survey_responses;
CREATE TRIGGER maybe_auto_suspend_engineer_on_cash_flag_trg
  AFTER INSERT ON public.cash_survey_responses
  FOR EACH ROW
  EXECUTE FUNCTION public.maybe_auto_suspend_engineer_on_cash_flag();

-- ---------------------------------------------------------------------
-- Admin RPC to clear the suspension after manual review.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.clear_cash_auto_suspension(
  p_engineer_id uuid,
  p_note        text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.engineers
     SET cash_auto_suspended_at      = NULL,
         cash_auto_suspension_reason = NULL
   WHERE id = p_engineer_id;
  -- We deliberately do NOT flip is_available back automatically.
  -- Admin should review + tell the engineer to manually re-enable.
END;
$$;
REVOKE EXECUTE ON FUNCTION public.clear_cash_auto_suspension(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.clear_cash_auto_suspension(uuid, text) TO authenticated;
