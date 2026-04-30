-- Storage cleanup needs `storage.allow_delete_query` session-local flag set
-- to 'true' to bypass storage.protect_delete trigger. Without this, the
-- prior migration's storage.objects delete failed with 42501.

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

    delete from public.repair_jobs where hospital_user_id = v_user;
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
