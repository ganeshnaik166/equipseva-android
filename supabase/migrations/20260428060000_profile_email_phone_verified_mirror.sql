-- Mirror Supabase's native auth.users.{email,phone}_confirmed_at into the
-- public.profiles row so the client can decide whether to nudge the user
-- with a "Verify email/phone" CTA without RPC-ing auth on every render.
--
-- Two new boolean columns + an AFTER UPDATE trigger on auth.users that
-- flips them whenever Supabase confirms a code. Backfill runs once on
-- migration apply so any pre-existing confirmed users start true.

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS email_verified boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS phone_verified boolean NOT NULL DEFAULT false;

-- Backfill from current auth.users state. Supabase's auth schema is owned
-- by the postgres role, so this runs cleanly during migration but not from
-- regular API contexts.
UPDATE public.profiles p
SET email_verified = (u.email_confirmed_at IS NOT NULL),
    phone_verified = (u.phone_confirmed_at IS NOT NULL)
FROM auth.users u
WHERE u.id = p.id;

-- Trigger function: fire on every auth.users update; if either confirmed_at
-- column flipped from null → not-null (or vice versa) push the new boolean
-- into the matching profile row. SECURITY DEFINER so it can write across
-- schemas under the auth-trigger context.
CREATE OR REPLACE FUNCTION public.sync_profile_verified_from_auth()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE public.profiles
    SET email_verified = (NEW.email_confirmed_at IS NOT NULL),
        phone_verified = (NEW.phone_confirmed_at IS NOT NULL)
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_verified_from_auth ON auth.users;
CREATE TRIGGER sync_profile_verified_from_auth
    AFTER UPDATE OF email_confirmed_at, phone_confirmed_at ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_profile_verified_from_auth();

-- Also fire on insert so the very first signup gets the flags right.
CREATE OR REPLACE FUNCTION public.sync_profile_verified_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- profiles row may not exist yet (handle_new_user trigger creates it).
    -- Run a no-op-on-missing UPDATE so we don't race the creator.
    UPDATE public.profiles
    SET email_verified = (NEW.email_confirmed_at IS NOT NULL),
        phone_verified = (NEW.phone_confirmed_at IS NOT NULL)
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_verified_on_insert ON auth.users;
CREATE TRIGGER sync_profile_verified_on_insert
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_profile_verified_on_insert();
