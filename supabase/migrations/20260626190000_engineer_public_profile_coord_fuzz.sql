-- Round 234 — coord obfuscation for engineer_public_profile.
--
-- engineer_public_profile returns e.latitude / e.longitude verbatim
-- to every authenticated caller. Hospitals (and any signed-in
-- engineer browsing the directory) can therefore pin the engineer's
-- exact home/base location, which defeats the "service area radius"
-- privacy model (we publish a circle, not a pinpoint).
--
-- Fix: keep exact coords for the engineer themselves + admin/founder.
-- Everyone else receives a deterministic ±0.01° jitter (≈ ±1 km in
-- India) seeded by the engineer's id, so the value is stable across
-- queries (no averaging attack) and the repeat-booking nudge's 50 km
-- distance check still works within tolerance.
--
-- The fuzz is computed inline in the RPC so we don't have to back-
-- fill an obfuscated coordinate column. Existing client code keeps
-- working — base_latitude / base_longitude are still returned, just
-- now coarsened for non-owners.

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

  -- Exact coords only for self + ops. Hospitals see a coarsened pin so
  -- the engineer's home isn't broadcast — the service-area circle
  -- already gives them everything they need.
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
      -- Deterministic ±0.01° jitter (~±1 km). md5 → first 4 hex chars
      -- → 16-bit int → mod 200 → −100..99 → /10000 → −0.01..+0.0099.
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
    AND coalesce(e.verification_status::text, 'pending') = 'verified';
END;
$function$;
