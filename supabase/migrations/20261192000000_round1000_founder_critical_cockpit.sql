BEGIN;
DROP FUNCTION IF EXISTS public.founder_critical_cockpit();
CREATE OR REPLACE FUNCTION public.founder_critical_cockpit()
RETURNS TABLE (
  payouts_stuck_over_7d        bigint,
  payouts_stuck_inr            numeric,
  code_red_stuck_over_4h       bigint,
  spare_parts_stuck_over_7d    bigint,
  spare_parts_stuck_inr        numeric,
  jobs_unassigned_over_1d      bigint,
  bids_stuck_over_1d           bigint,
  escrow_held_over_14d         bigint,
  escrow_held_inr              numeric,
  engineers_no_jobs_90d        bigint,
  hospitals_no_jobs_90d        bigint,
  amc_renewing_30d             bigint,
  amc_renewing_mrr_inr         numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.engineer_payouts
              WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(amount_inr)::numeric FROM public.engineer_payouts
              WHERE status IN ('queued','processing') AND queued_at < now() - interval '7 days'), 0),

    coalesce((SELECT count(*)::bigint FROM public.code_red_requests
              WHERE status NOT IN ('resolved','timed_out') AND created_at < now() - interval '4 hours'), 0),

    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders
              WHERE coalesce(payment_status,'') = 'paid'
                AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded')
                AND created_at < now() - interval '7 days'), 0),
    coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders
              WHERE coalesce(payment_status,'') = 'paid'
                AND coalesce(order_status,'') NOT IN ('shipped','delivered','cancelled','refunded')
                AND created_at < now() - interval '7 days'), 0),

    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
              WHERE engineer_id IS NULL AND status IN ('open','posted')
                AND created_at < now() - interval '1 day'), 0),

    coalesce((SELECT count(*)::bigint FROM public.repair_job_bids
              WHERE status IN ('submitted','pending') AND created_at < now() - interval '1 day'), 0),

    coalesce((SELECT count(*)::bigint FROM public.repair_job_escrow
              WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),
    coalesce((SELECT sum(amount)::numeric FROM public.repair_job_escrow
              WHERE status = 'held' AND created_at < now() - interval '14 days'), 0),

    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'engineer'
                AND NOT EXISTS (
                  SELECT 1 FROM public.repair_jobs j
                  WHERE j.engineer_id = p.id
                    AND j.status = 'completed'
                    AND j.completed_at >= now() - interval '90 days'
                )), 0),

    coalesce((SELECT count(*)::bigint FROM public.profiles p
              WHERE p.role = 'hospital'
                AND NOT EXISTS (
                  SELECT 1 FROM public.repair_jobs j
                  WHERE j.hospital_user_id = p.id
                    AND j.created_at >= now() - interval '90 days'
                )), 0),

    coalesce((SELECT count(*)::bigint FROM public.amc_contracts
              WHERE end_date IS NOT NULL
                AND end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date
                AND end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30
                AND status IN ('active','paused')), 0),
    coalesce((SELECT sum(amount_inr)::numeric FROM public.amc_contracts
              WHERE end_date IS NOT NULL
                AND end_date >= (now() AT TIME ZONE 'Asia/Kolkata')::date
                AND end_date <  (now() AT TIME ZONE 'Asia/Kolkata')::date + 30
                AND status IN ('active','paused')), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_critical_cockpit() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_critical_cockpit() TO authenticated;
COMMIT;
