-- Two more trust-column self-forgery surfaces caught:
--
-- 1. profiles.email_verified + profiles.phone_verified are mirrored
--    from auth.users via a SECURITY DEFINER trigger (per migration
--    20260428060000_profile_email_phone_verified_mirror) — they should
--    never be set by client REST. Default column grants let
--    authenticated UPDATE both to true, faking OTP-confirmed status
--    on the "Verify phone" / "Verify email" CTA gate.
--
-- 2. bank_accounts.verified is the admin's "I cleared this payout
--    account" stamp. Default grants let any signed-in user — including
--    anon, who shouldn't touch this table at all — UPDATE verified=true
--    on their own row before any admin review.
--
-- Add BEFORE INSERT/UPDATE triggers that block non-admin writes to
-- those specific columns. Existing guard_profile_self_escalation
-- handles role / role_confirmed / organization_id transitions; this
-- trigger is additive, narrowly focused on the verification booleans.
-- bank_accounts also gets anon revoked entirely while we're here.

REVOKE INSERT, UPDATE, SELECT, DELETE ON public.bank_accounts FROM anon;

CREATE OR REPLACE FUNCTION public.profiles_verification_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role' OR session_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF coalesce(NEW.email_verified, false) <> false
       OR coalesce(NEW.phone_verified, false) <> false THEN
      RAISE EXCEPTION 'profiles.email_verified / phone_verified must start false'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.email_verified IS DISTINCT FROM OLD.email_verified
     OR NEW.phone_verified IS DISTINCT FROM OLD.phone_verified THEN
    RAISE EXCEPTION
      'email_verified / phone_verified are auth-trigger-driven; client cannot write'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_verification_columns_guard_trg ON public.profiles;
CREATE TRIGGER profiles_verification_columns_guard_trg
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.profiles_verification_columns_guard();

REVOKE ALL ON FUNCTION public.profiles_verification_columns_guard() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.bank_accounts_verified_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role' OR session_user = 'postgres' THEN
    RETURN NEW;
  END IF;
  IF public.is_founder() OR public.is_admin(auth.uid()) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF coalesce(NEW.verified, false) <> false THEN
      RAISE EXCEPTION 'bank_accounts.verified must start false'
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.verified IS DISTINCT FROM OLD.verified THEN
    RAISE EXCEPTION 'bank_accounts.verified is admin-only'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bank_accounts_verified_guard_trg ON public.bank_accounts;
CREATE TRIGGER bank_accounts_verified_guard_trg
  BEFORE INSERT OR UPDATE ON public.bank_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.bank_accounts_verified_guard();

REVOKE ALL ON FUNCTION public.bank_accounts_verified_guard() FROM PUBLIC;
