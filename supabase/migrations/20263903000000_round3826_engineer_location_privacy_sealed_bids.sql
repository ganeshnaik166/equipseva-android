-- Round 3826 — engineer location privacy and sealed bids.
--
-- Found by the owner-directed security audit of 26 September 2026 and
-- verified against the production catalog snapshot (supabase/regression
-- baseline, 2026-09-18) plus the latest defining migration of each function.
--
-- 1. CRITICAL — engineer_public_profile (round3761) returns base coordinates
--    to every caller, anon included, "fuzzed" by a per-engineer offset of
--    ((md5(engineer_id || ':lat') first 4 hex) % 200 - 100) / 10000 degrees.
--    engineer_id is public (the directory returns it to anon) and this
--    formula is in a public repository, so anyone can compute the offset and
--    subtract it: every verified engineer's EXACT saved base location — for
--    many engineers their home — was recoverable without signing in.
--    Fix: snap to a coarse 0.05° grid (≈5.5 km north-south, 4.5–5.5 km
--    east-west across India). Snapping discards information, so nothing can
--    be subtracted back out. Callers allowed exact coordinates (the engineer
--    themself, admin, founder) are unchanged.
--
-- 2. HIGH — engineers_directory_search and recommended_engineers_for_hospital
--    return full-precision haversine distance from CALLER-SUPPLIED
--    coordinates to each engineer's exact base. Three calls from three points
--    trilaterate the exact location, which defeats item 1's intent even
--    after it is fixed. Fix: distance (and the 'nearest' ordering) is
--    computed from the same coarse grid point, so trilateration recovers at
--    most the grid cell the profile already shows.
--
-- 3. HIGH (regression) — round732 recreated recommended_engineers_for_hospital
--    and silently undid round451's privacy fix: it returns the raw
--    engineers.city (the full KYC address) instead of
--    engineer_address_public(), and it re-granted EXECUTE to anon, which
--    round451 had revoked. The only callers are signed-in hospitals (Home
--    carousel, repeat-booking nudge, both gated on a hospital session).
--    Fix: sanitised city, EXECUTE for authenticated only.
--
-- 4. HIGH — list_repair_job_bids_with_distance (round3767) has an
--    "engineer-bidder bypass": any engineer holding one bid on a job reads
--    EVERY bid on it — competitors' amounts, ETAs, notes, names and raw home
--    addresses (engineers.city). Table RLS on repair_job_bids correctly
--    limits engineers to their own rows, so this definer function was the
--    only leak. PRODUCT_PLAN §4: engineers cannot see competing sealed bids.
--    Fix: a bidder receives only their own row; engineer_city is sanitised
--    for everyone except admin/founder (same rule as engineer_public_profile);
--    distance uses the coarse grid point. The Android app already calls this
--    function only for the hospital viewer (engineers read their own row from
--    the table), so no screen changes.
--
-- 5. Correctness, same functions — (a) the app ALWAYS sends p_min_rating, so
--    PostgREST always routes directory calls to round350's 10-argument
--    overload, which never returned current_tier; round731 added the tier to
--    the 9-argument overload the app never calls, so no directory card has
--    ever shown a tier badge. The 9-argument overload is dropped (calls
--    without p_min_rating still resolve to the 10-argument one through its
--    default) and current_tier is added to the remaining overload.
--    (b) The directory and recommendations still gate on the legacy scalar
--    profiles.role, the same defect round3761 fixed in engineer_public_profile:
--    verified engineers who hold the role via profiles.roles[] or active_role
--    vanish from both lists. Both now accept any of the three role signals.
--
-- Everything else in each function body is copied verbatim from its latest
-- definition. Proven locally by supabase/tests/engineer_location_privacy.test.mjs
-- (PGlite), including negative controls against the previous definitions.
-- Not applied to production by this commit.
BEGIN;

-- ---------------------------------------------------------------------------
-- Helper: coarse public coordinate (0.05° grid). Internal: called only from
-- the SECURITY DEFINER functions below, which run as their owner.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.engineer_coarse_coord(p_coord double precision)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_coord IS NULL THEN NULL
    ELSE (round((p_coord / 0.05)::numeric) * 0.05)::double precision
  END
$$;

COMMENT ON FUNCTION public.engineer_coarse_coord(double precision) IS
  'Round 3826 — snaps a coordinate to a 0.05 degree grid for public display. Non-invertible by design (replaces the md5 offset that anyone could subtract).';

REVOKE ALL ON FUNCTION public.engineer_coarse_coord(double precision) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. engineer_public_profile — body from round3761; only the two coordinate
--    expressions change.
-- ---------------------------------------------------------------------------
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
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_engineer_user_id uuid;
  v_can_see_contacts boolean;
  v_can_see_full_address boolean;
  v_can_see_exact_coords boolean;
  v_completion numeric;
BEGIN
  SELECT e.user_id INTO v_engineer_user_id
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    WHERE e.id = p_engineer_id
      AND coalesce(e.verification_status::text, 'pending') = 'verified'
      AND (
        coalesce(p.role::text, '') = 'engineer'
        OR 'engineer' = ANY(coalesce(p.roles::text[], ARRAY[]::text[]))
        OR coalesce(p.active_role::text, '') = 'engineer'
      );

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

  -- Dynamic completion-rate computation. Replaces the stale stored column.
  -- Round 3761: alias repair_jobs as rj and qualify engineer_id/status —
  -- otherwise `engineer_id` collides with the RETURNS TABLE OUT column of
  -- the same name ("column reference engineer_id is ambiguous").
  SELECT
    CASE WHEN count(*) FILTER (WHERE rj.status IN ('completed','cancelled')) = 0 THEN 0::numeric
         ELSE round(
           count(*) FILTER (WHERE rj.status = 'completed')::numeric
           / count(*) FILTER (WHERE rj.status IN ('completed','cancelled'))::numeric
           * 100.0, 1)
    END INTO v_completion
  FROM public.repair_jobs rj
  WHERE rj.engineer_id = p_engineer_id;

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
    v_completion,
    e.hourly_rate,
    e.bio,
    coalesce(e.is_available, false),
    -- Round 3826: coarse grid instead of the invertible md5 offset.
    CASE
      WHEN v_can_see_exact_coords THEN e.latitude
      ELSE public.engineer_coarse_coord(e.latitude)
    END,
    CASE
      WHEN v_can_see_exact_coords THEN e.longitude
      ELSE public.engineer_coarse_coord(e.longitude)
    END,
    e.service_radius_km
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE e.id = p_engineer_id
    AND coalesce(e.verification_status::text, 'pending') = 'verified'
    AND (
      coalesce(p.role::text, '') = 'engineer'
      OR 'engineer' = ANY(coalesce(p.roles::text[], ARRAY[]::text[]))
      OR coalesce(p.active_role::text, '') = 'engineer'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.engineer_public_profile(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.engineer_public_profile(uuid) TO authenticated, anon;

-- ---------------------------------------------------------------------------
-- 2 + 5. engineers_directory_search — one 10-argument overload. Body from
--    round350 (the overload the app actually reaches) plus round731's tier
--    join; coarse distance; three-signal role gate.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.engineers_directory_search(
  text, text, text, text, int, int, double precision, double precision, text
);
DROP FUNCTION IF EXISTS public.engineers_directory_search(
  text, text, text, text, int, int, double precision, double precision, text, numeric
);

CREATE FUNCTION public.engineers_directory_search(
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
  distance_km double precision,
  current_tier text
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
      THEN public.haversine_km(p_hospital_lat, p_hospital_lng,
             public.engineer_coarse_coord(e.latitude), public.engineer_coarse_coord(e.longitude))
      ELSE NULL
    END AS distance_km,
    coalesce(cp.current_tier, 'none') AS current_tier
  FROM public.engineers e
  LEFT JOIN public.profiles p ON p.id = e.user_id
  LEFT JOIN public.engineer_certification_progress cp ON cp.engineer_user_id = e.user_id
  WHERE coalesce(e.verification_status::text, 'pending') = 'verified'
    AND (
      coalesce(p.role::text, '') = 'engineer'
      OR 'engineer' = ANY(coalesce(p.roles::text[], ARRAY[]::text[]))
      OR coalesce(p.active_role::text, '') = 'engineer'
    )
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
    AND (
      p_min_rating IS NULL
      OR coalesce(e.rating_avg, 0)::numeric >= p_min_rating
    )
  ORDER BY
    CASE WHEN p_sort_mode = 'nearest' AND p_hospital_lat IS NOT NULL AND p_hospital_lng IS NOT NULL
      THEN
        CASE
          WHEN e.latitude IS NOT NULL AND e.longitude IS NOT NULL
          THEN public.haversine_km(p_hospital_lat, p_hospital_lng,
                 public.engineer_coarse_coord(e.latitude), public.engineer_coarse_coord(e.longitude))
          ELSE NULL
        END
    END ASC NULLS LAST,
    CASE WHEN p_sort_mode = 'price_asc' THEN e.hourly_rate END ASC NULLS LAST,
    coalesce(e.rating_avg, 0) DESC,
    coalesce(e.total_jobs, 0) DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200))
  OFFSET greatest(0, coalesce(p_offset, 0));
$$;

REVOKE ALL ON FUNCTION public.engineers_directory_search(
  text, text, text, text, int, int, double precision, double precision, text, numeric
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.engineers_directory_search(
  text, text, text, text, int, int, double precision, double precision, text, numeric
) TO authenticated, anon;

-- ---------------------------------------------------------------------------
-- 2 + 3 + 5b. recommended_engineers_for_hospital — body from round732;
--    sanitised city, coarse distance, three-signal role gate; authenticated
--    only. Signature and return type unchanged (plain CREATE OR REPLACE).
-- ---------------------------------------------------------------------------
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
  match_score numeric,
  current_tier text
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
      public.engineer_address_public(e.city)              AS city,
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
        THEN public.haversine_km(p_hospital_lat, p_hospital_lng,
               public.engineer_coarse_coord(e.latitude), public.engineer_coarse_coord(e.longitude))
        ELSE NULL
      END                                                 AS distance_km,
      coalesce(e.completion_rate, 0)::numeric             AS completion_rate,
      coalesce(cp.current_tier, 'none')                   AS current_tier
    FROM public.engineers e
    LEFT JOIN public.profiles p ON p.id = e.user_id
    LEFT JOIN public.engineer_certification_progress cp ON cp.engineer_user_id = e.user_id
    WHERE coalesce(e.verification_status::text, 'pending') = 'verified'
      AND (
        coalesce(p.role::text, '') = 'engineer'
        OR 'engineer' = ANY(coalesce(p.roles::text[], ARRAY[]::text[]))
        OR coalesce(p.active_role::text, '') = 'engineer'
      )
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
    )::numeric AS match_score,
    b.current_tier
  FROM base b
  ORDER BY match_score DESC,
           b.distance_km ASC NULLS LAST
  LIMIT GREATEST(1, LEAST(coalesce(p_limit, 5), 20));
$$;

REVOKE ALL ON FUNCTION public.recommended_engineers_for_hospital(
  double precision, double precision, text, int
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recommended_engineers_for_hospital(
  double precision, double precision, text, int
) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. list_repair_job_bids_with_distance — body from round3767; a bidder sees
--    only their own bid; sanitised engineer_city unless admin/founder;
--    coarse distance.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_repair_job_bids_with_distance(
  p_repair_job_id uuid
)
RETURNS TABLE (
  id uuid,
  repair_job_id uuid,
  engineer_user_id uuid,
  amount_rupees numeric,
  eta_hours int,
  note text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  engineer_full_name text,
  engineer_avatar_url text,
  engineer_rating_avg numeric,
  engineer_total_jobs int,
  engineer_city text,
  distance_km double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_hospital_user_id uuid;
  v_site_lat double precision;
  v_site_lng double precision;
  v_is_admin boolean := false;
  v_is_bidder boolean := false;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'authentication required'
      USING ERRCODE = '42501';
  END IF;

  SELECT rj.hospital_user_id, rj.site_latitude, rj.site_longitude
    INTO v_hospital_user_id, v_site_lat, v_site_lng
  FROM public.repair_jobs rj
  WHERE rj.id = p_repair_job_id;

  IF v_hospital_user_id IS NULL THEN
    RAISE EXCEPTION 'repair job not found'
      USING ERRCODE = '42501';
  END IF;

  v_is_admin := public.is_admin(v_caller);

  -- engineer-bidder access: caller has a bid on this job
  IF NOT v_is_admin AND v_caller <> v_hospital_user_id THEN
    SELECT EXISTS (
      SELECT 1 FROM public.repair_job_bids b
       WHERE b.repair_job_id = p_repair_job_id
         AND b.engineer_user_id = v_caller
    ) INTO v_is_bidder;
  END IF;

  IF NOT v_is_admin
     AND v_caller <> v_hospital_user_id
     AND NOT v_is_bidder THEN
    RAISE EXCEPTION 'not authorized to read bids for this job'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.repair_job_id,
    b.engineer_user_id,
    b.amount_rupees,
    b.eta_hours,
    b.note,
    b.status,
    b.created_at,
    b.updated_at,
    coalesce(p.full_name, '(unnamed)')               AS engineer_full_name,
    p.avatar_url                                     AS engineer_avatar_url,
    coalesce(e.rating_avg, 0)::numeric               AS engineer_rating_avg,
    coalesce(e.total_jobs, 0)                        AS engineer_total_jobs,
    CASE WHEN v_is_admin THEN e.city
         ELSE public.engineer_address_public(e.city) END AS engineer_city,
    CASE
      WHEN v_site_lat IS NOT NULL
        AND v_site_lng IS NOT NULL
        AND e.latitude IS NOT NULL
        AND e.longitude IS NOT NULL
      THEN public.haversine_km(v_site_lat, v_site_lng,
             public.engineer_coarse_coord(e.latitude), public.engineer_coarse_coord(e.longitude))
      ELSE NULL
    END                                              AS distance_km
  FROM public.repair_job_bids b
  LEFT JOIN public.engineers e ON e.user_id = b.engineer_user_id
  LEFT JOIN public.profiles  p ON p.id      = b.engineer_user_id
  WHERE b.repair_job_id = p_repair_job_id
    -- Round 3826: sealed bids — a bidder (not the posting hospital, not
    -- admin/founder) sees only their own row.
    AND (NOT v_is_bidder OR b.engineer_user_id = v_caller)
  ORDER BY b.created_at ASC;
END;
$$;

ALTER FUNCTION public.list_repair_job_bids_with_distance(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.list_repair_job_bids_with_distance(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_repair_job_bids_with_distance(uuid) TO authenticated;

COMMENT ON FUNCTION public.list_repair_job_bids_with_distance(uuid) IS
  'Round 3826 — sealed bids: a bidder sees only their own bid; engineer_city sanitised for non-admin callers; distance from the coarse public grid point. Admin bypass via public.is_admin() (round3767).';

COMMIT;
