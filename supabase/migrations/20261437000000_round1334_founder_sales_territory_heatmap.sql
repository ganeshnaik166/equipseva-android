BEGIN;

-- =====================================================================
-- r1334 — Founder sales territory heatmap
-- Pure read aggregator. NO new tables.
-- Three RPCs:
--   founder_sales_territory_heatmap_summary()  -> 12 KPIs
--   founder_sales_territory_by_pincode(int)    -> top-N pincodes (90d)
--   founder_sales_territory_by_city(int)       -> top-N cities (90d)
-- Source: repair_jobs (90d window) JOIN organizations on hospital_org_id
-- organizations: city + state + pincode (pincode added r449)
-- engineers density via engineers.city/state/pincode
-- amc_contracts active via hospital_user_id -> profiles -> organizations
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. SUMMARY — 12 KPIs
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_sales_territory_heatmap_summary();
CREATE OR REPLACE FUNCTION public.founder_sales_territory_heatmap_summary()
RETURNS TABLE (
  total_active_cities           bigint,
  total_active_pincodes         bigint,
  top_city                      text,
  top_city_jobs_90d             bigint,
  top_pincode                   text,
  top_pincode_jobs_90d          bigint,
  cities_with_zero_jobs_30d     bigint,
  total_engineers_active        bigint,
  engineers_per_active_city_avg numeric,
  demand_signal_strong_count    bigint,
  demand_signal_weak_count      bigint,
  generated_at                  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_top_city          text;
  v_top_city_jobs     bigint;
  v_top_pincode       text;
  v_top_pincode_jobs  bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(nullif(trim(o.city), ''), '(unknown)'), count(rj.id)::bigint
    INTO v_top_city, v_top_city_jobs
  FROM public.repair_jobs rj
  JOIN public.organizations o ON o.id = rj.hospital_org_id
  WHERE rj.created_at >= now() - interval '90 days'
  GROUP BY coalesce(nullif(trim(o.city), ''), '(unknown)')
  ORDER BY count(rj.id) DESC NULLS LAST
  LIMIT 1;

  SELECT coalesce(nullif(trim(o.pincode), ''), '(unknown)'), count(rj.id)::bigint
    INTO v_top_pincode, v_top_pincode_jobs
  FROM public.repair_jobs rj
  JOIN public.organizations o ON o.id = rj.hospital_org_id
  WHERE rj.created_at >= now() - interval '90 days'
    AND o.pincode IS NOT NULL
    AND trim(o.pincode) <> ''
  GROUP BY coalesce(nullif(trim(o.pincode), ''), '(unknown)')
  ORDER BY count(rj.id) DESC NULLS LAST
  LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(DISTINCT coalesce(nullif(trim(o.city), ''), '(unknown)'))::bigint
              FROM public.repair_jobs rj
              JOIN public.organizations o ON o.id = rj.hospital_org_id
              WHERE rj.created_at >= now() - interval '90 days'), 0) AS total_active_cities,
    coalesce((SELECT count(DISTINCT coalesce(nullif(trim(o.pincode), ''), '(unknown)'))::bigint
              FROM public.repair_jobs rj
              JOIN public.organizations o ON o.id = rj.hospital_org_id
              WHERE rj.created_at >= now() - interval '90 days'
                AND o.pincode IS NOT NULL
                AND trim(o.pincode) <> ''), 0) AS total_active_pincodes,
    coalesce(v_top_city, '(none)')::text                      AS top_city,
    coalesce(v_top_city_jobs, 0)::bigint                      AS top_city_jobs_90d,
    coalesce(v_top_pincode, '(none)')::text                   AS top_pincode,
    coalesce(v_top_pincode_jobs, 0)::bigint                   AS top_pincode_jobs_90d,
    coalesce((
      WITH city_jobs AS (
        SELECT coalesce(nullif(trim(o.city), ''), '(unknown)') AS city,
               count(*) FILTER (WHERE rj.created_at >= now() - interval '30 days')::bigint AS j30
        FROM public.repair_jobs rj
        JOIN public.organizations o ON o.id = rj.hospital_org_id
        WHERE rj.created_at >= now() - interval '90 days'
        GROUP BY coalesce(nullif(trim(o.city), ''), '(unknown)')
      )
      SELECT count(*)::bigint FROM city_jobs WHERE j30 = 0
    ), 0)                                                     AS cities_with_zero_jobs_30d,
    coalesce((SELECT count(*)::bigint
              FROM public.engineers e
              WHERE e.verification_status::text = 'verified'), 0) AS total_engineers_active,
    coalesce((
      WITH eng_by_city AS (
        SELECT coalesce(nullif(trim(e.city), ''), '(unknown)') AS city,
               count(*)::numeric                                AS engs
        FROM public.engineers e
        WHERE e.verification_status::text = 'verified'
        GROUP BY coalesce(nullif(trim(e.city), ''), '(unknown)')
      ),
      active_cities AS (
        SELECT DISTINCT coalesce(nullif(trim(o.city), ''), '(unknown)') AS city
        FROM public.repair_jobs rj
        JOIN public.organizations o ON o.id = rj.hospital_org_id
        WHERE rj.created_at >= now() - interval '90 days'
      )
      SELECT round(avg(coalesce(eng_by_city.engs, 0))::numeric, 2)
      FROM active_cities
      LEFT JOIN eng_by_city ON eng_by_city.city = active_cities.city
    ), 0)::numeric                                            AS engineers_per_active_city_avg,
    coalesce((
      WITH pin_jobs AS (
        SELECT coalesce(nullif(trim(o.pincode), ''), '(unknown)') AS pin,
               count(*)::bigint AS j
        FROM public.repair_jobs rj
        JOIN public.organizations o ON o.id = rj.hospital_org_id
        WHERE rj.created_at >= now() - interval '90 days'
          AND o.pincode IS NOT NULL AND trim(o.pincode) <> ''
        GROUP BY coalesce(nullif(trim(o.pincode), ''), '(unknown)')
      )
      SELECT count(*)::bigint FROM pin_jobs WHERE j >= 10
    ), 0)                                                     AS demand_signal_strong_count,
    coalesce((
      WITH pin_jobs AS (
        SELECT coalesce(nullif(trim(o.pincode), ''), '(unknown)') AS pin,
               count(*)::bigint AS j
        FROM public.repair_jobs rj
        JOIN public.organizations o ON o.id = rj.hospital_org_id
        WHERE rj.created_at >= now() - interval '90 days'
          AND o.pincode IS NOT NULL AND trim(o.pincode) <> ''
        GROUP BY coalesce(nullif(trim(o.pincode), ''), '(unknown)')
      )
      SELECT count(*)::bigint FROM pin_jobs WHERE j BETWEEN 1 AND 3
    ), 0)                                                     AS demand_signal_weak_count,
    now()::timestamptz                                        AS generated_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_sales_territory_heatmap_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_sales_territory_heatmap_summary() TO authenticated;

-- ---------------------------------------------------------------------
-- 2. BY PINCODE — top-100 (90d)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_sales_territory_by_pincode(int);
CREATE OR REPLACE FUNCTION public.founder_sales_territory_by_pincode(p_limit int DEFAULT 100)
RETURNS TABLE (
  pincode                  text,
  city                     text,
  state                    text,
  total_jobs_90d           bigint,
  unique_hospitals         bigint,
  engineers_assigned       bigint,
  amc_contracts_active     bigint,
  avg_minutes_to_response  numeric,
  demand_band              text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit int := GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH pin_agg AS (
    SELECT
      coalesce(nullif(trim(o.pincode), ''), '(unknown)') AS pincode,
      max(coalesce(nullif(trim(o.city), ''), ''))        AS city,
      max(coalesce(nullif(trim(o.state), ''), ''))       AS state,
      count(rj.id)::bigint                                AS total_jobs_90d,
      count(DISTINCT rj.hospital_org_id)::bigint          AS unique_hospitals,
      count(DISTINCT rj.engineer_id) FILTER (WHERE rj.engineer_id IS NOT NULL)::bigint
                                                          AS engineers_assigned,
      round(
        avg(EXTRACT(EPOCH FROM (rj.accepted_at - rj.created_at)) / 60.0)
        FILTER (WHERE rj.accepted_at IS NOT NULL AND rj.accepted_at > rj.created_at)
      ::numeric, 1)                                        AS avg_minutes_to_response
    FROM public.repair_jobs rj
    JOIN public.organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at >= now() - interval '90 days'
      AND o.pincode IS NOT NULL
      AND trim(o.pincode) <> ''
    GROUP BY coalesce(nullif(trim(o.pincode), ''), '(unknown)')
  ),
  amc_by_pin AS (
    SELECT coalesce(nullif(trim(o2.pincode), ''), '(unknown)') AS pincode,
           count(*) FILTER (WHERE c.status = 'active')::bigint AS amc_contracts_active
    FROM public.amc_contracts c
    JOIN public.profiles      p2 ON p2.id = c.hospital_user_id
    JOIN public.organizations o2 ON o2.id = p2.organization_id
    WHERE o2.pincode IS NOT NULL AND trim(o2.pincode) <> ''
    GROUP BY coalesce(nullif(trim(o2.pincode), ''), '(unknown)')
  )
  SELECT
    pin_agg.pincode,
    pin_agg.city,
    pin_agg.state,
    pin_agg.total_jobs_90d,
    pin_agg.unique_hospitals,
    pin_agg.engineers_assigned,
    coalesce(amc_by_pin.amc_contracts_active, 0)::bigint AS amc_contracts_active,
    coalesce(pin_agg.avg_minutes_to_response, 0)::numeric AS avg_minutes_to_response,
    CASE
      WHEN pin_agg.total_jobs_90d >= 10 THEN 'strong'
      WHEN pin_agg.total_jobs_90d >= 4  THEN 'medium'
      WHEN pin_agg.total_jobs_90d >= 1  THEN 'weak'
      ELSE 'zero'
    END::text AS demand_band
  FROM pin_agg
  LEFT JOIN amc_by_pin ON amc_by_pin.pincode = pin_agg.pincode
  ORDER BY pin_agg.total_jobs_90d DESC NULLS LAST
  LIMIT v_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_sales_territory_by_pincode(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_sales_territory_by_pincode(int) TO authenticated;

-- ---------------------------------------------------------------------
-- 3. BY CITY — top-50 (90d)
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.founder_sales_territory_by_city(int);
CREATE OR REPLACE FUNCTION public.founder_sales_territory_by_city(p_limit int DEFAULT 50)
RETURNS TABLE (
  city                     text,
  state                    text,
  total_jobs_90d           bigint,
  unique_hospitals         bigint,
  engineers_assigned       bigint,
  amc_contracts_active     bigint,
  avg_minutes_to_response  numeric,
  demand_band              text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_limit int := GREATEST(1, LEAST(COALESCE(p_limit, 50), 200));
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH city_agg AS (
    SELECT
      coalesce(nullif(trim(o.city), ''), '(unknown)')   AS city,
      max(coalesce(nullif(trim(o.state), ''), ''))      AS state,
      count(rj.id)::bigint                               AS total_jobs_90d,
      count(DISTINCT rj.hospital_org_id)::bigint         AS unique_hospitals,
      count(DISTINCT rj.engineer_id) FILTER (WHERE rj.engineer_id IS NOT NULL)::bigint
                                                         AS engineers_assigned,
      round(
        avg(EXTRACT(EPOCH FROM (rj.accepted_at - rj.created_at)) / 60.0)
        FILTER (WHERE rj.accepted_at IS NOT NULL AND rj.accepted_at > rj.created_at)
      ::numeric, 1)                                       AS avg_minutes_to_response
    FROM public.repair_jobs rj
    JOIN public.organizations o ON o.id = rj.hospital_org_id
    WHERE rj.created_at >= now() - interval '90 days'
    GROUP BY coalesce(nullif(trim(o.city), ''), '(unknown)')
  ),
  amc_by_city AS (
    SELECT coalesce(nullif(trim(o2.city), ''), '(unknown)') AS city,
           count(*) FILTER (WHERE c.status = 'active')::bigint AS amc_contracts_active
    FROM public.amc_contracts c
    JOIN public.profiles      p2 ON p2.id = c.hospital_user_id
    JOIN public.organizations o2 ON o2.id = p2.organization_id
    GROUP BY coalesce(nullif(trim(o2.city), ''), '(unknown)')
  )
  SELECT
    city_agg.city,
    city_agg.state,
    city_agg.total_jobs_90d,
    city_agg.unique_hospitals,
    city_agg.engineers_assigned,
    coalesce(amc_by_city.amc_contracts_active, 0)::bigint AS amc_contracts_active,
    coalesce(city_agg.avg_minutes_to_response, 0)::numeric AS avg_minutes_to_response,
    CASE
      WHEN city_agg.total_jobs_90d >= 30 THEN 'strong'
      WHEN city_agg.total_jobs_90d >= 10 THEN 'medium'
      WHEN city_agg.total_jobs_90d >= 1  THEN 'weak'
      ELSE 'zero'
    END::text AS demand_band
  FROM city_agg
  LEFT JOIN amc_by_city ON amc_by_city.city = city_agg.city
  ORDER BY city_agg.total_jobs_90d DESC NULLS LAST
  LIMIT v_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_sales_territory_by_city(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_sales_territory_by_city(int) TO authenticated;

COMMIT;