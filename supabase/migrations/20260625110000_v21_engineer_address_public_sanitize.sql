-- v2.1 PR-D52 — close engineer-address PII leak.
--
-- KYC v2 stuffed the engineer's full street address into engineers.city
-- (door# + colony + mandalam + state + PIN, see EngineerDto.kt comment).
-- engineer_public_profile + engineers_directory_search both return e.city
-- verbatim, so every hospital browsing the directory sees the engineer's
-- exact home address — verified on-device 2026-05-08 e2e QA on profile
-- "Repair1" (H.no: 5-153, Miryalaguda, Water Tank Thanda, ...).
--
-- That violates the v2.1 anti-disintermediation contract: a hospital
-- never needs the engineer's door#. They need the service area to
-- decide reachability; the engineer travels to the hospital, not the
-- other way around.
--
-- Fix: add a SQL helper that keeps only the last 2 comma-separated
-- segments (typically city + state/PIN) and apply it to both RPCs.
-- Self-views (engineer reading own profile, admins, founders) keep
-- the full address since they have a legitimate need.
--
-- Address strings already short (<=2 segments) pass through unchanged
-- so legacy rows that just stored "Hyderabad" or "Hyderabad, Telangana"
-- aren't degraded.

CREATE OR REPLACE FUNCTION public.engineer_address_public(addr text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_parts text[];
  v_len int;
BEGIN
  IF addr IS NULL OR btrim(addr) = '' THEN
    RETURN addr;
  END IF;
  v_parts := string_to_array(addr, ',');
  v_len := array_length(v_parts, 1);
  IF v_len IS NULL OR v_len <= 2 THEN
    RETURN btrim(addr);
  END IF;
  RETURN btrim(v_parts[v_len - 1]) || ', ' || btrim(v_parts[v_len]);
END;
$$;

ALTER FUNCTION public.engineer_address_public(text) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.engineer_address_public(text) TO authenticated, anon;

-- Rebuild engineer_public_profile with caller-aware city sanitization.
-- Signature unchanged — only e.city expression replaced with a
-- conditional based on v_can_see_full_address.
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
BEGIN
  SELECT e.user_id INTO v_engineer_user_id
    FROM public.engineers e
    WHERE e.id = p_engineer_id
      AND coalesce(e.verification_status::text, 'pending') = 'verified';

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

  -- Full address only for self + ops. Even an engaged hospital with an
  -- accepted job sees only the public 2-segment form — they don't need
  -- the engineer's door# to receive on-site service.
  v_can_see_full_address :=
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
    e.latitude,
    e.longitude,
    e.service_radius_km
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.id = p_engineer_id
    AND coalesce(e.verification_status::text, 'pending') = 'verified';
END;
$function$;

-- Rebuild engineers_directory_search the same way. List rows are
-- public-shaped: callers are always "another hospital looking for an
-- engineer," so always sanitize. The internal ILIKE filter keeps the
-- raw e.city in the WHERE clause so district matching against full
-- address strings still works.
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
