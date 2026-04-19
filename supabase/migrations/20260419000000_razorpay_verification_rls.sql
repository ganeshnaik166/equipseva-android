-- Harden spare_part_orders so only the service-role path (via the
-- verify-razorpay-payment edge function) can flip an order to "completed"/"confirmed".
-- Clients keep the ability to set failed / cancelled states so a user-abort still updates
-- their UI. The edge function runs under service-role and bypasses these checks.

-- Drop any prior permissive update policy so we can re-express it with state constraints.
-- (Safe to re-run; the DROP IF EXISTS only removes the named policy.)
drop policy if exists "spare_part_orders_update_own" on public.spare_part_orders;

-- Owner may update their own orders, but only into non-terminal states.
-- payment_status may move to pending/failed/cancelled but NOT to "completed".
-- order_status may move to draft/cancelled but NOT to "confirmed" or anything
-- downstream of that (shipped/delivered/etc.) — those come from server-side writers.
create policy "spare_part_orders_update_own_nonconfirm"
  on public.spare_part_orders
  for update
  to authenticated
  using (buyer_user_id = auth.uid())
  with check (
    buyer_user_id = auth.uid()
    and (payment_status is null or payment_status in ('pending','failed','cancelled'))
    and (order_status  is null or order_status  in ('draft','cancelled'))
  );

-- Defence-in-depth: if anyone tries to flip to a gated state outside the policy
-- (e.g. via a future stored procedure), a trigger refuses the write unless it
-- runs as the service-role. postgres / service_role bypass RLS anyway, which is
-- exactly the path we want the edge function to take.
create or replace function public.guard_order_state_transitions()
returns trigger
language plpgsql
security invoker
as $$
declare
  caller_role text := current_setting('request.jwt.claims', true)::jsonb ->> 'role';
begin
  -- service_role and postgres may do anything.
  if caller_role = 'service_role' or session_user = 'postgres' then
    return new;
  end if;

  if new.payment_status = 'completed' and coalesce(old.payment_status, '') <> 'completed' then
    raise exception 'payment_status=completed requires server-side verification'
      using errcode = '42501';
  end if;

  if new.order_status = 'confirmed' and coalesce(old.order_status, '') <> 'confirmed' then
    raise exception 'order_status=confirmed requires server-side verification'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_order_state_transitions on public.spare_part_orders;
create trigger trg_guard_order_state_transitions
  before update on public.spare_part_orders
  for each row execute function public.guard_order_state_transitions();

comment on function public.guard_order_state_transitions() is
  'Refuses client-side transitions to payment_status=completed or order_status=confirmed. '
  'Service-role (edge function verify-razorpay-payment) bypasses the check.';
