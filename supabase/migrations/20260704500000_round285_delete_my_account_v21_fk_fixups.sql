-- Round 285 — close FK gaps that block delete_my_account on v2.1 tables.
--
-- 20260626120000_delete_my_account_v21_cleanup.sql extended cleanup to
-- amc_contracts / repair_job_bids / engineers — good for v2.1's release
-- snapshot at the time. Since then, more tables landed with auth.users
-- FKs that DEFAULT to NO ACTION (RESTRICT semantics), and they are NOT
-- handled by the cleanup function. Concrete failure modes today:
--
--   * repair_job_escrow.hospital_user_id (NOT NULL, no ON DELETE) →
--     final auth.users delete fails with FK violation if hospital ever
--     paid into escrow.
--   * repair_job_escrow.engineer_user_id (NOT NULL, no ON DELETE) →
--     same for the engineer side.
--   * repair_job_escrow.dispute_resolved_by (nullable, no ON DELETE) →
--     blocks delete for any admin/founder who ever resolved a dispute.
--   * repair_job_escrow_events.actor_user_id (nullable, no ON DELETE) →
--     blocks delete for anyone who ever interacted with an escrow
--     (creates the row on every paid / disputed / resolved event).
--   * repair_job_cost_revisions.decision_by (nullable, no ON DELETE) →
--     blocks delete for hospitals who decided a cost revision.
--   * amc_admin_escalations.resolved_by (nullable, no ON DELETE) →
--     blocks delete for admins who resolved an ops escalation.
--
-- The fix has two halves:
--
-- 1. For nullable audit-only columns (dispute_resolved_by,
--    actor_user_id, decision_by, amc_admin_escalations.resolved_by) we
--    UPDATE-to-NULL inside delete_my_account before the auth.users
--    delete. The audit row stays in place; we just lose the
--    "who did it" attribution for the departed user, which is the
--    legally-correct behaviour for a DPDP delete request anyway.
--
-- 2. For NOT NULL escrow.hospital_user_id / engineer_user_id we raise
--    a friendly error if any non-terminal escrow row references the
--    user. They must settle (resolve / refund / release) before they
--    can delete. Terminal escrows (released / refunded / cancelled)
--    still block today — fixing those needs the FK to go nullable
--    with ON DELETE SET NULL, which is a bigger schema change and
--    lives in a follow-up PR. For now, surface a clear message:
--      "Open escrow rows exist; resolve or refund them before
--       deleting your account."

CREATE OR REPLACE FUNCTION public.delete_my_account(p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage
AS $$
DECLARE
    v_user uuid := auth.uid();
    v_email text;
    v_open_escrows int;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = v_user;

    -- Round 285 pre-check — bail before any cleanup if the user has
    -- in-flight escrow positions. Cleaning up partially and then
    -- failing the auth.users delete would leave an inconsistent
    -- account_deletions row with no actual user gone.
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

    -- Round 285 — null out nullable audit references so the auth.users
    -- delete at the bottom of this function isn't blocked by a
    -- DEFAULT-NO-ACTION FK. Each column points at "who did this admin
    -- action" — losing the reference doesn't corrupt the financial
    -- row; the audit log preserves what happened, just not who.
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

    -- v2.1 additions (from 20260626120000) ----------------------------
    DELETE FROM public.amc_contracts
        WHERE hospital_user_id = v_user
           OR primary_engineer_id IN (SELECT id FROM public.engineers WHERE user_id = v_user);

    DELETE FROM public.repair_job_bids WHERE engineer_user_id = v_user;

    DELETE FROM public.repair_jobs WHERE hospital_user_id = v_user;
    DELETE FROM public.engineers WHERE user_id = v_user;
    -- ---------------------------------------------------------------

    DELETE FROM public.reviews WHERE reviewer_user_id = v_user OR reviewee_user_id = v_user;

    DELETE FROM public.enrollments WHERE user_id = v_user;
    DELETE FROM public.logistics_partners WHERE user_id = v_user;
    DELETE FROM public.support_tickets WHERE user_id = v_user OR assigned_to = v_user;

    UPDATE public.organizations SET created_by = NULL WHERE created_by = v_user;
    UPDATE public.organizations SET verified_by = NULL WHERE verified_by = v_user;
    UPDATE public.buyer_kyc_verifications SET reviewed_by = NULL WHERE reviewed_by = v_user;

    PERFORM set_config('storage.allow_delete_query', 'true', true);
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
