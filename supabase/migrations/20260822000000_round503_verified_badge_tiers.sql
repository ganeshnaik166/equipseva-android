-- =====================================================================
-- Round 503 — Verified Badge Tiers (v0.4 Phase 5 #6)
-- =====================================================================
--
-- Senior-PM brainstorm: today a single "Verified" pill says nothing
-- about WHAT was verified. Hospitals can't distinguish a barely-
-- onboarded engineer (Aadhaar only) from a fully-vetted one (Aadhaar
-- + PAN + police verification + 50 completed jobs + 4.5 rating).
--
-- Five tiers, computed from existing attributes:
--   - tier_aadhaar  → aadhaar_verified=true
--   - tier_pan      → pan_number not null + verified_status='verified'
--   - tier_gst      → gstin present (engineer has registered business)
--   - tier_bgc      → police_verification_at not null (3rd party check)
--   - tier_pro      → completed_jobs >= 10 AND avg_rating >= 4.5
--
-- A "highest tier" derived label: pro > bgc > gst > pan > aadhaar.
-- Public-facing pill shows the highest. Detail view shows all 5.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Add police_verification fields to engineers (if not present)
-- ---------------------------------------------------------------------
ALTER TABLE public.engineers
  ADD COLUMN IF NOT EXISTS police_verification_at  timestamptz,
  ADD COLUMN IF NOT EXISTS police_verification_ref text;

-- ---------------------------------------------------------------------
-- 2. compute_engineer_tiers — main RPC
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_engineer_tiers(
  p_engineer_user_id uuid
)
RETURNS TABLE(
  tier_aadhaar       boolean,
  tier_pan           boolean,
  tier_gst           boolean,
  tier_bgc           boolean,
  tier_pro           boolean,
  highest_tier       text,
  public_label       text,
  completed_jobs     int,
  avg_rating         numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_eng        record;
  v_p          record;
  v_jobs       int := 0;
  v_avg        numeric;
BEGIN
  -- Anyone authenticated can read tiers (it's a public trust signal).
  -- Internal columns like raw aadhaar number are NOT exposed.
  IF auth.uid() IS NULL AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_eng FROM public.engineers WHERE user_id = p_engineer_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'engineer_not_found' USING ERRCODE = '02000';
  END IF;
  SELECT * INTO v_p FROM public.profiles WHERE id = p_engineer_user_id;

  -- Completed jobs + avg rating
  SELECT count(*)::int, avg(rj.hospital_rating)::numeric(3,2)
    INTO v_jobs, v_avg
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
   WHERE b.engineer_user_id = p_engineer_user_id
     AND rj.status = 'completed'
     AND rj.hospital_rating IS NOT NULL;

  tier_aadhaar := coalesce(v_eng.aadhaar_verified, false);
  tier_pan := (v_eng.pan_number IS NOT NULL
               AND length(trim(v_eng.pan_number)) = 10
               AND v_eng.verification_status::text = 'verified');
  -- GSTIN on engineers row OR profiles row (whichever lives there)
  tier_gst := (v_p.gstin IS NOT NULL AND length(trim(v_p.gstin)) >= 15);
  tier_bgc := (v_eng.police_verification_at IS NOT NULL);
  tier_pro := (coalesce(v_jobs, 0) >= 10 AND coalesce(v_avg, 0) >= 4.5);

  -- Highest tier resolution (escalating)
  highest_tier := CASE
    WHEN tier_pro THEN 'pro'
    WHEN tier_bgc THEN 'bgc'
    WHEN tier_gst THEN 'gst'
    WHEN tier_pan THEN 'pan'
    WHEN tier_aadhaar THEN 'aadhaar'
    ELSE 'none'
  END;

  public_label := CASE highest_tier
    WHEN 'pro'      THEN 'Pro · top-rated'
    WHEN 'bgc'      THEN 'Verified · background-checked'
    WHEN 'gst'      THEN 'Verified · GST-registered'
    WHEN 'pan'      THEN 'Verified · PAN'
    WHEN 'aadhaar'  THEN 'Verified · Aadhaar'
    ELSE 'Pending verification'
  END;

  completed_jobs := coalesce(v_jobs, 0);
  avg_rating := v_avg;
  RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.compute_engineer_tiers(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.compute_engineer_tiers(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Cached column on engineers — denormalized for directory perf
-- ---------------------------------------------------------------------
-- The directory listing query hits ~50-200 rows per scroll; computing
-- tiers per row on each call would be O(N) JOINs. Cache the highest_
-- tier text on the engineers row + a generator function the trigger
-- below calls.
ALTER TABLE public.engineers
  ADD COLUMN IF NOT EXISTS cached_highest_tier text,
  ADD COLUMN IF NOT EXISTS cached_tiers_updated_at timestamptz;

COMMENT ON COLUMN public.engineers.cached_highest_tier IS
  'Round 503 — denormalized highest tier label for directory perf. Refreshed by refresh_engineer_tier_cache(user_id).';

-- ---------------------------------------------------------------------
-- 4. refresh_engineer_tier_cache — call after KYC/job changes
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_engineer_tier_cache(
  p_engineer_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tier text;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  SELECT t.highest_tier
    INTO v_tier
    FROM public.compute_engineer_tiers(p_engineer_user_id) t;

  UPDATE public.engineers
     SET cached_highest_tier = v_tier,
         cached_tiers_updated_at = now()
   WHERE user_id = p_engineer_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refresh_engineer_tier_cache(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.refresh_engineer_tier_cache(uuid)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. refresh_all_engineer_tier_cache — daily cron
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.refresh_all_engineer_tier_cache()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  v_eng   record;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;
  FOR v_eng IN SELECT user_id FROM public.engineers
                WHERE verification_status = 'verified'
                LOOP
    PERFORM public.refresh_engineer_tier_cache(v_eng.user_id);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refresh_all_engineer_tier_cache()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.refresh_all_engineer_tier_cache()
  TO service_role;

-- ---------------------------------------------------------------------
-- 6. Schedule daily cache refresh
-- ---------------------------------------------------------------------
DO $$
BEGIN
  PERFORM cron.schedule(
    'refresh_engineer_tier_cache_daily',
    '15 22 * * *',  -- 22:15 UTC = 03:45 IST
    $cron$SELECT public.refresh_all_engineer_tier_cache();$cron$
  );
  RAISE NOTICE 'round 503: tier cache refresh cron scheduled';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'round 503: pg_cron unavailable; refresh_all_engineer_tier_cache() callable from edge fn / manual';
END;
$$;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='engineers'
      AND column_name='cached_highest_tier'
  ) THEN
    RAISE EXCEPTION 'round 503: cached_highest_tier column not created';
  END IF;
  RAISE NOTICE 'round 503 verified badge tiers verified: 5 tiers + cache column + 3 RPCs ready';
END;
$$;
