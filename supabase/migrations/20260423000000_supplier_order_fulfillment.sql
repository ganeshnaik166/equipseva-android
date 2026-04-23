-- Let suppliers progress their own incoming orders through confirmed -> shipped.
--
-- Prior state (20260419000000_razorpay_verification_rls.sql): only the buyer could update
-- their own orders, and only to draft/cancelled; a trigger forbade any authenticated
-- transition to order_status='confirmed'. Payment verification ran under service-role to
-- flip placed -> confirmed after Razorpay settlement.
--
-- New requirement: suppliers need a lightweight manual path to confirm orders (for COD /
-- manual payment flows) and to mark them shipped. We gate it on supplier_org_id matching
-- the caller's profile.organization_id and keep the buyer policy intact.

-- Supplier-scoped update policy. We intentionally keep the existing buyer policy; a row
-- only needs to satisfy one permissive policy. Suppliers may advance the row to
-- confirmed/shipped as long as payment is not in a forbidden state (we leave payment_status
-- untouched in the code path, but the policy still has to allow the row's current value
-- to pass the `with check` clause because policies apply to the NEW row).
create policy "spare_part_orders_supplier_update_fulfillment"
  on public.spare_part_orders
  for update
  to authenticated
  using (
    supplier_org_id in (
      select organization_id from public.profiles
      where id = auth.uid() and organization_id is not null
    )
  )
  with check (
    supplier_org_id in (
      select organization_id from public.profiles
      where id = auth.uid() and organization_id is not null
    )
    and order_status in ('confirmed','shipped','delivered')
  );

-- Relax the defence-in-depth trigger so a supplier who owns the row can flip to confirmed.
-- The gate remains for anyone else: anon + hospital-buyer roles still cannot minted a
-- client-side confirmation. Service-role (edge function) continues to bypass.
create or replace function public.guard_order_state_transitions()
returns trigger
language plpgsql
security invoker
as $$
declare
  caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
  caller_org  uuid;
begin
  if caller_role = 'service_role' or session_user = 'postgres' then
    return new;
  end if;

  if new.payment_status = 'completed' and coalesce(old.payment_status, '') <> 'completed' then
    raise exception 'payment_status=completed requires server-side verification'
      using errcode = '42501';
  end if;

  if new.order_status = 'confirmed' and coalesce(old.order_status, '') <> 'confirmed' then
    select organization_id into caller_org
      from public.profiles
      where id = auth.uid();
    if caller_org is null or caller_org <> new.supplier_org_id then
      raise exception 'order_status=confirmed requires supplier ownership or server-side verification'
        using errcode = '42501';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.guard_order_state_transitions() is
  'Refuses client-side transitions to payment_status=completed. '
  'order_status=confirmed is allowed only for the owning supplier org or service-role.';
