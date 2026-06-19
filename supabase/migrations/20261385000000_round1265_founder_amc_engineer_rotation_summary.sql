BEGIN;

DROP FUNCTION IF EXISTS public.founder_amc_engineer_rotation_summary();

CREATE OR REPLACE FUNCTION public.founder_amc_engineer_rotation_summary()
RETURNS TABLE (
  total_active_contracts bigint,
  contracts_with_rotation bigint,
  contracts_no_fallback bigint,
  contracts_solo_primary_only bigint,
  total_rotation_seats bigint,
  active_rotation_seats bigint,
  inactive_rotation_seats bigint,
  distinct_engineers_rostered bigint,
  avg_rotation_depth numeric,
  max_rotation_depth int,
  median_rotation_depth numeric,
  engineers_overloaded_5plus bigint,
  engineers_in_single_contract bigint,
  unverified_engineers_in_rotation bigint,
  unavailable_engineers_in_rotation bigint,
  rotation_seats_added_7d bigint,
  rotation_seats_added_30d bigint,
  contracts_primary_unverified bigint,
  contracts_primary_unavailable bigint,
  top_loaded_engineer_id uuid,
  top_loaded_engineer_name text,
  top_loaded_active_contract_count bigint
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
  WITH active_contracts AS (
    SELECT id, primary_engineer_id
      FROM public.amc_contracts
      WHERE status = 'active'
  ),
  rotation_active AS (
    SELECT r.amc_contract_id, r.engineer_id, r.priority, r.active, r.created_at
      FROM public.amc_engineer_rotation r
      JOIN active_contracts c ON c.id = r.amc_contract_id
  ),
  per_contract_depth AS (
    SELECT amc_contract_id, count(*) FILTER (WHERE active) AS depth
      FROM rotation_active
      GROUP BY amc_contract_id
  ),
  engineer_load AS (
    SELECT engineer_id, count(DISTINCT amc_contract_id) AS contract_count
      FROM rotation_active
      WHERE active = true
      GROUP BY engineer_id
  ),
  top_loaded AS (
    SELECT el.engineer_id, el.contract_count,
           coalesce(p.full_name, '(unnamed)') AS eng_name
      FROM engineer_load el
      JOIN public.engineers e ON e.id = el.engineer_id
      LEFT JOIN public.profiles p ON p.id = e.user_id
      ORDER BY el.contract_count DESC, el.engineer_id ASC
      LIMIT 1
  ),
  depth_arr AS (
    SELECT array_agg(depth ORDER BY depth) AS arr,
           count(*) AS n
      FROM per_contract_depth
  )
  SELECT
    (SELECT count(*) FROM active_contracts)::bigint AS total_active_contracts,
    (SELECT count(*) FROM per_contract_depth WHERE depth >= 1)::bigint AS contracts_with_rotation,
    (SELECT count(*) FROM active_contracts ac
       WHERE NOT EXISTS (
         SELECT 1 FROM rotation_active r
         WHERE r.amc_contract_id = ac.id AND r.active = true AND r.priority >= 2
       ))::bigint AS contracts_no_fallback,
    (SELECT count(*) FROM per_contract_depth WHERE depth = 1)::bigint AS contracts_solo_primary_only,
    (SELECT count(*) FROM rotation_active)::bigint AS total_rotation_seats,
    (SELECT count(*) FROM rotation_active WHERE active = true)::bigint AS active_rotation_seats,
    (SELECT count(*) FROM rotation_active WHERE active = false)::bigint AS inactive_rotation_seats,
    (SELECT count(DISTINCT engineer_id) FROM rotation_active WHERE active = true)::bigint AS distinct_engineers_rostered,
    coalesce((SELECT round(avg(depth)::numeric, 2) FROM per_contract_depth), 0)::numeric AS avg_rotation_depth,
    coalesce((SELECT max(depth) FROM per_contract_depth), 0)::int AS max_rotation_depth,
    coalesce(
      (SELECT
         CASE WHEN n = 0 THEN 0
              WHEN n % 2 = 1 THEN arr[(n/2)+1]::numeric
              ELSE ((arr[n/2] + arr[(n/2)+1])::numeric / 2.0)
         END
         FROM depth_arr), 0)::numeric AS median_rotation_depth,
    (SELECT count(*) FROM engineer_load WHERE contract_count >= 5)::bigint AS engineers_overloaded_5plus,
    (SELECT count(*) FROM engineer_load WHERE contract_count = 1)::bigint AS engineers_in_single_contract,
    (SELECT count(DISTINCT r.engineer_id)
       FROM rotation_active r
       JOIN public.engineers e ON e.id = r.engineer_id
       WHERE r.active = true
         AND e.verification_status::text <> 'verified')::bigint AS unverified_engineers_in_rotation,
    (SELECT count(DISTINCT r.engineer_id)
       FROM rotation_active r
       JOIN public.engineers e ON e.id = r.engineer_id
       WHERE r.active = true
         AND coalesce(e.is_available, false) = false)::bigint AS unavailable_engineers_in_rotation,
    (SELECT count(*) FROM rotation_active WHERE created_at >= now() - interval '7 days')::bigint AS rotation_seats_added_7d,
    (SELECT count(*) FROM rotation_active WHERE created_at >= now() - interval '30 days')::bigint AS rotation_seats_added_30d,
    (SELECT count(*) FROM active_contracts ac
       JOIN public.engineers e ON e.id = ac.primary_engineer_id
       WHERE e.verification_status::text <> 'verified')::bigint AS contracts_primary_unverified,
    (SELECT count(*) FROM active_contracts ac
       JOIN public.engineers e ON e.id = ac.primary_engineer_id
       WHERE coalesce(e.is_available, false) = false)::bigint AS contracts_primary_unavailable,
    (SELECT engineer_id FROM top_loaded) AS top_loaded_engineer_id,
    (SELECT eng_name FROM top_loaded) AS top_loaded_engineer_name,
    coalesce((SELECT contract_count FROM top_loaded), 0)::bigint AS top_loaded_active_contract_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_amc_engineer_rotation_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_amc_engineer_rotation_summary() TO authenticated;

COMMIT;
