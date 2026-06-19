BEGIN;
DROP FUNCTION IF EXISTS public.founder_cumulative_rollup_summary();
CREATE OR REPLACE FUNCTION public.founder_cumulative_rollup_summary()
RETURNS TABLE (
  days_since_launch              bigint,
  lifetime_jobs_completed        bigint,
  lifetime_jobs_gmv_inr          numeric,
  lifetime_amc_revenue_inr       numeric,
  lifetime_parts_revenue_inr     numeric,
  lifetime_gmv_total_inr         numeric,
  lifetime_payouts_disbursed_inr numeric,
  lifetime_referral_bounties_inr numeric,
  lifetime_engineers_onboarded   bigint,
  lifetime_hospitals_onboarded   bigint,
  lifetime_amc_contracts_created bigint,
  lifetime_spare_part_orders     bigint,
  avg_gmv_per_day_inr            numeric,
  avg_jobs_per_day               numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_first_signup timestamptz;
  v_days numeric;
  v_jobs_gmv numeric;
  v_amc_rev numeric;
  v_parts_rev numeric;
  v_total_gmv numeric;
  v_jobs_done bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT min(created_at) INTO v_first_signup FROM public.profiles;
  IF v_first_signup IS NULL THEN
    v_days := 1;
  ELSE
    v_days := greatest(1, ceil(extract(epoch FROM (now() - v_first_signup)) / 86400.0));
  END IF;

  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_jobs_gmv
    FROM public.repair_jobs WHERE status = 'completed';

  SELECT coalesce(sum(amount_rupees), 0)::numeric INTO v_amc_rev
    FROM public.amc_payment_orders WHERE status = 'paid';

  SELECT coalesce(sum(total_amount), 0)::numeric INTO v_parts_rev
    FROM public.spare_part_orders WHERE coalesce(payment_status, '') = 'paid';

  v_total_gmv := v_jobs_gmv + v_amc_rev + v_parts_rev;

  SELECT count(*)::bigint INTO v_jobs_done
    FROM public.repair_jobs WHERE status = 'completed';

  RETURN QUERY
  SELECT
    v_days::bigint,
    v_jobs_done,
    v_jobs_gmv,
    v_amc_rev,
    v_parts_rev,
    v_total_gmv,
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.engineer_payouts
              WHERE status IN ('processed','paid')), 0),
    coalesce((SELECT sum(amount_rupees)::numeric FROM public.referral_bounty_payouts
              WHERE status = 'paid'), 0),
    coalesce((SELECT count(*)::bigint FROM public.engineers), 0),
    coalesce((SELECT count(*)::bigint FROM public.profiles WHERE role = 'hospital'), 0),
    coalesce((SELECT count(*)::bigint FROM public.amc_contracts), 0),
    coalesce((SELECT count(*)::bigint FROM public.spare_part_orders), 0),
    round(v_total_gmv / v_days, 2)::numeric,
    round(v_jobs_done::numeric / v_days, 2)::numeric;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_cumulative_rollup_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cumulative_rollup_summary() TO authenticated;
COMMIT;
