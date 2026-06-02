-- Round 425 — make UPI + bank both required at engineer onboarding.
--
-- Today (rounds 422-424) an engineer can have ONE payout method on file
-- (UPI OR bank). Until they add it, the auto-payout queue has a row
-- with payout_method_id=NULL and the worker skips it. The "no method"
-- placeholder list in PayoutMethodScreen was the only nudge.
--
-- This round upgrades that:
--   1. Schema lets an engineer hold BOTH a UPI row and a bank row (one
--      of each), defaulting to UPI so the worker uses the fast IMPS-UPI
--      rail. If UPI ever bounces (RazorpayX 'invalid'), the operator can
--      promote the bank row to default without re-asking the engineer.
--   2. `set_engineer_payout_method` becomes a real UPSERT keyed on
--      (user_id, kind). Saving UPI updates the existing UPI row, doesn't
--      touch the bank row. Saving bank updates bank, doesn't touch UPI.
--   3. New RPC `engineer_has_complete_payout_methods()` returns true
--      when the engineer has BOTH a UPI row and a bank row on file. The
--      Android side calls this during profile fetch (round-425 client
--      change) and folds the result into Profile.hasCompletedV2Onboarding
--      — same gate that already routes engineers to the v0.2.0
--      onboarding screen now also routes them to a payout-onboarding
--      screen.
--
-- Why bank in addition to UPI: the founder's view is that an engineer
-- without a bank account on file is a payout-failure risk we don't want
-- to discover at first payout time (bounced VPA / typo). Holding bank
-- as the fallback rail makes the engineer-side reachability defect
-- detectable at onboarding instead of after the first ₹9.30 attempt.

-- ---------------------------------------------------------------------
-- 1. Constraints — allow one row per (user_id, kind), still one default
-- ---------------------------------------------------------------------
-- The round-422 partial unique on (user_id) WHERE is_default=true
-- enforced "one default per engineer" — still correct, leave it.
-- Add a NEW unique on (user_id, kind) so an engineer can't accidentally
-- accumulate three UPI rows.
ALTER TABLE public.engineer_payout_methods
  DROP CONSTRAINT IF EXISTS engineer_payout_methods_user_kind_uq;
ALTER TABLE public.engineer_payout_methods
  ADD CONSTRAINT engineer_payout_methods_user_kind_uq
  UNIQUE (user_id, kind);

-- ---------------------------------------------------------------------
-- 2. set_engineer_payout_method — UPSERT by (user_id, kind)
-- ---------------------------------------------------------------------
-- Old behaviour: demote-all-and-insert. That blew away any existing row
-- of the other kind because the partial unique only allowed one
-- is_default=true row per user.
--
-- New behaviour:
--   * If a row of the same (user_id, kind) exists -> UPDATE it in place.
--   * Else INSERT a fresh row.
--   * Default promotion: the NEW/updated row becomes default ONLY when
--     the user has no existing default. We never demote a working
--     default just because the engineer edited the OTHER kind. Engineers
--     who want to switch defaults will do so explicitly later (round 426
--     adds the toggle UI).
CREATE OR REPLACE FUNCTION public.set_engineer_payout_method(
  p_kind                      text,
  p_vpa                       text DEFAULT NULL,
  p_vpa_holder_name           text DEFAULT NULL,
  p_bank_account_holder       text DEFAULT NULL,
  p_bank_name                 text DEFAULT NULL,
  p_ifsc                      text DEFAULT NULL,
  p_account_number_encrypted  text DEFAULT NULL,
  p_account_number_last4      text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller     uuid := auth.uid();
  v_role       text;
  v_existing_id uuid;
  v_has_any_default boolean;
  v_should_default  boolean;
  v_id         uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = v_caller;
  IF v_role <> 'engineer' THEN
    RAISE EXCEPTION 'only engineers can set payout method' USING ERRCODE = '42501';
  END IF;

  IF p_kind = 'upi' THEN
    IF p_vpa IS NULL OR length(trim(p_vpa)) = 0 THEN
      RAISE EXCEPTION 'vpa required for upi method' USING ERRCODE = '22023';
    END IF;
    IF p_vpa !~ '^[a-zA-Z0-9._-]+@[a-zA-Z]+$' THEN
      RAISE EXCEPTION 'invalid vpa format' USING ERRCODE = '22023';
    END IF;
  ELSIF p_kind = 'bank' THEN
    IF p_bank_account_holder IS NULL OR length(trim(p_bank_account_holder)) = 0
       OR p_ifsc IS NULL OR length(p_ifsc) <> 11
       OR p_account_number_encrypted IS NULL
       OR p_account_number_last4 IS NULL OR length(p_account_number_last4) <> 4 THEN
      RAISE EXCEPTION 'bank account fields incomplete' USING ERRCODE = '22023';
    END IF;
  ELSE
    RAISE EXCEPTION 'kind must be upi or bank' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_existing_id
    FROM public.engineer_payout_methods
   WHERE user_id = v_caller AND kind = p_kind;

  SELECT EXISTS (
    SELECT 1 FROM public.engineer_payout_methods
     WHERE user_id = v_caller AND is_default = true
  ) INTO v_has_any_default;

  -- Make the new/updated row default iff this is the user's first
  -- method, OR the user only has a row of THIS kind that is the
  -- default (i.e. we're updating their existing default, keep it
  -- default). Otherwise leave the existing default alone.
  v_should_default := NOT v_has_any_default OR (
    v_existing_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.engineer_payout_methods
       WHERE id = v_existing_id AND is_default = true
    )
  );

  IF v_existing_id IS NOT NULL THEN
    UPDATE public.engineer_payout_methods
       SET vpa                       = CASE WHEN p_kind = 'upi' THEN trim(p_vpa) ELSE vpa END,
           vpa_holder_name           = CASE WHEN p_kind = 'upi' THEN nullif(trim(p_vpa_holder_name), '') ELSE vpa_holder_name END,
           bank_account_holder       = CASE WHEN p_kind = 'bank' THEN trim(p_bank_account_holder) ELSE bank_account_holder END,
           bank_name                 = CASE WHEN p_kind = 'bank' THEN nullif(trim(p_bank_name), '') ELSE bank_name END,
           ifsc                      = CASE WHEN p_kind = 'bank' THEN upper(trim(p_ifsc)) ELSE ifsc END,
           account_number_encrypted  = CASE WHEN p_kind = 'bank' THEN p_account_number_encrypted ELSE account_number_encrypted END,
           account_number_last4      = CASE WHEN p_kind = 'bank' THEN p_account_number_last4 ELSE account_number_last4 END,
           is_default                = v_should_default OR is_default,
           -- Re-entering the value should re-arm the unverified state
           -- (so a fresh first-payout proves the new value works).
           status                    = 'unverified',
           -- Drop cached Razorpay handles when the underlying value
           -- changes — the contact/fund_account would otherwise still
           -- point at the OLD VPA/IFSC.
           razorpay_contact_id       = NULL,
           razorpay_fund_account_id  = NULL
     WHERE id = v_existing_id
    RETURNING id INTO v_id;
  ELSE
    -- New row. Demote any other default ONLY if this row will be the
    -- new default (i.e. user previously had no default — shouldn't
    -- happen given partial-unique semantics, but safe to be explicit).
    IF v_should_default THEN
      UPDATE public.engineer_payout_methods
         SET is_default = false
       WHERE user_id = v_caller AND is_default = true;
    END IF;

    INSERT INTO public.engineer_payout_methods (
      user_id, kind, vpa, vpa_holder_name,
      bank_account_holder, bank_name, ifsc,
      account_number_encrypted, account_number_last4,
      is_default, status
    ) VALUES (
      v_caller,
      p_kind,
      CASE WHEN p_kind = 'upi'  THEN trim(p_vpa)             ELSE NULL END,
      CASE WHEN p_kind = 'upi'  THEN nullif(trim(p_vpa_holder_name), '') ELSE NULL END,
      CASE WHEN p_kind = 'bank' THEN trim(p_bank_account_holder) ELSE NULL END,
      CASE WHEN p_kind = 'bank' THEN nullif(trim(p_bank_name), '')      ELSE NULL END,
      CASE WHEN p_kind = 'bank' THEN upper(trim(p_ifsc))      ELSE NULL END,
      CASE WHEN p_kind = 'bank' THEN p_account_number_encrypted ELSE NULL END,
      CASE WHEN p_kind = 'bank' THEN p_account_number_last4    ELSE NULL END,
      v_should_default,
      'unverified'
    ) RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END
$$;
-- Same grants as round 422 (re-stated for clarity; CREATE OR REPLACE
-- preserves them but a future drop-and-recreate would lose them).
REVOKE EXECUTE ON FUNCTION public.set_engineer_payout_method(
  text, text, text, text, text, text, text, text
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.set_engineer_payout_method(
  text, text, text, text, text, text, text, text
) TO authenticated;

-- ---------------------------------------------------------------------
-- 3. engineer_has_complete_payout_methods — gate check
-- ---------------------------------------------------------------------
-- Returns TRUE iff the caller has BOTH a UPI row AND a bank row in
-- engineer_payout_methods. Used by the Android side during profile
-- fetch to decide whether to send the engineer to the payout-onboarding
-- screen. Non-engineers always get TRUE so hospitals + buyers + founder
-- bypass the gate.
CREATE OR REPLACE FUNCTION public.engineer_has_complete_payout_methods()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_role   text;
BEGIN
  IF v_caller IS NULL THEN
    RETURN false;
  END IF;
  SELECT role INTO v_role FROM public.profiles WHERE id = v_caller;
  -- Non-engineers are not gated.
  IF v_role <> 'engineer' THEN
    RETURN true;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.engineer_payout_methods
     WHERE user_id = v_caller AND kind = 'upi'
  ) AND EXISTS (
    SELECT 1 FROM public.engineer_payout_methods
     WHERE user_id = v_caller AND kind = 'bank'
  );
END
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_has_complete_payout_methods() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_has_complete_payout_methods() TO authenticated;
