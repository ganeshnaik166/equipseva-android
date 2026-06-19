BEGIN;
-- r1377 — /founder-hospital-segmentation — hospital segmentation by usage × value.
-- Pure aggregator. Volume bands: high≥10 jobs/90d, medium≥3, low≥1, dormant=0.
-- Value bands: high≥10000 monthly fee, medium≥3000, low<3000. Composite = 9 cells.

DROP FUNCTION IF EXISTS public.founder_hospital_segmentation_summary();
CREATE OR REPLACE FUNCTION public.founder_hospital_segmentation_summary()
RETURNS TABLE (
  total_active_hospitals          bigint,
  high_volume_count               bigint,
  medium_volume_count             bigint,
  low_volume_count                bigint,
  dormant_count                   bigint,
  top_hospital_jobs_90d_count     int,
  top_hospital_name               text,
  avg_jobs_per_hospital_90d       numeric,
  avg_spend_per_hospital_90d_rupees numeric,
  enterprise_segment_count        bigint,
  starter_segment_count           bigint,
  super_user_count                bigint,
  segment_at_risk_count           bigint,
  generated_at                    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH active_amcs AS (
    SELECT DISTINCT c.hospital_org_id, c.amc_tier, c.monthly_fee_rupees, c.end_date
    FROM public.amc_contracts c
    WHERE c.status = 'active' AND c.hospital_org_id IS NOT NULL
  ),
  hosp_jobs AS (
    SELECT
      a.hospital_org_id,
      a.amc_tier,
      a.monthly_fee_rupees,
      a.end_date,
      coalesce(o.name, '(unnamed)') AS hospital_name,
      coalesce((
        SELECT count(*)::int FROM public.repair_jobs rj
        WHERE rj.hospital_org_id = a.hospital_org_id
          AND rj.completed_at >= now() - interval '90 days'
      ), 0) AS jobs_90d
    FROM active_amcs a
    LEFT JOIN public.organizations o ON o.id = a.hospital_org_id
  )
  SELECT
    count(*)::bigint AS total_active_hospitals,
    count(*) FILTER (WHERE jobs_90d >= 10)::bigint AS high_volume_count,
    count(*) FILTER (WHERE jobs_90d BETWEEN 3 AND 9)::bigint AS medium_volume_count,
    count(*) FILTER (WHERE jobs_90d BETWEEN 1 AND 2)::bigint AS low_volume_count,
    count(*) FILTER (WHERE jobs_90d = 0)::bigint AS dormant_count,
    coalesce((SELECT jobs_90d FROM hosp_jobs ORDER BY jobs_90d DESC LIMIT 1), 0)::int,
    coalesce((SELECT hospital_name FROM hosp_jobs ORDER BY jobs_90d DESC LIMIT 1), '(none)')::text,
    coalesce(avg(jobs_90d), 0)::numeric,
    coalesce(avg(jobs_90d * coalesce(monthly_fee_rupees, 0) / 30.0), 0)::numeric,
    count(*) FILTER (WHERE amc_tier = 'enterprise')::bigint,
    count(*) FILTER (WHERE amc_tier = 'starter')::bigint,
    count(*) FILTER (WHERE jobs_90d >= 20 AND amc_tier = 'enterprise')::bigint,
    count(*) FILTER (WHERE jobs_90d = 0 AND end_date < (now() + interval '60 days')::date)::bigint,
    now()
  FROM hosp_jobs;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_segmentation_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_segmentation_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_hospital_segmentation_by_segment(int);
CREATE OR REPLACE FUNCTION public.founder_hospital_segmentation_by_segment(p_limit int DEFAULT 100)
RETURNS TABLE (
  hospital_org_id        uuid,
  hospital_name          text,
  amc_tier               text,
  monthly_fee_rupees     numeric,
  jobs_90d               int,
  spend_90d_rupees       numeric,
  last_job_at            timestamptz,
  volume_segment         text,
  value_segment          text,
  composite_segment      text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH active_amcs AS (
    SELECT DISTINCT c.hospital_org_id, c.amc_tier, c.monthly_fee_rupees
    FROM public.amc_contracts c
    WHERE c.status = 'active' AND c.hospital_org_id IS NOT NULL
  ),
  per_hosp AS (
    SELECT
      a.hospital_org_id,
      coalesce(o.name, '(unnamed)') AS hospital_name,
      a.amc_tier::text AS amc_tier,
      coalesce(a.monthly_fee_rupees, 0)::numeric AS monthly_fee_rupees,
      coalesce(jc.cnt, 0)::int AS jobs_90d,
      coalesce(jc.cnt, 0) * coalesce(a.monthly_fee_rupees, 0) / 30.0 AS spend_90d_rupees,
      jc.last_at AS last_job_at
    FROM active_amcs a
    LEFT JOIN public.organizations o ON o.id = a.hospital_org_id
    LEFT JOIN (
      SELECT hospital_org_id, count(*) AS cnt, max(completed_at) AS last_at
      FROM public.repair_jobs
      WHERE completed_at >= now() - interval '90 days'
      GROUP BY hospital_org_id
    ) jc ON jc.hospital_org_id = a.hospital_org_id
  )
  SELECT
    p.hospital_org_id, p.hospital_name, p.amc_tier, p.monthly_fee_rupees,
    p.jobs_90d, round(p.spend_90d_rupees, 2)::numeric, p.last_job_at,
    CASE WHEN p.jobs_90d >= 10 THEN 'high'
         WHEN p.jobs_90d >= 3  THEN 'medium'
         WHEN p.jobs_90d >= 1  THEN 'low'
         ELSE 'dormant' END AS volume_segment,
    CASE WHEN p.monthly_fee_rupees >= 10000 THEN 'high_value'
         WHEN p.monthly_fee_rupees >= 3000  THEN 'medium_value'
         ELSE 'low_value' END AS value_segment,
    (
      CASE WHEN p.jobs_90d >= 10 THEN 'h' WHEN p.jobs_90d >= 3 THEN 'm' WHEN p.jobs_90d >= 1 THEN 'l' ELSE 'd' END
      || '_' ||
      CASE WHEN p.monthly_fee_rupees >= 10000 THEN 'h' WHEN p.monthly_fee_rupees >= 3000 THEN 'm' ELSE 'l' END
    ) AS composite_segment
  FROM per_hosp p
  ORDER BY p.spend_90d_rupees DESC NULLS LAST, p.jobs_90d DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_segmentation_by_segment(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_segmentation_by_segment(int) TO authenticated;

COMMIT;
