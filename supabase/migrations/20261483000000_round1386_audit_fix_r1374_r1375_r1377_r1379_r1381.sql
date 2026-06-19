BEGIN;
-- r1386 — CRITICAL audit-fix sweep for r1374 / r1375 / r1377 / r1379 / r1381
-- (workflow w5uk5afs5). 7 confirmed CRITICAL bugs · 2 false positives (r1382).
--
-- 1. r1374: amc_contracts.amc_tier values are 'basic','bronze','silver','gold'
--    (FK to amc_subscription_tiers from r560), NOT 'starter'/'growth'/'enterprise'.
--    All FILTER clauses match zero rows → page shows all zeroes.
-- 2. r1375: engineers.cached_highest_tier holds KYC tiers (pro/bgc/gst/pan/
--    aadhaar) from r503, NOT job-count tiers (bronze/silver/gold/platinum).
--    The CASE statement comparing against bronze/silver/gold never matches →
--    jobs_to_next_tier_estimate always returns 0.
-- 3. r1377: amc_contracts.hospital_org_id DOES NOT EXIST. Real column is
--    hospital_user_id (FK auth.users). Bridge via profiles.organization_id.
-- 4. r1379: founder_ma_activity_log has happened_at NOT created_at + deal_priority
--    values are 'p0_critical','p1_high','medium','p3_low' NOT 'critical'/'high'.
-- 5. r1381: founder_skill_coverage.importance DEFAULT 'medium' violates the
--    CHECK ('p0','p1','p2','p3'). Every INSERT would 23514-abort.

-- ============================================================================
-- 1. r1374 — fix amc_tier values throughout founder_pricing_tier_mix
-- ============================================================================
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
    -- r1386 FIX: map starter=basic, growth=bronze+silver, enterprise=gold
    SELECT
      count(*) FILTER (WHERE amc_tier = 'basic')::bigint AS starter_n,
      count(*) FILTER (WHERE amc_tier IN ('bronze','silver'))::bigint AS growth_n,
      count(*) FILTER (WHERE amc_tier = 'gold')::bigint AS enterprise_n,
      coalesce(sum(monthly_fee_rupees) FILTER (WHERE amc_tier = 'basic'), 0)::numeric AS starter_mrr,
      coalesce(sum(monthly_fee_rupees) FILTER (WHERE amc_tier IN ('bronze','silver')), 0)::numeric AS growth_mrr,
      coalesce(sum(monthly_fee_rupees) FILTER (WHERE amc_tier = 'gold'), 0)::numeric AS enterprise_mrr,
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
      count(*) FILTER (WHERE c.amc_tier = 'basic' AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start))::int AS starter_n,
      count(*) FILTER (WHERE c.amc_tier IN ('bronze','silver') AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start))::int AS growth_n,
      count(*) FILTER (WHERE c.amc_tier = 'gold' AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start))::int AS enterprise_n,
      coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start)), 0)::numeric AS total_mrr,
      coalesce(sum(c.monthly_fee_rupees) FILTER (WHERE c.amc_tier = 'gold' AND c.start_date < (m.m_start + interval '1 month')::date AND (c.end_date IS NULL OR c.end_date >= m.m_start)), 0)::numeric AS enterprise_mrr
    FROM months m
    LEFT JOIN public.amc_contracts c ON true
    GROUP BY m.m_start
  )
  SELECT pm.m_start, pm.starter_n, pm.growth_n, pm.enterprise_n, pm.total_mrr,
    CASE WHEN pm.total_mrr > 0 THEN round((pm.enterprise_mrr / pm.total_mrr) * 100, 2) ELSE 0 END
  FROM per_month pm ORDER BY pm.m_start;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_pricing_tier_mix_history(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_pricing_tier_mix_history(int) TO authenticated;

-- ============================================================================
-- 2. r1375 — derive tier from jobs_count (cached_highest_tier is KYC not job)
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_tier_progression_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_tier_progression_summary()
RETURNS TABLE (
  total_engineers_active      bigint,
  bronze_count                bigint,
  silver_count                bigint,
  gold_count                  bigint,
  platinum_count              bigint,
  top_tier_engineer_user_id   uuid,
  top_tier_engineer_jobs_count int,
  median_completed_jobs_per_engineer numeric,
  total_completed_jobs_lifetime bigint,
  generated_at                timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH eng_jobs AS (
    SELECT e.user_id, coalesce(jc.cnt, 0)::int AS jobs_count,
           -- r1386 FIX: derive job-count tier instead of using KYC tier
           CASE
             WHEN coalesce(jc.cnt, 0) >= 500 THEN 'platinum'
             WHEN coalesce(jc.cnt, 0) >= 200 THEN 'gold'
             WHEN coalesce(jc.cnt, 0) >= 50  THEN 'silver'
             ELSE 'bronze'
           END AS tier
    FROM public.engineers e
    LEFT JOIN (
      SELECT engineer_id, count(*) AS cnt FROM public.repair_jobs
      WHERE status = 'completed' GROUP BY engineer_id
    ) jc ON jc.engineer_id = e.id
    WHERE e.verification_status::text = 'verified'
  )
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE tier = 'bronze')::bigint,
    count(*) FILTER (WHERE tier = 'silver')::bigint,
    count(*) FILTER (WHERE tier = 'gold')::bigint,
    count(*) FILTER (WHERE tier = 'platinum')::bigint,
    (SELECT user_id FROM eng_jobs ORDER BY jobs_count DESC LIMIT 1),
    (SELECT jobs_count FROM eng_jobs ORDER BY jobs_count DESC LIMIT 1),
    coalesce(percentile_cont(0.5) WITHIN GROUP (ORDER BY jobs_count), 0)::numeric,
    coalesce(sum(jobs_count), 0)::bigint,
    now()
  FROM eng_jobs;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_tier_progression_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_tier_progression_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_engineer_tier_progression_climbers(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_tier_progression_climbers(p_limit int DEFAULT 30)
RETURNS TABLE (
  engineer_user_id      uuid,
  current_tier          text,
  jobs_completed_total  int,
  last_completed_at     timestamptz,
  jobs_to_next_tier_estimate int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH eng_data AS (
    SELECT
      e.user_id,
      coalesce(jc.cnt, 0)::int AS jobs_count,
      jc.last_at,
      -- r1386 FIX: derive tier from jobs_count
      CASE
        WHEN coalesce(jc.cnt, 0) >= 500 THEN 'platinum'
        WHEN coalesce(jc.cnt, 0) >= 200 THEN 'gold'
        WHEN coalesce(jc.cnt, 0) >= 50  THEN 'silver'
        ELSE 'bronze'
      END AS tier
    FROM public.engineers e
    LEFT JOIN (
      SELECT engineer_id, count(*) AS cnt, max(completed_at) AS last_at
      FROM public.repair_jobs WHERE status = 'completed'
      GROUP BY engineer_id
    ) jc ON jc.engineer_id = e.id
    WHERE e.verification_status::text = 'verified'
  )
  SELECT
    ed.user_id, ed.tier, ed.jobs_count, ed.last_at,
    CASE
      WHEN ed.tier = 'bronze' THEN greatest(0, 50 - ed.jobs_count)
      WHEN ed.tier = 'silver' THEN greatest(0, 200 - ed.jobs_count)
      WHEN ed.tier = 'gold'   THEN greatest(0, 500 - ed.jobs_count)
      ELSE 0
    END
  FROM eng_data ed
  WHERE ed.tier <> 'platinum'
  ORDER BY ed.jobs_count DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 30), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_tier_progression_climbers(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_engineer_tier_progression_climbers(int) TO authenticated;

-- ============================================================================
-- 3. r1377 — amc_contracts.hospital_org_id doesn't exist; bridge via profiles
-- ============================================================================
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
    -- r1386 FIX: bridge hospital_user_id → profiles.organization_id for org_id
    SELECT DISTINCT
      p.organization_id AS hospital_org_id,
      c.amc_tier, c.monthly_fee_rupees, c.end_date
    FROM public.amc_contracts c
    JOIN public.profiles p ON p.id = c.hospital_user_id
    WHERE c.status = 'active' AND p.organization_id IS NOT NULL
  ),
  hosp_jobs AS (
    SELECT
      a.hospital_org_id, a.amc_tier, a.monthly_fee_rupees, a.end_date,
      coalesce(o.name, '(unnamed)') AS hospital_name,
      coalesce((SELECT count(*)::int FROM public.repair_jobs rj
                WHERE rj.hospital_org_id = a.hospital_org_id
                  AND rj.completed_at >= now() - interval '90 days'), 0) AS jobs_90d
    FROM active_amcs a
    LEFT JOIN public.organizations o ON o.id = a.hospital_org_id
  )
  SELECT
    count(*)::bigint,
    count(*) FILTER (WHERE jobs_90d >= 10)::bigint,
    count(*) FILTER (WHERE jobs_90d BETWEEN 3 AND 9)::bigint,
    count(*) FILTER (WHERE jobs_90d BETWEEN 1 AND 2)::bigint,
    count(*) FILTER (WHERE jobs_90d = 0)::bigint,
    coalesce((SELECT jobs_90d FROM hosp_jobs ORDER BY jobs_90d DESC LIMIT 1), 0)::int,
    coalesce((SELECT hospital_name FROM hosp_jobs ORDER BY jobs_90d DESC LIMIT 1), '(none)')::text,
    coalesce(avg(jobs_90d), 0)::numeric,
    coalesce(avg(jobs_90d * coalesce(monthly_fee_rupees, 0) / 30.0), 0)::numeric,
    -- r1386 FIX: use canonical amc_tier values
    count(*) FILTER (WHERE amc_tier = 'gold')::bigint,
    count(*) FILTER (WHERE amc_tier = 'basic')::bigint,
    count(*) FILTER (WHERE jobs_90d >= 20 AND amc_tier = 'gold')::bigint,
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
    SELECT DISTINCT
      p.organization_id AS hospital_org_id,
      c.amc_tier, c.monthly_fee_rupees
    FROM public.amc_contracts c
    JOIN public.profiles p ON p.id = c.hospital_user_id
    WHERE c.status = 'active' AND p.organization_id IS NOT NULL
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
      FROM public.repair_jobs WHERE completed_at >= now() - interval '90 days'
      GROUP BY hospital_org_id
    ) jc ON jc.hospital_org_id = a.hospital_org_id
  )
  SELECT
    p.hospital_org_id, p.hospital_name, p.amc_tier, p.monthly_fee_rupees,
    p.jobs_90d, round(p.spend_90d_rupees, 2)::numeric, p.last_job_at,
    CASE WHEN p.jobs_90d >= 10 THEN 'high'
         WHEN p.jobs_90d >= 3  THEN 'medium'
         WHEN p.jobs_90d >= 1  THEN 'low'
         ELSE 'dormant' END,
    CASE WHEN p.monthly_fee_rupees >= 10000 THEN 'high_value'
         WHEN p.monthly_fee_rupees >= 3000  THEN 'medium_value'
         ELSE 'low_value' END,
    (
      CASE WHEN p.jobs_90d >= 10 THEN 'h' WHEN p.jobs_90d >= 3 THEN 'm' WHEN p.jobs_90d >= 1 THEN 'l' ELSE 'd' END
      || '_' ||
      CASE WHEN p.monthly_fee_rupees >= 10000 THEN 'h' WHEN p.monthly_fee_rupees >= 3000 THEN 'm' ELSE 'l' END
    )
  FROM per_hosp p
  ORDER BY p.spend_90d_rupees DESC NULLS LAST, p.jobs_90d DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_segmentation_by_segment(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_hospital_segmentation_by_segment(int) TO authenticated;

-- ============================================================================
-- 4. r1379 — founder_ma_activity_log uses happened_at + deal_priority enum fix
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_ma_pipeline_home_summary();
CREATE OR REPLACE FUNCTION public.founder_ma_pipeline_home_summary()
RETURNS TABLE (
  total_targets bigint,
  active_pipeline_count bigint,
  closed_deals_count bigint,
  passed_deals_count bigint,
  conversion_pct_to_closed numeric,
  total_estimated_acquisition_rupees numeric,
  total_closed_value_rupees numeric,
  active_pipeline_value_rupees numeric,
  avg_target_revenue_rupees numeric,
  most_active_segment text,
  most_active_segment_count bigint,
  activities_last_30d_count bigint,
  newest_target_at timestamptz,
  generated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint; v_active bigint; v_closed bigint; v_passed bigint;
  v_conv numeric; v_total_est numeric; v_total_closed numeric; v_active_val numeric;
  v_avg_rev numeric; v_top_seg text; v_top_seg_n bigint;
  v_act_30d bigint; v_newest timestamptz;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  SELECT count(*), count(*) FILTER (WHERE deal_status NOT IN ('passed','closed')),
         count(*) FILTER (WHERE deal_status = 'closed'),
         count(*) FILTER (WHERE deal_status = 'passed')
  INTO v_total, v_active, v_closed, v_passed FROM public.founder_ma_targets;

  IF (v_closed + v_passed) > 0 THEN
    v_conv := round(v_closed::numeric * 100 / (v_closed + v_passed)::numeric, 2);
  ELSE v_conv := 0; END IF;

  SELECT coalesce(sum(estimated_acquisition_rupees), 0),
         coalesce(sum(estimated_acquisition_rupees) FILTER (WHERE deal_status = 'closed'), 0),
         coalesce(sum(estimated_acquisition_rupees) FILTER (WHERE deal_status NOT IN ('passed','closed')), 0),
         CASE WHEN count(*) FILTER (WHERE target_revenue_rupees_annual IS NOT NULL) > 0
              THEN round(sum(target_revenue_rupees_annual) FILTER (WHERE target_revenue_rupees_annual IS NOT NULL)
                         / count(*) FILTER (WHERE target_revenue_rupees_annual IS NOT NULL)::numeric, 0)
              ELSE 0 END,
         max(created_at)
  INTO v_total_est, v_total_closed, v_active_val, v_avg_rev, v_newest
  FROM public.founder_ma_targets;

  SELECT industry_segment, cnt INTO v_top_seg, v_top_seg_n
  FROM (
    SELECT industry_segment, count(*) AS cnt
    FROM public.founder_ma_targets WHERE industry_segment IS NOT NULL
    GROUP BY industry_segment ORDER BY cnt DESC NULLS LAST, industry_segment ASC LIMIT 1
  ) seg;

  -- r1386 FIX: founder_ma_activity_log.happened_at (NOT created_at)
  SELECT count(*) INTO v_act_30d
  FROM public.founder_ma_activity_log
  WHERE happened_at >= now() - interval '30 days';

  RETURN QUERY SELECT
    coalesce(v_total, 0), coalesce(v_active, 0), coalesce(v_closed, 0), coalesce(v_passed, 0),
    coalesce(v_conv, 0), coalesce(v_total_est, 0), coalesce(v_total_closed, 0), coalesce(v_active_val, 0),
    coalesce(v_avg_rev, 0), coalesce(v_top_seg, '(none)'), coalesce(v_top_seg_n, 0),
    coalesce(v_act_30d, 0), v_newest, now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_ma_pipeline_home_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ma_pipeline_home_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_ma_pipeline_home_top_targets(int);
CREATE OR REPLACE FUNCTION public.founder_ma_pipeline_home_top_targets(p_limit int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  target_company_name text,
  industry_segment text,
  deal_status text,
  deal_priority text,
  estimated_acquisition_rupees numeric,
  last_activity_at timestamptz,
  days_since_activity int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH last_act AS (
    -- r1386 FIX: happened_at not created_at
    SELECT target_id, max(happened_at) AS last_at
    FROM public.founder_ma_activity_log GROUP BY target_id
  )
  SELECT t.id, t.target_company_name, t.industry_segment,
         t.deal_status, t.deal_priority,
         coalesce(t.estimated_acquisition_rupees, 0),
         la.last_at,
         CASE WHEN la.last_at IS NULL THEN NULL
              ELSE extract(day FROM (now() - la.last_at))::int END
  FROM public.founder_ma_targets t
  LEFT JOIN last_act la ON la.target_id = t.id
  WHERE t.deal_status NOT IN ('passed','closed')
  ORDER BY
    -- r1386 FIX: deal_priority values are 'p0_critical','p1_high','medium','p3_low'
    CASE t.deal_priority
      WHEN 'p0_critical' THEN 1
      WHEN 'p1_high'     THEN 2
      WHEN 'medium'      THEN 3
      WHEN 'p3_low'      THEN 4
      ELSE 5
    END ASC,
    coalesce(t.estimated_acquisition_rupees, 0) DESC,
    t.created_at DESC
  LIMIT greatest(coalesce(p_limit, 30), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_ma_pipeline_home_top_targets(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_ma_pipeline_home_top_targets(int) TO authenticated;

-- ============================================================================
-- 5. r1381 — fix importance DEFAULT 'medium' violating CHECK ('p0','p1','p2','p3')
-- ============================================================================
ALTER TABLE public.founder_skill_coverage
  ALTER COLUMN importance SET DEFAULT 'p2';
-- Also update any rows that somehow got 'medium' (shouldn't be possible since
-- CHECK would have rejected, but safe to clean up)
UPDATE public.founder_skill_coverage SET importance = 'p2' WHERE importance NOT IN ('p0','p1','p2','p3');

COMMIT;
