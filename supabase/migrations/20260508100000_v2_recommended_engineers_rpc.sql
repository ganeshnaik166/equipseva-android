-- v2.1 PR-B: smart-match recommended engineers for a hospital booking flow.
--
-- Hospitals shouldn't have to scroll the directory. Given a booking
-- location + (optional) equipment category, return the top N verified
-- engineers ranked by a composite match_score (0..100) that blends:
--   30% distance     (closer is better, capped at 200km)
--   25% rating       (rating_avg / 5)
--   20% specialization match (1.0 if engineer covers category, 0.5 if
--                            no category given, 0.0 otherwise)
--   15% completion_rate
--   10% completed-jobs count (capped at 5; v2.2 will refine to
--                             per-district repeat-customer count)
--
-- Reuses haversine_km() from 20260425073000_nearby_repair_jobs_rpc.sql
-- and the e.specializations::text[] cast pattern from PR-A
-- (engineers.specializations is equipment_category[] enum, not text[]).

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
    -- Composite score in 0..100, weights sum to 100.
    (
      -- 30% distance: closer = higher. Engineers w/ no coords get 0.
      30.0 * coalesce(
        1.0 - (LEAST(b.distance_km, 200.0) / 200.0),
        0.0
      )
      -- 25% rating
      + 25.0 * (b.rating_avg / 5.0)
      -- 20% specialization match
      + 20.0 * (
        CASE
          WHEN p_equipment_category IS NULL OR p_equipment_category = ''
            THEN 0.5
          WHEN p_equipment_category = ANY(coalesce(b.specializations, ARRAY[]::text[]))
            THEN 1.0
          ELSE 0.0
        END
      )
      -- 15% completion_rate (column is 0..100)
      + 15.0 * (b.completion_rate / 100.0)
      -- 10% completed jobs count, capped at 5 (social-proof proxy).
      -- v2.2: refine to per-district distinct hospital_user_ids.
      + 10.0 * (LEAST(b.total_jobs, 5)::numeric / 5.0)
    )::numeric AS match_score
  FROM base b
  ORDER BY match_score DESC,
           b.distance_km ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 5), 20));
$$;

COMMENT ON FUNCTION public.recommended_engineers_for_hospital(
  double precision, double precision, text, int
) IS
  'Smart-match top N verified engineers for a hospital booking. '
  'Composite score 0..100 = 30% distance + 25% rating + 20% '
  'specialization + 15% completion_rate + 10% completed-jobs '
  '(capped at 5). Reuses haversine_km(); does NOT redefine.';

GRANT EXECUTE ON FUNCTION public.recommended_engineers_for_hospital(
  double precision, double precision, text, int
) TO authenticated, anon;
