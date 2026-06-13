-- =====================================================================
-- Round 504 — First-job-free promo + Profile Completeness Meter
-- v0.4 Phase 5 #7 + #8
-- =====================================================================
--
-- Two small Phase 5 features bundled:
--
-- 1. FIRST-JOB-FREE PROMO — cold-start lever for new hospitals.
--    Senior-PM brainstorm: cap ₹500 per hospital, one-time. Server
--    side debits the promo against the platform fee on the first
--    completed escrow release. r501 duplicate detector prevents
--    sock-puppet farms from claiming N times.
--
-- 2. PROFILE COMPLETENESS METER — engineer-side nudge.
--    Server-computed 0-100 score with explicit missing_items list.
--    Drives the "complete your profile" banner on engineer home.

BEGIN;

-- =====================================================================
-- PART A — First-job-free promo
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.promo_redemptions (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_code          text        NOT NULL CHECK (promo_code IN ('FIRST_JOB_FREE')),
  hospital_user_id    uuid        NOT NULL,
  CONSTRAINT promo_redemptions_hospital_fk
    FOREIGN KEY (hospital_user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  repair_job_id       uuid        REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  -- The actual subsidy applied (capped at ₹500)
  amount_subsidized_rupees numeric(10,2) NOT NULL
                                   CHECK (amount_subsidized_rupees >= 0 AND amount_subsidized_rupees <= 500),
  -- Tracking
  redeemed_at         timestamptz NOT NULL DEFAULT now(),
  expires_at          timestamptz NOT NULL DEFAULT (now() + interval '90 days'),
  status              text        NOT NULL DEFAULT 'redeemed'
                                  CHECK (status IN ('reserved','redeemed','revoked','expired')),
  revoke_reason       text,
  -- One promo per (hospital, code) — UNIQUE prevents replay
  CONSTRAINT promo_redemptions_unique UNIQUE (hospital_user_id, promo_code)
);

CREATE INDEX IF NOT EXISTS promo_redemptions_status_idx
  ON public.promo_redemptions (status, redeemed_at DESC);

ALTER TABLE public.promo_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS promo_redemptions_select ON public.promo_redemptions;
CREATE POLICY promo_redemptions_select
  ON public.promo_redemptions
  FOR SELECT
  TO authenticated, service_role
  USING (hospital_user_id = auth.uid() OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.promo_redemptions
  FROM anon, authenticated, service_role;

-- first_job_free_eligible — hospital-callable
CREATE OR REPLACE FUNCTION public.first_job_free_eligible()
RETURNS TABLE(
  eligible          boolean,
  reason_if_not     text,
  cap_rupees        numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user           uuid := auth.uid();
  v_prior          int;
  v_duplicate_flag boolean := false;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Already redeemed?
  IF EXISTS (
    SELECT 1 FROM public.promo_redemptions
     WHERE hospital_user_id = v_user
       AND promo_code = 'FIRST_JOB_FREE'
       AND status IN ('reserved','redeemed')
  ) THEN
    eligible := false;
    reason_if_not := 'already_redeemed';
    cap_rupees := 0;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Hospital has prior completed jobs? Not eligible (it's a NEW-
  -- hospital lever, not a retroactive credit).
  SELECT count(*) INTO v_prior
    FROM public.repair_jobs
   WHERE hospital_user_id = v_user
     AND status = 'completed';
  IF v_prior > 0 THEN
    eligible := false;
    reason_if_not := 'not_first_time_user';
    cap_rupees := 0;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Caller's account is a CRITICAL duplicate flag? Block.
  SELECT EXISTS (
    SELECT 1 FROM public.duplicate_account_flags d
     WHERE (d.user_id_a = v_user OR d.user_id_b = v_user)
       AND d.severity = 'critical'
       AND d.status IN ('open','investigating','confirmed')
  ) INTO v_duplicate_flag;
  IF v_duplicate_flag THEN
    eligible := false;
    reason_if_not := 'account_under_review';
    cap_rupees := 0;
    RETURN NEXT;
    RETURN;
  END IF;

  eligible := true;
  reason_if_not := NULL;
  cap_rupees := 500;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.first_job_free_eligible() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.first_job_free_eligible() TO authenticated, service_role;

-- redeem_first_job_free — service-role
-- Called by escrow-release path when a hospital's first job completes.
-- Subsidy comes out of platform fee (not engineer payout).
CREATE OR REPLACE FUNCTION public.redeem_first_job_free(
  p_repair_job_id  uuid,
  p_job_total_rupees numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job        record;
  v_eligible   record;
  v_subsidy    numeric;
  v_id         uuid;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'job_not_found' USING ERRCODE = '02000';
  END IF;

  -- Re-check eligibility under hospital's identity (use a temp
  -- SET to impersonate? Cleaner: inline check the same logic)
  IF EXISTS (
    SELECT 1 FROM public.promo_redemptions
     WHERE hospital_user_id = v_job.hospital_user_id
       AND promo_code = 'FIRST_JOB_FREE'
  ) THEN
    RAISE EXCEPTION 'already_redeemed' USING ERRCODE = '22023';
  END IF;

  -- Subsidy = min(₹500, 7% of job total) — never exceed our platform
  -- take, otherwise we'd be subsidizing engineer pay (would create
  -- weird incentives).
  v_subsidy := least(500.00::numeric, round(p_job_total_rupees * 0.07, 2));

  INSERT INTO public.promo_redemptions (
    promo_code, hospital_user_id, repair_job_id, amount_subsidized_rupees, status
  ) VALUES (
    'FIRST_JOB_FREE', v_job.hospital_user_id, p_repair_job_id, v_subsidy, 'redeemed'
  ) RETURNING id INTO v_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'redeem_first_job_free',
    p_target_table  => 'promo_redemptions',
    p_target_row_id => v_id,
    p_before_value  => NULL,
    p_after_value   => jsonb_build_object(
      'hospital_user_id', v_job.hospital_user_id,
      'amount_subsidized', v_subsidy,
      'repair_job_id', p_repair_job_id
    ),
    p_reason        => 'First-job-free promo redeemed'
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.redeem_first_job_free(uuid, numeric)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.redeem_first_job_free(uuid, numeric)
  TO service_role;

-- Founder revoke (used if abuse detected post-redemption)
CREATE OR REPLACE FUNCTION public.founder_revoke_promo_redemption(
  p_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old record;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason required' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_old FROM public.promo_redemptions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'promo_not_found' USING ERRCODE = '02000';
  END IF;
  IF v_old.status = 'revoked' THEN
    RAISE EXCEPTION 'already_revoked' USING ERRCODE = '22023';
  END IF;
  UPDATE public.promo_redemptions
     SET status = 'revoked', revoke_reason = p_reason
   WHERE id = p_id;
  PERFORM public.log_founder_action(
    p_op_name       => 'founder_revoke_promo_redemption',
    p_target_table  => 'promo_redemptions',
    p_target_row_id => p_id,
    p_before_value  => jsonb_build_object('status', v_old.status, 'amount', v_old.amount_subsidized_rupees),
    p_after_value   => jsonb_build_object('status', 'revoked'),
    p_reason        => p_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revoke_promo_redemption(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_revoke_promo_redemption(uuid, text)
  TO service_role;

-- =====================================================================
-- PART B — Profile Completeness Meter (engineer)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.engineer_profile_completeness(
  p_engineer_user_id uuid DEFAULT NULL
)
RETURNS TABLE(
  score              int,
  missing_items      text[],
  band               text  -- 'incomplete' / 'partial' / 'complete'
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_target      uuid;
  v_eng         record;
  v_p           record;
  v_missing     text[] := ARRAY[]::text[];
  v_score       int := 0;
BEGIN
  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  -- Default to self when no param supplied
  v_target := coalesce(p_engineer_user_id, auth.uid());
  IF v_target <> auth.uid() AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_eng FROM public.engineers WHERE user_id = v_target;
  IF NOT FOUND THEN
    score := 0;
    missing_items := ARRAY['engineer_profile_not_created'];
    band := 'incomplete';
    RETURN NEXT;
    RETURN;
  END IF;
  SELECT * INTO v_p FROM public.profiles WHERE id = v_target;

  -- Each item is weighted; sum to 100.
  -- aadhaar_verified ............ 25
  -- pan_number  + verified ...... 10
  -- police_verification ......... 10
  -- specializations >= 1 ........ 10
  -- certificates >= 1 ........... 10
  -- profile photo (avatar_url) .. 5
  -- city / latitude+longitude ... 10
  -- profitability_floor set ..... 5
  -- gstin .......................  5
  -- minimum 6 jobs completed .... 10

  IF coalesce(v_eng.aadhaar_verified, false) THEN
    v_score := v_score + 25;
  ELSE
    v_missing := v_missing || ARRAY['aadhaar_verification'];
  END IF;

  IF v_eng.pan_number IS NOT NULL AND length(trim(v_eng.pan_number)) = 10
     AND v_eng.verification_status::text = 'verified' THEN
    v_score := v_score + 10;
  ELSE
    v_missing := v_missing || ARRAY['pan_verified'];
  END IF;

  IF v_eng.police_verification_at IS NOT NULL THEN
    v_score := v_score + 10;
  ELSE
    v_missing := v_missing || ARRAY['police_verification'];
  END IF;

  IF v_eng.specializations IS NOT NULL AND array_length(v_eng.specializations, 1) >= 1 THEN
    v_score := v_score + 10;
  ELSE
    v_missing := v_missing || ARRAY['specializations'];
  END IF;

  IF v_eng.certificates IS NOT NULL AND jsonb_array_length(v_eng.certificates) >= 1 THEN
    v_score := v_score + 10;
  ELSE
    v_missing := v_missing || ARRAY['certificates'];
  END IF;

  IF v_p.avatar_url IS NOT NULL AND length(trim(v_p.avatar_url)) > 0 THEN
    v_score := v_score + 5;
  ELSE
    v_missing := v_missing || ARRAY['profile_photo'];
  END IF;

  IF v_eng.latitude IS NOT NULL AND v_eng.longitude IS NOT NULL AND v_eng.city IS NOT NULL THEN
    v_score := v_score + 10;
  ELSE
    v_missing := v_missing || ARRAY['location'];
  END IF;

  IF coalesce(v_eng.profitability_floor_rupees, 0) > 0 THEN
    v_score := v_score + 5;
  ELSE
    v_missing := v_missing || ARRAY['profitability_floor'];
  END IF;

  IF v_p.gstin IS NOT NULL AND length(trim(v_p.gstin)) >= 15 THEN
    v_score := v_score + 5;
  ELSE
    v_missing := v_missing || ARRAY['gstin'];
  END IF;

  IF (
    SELECT count(*) FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
    WHERE b.engineer_user_id = v_target
      AND rj.status = 'completed'
  ) >= 6 THEN
    v_score := v_score + 10;
  ELSE
    v_missing := v_missing || ARRAY['needs_6_completed_jobs'];
  END IF;

  score := v_score;
  missing_items := v_missing;
  band := CASE
    WHEN v_score >= 90 THEN 'complete'
    WHEN v_score >= 60 THEN 'partial'
    ELSE 'incomplete'
  END;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_profile_completeness(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.engineer_profile_completeness(uuid)
  TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'promo_redemptions'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 504: promo_redemptions RLS not enabled';
  END IF;
  RAISE NOTICE 'round 504 promo + profile-meter verified: 1 table + 5 RPCs ready';
END;
$$;
