BEGIN;
-- Round 1365 — /founder-fleet-equipment-inventory
-- Equipment under AMC by category + manufacturer (brand).
-- Source: repair_jobs.equipment_type (category) + equipment_brand (manufacturer)
-- joined to amc_contracts for the "under AMC" filter.
-- No new tables — we read the equipment fingerprint off existing repair_jobs rows.



DROP FUNCTION IF EXISTS public.founder_fleet_equipment_inventory_summary();
DROP FUNCTION IF EXISTS public.founder_fleet_equipment_inventory_by_category(int);
DROP FUNCTION IF EXISTS public.founder_fleet_equipment_inventory_top_units(int);

CREATE OR REPLACE FUNCTION public.founder_fleet_equipment_inventory_summary()
RETURNS TABLE (
  total_equipment_under_amc_estimate     bigint,
  total_unique_categories                bigint,
  total_unique_manufacturers             bigint,
  top_category                           text,
  top_category_count                     bigint,
  top_manufacturer                       text,
  top_manufacturer_count                 bigint,
  equipment_with_5plus_visits_180d       bigint,
  equipment_with_zero_visits_180d_estimate bigint,
  avg_visits_per_equipment_180d          numeric,
  equipment_categories_with_dental       bigint,
  equipment_categories_with_radiology    bigint,
  newest_equipment_seen_at               timestamptz,
  generated_at                           timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH amc_jobs AS (
    SELECT
      coalesce(nullif(trim(rj.equipment_type::text), ''), '(unknown)') AS cat,
      coalesce(nullif(trim(rj.equipment_brand), ''), '(unknown)')      AS mfr,
      coalesce(nullif(trim(rj.equipment_model), ''), '(unspec)')       AS model,
      coalesce(nullif(trim(rj.equipment_serial), ''), '(noserial)')    AS serial,
      rj.completed_at,
      rj.created_at
    FROM public.repair_jobs rj
    JOIN public.amc_contracts ac ON ac.id = rj.amc_contract_id
    WHERE rj.amc_contract_id IS NOT NULL
      AND rj.created_at >= now() - interval '365 days'
  ),
  fingerprints AS (
    SELECT
      cat, mfr, model, serial,
      count(*) FILTER (WHERE created_at >= now() - interval '180 days') AS visits_180d,
      max(created_at) AS last_seen
    FROM amc_jobs
    GROUP BY cat, mfr, model, serial
  ),
  cat_rank AS (
    SELECT cat, count(*)::bigint AS n
    FROM fingerprints GROUP BY cat ORDER BY count(*) DESC LIMIT 1
  ),
  mfr_rank AS (
    SELECT mfr, count(*)::bigint AS n
    FROM fingerprints GROUP BY mfr ORDER BY count(*) DESC LIMIT 1
  )
  SELECT
    (SELECT count(*)::bigint FROM fingerprints),
    (SELECT count(DISTINCT cat)::bigint FROM fingerprints),
    (SELECT count(DISTINCT mfr)::bigint FROM fingerprints),
    coalesce((SELECT cat FROM cat_rank), '(none)'),
    coalesce((SELECT n   FROM cat_rank), 0),
    coalesce((SELECT mfr FROM mfr_rank), '(none)'),
    coalesce((SELECT n   FROM mfr_rank), 0),
    (SELECT count(*)::bigint FROM fingerprints WHERE visits_180d >= 5),
    0::bigint,
    coalesce((SELECT round(avg(visits_180d)::numeric, 2) FROM fingerprints), 0)::numeric,
    (SELECT count(DISTINCT cat)::bigint FROM fingerprints WHERE lower(cat) LIKE '%dental%'),
    (SELECT count(DISTINCT cat)::bigint FROM fingerprints WHERE lower(cat) LIKE '%radio%' OR lower(cat) LIKE '%xray%' OR lower(cat) LIKE '%x-ray%'),
    (SELECT max(last_seen) FROM fingerprints),
    now();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fleet_equipment_inventory_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_fleet_equipment_inventory_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_fleet_equipment_inventory_by_category(p_limit int DEFAULT 30)
RETURNS TABLE (
  equipment_category text,
  unique_units       bigint,
  unique_manufacturers bigint,
  total_visits_365d  bigint,
  visits_180d        bigint,
  last_seen_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH amc_jobs AS (
    SELECT
      coalesce(nullif(trim(rj.equipment_type::text), ''), '(unknown)') AS cat,
      coalesce(nullif(trim(rj.equipment_brand), ''), '(unknown)')      AS mfr,
      coalesce(nullif(trim(rj.equipment_model), ''), '(unspec)')       AS model,
      coalesce(nullif(trim(rj.equipment_serial), ''), '(noserial)')    AS serial,
      rj.created_at
    FROM public.repair_jobs rj
    WHERE rj.amc_contract_id IS NOT NULL
      AND rj.created_at >= now() - interval '365 days'
  )
  SELECT
    cat,
    count(DISTINCT (mfr || '|' || model || '|' || serial))::bigint AS unique_units,
    count(DISTINCT mfr)::bigint                                    AS unique_manufacturers,
    count(*)::bigint                                                AS total_visits_365d,
    count(*) FILTER (WHERE created_at >= now() - interval '180 days')::bigint AS visits_180d,
    max(created_at)                                                 AS last_seen_at
  FROM amc_jobs
  GROUP BY cat
  ORDER BY unique_units DESC, total_visits_365d DESC
  LIMIT greatest(coalesce(p_limit, 30), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fleet_equipment_inventory_by_category(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_fleet_equipment_inventory_by_category(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_fleet_equipment_inventory_top_units(p_limit int DEFAULT 50)
RETURNS TABLE (
  equipment_category text,
  manufacturer       text,
  model              text,
  serial             text,
  visits_365d        bigint,
  visits_180d        bigint,
  last_seen_at       timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH amc_jobs AS (
    SELECT
      coalesce(nullif(trim(rj.equipment_type::text), ''), '(unknown)') AS cat,
      coalesce(nullif(trim(rj.equipment_brand), ''), '(unknown)')      AS mfr,
      coalesce(nullif(trim(rj.equipment_model), ''), '(unspec)')       AS model,
      coalesce(nullif(trim(rj.equipment_serial), ''), '(noserial)')    AS serial,
      rj.created_at
    FROM public.repair_jobs rj
    WHERE rj.amc_contract_id IS NOT NULL
      AND rj.created_at >= now() - interval '365 days'
  )
  SELECT
    cat, mfr, model, serial,
    count(*)::bigint AS visits_365d,
    count(*) FILTER (WHERE created_at >= now() - interval '180 days')::bigint AS visits_180d,
    max(created_at) AS last_seen_at
  FROM amc_jobs
  GROUP BY cat, mfr, model, serial
  ORDER BY visits_365d DESC, last_seen_at DESC
  LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_fleet_equipment_inventory_top_units(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_fleet_equipment_inventory_top_units(int) TO authenticated;

COMMIT;