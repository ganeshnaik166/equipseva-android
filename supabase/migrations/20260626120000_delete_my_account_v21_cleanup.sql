-- delete_my_account() was written for v1 and missed every user-scoped
-- table that landed in v2.1: amc_contracts, repair_job_bids, the
-- engineers row itself. Two concrete failure modes today:
--
--   * Hospital with at least one amc_contracts row can't delete their
--     account at all — the final `delete from auth.users where id=v_user`
--     fails with a foreign-key violation because amc_contracts.hospital_user_id
--     references auth.users with ON DELETE RESTRICT.
--   * Engineer with at least one amc_contracts.primary_engineer_id
--     reference can't delete for the same reason.
--   * Engineer with queued repair_job_bids leaves orphan rows where the
--     RLS-readable engineer_user_id points at a deleted account.
--
-- This migration extends the cleanup block to cover those tables. Order
-- matters: amc_contracts must go before engineers (because of the
-- primary_engineer_id RESTRICT FK), and engineers before auth.users
-- (so the engineers→auth.users FK doesn't block the final auth delete).
-- repair_jobs.engineer_id is already ON DELETE SET NULL (migration
-- 20260425160000) so historical jobs survive as audit rows with a null
-- engineer reference.

create or replace function public.delete_my_account(p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
    v_user uuid := auth.uid();
    v_email text;
begin
    if v_user is null then
        raise exception 'Not authenticated' using errcode = '42501';
    end if;

    select email into v_email from auth.users where id = v_user;

    insert into public.account_deletions(user_id, email, reason, status)
    values (v_user, v_email, p_reason, 'processed');

    delete from public.chat_messages where sender_user_id = v_user;
    delete from public.notifications where user_id = v_user;
    update public.content_reports set reviewed_by = null where reviewed_by = v_user;

    delete from public.disputes
        where raised_by_user_id = v_user
           or against_user_id = v_user
           or resolved_by = v_user;

    delete from public.marketplace_offers where buyer_user_id = v_user;
    delete from public.marketplace_listings where seller_user_id = v_user;
    delete from public.spare_part_orders where buyer_user_id = v_user;
    delete from public.payments where payee_user_id = v_user or payer_user_id = v_user;
    delete from public.financing_applications where applicant_user_id = v_user;
    delete from public.rfqs where requester_user_id = v_user;

    -- v2.1 additions ----------------------------------------------------
    -- Hospitals: cancel + drop any AMC contracts they own. Engineers:
    -- drop AMC contracts where they're the primary engineer. amc_visits
    -- + amc_payment_ledger cascade on amc_contracts.id, so this single
    -- delete clears them.
    delete from public.amc_contracts
        where hospital_user_id = v_user
           or primary_engineer_id in (select id from public.engineers where user_id = v_user);

    -- Engineers' bids on any job (including jobs owned by other
    -- hospitals that we're NOT deleting here).
    delete from public.repair_job_bids where engineer_user_id = v_user;

    -- Hospital repair-jobs first (existing line). Then the engineer's
    -- engineers row — repair_jobs.engineer_id is ON DELETE SET NULL so
    -- audit rows survive with a null assignee.
    delete from public.repair_jobs where hospital_user_id = v_user;
    delete from public.engineers where user_id = v_user;
    -- -------------------------------------------------------------------

    delete from public.reviews where reviewer_user_id = v_user or reviewee_user_id = v_user;

    delete from public.enrollments where user_id = v_user;
    delete from public.logistics_partners where user_id = v_user;
    delete from public.support_tickets where user_id = v_user or assigned_to = v_user;

    update public.organizations set created_by = null where created_by = v_user;
    update public.organizations set verified_by = null where verified_by = v_user;
    update public.buyer_kyc_verifications set reviewed_by = null where reviewed_by = v_user;

    perform set_config('storage.allow_delete_query', 'true', true);
    delete from storage.objects
        where bucket_id in ('kyc-docs', 'repair-photos', 'avatars', 'chat-attachments')
          and split_part(name, '/', 1) = v_user::text;

    delete from auth.refresh_tokens where user_id = v_user::text;
    delete from auth.users where id = v_user;
end;
$$;

revoke all on function public.delete_my_account(text) from public;
revoke all on function public.delete_my_account(text) from anon;
grant execute on function public.delete_my_account(text) to authenticated;
