-- Fix engineer_public_profile RPC array column casts.
--
-- The RETURNS TABLE declares specializations / service_areas /
-- brands_serviced / oem_training_badges as text[], but the underlying
-- engineers.specializations column is the equipment_category[] enum
-- array. Postgres rejects the mismatch with:
--   ERROR: 42804 structure of query does not match function result type
--   DETAIL: Returned type equipment_category[] does not match expected
--           type text[] in column 10.
-- The companion engineers_directory_search RPC already casts these via
-- ::text[]; mirror the pattern here so the hospital → engineer profile
-- screen stops returning "Profile unavailable / Something went wrong."

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

  RETURN QUERY
  SELECT
    e.id,
    e.user_id,
    coalesce(p.full_name, '(unnamed)'),
    p.avatar_url,
    CASE WHEN v_can_see_contacts THEN p.phone ELSE NULL END,
    CASE WHEN v_can_see_contacts THEN p.email ELSE NULL END,
    e.city,
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
