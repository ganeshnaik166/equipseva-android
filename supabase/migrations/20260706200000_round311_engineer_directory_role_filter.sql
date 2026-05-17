-- Round 311 — engineer-directory leak: hospital_admin / manufacturer
-- rows with a stale engineers entry surface in the directory.
--
-- Live example found 2026-05-17 on prod: profile "Test Hospital2"
-- (role=hospital_admin) had a verified engineers row and appeared
-- in the hospital booking flow alongside real engineers.
--
-- engineers.verification_status='verified' isn't enough on its own —
-- the engineers row was likely seeded back when role wasn't gated, or
-- a user's role was flipped server-side after onboarding. Add a
-- defense-in-depth role filter to the three public-facing RPCs so
-- only profiles.role='engineer' rows surface.
--
-- Also unverify the existing cross-role engineers rows so they drop
-- out of the UI immediately (otherwise app caches would keep showing
-- them until the next pull).

-- ---------------------------------------------------------------
-- 1. Soft-fix the 3 cross-role engineer rows (today's prod state).
-- ---------------------------------------------------------------
UPDATE public.engineers e
   SET verification_status = 'pending'
  FROM public.profiles p
 WHERE e.user_id = p.id
   AND coalesce(p.role::text, '') <> 'engineer'
   AND coalesce(e.verification_status::text, 'pending') = 'verified';

-- ---------------------------------------------------------------
-- 2. engineers_directory_search — add role filter.
-- ---------------------------------------------------------------
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
  text, text, text, text, int, int, double precision, double precision, text
) TO authenticated, anon;

-- ---------------------------------------------------------------
-- 3. recommended_engineers_for_hospital — add role filter.
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recommended_engineers_for_hospital(
  p_hospital_lat double precision,
  p_hospital_lng double precision,
  p_equipment_category text DEFAULT NULL,
  p_limit int DEFAULT 5
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
  distance_km double precision,
  match_score numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH base AS (
    SELECT
      e.id                                                AS engineer_id,
      e.user_id                                           AS user_id,
      coalesce(p.full_name, '(unnamed)')                  AS full_name,
      p.avatar_url                                        AS avatar_url,
      e.city                                              AS city,
      e.state                                             AS state,
      e.service_areas                                     AS service_areas,
      e.specializations::text[]                           AS specializations,
      e.brands_serviced                                   AS brands_serviced,
      coalesce(e.experience_years, e.years_experience, 0) AS experience_years,
      coalesce(e.rating_avg, 0)::numeric                  AS rating_avg,
      coalesce(e.total_jobs, 0)                           AS total_jobs,
      e.hourly_rate                                       AS hourly_rate,
      e.bio                                               AS bio,
      coalesce(e.is_available, false)                     AS is_available,
      CASE
        WHEN e.latitude IS NOT NULL AND e.longitude IS NOT NULL
        THEN public.haversine_km(p_hospital_lat, p_hospital_lng, e.latitude, e.longitude)
        ELSE NULL
      END                                                 AS distance_km,
      coalesce(e.completion_rate, 0)::numeric             AS completion_rate
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    WHERE coalesce(e.verification_status::text, 'pending') = 'verified'
      AND coalesce(p.role::text, '') = 'engineer'  -- round 311: block cross-role leaks
  )
  SELECT
    b.engineer_id,
    b.user_id,
    b.full_name,
    b.avatar_url,
    b.city,
    b.state,
    b.service_areas,
    b.specializations,
    b.brands_serviced,
    b.experience_years,
    b.rating_avg,
    b.total_jobs,
    b.hourly_rate,
    b.bio,
    b.is_available,
    b.distance_km,
    (
      30.0 * coalesce(
        1.0 - (LEAST(b.distance_km, 200.0) / 200.0),
        0.0
      )
      + 25.0 * (b.rating_avg / 5.0)
      + 20.0 * (
        CASE
          WHEN p_equipment_category IS NULL OR p_equipment_category = ''
            THEN 0.5
          WHEN p_equipment_category = ANY(coalesce(b.specializations, ARRAY[]::text[]))
            THEN 1.0
          ELSE 0.0
        END
      )
      + 15.0 * (b.completion_rate / 100.0)
      + 10.0 * (LEAST(b.total_jobs, 5)::numeric / 5.0)
    )::numeric AS match_score
  FROM base b
  ORDER BY match_score DESC,
           b.distance_km ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 5), 20));
$$;

GRANT EXECUTE ON FUNCTION public.recommended_engineers_for_hospital(
  double precision, double precision, text, int
) TO authenticated, anon;

-- ---------------------------------------------------------------
-- 4. engineer_public_profile — add role filter on the lookup.
-- ---------------------------------------------------------------
-- Same cross-role leak risk via direct UUID lookup. Body verbatim
-- from 20260626190000 (coord-fuzz version), with role added to the
-- initial existence check AND the final SELECT.
CREATE OR REPLACE FUNCTION public.engineer_public_profile(p_engineer_id uuid)
 RETURNS TABLE (
   engineer_id uuid,
   user_id uuid,
   full_name text,
   avatar_url text,
   phone text,
   email text,
   city text,
   state text,
   service_areas text[],
   specializations text[],
   brands_serviced text[],
   oem_training_badges text[],
   experience_years integer,
   rating_avg numeric,
   total_jobs integer,
   completion_rate numeric,
   hourly_rate numeric,
   bio text,
   is_available boolean,
   base_latitude double precision,
   base_longitude double precision,
   service_radius_km integer
 )
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_engineer_user_id uuid;
  v_can_see_contacts boolean;
  v_can_see_full_address boolean;
  v_can_see_exact_coords boolean;
BEGIN
  SELECT e.user_id INTO v_engineer_user_id
    FROM public.engineers e
    JOIN public.profiles p ON p.id = e.user_id  -- round 311: role gate
    WHERE e.id = p_engineer_id
      AND coalesce(e.verification_status::text, 'pending') = 'verified'
      AND coalesce(p.role::text, '') = 'engineer';

  IF v_engineer_user_id IS NULL THEN
    RETURN;
  END IF;

  v_can_see_contacts :=
    v_caller = v_engineer_user_id
    OR public.is_admin(v_caller)
    OR public.is_founder()
    OR EXISTS (
      SELECT 1 FROM public.repair_jobs rj
        WHERE rj.engineer_id = p_engineer_id
          AND rj.hospital_user_id = v_caller
    )
    OR EXISTS (
      SELECT 1 FROM public.chat_conversations cc
        WHERE v_caller = ANY(cc.participant_user_ids)
          AND v_engineer_user_id = ANY(cc.participant_user_ids)
    );

  v_can_see_full_address :=
    v_caller = v_engineer_user_id
    OR public.is_admin(v_caller)
    OR public.is_founder();

  v_can_see_exact_coords :=
    v_caller = v_engineer_user_id
    OR public.is_admin(v_caller)
    OR public.is_founder();

  RETURN QUERY
  SELECT
    e.id,
    e.user_id,
    coalesce(p.full_name, '(unnamed)'),
    p.avatar_url,
    CASE WHEN v_can_see_contacts THEN p.phone ELSE NULL END,
    CASE WHEN v_can_see_contacts THEN p.email ELSE NULL END,
    CASE WHEN v_can_see_full_address THEN e.city
         ELSE public.engineer_address_public(e.city) END,
    e.state,
    e.service_areas::text[],
    e.specializations::text[],
    e.brands_serviced::text[],
    e.oem_training_badges::text[],
    coalesce(e.experience_years, e.years_experience, 0),
    coalesce(e.rating_avg, 0)::numeric,
    coalesce(e.total_jobs, 0),
    coalesce(e.completion_rate, 0)::numeric,
    e.hourly_rate,
    e.bio,
    coalesce(e.is_available, false),
    CASE
      WHEN v_can_see_exact_coords OR e.latitude IS NULL THEN e.latitude
      ELSE e.latitude + (
        (('x' || substr(md5(e.id::text || ':lat'), 1, 4))::bit(16)::int % 200 - 100)
          / 10000.0
      )
    END,
    CASE
      WHEN v_can_see_exact_coords OR e.longitude IS NULL THEN e.longitude
      ELSE e.longitude + (
        (('x' || substr(md5(e.id::text || ':lng'), 1, 4))::bit(16)::int % 200 - 100)
          / 10000.0
      )
    END,
    e.service_radius_km
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.id = p_engineer_id
    AND coalesce(e.verification_status::text, 'pending') = 'verified'
    AND coalesce(p.role::text, '') = 'engineer';  -- round 311: role gate
END;
$function$;

GRANT EXECUTE ON FUNCTION public.engineer_public_profile(uuid) TO authenticated, anon;
