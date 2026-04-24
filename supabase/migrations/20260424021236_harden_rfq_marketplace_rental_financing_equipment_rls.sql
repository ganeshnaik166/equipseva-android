-- Cross-table RLS cleanup. Same patterns as the spare_part_orders pass:
-- duplicate lax INSERT policies, anon-readable SELECT, and a wide-open
-- equipment INSERT that ignored organization scope. Already applied to
-- the live database via the Supabase MCP.

-- 1. rfqs
--    Drop the lax duplicate INSERT.
drop policy if exists "Auth users can create rfqs" on public.rfqs;

--    Tighten SELECT. Prior policy: roles={public} qual=true -> any anon
--    visitor could read every RFQ (title, description, specifications jsonb,
--    budget_range_min/max, delivery_location). Replace with a scoped policy
--    that allows the requester's org members and any manufacturer-org member
--    (manufacturers need to discover RFQs to bid on them). Other authenticated
--    users (hospital competitors, engineers, etc.) no longer see RFQs they
--    aren't party to.
drop policy if exists "rfqs read" on public.rfqs;
create policy "rfqs read"
  on public.rfqs
  for select
  to authenticated
  using (
    is_org_member(auth.uid(), requester_org_id)
    or exists (
      select 1 from public.manufacturers m
      where is_org_member(auth.uid(), m.organization_id)
    )
    or is_admin(auth.uid())
  );

-- 2. marketplace_listings
--    Drop the lax duplicate INSERT; the strict "Users can create listings"
--    sibling already enforces seller_user_id = auth.uid(). SELECT stays
--    public (intentional marketplace discovery).
drop policy if exists "Auth users can create marketplace listings" on public.marketplace_listings;

-- 3. rental_listings
--    Both existing INSERT policies are lax (auth.uid() IS NOT NULL); neither
--    ties the row to the caller's owner org. Drop both and add a strict
--    org-membership INSERT. SELECT stays public (intentional discovery).
drop policy if exists "Auth users can create rental listings" on public.rental_listings;
drop policy if exists "Users can create rental listings" on public.rental_listings;
create policy "rental listings owner insert"
  on public.rental_listings
  for insert
  to authenticated
  with check (is_org_member(auth.uid(), owner_org_id));

-- 4. financing_applications
--    Drop lax duplicate; sibling "fin_app applicant insert" already enforces
--    applicant_user_id = auth.uid().
drop policy if exists "Auth users can create financing apps" on public.financing_applications;

-- 5. equipment
--    Tighten INSERT to require the caller's profiles.organization_id matches
--    the row's organization_id. Matches the existing SELECT/UPDATE pattern;
--    closes the gap where any authenticated user could insert equipment for
--    any org.
drop policy if exists "Org members can manage equipment" on public.equipment;
create policy "Org members can manage equipment"
  on public.equipment
  for insert
  to authenticated
  with check (
    organization_id in (
      select organization_id from public.profiles
      where id = auth.uid() and organization_id is not null
    )
  );
