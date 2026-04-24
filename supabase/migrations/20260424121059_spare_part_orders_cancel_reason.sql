-- Add cancel_reason to spare_part_orders so buyers can (optionally) explain a cancellation.
alter table public.spare_part_orders
  add column if not exists cancel_reason text;

alter table public.spare_part_orders
  add constraint spare_part_orders_cancel_reason_len
  check (cancel_reason is null or char_length(cancel_reason) <= 500);
