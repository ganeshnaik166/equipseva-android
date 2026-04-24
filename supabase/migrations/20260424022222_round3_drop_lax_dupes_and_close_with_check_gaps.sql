-- Round 3 RLS cleanup. Three classes of leftover gaps surfaced by the
-- audit; one migration closes all of them. Already applied to the live
-- database via the Supabase MCP.
--
-- A. Duplicate lax SELECT/INSERT policies that nullify their strict siblings.
--    Postgres treats RLS policies as OR'd within a command, so a `qual=true`
--    policy makes any other SELECT policy on the same table moot.
-- B. UPDATE policies missing WITH_CHECK clauses, which lets a row be edited
--    to a state that violates the USING predicate (e.g. transferring
--    ownership to another user/org).
-- C. profiles SELECT was readable by anon (`roles=public, qual=true`).
--    Restrict to authenticated so the user directory is not scrapable from
--    the open internet.

-- A. Lax-duplicate drops
drop policy if exists "Calibration records viewable by org" on public.calibration_records;
drop policy if exists "Calibration services viewable"      on public.calibration_services;
drop policy if exists "Audits viewable"                    on public.compliance_audits;
drop policy if exists "Course modules are public"          on public.course_modules;
drop policy if exists "Auth users can create enrollments"  on public.enrollments;

-- B. UPDATE WITH_CHECK gaps. Mirror the existing USING predicate so the
--    NEW row also has to satisfy the same scope — prevents ownership flips.

-- marketplace_offers: buyer or listing seller can edit; the new row must
-- still tie back to one of those identities.
drop policy if exists "offers parties update" on public.marketplace_offers;
create policy "offers parties update"
  on public.marketplace_offers
  for update
  to authenticated
  using (
    auth.uid() = buyer_user_id
    or exists (
      select 1 from public.marketplace_listings l
      where l.id = marketplace_offers.listing_id
        and l.seller_user_id = auth.uid()
    )
  )
  with check (
    auth.uid() = buyer_user_id
    or exists (
      select 1 from public.marketplace_listings l
      where l.id = marketplace_offers.listing_id
        and l.seller_user_id = auth.uid()
    )
  );

-- rfq_bids: bidder must remain a member of the manufacturer org named on
-- the row (or admin). Without WITH_CHECK they could swap manufacturer_id.
drop policy if exists "rfq_bids bidder update" on public.rfq_bids;
create policy "rfq_bids bidder update"
  on public.rfq_bids
  for update
  to authenticated
  using (
    exists (
      select 1 from public.manufacturers m
      where m.id = rfq_bids.manufacturer_id
        and is_org_member(auth.uid(), m.organization_id)
    )
    or is_admin(auth.uid())
  )
  with check (
    exists (
      select 1 from public.manufacturers m
      where m.id = rfq_bids.manufacturer_id
        and is_org_member(auth.uid(), m.organization_id)
    )
    or is_admin(auth.uid())
  );

-- manufacturers: org member can edit; new row must still be on the same org.
drop policy if exists "manufacturers org update" on public.manufacturers;
create policy "manufacturers org update"
  on public.manufacturers
  for update
  to authenticated
  using (
    is_org_member(auth.uid(), organization_id)
    or is_admin(auth.uid())
  )
  with check (
    is_org_member(auth.uid(), organization_id)
    or is_admin(auth.uid())
  );

-- enrollments: user can edit own; new row's user_id must still be them.
drop policy if exists "enrollments own update" on public.enrollments;
create policy "enrollments own update"
  on public.enrollments
  for update
  to authenticated
  using (auth.uid() = user_id or is_admin(auth.uid()))
  with check (auth.uid() = user_id or is_admin(auth.uid()));

-- C. profiles SELECT — narrow from anon to authenticated. Inner-app reads
--    of other users (chat partners, RFQ requesters, etc.) still work.
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles are viewable by everyone"
  on public.profiles
  for select
  to authenticated
  using (true);
