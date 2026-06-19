BEGIN;
DROP FUNCTION IF EXISTS public.founder_equipment_category_snapshot_summary();
CREATE OR REPLACE FUNCTION public.founder_equipment_category_snapshot_summary()
RETURNS TABLE (
  categories_total              bigint,
  categories_active             bigint,
  categories_repair_scope       bigint,
  categories_spare_part_scope   bigint,
  categories_both_scope         bigint,
  taxonomy_in_scope_v04         bigint,
  taxonomy_out_of_scope_v04     bigint,
  jobs_distinct_types_90d       bigint,
  jobs_top_category             text,
  jobs_top_category_count_90d   bigint,
  jobs_unspecified_90d          bigint,
  amc_distinct_categories_active bigint,
  code_red_distinct_types_90d   bigint,
  spare_parts_distinct_cats_active bigint,
  categories_updated_30d        bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_top_cat        text;
  v_top_cat_count  bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  -- precompute top category by job volume (90d)
  SELECT coalesce(nullif(trim(j.equipment_type), ''), '(unspecified)')::text, count(*)::bigint
    INTO v_top_cat, v_top_cat_count
    FROM public.repair_jobs j
   WHERE j.created_at >= now() - interval '90 days'
   GROUP BY coalesce(nullif(trim(j.equipment_type), ''), '(unspecified)')
   ORDER BY count(*) DESC
   LIMIT 1;

  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.equipment_categories), 0),
    coalesce((SELECT count(*)::bigint FROM public.equipment_categories WHERE is_active = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.equipment_categories WHERE scope = 'repair' AND is_active = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.equipment_categories WHERE scope = 'spare_part' AND is_active = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.equipment_categories WHERE scope = 'both' AND is_active = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.equipment_taxonomy_class WHERE allowed_in_v04 = true), 0),
    coalesce((SELECT count(*)::bigint FROM public.equipment_taxonomy_class WHERE allowed_in_v04 = false), 0),
    coalesce((SELECT count(DISTINCT coalesce(nullif(trim(j.equipment_type), ''), '(unspecified)'))::bigint
              FROM public.repair_jobs j WHERE j.created_at >= now() - interval '90 days'), 0),
    coalesce(v_top_cat, '(none)')::text,
    coalesce(v_top_cat_count, 0)::bigint,
    coalesce((SELECT count(*)::bigint FROM public.repair_jobs j
               WHERE j.created_at >= now() - interval '90 days'
                 AND (j.equipment_type IS NULL OR length(trim(j.equipment_type)) = 0)), 0),
    coalesce((SELECT count(DISTINCT cat)::bigint FROM (
                SELECT unnest(c.equipment_categories) AS cat
                  FROM public.amc_contracts c
                 WHERE c.status IN ('active','paused')
                   AND c.equipment_categories IS NOT NULL
             ) ec WHERE cat IS NOT NULL AND length(trim(cat)) > 0), 0),
    coalesce((SELECT count(DISTINCT coalesce(nullif(trim(r.equipment_type), ''), '(unspecified)'))::bigint
              FROM public.code_red_requests r WHERE r.created_at >= now() - interval '90 days'), 0),
    coalesce((SELECT count(DISTINCT s.category)::bigint
              FROM public.spare_parts s WHERE s.is_active = true AND s.category IS NOT NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.equipment_categories WHERE updated_at >= now() - interval '30 days'), 0)
  ;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_equipment_category_snapshot_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_equipment_category_snapshot_summary() TO authenticated;
COMMIT;
