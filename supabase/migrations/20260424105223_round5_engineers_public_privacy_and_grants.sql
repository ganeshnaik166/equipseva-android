-- Round 5: harden public.engineers_public view.
--
-- Privacy: drop latitude, longitude, and background_check_status from the
-- projection. Hospitals browsing the directory get coarse location (city,
-- state) and service_radius_km, not exact coordinates or BGC status. If
-- distance-based search is later needed, add a server-side RPC that reads
-- engineers.latitude/longitude directly and returns only a sorted list of
-- engineer ids + distance bucket — never raw coordinates.
--
-- Grants: previously ALL privileges (INSERT/UPDATE/DELETE/TRUNCATE/...) were
-- granted to both `anon` and `authenticated`. Because the view runs with
-- security_invoker=false (owner = postgres) and is a simple auto-updatable
-- view over one table, writes through it would bypass RLS on `engineers`.
-- Lock to SELECT-only, authenticated only.
--
-- security_invoker is intentionally left false (owner-executed) so that
-- SELECTs bypass the engineers-table PII RLS — that is the whole point of
-- the public projection. The Supabase advisor ERROR for this view is expected
-- and acknowledged.
--
-- security_barrier=true is added to prevent malicious operator/function
-- leak attempts in WHERE clauses from pushing underlying rows through the
-- view boundary.

DROP VIEW IF EXISTS public.engineers_public CASCADE;

CREATE VIEW public.engineers_public
WITH (security_invoker = false, security_barrier = true)
AS
SELECT
    id,
    user_id,
    qualifications,
    specializations,
    brands_serviced,
    experience_years,
    oem_training_badges,
    service_radius_km,
    is_available,
    available_from,
    available_to,
    rating_avg,
    total_jobs,
    completion_rate,
    verification_status,
    city,
    state,
    created_at,
    updated_at
FROM public.engineers;

COMMENT ON VIEW public.engineers_public IS
  'Public projection of engineers for hospital-facing directory. Excludes PII '
  '(latitude, longitude, background_check_status, aadhaar, phone, email, bank). '
  'Runs SECURITY DEFINER-style (security_invoker=false) so non-self reads succeed '
  'despite engineers-table RLS; SELECT-only for authenticated role.';

REVOKE ALL ON public.engineers_public FROM PUBLIC;
REVOKE ALL ON public.engineers_public FROM anon;
REVOKE ALL ON public.engineers_public FROM authenticated;
GRANT SELECT ON public.engineers_public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.engineers_public TO postgres, service_role;
