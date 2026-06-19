BEGIN;
-- Round 1241 — Pre-visit dossier (PVED) readiness summary
-- Why: pre_visit_engineer_dossiers is THE quality-prep signal but untapped.
-- Surface generation %, consume-before-visit %, accept→open p50,
-- jobs-without-dossier (quality risk), avg dossier size — direct FTFR proxy.

DROP FUNCTION IF EXISTS public.founder_pre_visit_dossier_readiness_summary();
CREATE OR REPLACE FUNCTION public.founder_pre_visit_dossier_readiness_summary()
RETURNS TABLE (
  metric_key       text,
  metric_label     text,
  value_num        numeric,
  value_display    text,
  bucket           text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_window_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date - INTERVAL '90 days';
  v_total_eligible_jobs    int;
  v_jobs_with_dossier      int;
  v_dossiers_total         int;
  v_dossiers_consumed      int;
  v_dossiers_expired       int;
  v_dossiers_cancelled     int;
  v_dossiers_issued_open   int;
  v_jobs_no_dossier        int;
  v_avg_last5_size         numeric;
  v_avg_cert_count         numeric;
  v_p50_accept_to_open_min numeric;
  v_p90_accept_to_open_min numeric;
  v_gen_pct                numeric;
  v_consume_pct            numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
  END IF;

  -- Eligible jobs = jobs with an accepted bid in last 90 days
  SELECT count(DISTINCT rj.id)::int
    INTO v_total_eligible_jobs
    FROM public.repair_jobs rj
    JOIN public.repair_job_bids b
      ON b.repair_job_id = rj.id AND b.status = 'accepted'
   WHERE rj.created_at >= v_window_start;

  SELECT count(DISTINCT pved.repair_job_id)::int
    INTO v_jobs_with_dossier
    FROM public.pre_visit_engineer_dossiers pved
    JOIN public.repair_jobs rj ON rj.id = pved.repair_job_id
   WHERE pved.issued_at >= v_window_start
     AND rj.created_at >= v_window_start;

  v_jobs_no_dossier := greatest(v_total_eligible_jobs - v_jobs_with_dossier, 0);

  SELECT
    count(*)::int,
    count(*) FILTER (WHERE status = 'consumed')::int,
    count(*) FILTER (WHERE status = 'expired')::int,
    count(*) FILTER (WHERE status = 'cancelled')::int,
    count(*) FILTER (WHERE status = 'issued')::int,
    coalesce(avg(coalesce(jsonb_array_length(last_5_jobs), 0))::numeric(10,2), 0),
    coalesce(avg(certificate_count)::numeric(10,2), 0)
    INTO
      v_dossiers_total,
      v_dossiers_consumed,
      v_dossiers_expired,
      v_dossiers_cancelled,
      v_dossiers_issued_open,
      v_avg_last5_size,
      v_avg_cert_count
    FROM public.pre_visit_engineer_dossiers
   WHERE issued_at >= v_window_start;

  v_gen_pct := CASE WHEN v_total_eligible_jobs > 0
                    THEN (v_jobs_with_dossier::numeric * 100.0 / v_total_eligible_jobs)::numeric(5,2)
                    ELSE 0 END;
  v_consume_pct := CASE WHEN v_dossiers_total > 0
                    THEN (v_dossiers_consumed::numeric * 100.0 / v_dossiers_total)::numeric(5,2)
                    ELSE 0 END;

  -- Time-from-accept (bid.accepted_at on the accepted bid) to
  -- dossier.consumed_at — percentile in minutes.
  WITH accepted AS (
    SELECT b.repair_job_id, max(b.updated_at) AS accepted_at
      FROM public.repair_job_bids b
     WHERE b.status = 'accepted'
       AND b.updated_at >= v_window_start
     GROUP BY b.repair_job_id
  ),
  durations AS (
    SELECT EXTRACT(EPOCH FROM (pved.consumed_at - a.accepted_at)) / 60.0 AS mins
      FROM public.pre_visit_engineer_dossiers pved
      JOIN accepted a ON a.repair_job_id = pved.repair_job_id
     WHERE pved.consumed_at IS NOT NULL
       AND pved.consumed_at >= a.accepted_at
  )
  SELECT
    percentile_cont(0.5) WITHIN GROUP (ORDER BY mins)::numeric(10,1),
    percentile_cont(0.9) WITHIN GROUP (ORDER BY mins)::numeric(10,1)
    INTO v_p50_accept_to_open_min, v_p90_accept_to_open_min
    FROM durations;

  RETURN QUERY
  SELECT 'eligible_jobs_90d'::text, 'Eligible jobs (90d, accepted bid)'::text,
         v_total_eligible_jobs::numeric, v_total_eligible_jobs::text, 'volume'::text
  UNION ALL SELECT 'jobs_with_dossier_90d', 'Jobs with dossier issued',
         v_jobs_with_dossier::numeric, v_jobs_with_dossier::text, 'volume'
  UNION ALL SELECT 'jobs_no_dossier_90d', 'Jobs WITHOUT dossier (quality risk)',
         v_jobs_no_dossier::numeric, v_jobs_no_dossier::text, 'risk'
  UNION ALL SELECT 'gen_pct_90d', 'Dossier generation %',
         v_gen_pct, v_gen_pct::text || '%', 'rate'
  UNION ALL SELECT 'consume_pct_90d', 'Dossier opened-before-visit %',
         v_consume_pct, v_consume_pct::text || '%', 'rate'
  UNION ALL SELECT 'p50_accept_to_open_min', 'Accept → open p50 (min)',
         coalesce(v_p50_accept_to_open_min, 0),
         coalesce(v_p50_accept_to_open_min, 0)::text || ' min', 'latency'
  UNION ALL SELECT 'p90_accept_to_open_min', 'Accept → open p90 (min)',
         coalesce(v_p90_accept_to_open_min, 0),
         coalesce(v_p90_accept_to_open_min, 0)::text || ' min', 'latency'
  UNION ALL SELECT 'dossiers_total_90d', 'Dossiers issued (total)',
         v_dossiers_total::numeric, v_dossiers_total::text, 'volume'
  UNION ALL SELECT 'dossiers_consumed_90d', 'Dossiers consumed',
         v_dossiers_consumed::numeric, v_dossiers_consumed::text, 'volume'
  UNION ALL SELECT 'dossiers_issued_open_90d', 'Dossiers still in issued state',
         v_dossiers_issued_open::numeric, v_dossiers_issued_open::text, 'volume'
  UNION ALL SELECT 'dossiers_expired_90d', 'Dossiers expired unopened',
         v_dossiers_expired::numeric, v_dossiers_expired::text, 'risk'
  UNION ALL SELECT 'dossiers_cancelled_90d', 'Dossiers cancelled (re-issued)',
         v_dossiers_cancelled::numeric, v_dossiers_cancelled::text, 'volume'
  UNION ALL SELECT 'avg_last5_size', 'Avg recent-jobs payload (rows)',
         v_avg_last5_size, v_avg_last5_size::text, 'size'
  UNION ALL SELECT 'avg_cert_count', 'Avg cert count per dossier',
         v_avg_cert_count, v_avg_cert_count::text, 'size';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_pre_visit_dossier_readiness_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pre_visit_dossier_readiness_summary() TO authenticated;
COMMIT;
