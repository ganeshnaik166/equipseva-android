BEGIN;
-- r1328 — founder_engineer_cohort_retention + founder_hospital_cohort_retention
--
-- Two cohort retention RPCs for the founder console.
--
--   founder_engineer_cohort_retention(p_months int default 12)
--     Cohort = engineers grouped by date_trunc('month', engineers.created_at).
--     M0 active = at least one repair_jobs.completed_at within cohort month itself.
--     M1..M6, M12 active = same engineer with completed_at in cohort_month + N months.
--
--   founder_hospital_cohort_retention(p_months int default 12)
--     Cohort = organizations.kind='hospital' grouped by date_trunc('month', organizations.created_at).
--     Active in month M = at least one repair_jobs.hospital_org_id = org.id with completed_at in cohort_month + N.
--
-- Both functions are STABLE, SECURITY DEFINER, gated by is_founder(), search_path locked.
-- No new tables introduced.



DROP FUNCTION IF EXISTS public.founder_engineer_cohort_retention(int);
DROP FUNCTION IF EXISTS public.founder_hospital_cohort_retention(int);

CREATE OR REPLACE FUNCTION public.founder_engineer_cohort_retention(p_months int DEFAULT 12)
RETURNS TABLE (
  cohort_month        date,
  cohort_size         int,
  m0_active           int,
  m1_active           int,
  m2_active           int,
  m3_active           int,
  m4_active           int,
  m5_active           int,
  m6_active           int,
  m12_active          int,
  retention_pct_m1    numeric,
  retention_pct_m3    numeric,
  retention_pct_m6    numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_months int := greatest(1, least(coalesce(p_months, 12), 36));
  v_start  date := (date_trunc('month', now())::date) - make_interval(months => v_months - 1);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH cohorts AS (
    SELECT
      date_trunc('month', e.created_at)::date AS cohort_month,
      e.id                                    AS engineer_id
    FROM public.engineers e
    WHERE e.created_at >= v_start
  ),
  cohort_sizes AS (
    SELECT cohort_month, count(*)::int AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
  ),
  activity AS (
    SELECT
      c.cohort_month,
      c.engineer_id,
      date_trunc('month', rj.completed_at)::date AS active_month
    FROM cohorts c
    JOIN public.repair_jobs rj
      ON rj.engineer_id = c.engineer_id
     AND rj.status = 'completed'
     AND rj.completed_at IS NOT NULL
  ),
  per_offset AS (
    SELECT
      a.cohort_month,
      ((extract(year FROM age(a.active_month, a.cohort_month)) * 12)
       + extract(month FROM age(a.active_month, a.cohort_month)))::int AS m_offset,
      a.engineer_id
    FROM activity a
    WHERE a.active_month >= a.cohort_month
  ),
  agg AS (
    SELECT
      cohort_month,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 0)  AS m0,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 1)  AS m1,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 2)  AS m2,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 3)  AS m3,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 4)  AS m4,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 5)  AS m5,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 6)  AS m6,
      count(DISTINCT engineer_id) FILTER (WHERE m_offset = 12) AS m12
    FROM per_offset
    GROUP BY cohort_month
  )
  SELECT
    cs.cohort_month,
    cs.cohort_size,
    coalesce(a.m0,  0)::int AS m0_active,
    coalesce(a.m1,  0)::int AS m1_active,
    coalesce(a.m2,  0)::int AS m2_active,
    coalesce(a.m3,  0)::int AS m3_active,
    coalesce(a.m4,  0)::int AS m4_active,
    coalesce(a.m5,  0)::int AS m5_active,
    coalesce(a.m6,  0)::int AS m6_active,
    coalesce(a.m12, 0)::int AS m12_active,
    CASE WHEN cs.cohort_size > 0 THEN round((coalesce(a.m1, 0)::numeric / cs.cohort_size) * 100, 1) ELSE 0 END AS retention_pct_m1,
    CASE WHEN cs.cohort_size > 0 THEN round((coalesce(a.m3, 0)::numeric / cs.cohort_size) * 100, 1) ELSE 0 END AS retention_pct_m3,
    CASE WHEN cs.cohort_size > 0 THEN round((coalesce(a.m6, 0)::numeric / cs.cohort_size) * 100, 1) ELSE 0 END AS retention_pct_m6
  FROM cohort_sizes cs
  LEFT JOIN agg a USING (cohort_month)
  ORDER BY cs.cohort_month DESC;
END;
$$;

ALTER FUNCTION public.founder_engineer_cohort_retention(int) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_cohort_retention(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_cohort_retention(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_hospital_cohort_retention(p_months int DEFAULT 12)
RETURNS TABLE (
  cohort_month        date,
  cohort_size         int,
  m0_active           int,
  m1_active           int,
  m2_active           int,
  m3_active           int,
  m4_active           int,
  m5_active           int,
  m6_active           int,
  m12_active          int,
  retention_pct_m1    numeric,
  retention_pct_m3    numeric,
  retention_pct_m6    numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_months int := greatest(1, least(coalesce(p_months, 12), 36));
  v_start  date := (date_trunc('month', now())::date) - make_interval(months => v_months - 1);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH cohorts AS (
    SELECT
      date_trunc('month', o.created_at)::date AS cohort_month,
      o.id                                    AS org_id
    FROM public.organizations o
    WHERE o.kind = 'hospital'
      AND o.created_at >= v_start
  ),
  cohort_sizes AS (
    SELECT cohort_month, count(*)::int AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
  ),
  activity AS (
    SELECT
      c.cohort_month,
      c.org_id,
      date_trunc('month', rj.completed_at)::date AS active_month
    FROM cohorts c
    JOIN public.repair_jobs rj
      ON rj.hospital_org_id = c.org_id
     AND rj.completed_at IS NOT NULL
  ),
  per_offset AS (
    SELECT
      a.cohort_month,
      ((extract(year FROM age(a.active_month, a.cohort_month)) * 12)
       + extract(month FROM age(a.active_month, a.cohort_month)))::int AS m_offset,
      a.org_id
    FROM activity a
    WHERE a.active_month >= a.cohort_month
  ),
  agg AS (
    SELECT
      cohort_month,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 0)  AS m0,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 1)  AS m1,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 2)  AS m2,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 3)  AS m3,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 4)  AS m4,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 5)  AS m5,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 6)  AS m6,
      count(DISTINCT org_id) FILTER (WHERE m_offset = 12) AS m12
    FROM per_offset
    GROUP BY cohort_month
  )
  SELECT
    cs.cohort_month,
    cs.cohort_size,
    coalesce(a.m0,  0)::int AS m0_active,
    coalesce(a.m1,  0)::int AS m1_active,
    coalesce(a.m2,  0)::int AS m2_active,
    coalesce(a.m3,  0)::int AS m3_active,
    coalesce(a.m4,  0)::int AS m4_active,
    coalesce(a.m5,  0)::int AS m5_active,
    coalesce(a.m6,  0)::int AS m6_active,
    coalesce(a.m12, 0)::int AS m12_active,
    CASE WHEN cs.cohort_size > 0 THEN round((coalesce(a.m1, 0)::numeric / cs.cohort_size) * 100, 1) ELSE 0 END AS retention_pct_m1,
    CASE WHEN cs.cohort_size > 0 THEN round((coalesce(a.m3, 0)::numeric / cs.cohort_size) * 100, 1) ELSE 0 END AS retention_pct_m3,
    CASE WHEN cs.cohort_size > 0 THEN round((coalesce(a.m6, 0)::numeric / cs.cohort_size) * 100, 1) ELSE 0 END AS retention_pct_m6
  FROM cohort_sizes cs
  LEFT JOIN agg a USING (cohort_month)
  ORDER BY cs.cohort_month DESC;
END;
$$;

ALTER FUNCTION public.founder_hospital_cohort_retention(int) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_cohort_retention(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_cohort_retention(int) TO authenticated;

COMMIT;