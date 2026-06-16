-- =====================================================================
-- Round 593 — Engineer tier history ledger (forensic + engineer-facing)
-- =====================================================================
--
-- The r550/r578 compute_engineer_certification_tier idempotently
-- overwrites engineer_certification_progress on every 03:17 cron tick.
-- That gives us "current state" forever but ZERO history: if a founder
-- asks "when did engineer X go from bronze to silver?", the answer is
-- "we can't tell — the progress row's updated_at moves with every
-- non-tier change too (jobs counter, dispute pct snapshot)."
--
-- r593 plants an append-only ledger that captures every tier change
-- the compute fn produces, plus founder manual overrides. Two read
-- RPCs:
--
--   my_tier_history()                — engineer self-view (own rows
--                                       only, auth.uid()-scoped)
--   founder_tier_history_recent()    — founder ops view (last 100,
--                                       founder-only via is_founder())
--
-- The compute fn is REPLACED here (not just amended) to write the
-- ledger row INSIDE the same transaction as the progress UPDATE, so
-- a rolled-back compute also rolls back its history row — preventing
-- "ghost" promotions in history that the progress table doesn't agree
-- with.
--
-- Privacy/safety:
--   - my_tier_history is auth.uid()-scoped server-side; engineers see
--     only their own moves
--   - founder_tier_history_recent is is_founder()-gated
--   - Append-only: no UPDATE/DELETE RPCs exposed; service_role retains
--     direct table access for the compute fn but normal callers can't
--     mutate

BEGIN;

-- ----------------------------------------------------------------
-- 1. Schema — append-only ledger
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.engineer_tier_history (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id     uuid NOT NULL
                         REFERENCES auth.users(id) ON DELETE CASCADE,
  prev_tier            text NOT NULL
                         CHECK (prev_tier IN ('none','bronze','silver','gold')),
  new_tier             text NOT NULL
                         CHECK (new_tier IN ('none','bronze','silver','gold')),
  change_kind          text NOT NULL
                         CHECK (change_kind IN ('cron_compute','founder_override','founder_promote','founder_demote')),
  reason               text,
  jobs_completed_at_change            int,
  dispute_rate_pct_at_change          numeric(5,2),
  supervised_completions_at_change    int,
  verified_tier_at_change             text,
  changed_at           timestamptz NOT NULL DEFAULT now(),

  -- Self-transitions (bronze→bronze) are not interesting history; the
  -- compute fn won't write them, but the table-level check is belt-
  -- and-braces.
  CONSTRAINT engineer_tier_history_real_change
    CHECK (prev_tier <> new_tier)
);

CREATE INDEX IF NOT EXISTS engineer_tier_history_eng_idx
  ON public.engineer_tier_history (engineer_user_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS engineer_tier_history_recent_idx
  ON public.engineer_tier_history (changed_at DESC);

ALTER TABLE public.engineer_tier_history ENABLE ROW LEVEL SECURITY;

-- Deny-all default. Reads via SECDEF RPCs only.
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.engineer_tier_history
  FROM anon, authenticated;

-- ----------------------------------------------------------------
-- 2. Replace compute_engineer_certification_tier to emit history
-- ----------------------------------------------------------------
-- Same as r578 except: after the progress upsert, if the chosen_tier
-- differs from the prior current_tier, write an engineer_tier_history
-- row inside the same transaction.
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
  v_prev_tier      text := 'none';
  v_had_prior      boolean := false;
  v_existing       record;
  v_t              record;
BEGIN
  SELECT * INTO v_existing
    FROM public.engineer_certification_progress
   WHERE engineer_user_id = p_engineer_user_id
   FOR UPDATE;

  IF FOUND THEN
    v_had_prior := true;
    v_prev_tier := v_existing.current_tier;
  END IF;

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

  -- r593: write history if the chosen tier differs from the prior.
  -- First-ever compute (no prior row) → only log if chosen <> 'none'
  -- so we don't spam the ledger with "none→none" on cold-start runs.
  IF v_had_prior AND v_prev_tier <> v_chosen_tier THEN
    INSERT INTO public.engineer_tier_history
      (engineer_user_id, prev_tier, new_tier, change_kind, reason,
       jobs_completed_at_change, dispute_rate_pct_at_change,
       supervised_completions_at_change, verified_tier_at_change)
    VALUES
      (p_engineer_user_id, v_prev_tier, v_chosen_tier, 'cron_compute', NULL,
       v_jobs, v_dispute_pct, v_supervised, v_verified_tier);
  ELSIF NOT v_had_prior AND v_chosen_tier <> 'none' THEN
    INSERT INTO public.engineer_tier_history
      (engineer_user_id, prev_tier, new_tier, change_kind, reason,
       jobs_completed_at_change, dispute_rate_pct_at_change,
       supervised_completions_at_change, verified_tier_at_change)
    VALUES
      (p_engineer_user_id, 'none', v_chosen_tier, 'cron_compute', NULL,
       v_jobs, v_dispute_pct, v_supervised, v_verified_tier);
  END IF;

  RETURN v_chosen_tier;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.compute_engineer_certification_tier(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.compute_engineer_certification_tier(uuid)
  TO service_role;

-- ----------------------------------------------------------------
-- 3. my_tier_history — engineer self-view (own rows only)
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.my_tier_history();
CREATE OR REPLACE FUNCTION public.my_tier_history()
RETURNS TABLE (
  id                   uuid,
  prev_tier            text,
  new_tier             text,
  change_kind          text,
  reason               text,
  changed_at           timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    h.id,
    h.prev_tier,
    h.new_tier,
    h.change_kind,
    h.reason,
    h.changed_at
  FROM public.engineer_tier_history h
  WHERE h.engineer_user_id = v_caller
  ORDER BY h.changed_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.my_tier_history() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.my_tier_history() TO authenticated;

-- ----------------------------------------------------------------
-- 4. founder_tier_history_recent — founder ops view
-- ----------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_tier_history_recent(int);
CREATE OR REPLACE FUNCTION public.founder_tier_history_recent(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  id                   uuid,
  engineer_user_id     uuid,
  prev_tier            text,
  new_tier             text,
  change_kind          text,
  reason               text,
  jobs_completed_at_change            int,
  dispute_rate_pct_at_change          numeric,
  supervised_completions_at_change    int,
  verified_tier_at_change             text,
  changed_at           timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit int;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  v_limit := least(greatest(coalesce(p_limit, 100), 1), 500);

  RETURN QUERY
  SELECT
    h.id,
    h.engineer_user_id,
    h.prev_tier,
    h.new_tier,
    h.change_kind,
    h.reason,
    h.jobs_completed_at_change,
    h.dispute_rate_pct_at_change,
    h.supervised_completions_at_change,
    h.verified_tier_at_change,
    h.changed_at
  FROM public.engineer_tier_history h
  ORDER BY h.changed_at DESC
  LIMIT v_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_tier_history_recent(int)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_tier_history_recent(int)
  TO authenticated;

COMMIT;
