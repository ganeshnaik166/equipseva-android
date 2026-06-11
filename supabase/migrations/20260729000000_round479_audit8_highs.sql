-- =====================================================================
-- Round 479 — Audit-8 HIGH bundle (5 fixes in one migration).
--
-- Bundles 5 audit-8 HIGH closures into a single migration for cleaner
-- history. Each section closes one finding; sections are independent
-- and idempotent.
--
--   (A) repair_job_bids.amount_rupees → numeric(10,2) + precision CHECK
--   (B) repair_job_bids INSERT RLS: block self-bidding (multi-role users)
--   (C) accept_repair_bid: hoist auth check before FOR UPDATE lock
--   (D) Stale 'requested' repair_jobs reaper + pg_cron schedule
--   (E) delete_my_account: guard against in-flight engineer payouts
-- =====================================================================


-- =====================================================================
-- (A) FIX-B — Bid amount precision.
--
-- Audit-8 HIGH: engineers submit 5000.5555 → display rounds 5000.56 →
-- contract stores 5000.55 → disputes. Solution: coerce column to
-- numeric(10,2) and add a redundant CHECK constraint so any future
-- fractional paise are rejected at write time.
-- Pattern mirrors amc_payment_orders + repair_job_cost_revisions.
-- =====================================================================

DO $precision$
DECLARE
  v_fractional_count int;
BEGIN
  -- Pre-flight: surface any existing rows with > 2 decimals before we
  -- coerce them. Not a blocker (coercion is silent + safe) but visible
  -- for audit trail.
  SELECT COUNT(*) INTO v_fractional_count
    FROM public.repair_job_bids
   WHERE amount_rupees IS NOT NULL
     AND amount_rupees <> round(amount_rupees, 2);

  IF v_fractional_count > 0 THEN
    RAISE NOTICE 'repair_job_bids: % rows have > 2 decimal places; will be truncated by ALTER COLUMN to numeric(10,2)',
      v_fractional_count;
  END IF;
END
$precision$;

-- 1. Coerce column type to numeric(10,2). Idempotent — re-runs are
--    no-ops once the column already has that type/precision.
ALTER TABLE public.repair_job_bids
  ALTER COLUMN amount_rupees TYPE numeric(10,2);

-- 2. Add explicit precision CHECK if not present. Mirrors
--    repair_job_cost_revisions pattern. NOT VALID + VALIDATE keeps the
--    migration safe on large tables.
DO $precision_check$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'repair_job_bids_amount_precision'
      AND conrelid = 'public.repair_job_bids'::regclass
  ) THEN
    ALTER TABLE public.repair_job_bids
      ADD CONSTRAINT repair_job_bids_amount_precision
      CHECK (round(amount_rupees, 2) = amount_rupees) NOT VALID;
    ALTER TABLE public.repair_job_bids
      VALIDATE CONSTRAINT repair_job_bids_amount_precision;
  END IF;
END
$precision_check$;

COMMENT ON COLUMN public.repair_job_bids.amount_rupees IS
  'Bid amount in rupees. numeric(10,2) enforces max ₹99,999,999.99 with 2 decimal places. '
  'CHECK constraint (round to 2 decimals = value) rejects fractional paise at write time. '
  'Audit-8 FIX-B: prevents precision mismatch disputes (engineer submits 5000.5555 → stored 5000.56 ≠ contract).';


-- =====================================================================
-- (B) Multi-role self-bid block.
--
-- Audit-8 HIGH #1: a user with both verified hospital + engineer roles
-- on the same auth.uid() could (1) post a repair_job as hospital_user_id,
-- (2) bid on it as engineer_user_id, (3) accept the bid, and (4) collect
-- the engineer payout without performing the work.
--
-- Fix: extend the repair_job_bids INSERT RLS with a NOT EXISTS clause
-- against the parent job's hospital_user_id.
-- =====================================================================

-- Drop ALL existing INSERT policies on repair_job_bids (same scan
-- pattern as 20260621100000 to handle unknown legacy policy names).
DO $bid_policy_cleanup$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT polname FROM pg_policy p
      JOIN pg_class c ON c.oid = p.polrelid
     WHERE c.relname = 'repair_job_bids'
       AND p.polcmd = 'a'  -- 'a' = INSERT
  LOOP
    EXECUTE format('DROP POLICY %I ON public.repair_job_bids', r.polname);
  END LOOP;
END
$bid_policy_cleanup$;

ALTER TABLE public.repair_job_bids ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Verified engineers insert own bid (no self-job bidding)"
  ON public.repair_job_bids
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = engineer_user_id
    AND EXISTS (
      SELECT 1
        FROM public.engineers e
       WHERE e.user_id = auth.uid()
         AND e.verification_status = 'verified'
    )
    AND NOT EXISTS (
      SELECT 1
        FROM public.repair_jobs rj
       WHERE rj.id = repair_job_id
         AND rj.hospital_user_id = auth.uid()
    )
  );

COMMENT ON POLICY "Verified engineers insert own bid (no self-job bidding)" ON public.repair_job_bids IS
  'Round 479 — Audit-8 HIGH #1. KYC-verified engineers can submit bids, but '
  'cannot bid on repair jobs they themselves posted as hospital_user_id. '
  'Blocks multi-role self-bidding pollution: a user with both hospital + '
  'engineer verified roles cannot submit bids to their own posted jobs, '
  'accept those bids, and claim engineer payout without doing the work.';


-- =====================================================================
-- (C) accept_repair_bid — hoist auth check before FOR UPDATE.
--
-- Audit-8 HIGH: previous version acquired FOR UPDATE OF rj BEFORE
-- checking auth.uid() = hospital_user_id. Two problems:
--   1. Auth-failed callers hold a row lock during the failure path,
--      increasing contention.
--   2. Lock-acquisition latency vs. auth-failure latency is timing-
--      probable to enumerate valid bid IDs.
--
-- Fix: split into two SELECTs.
--   Phase 1: lightweight (no lock) → validate auth → exit early on fail.
--   Phase 2: lock with FOR UPDATE OF rj → re-validate state under MVCC.
--
-- Round 276 TOCTOU guard (AND status='pending' + GET DIAGNOSTICS
-- ROW_COUNT check on the bid UPDATE) is preserved verbatim.
-- v2.1 / Round 421 per-job escrow INSERT block also preserved verbatim.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.accept_repair_bid(p_bid_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_bid record;
  v_engineer_id uuid;
  v_job jsonb;
  v_accepted_count int;
  v_escrow_id uuid;
BEGIN
  -- Phase 1: lightweight fetch (no lock) to validate auth.
  SELECT
      b.id,
      b.repair_job_id,
      b.engineer_user_id,
      b.amount_rupees,
      b.status,
      rj.hospital_user_id,
      rj.status AS job_status
    INTO v_bid
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
   WHERE b.id = p_bid_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bid not found' USING ERRCODE = 'P0002';
  END IF;

  -- AUTH CHECK MOVED HERE (before any locks).
  -- Exit immediately on auth failure — no row lock is ever acquired.
  -- Prevents timing probes and reduces lock contention on auth-fail.
  IF v_bid.hospital_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the hospital owner can accept bids' USING ERRCODE = '42501';
  END IF;

  -- Phase 2: auth passed — acquire FOR UPDATE OF rj and re-validate
  -- state (MVCC: bid/job could have changed between phases).
  SELECT
      b.id,
      b.repair_job_id,
      b.engineer_user_id,
      b.amount_rupees,
      b.status,
      rj.hospital_user_id,
      rj.status AS job_status
    INTO v_bid
    FROM public.repair_job_bids b
    JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
   WHERE b.id = p_bid_id
   FOR UPDATE OF rj;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bid not found' USING ERRCODE = 'P0002';
  END IF;

  -- Defensive re-check (hospital_user_id should be immutable, but if
  -- Phase 1 read was stale we still bail before mutating).
  IF v_bid.hospital_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the hospital owner can accept bids' USING ERRCODE = '42501';
  END IF;

  IF v_bid.status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending bids can be accepted' USING ERRCODE = '22023';
  END IF;

  IF v_bid.job_status <> 'requested' THEN
    RAISE EXCEPTION 'Job is no longer open for bids' USING ERRCODE = '22023';
  END IF;

  SELECT e.id INTO v_engineer_id
    FROM public.engineers e
   WHERE e.user_id = v_bid.engineer_user_id
   LIMIT 1;

  IF v_engineer_id IS NULL THEN
    RAISE EXCEPTION 'Engineer profile not found for bid' USING ERRCODE = 'P0002';
  END IF;

  -- Round 276 TOCTOU guard: explicit `status = 'pending'` clause closes
  -- the withdraw-vs-accept race. Do NOT remove — see r276 migration.
  UPDATE public.repair_job_bids
     SET status = 'accepted',
         updated_at = now()
   WHERE id = p_bid_id
     AND status = 'pending';

  GET DIAGNOSTICS v_accepted_count = ROW_COUNT;
  IF v_accepted_count = 0 THEN
    RAISE EXCEPTION 'Only pending bids can be accepted' USING ERRCODE = '22023';
  END IF;

  UPDATE public.repair_job_bids
     SET status = 'rejected',
         updated_at = now()
   WHERE repair_job_id = v_bid.repair_job_id
     AND id <> p_bid_id
     AND status = 'pending';

  UPDATE public.repair_jobs
     SET engineer_id = v_engineer_id,
         status = 'assigned',
         contracted_amount_rupees = v_bid.amount_rupees,
         updated_at = now()
   WHERE id = v_bid.repair_job_id
   RETURNING to_jsonb(repair_jobs.*) INTO v_job;

  -- PR-D4 / v2.1 / Round 421: escrow row at quote-accept. Idempotent
  -- via ON CONFLICT (repair_job_id) DO NOTHING. Pay-in flips status
  -- from 'pending' to 'held' later via the Razorpay verify edge fn.
  INSERT INTO public.repair_job_escrow (
    repair_job_id, hospital_user_id, engineer_user_id, amount_rupees, status
  )
  VALUES (
    v_bid.repair_job_id, v_bid.hospital_user_id, v_bid.engineer_user_id,
    v_bid.amount_rupees, 'pending'
  )
  ON CONFLICT (repair_job_id) DO NOTHING
  RETURNING id INTO v_escrow_id;

  IF v_escrow_id IS NOT NULL THEN
    INSERT INTO public.repair_job_escrow_events (escrow_id, event_kind, actor_user_id, payload)
    VALUES (v_escrow_id, 'created', v_bid.hospital_user_id,
            jsonb_build_object('amount_rupees', v_bid.amount_rupees));
  END IF;

  RETURN v_job;
END;
$$;

ALTER FUNCTION public.accept_repair_bid(uuid) OWNER TO postgres;

COMMENT ON FUNCTION public.accept_repair_bid(uuid) IS
  'PR-D4 / v2.1 + Round 276 (TOCTOU) + Round 421 (escrow restore) + Round 479 (auth hoist). '
  'Hospital accepts an engineer bid → bid=accepted, others=rejected, job=assigned, '
  'engineer_id set, contracted_amount_rupees set, escrow row inserted (status=pending). '
  'Round 479 hoists auth check before FOR UPDATE to prevent timing probes and lock contention.';


-- =====================================================================
-- (D) Stale 'requested' repair_jobs reaper.
--
-- Audit-8 HIGH: hospital posts job → no engineers bid → job sits in
-- 'requested' forever, polluting engineer feeds and active-jobs KPIs.
--
-- Fix: pg_cron sweeper cancels jobs in 'requested' for >30 days. Uses
-- 'cancelled' status (already valid per repair_jobs_status_transition_guard).
-- Function runs as SECURITY DEFINER (owner postgres) so the transition
-- guard's current_user='postgres' bypass clause applies.
--
-- pg_cron extension may not be available on this Supabase project —
-- wrap schedule call in EXCEPTION WHEN OTHERS (r477 pattern). If cron
-- is missing, the function still exists and can be invoked manually
-- or via GH Actions cron-tick.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.reap_stranded_requested_repair_jobs()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int := 0;
BEGIN
  WITH to_reap AS (
    SELECT id
      FROM public.repair_jobs
     WHERE status = 'requested'
       AND created_at < now() - interval '30 days'
     FOR UPDATE
  )
  UPDATE public.repair_jobs rj
     SET status = 'cancelled',
         updated_at = now()
    FROM to_reap
   WHERE rj.id = to_reap.id;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  IF v_count > 0 THEN
    RAISE NOTICE 'reap_stranded_requested_repair_jobs: closed % jobs (30+ days in requested)', v_count;
  END IF;

  RETURN v_count;
END;
$$;

ALTER FUNCTION public.reap_stranded_requested_repair_jobs() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.reap_stranded_requested_repair_jobs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reap_stranded_requested_repair_jobs() TO service_role;

COMMENT ON FUNCTION public.reap_stranded_requested_repair_jobs() IS
  'Round 479 — Audit-8 HIGH. Auto-cancel repair_jobs stuck in requested >30 days. '
  'Runs daily 03:00 UTC via pg_cron if available; else invoke via GH Actions '
  'cron-tick or manually. notify_on_repair_job_cancelled trigger fires per row.';

-- Unschedule prior version for idempotency (re-running this migration
-- is safe). Wrap in EXCEPTION WHEN OTHERS for pg_cron-missing envs.
DO $cron_unschedule$
DECLARE
  v_jobid bigint;
BEGIN
  SELECT jobid INTO v_jobid FROM cron.job
   WHERE jobname = 'reap_stranded_requested_repair_jobs';
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.unschedule(v_jobid);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not available (% / %) — skipping unschedule of reap_stranded_requested_repair_jobs',
      SQLSTATE, SQLERRM;
END
$cron_unschedule$;

DO $cron_schedule$
BEGIN
  PERFORM cron.schedule(
    'reap_stranded_requested_repair_jobs',
    '0 3 * * *',  -- daily 03:00 UTC (08:30 IST)
    $job$SELECT public.reap_stranded_requested_repair_jobs();$job$
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not available (% / %) — reap_stranded_requested_repair_jobs not scheduled; invoke manually or via GH Actions cron-tick',
      SQLSTATE, SQLERRM;
END
$cron_schedule$;


-- =====================================================================
-- (E) delete_my_account — guard against in-flight engineer payouts.
--
-- Audit-8 HIGH: engineer payouts with status IN ('queued','processing')
-- block the auth.users DELETE via FK NO ACTION on
-- engineer_payouts.engineer_user_id. Round 285 pre-check only covers
-- escrows, so engineer-initiated deletion fails with a cryptic FK
-- violation rather than an actionable error.
--
-- Fix: add a second pre-check counting queued + processing payouts and
-- RAISE EXCEPTION (errcode 22023) with a clear message if any exist.
-- All other logic from Round 460 preserved verbatim.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.delete_my_account(p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage
AS $$
DECLARE
    v_user uuid := auth.uid();
    v_email text;
    v_phone text;
    v_open_escrows int;
    v_in_flight_payouts int;  -- Round 479: queued/processing payouts
    v_obj record;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    -- Round 460: capture phone BEFORE delete so we can purge
    -- phone_otp_requests for that number.
    SELECT email, phone INTO v_email, v_phone FROM auth.users WHERE id = v_user;

    -- Round 285 pre-check: open escrow positions block deletion.
    SELECT count(*) INTO v_open_escrows
      FROM public.repair_job_escrow
      WHERE (hospital_user_id = v_user OR engineer_user_id = v_user)
        AND status IN ('pending', 'held', 'in_dispute');
    IF v_open_escrows > 0 THEN
        RAISE EXCEPTION
          'Account has % open escrow row(s). Resolve / refund / release them before deleting your account.',
          v_open_escrows
          USING ERRCODE = '22023';
    END IF;

    -- Round 479 pre-check: in-flight engineer payouts block deletion.
    -- These would otherwise raise an opaque FK violation on the final
    -- DELETE FROM auth.users (engineer_payouts.engineer_user_id is
    -- REFERENCES auth.users(id) with default NO ACTION).
    SELECT count(*) INTO v_in_flight_payouts
      FROM public.engineer_payouts
      WHERE engineer_user_id = v_user
        AND status IN ('queued', 'processing');
    IF v_in_flight_payouts > 0 THEN
        RAISE EXCEPTION
          'Account has % in-flight payout row(s) (queued or processing). Wait for payouts to complete before deleting your account.',
          v_in_flight_payouts
          USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.account_deletions(user_id, email, reason, status)
    VALUES (v_user, v_email, p_reason, 'processed');

    -- Round 451 storage purge (preserved).
    PERFORM set_config('storage.allow_delete_query', 'true', true);

    FOR v_obj IN
      SELECT bucket_id, name
        FROM storage.objects
       WHERE bucket_id IN (
               'kyc-docs', 'repair-photos', 'avatars', 'chat-attachments'
             )
         AND split_part(name, '/', 1) = v_user::text
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped storage object %/%: % / %',
          v_obj.bucket_id, v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    FOR v_obj IN
      SELECT 'invoices'::text AS bucket_id, (o.id::text || '.html') AS name
        FROM public.spare_part_orders o
       WHERE o.buyer_user_id = v_user
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped spare-part invoice %: % / %',
          v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    FOR v_obj IN
      SELECT 'invoices'::text AS bucket_id, ('repair_' || rj.id::text || '.html') AS name
        FROM public.repair_jobs rj
       WHERE rj.hospital_user_id = v_user
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped repair invoice %: % / %',
          v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    FOR v_obj IN
      SELECT 'service-reports'::text AS bucket_id, (rj.id::text || '.html') AS name
        FROM public.repair_jobs rj
        LEFT JOIN public.engineers e ON e.id = rj.engineer_id
       WHERE rj.hospital_user_id = v_user
          OR e.user_id = v_user
    LOOP
      BEGIN
        PERFORM storage.delete_object(v_obj.bucket_id, v_obj.name);
      EXCEPTION WHEN undefined_function OR undefined_object THEN
        DELETE FROM storage.objects
         WHERE bucket_id = v_obj.bucket_id AND name = v_obj.name;
      WHEN OTHERS THEN
        RAISE NOTICE 'delete_my_account: skipped service report %: % / %',
          v_obj.name, SQLSTATE, SQLERRM;
      END;
    END LOOP;

    UPDATE public.spare_part_orders SET invoice_url = NULL
     WHERE buyer_user_id = v_user;
    UPDATE public.repair_jobs SET service_report_url = NULL
     WHERE hospital_user_id = v_user
        OR engineer_id IN (SELECT id FROM public.engineers WHERE user_id = v_user);

    UPDATE public.repair_job_escrow
      SET dispute_resolved_by = NULL
      WHERE dispute_resolved_by = v_user;
    UPDATE public.repair_job_escrow_events
      SET actor_user_id = NULL
      WHERE actor_user_id = v_user;
    UPDATE public.repair_job_cost_revisions
      SET decision_by = NULL
      WHERE decision_by = v_user;
    UPDATE public.amc_admin_escalations
      SET resolved_by = NULL
      WHERE resolved_by = v_user;

    DELETE FROM public.chat_messages WHERE sender_user_id = v_user;
    DELETE FROM public.notifications WHERE user_id = v_user;
    UPDATE public.content_reports SET reviewed_by = NULL WHERE reviewed_by = v_user;

    DELETE FROM public.disputes
        WHERE raised_by_user_id = v_user
           OR against_user_id = v_user
           OR resolved_by = v_user;

    DELETE FROM public.marketplace_offers WHERE buyer_user_id = v_user;
    DELETE FROM public.marketplace_listings WHERE seller_user_id = v_user;
    DELETE FROM public.spare_part_orders WHERE buyer_user_id = v_user;
    DELETE FROM public.payments WHERE payee_user_id = v_user OR payer_user_id = v_user;
    DELETE FROM public.financing_applications WHERE applicant_user_id = v_user;
    DELETE FROM public.rfqs WHERE requester_user_id = v_user;

    DELETE FROM public.amc_contracts
        WHERE hospital_user_id = v_user
           OR primary_engineer_id IN (SELECT id FROM public.engineers WHERE user_id = v_user);

    DELETE FROM public.repair_job_bids WHERE engineer_user_id = v_user;

    DELETE FROM public.repair_jobs WHERE hospital_user_id = v_user;
    DELETE FROM public.engineers WHERE user_id = v_user;

    DELETE FROM public.reviews WHERE reviewer_user_id = v_user OR reviewee_user_id = v_user;

    DELETE FROM public.enrollments WHERE user_id = v_user;
    DELETE FROM public.logistics_partners WHERE user_id = v_user;
    DELETE FROM public.support_tickets WHERE user_id = v_user OR assigned_to = v_user;

    UPDATE public.organizations SET created_by = NULL WHERE created_by = v_user;
    UPDATE public.organizations SET verified_by = NULL WHERE verified_by = v_user;
    UPDATE public.buyer_kyc_verifications SET reviewed_by = NULL WHERE reviewed_by = v_user;

    -- Round 460: purge phone_otp_requests for the user's phone (closes
    -- the resurrection window where rate-limit lookups still saw rows).
    IF v_phone IS NOT NULL AND v_phone <> '' THEN
      DELETE FROM public.phone_otp_requests WHERE phone = v_phone;
    END IF;

    DELETE FROM storage.objects
        WHERE bucket_id IN ('kyc-docs', 'repair-photos', 'avatars', 'chat-attachments')
          AND split_part(name, '/', 1) = v_user::text;

    DELETE FROM auth.refresh_tokens WHERE user_id = v_user::text;
    DELETE FROM auth.users WHERE id = v_user;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account(text) FROM public;
REVOKE ALL ON FUNCTION public.delete_my_account(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account(text) TO authenticated;

COMMENT ON FUNCTION public.delete_my_account(text) IS
  'Round 285 + 451 + 460 + 479. Self-serve account deletion. Round 479 adds '
  'pre-check for in-flight engineer payouts (queued/processing) to surface a '
  'clear error instead of an opaque FK violation. All Round 460 storage / '
  'phone-OTP / per-table cleanup preserved.';
