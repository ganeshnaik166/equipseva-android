BEGIN;
-- round1360 · /founder-customer-health-score
-- Composite hospital health score (0..100) computed from activity,
-- code-red volume, dispute volume, SLA breaches and NPS sentiment.
--
-- Two RPCs (no new tables):
--   • founder_customer_health_score_summary()            → 14 KPIs
--   • founder_customer_health_score_by_hospital(p_limit) → ranked list
--
-- Formula (clamped 0..100):
--   base = 100
--   - days_since_last_visit / 90 * 25   (cap 25 deduction)
--   - open_codered_count * 15           (cap 30)
--   - open_dispute_count * 10           (cap 20)
--   - sla_breach_count_180d * 5         (cap 25)
--   + nps_bonus (+10 promoter / -15 detractor / 0 passive/null)
--
-- Bands: healthy ≥ 80 · watch ≥ 60 · at_risk ≥ 30 · critical < 30
--
-- Joins:
--   amc_contracts  (active OR paused)  →  hospital_org_id
--   organizations                       →  name
--   repair_jobs                         →  latest completed_at per org
--   code_red_requests                   →  hospital_user_id  →  profiles.organization_id
--   repair_job_escrow                   →  in_dispute · joined via repair_jobs
--   amc_sla_breaches                    →  detected_at within 180d
--   founder_nps_responses               →  latest per hospital_org_id



-- ------------------------------------------------------------
-- summary RPC
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_customer_health_score_summary();

CREATE OR REPLACE FUNCTION public.founder_customer_health_score_summary()
RETURNS TABLE (
  total_active_hospitals       bigint,
  healthy_count                bigint,
  watch_count                  bigint,
  at_risk_count                bigint,
  critical_count               bigint,
  avg_health_score             numeric,
  top_health_hospital_name     text,
  top_health_score             numeric,
  lowest_health_hospital_name  text,
  lowest_health_score          numeric,
  hospitals_improved_30d       bigint,
  hospitals_declined_30d       bigint,
  nps_promoter_count           bigint,
  nps_detractor_count          bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH active_amc AS (
    SELECT DISTINCT ac.hospital_org_id
    FROM public.amc_contracts ac
    WHERE ac.status IN ('active','paused')
      AND ac.hospital_org_id IS NOT NULL
  ),
  last_visit AS (
    SELECT rj.hospital_org_id, max(rj.completed_at) AS last_visit_at
    FROM public.repair_jobs rj
    WHERE rj.completed_at IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  codered AS (
    SELECT p.organization_id AS hospital_org_id, count(*)::bigint AS open_codered
    FROM public.code_red_requests cr
    JOIN public.profiles p ON p.user_id = cr.hospital_user_id
    WHERE cr.status IN ('open','engineer_accepted')
      AND p.organization_id IS NOT NULL
    GROUP BY p.organization_id
  ),
  disputes AS (
    SELECT rj.hospital_org_id, count(*)::bigint AS open_disputes
    FROM public.repair_job_escrow rje
    JOIN public.repair_jobs rj ON rj.id = rje.repair_job_id
    WHERE rje.status = 'in_dispute'
      AND rj.hospital_org_id IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  sla AS (
    SELECT ac.hospital_org_id, count(*)::bigint AS breach_180d
    FROM public.amc_sla_breaches sb
    JOIN public.amc_contracts ac ON ac.id = sb.amc_contract_id
    WHERE sb.detected_at >= now() - interval '180 days'
      AND ac.hospital_org_id IS NOT NULL
    GROUP BY ac.hospital_org_id
  ),
  latest_nps AS (
    SELECT DISTINCT ON (n.hospital_org_id)
      n.hospital_org_id,
      n.score,
      n.category
    FROM public.founder_nps_responses n
    ORDER BY n.hospital_org_id, n.responded_at DESC
  ),
  scored AS (
    SELECT
      a.hospital_org_id,
      o.name AS hospital_name,
      coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999) AS dslv,
      coalesce(cr.open_codered, 0) AS open_cr,
      coalesce(d.open_disputes, 0) AS open_dp,
      coalesce(s.breach_180d, 0)   AS breaches,
      ln.category                  AS nps_cat,
      GREATEST(
        0::numeric,
        LEAST(
          100::numeric,
          100::numeric
          - LEAST(25::numeric,
                  (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
          - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
          - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
          - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
          + CASE ln.category
              WHEN 'promoter'  THEN 10::numeric
              WHEN 'detractor' THEN -15::numeric
              ELSE 0::numeric
            END
        )
      ) AS health_score
    FROM active_amc a
    JOIN public.organizations o ON o.id = a.hospital_org_id
    LEFT JOIN last_visit lv ON lv.hospital_org_id = a.hospital_org_id
    LEFT JOIN codered   cr ON cr.hospital_org_id = a.hospital_org_id
    LEFT JOIN disputes  d  ON d.hospital_org_id  = a.hospital_org_id
    LEFT JOIN sla       s  ON s.hospital_org_id  = a.hospital_org_id
    LEFT JOIN latest_nps ln ON ln.hospital_org_id = a.hospital_org_id
  ),
  top_h AS (
    SELECT hospital_name, health_score
    FROM scored
    ORDER BY health_score DESC NULLS LAST, hospital_name ASC
    LIMIT 1
  ),
  low_h AS (
    SELECT hospital_name, health_score
    FROM scored
    ORDER BY health_score ASC NULLS LAST, hospital_name ASC
    LIMIT 1
  )
  SELECT
    (SELECT count(*)::bigint FROM scored)                                                    AS total_active_hospitals,
    (SELECT count(*) FILTER (WHERE health_score >= 80)::bigint FROM scored)                  AS healthy_count,
    (SELECT count(*) FILTER (WHERE health_score >= 60 AND health_score < 80)::bigint FROM scored) AS watch_count,
    (SELECT count(*) FILTER (WHERE health_score >= 30 AND health_score < 60)::bigint FROM scored) AS at_risk_count,
    (SELECT count(*) FILTER (WHERE health_score < 30)::bigint FROM scored)                   AS critical_count,
    (SELECT coalesce(round(avg(health_score)::numeric, 1), 0) FROM scored)                   AS avg_health_score,
    (SELECT hospital_name FROM top_h)                                                        AS top_health_hospital_name,
    (SELECT round(health_score::numeric, 1) FROM top_h)                                      AS top_health_score,
    (SELECT hospital_name FROM low_h)                                                        AS lowest_health_hospital_name,
    (SELECT round(health_score::numeric, 1) FROM low_h)                                      AS lowest_health_score,
    0::bigint                                                                                AS hospitals_improved_30d,
    0::bigint                                                                                AS hospitals_declined_30d,
    (SELECT count(*) FILTER (WHERE nps_cat = 'promoter')::bigint  FROM scored)               AS nps_promoter_count,
    (SELECT count(*) FILTER (WHERE nps_cat = 'detractor')::bigint FROM scored)               AS nps_detractor_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_customer_health_score_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_customer_health_score_summary() TO authenticated;

-- ------------------------------------------------------------
-- ranked by hospital RPC
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_customer_health_score_by_hospital(int);

CREATE OR REPLACE FUNCTION public.founder_customer_health_score_by_hospital(p_limit int DEFAULT 100)
RETURNS TABLE (
  hospital_org_id          uuid,
  hospital_name            text,
  amc_tier                 text,
  monthly_fee_rupees       numeric,
  days_active              int,
  last_visit_at            timestamptz,
  days_since_last_visit    int,
  open_codered_count       int,
  open_dispute_count       int,
  sla_breach_count_180d    int,
  nps_latest_score         int,
  latest_nps_category      text,
  health_score             numeric,
  health_band              text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH primary_amc AS (
    SELECT DISTINCT ON (ac.hospital_org_id)
      ac.hospital_org_id,
      ac.amc_tier,
      ac.monthly_fee_rupees,
      ac.start_date,
      ac.activated_at
    FROM public.amc_contracts ac
    WHERE ac.status IN ('active','paused')
      AND ac.hospital_org_id IS NOT NULL
    ORDER BY ac.hospital_org_id, ac.activated_at DESC NULLS LAST, ac.start_date DESC NULLS LAST
  ),
  last_visit AS (
    SELECT rj.hospital_org_id, max(rj.completed_at) AS last_visit_at
    FROM public.repair_jobs rj
    WHERE rj.completed_at IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  codered AS (
    SELECT p.organization_id AS hospital_org_id, count(*)::int AS open_codered
    FROM public.code_red_requests cr
    JOIN public.profiles p ON p.user_id = cr.hospital_user_id
    WHERE cr.status IN ('open','engineer_accepted')
      AND p.organization_id IS NOT NULL
    GROUP BY p.organization_id
  ),
  disputes AS (
    SELECT rj.hospital_org_id, count(*)::int AS open_disputes
    FROM public.repair_job_escrow rje
    JOIN public.repair_jobs rj ON rj.id = rje.repair_job_id
    WHERE rje.status = 'in_dispute'
      AND rj.hospital_org_id IS NOT NULL
    GROUP BY rj.hospital_org_id
  ),
  sla AS (
    SELECT ac.hospital_org_id, count(*)::int AS breach_180d
    FROM public.amc_sla_breaches sb
    JOIN public.amc_contracts ac ON ac.id = sb.amc_contract_id
    WHERE sb.detected_at >= now() - interval '180 days'
      AND ac.hospital_org_id IS NOT NULL
    GROUP BY ac.hospital_org_id
  ),
  latest_nps AS (
    SELECT DISTINCT ON (n.hospital_org_id)
      n.hospital_org_id,
      n.score,
      n.category
    FROM public.founder_nps_responses n
    ORDER BY n.hospital_org_id, n.responded_at DESC
  )
  SELECT
    pa.hospital_org_id,
    o.name::text                                       AS hospital_name,
    pa.amc_tier::text                                  AS amc_tier,
    pa.monthly_fee_rupees::numeric                     AS monthly_fee_rupees,
    GREATEST(0, coalesce(
      extract(day FROM (now() - coalesce(pa.activated_at, pa.start_date::timestamptz)))::int,
      0
    ))                                                 AS days_active,
    lv.last_visit_at                                   AS last_visit_at,
    coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)
                                                       AS days_since_last_visit,
    coalesce(cr.open_codered, 0)::int                  AS open_codered_count,
    coalesce(d.open_disputes, 0)::int                  AS open_dispute_count,
    coalesce(s.breach_180d, 0)::int                    AS sla_breach_count_180d,
    ln.score                                           AS nps_latest_score,
    ln.category::text                                  AS latest_nps_category,
    round(
      GREATEST(
        0::numeric,
        LEAST(
          100::numeric,
          100::numeric
          - LEAST(25::numeric,
                  (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
          - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
          - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
          - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
          + CASE ln.category
              WHEN 'promoter'  THEN 10::numeric
              WHEN 'detractor' THEN -15::numeric
              ELSE 0::numeric
            END
        )
      )::numeric,
      1
    )                                                  AS health_score,
    CASE
      WHEN GREATEST(0::numeric, LEAST(100::numeric,
        100::numeric
        - LEAST(25::numeric, (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
        - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
        - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
        - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
        + CASE ln.category WHEN 'promoter' THEN 10::numeric WHEN 'detractor' THEN -15::numeric ELSE 0::numeric END
      )) >= 80 THEN 'healthy'
      WHEN GREATEST(0::numeric, LEAST(100::numeric,
        100::numeric
        - LEAST(25::numeric, (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
        - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
        - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
        - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
        + CASE ln.category WHEN 'promoter' THEN 10::numeric WHEN 'detractor' THEN -15::numeric ELSE 0::numeric END
      )) >= 60 THEN 'watch'
      WHEN GREATEST(0::numeric, LEAST(100::numeric,
        100::numeric
        - LEAST(25::numeric, (coalesce(extract(day FROM (now() - lv.last_visit_at))::int, 999)::numeric / 90::numeric) * 25::numeric)
        - LEAST(30::numeric, coalesce(cr.open_codered, 0)::numeric * 15::numeric)
        - LEAST(20::numeric, coalesce(d.open_disputes, 0)::numeric * 10::numeric)
        - LEAST(25::numeric, coalesce(s.breach_180d, 0)::numeric * 5::numeric)
        + CASE ln.category WHEN 'promoter' THEN 10::numeric WHEN 'detractor' THEN -15::numeric ELSE 0::numeric END
      )) >= 30 THEN 'at_risk'
      ELSE 'critical'
    END                                                AS health_band
  FROM primary_amc pa
  JOIN public.organizations o ON o.id = pa.hospital_org_id
  LEFT JOIN last_visit lv ON lv.hospital_org_id = pa.hospital_org_id
  LEFT JOIN codered   cr ON cr.hospital_org_id = pa.hospital_org_id
  LEFT JOIN disputes  d  ON d.hospital_org_id  = pa.hospital_org_id
  LEFT JOIN sla       s  ON s.hospital_org_id  = pa.hospital_org_id
  LEFT JOIN latest_nps ln ON ln.hospital_org_id = pa.hospital_org_id
  ORDER BY health_score ASC NULLS LAST, hospital_name ASC
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 100), 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_customer_health_score_by_hospital(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_customer_health_score_by_hospital(int) TO authenticated;

COMMIT;