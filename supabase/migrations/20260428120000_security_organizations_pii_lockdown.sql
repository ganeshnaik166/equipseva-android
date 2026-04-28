-- Organizations table currently has SELECT open to everyone (qual=true), and
-- the table holds GSTIN, PAN, address, lat/lng, phone, email, GST/trade
-- licence URLs — all hospital PII. Lock at column level so REST callers
-- only see the public-safe summary fields.

REVOKE SELECT ON public.organizations FROM authenticated, anon;
GRANT SELECT (
    id, name, type, city, state, logo_url, description, beds_count,
    accreditation, medequip_score, subscription_tier, verification_status,
    created_by, created_at, updated_at
) ON public.organizations TO authenticated;
GRANT SELECT (id, name, type, city, state, logo_url) ON public.organizations TO anon;

CREATE OR REPLACE FUNCTION public.organization_full(p_org_id uuid)
RETURNS SETOF public.organizations
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT o.*
    FROM public.organizations o
    WHERE o.id = p_org_id
      AND (
        public.is_founder()
        OR EXISTS (
          SELECT 1 FROM public.profiles p
          WHERE p.id = auth.uid()
            AND p.organization_id = o.id
            AND coalesce(p.is_active, true) = true
        )
      );
$$;

REVOKE ALL ON FUNCTION public.organization_full(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.organization_full(uuid) TO authenticated;
