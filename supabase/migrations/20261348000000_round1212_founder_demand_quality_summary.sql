BEGIN;
DROP FUNCTION IF EXISTS public.founder_demand_quality_summary();
CREATE OR REPLACE FUNCTION public.founder_demand_quality_summary()
RETURNS TABLE (
  total_hospitals              bigint,
  amc_coverage_pct             numeric,
  active_30d_pct               numeric,
  active_90d_pct               numeric,
  loyalty_10_plus_pct          numeric,
  never_posted_pct             numeric,
  churn_signal_pct             numeric,
  avg_spend_per_active_30d_inr numeric,
  cancellation_rate_pct_30d    numeric,
  disputes_filed_by_hosp_30d   bigint,
  repeat_buyer_pct             numeric,
  composite_demand_score       numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
  v_with_amc bigint;
  v_active_30 bigint;
  v_active_90 bigint;
  v_loyal bigint;
  v_never_posted bigint;
  v_was_active_60_90 bigint;
  v_currently_inactive_after_60 bigint;
  v_spend_30d numeric;
  v_jobs_30d bigint;
  v_cancelled_30d bigint;
  v_total_jobs_30d bigint;
  v_repeat bigint;
  v_amc_pct numeric;
  v_active_30_pct numeric;
  v_active_90_pct numeric;
  v_loyal_pct numeric;
  v_never_pct numeric;
  v_churn_pct numeric;
  v_cancel_pct numeric;
  v_repeat_pct numeric;
  v_score numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_total FROM public.profiles WHERE role = 'hospital';
  IF v_total IS NULL THEN v_total := 0; END IF;
  SELECT count(DISTINCT hospital_user_id)::bigint INTO v_with_amc FROM public.amc_contracts WHERE status = 'active';
  SELECT count(DISTINCT hospital_user_id)::bigint INTO v_active_30 FROM public.repair_jobs WHERE created_at >= now() - interval '30 days';
  SELECT count(DISTINCT hospital_user_id)::bigint INTO v_active_90 FROM public.repair_jobs WHERE created_at >= now() - interval '90 days';
  SELECT count(*)::bigint INTO v_loyal FROM (
    SELECT hospital_user_id FROM public.repair_jobs GROUP BY hospital_user_id HAVING count(*) >= 10
  ) t;
  SELECT count(*)::bigint INTO v_never_posted FROM public.profiles p
    WHERE p.role = 'hospital' AND NOT EXISTS (SELECT 1 FROM public.repair_jobs j WHERE j.hospital_user_id = p.id);

  -- Churn signal: posted 60-90d ago but NOT in last 30d
  SELECT count(DISTINCT j1.hospital_user_id)::bigint INTO v_currently_inactive_after_60 FROM public.repair_jobs j1
    WHERE j1.created_at >= now() - interval '90 days'
      AND j1.created_at <  now() - interval '60 days'
      AND NOT EXISTS (
        SELECT 1 FROM public.repair_jobs j2
         WHERE j2.hospital_user_id = j1.hospital_user_id
           AND j2.created_at >= now() - interval '30 days'
      );

  SELECT coalesce(sum(contracted_amount_rupees), 0)::numeric INTO v_spend_30d
    FROM public.repair_jobs WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_jobs_30d FROM public.repair_jobs WHERE created_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_cancelled_30d FROM public.repair_jobs WHERE status = 'cancelled' AND created_at >= now() - interval '30 days';

  -- Repeat buyer = posted at least 2 jobs lifetime
  SELECT count(*)::bigint INTO v_repeat FROM (
    SELECT hospital_user_id FROM public.repair_jobs GROUP BY hospital_user_id HAVING count(*) >= 2
  ) t;

  v_amc_pct       := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_with_amc / v_total, 1) END;
  v_active_30_pct := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_active_30 / v_total, 1) END;
  v_active_90_pct := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_active_90 / v_total, 1) END;
  v_loyal_pct     := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_loyal / v_total, 1) END;
  v_never_pct     := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_never_posted / v_total, 1) END;
  v_churn_pct     := CASE WHEN v_active_90 = 0 THEN 0::numeric ELSE round(100.0 * v_currently_inactive_after_60 / v_active_90, 1) END;
  v_cancel_pct    := CASE WHEN v_jobs_30d = 0 THEN 0::numeric ELSE round(100.0 * v_cancelled_30d / v_jobs_30d, 1) END;
  v_repeat_pct    := CASE WHEN v_total = 0 THEN 0::numeric ELSE round(100.0 * v_repeat / v_total, 1) END;
  -- Score: average of "good" signals minus churn penalty
  v_score := round((
    v_amc_pct +
    v_active_30_pct +
    v_loyal_pct +
    v_repeat_pct +
    (100 - v_never_pct) +
    (100 - v_churn_pct) +
    (100 - v_cancel_pct)
  ) / 7.0, 1);

  RETURN QUERY
  SELECT
    v_total,
    v_amc_pct,
    v_active_30_pct,
    v_active_90_pct,
    v_loyal_pct,
    v_never_pct,
    v_churn_pct,
    CASE WHEN v_active_30 = 0 THEN 0::numeric ELSE round(v_spend_30d / v_active_30, 2) END,
    v_cancel_pct,
    coalesce((SELECT count(*)::bigint FROM public.dispute_evidence_packs
              WHERE submitted_at IS NOT NULL AND submitted_at >= now() - interval '30 days'
                AND filer_role = 'hospital'), 0),
    v_repeat_pct,
    v_score;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_demand_quality_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_demand_quality_summary() TO authenticated;
COMMIT;
