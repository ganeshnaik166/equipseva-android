BEGIN;
-- r1237 — audit-driven sweep (wf wwc5rgoqp) for r1224 + r1225 bugs.
--
-- 1. r1224 founder_regional_city_summary — CRITICAL: profiles.city column
--    does NOT exist (removed in earlier schema/security sweep — see
--    20260508110100_v2_engineer_recent_reviews_drop_profile_city.sql).
--    Three sites in r1224 reference p.city. Function fails at runtime.
--    Fix: bridge hospital_user_id → profiles.organization_id → organizations.city.
--
-- 2. r1225 founder_repair_types_snapshot_summary — HIGH:
--    repair_jobs.kind CHECK constraint allows only 'repair'/'maintenance'.
--    r1225 filters kind='amc' (always 0) and kind='warranty' (always 0).
--    AMC visits use kind='maintenance'. Warranty work is tracked via the
--    warranty_source_job_id column, NOT kind discriminator.

-- ============================================================================
-- 1. r1224 founder_regional_city_summary — profiles.city → organizations.city
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_regional_city_summary();
CREATE OR REPLACE FUNCTION public.founder_regional_city_summary()
RETURNS TABLE (
  cities_active_30d         bigint,
  top1_city                 text,
  top1_jobs_30d             bigint,
  top1_revenue_30d_rupees   numeric,
  top1_active_amcs          bigint,
  top1_engineers_30d        bigint,
  top1_hospitals_30d        bigint,
  top2_city                 text,
  top2_jobs_30d             bigint,
  top3_city                 text,
  top3_jobs_30d             bigint,
  top1_share_pct            numeric,
  total_jobs_30d            bigint,
  total_revenue_30d_rupees  numeric,
  unknown_city_jobs_30d     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_jobs_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- profiles.city does not exist; bridge via profiles.organization_id → organizations.city.
  CREATE TEMP TABLE IF NOT EXISTS _tmp_regional_city_rollup ON COMMIT DROP AS
  WITH job_city AS (
    SELECT
      coalesce(nullif(trim(o.city), ''), '(unknown)') AS city,
      rj.id            AS job_id,
      rj.hospital_user_id,
      rj.engineer_id,
      rj.status,
      rj.completed_at,
      rj.created_at,
      rj.contracted_amount_rupees
    FROM public.repair_jobs rj
    LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    WHERE rj.created_at >= now() - interval '30 days'
  ),
  amc_city AS (
    SELECT
      coalesce(nullif(trim(o.city), ''), '(unknown)') AS city,
      c.id AS amc_id,
      c.status
    FROM public.amc_contracts c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
  ),
  agg AS (
    SELECT
      jc.city,
      count(DISTINCT jc.job_id)::bigint                                                    AS jobs_30d,
      count(DISTINCT jc.hospital_user_id)::bigint                                          AS hospitals_30d,
      count(DISTINCT jc.engineer_id) FILTER (WHERE jc.engineer_id IS NOT NULL)::bigint     AS engineers_30d,
      coalesce(sum(jc.contracted_amount_rupees) FILTER (WHERE jc.status = 'completed'
        AND jc.completed_at >= now() - interval '30 days'), 0)::numeric                    AS revenue_30d
    FROM job_city jc
    GROUP BY jc.city
  ),
  amc_agg AS (
    SELECT a.city, count(*) FILTER (WHERE a.status = 'active')::bigint AS active_amcs
    FROM amc_city a GROUP BY a.city
  )
  SELECT
    agg.city,
    agg.jobs_30d,
    agg.hospitals_30d,
    agg.engineers_30d,
    agg.revenue_30d,
    coalesce(amc_agg.active_amcs, 0)::bigint AS active_amcs,
    (agg.jobs_30d
      + (agg.revenue_30d / 1000.0)
      + (agg.engineers_30d * 5)
      + (agg.hospitals_30d * 5)
      + (coalesce(amc_agg.active_amcs, 0) * 3))::numeric AS score
  FROM agg
  LEFT JOIN amc_agg ON amc_agg.city = agg.city
  WHERE agg.city <> '(unknown)';

  SELECT coalesce(sum(r.jobs_30d), 0)::bigint INTO v_total_jobs_30d FROM _tmp_regional_city_rollup r;
  IF v_total_jobs_30d IS NULL THEN v_total_jobs_30d := 0; END IF;

  RETURN QUERY
  WITH ranked AS (
    SELECT
      r.*,
      row_number() OVER (ORDER BY r.score DESC NULLS LAST, r.jobs_30d DESC, r.city ASC) AS rk
    FROM _tmp_regional_city_rollup r
  ),
  t1 AS (SELECT * FROM ranked WHERE rk = 1),
  t2 AS (SELECT * FROM ranked WHERE rk = 2),
  t3 AS (SELECT * FROM ranked WHERE rk = 3)
  SELECT
    coalesce((SELECT count(*)::bigint FROM _tmp_regional_city_rollup), 0),
    coalesce((SELECT city FROM t1), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t1), 0)::bigint,
    coalesce((SELECT revenue_30d FROM t1), 0)::numeric,
    coalesce((SELECT active_amcs FROM t1), 0)::bigint,
    coalesce((SELECT engineers_30d FROM t1), 0)::bigint,
    coalesce((SELECT hospitals_30d FROM t1), 0)::bigint,
    coalesce((SELECT city FROM t2), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t2), 0)::bigint,
    coalesce((SELECT city FROM t3), '(none)')::text,
    coalesce((SELECT jobs_30d FROM t3), 0)::bigint,
    CASE WHEN v_total_jobs_30d = 0 THEN 0::numeric
         ELSE round(100.0 * coalesce((SELECT jobs_30d FROM t1), 0)::numeric / v_total_jobs_30d, 1) END,
    v_total_jobs_30d,
    coalesce((SELECT sum(revenue_30d)::numeric FROM _tmp_regional_city_rollup), 0),
    coalesce((SELECT count(*)::bigint
              FROM public.repair_jobs rj
              LEFT JOIN public.profiles p ON p.id = rj.hospital_user_id
              LEFT JOIN public.organizations o ON o.id = p.organization_id
              WHERE rj.created_at >= now() - interval '30 days'
                AND coalesce(nullif(trim(o.city), ''), '(unknown)') = '(unknown)'), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_regional_city_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_regional_city_summary() TO authenticated;

-- ============================================================================
-- 2. r1225 founder_repair_types_snapshot_summary — fix kind enum + warranty
-- ============================================================================
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
    -- AMC visits use kind = 'maintenance' (NOT 'amc' — CHECK constraint only allows 'repair'/'maintenance')
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND kind = 'maintenance'), 0),
    -- Warranty work is tracked via warranty_source_job_id FK column, not kind discriminator
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND warranty_source_job_id IS NOT NULL), 0),
    -- Paid bucket = kind = 'repair' (kind is NOT NULL with DEFAULT 'repair')
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs
               WHERE created_at >= now() - interval '90 days'
                 AND kind = 'repair'), 0),
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
                 AND kind = 'maintenance'), 0)::numeric,
    coalesce((SELECT round(avg(extract(epoch FROM (completed_at - created_at)) / 3600.0)::numeric, 1)
                FROM public.repair_jobs
               WHERE status = 'completed'
                 AND completed_at >= now() - interval '30 days'
                 AND completed_at IS NOT NULL
                 AND kind = 'repair'), 0)::numeric
  ;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_repair_types_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_repair_types_snapshot_summary() TO authenticated;

COMMIT;
