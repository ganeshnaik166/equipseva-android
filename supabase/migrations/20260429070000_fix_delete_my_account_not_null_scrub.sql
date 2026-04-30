-- Fix delete_my_account: profiles.full_name is NOT NULL, so scrub to a
-- placeholder string instead of null. The original 20260424120000 migration
-- assumed nullable, which broke the RPC with a NOT NULL constraint violation
-- the first time a real user tried to delete.

create or replace function public.delete_my_account(p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user uuid := auth.uid();
begin
    if v_user is null then
        raise exception 'Not authenticated' using errcode = '42501';
    end if;

    insert into public.account_deletions(user_id, reason, status)
    values (v_user, p_reason, 'pending');

    update public.profiles
       set full_name = '[deleted]',
           phone = null,
           avatar_url = null,
           is_active = false,
           onboarding_completed = false,
           organization_id = null
     where id = v_user;

    delete from public.device_tokens where user_id = v_user;
end;
$$;

revoke all on function public.delete_my_account(text) from public;
revoke all on function public.delete_my_account(text) from anon;
grant execute on function public.delete_my_account(text) to authenticated;
