-- Block re-login on a deleted account. Hard-delete of auth.users hits FK
-- violations (chat_messages / repair_jobs / payments / reviews are all
-- ON DELETE NO ACTION), so we keep the soft-delete but:
--   1. Drop the cascade FK on account_deletions so the audit row survives
--      any future cleanup of auth.users.
--   2. Capture the deleted user's email at write time for forensics.
--   3. Invalidate every refresh_token so the user is signed out from every
--      device immediately.
-- The client checks profiles.is_active on each sign-in and bounces with
-- "Account deleted" if the row was scrubbed.

alter table public.account_deletions
    drop constraint if exists account_deletions_user_id_fkey;

alter table public.account_deletions
    add column if not exists email text;

create or replace function public.delete_my_account(p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public, auth
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
    values (v_user, v_email, p_reason, 'pending');

    update public.profiles
       set full_name = '[deleted]',
           phone = null,
           avatar_url = null,
           is_active = false,
           onboarding_completed = false,
           organization_id = null
     where id = v_user;

    delete from public.device_tokens where user_id = v_user;
    delete from auth.refresh_tokens where user_id = v_user::text;
end;
$$;

revoke all on function public.delete_my_account(text) from public;
revoke all on function public.delete_my_account(text) from anon;
grant execute on function public.delete_my_account(text) to authenticated;
