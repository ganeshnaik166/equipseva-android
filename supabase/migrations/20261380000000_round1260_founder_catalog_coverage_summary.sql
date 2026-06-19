BEGIN;

DROP FUNCTION IF EXISTS public.founder_catalog_coverage_summary();

CREATE OR REPLACE FUNCTION public.founder_catalog_coverage_summary()
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
      count(*)::bigint                                                                AS total_devices,
      count(*) FILTER (WHERE brand_id IS NOT NULL)::bigint                            AS devices_with_brand,
      count(*) FILTER (WHERE category_key IS NOT NULL)::bigint                        AS devices_with_category,
      count(*) FILTER (WHERE image_url IS NOT NULL AND image_url <> '')::bigint       AS devices_with_image,
      count(DISTINCT manufacturer) FILTER (WHERE manufacturer IS NOT NULL)::bigint    AS distinct_manufacturers
    FROM public.catalog_devices
  ),
  br AS (
    SELECT
      count(*)::bigint                                                                AS total_brands,
      count(*) FILTER (WHERE manufacturer_count > 0)::bigint                          AS active_brands
    FROM public.catalog_brands
  ),
  ref AS (
    SELECT
      count(*)::bigint                                                                AS total_ref_items,
      count(DISTINCT category)::bigint                                                AS distinct_ref_categories,
      count(DISTINCT brand) FILTER (WHERE brand IS NOT NULL)::bigint                  AS distinct_ref_brands,
      count(*) FILTER (WHERE price_inr_low IS NOT NULL AND price_inr_high IS NOT NULL)::bigint
                                                                                     AS ref_items_priced
    FROM public.catalog_reference_items
  ),
  tax AS (
    SELECT
      count(*)::bigint                                                                AS taxonomy_rows,
      count(*) FILTER (WHERE allowed_in_v04)::bigint                                  AS taxonomy_allowed_v04
    FROM public.equipment_taxonomy_class
  ),
  cats AS (
    SELECT
      count(*)::bigint                                                                AS active_categories
    FROM public.equipment_categories
    WHERE is_active = true
  )
  SELECT m, n, t FROM (
    VALUES
      ('total_devices',           (SELECT total_devices            FROM dev),  NULL::text),
      ('devices_with_brand',      (SELECT devices_with_brand       FROM dev),  NULL::text),
      ('devices_without_brand',   (SELECT total_devices - devices_with_brand FROM dev), NULL::text),
      ('devices_with_category',   (SELECT devices_with_category    FROM dev),  NULL::text),
      ('devices_without_category',(SELECT total_devices - devices_with_category FROM dev), NULL::text),
      ('devices_with_image',      (SELECT devices_with_image       FROM dev),  NULL::text),
      ('distinct_manufacturers',  (SELECT distinct_manufacturers   FROM dev),  NULL::text),
      ('total_brands',            (SELECT total_brands             FROM br),   NULL::text),
      ('active_brands',           (SELECT active_brands            FROM br),   NULL::text),
      ('total_ref_items',         (SELECT total_ref_items          FROM ref),  NULL::text),
      ('ref_items_priced',        (SELECT ref_items_priced         FROM ref),  NULL::text),
      ('distinct_ref_categories', (SELECT distinct_ref_categories  FROM ref),  NULL::text),
      ('distinct_ref_brands',     (SELECT distinct_ref_brands      FROM ref),  NULL::text),
      ('taxonomy_rows',           (SELECT taxonomy_rows            FROM tax),  NULL::text),
      ('taxonomy_allowed_v04',    (SELECT taxonomy_allowed_v04     FROM tax),  NULL::text),
      ('active_equipment_categories', (SELECT active_categories    FROM cats), NULL::text)
  ) AS v(m, n, t);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_catalog_coverage_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_catalog_coverage_summary() TO authenticated;

COMMIT;