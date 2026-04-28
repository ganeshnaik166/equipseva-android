-- Tighten profiles SELECT to self-only. Currently any authenticated user can
-- scrape every other user's email + phone via REST against the profiles
-- table. The verified-engineer directory + chat avatar lookups go through
-- a new SECURITY DEFINER RPC that returns ONLY (id, full_name, avatar_url).

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;

CREATE POLICY "Users can read their own profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = id);

CREATE OR REPLACE FUNCTION public.public_profiles_minimal(p_user_ids uuid[])
RETURNS TABLE (
    id uuid,
    full_name text,
    avatar_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT id, full_name, avatar_url
    FROM public.profiles
    WHERE id = ANY(p_user_ids);
$$;

REVOKE ALL ON FUNCTION public.public_profiles_minimal(uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.public_profiles_minimal(uuid[]) TO authenticated;
