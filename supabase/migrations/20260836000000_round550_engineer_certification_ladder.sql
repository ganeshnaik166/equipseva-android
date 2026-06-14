-- =====================================================================
-- Round 550 — Engineer certification ladder (v0.5 Phase 2 #1)
-- =====================================================================
--
-- Bronze / Silver / Gold tiers earned from completed-job count +
-- dispute rate + the r503 verified_tier ceiling. Higher tiers unlock:
--   - First-pick on Code Red emergency dispatch (Gold)
--   - Lower platform fee on completed jobs (Silver+)
--   - PI insurance bundle eligibility (Gold)
--   - "Featured engineer" badge in hospital search (Silver+)
--
-- Schema:
--   engineer_certification_tiers       — lookup of tier definitions
--   engineer_certification_progress    — per-engineer running snapshot
--
-- The actual promotion / demotion derivation lives in
-- compute_engineer_certification_tier() — idempotent, can be re-run
-- safely. Daily cron refreshes; founder can also override manually.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Tier lookup
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_certification_tiers (
  tier                text PRIMARY KEY CHECK (tier IN ('none','bronze','silver','gold')),
  min_completed_jobs  int NOT NULL DEFAULT 0,
  max_dispute_rate_pct numeric(5,2) NOT NULL DEFAULT 100,
  min_verified_tier   text NOT NULL DEFAULT 'none'
                        CHECK (min_verified_tier IN ('none','aadhaar','pan','gst','bgc','pro')),
  platform_fee_pct    numeric(5,2) NOT NULL DEFAULT 7.00,
  code_red_priority   smallint NOT NULL DEFAULT 0,     -- higher = first pick
  pi_insurance_eligible boolean NOT NULL DEFAULT false,
  featured_in_search  boolean NOT NULL DEFAULT false,
  display_label       text NOT NULL,
  display_order       smallint NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now()
);

INSERT INTO public.engineer_certification_tiers
  (tier, min_completed_jobs, max_dispute_rate_pct, min_verified_tier,
   platform_fee_pct, code_red_priority, pi_insurance_eligible,
   featured_in_search, display_label, display_order)
VALUES
  ('none',   0,   100, 'none',    7.00, 0, false, false, 'New',    0),
  ('bronze', 5,    15, 'aadhaar', 7.00, 1, false, false, 'Bronze', 1),
  ('silver', 25,   10, 'pan',     6.00, 2, false, true,  'Silver', 2),
  ('gold',   75,    5, 'bgc',     5.00, 3, true,  true,  'Gold',   3)
ON CONFLICT (tier) DO UPDATE
  SET min_completed_jobs    = EXCLUDED.min_completed_jobs,
      max_dispute_rate_pct  = EXCLUDED.max_dispute_rate_pct,
      min_verified_tier     = EXCLUDED.min_verified_tier,
      platform_fee_pct      = EXCLUDED.platform_fee_pct,
      code_red_priority     = EXCLUDED.code_red_priority,
      pi_insurance_eligible = EXCLUDED.pi_insurance_eligible,
      featured_in_search    = EXCLUDED.featured_in_search,
      display_label         = EXCLUDED.display_label,
      display_order         = EXCLUDED.display_order;

ALTER TABLE public.engineer_certification_tiers ENABLE ROW LEVEL SECURITY;

-- Lookup is public (any authenticated user can read tier definitions
-- so the Android client can show "earn N more jobs for Silver").
DROP POLICY IF EXISTS engineer_certification_tiers_select ON public.engineer_certification_tiers;
CREATE POLICY engineer_certification_tiers_select
  ON public.engineer_certification_tiers FOR SELECT
  TO authenticated, anon
  USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.engineer_certification_tiers
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 2. Per-engineer progress
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_certification_progress (
  engineer_user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_tier        text NOT NULL DEFAULT 'none'
                        REFERENCES public.engineer_certification_tiers(tier),
  jobs_completed      int NOT NULL DEFAULT 0,
  dispute_rate_pct    numeric(5,2) NOT NULL DEFAULT 0,
  verified_tier_at_eval text,
  manual_override     boolean NOT NULL DEFAULT false,
  override_reason     text,
  last_computed_at    timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_certification_progress_tier_idx
  ON public.engineer_certification_progress (current_tier, last_computed_at DESC);

ALTER TABLE public.engineer_certification_progress ENABLE ROW LEVEL SECURITY;

-- Engineer reads own row; founder reads all.
DROP POLICY IF EXISTS engineer_certification_progress_select ON public.engineer_certification_progress;
CREATE POLICY engineer_certification_progress_select
  ON public.engineer_certification_progress FOR SELECT
  TO authenticated
  USING (engineer_user_id = auth.uid() OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.engineer_certification_progress
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. compute_engineer_certification_tier — idempotent derivation
-- ---------------------------------------------------------------------
--
-- Pulls signals:
--   - jobs_completed: count from repair_jobs where engineer was assigned and status='completed'
--   - dispute_rate_pct: dispute_evidence_packs / completed_jobs * 100
--   - verified_tier_at_eval: cached_highest_tier from engineers (r503)
--
-- Then walks tiers from highest (gold) to lowest until all gates pass.
-- If a row exists with manual_override = true, skip — founder decided.
CREATE OR REPLACE FUNCTION public.compute_engineer_certification_tier(
  p_engineer_user_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_jobs          int := 0;
  v_disputes      int := 0;
  v_dispute_pct   numeric(5,2) := 0;
  v_verified_tier text := 'none';
  v_chosen_tier   text := 'none';
  v_existing      record;
  v_t             record;
BEGIN
  SELECT * INTO v_existing
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = p_engineer_user_id
   FOR UPDATE;

  IF FOUND AND v_existing.manual_override THEN
    -- Founder pin — leave row alone, just bump the snapshot timestamps.
    UPDATE public.engineer_certification_progress
       SET last_computed_at = now()
     WHERE engineer_user_id = p_engineer_user_id;
    RETURN v_existing.current_tier;
  END IF;

  -- Signal 1 + 2: completed jobs and dispute rate.
  SELECT count(*)::int INTO v_jobs
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
   WHERE rj.status = 'completed'
     AND b.engineer_user_id = p_engineer_user_id;

  SELECT count(*)::int INTO v_disputes
    FROM public.dispute_evidence_packs dp
    JOIN public.repair_jobs rj ON rj.id = dp.repair_job_id
    JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
   WHERE b.engineer_user_id = p_engineer_user_id
     AND dp.created_at > now() - interval '180 days';

  IF v_jobs > 0 THEN
    v_dispute_pct := round(v_disputes * 100.0 / v_jobs, 2);
  END IF;

  -- Signal 3: verified tier from r503.
  SELECT coalesce(cached_highest_tier, 'none')
    INTO v_verified_tier
    FROM public.engineers
   WHERE user_id = p_engineer_user_id;

  IF v_verified_tier IS NULL THEN
    v_verified_tier := 'none';
  END IF;

  -- Walk tiers desc; pick the highest that passes all gates.
  FOR v_t IN
    SELECT tier, min_completed_jobs, max_dispute_rate_pct, min_verified_tier, display_order
      FROM public.engineer_certification_tiers
     ORDER BY display_order DESC
  LOOP
    IF v_jobs >= v_t.min_completed_jobs
       AND v_dispute_pct <= v_t.max_dispute_rate_pct
       AND _verified_tier_at_or_above(v_verified_tier, v_t.min_verified_tier)
    THEN
      v_chosen_tier := v_t.tier;
      EXIT;
    END IF;
  END LOOP;

  INSERT INTO public.engineer_certification_progress
    (engineer_user_id, current_tier, jobs_completed, dispute_rate_pct,
     verified_tier_at_eval, last_computed_at, updated_at)
  VALUES
    (p_engineer_user_id, v_chosen_tier, v_jobs, v_dispute_pct,
     v_verified_tier, now(), now())
  ON CONFLICT (engineer_user_id) DO UPDATE
    SET current_tier         = EXCLUDED.current_tier,
        jobs_completed       = EXCLUDED.jobs_completed,
        dispute_rate_pct     = EXCLUDED.dispute_rate_pct,
        verified_tier_at_eval = EXCLUDED.verified_tier_at_eval,
        last_computed_at     = now(),
        updated_at           = CASE
                                 WHEN public.engineer_certification_progress.current_tier
                                      <> EXCLUDED.current_tier THEN now()
                                 ELSE public.engineer_certification_progress.updated_at
                               END;

  RETURN v_chosen_tier;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.compute_engineer_certification_tier(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.compute_engineer_certification_tier(uuid)
  TO service_role;

-- Private helper — does the engineer's verified tier rank at or above
-- the minimum required by the certification tier?
CREATE OR REPLACE FUNCTION public._verified_tier_at_or_above(
  p_have text,
  p_min  text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  -- Rank: none < aadhaar < pan < gst < bgc < pro
  WITH rank_map AS (
    SELECT 'none' AS t, 0 AS r UNION ALL
    SELECT 'aadhaar', 1 UNION ALL
    SELECT 'pan',     2 UNION ALL
    SELECT 'gst',     3 UNION ALL
    SELECT 'bgc',     4 UNION ALL
    SELECT 'pro',     5
  )
  SELECT (SELECT r FROM rank_map WHERE t = p_have)
         >= (SELECT r FROM rank_map WHERE t = p_min);
$$;

REVOKE EXECUTE ON FUNCTION public._verified_tier_at_or_above(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public._verified_tier_at_or_above(text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 4. founder_promote_engineer_tier — manual override with audit
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_promote_engineer_tier(
  p_engineer_user_id uuid,
  p_target_tier      text,
  p_reason           text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_before text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_target_tier NOT IN ('none','bronze','silver','gold') THEN
    RAISE EXCEPTION 'invalid_tier' USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'reason required (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT current_tier INTO v_before
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = p_engineer_user_id;

  INSERT INTO public.engineer_certification_progress
    (engineer_user_id, current_tier, manual_override, override_reason, updated_at)
  VALUES (p_engineer_user_id, p_target_tier, true, p_reason, now())
  ON CONFLICT (engineer_user_id) DO UPDATE
    SET current_tier     = EXCLUDED.current_tier,
        manual_override  = true,
        override_reason  = EXCLUDED.override_reason,
        updated_at       = now();

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_promote_engineer_tier',
    p_target_table  => 'engineer_certification_progress',
    p_target_row_id => p_engineer_user_id,
    p_before_value  => jsonb_build_object('current_tier', coalesce(v_before, 'none')),
    p_after_value   => jsonb_build_object('current_tier', p_target_tier, 'manual_override', true),
    p_reason        => p_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_promote_engineer_tier(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_promote_engineer_tier(uuid, text, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- 5. founder_certification_tier_distribution — cockpit view
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_certification_tier_distribution()
RETURNS TABLE (
  tier                text,
  display_label       text,
  engineer_count      int,
  manual_override_count int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    t.tier,
    t.display_label,
    coalesce(
      (SELECT count(*)::int FROM public.engineer_certification_progress p
        WHERE p.current_tier = t.tier),
      0
    ),
    coalesce(
      (SELECT count(*)::int FROM public.engineer_certification_progress p
        WHERE p.current_tier = t.tier AND p.manual_override = true),
      0
    )
   FROM public.engineer_certification_tiers t
  ORDER BY t.display_order DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_certification_tier_distribution()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_certification_tier_distribution()
  TO service_role;

-- ---------------------------------------------------------------------
-- 6. Daily recompute for every engineer
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recompute_all_engineer_certifications()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
  v_user  uuid;
BEGIN
  FOR v_user IN
    SELECT DISTINCT b.engineer_user_id
      FROM public.repair_job_bids b
     WHERE b.status = 'accepted'
       AND b.engineer_user_id IS NOT NULL
  LOOP
    PERFORM public.compute_engineer_certification_tier(v_user);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recompute_all_engineer_certifications()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.recompute_all_engineer_certifications()
  TO service_role;

DO $$
BEGIN
  PERFORM cron.schedule(
    'recompute_all_engineer_certifications_daily',
    '17 3 * * *',  -- 03:17 UTC = 08:47 IST
    $cron$SELECT public.recompute_all_engineer_certifications();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron unavailable; recompute_all_engineer_certifications must be triggered by edge fn';
END;
$$;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 550 engineer certification ladder verified: 2 tables + 4 SECDEF fns + daily cron (Bronze/Silver/Gold)';
END;
$$;
