-- Tighten public.seller_can_list — drop the `p_user_id uuid` parameter
-- so any authenticated caller can only probe their OWN org's verification
-- status, never an arbitrary other user's.
--
-- The original 20260425090000_invoices_and_seller_verification.sql:261
-- defined:
--
--   seller_can_list(p_user_id uuid) RETURNS boolean
--   GRANT EXECUTE ... TO authenticated
--
-- and was meant as a future RLS helper. No callsite exists in the
-- repo (RLS on spare_parts inlines the same EXISTS check against
-- auth.uid()), but the parameterized form is granted to authenticated
-- — so any signed-in user can enumerate organization verification
-- status by walking user ids. Information disclosure with low effort.
--
-- This migration:
--   1. Adds a no-arg `seller_can_list()` that uses auth.uid() internally.
--   2. Drops the parameterized `seller_can_list(uuid)` overload.
--   3. Grants EXECUTE on the no-arg form to authenticated only.

CREATE OR REPLACE FUNCTION public.seller_can_list()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    JOIN public.organizations o ON o.id = p.organization_id
    WHERE p.id = auth.uid()
      AND p.organization_id IS NOT NULL
      AND o.verification_status = 'verified'
  );
$$;

REVOKE EXECUTE ON FUNCTION public.seller_can_list() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seller_can_list() TO authenticated;

-- Drop the impersonation-capable form. No in-repo callers; if any
-- internal admin tooling depended on it, prefer admin_set_org_verification
-- which is already founder-gated.
DROP FUNCTION IF EXISTS public.seller_can_list(uuid);
