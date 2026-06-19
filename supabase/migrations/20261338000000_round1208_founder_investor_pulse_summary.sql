BEGIN;
DROP FUNCTION IF EXISTS public.founder_investor_pulse_summary();
CREATE OR REPLACE FUNCTION public.founder_investor_pulse_summary()
RETURNS TABLE (
  active_mrr_inr             numeric,
  active_amc_contracts       bigint,
  gmv_30d_inr                numeric,
  jobs_completed_30d         bigint,
  spare_parts_paid_30d_inr   numeric,
  payouts_paid_30d_inr       numeric,
  new_engineers_30d          bigint,
  new_hospitals_30d          bigint,
  active_engineers_30d       bigint,
  active_hospitals_30d       bigint,
  referral_bounty_paid_30d_inr numeric,
  amc_renewals_30d           bigint,
  total_users_all_time       bigint,
  ttv_lifetime_gmv_inr       numeric,
  lifetime_payouts_inr       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_jobs_gmv_30d numeric;
  v_spare_gmv_30d numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_jobs_gmv_30d
    FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT coalesce(sum(total_amount), 0)::numeric INTO v_spare_gmv_30d
    FROM public.spare_part_orders WHERE coalesce(payment_status, '') = 'paid' AND created_at >= now() - interval '30 days';

  RETURN QUERY
  SELECT
    coalesce((SELECT sum(monthly_fee_rupees)::numeric FROM public.amc_contracts WHERE status = 'active'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts WHERE status = 'active'), 0),
    (v_jobs_gmv_30d + v_spare_gmv_30d)::numeric,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days'), 0),
    v_spare_gmv_30d,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status IN ('processed','paid') AND queued_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE role = 'hospital' AND created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT engineer_id)::bigint FROM public.repair_jobs
              WHERE engineer_id IS NOT NULL AND completed_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(DISTINCT hospital_user_id)::bigint FROM public.repair_jobs
              WHERE created_at >= now() - interval '30 days'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'paid' AND paid_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts
              WHERE created_at >= now() - interval '30 days'
                AND (start_date IS NOT NULL AND end_date IS NOT NULL AND end_date > start_date)), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles), 0),
    coalesce((SELECT sum(contracted_amount_rupees)::numeric FROM public.repair_jobs WHERE status = 'completed'), 0)
      + coalesce((SELECT sum(total_amount)::numeric FROM public.spare_part_orders WHERE coalesce(payment_status, '') = 'paid'), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts WHERE status IN ('processed','paid')), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_pulse_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_pulse_summary() TO authenticated;
COMMIT;
