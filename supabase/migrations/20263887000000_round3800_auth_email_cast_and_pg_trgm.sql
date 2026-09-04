-- =====================================================================
-- Round 3800 -- the last two real defects in the sweep's bespoke tail
-- =====================================================================
--
-- round3799 repaired 101 functions and its gate reported 6 still
-- statically broken. Four of those six are FALSE POSITIVES, confirmed by
-- execution, not by argument (see the note at the bottom). These are the
-- two that were real.
--
-- 1. founder_dispute_queue -- 42804, "Returned type character
--    varying(255) does not match expected type text in column 5".
--    `auth.users.email` is varchar(255); the function declares
--    `hospital_email text` and `engineer_email text`. PostgreSQL will not
--    silently widen varchar to text in a RETURN QUERY row. This is the
--    THIRD instance of this exact class in the sweep (engineer_sla_board
--    in round3797 was the second), so it is worth naming as a rule:
--    **any RETURNS TABLE column fed from auth.users.email must be cast**.
--    Both sub-selects are cast and their table aliased.
--
-- 2. scan_duplicate_accounts -- 42883, "function similarity(text, text)
--    does not exist". Not a missing extension: `pg_trgm` IS installed,
--    but in schema `extensions`, and this function pins
--    `SET search_path = public, pg_temp`. Exactly the same root cause as
--    round3783 (pgcrypto/digest), round3792 class B (pgcrypto
--    gen_random_bytes, and pg_stat_statements) -- the FOURTH extension
--    caught by the same trap. Qualified as
--    `extensions.similarity(...)`, verified to resolve.
--
--    This one matters operationally: scan_duplicate_accounts is the
--    duplicate-account fraud scan, and per docs/CRON_SCHEDULING_GAP.md it
--    is one of the declared daily jobs that has no scheduler. So it was
--    doubly dead -- never called, and broken if it had been.
--
--    FLAGGED, NOT CHANGED: its own comment reads "pg_trgm similarity >
--    0.8 catches \"Anil Reddy\" vs \"Aanil Reddy\"", but the code
--    threshold is `> 0.85` and the real similarity of that exact pair is
--    **0.769** -- measured on this database. So the function's own
--    documented example would NOT be caught by its own threshold, at
--    either 0.8 or 0.85. Tightening it trades missed duplicates against
--    false accusations of real users, which is a policy call for the
--    founder, so the threshold is left exactly as-is and only the
--    resolution bug is fixed here.
--
-- VERIFICATION runs inside the transaction. Because a 42804 does not
-- raise until the query yields a row (the round3797 lesson), the gate
-- asserts plpgsql_check reports ZERO errors for both functions rather
-- than relying on them executing.

BEGIN;

-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_dispute_queue(p_limit integer DEFAULT 50)
 RETURNS TABLE(escrow_id uuid, repair_job_id uuid, amount_rupees numeric, hospital_user_id uuid, hospital_email text, engineer_user_id uuid, engineer_email text, engineer_pack_id uuid, hospital_pack_id uuid, engineer_pack_evidence_count integer, hospital_pack_evidence_count integer, earliest_pack_at timestamp with time zone, hours_since_oldest_pack numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH escrows_in_dispute AS (
    SELECT e.id, e.repair_job_id, e.amount_rupees, e.dispute_reason
      FROM public.repair_job_escrow e
     WHERE e.status = 'disputed'
        OR (e.dispute_reason IS NOT NULL AND e.dispute_resolved_at IS NULL)
  ),
  packs AS (
    SELECT
      p.repair_job_escrow_id,
      (max(p.id::text) FILTER (WHERE p.filer_role = 'engineer' AND p.status = 'submitted'))::uuid AS engineer_pack_id,
      (max(p.id::text) FILTER (WHERE p.filer_role = 'hospital' AND p.status = 'submitted'))::uuid AS hospital_pack_id,
      max(p.evidence_count) FILTER (WHERE p.filer_role = 'engineer' AND p.status = 'submitted') AS engineer_pack_evidence_count,
      max(p.evidence_count) FILTER (WHERE p.filer_role = 'hospital' AND p.status = 'submitted') AS hospital_pack_evidence_count,
      min(p.submitted_at) FILTER (WHERE p.status = 'submitted') AS earliest_pack_at
    FROM public.dispute_evidence_packs p
    GROUP BY p.repair_job_escrow_id
  ),
  bids AS (
    SELECT b.repair_job_id, b.engineer_user_id
      FROM public.repair_job_bids b
     WHERE b.status = 'accepted'
  )
  SELECT
    e.id AS escrow_id,
    e.repair_job_id,
    e.amount_rupees,
    rj.hospital_user_id,
    (SELECT u.email::text FROM auth.users u WHERE u.id = rj.hospital_user_id) AS hospital_email,
    b.engineer_user_id,
    (SELECT u.email::text FROM auth.users u WHERE u.id = b.engineer_user_id) AS engineer_email,
    p.engineer_pack_id,
    p.hospital_pack_id,
    coalesce(p.engineer_pack_evidence_count, 0)::int,
    coalesce(p.hospital_pack_evidence_count, 0)::int,
    p.earliest_pack_at,
    EXTRACT(EPOCH FROM (now() - p.earliest_pack_at)) / 3600
  FROM escrows_in_dispute e
  JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
  LEFT JOIN bids b ON b.repair_job_id = e.repair_job_id
  LEFT JOIN packs p ON p.repair_job_escrow_id = e.id
  ORDER BY p.earliest_pack_at ASC NULLS LAST
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$function$;

-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.scan_duplicate_accounts()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pair record;
  v_count int := 0;
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  -- ============================================================
  -- Signal 1: shared Aadhaar (CRITICAL — engineers only)
  -- ============================================================
  FOR v_pair IN
    SELECT
      least(e1.user_id, e2.user_id) AS user_id_a,
      greatest(e1.user_id, e2.user_id) AS user_id_b,
      e1.aadhaar_number AS aadhaar
    FROM public.engineers e1
    JOIN public.engineers e2
      ON e1.aadhaar_number = e2.aadhaar_number
     AND e1.user_id < e2.user_id
    WHERE e1.aadhaar_number IS NOT NULL
      AND length(e1.aadhaar_number) >= 4
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_aadhaar', 'critical',
      jsonb_build_object(
        'aadhaar_masked', 'XXXX-XXXX-' || right(v_pair.aadhaar, 4),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 2: shared PAN (CRITICAL — engineers only)
  -- ============================================================
  FOR v_pair IN
    SELECT
      least(e1.user_id, e2.user_id) AS user_id_a,
      greatest(e1.user_id, e2.user_id) AS user_id_b,
      e1.pan_number AS pan
    FROM public.engineers e1
    JOIN public.engineers e2
      ON upper(trim(e1.pan_number)) = upper(trim(e2.pan_number))
     AND e1.user_id < e2.user_id
    WHERE e1.pan_number IS NOT NULL
      AND length(trim(e1.pan_number)) = 10
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_pan', 'critical',
      jsonb_build_object(
        'pan_masked', left(v_pair.pan, 4) || '...' || right(v_pair.pan, 1),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 3: shared phone (HIGH — both sides; covers profiles)
  -- Phone reuse in India is real (family share), so HIGH not
  -- CRITICAL. Normalized to last 10 digits.
  -- ============================================================
  FOR v_pair IN
    WITH normed AS (
      SELECT
        u.id AS user_id,
        public.normalize_indian_phone(
          coalesce(p.phone, u.phone, u.raw_user_meta_data->>'phone')
        ) AS norm_phone
      FROM auth.users u
      LEFT JOIN public.profiles p ON p.id = u.id
    )
    SELECT
      least(n1.user_id, n2.user_id) AS user_id_a,
      greatest(n1.user_id, n2.user_id) AS user_id_b,
      n1.norm_phone AS phone
    FROM normed n1
    JOIN normed n2
      ON n1.norm_phone = n2.norm_phone
     AND n1.user_id < n2.user_id
    WHERE n1.norm_phone IS NOT NULL
      AND length(n1.norm_phone) = 10
  LOOP
    INSERT INTO public.duplicate_account_flags (
      user_id_a, user_id_b, signal_kind, severity, evidence
    ) VALUES (
      v_pair.user_id_a, v_pair.user_id_b, 'shared_phone_normalized', 'high',
      jsonb_build_object(
        'phone_last4', right(v_pair.phone, 4),
        'detector', 'scan_duplicate_accounts_v1'
      )
    )
    ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
    v_count := v_count + 1;
  END LOOP;

  -- ============================================================
  -- Signal 4: name fuzzy match (MEDIUM — heuristic only)
  -- pg_trgm similarity > 0.8 catches "Anil Reddy" vs "Aanil Reddy"
  -- ============================================================
  -- Skip if pg_trgm not installed (graceful degrade)
  BEGIN
    FOR v_pair IN
      WITH names AS (
        SELECT u.id AS user_id,
               coalesce(u.raw_user_meta_data->>'full_name',
                        p.full_name, '') AS dn
          FROM auth.users u
          LEFT JOIN public.profiles p ON p.id = u.id
         WHERE coalesce(u.raw_user_meta_data->>'full_name',
                        p.full_name, '') <> ''
      )
      SELECT
        least(n1.user_id, n2.user_id) AS user_id_a,
        greatest(n1.user_id, n2.user_id) AS user_id_b,
        n1.dn AS dn_a,
        n2.dn AS dn_b
      FROM names n1
      JOIN names n2
        ON n1.user_id < n2.user_id
       AND extensions.similarity(n1.dn, n2.dn) > 0.85
       AND length(n1.dn) >= 6   -- avoid 'A B' false-positives
    LOOP
      INSERT INTO public.duplicate_account_flags (
        user_id_a, user_id_b, signal_kind, severity, evidence
      ) VALUES (
        v_pair.user_id_a, v_pair.user_id_b, 'name_fuzzy_match', 'medium',
        jsonb_build_object(
          'name_a', v_pair.dn_a, 'name_b', v_pair.dn_b,
          'detector', 'scan_duplicate_accounts_v1'
        )
      )
      ON CONFLICT (user_id_a, user_id_b, signal_kind, status) DO NOTHING;
      v_count := v_count + 1;
    END LOOP;
  EXCEPTION
    WHEN undefined_function THEN
      RAISE NOTICE 'pg_trgm not installed; skipping name fuzzy match signal';
  END;

  RETURN v_count;
END;
$function$;

-- =====================================================================
-- VERIFY
-- =====================================================================
DO $gate$
DECLARE
  v_names text[] := ARRAY[
    'founder_dispute_queue',
    'scan_duplicate_accounts'
  ];
  v_bad   text;
BEGIN
  SELECT string_agg(x, ', ') INTO v_bad FROM unnest(v_names) x
   WHERE NOT EXISTS (SELECT 1 FROM pg_proc p
                      WHERE p.pronamespace='public'::regnamespace AND p.proname = x);
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3800 VERIFY FAILED: function(s) vanished: %', v_bad;
  END IF;

  SELECT string_agg(q.proname || ' x' || q.c, ', ') INTO v_bad
    FROM (SELECT p.proname, count(*) c FROM pg_proc p
           WHERE p.pronamespace='public'::regnamespace AND p.proname = ANY(v_names)
           GROUP BY p.proname) q WHERE q.c > 1;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'round 3800 VERIFY FAILED: extra overload(s): %', v_bad;
  END IF;

  -- the pg_trgm call must resolve for real, not just parse
  IF to_regprocedure('extensions.similarity(text,text)') IS NULL THEN
    RAISE EXCEPTION 'round 3800 VERIFY FAILED: extensions.similarity(text,text) does not exist';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='plpgsql_check') THEN
    SELECT string_agg(DISTINCT p.proname || ' [' || e.sqlstate || '] ' ||
                      replace(coalesce(e.detail, e.message), chr(10), ' '), '; ') INTO v_bad
      FROM pg_proc p CROSS JOIN LATERAL plpgsql_check_function_tb(p.oid) e
     WHERE p.pronamespace='public'::regnamespace
       AND p.prolang=(SELECT oid FROM pg_language WHERE lanname='plpgsql')
       AND p.prorettype <> 'trigger'::regtype
       AND p.proname = ANY(v_names) AND e.level='error';
    IF v_bad IS NOT NULL THEN
      RAISE EXCEPTION 'round 3800 VERIFY FAILED: still broken: %', v_bad;
    END IF;
    RAISE NOTICE 'round 3800: both function(s) now statically clean';
  END IF;

  RAISE NOTICE 'round 3800 verified: auth.users.email cast + pg_trgm requalified';
END
$gate$;

COMMIT;

-- ---------------------------------------------------------------------
-- THE FOUR FALSE POSITIVES round3799's gate counted, left UNCHANGED
-- ---------------------------------------------------------------------
-- founder_cron_status_summary, founder_cron_jobs_recent,
-- founder_morning_digest_v2 and founder_tier_1_home_metadata all report
-- 42P01 on `cron.job` / `cron.job_run_details`. pg_cron is genuinely not
-- installed on this project (no `cron` schema at all -- see
-- docs/CRON_SCHEDULING_GAP.md), so there is no column-level repair.
--
-- But all four EXECUTE SUCCESSFULLY -- verified as the founder, returning
-- 0, 1, 1 and 1 rows respectively -- because each wraps the cron read in
-- its own EXCEPTION handler and degrades that one metric rather than
-- failing. That is the same guarded-with-a-working-fallback shape already
-- calibrated as a false positive for wrapped 42883 (`delete_my_account`,
-- round3785) and for `founder_cron_status` / the ops cockpit heartbeat
-- (round3797).
--
-- Editing them would delete working defensive code to satisfy a static
-- checker, which is the precise mistake round3785 avoided. They stay.
--
-- CALIBRATION, updated: a 42P01 naming a `cron.*` relation on this
-- project is a FALSE POSITIVE whenever the reference sits inside an
-- EXCEPTION handler. Always test by executing before "fixing" one.
