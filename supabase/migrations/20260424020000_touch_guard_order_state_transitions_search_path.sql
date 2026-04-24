-- Pin search_path on guard_order_state_transitions so a caller-controlled
-- session search_path can't redirect the profiles lookup it uses to verify
-- supplier ownership. Same fix pattern as
-- 20260418232257_touch_repair_job_bids_search_path and
-- 20260424015902_touch_compute_order_totals_search_path. Closes the only
-- remaining function_search_path_mutable advisor lint.
alter function public.guard_order_state_transitions() set search_path = public;
