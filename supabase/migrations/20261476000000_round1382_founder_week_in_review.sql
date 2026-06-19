BEGIN;
-- r1382 — /founder-week-in-review — auto-generated 7-day summary across all key domains.

DROP FUNCTION IF EXISTS public.founder_week_in_review_summary();
CREATE OR REPLACE FUNCTION public.founder_week_in_review_summary()
RETURNS TABLE (
  week_start_date              date,
  week_end_date                date,
  amcs_signed_count            bigint,
  amcs_churned_count           bigint,
  amc_net_new                  int,
  total_mrr_added_rupees       numeric,
  jobs_completed_count         bigint,
  jobs_initiated_count         bigint,
  payments_captured_count      bigint,
  payments_captured_rupees     numeric,
  payouts_processed_count      bigint,
  payouts_processed_rupees     numeric,
  code_red_count               bigint,
  open_incidents_count         bigint,
  new_postmortems_count        bigint,
  founder_actions_logged       bigint,
  engineers_added_count        bigint,
  hospitals_added_count        bigint,
  spare_parts_orders_count     bigint,
  spare_parts_orders_rupees    numeric,
  refunds_issued_rupees        numeric,
  net_cash_position_change_rupees numeric,
  generated_at                 timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_week_start date := (current_date - interval '6 days')::date;
  v_week_end   date := current_date;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT
    v_week_start, v_week_end,
    coalesce((SELECT count(*) FROM public.amc_contracts
              WHERE start_date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.amc_contracts
              WHERE status = 'churned' AND deactivated_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    (coalesce((SELECT count(*) FROM public.amc_contracts WHERE start_date BETWEEN v_week_start AND v_week_end), 0)
     - coalesce((SELECT count(*) FROM public.amc_contracts WHERE status = 'churned' AND deactivated_at::date BETWEEN v_week_start AND v_week_end), 0))::int,
    coalesce((SELECT sum(monthly_fee_rupees) FROM public.amc_contracts
              WHERE start_date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT count(*) FROM public.repair_jobs
              WHERE status = 'completed' AND completed_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.repair_jobs
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.payments
              WHERE status = 'captured' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT sum(amount_rupees) FROM public.payments
              WHERE status = 'captured' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT count(*) FROM public.engineer_payouts
              WHERE status = 'processed' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT sum(amount_rupees) FROM public.engineer_payouts
              WHERE status = 'processed' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT count(*) FROM public.code_red_requests
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.founder_incidents
              WHERE status = 'open'), 0)::bigint,
    coalesce((SELECT count(*) FROM public.founder_incident_postmortems
              WHERE written_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.founder_priority_actions
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.engineers
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.organizations
              WHERE kind = 'hospital' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT count(*) FROM public.spare_part_orders
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::bigint,
    coalesce((SELECT sum(total_amount) FROM public.spare_part_orders
              WHERE created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce((SELECT sum(amount_rupees) FROM public.payments
              WHERE status = 'refunded' AND created_at::date BETWEEN v_week_start AND v_week_end), 0)::numeric,
    coalesce(
      (SELECT cash_balance_rupees FROM public.founder_cash_position_snapshots
       WHERE snapshot_date BETWEEN v_week_start AND v_week_end
       ORDER BY snapshot_date DESC LIMIT 1)
      - (SELECT cash_balance_rupees FROM public.founder_cash_position_snapshots
         WHERE snapshot_date < v_week_start
         ORDER BY snapshot_date DESC LIMIT 1), 0)::numeric,
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_week_in_review_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_week_in_review_summary() TO authenticated;

COMMIT;
