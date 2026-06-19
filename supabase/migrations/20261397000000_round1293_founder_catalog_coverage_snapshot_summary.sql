BEGIN;

DROP FUNCTION IF EXISTS public.founder_catalog_coverage_snapshot_summary();

CREATE OR REPLACE FUNCTION public.founder_catalog_coverage_snapshot_summary()
RETURNS TABLE (
  metric text,
  value_num bigint,
  value_text text
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
  WITH dev AS (
    SELECT
      count(*)::bigint                                                                          AS total_devices,
      count(*) FILTER (WHERE image_url IS NULL OR image_url = '')::bigint                       AS devices_missing_image,
      count(*) FILTER (WHERE description IS NULL OR description = '')::bigint                   AS devices_missing_description,
      count(*) FILTER (WHERE ingested_at >= now() - interval '7 days')::bigint                  AS devices_ingested_last_7d,
      count(*) FILTER (WHERE ingested_at >= now() - interval '30 days')::bigint                 AS devices_ingested_last_30d,
      max(ingested_at)                                                                          AS devices_newest_at,
      min(ingested_at)                                                                          AS devices_oldest_at
    FROM public.catalog_devices
  ),
  br AS (
    SELECT
      count(*)::bigint                                                                          AS total_brands,
      count(*) FILTER (WHERE logo_url IS NULL OR logo_url = '')::bigint                         AS brands_missing_logo,
      count(*) FILTER (WHERE country IS NULL OR country = '')::bigint                           AS brands_missing_country,
      count(*) FILTER (WHERE ingested_at >= now() - interval '30 days')::bigint                 AS brands_ingested_last_30d,
      max(ingested_at)                                                                          AS brands_newest_at
    FROM public.catalog_brands
  ),
  ref AS (
    SELECT
      count(*)::bigint                                                                          AS total_ref_items,
      count(*) FILTER (WHERE key_specifications IS NULL OR key_specifications = '')::bigint     AS ref_missing_specs,
      count(*) FILTER (WHERE brand IS NULL OR brand = '')::bigint                               AS ref_missing_brand,
      count(*) FILTER (WHERE model IS NULL OR model = '')::bigint                               AS ref_missing_model,
      count(*) FILTER (WHERE price_inr_low IS NULL OR price_inr_high IS NULL)::bigint           AS ref_missing_price,
      max(created_at)                                                                           AS ref_newest_at
    FROM public.catalog_reference_items
  )
  SELECT m, n, t FROM (
    VALUES
      ('total_devices',              (SELECT total_devices               FROM dev), NULL::text),
      ('devices_missing_image',      (SELECT devices_missing_image       FROM dev), NULL::text),
      ('devices_missing_description',(SELECT devices_missing_description FROM dev), NULL::text),
      ('devices_ingested_last_7d',   (SELECT devices_ingested_last_7d    FROM dev), NULL::text),
      ('devices_ingested_last_30d',  (SELECT devices_ingested_last_30d   FROM dev), NULL::text),
      ('devices_newest_at',          NULL::bigint, (SELECT to_char(devices_newest_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') FROM dev)),
      ('devices_oldest_at',          NULL::bigint, (SELECT to_char(devices_oldest_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') FROM dev)),
      ('total_brands',               (SELECT total_brands                FROM br),  NULL::text),
      ('brands_missing_logo',        (SELECT brands_missing_logo         FROM br),  NULL::text),
      ('brands_missing_country',     (SELECT brands_missing_country      FROM br),  NULL::text),
      ('brands_ingested_last_30d',   (SELECT brands_ingested_last_30d    FROM br),  NULL::text),
      ('brands_newest_at',           NULL::bigint, (SELECT to_char(brands_newest_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD HH24:MI') FROM br)),
      ('total_ref_items',            (SELECT total_ref_items             FROM ref), NULL::text),
      ('ref_missing_specs',          (SELECT ref_missing_specs           FROM ref), NULL::text),
      ('ref_missing_brand',          (SELECT ref_missing_brand           FROM ref), NULL::text),
      ('ref_missing_model',          (SELECT ref_missing_model           FROM ref), NULL::text),
      ('ref_missing_price',          (SELECT ref_missing_price           FROM ref), NULL::text)
  ) AS v(m, n, t);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_catalog_coverage_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_catalog_coverage_snapshot_summary() TO authenticated;

COMMIT;
