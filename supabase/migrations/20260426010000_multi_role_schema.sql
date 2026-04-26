-- S0a: Multi-role schema (additive only — no destructive changes).
--
-- Today every profile holds exactly one `role` (single user_role enum). The
-- new Global Service Hub lets a user hold many services at once (Hospital +
-- Logistics, Engineer + Manufacturer, etc.). This migration:
--
--   1. Adds `profiles.roles text[]` — backfills from the scalar.
--   2. Adds `profiles.active_role text` — current dashboard.
--   3. Adds a SECURITY INVOKER `has_role(text)` helper for future RLS use.
--   4. Adds an INSERT/UPDATE trigger so `roles` always contains `role` (keeps
--      the legacy scalar column in sync until the Android cutover lands).
--
-- KEEPS the legacy `role` column intact and KEEPS every existing RLS policy
-- unchanged. The Android client reads new columns; writes both for backwards
-- compat. A follow-up migration drops the scalar after the cutover proves out.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS roles text[] NOT NULL DEFAULT '{}'::text[];

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS active_role text;

-- Backfill from the legacy scalar.
UPDATE public.profiles
SET roles = ARRAY[role::text]
WHERE role IS NOT NULL
  AND (roles IS NULL OR cardinality(roles) = 0);

UPDATE public.profiles
SET active_role = role::text
WHERE role IS NOT NULL
  AND active_role IS NULL;

-- Trigger keeps the two representations in sync so the legacy code path
-- doesn't drift while we cut the client over.
CREATE OR REPLACE FUNCTION public._sync_profile_roles()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role IS NOT NULL THEN
    -- Ensure scalar role is in the array.
    IF NEW.roles IS NULL OR NOT (NEW.role::text = ANY(NEW.roles)) THEN
      NEW.roles := array_append(coalesce(NEW.roles, ARRAY[]::text[]), NEW.role::text);
    END IF;
    -- If active_role unset, default to the scalar role.
    IF NEW.active_role IS NULL THEN
      NEW.active_role := NEW.role::text;
    END IF;
  ELSIF NEW.active_role IS NOT NULL AND (NEW.roles IS NULL OR cardinality(NEW.roles) = 0) THEN
    NEW.roles := ARRAY[NEW.active_role];
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_roles ON public.profiles;
CREATE TRIGGER trg_sync_profile_roles
  BEFORE INSERT OR UPDATE OF role, roles, active_role ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public._sync_profile_roles();

-- Helper for future RLS rewrites.
CREATE OR REPLACE FUNCTION public.has_role(p_role text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND p_role = ANY(roles)
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_role(text) TO authenticated;

-- Client-callable RPCs for the Global Hub add-role flow.

CREATE OR REPLACE FUNCTION public.add_role(p_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_role NOT IN ('hospital_admin','engineer','supplier','manufacturer','logistics') THEN
    RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023';
  END IF;
  UPDATE public.profiles
  SET roles = (
        CASE WHEN p_role = ANY(roles) THEN roles
             ELSE array_append(roles, p_role) END),
      active_role = p_role,
      role_confirmed = true,
      updated_at = now()
  WHERE id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.add_role(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_active_role(p_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_role NOT IN ('hospital_admin','engineer','supplier','manufacturer','logistics') THEN
    RAISE EXCEPTION 'invalid_role' USING ERRCODE='22023';
  END IF;
  UPDATE public.profiles
  SET active_role = p_role,
      role = p_role::user_role,  -- keep scalar in sync until cutover finishes
      updated_at = now()
  WHERE id = auth.uid()
    AND p_role = ANY(roles);
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_active_role(text) TO authenticated;
