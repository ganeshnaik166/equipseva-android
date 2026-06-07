-- Round 460 — account-resignup hygiene + migration idempotency
-- (1 LOW from audit 4 + 1 MED re-apply hazard).
--
--   1. LOW (resurrection_friction) — phone_otp_requests rows survive
--      account delete by phone column. ON DELETE SET NULL wipes the
--      user_id but the phone column persists, so a user who deletes
--      and resurrects with the same phone within an hour gets
--      rate-limited (4-OTP-per-hour budget consumed by the prior
--      identity). Round 304 TTL purges only past-7-days rows, so the
--      resurrection-window friction is real until midnight.
--      Fix: extend delete_my_account to DELETE rows where phone = the
--      user's auth.users.phone BEFORE the auth.users row goes (need
--      the lookup to resolve the phone in advance).
--
--   2. MED (re-apply idempotency) — round 419 (20260711000000) adds a
--      CHECK constraint on profiles.state without DROP IF EXISTS.
--      Re-applying that migration (CI fresh-apply, dev reset, manual
--      replay) fails with "constraint ... already exists". The same
--      shape exists for profiles.district. Round 449 already follows
--      the correct DROP+ADD pattern for gstin_format — back-port to
--      419. Belt-and-suspenders for any future replay.

-- ---------------------------------------------------------------------
-- 1. delete_my_account — purge phone_otp_requests by phone
-- ---------------------------------------------------------------------
-- We preserve every existing step from the round 451 redefinition
-- (storage purge → audit nulls → row deletes → auth.users delete) and
-- splice a one-liner that captures the user's phone BEFORE the
-- auth.users row is deleted so we can purge phone_otp_requests by
-- that phone. The ON DELETE SET NULL on user_id stays; we add the
-- phone-based purge as a separate explicit step.

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
    v_obj record;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    -- Round 460: capture phone BEFORE the user row is deleted so we
    -- can purge phone_otp_requests for that number.
    SELECT email, phone INTO v_email, v_phone FROM auth.users WHERE id = v_user;

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

    -- Round 460 fix #1: purge phone_otp_requests for the user's phone.
    -- The ON DELETE SET NULL on user_id already wipes the user_id when
    -- auth.users is deleted, but the phone-based rate-limit lookup
    -- (phone_otp_can_request) still sees historical rows. Purging by
    -- phone closes the resurrection window. v_phone captured at top.
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

-- ---------------------------------------------------------------------
-- 2. profiles state/district CHECK — drop-and-add for idempotent replay
-- ---------------------------------------------------------------------
-- Round 419's migration uses bare ADD CONSTRAINT, which 42P07s on
-- re-apply. CHECK constraints can be re-defined safely; the values
-- remain valid because no rows have changed shape since the original
-- ship. Drop-and-add makes the migration idempotent for fresh applies
-- on dev / staging / CI.

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_state_len_chk;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_state_len_chk
  CHECK (state IS NULL OR length(state) BETWEEN 1 AND 64);

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_district_len_chk;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_district_len_chk
  CHECK (district IS NULL OR length(district) BETWEEN 1 AND 64);
