BEGIN;
-- r1374 — /founder-pricing-tier-mix — AMC tier mix snapshot + 12-month history.

DROP FUNCTION IF EXISTS public.founder_pricing_tier_mix_summary();
CREATE OR REPLACE FUNCTION public.founder_pricing_tier_mix_summary()
RETURNS TABLE (
  total_active_contracts  bigint,
  starter_count           bigint,
  growth_count            bigint,
  enterprise_count        bigint,
  starter_pct             numeric,
  growth_pct              numeric,
  enterprise_pct          numeric,
  starter_mrr_rupees      numeric,
  growth_mrr_rupees       numeric,
  enterprise_mrr_rupees   numeric,
  total_mrr_rupees        numeric,
  enterprise_mrr_pct      numeric,
  avg_revenue_per_contract_rupees numeric,
  generated_at            timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT count(*) INTO v_total FROM public.amc_contracts WHERE status = 'active';

  RETURN QUERY
  WITH agg AS (
    SELECT
      count(*) FILTER (WHERE amc_tier = 'starter')::bigint AS starter_n,
      count(*) FILTER (WHERE amc_tier = 'growth')::bigint AS growth_n,
      count(*) FILTER (WHERE amc_tier = 'enterprise')::bigint AS enterprise_n,
      coalesce(sum(monthly_fee_rupees) FILTER (WHERE amc_tier = 'starter'), 0)::numeric AS starter_mrr,
      coalesce(sum(monthly_fee_rupees) FILTER (WHERE amc_tier = 'growth'), 0)::numeric AS growth_mrr,
      coalesce(sum(monthly_fee_rupees) FILTER (WHERE amc_tier = 'enterprise'), 0)::numeric AS enterprise_mrr,
      coalesce(sum(monthly_fee_rupees), 0)::numeric AS total_mrr
    FROM public.amc_contracts WHERE status = 'active'
  )
  SELECT
    v_total,
    agg.starter_n, agg.growth_n, agg.enterprise_n,
    CASE WHEN v_total > 0 THEN round(agg.starter_n::numeric * 100 / v_total, 2) ELSE 0 END,
    CASE WHEN v_total > 0 THEN round(agg.growth_n::numeric * 100 / v_total, 2) ELSE 0 END,
    CASE WHEN v_total > 0 THEN round(agg.enterprise_n::numeric * 100 / v_total, 2) ELSE 0 END,
    agg.starter_mrr, agg.growth_mrr, agg.enterprise_mrr, agg.total_mrr,
    CASE WHEN agg.total_mrr > 0 THEN round((agg.enterprise_mrr / agg.total_mrr) * 100, 2) ELSE 0 END,
    CASE WHEN v_total > 0 THEN round(agg.total_mrr / v_total, 2) ELSE 0 END,
    now()
  FROM agg;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pricing_tier_mix_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pricing_tier_mix_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_pricing_tier_mix_history(int);
CREATE OR REPLACE FUNCTION public.founder_pricing_tier_mix_history(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start          date,
  starter_count        int,
  growth_count         int,
  enterprise_count     int,
  total_mrr_rupees     numeric,
  enterprise_mrr_pct   numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_months int := greatest(least(coalesce(p_months, 12), 24), 1);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  RETURN QUERY
  WITH months AS (
    SELECT date_trunc('month', generate_series(
      date_trunc('month', now()) - ((v_months - 1) || ' months')::interval,
      date_trunc('month', now()),
      interval '1 month'
    ))::date AS m_start
  ),
  per_month AS (
    SELECT
      m.m_start,
      count(*) FILTER (WHERE c.amc_tier = 'starter' AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start))::int AS starter_n,
      count(*) FILTER (WHERE c.amc_tier = 'growth' AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start))::int AS growth_n,
      count(*) FILTER (WHERE c.amc_tier = 'enterprise' AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start))::int AS enterprise_n,
      coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start)), 0)::numeric AS total_mrr,
      coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.amc_tier = 'enterprise' AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start)), 0)::numeric AS enterprise_mrr
    FROM months m
    LEFT JOIN public.amc_contracts c ON true
    GROUP BY m.m_start
  )
  SELECT
    pm.m_start, pm.starter_n, pm.growth_n, pm.enterprise_n, pm.total_mrr,
    CASE WHEN pm.total_mrr > 0 THEN round((pm.enterprise_mrr / pm.total_mrr) * 100, 2) ELSE 0 END
  FROM per_month pm
  ORDER BY pm.m_start;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pricing_tier_mix_history(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pricing_tier_mix_history(int) TO authenticated;

COMMIT;
