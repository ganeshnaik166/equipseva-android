-- v2.1 PR-D47 — close 5 MEDIUM-severity holes from the 2026-05-07 audit:
--
-- (a) #2 dispute weaponization — hospital files unlimited disputes,
--     including ones admin keeps ruling against. Add a 90-day limit:
--     >=3 prior 'release' resolutions in 90d → reject the new dispute
--     with a clear ERRCODE so the client can show a friendly message.
--
-- (b) #3 commission tier gaming — commission_rate_for_hospital counts
--     ALL completed jobs in 12mo, no minimum amount, no diversity req.
--     Hospital + colluding engineer can churn 50× ₹100 fake jobs to
--     drop from 7%→3%. Tighten:
--       * only count jobs with contracted_amount_rupees >= ₹2000
--       * require count(DISTINCT engineer_id) >= 3 (real diversity)
--     Hospitals concentrated on 1-2 engineers stay at default 7%.
--
-- (c) #4 self-rating via colluding fake hospital — engineer creates a
--     fake hospital account → ₹100 fake job → 5★ self-review. Update
--     recompute_engineer_rating_aggregates so a hospital's reviews
--     count toward an engineer's aggregate ONLY when:
--       * the rated job's contracted_amount_rupees >= ₹500
--       * AND the rating-submitting hospital has rated >=2 distinct
--         engineers across their lifetime (i.e. their pattern looks
--         legitimate, not single-engineer-collusion)
--     Honest first-job hospitals get their review counted as soon as
--     they engage a second engineer.
--
-- (d) #6a profiles_verification_columns_guard bypass — current_user
--     branch missing per the column-guard-bypass-pattern memory. Mirror
--     the 20260506100000 fix.
--
-- (e) #6b bank_accounts_verified_guard bypass — same.
--
-- #1 (Exotel global cap) lives in supabase/functions/request-call-session.
-- #5 (Maps API key restriction) is a Google Cloud Console-only task —
-- documented in V21_ACTIVATION_RUNBOOK.md.

-- ---------- (a) dispute weaponization cap ------------------------------

CREATE OR REPLACE FUNCTION public.dispute_repair_job_escrow(
  p_repair_job_id uuid,
  p_reason        text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_escrow record;
  v_completed_at timestamptz;
  v_prior_release_resolutions int;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF coalesce(length(trim(p_reason)),0) < 10 THEN
    RAISE EXCEPTION 'dispute reason too short (min 10 chars)' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_escrow
    FROM public.repair_job_escrow
   WHERE repair_job_id = p_repair_job_id
   FOR UPDATE;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_escrow.hospital_user_id THEN
    RAISE EXCEPTION 'only hospital can open dispute' USING ERRCODE = '42501';
  END IF;
  IF v_escrow.status <> 'held' THEN
    RAISE EXCEPTION 'escrow not in held state (got %)', v_escrow.status USING ERRCODE = '22023';
  END IF;

  SELECT completed_at INTO v_completed_at
    FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF v_completed_at IS NULL THEN
    RAISE EXCEPTION 'job not completed' USING ERRCODE = '22023';
  END IF;
  IF now() > v_completed_at + interval '48 hours' THEN
    RAISE EXCEPTION 'dispute window closed' USING ERRCODE = '22023';
  END IF;

  -- Weaponization cap: a hospital that's had >=3 disputes ruled in the
  -- engineer's favor (release outcome) in the past 90 days has shown a
  -- pattern of false-flag disputes. Block further dispute filing — they
  -- can still raise the issue with admin via support, but can't trigger
  -- the automatic 'in_dispute' freeze on escrow.
  SELECT count(*) INTO v_prior_release_resolutions
    FROM public.repair_job_escrow
   WHERE hospital_user_id = v_caller
     AND dispute_resolution = 'release'
     AND dispute_resolved_at IS NOT NULL
     AND dispute_resolved_at >= now() - interval '90 days';

  IF v_prior_release_resolutions >= 3 THEN
    RAISE EXCEPTION
      'dispute filing temporarily blocked: too many prior disputes ruled in engineer favor in the last 90 days. Contact support.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.repair_job_escrow
     SET status = 'in_dispute',
         dispute_opened_at = now(),
         dispute_reason = p_reason
   WHERE id = v_escrow.id;

  INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
  VALUES (v_escrow.id, 'disputed', v_caller,
          jsonb_build_object('reason', p_reason));

  RETURN v_escrow.id;
END;
$$;

ALTER FUNCTION public.dispute_repair_job_escrow(uuid, text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.dispute_repair_job_escrow(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.dispute_repair_job_escrow(uuid, text) TO authenticated;

-- ---------- (b) commission tier gaming guard --------------------------

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
  v_distinct_engineers int := 0;
  v_min_amount constant numeric := 2000;
  v_min_distinct constant int := 3;
BEGIN
  IF p_hospital_user_id IS NULL THEN
    RETURN 0.07;
  END IF;

  -- Count + diversity check in one pass. Filters:
  --   * status='completed' (real)
  --   * completed_at within 12 months
  --   * contracted_amount_rupees >= ₹2000 (excludes trivial-fee farms)
  -- Engineer-id NULL rows ignored — those are AMC pool jobs without
  -- a per-job assignment yet, which can't be used for collusion.
  SELECT count(*),
         count(DISTINCT engineer_id)
    INTO v_count, v_distinct_engineers
    FROM public.repair_jobs
   WHERE hospital_user_id = p_hospital_user_id
     AND status::text = 'completed'
     AND completed_at IS NOT NULL
     AND completed_at >= now() - interval '12 months'
     AND COALESCE(contracted_amount_rupees, 0) >= v_min_amount
     AND engineer_id IS NOT NULL;

  -- Diversity gate: a hospital that's only ever used 1-2 engineers
  -- doesn't get the loyalty discount. That stops the "1 fake hospital
  -- + 1 colluding engineer" tier-gaming pattern at zero marginal cost
  -- to legit multi-vendor hospitals.
  IF v_distinct_engineers < v_min_distinct THEN
    RETURN 0.07;
  END IF;

  IF v_count >= 50 THEN
    RETURN 0.03;
  ELSIF v_count >= 10 THEN
    RETURN 0.05;
  ELSE
    RETURN 0.07;
  END IF;
END;
$$;

ALTER FUNCTION public.commission_rate_for_hospital(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.commission_rate_for_hospital(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.commission_rate_for_hospital(uuid) TO authenticated;

-- ---------- (c) self-rating fake-hospital exclusion -------------------

CREATE OR REPLACE FUNCTION public.recompute_engineer_rating_aggregates()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_avg numeric;
  v_cnt int;
  v_min_amount constant numeric := 500;
  v_min_distinct_engineers constant int := 2;
BEGIN
  IF NEW.engineer_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Reviews count toward engineer aggregates only when:
  --   * the job's contracted_amount_rupees >= ₹500 (no trivial fee
  --     reviews inflating the average), AND
  --   * the rating-submitting hospital has rated >= 2 distinct
  --     engineers across their lifetime (their behaviour pattern
  --     looks like a real hospital, not a 1-engineer collusion farm)
  WITH trusted_hospitals AS (
    SELECT hospital_user_id
      FROM public.repair_jobs
     WHERE hospital_rating IS NOT NULL
       AND status::text = 'completed'
       AND engineer_id IS NOT NULL
     GROUP BY hospital_user_id
    HAVING count(DISTINCT engineer_id) >= v_min_distinct_engineers
  )
  SELECT COALESCE(AVG(rj.hospital_rating)::numeric(10,2), 0), COUNT(*)
    INTO v_avg, v_cnt
    FROM public.repair_jobs rj
    JOIN trusted_hospitals th ON th.hospital_user_id = rj.hospital_user_id
   WHERE rj.engineer_id = NEW.engineer_id
     AND rj.hospital_rating IS NOT NULL
     AND rj.status::text = 'completed'
     AND COALESCE(rj.contracted_amount_rupees, 0) >= v_min_amount;

  UPDATE public.engineers
     SET rating_avg = v_avg,
         total_jobs = v_cnt
   WHERE id = NEW.engineer_id;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.recompute_engineer_rating_aggregates() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.recompute_engineer_rating_aggregates() FROM PUBLIC;

-- One-time idempotent backfill so the directory ranking re-reflects the
-- new filtering logic immediately. Engineers whose existing rating_avg
-- came from low-amount or single-engineer-hospital reviews lose those.
WITH trusted_hospitals AS (
  SELECT hospital_user_id
    FROM public.repair_jobs
   WHERE hospital_rating IS NOT NULL
     AND status::text = 'completed'
     AND engineer_id IS NOT NULL
   GROUP BY hospital_user_id
  HAVING count(DISTINCT engineer_id) >= 2
),
agg AS (
  SELECT rj.engineer_id,
         COALESCE(AVG(rj.hospital_rating)::numeric(10,2), 0) AS avg_rating,
         COUNT(*)                                            AS total
    FROM public.repair_jobs rj
    JOIN trusted_hospitals th ON th.hospital_user_id = rj.hospital_user_id
   WHERE rj.hospital_rating IS NOT NULL
     AND rj.status::text = 'completed'
     AND rj.engineer_id IS NOT NULL
     AND COALESCE(rj.contracted_amount_rupees, 0) >= 500
   GROUP BY rj.engineer_id
)
UPDATE public.engineers e
   SET rating_avg = COALESCE(agg.avg_rating, 0),
       total_jobs = COALESCE(agg.total, 0)
  FROM agg
 WHERE e.id = agg.engineer_id;

-- Reset engineers whose only reviews came from now-excluded sources to
-- 0/0 so they don't keep inflated stats from before the filter.
UPDATE public.engineers e
   SET rating_avg = 0, total_jobs = 0
 WHERE NOT EXISTS (
   SELECT 1
     FROM public.repair_jobs rj
     JOIN (
       SELECT hospital_user_id
         FROM public.repair_jobs
        WHERE hospital_rating IS NOT NULL
          AND status::text = 'completed'
          AND engineer_id IS NOT NULL
        GROUP BY hospital_user_id
       HAVING count(DISTINCT engineer_id) >= 2
     ) th ON th.hospital_user_id = rj.hospital_user_id
    WHERE rj.engineer_id = e.id
      AND rj.hospital_rating IS NOT NULL
      AND rj.status::text = 'completed'
      AND COALESCE(rj.contracted_amount_rupees, 0) >= 500
 )
   AND (e.rating_avg <> 0 OR e.total_jobs <> 0);

-- ---------- (d) profiles_verification_columns_guard bypass ------------

CREATE OR REPLACE FUNCTION public.profiles_verification_columns_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  -- service_role + direct postgres + SECDEF-via-postgres + founder + admin bypass.
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
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

ALTER FUNCTION public.profiles_verification_columns_guard() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.profiles_verification_columns_guard() FROM PUBLIC;

-- ---------- (e) bank_accounts_verified_guard bypass -------------------

CREATE OR REPLACE FUNCTION public.bank_accounts_verified_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
BEGIN
  IF v_caller_role = 'service_role'
     OR session_user = 'postgres'
     OR current_user = 'postgres' THEN
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

ALTER FUNCTION public.bank_accounts_verified_guard() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.bank_accounts_verified_guard() FROM PUBLIC;
