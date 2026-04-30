-- Bug: signup fails with 500 "Database error updating user" because the
-- sync_profile_verified_on_insert trigger UPDATEs profiles.email_verified
-- right after the row is created. profiles_verification_columns_guard
-- raises 42501 because the connection's session_user is supabase_auth_admin
-- (the GoTrue role), not postgres. SECURITY DEFINER functions change
-- current_user to postgres but session_user stays — so the guard blocks
-- the trigger's own writes.
--
-- Fix: also bypass the guard when current_user = 'postgres' (i.e. running
-- inside a SECURITY DEFINER function owned by postgres). Anon + authenticated
-- client writes still hit current_user = 'authenticated' / 'anon' and remain
-- blocked.

create or replace function public.profiles_verification_columns_guard()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
    v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
begin
    if v_caller_role = 'service_role'
       or session_user = 'postgres'
       or current_user = 'postgres' then
        return new;
    end if;
    if public.is_founder() or public.is_admin(auth.uid()) then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if coalesce(new.email_verified, false) <> false
           or coalesce(new.phone_verified, false) <> false then
            raise exception 'profiles.email_verified / phone_verified must start false'
                using errcode = '42501';
        end if;
        return new;
    end if;

    if new.email_verified is distinct from old.email_verified
       or new.phone_verified is distinct from old.phone_verified then
        raise exception
            'email_verified / phone_verified are auth-trigger-driven; client cannot write'
            using errcode = '42501';
    end if;

    return new;
end;
$$;
