-- v2.1 PR-A: hospital-side engineer directory gets distance + sort.
--
-- The original engineers_directory_search (20260427010000) joined
-- profiles + filtered to verified engineers but only sorted by
-- rating_avg DESC, total_jobs DESC. Hospitals had no way to find a
-- LOCAL engineer — distance was not even returned, let alone ranked.
-- The user's friend in Miryalaguda was driving 300km to Adilabad
-- because the Adilabad hospital had no easy way to discover local
-- verified engineers in the directory.
--
-- This drops + recreates the function with three additions:
--   1. p_hospital_lat / p_hospital_lng — optional caller coords
--   2. p_sort_mode — 'nearest' | 'rating' | 'price_asc'  (default 'rating')
--   3. distance_km in the return shape (NULL when caller gave no coords)
--
-- Backwards-compatible: callers that pass none of the new params keep
-- the rating-DESC behaviour they had before.
--
-- haversine_km() comes from 20260425073000_nearby_repair_jobs_rpc.sql,
-- already in prod. Reused here, no new helper.

DROP FUNCTION IF EXISTS public.engineers_directory_search(text, text, text, text, int, int);

CREATE OR REPLACE FUNCTION public.engineers_directory_search(
  p_query text DEFAULT NULL,
  p_district text DEFAULT NULL,
  p_specialization text DEFAULT NULL,
  p_brand text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_hospital_lat double precision DEFAULT NULL,
  p_hospital_lng double precision DEFAULT NULL,
  p_sort_mode text DEFAULT 'rating'
)
RETURNS TABLE (
  engineer_id uuid,
  user_id uuid,
  full_name text,
  avatar_url text,
  city text,
  state text,
  service_areas text[],
  specializations text[],
  brands_serviced text[],
  experience_years int,
  rating_avg numeric,
  total_jobs int,
  hourly_rate numeric,
  bio text,
  is_available boolean,
  distance_km double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    e.id,
    e.user_id,
    coalesce(p.full_name, '(unnamed)'),
    p.avatar_url,
    e.city,
    e.state,
    e.service_areas,
    e.specializations,
    e.brands_serviced,
    coalesce(e.experience_years, e.years_experience, 0),
    coalesce(e.rating_avg, 0)::numeric,
    coalesce(e.total_jobs, 0),
    e.hourly_rate,
    e.bio,
    coalesce(e.is_available, false),
    -- distance only when both caller coords + engineer base coords known
    CASE
      WHEN p_hospital_lat IS NOT NULL
        AND p_hospital_lng IS NOT NULL
        AND e.latitude IS NOT NULL
        AND e.longitude IS NOT NULL
      THEN public.haversine_km(p_hospital_lat, p_hospital_lng, e.latitude, e.longitude)
      ELSE NULL
    END AS distance_km
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE coalesce(e.verification_status::text, 'pending') = 'verified'
    AND (
      p_query IS NULL OR p_query = ''
      OR coalesce(p.full_name, '') ILIKE '%' || p_query || '%'
      OR coalesce(e.bio, '') ILIKE '%' || p_query || '%'
    )
    AND (
      p_district IS NULL OR p_district = ''
      OR p_district = ANY(coalesce(e.service_areas, ARRAY[]::text[]))
      OR e.city ILIKE p_district
    )
    AND (
      p_specialization IS NULL OR p_specialization = ''
      -- specializations is enum array (equipment_category[]), cast to
      -- text[] to compare against the text param. Original migration
      -- worked when the column was text[]; type tightened later.
      OR p_specialization = ANY(coalesce(e.specializations::text[], ARRAY[]::text[]))
    )
    AND (
      p_brand IS NULL OR p_brand = ''
      OR p_brand = ANY(coalesce(e.brands_serviced, ARRAY[]::text[]))
    )
  ORDER BY
    -- Nearest first when caller passed coords AND chose nearest sort.
    -- Engineers with NULL distance (missing coords) drop to the bottom
    -- via NULLS LAST so the directory still shows them.
    CASE WHEN p_sort_mode = 'nearest' AND p_hospital_lat IS NOT NULL AND p_hospital_lng IS NOT NULL
      THEN
        CASE
          WHEN e.latitude IS NOT NULL AND e.longitude IS NOT NULL
          THEN public.haversine_km(p_hospital_lat, p_hospital_lng, e.latitude, e.longitude)
          ELSE NULL
        END
    END ASC NULLS LAST,
    -- Price-asc: cheapest hourly_rate first; NULLs go last.
    CASE WHEN p_sort_mode = 'price_asc' THEN e.hourly_rate END ASC NULLS LAST,
    -- Default tiebreaker / fallback: rating then job count, matching
    -- the pre-PR-A behaviour exactly.
    coalesce(e.rating_avg, 0) DESC,
    coalesce(e.total_jobs, 0) DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
  OFFSET greatest(0, coalesce(p_offset, 0));
$$;
GRANT EXECUTE ON FUNCTION public.engineers_directory_search(
  text, text, text, text, int, int, double precision, double precision, text
) TO authenticated, anon;
