-- =====================================================================
-- Round 3785 — 7 Android-called RPCs that were broken in production
-- =====================================================================
--
-- These are NOT dormant functions. The Android app calls every one of
-- them today, so each has been failing for real users. Found by the
-- same plpgsql_check static sweep as round3780-3784, then every single
-- one CONFIRMED by live execution against production before any fix was
-- written (each returned exactly the predicted SQLSTATE).
--
--   my_supervision_graduation_status()   42702  EngineerGraduationScreen
--   my_tier_earnings_projection()        42702  engineer earnings-projection route
--   my_eligible_supervisors()            42702  engineer supervision route
--   my_supervisable_jobs()               42804  engineer supervision route
--   admin_users_search(...)              42702  founder user search
--   admin_dispute_party_track_record(..) 42702  founder dispute drill-down
--   log_analytics_event(...)             42703  app-wide analytics writer
--
-- So four engineer-facing screens (graduation/tier progress, earnings
-- projection, supervision x2), two founder screens, and the analytics
-- write path have never worked. public.analytics_events is presumably
-- empty for the same reason.
--
-- DOMINANT ROOT CAUSE (5 of 7): the ambiguous-OUT-column trap. A
-- `RETURNS TABLE(... foo ...)` declaration creates an implicit
-- function-scope PL/pgSQL variable `foo`; a later `SELECT foo FROM t`
-- where t also has a column `foo` cannot be resolved and raises 42702
-- at execution time — so CREATE FUNCTION succeeds and the defect ships
-- invisibly. This is now the 5th through 9th instance of this one class
-- in this codebase (round3761 engineer_public_profile, round3781's pair,
-- and these). Fix throughout: alias the table and qualify the column,
-- because PL/pgSQL only substitutes UNQUALIFIED identifiers.
-- Deliberately NOT using `#variable_conflict use_column`, which applies
-- function-wide and could silently change resolution elsewhere in a body.
--
-- The other two:
--   my_supervisable_jobs  42804 — RETURN QUERY select-list did not match
--     the declared RETURNS TABLE (enum columns needed explicit ::text).
--   log_analytics_event   42703 — `SELECT k, v FROM jsonb_each(...)`;
--     jsonb_each() yields columns named `key`/`value`, not `k`/`v`.
--
-- PROVENANCE / REVIEW: each fix was drafted against the authoritative
-- production definition (pg_get_functiondef, not the repo migrations,
-- which may have been superseded) and then adversarially reviewed by an
-- independent pass checking signature preservation, RETURNS-shape
-- preservation, volatility/SECURITY DEFINER/search_path preservation,
-- whether EVERY instance of the defect was fixed rather than just the
-- reported one, and whether the fix introduced anything new. Two further
-- fixes from the same batch were REJECTED and are deliberately NOT here:
--
--   engineer_respond_to_escrow_dispute — the drafted fix reimplemented
--     the founder check instead of using public.admin_or_founder_user_ids()
--     (the helper round3782 added for exactly this), diverging in
--     semantics. Fixed below, by hand, using the helper.
--
--   delete_my_account — REJECTED, and then the premise itself turned out
--     to be wrong: this function is NOT broken. plpgsql_check flags
--     `storage.delete_object(text,text) does not exist` (42883, true —
--     Supabase has no such function), but the call site is ALREADY
--     wrapped in `EXCEPTION WHEN undefined_function OR undefined_object
--     THEN DELETE FROM storage.objects ...`. Verified empirically: a
--     PERFORM of that missing function inside exactly that handler is
--     caught, so the intended fallback runs and objects are removed via
--     the storage.objects table. The code is deliberately defensive and
--     works as designed.
--
--     This makes it a FALSE POSITIVE — plpgsql_check analyses the static
--     call without modelling the enclosing handler. The drafted "fix"
--     would have DELETED that working defensive code and, per review,
--     turned a would-be hard failure into a silently PARTIAL erasure on
--     a DPDP statutory / Play-Store-required right-to-erasure path,
--     where a false success is unrecoverable. Left exactly as it is,
--     on purpose. Nothing to fix here.
--
-- Every function below is EXERCISED at the bottom of this migration,
-- inside the transaction, so a still-broken fix aborts the migration
-- rather than shipping. (42702/42703/42804 are all execution-time, so
-- redefining a function proves nothing on its own.)

BEGIN;

-- ------------------------------------------------------------------
-- my_supervision_graduation_status
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_supervision_graduation_status()
 RETURNS TABLE(current_tier text, next_tier text, jobs_completed integer, jobs_required_for_next integer, dispute_rate_pct numeric, max_dispute_rate_for_next numeric, verified_tier_at_eval text, min_verified_tier_for_next text, supervised_completed integer, supervised_required_for_next integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller       uuid := auth.uid();
  v_prog         record;
  v_next         record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  -- round3785: alias the progress table as `p` and qualify EVERY column
  -- in this statement. current_tier / jobs_completed / dispute_rate_pct /
  -- verified_tier_at_eval are all ALSO RETURNS TABLE OUT columns (i.e.
  -- implicit plpgsql variables), so unqualified they resolved against both
  -- namespaces and raised 42702 "column reference is ambiguous" — the
  -- reported failure was current_tier, but all four were broken; Postgres
  -- just stops at the first. PL/pgSQL only substitutes UNQUALIFIED
  -- identifiers, so `p.<col>` unambiguously means the table column.
  -- Qualifying keeps the output column names bare (`current_tier`, …), so
  -- v_prog's field names — and every v_prog.* read below — are unchanged.
  SELECT p.current_tier, p.jobs_completed, p.dispute_rate_pct,          -- round3785: was unqualified -> ambiguous (42702)
         p.verified_tier_at_eval, p.supervised_completions_at_eval      -- round3785: verified_tier_at_eval was ambiguous too
    INTO v_prog
    FROM public.engineer_certification_progress p                       -- round3785: added alias `p` so the columns can be qualified
   WHERE p.engineer_user_id = v_caller;                                 -- round3785: qualified for consistency with the alias

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
$function$
;

-- ------------------------------------------------------------------
-- my_tier_earnings_projection
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_tier_earnings_projection()
 RETURNS TABLE(current_tier text, current_platform_fee_pct numeric, next_tier text, next_platform_fee_pct numeric, avg_monthly_gross_rupees numeric, projected_monthly_uplift_rupees numeric, completed_jobs_90d integer, supervised_completions_at_eval integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH me AS (
    SELECT
      coalesce(p.current_tier, 'none')                  AS current_tier,
      coalesce(p.supervised_completions_at_eval, 0)     AS supervised_completions_at_eval
    FROM (SELECT 1) seed
    LEFT JOIN public.engineer_certification_progress p
      ON p.engineer_user_id = v_caller
  ),
  current_def AS (
    SELECT t.tier, t.platform_fee_pct, t.display_order
    FROM public.engineer_certification_tiers t
    JOIN me ON me.current_tier = t.tier
  ),
  next_def AS (
    -- "Lowest display_order strictly greater than current's display_order"
    SELECT t.tier, t.platform_fee_pct
    FROM public.engineer_certification_tiers t
    WHERE t.display_order > coalesce((SELECT display_order FROM current_def), -1)
    ORDER BY t.display_order ASC
    LIMIT 1
  ),
  window_jobs AS (
    -- Completed jobs in trailing 90d where caller was accepted-bid engineer.
    SELECT
      count(*)::int                                   AS completed_jobs_90d,
      coalesce(sum(rj.contracted_amount_rupees), 0)   AS gross_rupees_90d
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b
      ON b.repair_job_id    = rj.id
     AND b.status           = 'accepted'
     AND b.engineer_user_id = v_caller
    WHERE rj.status       = 'completed'
      AND rj.completed_at >= now() - interval '90 days'
  )
  SELECT
    -- round3785: `current_tier` is ALSO this function's own RETURNS TABLE OUT
    -- variable, so the bare `SELECT current_tier FROM me` was 42702-ambiguous
    -- and aborted the whole RETURN QUERY on every call. Alias the CTE and
    -- qualify so the intended value (me's coalesced tier column) is used.
    coalesce((SELECT m.current_tier FROM me m), 'none')              AS current_tier,
    coalesce((SELECT platform_fee_pct FROM current_def), 7.00)       AS current_platform_fee_pct,
    (SELECT tier FROM next_def)                                      AS next_tier,
    (SELECT platform_fee_pct FROM next_def)                          AS next_platform_fee_pct,
    -- avg_monthly_gross = sum / 3.0 (90d ≈ 3 months)
    round(
      coalesce((SELECT gross_rupees_90d FROM window_jobs), 0) / 3.0,
      2
    )                                                                AS avg_monthly_gross_rupees,
    -- projected_monthly_uplift = avg_monthly * (current_fee - next_fee) / 100
    -- = 0 when next_tier is NULL (top of ladder)
    CASE
      WHEN (SELECT tier FROM next_def) IS NULL THEN 0::numeric
      ELSE round(
        (coalesce((SELECT gross_rupees_90d FROM window_jobs), 0) / 3.0)
        * (
            coalesce((SELECT platform_fee_pct FROM current_def), 7.00)
          - coalesce((SELECT platform_fee_pct FROM next_def), 7.00)
          )
        / 100.0,
        2
      )
    END                                                              AS projected_monthly_uplift_rupees,
    -- round3785: same OUT-variable ambiguity as current_tier above —
    -- `completed_jobs_90d` is an OUT variable AND a window_jobs column.
    coalesce((SELECT w.completed_jobs_90d FROM window_jobs w), 0)    AS completed_jobs_90d,
    -- round3785: same OUT-variable ambiguity — `supervised_completions_at_eval`
    -- is an OUT variable AND a me column.
    coalesce((SELECT m.supervised_completions_at_eval FROM me m), 0) AS supervised_completions_at_eval;
END;
$function$;

-- ------------------------------------------------------------------
-- my_eligible_supervisors
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_eligible_supervisors()
 RETURNS TABLE(user_id uuid, current_tier text, jobs_completed integer, display_name text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid             uuid := auth.uid();
  v_my_tier         text;
  v_my_rank         int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  -- round3785: alias the table and qualify the column refs. Bare
  -- `current_tier` collided with the same-named RETURNS TABLE OUT
  -- parameter, so plpgsql raised 42702 ("column reference
  -- "current_tier" is ambiguous") on every call — the supervisor
  -- picker never returned a row. plpgsql only substitutes UNQUALIFIED
  -- identifiers, so ecp.current_tier resolves to the column.
  SELECT ecp.current_tier INTO v_my_tier
    FROM public.engineer_certification_progress ecp
   WHERE ecp.engineer_user_id = v_uid;
  IF NOT FOUND THEN
    v_my_tier := 'none';
  END IF;

  v_my_rank := public._supervised_tier_rank(v_my_tier);
  IF v_my_rank IS NULL THEN
    v_my_rank := 0;
  END IF;

  RETURN QUERY
  SELECT
    p.engineer_user_id                          AS user_id,
    p.current_tier,
    p.jobs_completed,
    coalesce(pr.full_name, '(engineer)')        AS display_name
  FROM public.engineer_certification_progress p
  JOIN public.engineers e
    ON e.user_id = p.engineer_user_id
   AND e.verification_status = 'verified'
   AND e.cash_auto_suspended_at IS NULL
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  WHERE p.engineer_user_id <> v_uid
    AND public._supervised_tier_rank(p.current_tier) > v_my_rank
  ORDER BY public._supervised_tier_rank(p.current_tier) DESC,
           p.jobs_completed DESC
  LIMIT 50;
END;
$function$;

-- ------------------------------------------------------------------
-- my_supervisable_jobs
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_supervisable_jobs()
 RETURNS TABLE(repair_job_id uuid, job_number text, equipment_brand text, equipment_model text, status text, accepted_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    rj.id                  AS repair_job_id,
    rj.job_number,
    rj.equipment_brand,
    rj.equipment_model,
    -- round3785: cast the ENUM to text HERE. repair_jobs.status is the
    -- job_status ENUM but OUT column 5 is declared `text`, and RETURN QUERY
    -- matches by position with exact type-OID equality (enum is not
    -- binary-coercible to text) — so every call raised 42804 "structure of
    -- query does not match function result type" and this RPC has never
    -- returned a row. The WHERE clause below intentionally keeps comparing
    -- the ENUM to its own labels (all three are real job_status values).
    rj.status::text,
    b.created_at           AS accepted_at
  FROM public.repair_jobs rj
  JOIN public.repair_job_bids b
    ON b.repair_job_id = rj.id
   AND b.status = 'accepted'
  WHERE b.engineer_user_id = v_uid
    AND rj.status NOT IN ('completed','cancelled','disputed')
  ORDER BY b.created_at DESC
  LIMIT 50;
END;
$function$;

-- ------------------------------------------------------------------
-- admin_users_search
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_users_search(p_query text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(user_id uuid, email text, phone text, full_name text, role text, organization_id uuid, is_active boolean, created_at timestamp with time zone, failed_integrity_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_q text := nullif(trim(coalesce(p_query, '')), '');
  v_pat text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_founder' USING ERRCODE='42501';
  END IF;
  v_pat := CASE WHEN v_q IS NULL THEN NULL ELSE '%' || lower(v_q) || '%' END;
  RETURN QUERY
    WITH integrity_counts AS (
      -- round3785: qualify as dic.user_id — bare `user_id` was captured by the
      -- RETURNS TABLE OUT column of the same name, so the whole RETURN QUERY
      -- failed to plan with 42702 (ambiguous) for every caller.
      SELECT dic.user_id, count(*)::int AS failed_count
        -- round3785: alias the table so user_id can be qualified (PL/pgSQL only
        -- substitutes UNQUALIFIED identifiers).
        FROM public.device_integrity_checks dic
       WHERE pass = false
       -- round3785: qualify — same 42702 collision with the OUT column.
       GROUP BY dic.user_id
    )
    SELECT
      p.id,
      p.email,
      p.phone,
      coalesce(p.full_name, '(unnamed)'),
      p.role::text,
      p.organization_id,
      p.is_active,
      p.created_at,
      coalesce(ic.failed_count, 0)
    FROM public.profiles p
    LEFT JOIN integrity_counts ic ON ic.user_id = p.id
    WHERE
      (v_pat IS NULL
        OR lower(coalesce(p.email, '')) LIKE v_pat
        OR lower(coalesce(p.phone, '')) LIKE v_pat
        OR lower(coalesce(p.full_name, '')) LIKE v_pat)
      AND (p_role IS NULL OR p.role::text = p_role)
    -- Round 377 — risky users first, recency tie-break.
    ORDER BY coalesce(ic.failed_count, 0) DESC,
             p.created_at DESC NULLS LAST
    LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
    OFFSET greatest(0, coalesce(p_offset, 0));
END;
$function$;

-- ------------------------------------------------------------------
-- admin_dispute_party_track_record
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_dispute_party_track_record(p_escrow_id uuid, p_window_days integer DEFAULT 90)
 RETURNS TABLE(hospital_user_id uuid, hospital_disputes_filed integer, hospital_disputes_won integer, hospital_disputes_lost integer, hospital_disputes_open integer, engineer_user_id uuid, engineer_disputes_recv integer, engineer_disputes_won integer, engineer_disputes_lost integer, engineer_disputes_open integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller   uuid := auth.uid();
  v_escrow   record;
  v_since    timestamptz;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;
  IF p_window_days <= 0 OR p_window_days > 365 THEN
    RAISE EXCEPTION 'window_days must be 1..365' USING ERRCODE = '22023';
  END IF;

  -- round3785: alias the escrow table as `rje` and qualify EVERY column on
  -- all three lines of this statement. `hospital_user_id` and
  -- `engineer_user_id` are also RETURNS TABLE OUT params (i.e. in-scope
  -- PL/pgSQL variables), so the unqualified references were ambiguous
  -- (42702) and this SELECT INTO failed for every caller -- the whole RPC
  -- was dead. PL/pgSQL only substitutes UNQUALIFIED identifiers, so
  -- `rje.`-qualifying pins them to the table columns. `id` is qualified
  -- too (harmless, and immune to a future OUT param / variable named `id`).
  -- Field names of v_escrow are unchanged: the output column name of
  -- `rje.hospital_user_id` is still `hospital_user_id`.
  SELECT rje.id, rje.hospital_user_id, rje.engineer_user_id INTO v_escrow
    FROM public.repair_job_escrow rje
   WHERE rje.id = p_escrow_id;
  IF v_escrow IS NULL THEN
    RAISE EXCEPTION 'escrow not found' USING ERRCODE = '02000';
  END IF;

  v_since := now() - make_interval(days => p_window_days);

  RETURN QUERY
  SELECT
    v_escrow.hospital_user_id  AS hospital_user_id,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
    ), 0) AS hospital_disputes_filed,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'refund'
    ), 0) AS hospital_disputes_won,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'release'
    ), 0) AS hospital_disputes_lost,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.hospital_user_id = v_escrow.hospital_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.status = 'in_dispute'
    ), 0) AS hospital_disputes_open,
    v_escrow.engineer_user_id  AS engineer_user_id,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
    ), 0) AS engineer_disputes_recv,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'release'
    ), 0) AS engineer_disputes_won,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.dispute_resolution = 'refund'
    ), 0) AS engineer_disputes_lost,
    coalesce((
      SELECT count(*)::int FROM public.repair_job_escrow e
       WHERE e.engineer_user_id = v_escrow.engineer_user_id
         AND e.dispute_opened_at IS NOT NULL
         AND e.dispute_opened_at >= v_since
         AND e.status = 'in_dispute'
    ), 0) AS engineer_disputes_open;
END;
$function$
;

-- ------------------------------------------------------------------
-- log_analytics_event
-- ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_analytics_event(p_event_key text, p_session_id uuid DEFAULT NULL::uuid, p_surface text DEFAULT 'android'::text, p_app_version text DEFAULT NULL::text, p_props jsonb DEFAULT '{}'::jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id          bigint;
  v_user        uuid := auth.uid();
  v_clean       jsonb;
  v_key         text;
  v_jvalue      jsonb;
  v_type        text;
  v_text        text;
  v_normalized  text;
BEGIN
  IF p_event_key IS NULL OR p_event_key !~ '^[a-z][a-z0-9_]{1,63}$' THEN
    RAISE EXCEPTION 'invalid_event_key' USING ERRCODE = '22023';
  END IF;
  IF p_surface NOT IN ('android', 'web', 'edge', 'cron') THEN
    RAISE EXCEPTION 'invalid_surface' USING ERRCODE = '22023';
  END IF;

  -- Key drop list (r510 base + r522 extension; unchanged in r529).
  v_clean := coalesce(p_props, '{}'::jsonb)
             - 'aadhaar' - 'aadhaar_number'
             - 'pan' - 'pan_number'
             - 'phone' - 'phone_number' - 'alternate_phone' - 'mobile' - 'mobile_number'
             - 'email' - 'alternate_email' - 'email_address'
             - 'address' - 'street' - 'pincode' - 'city_full'
             - 'gst' - 'gstin'
             - 'name' - 'full_name' - 'user_name' - 'contact_name' - 'engineer_name' - 'hospital_name'
             - 'bank_account' - 'bank_account_number' - 'account_number'
             - 'ifsc' - 'ifsc_code'
             - 'upi' - 'upi_id' - 'vpa'
             - 'pan_card' - 'aadhaar_card' - 'kyc';

  -- Per-key value walk via jsonb_each (not jsonb_each_text) so we keep
  -- the type information. We REJECT objects + arrays entirely (they
  -- can hide PII at any depth and the contract says props are flat).
  -- For scalars, we cast to text + normalize + apply PII regex.
  FOR v_key, v_jvalue IN
    -- round3785: jsonb_each() emits columns named key/value, never k/v, so the
    -- old `SELECT k, v` raised 42703 ("column k does not exist") on EVERY call
    -- (defect carried in from r522) and no analytics event was ever logged.
    -- Alias the set-returning function and qualify both columns.
    SELECT e.key, e.value FROM jsonb_each(v_clean) AS e
  LOOP
    v_type := jsonb_typeof(v_jvalue);

    -- Audit-12 finding 2(a, b): nested object / array — drop.
    IF v_type IN ('object', 'array') THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;

    -- Booleans are fine, pass through.
    IF v_type = 'boolean' OR v_type = 'null' THEN
      CONTINUE;
    END IF;

    -- Numbers + strings: extract scalar text and normalize.
    IF v_type = 'number' THEN
      v_text := v_jvalue::text;     -- "12345" without quotes
    ELSE
      v_text := v_jvalue #>> '{}';  -- unquoted string
    END IF;

    IF v_text IS NULL THEN
      CONTINUE;
    END IF;

    v_normalized := public._analytics_normalize_for_pii(v_text);

    -- Email
    IF v_normalized ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Indian phone: 10 digits, optionally +91 prefix
    IF v_normalized ~ '^(\+?91)?[6-9][0-9]{9}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Aadhaar: 12 digits starting 2-9
    IF v_normalized ~ '^[2-9][0-9]{11}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- PAN: 5 letters + 4 digits + 1 letter (case-insensitive after upper)
    IF upper(v_normalized) ~ '^[A-Z]{5}[0-9]{4}[A-Z]$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- IFSC: 4 letters + 0 + 6 alphanumeric
    IF upper(v_normalized) ~ '^[A-Z]{4}0[A-Z0-9]{6}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- Bank account / card: 12-19 contiguous digits
    IF v_normalized ~ '^[0-9]{12,19}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
    -- UPI VPA: text@bankname
    IF v_normalized ~* '^[a-z0-9._-]{2,}@[a-z]{2,15}$' THEN
      v_clean := v_clean - v_key;
      CONTINUE;
    END IF;
  END LOOP;

  IF octet_length(v_clean::text) > 4096 THEN
    RAISE EXCEPTION 'props_too_large' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.analytics_events
    (user_id, session_id, event_key, surface, app_version, props)
  VALUES
    (v_user, p_session_id, p_event_key, p_surface, p_app_version, v_clean)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;

-- ------------------------------------------------------------------
-- engineer_respond_to_escrow_dispute — the 8th fix, done by hand
-- ------------------------------------------------------------------
-- Same phantom `profiles.is_founder` column as round3782's three
-- triggers (profiles has no such column; is_founder() is a
-- session-scoped function). This is an RPC rather than a trigger, and
-- it is a MONEY path: it is how an engineer answers a hospital's
-- escrow dispute. It raised 42703 for every caller, so an engineer
-- could never respond to a dispute — the mirror image of round3782,
-- where the hospital could never open one.
--
-- Fixed to reuse public.admin_or_founder_user_ids() (added by round3782
-- precisely so this predicate exists in ONE place) rather than
-- re-deriving the founder test, which is what the drafted fix did and
-- why it was rejected. The function is SECURITY DEFINER (verified), so
-- it executes as owner and may call the helper despite the helper being
-- withheld from `authenticated`.
--
-- The admin arm of the surrounding OR is now technically redundant —
-- the helper already includes admins — but the predicate is left in
-- place to keep this a single-region substitution on a money path
-- rather than a structural rewrite.
DO $$
DECLARE
  v_oid oid; v_def text; v_new text; v_before int; v_after int;
BEGIN
  SELECT oid INTO v_oid FROM pg_proc
   WHERE pronamespace='public'::regnamespace
     AND proname='engineer_respond_to_escrow_dispute';
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'round 3785: engineer_respond_to_escrow_dispute not found';
  END IF;

  v_def := pg_get_functiondef(v_oid);

  SELECT count(*) INTO v_before FROM regexp_matches(v_def, 'p\.is_founder[[:space:]]*=[[:space:]]*true', 'g');
  IF v_before <> 1 THEN
    RAISE EXCEPTION 'round 3785: expected exactly 1 `p.is_founder = true` in engineer_respond_to_escrow_dispute, found % — refusing to rewrite', v_before;
  END IF;

  v_new := regexp_replace(
             v_def,
             'p\.is_founder[[:space:]]*=[[:space:]]*true',
             'u.id IN (SELECT uid FROM public.admin_or_founder_user_ids() AS uid)',
             'g');

  SELECT count(*) INTO v_after FROM regexp_matches(v_new, 'p\.is_founder', 'g');
  IF v_after <> 0 THEN
    RAISE EXCEPTION 'round 3785: rewrite left % reference(s) to the phantom p.is_founder — refusing to apply', v_after;
  END IF;
  IF position('search_path' IN v_new) = 0 THEN
    RAISE EXCEPTION 'round 3785: rewrite lost the search_path pin — refusing to apply';
  END IF;

  EXECUTE v_new;
  RAISE NOTICE 'round 3785: engineer_respond_to_escrow_dispute now uses admin_or_founder_user_ids()';
END;
$$;

-- ------------------------------------------------------------------
-- Verification — actually EXECUTE all 8, inside the transaction
-- ------------------------------------------------------------------
DO $$
DECLARE
  v_n        int;
  v_eng      uuid := '20d7597c-2dea-4be0-ba7a-1713392325ee'; -- play-review-engineer
  v_founder  uuid := '756a3373-1077-470e-bc0a-79b8d6673ef4';
BEGIN
  -- ---- engineer-facing four, as a real engineer -------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_eng, 'role','authenticated',
                      'email','play-review-engineer@equipseva.com')::text, true);

  SELECT count(*) INTO v_n FROM public.my_supervision_graduation_status();
  RAISE NOTICE 'round 3785: my_supervision_graduation_status() OK (% rows)', v_n;

  SELECT count(*) INTO v_n FROM public.my_tier_earnings_projection();
  RAISE NOTICE 'round 3785: my_tier_earnings_projection() OK (% rows)', v_n;

  SELECT count(*) INTO v_n FROM public.my_eligible_supervisors();
  RAISE NOTICE 'round 3785: my_eligible_supervisors() OK (% rows)', v_n;

  SELECT count(*) INTO v_n FROM public.my_supervisable_jobs();
  RAISE NOTICE 'round 3785: my_supervisable_jobs() OK (% rows)', v_n;

  -- ---- founder-facing two, as the founder -------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_founder, 'role','authenticated',
                      'email','ganesh1431.dhanavath@gmail.com')::text, true);

  SELECT count(*) INTO v_n FROM public.admin_users_search(NULL, NULL, 5, 0);
  RAISE NOTICE 'round 3785: admin_users_search() OK (% rows)', v_n;

  -- NB: its first argument is an ESCROW id (p_escrow_id), not a user id.
  -- Passing a real one exercises the previously-ambiguous SELECT; if this
  -- database has no escrow rows, a domain-level 02000 'escrow not found'
  -- is itself proof the 42702 is gone, since that check sits AFTER the
  -- statement that used to fail.
  BEGIN
    SELECT count(*) INTO v_n
      FROM public.admin_dispute_party_track_record(
             (SELECT id FROM public.repair_job_escrow ORDER BY created_at DESC LIMIT 1), 90);
    RAISE NOTICE 'round 3785: admin_dispute_party_track_record() OK (% rows)', v_n;
  EXCEPTION
    WHEN SQLSTATE '02000' THEN
      RAISE NOTICE 'round 3785: admin_dispute_party_track_record() reached domain logic (02000 escrow not found) — 42702 is gone';
    WHEN OTHERS THEN
      RAISE EXCEPTION 'round 3785 VERIFY FAILED: admin_dispute_party_track_record still errors: % %', SQLSTATE, SQLERRM;
  END;

  -- ---- the analytics writer (VOLATILE) — probe and roll back ------
  BEGIN
    PERFORM public.log_analytics_event('round3785_probe', NULL, NULL, NULL, NULL);
    RAISE EXCEPTION 'ROUND3785_ANALYTICS_ROLLBACK';
  EXCEPTION
    WHEN SQLSTATE 'P0001' THEN
      RAISE NOTICE 'round 3785: log_analytics_event() OK (probe row rolled back)';
    WHEN OTHERS THEN
      RAISE EXCEPTION 'round 3785 VERIFY FAILED: log_analytics_event still errors: % %', SQLSTATE, SQLERRM;
  END;

  -- ---- the escrow-dispute responder (VOLATILE) -------------------
  -- Only its admin fan-out was broken, and reaching it requires a real
  -- disputed escrow owned by the calling engineer, which this database
  -- does not currently have. Assert the phantom column is gone from the
  -- stored source instead — that IS the defect, precisely.
  IF EXISTS (
    SELECT 1 FROM pg_proc
     WHERE pronamespace='public'::regnamespace
       AND proname='engineer_respond_to_escrow_dispute'
       AND prosrc ~ 'p\.is_founder'
  ) THEN
    RAISE EXCEPTION 'round 3785 VERIFY FAILED: engineer_respond_to_escrow_dispute still references profiles.is_founder';
  END IF;
  RAISE NOTICE 'round 3785: engineer_respond_to_escrow_dispute no longer references the phantom column';

  RAISE NOTICE 'round 3785 verified: 8 Android-called RPCs execute again (4 engineer screens, 2 founder screens, analytics writer, escrow-dispute responder)';
END;
$$;

COMMIT;
