-- Close three audit findings on the buyer / supplier surface in one shot.
--
-- 1. Drop a duplicate, lax INSERT policy on spare_part_orders.
--    "Auth users can create orders" allowed any authenticated user; the
--    sibling "Users can create orders" already enforces buyer_user_id =
--    auth.uid() so the lax one is pure attack surface.
drop policy if exists "Auth users can create orders" on public.spare_part_orders;

-- 2. Tighten SELECT on spare_part_orders.
--    Prior policy: (auth.uid() = buyer_user_id) OR (auth.uid() IS NOT NULL)
--    -> any authenticated user could read every order, including shipping
--    address, total, payment_id, line items. PII leak.
--    New: buyer OR supplier-org member.
drop policy if exists "Order parties can view" on public.spare_part_orders;
create policy "Order parties can view"
  on public.spare_part_orders
  for select
  to authenticated
  using (
    auth.uid() = buyer_user_id
    or supplier_org_id in (
      select organization_id from public.profiles
      where id = auth.uid() and organization_id is not null
    )
  );

-- 3. Tighten INSERT on spare_parts so a buyer can't insert a fake low-priced
--    part under any supplier_org_id and then "buy" it for paise.
drop policy if exists "Suppliers can manage parts" on public.spare_parts;
create policy "Suppliers can manage parts"
  on public.spare_parts
  for insert
  to authenticated
  with check (
    supplier_org_id in (
      select organization_id from public.profiles
      where id = auth.uid() and organization_id is not null
    )
  );

-- 4. Recompute order totals server-side from canonical spare_parts.price.
--    Closes the 1-paisa exploit: client may submit any subtotal/total, but
--    the trigger overrides them before the row hits the table. Razorpay
--    create-order edge fn already reads total_amount from the DB, so once
--    the DB row is authoritative the whole pricing chain is too.
create or replace function public.compute_order_totals()
returns trigger
language plpgsql
security invoker
as $$
declare
  v_caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
  v_subtotal numeric := 0;
  v_gst numeric := 0;
  v_shipping numeric := 0;
  v_item jsonb;
  v_part_id uuid;
  v_qty integer;
  v_price numeric;
  v_gst_rate numeric;
  v_active boolean;
begin
  -- Service-role / postgres bypass: future admin backfills can supply totals
  -- explicitly. The Razorpay verify edge fn only does UPDATE so it is not
  -- affected here either way.
  if v_caller_role = 'service_role' or session_user = 'postgres' then
    return new;
  end if;

  if jsonb_typeof(new.items) <> 'array' or jsonb_array_length(new.items) = 0 then
    raise exception 'order.items must be a non-empty jsonb array' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(new.items) loop
    v_part_id := nullif(v_item ->> 'part_id', '')::uuid;
    v_qty := coalesce((v_item ->> 'quantity')::integer, 0);
    if v_part_id is null or v_qty <= 0 then
      raise exception 'order.items entry missing part_id or quantity' using errcode = '22023';
    end if;
    select price, coalesce(gst_rate, 0), coalesce(is_active, true)
      into v_price, v_gst_rate, v_active
      from public.spare_parts where id = v_part_id;
    if v_price is null then
      raise exception 'spare part % not found', v_part_id using errcode = 'P0002';
    end if;
    if not v_active then
      raise exception 'spare part % is not active', v_part_id using errcode = '22023';
    end if;
    v_subtotal := v_subtotal + (v_price * v_qty);
    v_gst := v_gst + (v_price * v_qty * v_gst_rate / 100.0);
  end loop;

  -- Flat shipping per current product decision (CheckoutViewModel:318). If
  -- shipping rules grow (per-supplier, per-state, distance) plumb a lookup
  -- through here so the trigger remains the source of truth.
  v_shipping := 0;

  new.subtotal := v_subtotal;
  new.gst_amount := v_gst;
  new.shipping_cost := v_shipping;
  new.total_amount := v_subtotal + v_gst + v_shipping;

  return new;
end;
$$;

drop trigger if exists trg_compute_order_totals on public.spare_part_orders;
create trigger trg_compute_order_totals
  before insert on public.spare_part_orders
  for each row execute function public.compute_order_totals();

comment on function public.compute_order_totals() is
  'Recomputes spare_part_orders subtotal/gst_amount/shipping_cost/total_amount '
  'from spare_parts.price + gst_rate at INSERT. Refuses missing/inactive parts. '
  'Service-role bypasses.';
