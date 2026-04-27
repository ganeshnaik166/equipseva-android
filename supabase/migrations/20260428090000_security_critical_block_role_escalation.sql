-- CRITICAL FIX: handle_new_user trusted raw_user_meta_data->>'role' from the
-- signup payload, so a malicious signup with `data: {role: 'admin'}` would
-- create an admin profile. Ignore the meta_data role entirely and force the
-- safe default 'engineer'. Role changes after signup go through the gated
-- add_role / set_active_role RPCs.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, phone, full_name, avatar_url, role)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'name',
            split_part(COALESCE(NEW.email, 'user@equipseva'), '@', 1)
        ),
        NEW.raw_user_meta_data->>'avatar_url',
        -- HARDCODED. Do NOT read from raw_user_meta_data — that's
        -- attacker-controlled.
        'engineer'::public.user_role
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user failed for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$;

-- Belt + suspenders: revoke direct UPDATE on `role` from authenticated
-- users so even if an attacker reaches the column via PostgREST they can't
-- self-elevate. Roles change exclusively via the SECURITY DEFINER add_role +
-- set_active_role RPCs which validate the caller is allowed the target role.
REVOKE UPDATE (role) ON public.profiles FROM PUBLIC, authenticated, anon;
