BEGIN;
-- round1360_founder_amc_renewal_pipeline.sql
-- Pure read aggregator: AMC renewal pipeline with T-90/60/30 windows.
-- NO new tables. Reads amc_contracts + amc_payment_pool + repair_jobs + code_red_requests
--   + repair_job_escrow + profiles for hospital name.
--
-- Two RPCs:
--   founder_amc_renewal_pipeline_summary()  -> 16 KPIs
--   founder_amc_renewal_pipeline_due(p_window_days int, p_limit int)  -> per-contract rows

-- ------------------------------------------------------------------
-- 1. KPI summary
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_amc_renewal_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_pipeline_summary()
RETURNS TABLE (
  total_active_amcs                       bigint,
  renewals_due_t90                        bigint,
  renewals_due_t60                        bigint,
  renewals_due_t30                        bigint,
  renewals_overdue                        bigint,
  expected_renewal_arr_rupees             numeric,
  avg_renewal_lead_time_days              numeric,
  highest_value_renewal_due_rupees        numeric,
  highest_value_renewal_hospital_name     text,
  contracts_at_risk_due_t90               bigint,
  contracts_renewed_30d                   bigint,
  contracts_churned_30d                   bigint,
  net_renewal_pct                         numeric,
  enterprise_tier_due_t90                 bigint,
  growth_tier_due_t90                     bigint,
  starter_tier_due_t90                    bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now            timestamptz := now();
  v_renewed_30d    bigint;
  v_churned_30d    bigint;
  v_highest_val    numeric;
  v_highest_name   text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Highest-value contract end-date in next 90d (expected_renewal_value = monthly_fee * 12)
  SELECT
    (c.monthly_fee_rupees * 12)::numeric,
    coalesce(hp.full_name, '(unnamed)')
  INTO v_highest_val, v_highest_name
  FROM public.amc_contracts c
  LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
  WHERE c.status = 'active'
    AND c.end_date IS NOT NULL
    AND c.end_date >= v_now::date
    AND c.end_date <= (v_now + interval '90 days')::date
  ORDER BY (c.monthly_fee_rupees * 12) DESC NULLS LAST
  LIMIT 1;

  SELECT count(*) INTO v_renewed_30d
  FROM public.amc_contracts c
  WHERE c.end_date > v_now::date
    AND c.created_at + interval '12 months' < c.end_date
    AND c.created_at >= v_now - interval '30 days';

  SELECT count(*) INTO v_churned_30d
  FROM public.amc_contracts c
  WHERE c.status = 'churned'
    AND c.deactivated_at IS NOT NULL
    AND c.deactivated_at >= v_now - interval '30 days';

  RETURN QUERY
  WITH base AS (
    SELECT
      c.id,
      c.hospital_user_id,
      c.amc_tier,
      c.monthly_fee_rupees,
      c.end_date,
      c.status,
      (c.end_date - v_now::date) AS days_until
    FROM public.amc_contracts c
    WHERE c.status = 'active'
      AND c.end_date IS NOT NULL
  ),
  due90 AS (
    SELECT * FROM base WHERE days_until BETWEEN 0 AND 90
  ),
  at_risk AS (
    SELECT DISTINCT d.id
    FROM due90 d
    WHERE EXISTS (
      SELECT 1
      FROM public.code_red_requests cr
      WHERE cr.hospital_user_id = d.hospital_user_id
        AND cr.created_at >= v_now - interval '30 days'
        AND cr.status NOT IN ('resolved','timed_out','cancelled')
    )
    OR EXISTS (
      SELECT 1
      FROM public.repair_job_escrow e
      JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
      WHERE rj.amc_contract_id = d.id
        AND e.status = 'in_dispute'
    )
  )
  SELECT
    (SELECT count(*)::bigint FROM base) AS total_active_amcs,
    (SELECT count(*)::bigint FROM base WHERE days_until BETWEEN 0 AND 90)  AS renewals_due_t90,
    (SELECT count(*)::bigint FROM base WHERE days_until BETWEEN 0 AND 60)  AS renewals_due_t60,
    (SELECT count(*)::bigint FROM base WHERE days_until BETWEEN 0 AND 30)  AS renewals_due_t30,
    (SELECT count(*)::bigint FROM base WHERE days_until < 0)               AS renewals_overdue,
    coalesce((SELECT sum(monthly_fee_rupees * 12) FROM due90), 0)::numeric AS expected_renewal_arr_rupees,
    30::numeric                                                            AS avg_renewal_lead_time_days,
    coalesce(v_highest_val, 0)::numeric                                    AS highest_value_renewal_due_rupees,
    coalesce(v_highest_name, '(none)')                                     AS highest_value_renewal_hospital_name,
    (SELECT count(*)::bigint FROM at_risk)                                 AS contracts_at_risk_due_t90,
    v_renewed_30d                                                          AS contracts_renewed_30d,
    v_churned_30d                                                          AS contracts_churned_30d,
    CASE WHEN (v_renewed_30d + v_churned_30d) = 0 THEN 0
         ELSE round(v_renewed_30d::numeric * 100 / (v_renewed_30d + v_churned_30d)::numeric, 1)
    END                                                                    AS net_renewal_pct,
    (SELECT count(*)::bigint FROM due90 WHERE amc_tier = 'enterprise')     AS enterprise_tier_due_t90,
    (SELECT count(*)::bigint FROM due90 WHERE amc_tier = 'growth')         AS growth_tier_due_t90,
    (SELECT count(*)::bigint FROM due90 WHERE amc_tier = 'starter')        AS starter_tier_due_t90;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_pipeline_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_pipeline_summary() TO authenticated;

-- ------------------------------------------------------------------
-- 2. Per-contract due rows
-- ------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_amc_renewal_pipeline_due(int, int);
CREATE OR REPLACE FUNCTION public.founder_amc_renewal_pipeline_due(
  p_window_days int DEFAULT 90,
  p_limit       int DEFAULT 100
)
RETURNS TABLE (
  contract_id                   uuid,
  hospital_org_id               uuid,
  hospital_name                 text,
  amc_tier                      text,
  monthly_fee_rupees            numeric,
  end_date                      date,
  days_until_renewal            int,
  last_visit_at                 timestamptz,
  has_open_codered              boolean,
  has_open_dispute              boolean,
  expected_renewal_value_rupees numeric,
  risk_band                     text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now    timestamptz := now();
  v_window int := greatest(coalesce(p_window_days, 90), 1);
  v_limit  int := greatest(coalesce(p_limit, 100), 1);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      c.id                                              AS contract_id,
      hp.organization_id                                AS hospital_org_id,
      coalesce(hp.full_name, '(unnamed)')               AS hospital_name,
      c.amc_tier                                        AS amc_tier,
      c.monthly_fee_rupees::numeric                     AS monthly_fee_rupees,
      c.end_date                                        AS end_date,
      (c.end_date - v_now::date)::int                   AS days_until_renewal,
      c.hospital_user_id
    FROM public.amc_contracts c
    LEFT JOIN public.profiles hp ON hp.id = c.hospital_user_id
    WHERE c.status = 'active'
      AND c.end_date IS NOT NULL
      AND c.end_date <= (v_now + (v_window || ' days')::interval)::date
  ),
  last_visit AS (
    SELECT rj.amc_contract_id, max(rj.created_at) AS last_visit_at
    FROM public.repair_jobs rj
    WHERE rj.amc_contract_id IS NOT NULL
    GROUP BY rj.amc_contract_id
  ),
  codered AS (
    SELECT DISTINCT b.contract_id
    FROM base b
    JOIN public.code_red_requests cr
      ON cr.hospital_user_id = b.hospital_user_id
    WHERE cr.created_at >= v_now - interval '30 days'
      AND cr.status NOT IN ('resolved','timed_out','cancelled')
  ),
  dispute AS (
    SELECT DISTINCT rj.amc_contract_id AS contract_id
    FROM public.repair_job_escrow e
    JOIN public.repair_jobs rj ON rj.id = e.repair_job_id
    WHERE e.status = 'in_dispute'
      AND rj.amc_contract_id IS NOT NULL
  )
  SELECT
    b.contract_id,
    b.hospital_org_id,
    b.hospital_name,
    b.amc_tier,
    b.monthly_fee_rupees,
    b.end_date,
    b.days_until_renewal,
    lv.last_visit_at,
    (cr.contract_id IS NOT NULL)                       AS has_open_codered,
    (dp.contract_id IS NOT NULL)                       AS has_open_dispute,
    (b.monthly_fee_rupees * 12)::numeric               AS expected_renewal_value_rupees,
    CASE
      WHEN b.days_until_renewal < 0                                   THEN 'critical'
      WHEN cr.contract_id IS NOT NULL AND b.days_until_renewal <= 30  THEN 'critical'
      WHEN dp.contract_id IS NOT NULL AND b.days_until_renewal <= 30  THEN 'high'
      WHEN b.days_until_renewal <= 30                                 THEN 'medium'
      WHEN b.days_until_renewal <= 90                                 THEN 'low'
      ELSE 'ok'
    END                                                AS risk_band
  FROM base b
  LEFT JOIN last_visit lv ON lv.amc_contract_id = b.contract_id
  LEFT JOIN codered    cr ON cr.contract_id    = b.contract_id
  LEFT JOIN dispute    dp ON dp.contract_id    = b.contract_id
  ORDER BY
    CASE
      WHEN b.days_until_renewal < 0                                   THEN 0
      WHEN cr.contract_id IS NOT NULL AND b.days_until_renewal <= 30  THEN 1
      WHEN dp.contract_id IS NOT NULL AND b.days_until_renewal <= 30  THEN 2
      WHEN b.days_until_renewal <= 30                                 THEN 3
      WHEN b.days_until_renewal <= 90                                 THEN 4
      ELSE 5
    END ASC,
    b.days_until_renewal ASC
  LIMIT v_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_renewal_pipeline_due(int, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_renewal_pipeline_due(int, int) TO authenticated;

COMMIT;