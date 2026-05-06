-- v2.1 PR-D2: loyalty-based commission tier (T3.17 in the
-- anti-disintermediation strategy memo).
--
-- Default platform commission is 7% (set in the v2 spec + the
-- compute_repair_job_commission_on_complete trigger from
-- 20260506110000). This migration introduces a per-hospital tier:
--   * 50+ completed jobs in trailing 12 months → 3%
--   * 10+ completed jobs in trailing 12 months → 5%
--   * default                                  → 7%
--
-- The cheaper rates trade short-term margin for retention — a hospital
-- doing 100 jobs/yr at 5% generates more revenue than the same
-- hospital churning to a competitor over the marginal 2 percentage
-- points. Standard marketplace move (Uber Pro, Airbnb superhost, etc).
--
-- AMC jobs (repair_jobs.amc_contract_id IS NOT NULL) count toward the
-- loyalty tier even though commission is computed at the AMC pool
-- level rather than per-job. Off-platform deals don't count, by
-- definition — that's the whole point.
--
-- Backfill: existing completed rows are NOT recomputed; their
-- commission stays at whatever the original trigger wrote. Avoids
-- surprise refunds and keeps the audit trail honest.

-- ---------------------------------------------------------------------
-- Helper: commission_rate_for_hospital
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.commission_rate_for_hospital(
  p_hospital_user_id uuid
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF p_hospital_user_id IS NULL THEN
    RETURN 0.07;
  END IF;

  SELECT count(*) INTO v_count
    FROM public.repair_jobs
   WHERE hospital_user_id = p_hospital_user_id
     AND status::text = 'completed'
     AND completed_at IS NOT NULL
     AND completed_at >= now() - interval '12 months';

  IF v_count >= 50 THEN
    RETURN 0.03;
  ELSIF v_count >= 10 THEN
    RETURN 0.05;
  ELSE
    RETURN 0.07;
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.commission_rate_for_hospital(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.commission_rate_for_hospital(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- Replace compute_repair_job_commission_on_complete to use the helper.
-- Body unchanged otherwise — same idempotency, same status-flip gate,
-- same v_amount<=0 short-circuit (so AMC-funded jobs without a
-- contracted amount still bypass the commission write).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_repair_job_commission_on_complete()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_commission_rate numeric;
  v_amount          numeric;
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status::text <> 'completed' THEN
    RETURN NEW;
  END IF;

  v_amount := COALESCE(NEW.contracted_amount_rupees, 0);
  IF v_amount <= 0 THEN
    RETURN NEW;
  END IF;

  -- Tier lookup excludes the current row (it isn't 'completed' yet
  -- when this BEFORE-UPDATE trigger fires) — so the 10th and 50th job
  -- still pay the higher rate, the 11th + 51st cross the threshold.
  -- That matches the strategy memo: "after 10 jobs / 50 jobs", not
  -- "on the 10th / 50th".
  v_commission_rate := public.commission_rate_for_hospital(NEW.hospital_user_id);

  IF COALESCE(NEW.platform_commission, 0) = 0 THEN
    NEW.platform_commission := ROUND(v_amount * v_commission_rate, 2);
  END IF;
  IF COALESCE(NEW.engineer_payout, 0) = 0 THEN
    NEW.engineer_payout := ROUND(v_amount - COALESCE(NEW.platform_commission, 0), 2);
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger already exists from 20260506110000; replacing the function
-- body alone is enough.

-- ---------------------------------------------------------------------
-- Hospital-facing read: my current tier + how many more jobs to next.
-- Surfaces transparency in a future Profile screen ("8 jobs done in
-- the last 12 months — 2 more to unlock 5% commission tier").
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_commission_tier()
RETURNS TABLE (
  completed_12m       int,
  current_rate        numeric,
  next_tier_rate      numeric,
  jobs_to_next_tier   int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_count  int  := 0;
  v_rate   numeric;
  v_next   numeric;
  v_to_next int;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_count
    FROM public.repair_jobs
   WHERE hospital_user_id = v_caller
     AND status::text = 'completed'
     AND completed_at IS NOT NULL
     AND completed_at >= now() - interval '12 months';

  IF v_count >= 50 THEN
    v_rate := 0.03; v_next := NULL; v_to_next := 0;
  ELSIF v_count >= 10 THEN
    v_rate := 0.05; v_next := 0.03; v_to_next := 50 - v_count;
  ELSE
    v_rate := 0.07; v_next := 0.05; v_to_next := 10 - v_count;
  END IF;

  RETURN QUERY SELECT v_count, v_rate, v_next, v_to_next;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_my_commission_tier() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_my_commission_tier() TO authenticated;
