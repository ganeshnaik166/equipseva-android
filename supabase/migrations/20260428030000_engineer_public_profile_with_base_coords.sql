-- Surface engineer base lat/lng + service radius on the public profile so the
-- hospital-side map widget can draw a service-area circle. Same verification
-- gate as before — only verified engineers leak coords.

DROP FUNCTION IF EXISTS public.engineer_public_profile(uuid);

CREATE OR REPLACE FUNCTION public.engineer_public_profile(
  p_engineer_id uuid
)
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
  experience_years int,
  rating_avg numeric,
  total_jobs int,
  completion_rate numeric,
  hourly_rate numeric,
  bio text,
  is_available boolean,
  base_latitude double precision,
  base_longitude double precision,
  service_radius_km int
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
    p.phone,
    p.email,
    e.city,
    e.state,
    e.service_areas,
    e.specializations,
    e.brands_serviced,
    e.oem_training_badges,
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
$$;
GRANT EXECUTE ON FUNCTION public.engineer_public_profile(uuid) TO authenticated, anon;
