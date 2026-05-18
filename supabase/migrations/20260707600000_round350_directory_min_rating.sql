-- Round 350 — engineer directory: add p_min_rating filter.
-- Hospital had district + specialization + query filters but no way to
-- say "only show me 4-star-and-above engineers" without scrolling the
-- whole list and visually rejecting low-rated cards. Add a server-side
-- predicate so the UI chip can do a single round-trip.
--
-- Schema evolution: drop the round-311 9-arity signature and replace
-- with a 10-arity version where p_min_rating defaults to NULL (= no
-- filter). PostgREST routes calls without the new param to the same
-- function via parameter defaults, so this stays back-compatible for
-- any in-flight clients that haven't picked up the new repo helper.

DROP FUNCTION IF EXISTS public.engineers_directory_search(
  text, text, text, text, int, int, double precision, double precision, text
);

CREATE OR REPLACE FUNCTION public.engineers_directory_search(
  p_query text DEFAULT NULL,
  p_district text DEFAULT NULL,
  p_specialization text DEFAULT NULL,
  p_brand text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_hospital_lat double precision DEFAULT NULL,
  p_hospital_lng double precision DEFAULT NULL,
  p_sort_mode text DEFAULT 'rating',
  p_min_rating numeric DEFAULT NULL
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
    public.engineer_address_public(e.city),
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
    AND coalesce(p.role::text, '') = 'engineer'  -- round 311: block cross-role leaks
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
      OR p_specialization = ANY(coalesce(e.specializations::text[], ARRAY[]::text[]))
    )
    AND (
      p_brand IS NULL OR p_brand = ''
      OR p_brand = ANY(coalesce(e.brands_serviced, ARRAY[]::text[]))
    )
    -- Round 350 — rating threshold. NULL = no filter (back-compat).
    AND (
      p_min_rating IS NULL
      OR coalesce(e.rating_avg, 0)::numeric >= p_min_rating
    )
  ORDER BY
    CASE WHEN p_sort_mode = 'nearest' AND p_hospital_lat IS NOT NULL AND p_hospital_lng IS NOT NULL
      THEN
        CASE
          WHEN e.latitude IS NOT NULL AND e.longitude IS NOT NULL
          THEN public.haversine_km(p_hospital_lat, p_hospital_lng, e.latitude, e.longitude)
          ELSE NULL
        END
    END ASC NULLS LAST,
    CASE WHEN p_sort_mode = 'price_asc' THEN e.hourly_rate END ASC NULLS LAST,
    coalesce(e.rating_avg, 0) DESC,
    coalesce(e.total_jobs, 0) DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
  OFFSET greatest(0, coalesce(p_offset, 0));
$$;

GRANT EXECUTE ON FUNCTION public.engineers_directory_search(
  text, text, text, text, int, int, double precision, double precision, text, numeric
) TO authenticated, anon;
