BEGIN;

-- ============================================================================
-- r1404 · /founder-hospital-chains-deep-drilldown
-- Deep analytics aggregator over hospital_chains (r544 + r1321).
-- Pure read-only. 5 RPCs:
--   1. founder_hospital_chains_drilldown_summary()        — 18 KPIs
--   2. founder_hospital_chains_drilldown_by_chain(int)    — per-chain table
--   3. founder_hospital_chains_drilldown_concentration_risk()
--   4. founder_hospital_chains_drilldown_revenue_trend(int)
--   5. founder_hospital_chains_drilldown_funnel_velocity()
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_hospital_chains_drilldown_summary();
DROP FUNCTION IF EXISTS public.founder_hospital_chains_drilldown_by_chain(int);
DROP FUNCTION IF EXISTS public.founder_hospital_chains_drilldown_concentration_risk();
DROP FUNCTION IF EXISTS public.founder_hospital_chains_drilldown_revenue_trend(int);
DROP FUNCTION IF EXISTS public.founder_hospital_chains_drilldown_funnel_velocity();

-- ---------- 1. SUMMARY ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hospital_chains_drilldown_summary()
RETURNS TABLE (
  total_chains                          bigint,
  prospecting_count                     bigint,
  signed_count                          bigint,
  live_count                            bigint,
  churned_count                         bigint,
  total_hospitals_under_chains          bigint,
  total_engineers_serving_chains        bigint,
  total_amc_mrr_from_chains_rupees      numeric,
  top_chain_by_hospital_count           text,
  top_chain_name                        text,
  top_chain_hospital_count              bigint,
  avg_hospitals_per_chain               numeric,
  top_state_for_chains                  text,
  conversion_pct_prospecting_to_live    numeric,
  days_to_signed_median                 numeric,
  chain_revenue_concentration_top3_pct  numeric,
  chain_revenue_concentration_top10_pct numeric,
  generated_at                          timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total_chains       bigint;
  v_total_mrr          numeric;
  v_total_hospitals    bigint;
  v_total_engineers    bigint;
  v_top_chain_id       uuid;
  v_top_chain_name     text;
  v_top_chain_count    bigint;
  v_top_state          text;
  v_prospecting        bigint;
  v_live               bigint;
  v_conv_pct           numeric;
  v_median_days        numeric;
  v_top3_pct           numeric;
  v_top10_pct          numeric;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  SELECT count(*)::bigint INTO v_total_chains FROM public.hospital_chains;
  v_total_chains := coalesce(v_total_chains, 0);

  SELECT count(*)::bigint INTO v_prospecting
    FROM public.hospital_chains WHERE status = 'prospecting';
  v_prospecting := coalesce(v_prospecting, 0);

  SELECT count(*)::bigint INTO v_live
    FROM public.hospital_chains WHERE status = 'live';
  v_live := coalesce(v_live, 0);

  SELECT count(DISTINCT m.hospital_user_id)::bigint
    INTO v_total_hospitals
    FROM public.hospital_chain_memberships m;
  v_total_hospitals := coalesce(v_total_hospitals, 0);

  SELECT count(DISTINCT rj.engineer_id)::bigint
    INTO v_total_engineers
    FROM public.repair_jobs rj
    JOIN public.hospital_chain_memberships m
      ON m.hospital_user_id = rj.hospital_user_id
   WHERE rj.engineer_id IS NOT NULL
     AND rj.created_at >= now() - interval '90 days';
  v_total_engineers := coalesce(v_total_engineers, 0);

  SELECT coalesce(sum(a.monthly_fee_rupees), 0)::numeric
    INTO v_total_mrr
    FROM public.amc_contracts a
    JOIN public.hospital_chain_memberships m
      ON m.hospital_user_id = a.hospital_user_id
   WHERE a.status = 'active';

  SELECT c.id, c.name, cnt
    INTO v_top_chain_id, v_top_chain_name, v_top_chain_count
    FROM (
      SELECT m.chain_id, count(*)::bigint AS cnt
        FROM public.hospital_chain_memberships m
       GROUP BY m.chain_id
       ORDER BY cnt DESC
       LIMIT 1
    ) x
    JOIN public.hospital_chains c ON c.id = x.chain_id;

  SELECT o.state INTO v_top_state
    FROM public.hospital_chain_memberships m
    JOIN public.profiles p ON p.user_id = m.hospital_user_id
    JOIN public.organizations o ON o.id = p.organization_id
   WHERE o.state IS NOT NULL
   GROUP BY o.state
   ORDER BY count(*) DESC
   LIMIT 1;

  v_conv_pct := CASE WHEN v_prospecting + v_live = 0 THEN 0
    ELSE round(100.0 * v_live::numeric / (v_prospecting + v_live)::numeric, 1) END;

  SELECT percentile_cont(0.5) WITHIN GROUP (
    ORDER BY EXTRACT(epoch FROM (signed_at - created_at)) / 86400.0
  )::numeric
    INTO v_median_days
    FROM public.hospital_chains
   WHERE signed_at IS NOT NULL;
  v_median_days := coalesce(v_median_days, 0);

  WITH chain_mrr AS (
    SELECT m.chain_id, sum(a.monthly_fee_rupees)::numeric AS mrr
      FROM public.amc_contracts a
      JOIN public.hospital_chain_memberships m
        ON m.hospital_user_id = a.hospital_user_id
     WHERE a.status = 'active'
     GROUP BY m.chain_id
  ),
  ranked AS (
    SELECT mrr, row_number() OVER (ORDER BY mrr DESC) AS rn,
           sum(mrr) OVER () AS total
      FROM chain_mrr
  )
  SELECT
    CASE WHEN max(total) = 0 THEN 0
         ELSE round(100.0 * coalesce(sum(mrr) FILTER (WHERE rn <= 3), 0) / max(total), 1) END,
    CASE WHEN max(total) = 0 THEN 0
         ELSE round(100.0 * coalesce(sum(mrr) FILTER (WHERE rn <= 10), 0) / max(total), 1) END
    INTO v_top3_pct, v_top10_pct
    FROM ranked;

  RETURN QUERY SELECT
    v_total_chains,
    v_prospecting,
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains WHERE status = 'signed'), 0),
    v_live,
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains WHERE status = 'churned'), 0),
    v_total_hospitals,
    v_total_engineers,
    coalesce(v_total_mrr, 0),
    coalesce(v_top_chain_name, '—'),
    coalesce(v_top_chain_name, '—'),
    coalesce(v_top_chain_count, 0),
    CASE WHEN v_total_chains = 0 THEN 0
         ELSE round(v_total_hospitals::numeric / v_total_chains, 2) END,
    coalesce(v_top_state, '—'),
    v_conv_pct,
    v_median_days,
    coalesce(v_top3_pct, 0),
    coalesce(v_top10_pct, 0),
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_summary() TO authenticated;

-- ---------- 2. BY-CHAIN -----------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hospital_chains_drilldown_by_chain(p_limit int DEFAULT 30)
RETURNS TABLE (
  chain_id                 uuid,
  chain_name               text,
  status                   text,
  total_hospitals_onboarded bigint,
  total_active_amcs        bigint,
  total_mrr_rupees         numeric,
  last_activity_at         timestamptz,
  days_since_last_activity numeric,
  churn_risk_band          text,
  primary_state            text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH per_chain AS (
    SELECT
      c.id   AS chain_id,
      c.name AS chain_name,
      c.status,
      coalesce((SELECT count(*)::bigint FROM public.hospital_chain_memberships m
                 WHERE m.chain_id = c.id), 0) AS hospitals,
      coalesce((SELECT count(*)::bigint
                  FROM public.amc_contracts a
                  JOIN public.hospital_chain_memberships m
                    ON m.hospital_user_id = a.hospital_user_id
                 WHERE m.chain_id = c.id AND a.status = 'active'), 0) AS amcs,
      coalesce((SELECT sum(a.monthly_fee_rupees)::numeric
                  FROM public.amc_contracts a
                  JOIN public.hospital_chain_memberships m
                    ON m.hospital_user_id = a.hospital_user_id
                 WHERE m.chain_id = c.id AND a.status = 'active'), 0) AS mrr,
      (SELECT max(rj.created_at)
         FROM public.repair_jobs rj
         JOIN public.hospital_chain_memberships m
           ON m.hospital_user_id = rj.hospital_user_id
        WHERE m.chain_id = c.id) AS last_act,
      (SELECT o.state
         FROM public.hospital_chain_memberships m
         JOIN public.profiles p ON p.user_id = m.hospital_user_id
         JOIN public.organizations o ON o.id = p.organization_id
        WHERE m.chain_id = c.id AND o.state IS NOT NULL
        GROUP BY o.state
        ORDER BY count(*) DESC
        LIMIT 1) AS p_state
    FROM public.hospital_chains c
  )
  SELECT
    pc.chain_id,
    pc.chain_name,
    pc.status,
    pc.hospitals,
    pc.amcs,
    pc.mrr,
    pc.last_act,
    CASE WHEN pc.last_act IS NULL THEN NULL
         ELSE round(EXTRACT(epoch FROM (now() - pc.last_act)) / 86400.0, 1) END,
    CASE
      WHEN pc.status = 'churned' THEN 'high'
      WHEN pc.last_act IS NULL THEN 'high'
      WHEN pc.last_act < now() - interval '60 days' THEN 'high'
      WHEN pc.last_act < now() - interval '30 days' THEN 'medium'
      ELSE 'low'
    END,
    coalesce(pc.p_state, '—')
  FROM per_chain pc
  ORDER BY pc.mrr DESC NULLS LAST, pc.hospitals DESC
  LIMIT greatest(coalesce(p_limit, 30), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_by_chain(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_by_chain(int) TO authenticated;

-- ---------- 3. CONCENTRATION RISK -------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hospital_chains_drilldown_concentration_risk()
RETURNS TABLE (
  rank_pos       bigint,
  chain_id       uuid,
  chain_name     text,
  mrr_rupees     numeric,
  pct_of_total   numeric,
  cumulative_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH chain_mrr AS (
    SELECT
      c.id   AS chain_id,
      c.name AS chain_name,
      coalesce(sum(a.monthly_fee_rupees), 0)::numeric AS mrr
      FROM public.hospital_chains c
      LEFT JOIN public.hospital_chain_memberships m ON m.chain_id = c.id
      LEFT JOIN public.amc_contracts a
        ON a.hospital_user_id = m.hospital_user_id AND a.status = 'active'
     GROUP BY c.id, c.name
  ),
  ranked AS (
    SELECT cm.*,
           row_number() OVER (ORDER BY cm.mrr DESC) AS rn,
           sum(cm.mrr) OVER () AS total
      FROM chain_mrr cm
  )
  SELECT
    r.rn,
    r.chain_id,
    r.chain_name,
    r.mrr,
    CASE WHEN r.total = 0 THEN 0 ELSE round(100.0 * r.mrr / r.total, 2) END,
    CASE WHEN r.total = 0 THEN 0
         ELSE round(100.0 * sum(r.mrr) OVER (ORDER BY r.mrr DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / r.total, 2) END
  FROM ranked r
  WHERE r.rn <= 10
  ORDER BY r.rn;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_concentration_risk() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_concentration_risk() TO authenticated;

-- ---------- 4. REVENUE TREND ------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hospital_chains_drilldown_revenue_trend(p_months int DEFAULT 12)
RETURNS TABLE (
  month_start   date,
  mrr_rupees    numeric,
  paid_orders   bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_months int := greatest(coalesce(p_months, 12), 1);
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  WITH months AS (
    SELECT date_trunc('month', now())::date - (i || ' months')::interval AS ms
      FROM generate_series(0, v_months - 1) AS i
  ),
  paid AS (
    SELECT date_trunc('month', o.created_at)::date AS ms,
           sum(o.amount_rupees)::numeric AS amt,
           count(*)::bigint AS cnt
      FROM public.amc_payment_orders o
      JOIN public.amc_contracts a ON a.id = o.amc_contract_id
      JOIN public.hospital_chain_memberships m
        ON m.hospital_user_id = a.hospital_user_id
     WHERE o.status = 'paid'
       AND o.created_at >= date_trunc('month', now() - (v_months || ' months')::interval)
     GROUP BY 1
  )
  SELECT m.ms::date,
         coalesce(p.amt, 0),
         coalesce(p.cnt, 0)
    FROM months m
    LEFT JOIN paid p ON p.ms = m.ms::date
   ORDER BY m.ms ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_revenue_trend(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_revenue_trend(int) TO authenticated;

-- ---------- 5. FUNNEL VELOCITY ----------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_hospital_chains_drilldown_funnel_velocity()
RETURNS TABLE (
  stage           text,
  current_count   bigint,
  avg_days_in_stage numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT
    s.stage,
    coalesce((SELECT count(*)::bigint FROM public.hospital_chains
               WHERE status = s.stage), 0),
    coalesce((SELECT round(avg(EXTRACT(epoch FROM (now() - created_at)) / 86400.0)::numeric, 1)
                FROM public.hospital_chains
               WHERE status = s.stage), 0)
  FROM (VALUES
    ('prospecting'),
    ('negotiating'),
    ('signed'),
    ('onboarding'),
    ('live'),
    ('paused'),
    ('churned')
  ) AS s(stage);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_funnel_velocity() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_chains_drilldown_funnel_velocity() TO authenticated;

COMMIT;