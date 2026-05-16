-- Round 291 — extend delete_my_account to clean up chat_conversations
-- the user participated in.
--
-- Round 285 (PR #733) deletes chat_messages WHERE sender_user_id =
-- v_user, but leaves chat_conversations rows in place even when the
-- user is in `participant_user_ids`. Two failure modes:
--
--   1. The other party's chat inbox keeps a "ghost" conversation
--      where the deleted user contributed nothing (their messages
--      were hard-deleted by the round 285 step). Display sites
--      render the conversation with an empty body and a counterpart
--      name resolved from a vanished profile row — UX confusion.
--
--   2. DPDP compliance: the deleted user's participation in a
--      conversation is itself PII (you-talked-with-X). Leaving the
--      row in place means a forensic scan of chat_conversations
--      still reveals their account ID in participant_user_ids,
--      which is exactly what a delete-my-data request is meant to
--      wipe.
--
-- Fix: delete conversations where the user is a participant. The
-- other party's chat history goes too — that's the cost of the
-- deleted user's right to be forgotten (DPDP gives priority to the
-- data principal).
--
-- chat_messages.conversation_id FK is ON DELETE CASCADE so the
-- conversation delete propagates without us needing a separate
-- delete on messages from the OTHER party. (Our round-285 step
-- earlier deleted the user's own messages; this conversation delete
-- now sweeps everything else.)
--
-- Idempotent: re-applying replaces the function definition.

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

    -- Round 285 pre-check.
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

    -- Round 285 — NULL audit references before the auth.users delete.
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
    -- Round 291 — also clear conversations the user participated in.
    -- chat_messages.conversation_id is ON DELETE CASCADE so the other
    -- party's messages on these conversations get swept too.
    DELETE FROM public.chat_conversations
        WHERE v_user = ANY(participant_user_ids);
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
