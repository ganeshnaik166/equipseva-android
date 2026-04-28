-- organizations.{verification_status, medequip_score, subscription_tier,
-- verified_at, verified_by, created_by, id, created_at, updated_at} are
-- trust-signal / system columns, but the table inherited the default
-- "all columns" INSERT/UPDATE grant for both anon and authenticated. A
-- hospital signing up could self-set verification_status='verified',
-- medequip_score=999, subscription_tier='enterprise' on their own row
-- and look fully legit on the engineer feed before any admin review.
--
-- Same for UPDATE — even after creation, the org's created_by could
-- post-hoc flip their own verification badge or score on demand.
--
-- Lock down: revoke every column-level INSERT/UPDATE on organizations
-- from anon + authenticated, then re-grant only the user-controllable
-- fields. Trust columns stay admin / service_role / SECURITY DEFINER
-- writeable only (admin_set_org_verification RPC already exists for
-- the verify side).
--
-- anon never legitimately writes orgs — revoke INSERT/UPDATE entirely.

-- 1. Strip every existing column INSERT/UPDATE from anon + authenticated.
REVOKE INSERT, UPDATE ON public.organizations FROM anon, authenticated;

-- 2. Re-grant user-controllable columns to authenticated only.
--    Hospital onboarding writes these on first save; admin tooling on
--    service_role still has full table access via implicit role bypass.
GRANT INSERT (
    name, type, city, state, address, pincode, phone, email, website,
    logo_url, description, accreditation, beds_count,
    latitude, longitude,
    gstin, pan, gst_certificate_url, trade_licence_url, licence_expires_at
) ON public.organizations TO authenticated;

-- 3. UPDATE allow-list. `type` intentionally omitted — flipping a
--    hospital row to 'manufacturer' post-hoc would route engineer
--    surfaces incorrectly. Same for gstin/pan (one-shot identity
--    fields the verification flow signs off on); allow them to be
--    set once but admins can bump them via the admin RPC.
GRANT UPDATE (
    name, city, state, address, pincode, phone, email, website,
    logo_url, description, accreditation, beds_count,
    latitude, longitude,
    gst_certificate_url, trade_licence_url, licence_expires_at
) ON public.organizations TO authenticated;
