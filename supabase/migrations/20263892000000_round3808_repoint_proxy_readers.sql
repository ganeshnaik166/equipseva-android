-- =====================================================================
-- Round 3808 -- the proxy readers, re-pointed onto the real timestamp
-- =====================================================================
--
-- round3806 added engineers.verification_status_updated_at. Three
-- functions had been repaired during the sweep to DOCUMENT that column's
-- absence rather than invent a proxy; now that it exists, each is
-- re-pointed -- with the backfill handled honestly rather than leaked
-- into founder metrics.
--
-- THE BACKFILL PROBLEM, made explicit: the 16 engineers verified before
-- round3806 all share ONE timestamp -- 2026-09-05 12:59:09.589862+00, the
-- backfill instant. "Signup -> verified" computed from that value is not
-- a latency, it is (migration day - signup day). So:
--
--   * founder_verified_engineers_recent -- lists engineers by REAL
--     verification recency now, and verified_at carries the real stamp.
--     The days column reports the true latency for post-backfill
--     verifications and keeps the established 0 "unknown" sentinel for
--     the 16 legacy rows. For ~30 days all 16 appear in the list, which
--     is what their timestamps honestly say.
--   * build_pved -- the pre-visit trust dossier finally attests a
--     "verification status recorded as of" date instead of NULL, and
--     only when the status actually is verified.
--   * founder_onboarding_velocity_summary -- the two signup->verified
--     percentiles compute from real data but EXCLUDE the backfill
--     instant, because 16 fabricated latencies would swamp the whole
--     90-day cohort window. Until the first post-backfill verification,
--     they keep reporting the 0 "no data" sentinel.
--
-- The exclusion uses the LITERAL backfill timestamp captured at
-- generation time rather than min() over the table, so that later
-- re-verifications can never silently shift which rows are excluded.
--
-- VERIFY executes all three (the dossier WRITE probed and rolled back),
-- with no blanket exception handler (round3802) and assertions on the
-- values, not just on the absence of errors.

BEGIN;

CREATE OR REPLACE FUNCTION public.founder_verified_engineers_recent()
 RETURNS TABLE(user_id uuid, display_name text, state text, city text, verified_at timestamp with time zone, signup_to_verified_days numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  -- round3808: engineers.verification_status_updated_at exists since round3806,
  -- so this report finally means what its name says: engineers VERIFIED in the
  -- last 30 days, with verified_at carrying the real (server-stamped) time.
  -- BACKFILL CAVEAT: the 16 engineers verified before the column existed all
  -- carry the single round3806 backfill instant. For them the true signup ->
  -- verified latency was never recorded, so the days column keeps the
  -- established 0 "unknown" sentinel instead of printing signup->backfill,
  -- which would be a fabricated number. Rows verified after round3806 report
  -- the real latency. (For ~30 days after the backfill, all 16 legacy
  -- engineers appear in this list — the timestamp says so, honestly.)
  RETURN QUERY
  SELECT
    e.user_id,
    coalesce(p.full_name, '(engineer)'),
    coalesce(nullif(trim(p.state), ''), '—'),
    coalesce(nullif(trim(p.city), ''), '—'),
    e.verification_status_updated_at,
    CASE WHEN e.verification_status_updated_at = '2026-09-05 12:59:09.589862+00'::timestamptz
         THEN 0::numeric
         ELSE round((extract(epoch FROM (e.verification_status_updated_at - e.created_at)) / 86400.0)::numeric, 1)
    END
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.verification_status = 'verified'
    AND e.verification_status_updated_at >= now() - interval '30 days'
  ORDER BY e.verification_status_updated_at DESC
  LIMIT 100;
END;
$function$;

CREATE OR REPLACE FUNCTION public.build_pved(p_repair_job_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_job             record;
  v_engineer_user   uuid;
  v_engineer        record;
  v_caller          uuid := auth.uid();
  v_display_name    text;
  v_aadhaar_masked  text;
  v_cert_count      int;
  v_avg_rating      numeric(3,2);
  v_total_jobs      int;
  v_last_5          jsonb;
  v_pved_id         uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
  END IF;

  -- Only hospital on the job, the accepted engineer, or founder can
  -- request the dossier.
  SELECT b.engineer_user_id INTO v_engineer_user
    FROM public.repair_job_bids b
   WHERE b.repair_job_id = p_repair_job_id
     AND b.status = 'accepted'
   LIMIT 1;
  IF v_engineer_user IS NULL THEN
    RAISE EXCEPTION 'no_accepted_engineer_yet' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_job.hospital_user_id
     AND v_caller <> v_engineer_user
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_engineer
    FROM public.engineers
   WHERE user_id = v_engineer_user;

  SELECT
    coalesce((SELECT raw_user_meta_data->>'full_name'
                FROM auth.users WHERE id = v_engineer_user), 'Engineer')
    INTO v_display_name;

  -- Mask Aadhaar: show only last 4 digits, mask first 8 with X.
  IF v_engineer.aadhaar_number IS NOT NULL AND length(v_engineer.aadhaar_number) >= 4 THEN
    v_aadhaar_masked := 'XXXX-XXXX-' || right(v_engineer.aadhaar_number, 4);
  ELSE
    v_aadhaar_masked := NULL;
  END IF;

  v_cert_count := coalesce(jsonb_array_length(v_engineer.certificates), 0);

  -- Aggregate last 5 completed jobs + rating
  SELECT
    avg(hospital_rating)::numeric(3,2),
    count(*)::int
    INTO v_avg_rating, v_total_jobs
    FROM public.repair_jobs
   WHERE status = 'completed'
     AND id IN (
       SELECT rj.id FROM public.repair_jobs rj
       JOIN public.repair_job_bids b ON b.repair_job_id = rj.id
       WHERE b.engineer_user_id = v_engineer_user
         AND b.status = 'accepted'
     );

  SELECT coalesce(jsonb_agg(j ORDER BY j->>'completed_at' DESC), '[]'::jsonb)
    INTO v_last_5
    FROM (
      SELECT jsonb_build_object(
        'job_number', rj.job_number,
        'equipment_brand', rj.equipment_brand,
        'equipment_type', rj.equipment_type,
        'completed_at', rj.completed_at,
        'hospital_rating', rj.hospital_rating
      ) AS j
      FROM public.repair_jobs rj
      JOIN public.repair_job_bids b ON b.repair_job_id = rj.id AND b.status = 'accepted'
      WHERE b.engineer_user_id = v_engineer_user
        AND rj.status = 'completed'
      ORDER BY rj.completed_at DESC NULLS LAST
      LIMIT 5
    ) sub;

  -- Cancel any prior 'issued' dossier for this (job, engineer) so
  -- the UNIQUE constraint allows the new row.
  UPDATE public.pre_visit_engineer_dossiers
     SET status = 'cancelled'
   WHERE repair_job_id = p_repair_job_id
     AND engineer_user_id = v_engineer_user
     AND status = 'issued';

  INSERT INTO public.pre_visit_engineer_dossiers (
    repair_job_id, engineer_user_id, hospital_user_id,
    engineer_display_name, aadhaar_masked_id, verification_status,
    verified_at, certificate_count, oem_cert_summary,
    total_jobs_completed, average_rating, last_5_jobs
  ) VALUES (
    p_repair_job_id, v_engineer_user, v_job.hospital_user_id,
    v_display_name, v_aadhaar_masked,
    coalesce(v_engineer.verification_status::text, 'pending'),
    -- round3808: the real column exists since round3806 and is
    -- server-stamped on every status change, so the dossier can now attest
    -- "verification status recorded as of <ts>". Only attested when the
    -- status actually IS verified; anything else stays NULL. For engineers
    -- verified before round3806 this prints the backfill date — literally
    -- the time the platform first RECORDED verified status, which is the
    -- honest reading given earlier history was never captured.
    CASE WHEN v_engineer.verification_status::text = 'verified'
         THEN v_engineer.verification_status_updated_at
    END,
    v_cert_count, v_engineer.certificates,
    coalesce(v_total_jobs, 0), v_avg_rating, v_last_5
  ) RETURNING id INTO v_pved_id;

  RETURN v_pved_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.founder_onboarding_velocity_summary()
 RETURNS TABLE(eng_cohort_90d bigint, eng_median_signup_to_verified_h numeric, eng_p90_signup_to_verified_h numeric, eng_median_signup_to_first_bid_h numeric, eng_p90_signup_to_first_bid_h numeric, eng_stalled_no_bid_over_7d bigint, hosp_cohort_90d bigint, hosp_median_signup_to_first_job_h numeric, hosp_p90_signup_to_first_job_h numeric, hosp_median_signup_to_first_amc_d numeric, hosp_stalled_no_job_over_7d bigint, avg_signups_per_day_30d numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH eng_cohort AS (
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'engineer'
      AND p.created_at >= now() - interval '90 days'
  ),
  eng_verified AS (
    -- round3808: real latency from engineers.verification_status_updated_at
    -- (round3806), EXCLUDING the 16 legacy engineers whose timestamp is the
    -- round3806 backfill instant — their true approval time was never
    -- recorded, and signup->backfill would be a fabricated latency inflating
    -- both percentiles for the whole 90d cohort window. Until an engineer is
    -- verified post-backfill, this emits no rows and the percentiles keep
    -- falling through to the coalesce(...,0) "no data" sentinel.
    SELECT extract(epoch FROM (e.verification_status_updated_at - ec.created_at)) / 3600.0 AS hours_to_verified
    FROM eng_cohort ec
    JOIN public.engineers e ON e.user_id = ec.id
    WHERE e.verification_status = 'verified'
      AND e.verification_status_updated_at IS NOT NULL
      AND e.verification_status_updated_at <> '2026-09-05 12:59:09.589862+00'::timestamptz
      AND e.verification_status_updated_at >= ec.created_at
  ),
  eng_first_bid AS (
    SELECT extract(epoch FROM (min(b.created_at) - ec.created_at)) / 3600.0 AS hours_to_first_bid
    FROM eng_cohort ec
    JOIN public.repair_job_bids b ON b.engineer_user_id = ec.id
    WHERE b.created_at >= ec.created_at
    GROUP BY ec.id, ec.created_at
  ),
  eng_stalled AS (
    SELECT count(*)::bigint AS n
    FROM eng_cohort ec
    WHERE ec.created_at < now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.repair_job_bids b WHERE b.engineer_user_id = ec.id)
  ),
  hosp_cohort AS (
    -- user_role has no 'hospital' label; the hospital-side role is 'hospital_admin'.
    SELECT p.id, p.created_at
    FROM public.profiles p
    WHERE p.role = 'hospital_admin'
      AND p.created_at >= now() - interval '90 days'
  ),
  hosp_first_job AS (
    SELECT extract(epoch FROM (min(j.created_at) - hc.created_at)) / 3600.0 AS hours_to_first_job
    FROM hosp_cohort hc
    JOIN public.repair_jobs j ON j.hospital_user_id = hc.id
    WHERE j.created_at >= hc.created_at
    GROUP BY hc.id, hc.created_at
  ),
  hosp_first_amc AS (
    SELECT extract(epoch FROM (min(c.created_at) - hc.created_at)) / 86400.0 AS days_to_first_amc
    FROM hosp_cohort hc
    JOIN public.amc_contracts c ON c.hospital_user_id = hc.id
    WHERE c.created_at >= hc.created_at
      AND c.status IN ('active','paused','expired')
    GROUP BY hc.id, hc.created_at
  ),
  hosp_stalled AS (
    SELECT count(*)::bigint AS n
    FROM hosp_cohort hc
    WHERE hc.created_at < now() - interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = hc.id)
  ),
  signups_30d AS (
    SELECT count(*)::numeric / 30.0 AS avg_per_day
    FROM public.profiles p
    WHERE p.role IN ('engineer','hospital_admin')
      AND p.created_at >= now() - interval '30 days'
  )
  SELECT
    (SELECT count(*)::bigint FROM eng_cohort),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_verified))::numeric, 1), 0)::numeric FROM eng_verified),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_verified))::numeric, 1), 0)::numeric FROM eng_verified),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_bid))::numeric, 1), 0)::numeric FROM eng_first_bid),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_first_bid))::numeric, 1), 0)::numeric FROM eng_first_bid),
    (SELECT n FROM eng_stalled),
    (SELECT count(*)::bigint FROM hosp_cohort),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_job))::numeric, 1), 0)::numeric FROM hosp_first_job),
    (SELECT coalesce(round((percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_first_job))::numeric, 1), 0)::numeric FROM hosp_first_job),
    (SELECT coalesce(round((percentile_cont(0.5) WITHIN GROUP (ORDER BY days_to_first_amc))::numeric, 1), 0)::numeric FROM hosp_first_amc),
    (SELECT n FROM hosp_stalled),
    (SELECT round(avg_per_day, 1)::numeric FROM signups_30d);
END;
$function$;

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  v_n     int;
  v_zero  int;
  v_job   uuid;
  v_pved  uuid;
  v_vat   timestamptz;
  v_med   numeric;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub','756a3373-1077-470e-bc0a-79b8d6673ef4','role','authenticated',
                      'email','ganesh1431.dhanavath@gmail.com')::text, true);

  -- 1. the list: 16 backfilled engineers, all with the 0 sentinel and a
  --    non-null verified_at equal to the backfill instant
  SELECT count(*),
         count(*) FILTER (WHERE t.signup_to_verified_days = 0
                            AND t.verified_at = '2026-09-05 12:59:09.589862+00'::timestamptz)
    INTO v_n, v_zero
    FROM public.founder_verified_engineers_recent() t;
  IF v_n < 1 OR v_n <> v_zero THEN
    RAISE EXCEPTION 'round 3808 VERIFY FAILED: verified_recent returned % row(s), % matching the backfill contract', v_n, v_zero;
  END IF;

  -- 2. the velocity summary: runs, and the two verified-latency
  --    percentiles are the 0 sentinel (backfill excluded, no real data yet)
  SELECT t.eng_median_signup_to_verified_h INTO v_med
    FROM public.founder_onboarding_velocity_summary() t;
  IF v_med IS DISTINCT FROM 0 THEN
    RAISE EXCEPTION 'round 3808 VERIFY FAILED: velocity median is % -- backfill leaked into the latency', v_med;
  END IF;

  -- 3. the dossier write: build a real PVED for a job with an assigned
  --    verified engineer, assert verified_at landed non-null, roll back
  -- build_pved resolves the engineer from the ACCEPTED BID, not from
  -- repair_jobs.engineer_id (the first probe picked by engineer_id and got
  -- no_accepted_engineer_yet), so pick the job the same way it will.
  SELECT b.repair_job_id INTO v_job
    FROM public.repair_job_bids b
    JOIN public.engineers e ON e.user_id = b.engineer_user_id
   WHERE b.status = 'accepted'
     AND e.verification_status = 'verified'
   LIMIT 1;
  IF v_job IS NULL THEN
    RAISE EXCEPTION 'round 3808 VERIFY FAILED: no job with a verified engineer to probe build_pved';
  END IF;
  BEGIN
    -- build_pved requires auth.uid() and allows the job hospital, the
    -- accepted engineer, or the founder -- probe as the FOUNDER (the
    -- service_role-only claims first tried here have no sub, so
    -- auth.uid() was NULL and the probe died with auth_required).
    v_pved := public.build_pved(v_job);
    SELECT d.verified_at INTO v_vat
      FROM public.pre_visit_engineer_dossiers d WHERE d.id = v_pved;
    IF v_vat IS NULL THEN
      RAISE EXCEPTION 'round 3808 VERIFY FAILED: dossier verified_at still NULL for a verified engineer';
    END IF;
    RAISE EXCEPTION 'R3808_PROBE_ROLLBACK';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'R3808_PROBE_ROLLBACK' THEN RAISE; END IF;
  END;
  SELECT count(*) INTO v_n FROM public.pre_visit_engineer_dossiers d WHERE d.id = v_pved;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'round 3808 VERIFY FAILED: dossier probe leaked % row(s)', v_n;
  END IF;

  RAISE NOTICE 'round 3808 verified: list contract, velocity sentinel, and a live dossier write (rolled back) all proven';
END
$gate$;

COMMIT;
