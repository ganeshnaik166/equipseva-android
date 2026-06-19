BEGIN;
DROP FUNCTION IF EXISTS public.founder_repair_types_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_repair_types_snapshot_summary()
RETURNS TABLE (
  jobs_total_90d                   bigint,
  distinct_job_types_90d           bigint,
  top_job_type                     text,
  top_job_type_count_90d           bigint,
  unspecified_job_type_90d         bigint,
  amc_kind_jobs_90d                bigint,
  warranty_kind_jobs_90d           bigint,
  paid_kind_jobs_90d               bigint,
  urgency_emergency_90d            bigint,
  urgency_high_90d                 bigint,
  contracted_revenue_30d_rupees    numeric,
  avg_completion_hours_by_kind_amc numeric,
  avg_completion_hours_by_kind_paid numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_type       text;
  v_top_type_count bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- precompute top job_type by volume (90d), normalize NULL/blank
  SELECT coalesce(nullif(trim(j.job_type), ''), '(unspecified)')::text, count(*)::bigint
    INTO v_top_type, v_top_type_count
    FROM public.repair_jobs j
   WHERE j.created_at >= now() - interval '90 days'
   GROUP BY coalesce(nullif(trim(j.job_type), ''), '(unspecified)')
   ORDER BY count(*) DESC
   LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'), 0),
    coalesce((SELECT count(DISTINCT coalesce(nullif(trim(j.job_type), ''), '(unspecified)'))::bigint
               FROM public.repair_jobs j
              WHERE j.created_at >= now() - interval '90 days'), 0),
    coalesce(v_top_type, '(none)')::text,
    coalesce(v_top_type_count, 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
               WHERE j.created_at >= now() - interval '90 days'
                 AND (j.job_type IS NULL OR length(trim(j.job_type)) = 0)), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND kind = 'amc'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND kind = 'warranty'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND (kind IS NULL OR kind = 'repair')), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND urgency = 'emergency'), 0),
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND urgency = 'high'), 0),
    coalesce((SELECT round(sum(contracted_amount_rupees)::numeric, 2)
                FROM public.repair_jobs
               WHERE status = 'completed'
                 AND completed_at >= now() - interval '30 days'
                 AND contracted_amount_rupees IS NOT NULL), 0)::numeric,
    coalesce((SELECT round(avg(extract(epoch FROM (completed_at - created_at)) / 3600.0)::numeric, 1)
                FROM public.repair_jobs
               WHERE status = 'completed'
                 AND completed_at >= now() - interval '30 days'
                 AND completed_at IS NOT NULL
                 AND kind = 'amc'), 0)::numeric,
    coalesce((SELECT round(avg(extract(epoch FROM (completed_at - created_at)) / 3600.0)::numeric, 1)
                FROM public.repair_jobs
               WHERE status = 'completed'
                 AND completed_at >= now() - interval '30 days'
                 AND completed_at IS NOT NULL
                 AND (kind IS NULL OR kind = 'repair')), 0)::numeric
  ;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_types_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_types_snapshot_summary() TO authenticated;
COMMIT;
