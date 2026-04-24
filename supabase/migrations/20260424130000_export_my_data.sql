-- DPDP (Digital Personal Data Protection Act, India) right-to-portability.
-- A signed-in user calls public.export_my_data() and gets a single JSONB
-- payload containing every public.* row they own — profile, conversations,
-- listings, jobs, bids, payments, notifications, reports, blocks, etc.
-- The function is SECURITY DEFINER and filtered strictly by auth.uid(); no
-- orgs/equipment/catalog data that isn't tied to the user is included.

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user uuid := auth.uid();
    v_data jsonb;
begin
    if v_user is null then
        raise exception 'Not authenticated' using errcode = '42501';
    end if;

    select jsonb_build_object(
        'exported_at', now(),
        'user_id', v_user,
        'schema_version', 1,
        'profile',
            (select to_jsonb(p) from public.profiles p where p.id = v_user),
        'chat_conversations',
            coalesce((select jsonb_agg(c) from public.chat_conversations c
                       where v_user = any(c.participant_user_ids)), '[]'::jsonb),
        'chat_messages',
            coalesce((select jsonb_agg(m) from public.chat_messages m
                       where m.sender_user_id = v_user), '[]'::jsonb),
        'spare_part_orders',
            coalesce((select jsonb_agg(o) from public.spare_part_orders o
                       where o.buyer_user_id = v_user), '[]'::jsonb),
        'marketplace_listings',
            coalesce((select jsonb_agg(l) from public.marketplace_listings l
                       where l.seller_user_id = v_user), '[]'::jsonb),
        'repair_jobs',
            coalesce((select jsonb_agg(r) from public.repair_jobs r
                       where r.hospital_user_id = v_user), '[]'::jsonb),
        'repair_job_bids',
            coalesce((select jsonb_agg(b) from public.repair_job_bids b
                       where b.engineer_user_id = v_user), '[]'::jsonb),
        'rfqs',
            coalesce((select jsonb_agg(r) from public.rfqs r
                       where r.requester_user_id = v_user), '[]'::jsonb),
        'reviews_authored',
            coalesce((select jsonb_agg(r) from public.reviews r
                       where r.reviewer_user_id = v_user), '[]'::jsonb),
        'reviews_received',
            coalesce((select jsonb_agg(r) from public.reviews r
                       where r.reviewee_user_id = v_user), '[]'::jsonb),
        'payments',
            coalesce((select jsonb_agg(p) from public.payments p
                       where p.payer_user_id = v_user or p.payee_user_id = v_user), '[]'::jsonb),
        'bank_accounts',
            coalesce((select jsonb_agg(b) from public.bank_accounts b
                       where b.user_id = v_user), '[]'::jsonb),
        'notifications',
            coalesce((select jsonb_agg(n) from public.notifications n
                       where n.user_id = v_user), '[]'::jsonb),
        'content_reports',
            coalesce((select jsonb_agg(r) from public.content_reports r
                       where r.reporter_user_id = v_user), '[]'::jsonb),
        'user_blocks',
            coalesce((select jsonb_agg(b) from public.user_blocks b
                       where b.blocker_user_id = v_user), '[]'::jsonb),
        'account_deletions',
            coalesce((select jsonb_agg(d) from public.account_deletions d
                       where d.user_id = v_user), '[]'::jsonb)
    ) into v_data;

    return v_data;
end;
$$;

revoke all on function public.export_my_data() from public;
grant execute on function public.export_my_data() to authenticated;
