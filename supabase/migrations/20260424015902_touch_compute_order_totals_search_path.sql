-- Pin search_path on compute_order_totals so it can't be hijacked by a
-- caller-controlled session search_path. Same fix as
-- 20260418232257_touch_repair_job_bids_search_path applied to the new
-- trigger function.
alter function public.compute_order_totals() set search_path = public;
