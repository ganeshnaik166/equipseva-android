BEGIN;
-- r1389 — /founder-revenue-per-engineer — revenue contribution per engineer (RPE).

DROP FUNCTION IF EXISTS public.founder_revenue_per_engineer_summary();
CREATE OR REPLACE FUNCTION public.founder_revenue_per_engineer_summary()
RETURNS TABLE (
  total_active_engineers              bigint,
  total_amc_mrr_rupees                numeric,
  total_jobs_completed_30d            bigint,
  revenue_per_completed_job_avg_rupees numeric,
  avg_rpe_30d_rupees                  numeric,
  top_rpe_engineer_user_id            uuid,
  top_rpe_engineer_revenue_30d_rupees numeric,
  engineers_above_avg_rpe_count       bigint,
  engineers_below_avg_rpe_count       bigint,
  engineers_with_zero_revenue_30d     bigint,
  top_decile_rpe_threshold_rupees     numeric,
  bottom_decile_rpe_threshold_rupees  numeric,
  median_rpe_rupees                   numeric,
  generated_at                        timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_mrr_total numeric := 0;
  v_jobs_total bigint := 0;
  v_revenue_per_job numeric := 0;
  v_eng_total bigint := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT coalesce(sum(monthly_fee_rupees), 0) INTO v_mrr_total
  FROM public.amc_contracts WHERE status = 'active';

  SELECT count(*) INTO v_jobs_total
  FROM public.repair_jobs
  WHERE status = 'completed' AND completed_at >= now() - interval '30 days';

  IF v_jobs_total > 0 THEN
    v_revenue_per_job := v_mrr_total / v_jobs_total;
  END IF;

  SELECT count(*) INTO v_eng_total
  FROM public.engineers WHERE verification_status::text = 'verified';

  RETURN QUERY
  WITH per_eng AS (
    SELECT e.user_id,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '30 days'), 0)::int AS jobs_30d
    FROM public.engineers e WHERE e.verification_status::text = 'verified'
  ),
  with_rpe AS (
    SELECT user_id, jobs_30d, (jobs_30d * v_revenue_per_job)::numeric AS rpe_30d
    FROM per_eng
  )
  SELECT
    v_eng_total,
    round(v_mrr_total, 2)::numeric,
    v_jobs_total,
    round(v_revenue_per_job, 2)::numeric,
    CASE WHEN v_eng_total > 0 THEN round((sum(rpe_30d) / v_eng_total)::numeric, 2) ELSE 0 END,
    (SELECT user_id FROM with_rpe ORDER BY rpe_30d DESC NULLS LAST LIMIT 1),
    coalesce((SELECT round(rpe_30d, 2)::numeric FROM with_rpe ORDER BY rpe_30d DESC NULLS LAST LIMIT 1), 0),
    count(*) FILTER (WHERE rpe_30d > (sum(rpe_30d) OVER () / NULLIF(v_eng_total, 0)))::bigint,
    count(*) FILTER (WHERE rpe_30d < (sum(rpe_30d) OVER () / NULLIF(v_eng_total, 0)))::bigint,
    count(*) FILTER (WHERE rpe_30d = 0)::bigint,
    coalesce(percentile_cont(0.9) WITHIN GROUP (ORDER BY rpe_30d), 0)::numeric,
    coalesce(percentile_cont(0.1) WITHIN GROUP (ORDER BY rpe_30d), 0)::numeric,
    coalesce(percentile_cont(0.5) WITHIN GROUP (ORDER BY rpe_30d), 0)::numeric,
    now()
  FROM with_rpe;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_revenue_per_engineer_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_revenue_per_engineer_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_revenue_per_engineer_breakdown(int);
CREATE OR REPLACE FUNCTION public.founder_revenue_per_engineer_breakdown(p_limit int DEFAULT 50)
RETURNS TABLE (
  engineer_user_id              uuid,
  jobs_30d                      int,
  attributed_revenue_30d_rupees numeric,
  rpe_band                      text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_mrr numeric := 0; v_jobs bigint := 0; v_revenue_per_job numeric := 0;
  v_p90 numeric := 0; v_p50 numeric := 0; v_p10 numeric := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT coalesce(sum(monthly_fee_rupees), 0) INTO v_mrr
  FROM public.amc_contracts WHERE status = 'active';
  SELECT count(*) INTO v_jobs FROM public.repair_jobs
  WHERE status = 'completed' AND completed_at >= now() - interval '30 days';
  IF v_jobs > 0 THEN v_revenue_per_job := v_mrr / v_jobs; END IF;

  SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY (j.cnt * v_revenue_per_job)),
         percentile_cont(0.5) WITHIN GROUP (ORDER BY (j.cnt * v_revenue_per_job)),
         percentile_cont(0.1) WITHIN GROUP (ORDER BY (j.cnt * v_revenue_per_job))
  INTO v_p90, v_p50, v_p10
  FROM (
    SELECT coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '30 days'), 0) AS cnt
    FROM public.engineers e WHERE e.verification_status::text = 'verified'
  ) j;

  RETURN QUERY
  WITH per_eng AS (
    SELECT e.user_id,
           coalesce((SELECT count(*) FROM public.repair_jobs rj
                     WHERE rj.engineer_id = e.id AND rj.status = 'completed'
                       AND rj.completed_at >= now() - interval '30 days'), 0)::int AS jobs_30d
    FROM public.engineers e WHERE e.verification_status::text = 'verified'
  )
  SELECT
    pe.user_id, pe.jobs_30d,
    round((pe.jobs_30d * v_revenue_per_job)::numeric, 2),
    CASE
      WHEN (pe.jobs_30d * v_revenue_per_job) >= v_p90 THEN 'top_decile'
      WHEN (pe.jobs_30d * v_revenue_per_job) >= v_p50 THEN 'upper_half'
      WHEN (pe.jobs_30d * v_revenue_per_job) >= v_p10 THEN 'lower_half'
      ELSE 'bottom_decile'
    END
  FROM per_eng pe
  ORDER BY pe.jobs_30d DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_revenue_per_engineer_breakdown(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_revenue_per_engineer_breakdown(int) TO authenticated;

COMMIT;
