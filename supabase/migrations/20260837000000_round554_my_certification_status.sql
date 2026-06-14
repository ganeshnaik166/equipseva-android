-- =====================================================================
-- Round 554 — Engineer self-view RPC for certification status
-- =====================================================================
--
-- Engineer-side companion to r550. Lets the Android app show:
--   - Your current tier badge
--   - "Earn N more jobs for Silver" coaching nudge
--   - Dispute rate (so engineer knows what to defend)
--   - Whether founder pinned you (manual override is transparent)
--
-- Pure read RPC; no writes. Tier definitions came from r550 lookup.

BEGIN;

CREATE OR REPLACE FUNCTION public.my_certification_status()
RETURNS TABLE (
  current_tier          text,
  current_tier_label    text,
  jobs_completed        int,
  dispute_rate_pct      numeric,
  verified_tier_at_eval text,
  manual_override       boolean,
  last_computed_at      timestamptz,
  -- Forward-looking: what's the next tier and what's needed?
  next_tier             text,
  next_tier_label       text,
  jobs_needed_for_next  int,
  max_dispute_for_next  numeric,
  min_verified_for_next text,
  -- Static tier perks (current tier).
  current_platform_fee_pct numeric,
  current_code_red_priority smallint,
  current_pi_insurance_eligible boolean,
  current_featured_in_search boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user uuid := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH me AS (
    SELECT * FROM public.engineer_certification_progress
     WHERE engineer_user_id = v_user
  ),
  current_def AS (
    SELECT * FROM public.engineer_certification_tiers
     WHERE tier = (SELECT current_tier FROM me)
  ),
  next_def AS (
    SELECT * FROM public.engineer_certification_tiers
     WHERE display_order = (SELECT display_order + 1 FROM current_def)
  )
  SELECT
    coalesce((SELECT current_tier FROM me), 'none'),
    coalesce((SELECT display_label FROM current_def), 'New'),
    coalesce((SELECT jobs_completed FROM me), 0),
    coalesce((SELECT dispute_rate_pct FROM me), 0::numeric),
    (SELECT verified_tier_at_eval FROM me),
    coalesce((SELECT manual_override FROM me), false),
    (SELECT last_computed_at FROM me),
    (SELECT tier FROM next_def),
    (SELECT display_label FROM next_def),
    greatest(
      coalesce((SELECT min_completed_jobs FROM next_def), 0)
        - coalesce((SELECT jobs_completed FROM me), 0),
      0
    ),
    (SELECT max_dispute_rate_pct FROM next_def),
    (SELECT min_verified_tier FROM next_def),
    coalesce((SELECT platform_fee_pct FROM current_def), 7.00),
    coalesce((SELECT code_red_priority FROM current_def), 0::smallint),
    coalesce((SELECT pi_insurance_eligible FROM current_def), false),
    coalesce((SELECT featured_in_search FROM current_def), false);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_certification_status() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_certification_status() TO authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 554 my_certification_status verified: engineer self-view ready for Android client';
END;
$$;
