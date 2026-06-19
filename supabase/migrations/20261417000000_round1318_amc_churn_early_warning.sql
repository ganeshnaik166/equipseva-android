BEGIN;

-- =============================================================================
-- r1318 — AMC churn early warning
-- Probabilistic per-contract churn score (0..1) with banded watchlist.
-- Weighted signal blend: visit recency, overdue visits, payment lateness,
-- SLA breaches, open disputes, code-red incidents (180d).
-- =============================================================================

DROP FUNCTION IF EXISTS public.founder_amc_churn_scores(int);
DROP FUNCTION IF EXISTS public.founder_amc_churn_summary();

CREATE OR REPLACE FUNCTION public.founder_amc_churn_scores(
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  contract_id              uuid,
  hospital_org_id          uuid,
  hospital_name            text,
  amc_tier                 text,
  monthly_fee_rupees       numeric,
  activated_at             timestamptz,
  days_active              int,
  last_repair_completed_at timestamptz,
  days_since_last_visit    int,
  overdue_visits_count     int,
  payment_overdue_days     int,
  sla_breaches_count       int,
  open_disputes_count      int,
  code_red_count_180d      int,
  churn_score              numeric,
  churn_band               text,
  primary_signal           text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      c.id                                AS contract_id,
      c.hospital_org_id                   AS hospital_org_id,
      COALESCE(o.name, 'Unknown')         AS hospital_name,
      c.amc_tier::text                    AS amc_tier,
      c.monthly_fee_rupees                AS monthly_fee_rupees,
      c.activated_at                      AS activated_at,
      GREATEST(0, EXTRACT(DAY FROM (now() - c.activated_at))::int) AS days_active
    FROM public.amc_contracts c
    LEFT JOIN public.organizations o ON o.id = c.hospital_org_id
    WHERE c.status = 'active'
  ),
  last_visit AS (
    SELECT
      rj.amc_contract_id                  AS contract_id,
      MAX(rj.completed_at)                AS last_repair_completed_at
    FROM public.repair_jobs rj
    WHERE rj.amc_contract_id IS NOT NULL
      AND rj.completed_at IS NOT NULL
    GROUP BY rj.amc_contract_id
  ),
  overdue_visits AS (
    SELECT
      sv.contract_id                      AS contract_id,
      COUNT(*)::int                       AS overdue_visits_count
    FROM public.amc_scheduled_visits sv
    WHERE sv.scheduled_at < now()
      AND sv.completed_at IS NULL
    GROUP BY sv.contract_id
  ),
  pay_overdue AS (
    SELECT
      p.contract_id                       AS contract_id,
      MAX(GREATEST(0, EXTRACT(DAY FROM (now() - p.due_date))::int)) AS payment_overdue_days
    FROM public.amc_payments p
    WHERE p.due_date < now()
      AND p.paid_at IS NULL
    GROUP BY p.contract_id
  ),
  sla AS (
    SELECT
      b.contract_id                       AS contract_id,
      COUNT(*)::int                       AS sla_breaches_count
    FROM public.amc_sla_breaches b
    GROUP BY b.contract_id
  ),
  disputes AS (
    SELECT
      d.contract_id                       AS contract_id,
      COUNT(*)::int                       AS open_disputes_count
    FROM public.amc_disputes d
    WHERE d.status IN ('open','in_review')
    GROUP BY d.contract_id
  ),
  code_red AS (
    SELECT
      rj.amc_contract_id                  AS contract_id,
      COUNT(*)::int                       AS code_red_count_180d
    FROM public.code_red_incidents cri
    JOIN public.repair_jobs rj ON rj.id = cri.repair_job_id
    WHERE cri.created_at >= now() - interval '180 days'
      AND rj.amc_contract_id IS NOT NULL
    GROUP BY rj.amc_contract_id
  ),
  joined AS (
    SELECT
      b.contract_id,
      b.hospital_org_id,
      b.hospital_name,
      b.amc_tier,
      b.monthly_fee_rupees,
      b.activated_at,
      b.days_active,
      lv.last_repair_completed_at,
      GREATEST(0, EXTRACT(DAY FROM (now() - COALESCE(lv.last_repair_completed_at, b.activated_at)))::int) AS days_since_last_visit,
      COALESCE(ov.overdue_visits_count, 0)  AS overdue_visits_count,
      COALESCE(po.payment_overdue_days, 0)  AS payment_overdue_days,
      COALESCE(sla.sla_breaches_count, 0)   AS sla_breaches_count,
      COALESCE(dis.open_disputes_count, 0)  AS open_disputes_count,
      COALESCE(cr.code_red_count_180d, 0)   AS code_red_count_180d
    FROM base b
    LEFT JOIN last_visit     lv  ON lv.contract_id  = b.contract_id
    LEFT JOIN overdue_visits ov  ON ov.contract_id  = b.contract_id
    LEFT JOIN pay_overdue    po  ON po.contract_id  = b.contract_id
    LEFT JOIN sla            sla ON sla.contract_id = b.contract_id
    LEFT JOIN disputes       dis ON dis.contract_id = b.contract_id
    LEFT JOIN code_red       cr  ON cr.contract_id  = b.contract_id
  ),
  scored AS (
    SELECT
      j.*,
      LEAST(1.0, GREATEST(0.0,
          LEAST(1.0, j.days_since_last_visit::numeric / 90.0) * 0.25
        + LEAST(1.0, j.overdue_visits_count::numeric / 3.0)   * 0.20
        + LEAST(1.0, j.payment_overdue_days::numeric / 30.0)  * 0.20
        + LEAST(1.0, j.sla_breaches_count::numeric / 5.0)     * 0.15
        + LEAST(1.0, j.open_disputes_count::numeric / 2.0)    * 0.10
        + LEAST(1.0, j.code_red_count_180d::numeric / 3.0)    * 0.10
      )) AS churn_score_raw
    FROM joined j
  )
  SELECT
    s.contract_id,
    s.hospital_org_id,
    s.hospital_name,
    s.amc_tier,
    s.monthly_fee_rupees,
    s.activated_at,
    s.days_active,
    s.last_repair_completed_at,
    s.days_since_last_visit,
    s.overdue_visits_count,
    s.payment_overdue_days,
    s.sla_breaches_count,
    s.open_disputes_count,
    s.code_red_count_180d,
    ROUND(s.churn_score_raw, 4) AS churn_score,
    CASE
      WHEN s.churn_score_raw >= 0.75 THEN 'critical'
      WHEN s.churn_score_raw >= 0.50 THEN 'high'
      WHEN s.churn_score_raw >= 0.25 THEN 'medium'
      ELSE 'low'
    END AS churn_band,
    CASE
      WHEN s.payment_overdue_days  >= 30 THEN 'payment overdue 30d+'
      WHEN s.overdue_visits_count  >= 2  THEN 'overdue visits backlog'
      WHEN s.days_since_last_visit >= 60 THEN 'no visit 60d+'
      WHEN s.sla_breaches_count    >= 2  THEN 'repeat SLA breaches'
      WHEN s.open_disputes_count   >= 1  THEN 'open dispute'
      WHEN s.code_red_count_180d   >= 1  THEN 'code-red 180d'
      WHEN s.payment_overdue_days  >  0  THEN 'payment overdue'
      WHEN s.overdue_visits_count  >  0  THEN 'overdue visit'
      WHEN s.days_since_last_visit >= 30 THEN 'visit gap 30d+'
      ELSE 'healthy'
    END AS primary_signal
  FROM scored s
  ORDER BY s.churn_score_raw DESC NULLS LAST, s.monthly_fee_rupees DESC NULLS LAST
  LIMIT GREATEST(1, COALESCE(p_limit, 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_churn_scores(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_churn_scores(int) TO authenticated;

-- =============================================================================
-- Summary RPC
-- =============================================================================

CREATE OR REPLACE FUNCTION public.founder_amc_churn_summary()
RETURNS TABLE (
  total_active_contracts             bigint,
  critical_band                      bigint,
  high_band                          bigint,
  medium_band                        bigint,
  low_band                           bigint,
  total_arr_at_risk_critical_rupees  numeric,
  total_arr_at_risk_high_rupees      numeric,
  median_churn_score                 numeric,
  contracts_with_overdue_visit       bigint,
  contracts_with_payment_overdue     bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH s AS (
    SELECT * FROM public.founder_amc_churn_scores(100000)
  )
  SELECT
    COUNT(*)::bigint                                                                        AS total_active_contracts,
    COUNT(*) FILTER (WHERE churn_band = 'critical')::bigint                                 AS critical_band,
    COUNT(*) FILTER (WHERE churn_band = 'high')::bigint                                     AS high_band,
    COUNT(*) FILTER (WHERE churn_band = 'medium')::bigint                                   AS medium_band,
    COUNT(*) FILTER (WHERE churn_band = 'low')::bigint                                      AS low_band,
    COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE churn_band = 'critical'), 0)::numeric AS total_arr_at_risk_critical_rupees,
    COALESCE(SUM(monthly_fee_rupees * 12) FILTER (WHERE churn_band = 'high'), 0)::numeric     AS total_arr_at_risk_high_rupees,
    COALESCE(ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY churn_score)::numeric, 4), 0) AS median_churn_score,
    COUNT(*) FILTER (WHERE overdue_visits_count > 0)::bigint                                AS contracts_with_overdue_visit,
    COUNT(*) FILTER (WHERE payment_overdue_days > 0)::bigint                                AS contracts_with_payment_overdue
  FROM s;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_churn_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_churn_summary() TO authenticated;

COMMIT;