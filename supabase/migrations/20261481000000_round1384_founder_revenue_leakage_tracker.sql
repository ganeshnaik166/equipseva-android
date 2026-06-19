BEGIN;

-- ============================================================================
-- Round 1383 — /founder-revenue-leakage-tracker
-- Aggregator-only surface: refunds (payments) + SLA credits (amc_sla_breaches)
--   + escrow refunds (repair_job_escrow) — combined leakage view.
-- NO new tables.
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_revenue_leakage_summary();

CREATE OR REPLACE FUNCTION public.founder_revenue_leakage_summary()
RETURNS TABLE (
  total_refunds_lifetime_rupees numeric,
  refunds_30d_rupees numeric,
  refunds_90d_rupees numeric,
  total_sla_credits_lifetime_rupees numeric,
  sla_credits_30d_rupees numeric,
  escrow_refunds_lifetime_rupees numeric,
  escrow_refunds_30d_rupees numeric,
  total_leakage_lifetime_rupees numeric,
  total_leakage_30d_rupees numeric,
  leakage_pct_of_gmv_30d numeric,
  biggest_single_refund_rupees numeric,
  biggest_sla_credit_rupees numeric,
  count_of_credit_events_30d bigint,
  generated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_refunds_lifetime numeric;
  v_refunds_30d numeric;
  v_refunds_90d numeric;
  v_sla_lifetime numeric;
  v_sla_30d numeric;
  v_escrow_lifetime numeric;
  v_escrow_30d numeric;
  v_gmv_30d numeric;
  v_biggest_refund numeric;
  v_biggest_sla numeric;
  v_credit_events_30d bigint;
  v_leak_lifetime numeric;
  v_leak_30d numeric;
  v_leak_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  -- Lifetime refunds (payments table, status='refunded')
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_refunds_lifetime
    FROM public.payments
   WHERE status = 'refunded';

  -- 30d refunds
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_refunds_30d
    FROM public.payments
   WHERE status = 'refunded'
     AND created_at >= now() - interval '30 days';

  -- 90d refunds
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_refunds_90d
    FROM public.payments
   WHERE status = 'refunded'
     AND created_at >= now() - interval '90 days';

  -- Lifetime SLA credits issued
  SELECT COALESCE(SUM(credit_issued_rupees), 0)::numeric
    INTO v_sla_lifetime
    FROM public.amc_sla_breaches;

  -- 30d SLA credits
  SELECT COALESCE(SUM(credit_issued_rupees), 0)::numeric
    INTO v_sla_30d
    FROM public.amc_sla_breaches
   WHERE detected_at >= now() - interval '30 days';

  -- Lifetime escrow refunds (status='refunded')
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_escrow_lifetime
    FROM public.repair_job_escrow
   WHERE status = 'refunded';

  -- 30d escrow refunds (use refunded_at when present, else created)
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_escrow_30d
    FROM public.repair_job_escrow
   WHERE status = 'refunded'
     AND COALESCE(refunded_at, created_at) >= now() - interval '30 days';

  -- 30d GMV = captured payments
  SELECT COALESCE(SUM(amount_rupees), 0)::numeric
    INTO v_gmv_30d
    FROM public.payments
   WHERE status = 'captured'
     AND created_at >= now() - interval '30 days';

  -- Biggest single refund (lifetime)
  SELECT COALESCE(MAX(amount_rupees), 0)::numeric
    INTO v_biggest_refund
    FROM public.payments
   WHERE status = 'refunded';

  -- Biggest SLA credit (lifetime)
  SELECT COALESCE(MAX(credit_issued_rupees), 0)::numeric
    INTO v_biggest_sla
    FROM public.amc_sla_breaches;

  -- Count of credit events 30d (refunds + sla + escrow refunds)
  SELECT
    (SELECT COUNT(*) FROM public.payments
       WHERE status = 'refunded' AND created_at >= now() - interval '30 days')
    + (SELECT COUNT(*) FROM public.amc_sla_breaches
         WHERE detected_at >= now() - interval '30 days')
    + (SELECT COUNT(*) FROM public.repair_job_escrow
         WHERE status = 'refunded'
           AND COALESCE(refunded_at, created_at) >= now() - interval '30 days')
    INTO v_credit_events_30d;

  v_leak_lifetime := v_refunds_lifetime + v_sla_lifetime + v_escrow_lifetime;
  v_leak_30d := v_refunds_30d + v_sla_30d + v_escrow_30d;
  v_leak_pct := CASE
    WHEN v_gmv_30d > 0 THEN ROUND((v_leak_30d / v_gmv_30d) * 100, 2)
    ELSE 0
  END;

  RETURN QUERY SELECT
    v_refunds_lifetime,
    v_refunds_30d,
    v_refunds_90d,
    v_sla_lifetime,
    v_sla_30d,
    v_escrow_lifetime,
    v_escrow_30d,
    v_leak_lifetime,
    v_leak_30d,
    v_leak_pct,
    v_biggest_refund,
    v_biggest_sla,
    v_credit_events_30d,
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revenue_leakage_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revenue_leakage_summary() TO authenticated;


DROP FUNCTION IF EXISTS public.founder_revenue_leakage_history(int);

CREATE OR REPLACE FUNCTION public.founder_revenue_leakage_history(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start text,
  refunds_rupees numeric,
  sla_credits_rupees numeric,
  escrow_refunds_rupees numeric,
  total_leakage_rupees numeric,
  gmv_captured_rupees numeric,
  leakage_pct_of_gmv numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT generate_series(
      date_trunc('month', now()) - (COALESCE(p_months, 12) - 1) * interval '1 month',
      date_trunc('month', now()),
      interval '1 month'
    ) AS m
  ),
  refunds_m AS (
    SELECT date_trunc('month', created_at) AS m,
           COALESCE(SUM(amount_rupees), 0)::numeric AS amt
      FROM public.payments
     WHERE status = 'refunded'
     GROUP BY 1
  ),
  sla_m AS (
    SELECT date_trunc('month', detected_at) AS m,
           COALESCE(SUM(credit_issued_rupees), 0)::numeric AS amt
      FROM public.amc_sla_breaches
     GROUP BY 1
  ),
  escrow_m AS (
    SELECT date_trunc('month', COALESCE(refunded_at, created_at)) AS m,
           COALESCE(SUM(amount_rupees), 0)::numeric AS amt
      FROM public.repair_job_escrow
     WHERE status = 'refunded'
     GROUP BY 1
  ),
  gmv_m AS (
    SELECT date_trunc('month', created_at) AS m,
           COALESCE(SUM(amount_rupees), 0)::numeric AS amt
      FROM public.payments
     WHERE status = 'captured'
     GROUP BY 1
  )
  SELECT
    to_char(months.m, 'YYYY-MM') AS month_start,
    COALESCE(refunds_m.amt, 0)::numeric AS refunds_rupees,
    COALESCE(sla_m.amt, 0)::numeric AS sla_credits_rupees,
    COALESCE(escrow_m.amt, 0)::numeric AS escrow_refunds_rupees,
    (COALESCE(refunds_m.amt, 0) + COALESCE(sla_m.amt, 0) + COALESCE(escrow_m.amt, 0))::numeric AS total_leakage_rupees,
    COALESCE(gmv_m.amt, 0)::numeric AS gmv_captured_rupees,
    CASE
      WHEN COALESCE(gmv_m.amt, 0) > 0
      THEN ROUND(((COALESCE(refunds_m.amt, 0) + COALESCE(sla_m.amt, 0) + COALESCE(escrow_m.amt, 0)) / gmv_m.amt) * 100, 2)
      ELSE 0
    END::numeric AS leakage_pct_of_gmv
  FROM months
  LEFT JOIN refunds_m ON refunds_m.m = months.m
  LEFT JOIN sla_m ON sla_m.m = months.m
  LEFT JOIN escrow_m ON escrow_m.m = months.m
  LEFT JOIN gmv_m ON gmv_m.m = months.m
  ORDER BY months.m DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revenue_leakage_history(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_revenue_leakage_history(int) TO authenticated;

COMMIT;