BEGIN;
-- r1339 — CRITICAL audit-fix sweep for batch 13.
-- Workflow whg8da6kf caught 4 confirmed bugs:
--
-- 1. r1331 CRITICAL: amc_contracts.activated_at + amc_contracts.deactivated_at
--    columns DO NOT EXIST in the original schema (r451/v21_amc_contracts only
--    defines start_date + end_date + status). Multiple migrations (r1315 /
--    r1322 / r1331) reference these non-existent columns — all RPCs that
--    touch them would 500 with column-does-not-exist at runtime.
--    Fix: ADD COLUMN both (nullable) + backfill from start_date/end_date.
--
-- 2. r1330 HIGH: founder_hospital_cohort_retention omits the status='completed'
--    filter that founder_engineer_cohort_retention has. Retention numbers
--    inflated by disputed/cancelled jobs. Fix the JOIN condition.
--
-- 3. r1329 MEDIUM/LOW: fmtRup() misuse + oldest_pending_days TS type
--    nullability — cosmetic only, defer to a non-critical follow-up.

-- ============================================================================
-- 1. ALTER amc_contracts to ADD missing activated_at + deactivated_at columns
-- ============================================================================
ALTER TABLE public.amc_contracts
  ADD COLUMN IF NOT EXISTS activated_at   timestamptz,
  ADD COLUMN IF NOT EXISTS deactivated_at timestamptz;

-- Backfill: every existing row's activated_at = start_date 00:00 IST + 12h
-- (noon local), since the schema uses start_date::timestamptz + 12h as the
-- first-visit nudge time. Deactivated_at NULL while still active; set to
-- end_date + 23:59:59 IST for churned/expired rows.
UPDATE public.amc_contracts
SET activated_at = (start_date::timestamptz + interval '12 hours')
WHERE activated_at IS NULL;

UPDATE public.amc_contracts
SET deactivated_at = (end_date::timestamptz + interval '23 hours 59 minutes')
WHERE deactivated_at IS NULL
  AND status IN ('churned','expired','cancelled');

CREATE INDEX IF NOT EXISTS idx_amc_contracts_activated_at
  ON public.amc_contracts (activated_at DESC);

-- ============================================================================
-- 2. r1330 — add status='completed' filter to hospital cohort retention
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_hospital_cohort_retention(int);
CREATE OR REPLACE FUNCTION public.founder_hospital_cohort_retention(p_months int DEFAULT 12)
RETURNS TABLE (
  cohort_month       date,
  cohort_size        int,
  m0_active          int,
  m1_active          int,
  m2_active          int,
  m3_active          int,
  m4_active          int,
  m5_active          int,
  m6_active          int,
  m12_active         int,
  retention_pct_m1   numeric,
  retention_pct_m3   numeric,
  retention_pct_m6   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_months int := GREATEST(LEAST(COALESCE(p_months, 12), 24), 1);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  WITH cohorts AS (
    SELECT
      o.id        AS org_id,
      date_trunc('month', o.created_at AT TIME ZONE 'Asia/Kolkata')::date AS c_month
    FROM public.organizations o
    WHERE o.kind = 'hospital'
      AND o.created_at >= now() - (v_months || ' months')::interval
  ),
  -- r1339 FIX: status='completed' filter (matched engineer cohort retention)
  activity AS (
    SELECT
      c.org_id,
      c.c_month,
      date_trunc('month', rj.completed_at AT TIME ZONE 'Asia/Kolkata')::date AS active_month
    FROM cohorts c
    JOIN public.repair_jobs rj
      ON rj.hospital_org_id = c.org_id
     AND rj.status = 'completed'
     AND rj.completed_at IS NOT NULL
  ),
  cohort_size AS (
    SELECT c_month, count(DISTINCT org_id)::int AS sz FROM cohorts GROUP BY c_month
  ),
  active_buckets AS (
    SELECT
      c.c_month,
      count(DISTINCT CASE WHEN a.active_month = c.c_month                                       THEN c.org_id END)::int AS m0,
      count(DISTINCT CASE WHEN a.active_month = (c.c_month + interval '1 month')::date          THEN c.org_id END)::int AS m1,
      count(DISTINCT CASE WHEN a.active_month = (c.c_month + interval '2 months')::date         THEN c.org_id END)::int AS m2,
      count(DISTINCT CASE WHEN a.active_month = (c.c_month + interval '3 months')::date         THEN c.org_id END)::int AS m3,
      count(DISTINCT CASE WHEN a.active_month = (c.c_month + interval '4 months')::date         THEN c.org_id END)::int AS m4,
      count(DISTINCT CASE WHEN a.active_month = (c.c_month + interval '5 months')::date         THEN c.org_id END)::int AS m5,
      count(DISTINCT CASE WHEN a.active_month = (c.c_month + interval '6 months')::date         THEN c.org_id END)::int AS m6,
      count(DISTINCT CASE WHEN a.active_month = (c.c_month + interval '12 months')::date        THEN c.org_id END)::int AS m12
    FROM cohorts c
    LEFT JOIN activity a ON a.org_id = c.org_id
    GROUP BY c.c_month
  )
  SELECT
    cs.c_month,
    cs.sz,
    COALESCE(ab.m0, 0), COALESCE(ab.m1, 0), COALESCE(ab.m2, 0),
    COALESCE(ab.m3, 0), COALESCE(ab.m4, 0), COALESCE(ab.m5, 0),
    COALESCE(ab.m6, 0), COALESCE(ab.m12, 0),
    CASE WHEN cs.sz > 0 THEN ROUND((COALESCE(ab.m1, 0)::numeric / cs.sz::numeric) * 100, 1) ELSE 0 END,
    CASE WHEN cs.sz > 0 THEN ROUND((COALESCE(ab.m3, 0)::numeric / cs.sz::numeric) * 100, 1) ELSE 0 END,
    CASE WHEN cs.sz > 0 THEN ROUND((COALESCE(ab.m6, 0)::numeric / cs.sz::numeric) * 100, 1) ELSE 0 END
  FROM cohort_size cs
  LEFT JOIN active_buckets ab ON ab.c_month = cs.c_month
  ORDER BY cs.c_month;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_cohort_retention(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_cohort_retention(int) TO authenticated;

COMMIT;
