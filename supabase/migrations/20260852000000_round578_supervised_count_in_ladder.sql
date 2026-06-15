-- Round 578 — Wire supervised-completion count into r550 cert ladder
--
-- Without this, r576's supervised training program is dormant: a
-- trainee can rack up completed_successful supervision rows but the
-- compute_engineer_certification_tier fn ignores them, so they never
-- promote. r578 plants the missing rung:
--
--   1. ADD min_supervised_completions to engineer_certification_tiers
--      (default 0 — NO behavior change for currently-promoted engineers
--      until the founder explicitly bumps the threshold via the new
--      founder_set_tier_supervised_threshold RPC).
--   2. ADD supervised_completions_at_eval to engineer_certification_progress
--      (snapshot of the count at the most recent compute).
--   3. REPLACE compute_engineer_certification_tier with a version that
--      counts supervised completions and enforces the new threshold.
--   4. ADD founder_set_tier_supervised_threshold RPC (per-tier knob).
--   5. ADD my_supervision_graduation_status RPC (engineer self-view of
--      "X of Y supervised completions toward next tier").
--
-- DEMOTION SAFETY:
--   * All thresholds default to 0 — every currently-promoted engineer
--     satisfies the new check trivially. Founder explicitly opts in
--     to enforcement per tier when ready.
--   * Manual overrides (manual_override=true) continue to bypass
--     computation entirely.

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Schema additions
-- ---------------------------------------------------------------------
ALTER TABLE public.engineer_certification_tiers
  ADD COLUMN IF NOT EXISTS min_supervised_completions int NOT NULL DEFAULT 0
    CHECK (min_supervised_completions >= 0);

ALTER TABLE public.engineer_certification_progress
  ADD COLUMN IF NOT EXISTS supervised_completions_at_eval int NOT NULL DEFAULT 0;

-- ---------------------------------------------------------------------
-- 2. Replace compute_engineer_certification_tier
-- ---------------------------------------------------------------------
-- Same as r550 except: counts successful supervised completions and
-- adds them as a fourth gate in the tier walk.
DROP FUNCTION IF EXISTS public.compute_engineer_certification_tier(uuid);
CREATE OR REPLACE FUNCTION public.compute_engineer_certification_tier(
  p_engineer_user_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_jobs           int := 0;
  v_disputes       int := 0;
  v_dispute_pct    numeric(5,2) := 0;
  v_supervised     int := 0;
  v_verified_tier  text := 'none';
  v_chosen_tier    text := 'none';
  v_existing       record;
  v_t              record;
BEGIN
  SELECT * INTO v_existing
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = p_engineer_user_id
   FOR UPDATE;

  IF FOUND AND v_existing.manual_override THEN
    UPDATE public.engineer_certification_progress
       SET last_computed_at = now()
     WHERE engineer_user_id = p_engineer_user_id;
    RETURN v_existing.current_tier;
  END IF;

  -- Signal 1+2: completed unsupervised jobs + dispute rate
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

  -- Signal 3: r503 verified tier
  SELECT coalesce(cached_highest_tier, 'none')
    INTO v_verified_tier
    FROM public.engineers
   WHERE user_id = p_engineer_user_id;
  IF v_verified_tier IS NULL THEN
    v_verified_tier := 'none';
  END IF;

  -- Signal 4 (r578): successful supervised completions as trainee
  SELECT count(*)::int INTO v_supervised
    FROM public.supervised_job_assignments s
   WHERE s.trainee_user_id = p_engineer_user_id
     AND s.status = 'completed_successful';

  -- Walk tiers desc; pick highest that passes all gates.
  FOR v_t IN
    SELECT tier, min_completed_jobs, max_dispute_rate_pct, min_verified_tier,
           min_supervised_completions, display_order
      FROM public.engineer_certification_tiers
     ORDER BY display_order DESC
  LOOP
    IF v_jobs >= v_t.min_completed_jobs
       AND v_dispute_pct <= v_t.max_dispute_rate_pct
       AND public._verified_tier_at_or_above(v_verified_tier, v_t.min_verified_tier)
       AND v_supervised >= v_t.min_supervised_completions
    THEN
      v_chosen_tier := v_t.tier;
      EXIT;
    END IF;
  END LOOP;

  INSERT INTO public.engineer_certification_progress
    (engineer_user_id, current_tier, jobs_completed, dispute_rate_pct,
     verified_tier_at_eval, supervised_completions_at_eval,
     last_computed_at, updated_at)
  VALUES
    (p_engineer_user_id, v_chosen_tier, v_jobs, v_dispute_pct,
     v_verified_tier, v_supervised,
     now(), now())
  ON CONFLICT (engineer_user_id) DO UPDATE
    SET current_tier                  = EXCLUDED.current_tier,
        jobs_completed                = EXCLUDED.jobs_completed,
        dispute_rate_pct              = EXCLUDED.dispute_rate_pct,
        verified_tier_at_eval         = EXCLUDED.verified_tier_at_eval,
        supervised_completions_at_eval = EXCLUDED.supervised_completions_at_eval,
        last_computed_at              = now(),
        updated_at                    = CASE
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

-- ---------------------------------------------------------------------
-- 3. founder_set_tier_supervised_threshold
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_set_tier_supervised_threshold(text, int);
CREATE OR REPLACE FUNCTION public.founder_set_tier_supervised_threshold(
  p_tier text,
  p_min  int
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_before int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_tier NOT IN ('none','bronze','silver','gold') THEN
    RAISE EXCEPTION 'tier must be none|bronze|silver|gold' USING ERRCODE = '22023';
  END IF;
  IF p_min IS NULL OR p_min < 0 THEN
    RAISE EXCEPTION 'min must be >= 0' USING ERRCODE = '22023';
  END IF;

  SELECT min_supervised_completions INTO v_before
    FROM public.engineer_certification_tiers
   WHERE tier = p_tier
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tier % not found', p_tier USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.engineer_certification_tiers
     SET min_supervised_completions = p_min
   WHERE tier = p_tier;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_set_tier_supervised_threshold',
    p_target_table  => 'engineer_certification_tiers',
    p_target_row_id => NULL,
    p_before_value  => jsonb_build_object('tier', p_tier, 'min_supervised_completions', v_before),
    p_after_value   => jsonb_build_object('tier', p_tier, 'min_supervised_completions', p_min),
    p_reason        => format('Founder set %s supervised threshold to %s', p_tier, p_min)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_set_tier_supervised_threshold(text, int)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_set_tier_supervised_threshold(text, int)
  TO authenticated;

-- ---------------------------------------------------------------------
-- 4. my_supervision_graduation_status — engineer self-view
-- ---------------------------------------------------------------------
-- Returns: current_tier, next_tier (if any), supervised_completed,
-- supervised_required_for_next, plus the same shape for the OTHER
-- gates so engineers see a complete graduation picture.
DROP FUNCTION IF EXISTS public.my_supervision_graduation_status();
CREATE OR REPLACE FUNCTION public.my_supervision_graduation_status()
RETURNS TABLE (
  current_tier                        text,
  next_tier                           text,
  jobs_completed                      int,
  jobs_required_for_next              int,
  dispute_rate_pct                    numeric,
  max_dispute_rate_for_next           numeric,
  verified_tier_at_eval               text,
  min_verified_tier_for_next          text,
  supervised_completed                int,
  supervised_required_for_next        int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller       uuid := auth.uid();
  v_prog         record;
  v_next         record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT current_tier, jobs_completed, dispute_rate_pct,
         verified_tier_at_eval, supervised_completions_at_eval
    INTO v_prog
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = v_caller;

  -- If no progress row yet, treat as 'none' baseline so the
  -- self-view still works (returns gates for bronze).
  IF NOT FOUND THEN
    v_prog.current_tier := 'none';
    v_prog.jobs_completed := 0;
    v_prog.dispute_rate_pct := 0;
    v_prog.verified_tier_at_eval := 'none';
    v_prog.supervised_completions_at_eval := 0;
  END IF;

  -- Next tier = lowest display_order strictly greater than current.
  SELECT t.tier, t.min_completed_jobs, t.max_dispute_rate_pct,
         t.min_verified_tier, t.min_supervised_completions
    INTO v_next
    FROM public.engineer_certification_tiers t
   WHERE t.display_order > (
            SELECT cur.display_order
              FROM public.engineer_certification_tiers cur
             WHERE cur.tier = v_prog.current_tier
          )
   ORDER BY t.display_order ASC
   LIMIT 1;

  RETURN QUERY
  SELECT
    v_prog.current_tier,
    v_next.tier,
    v_prog.jobs_completed,
    v_next.min_completed_jobs,
    v_prog.dispute_rate_pct,
    v_next.max_dispute_rate_pct,
    v_prog.verified_tier_at_eval,
    v_next.min_verified_tier,
    v_prog.supervised_completions_at_eval,
    v_next.min_supervised_completions;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_supervision_graduation_status()
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_supervision_graduation_status()
  TO authenticated;

COMMIT;
