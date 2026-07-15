-- Round 735 — fix engineer_public_profile "column reference engineer_id is
-- ambiguous" (the REAL cause of "Profile unavailable").
--
-- Live mobile test (hospital taps an engineer) threw, captured from PostgREST:
--   column reference "engineer_id" is ambiguous (It could refer to either a
--   PL/pgSQL variable or a table column.)
--
-- Root cause: the function's RETURNS TABLE declares an OUT column named
-- `engineer_id`. The dynamic completion-rate subquery added in r728 does
-- `... FROM public.repair_jobs WHERE engineer_id = p_engineer_id` with
-- engineer_id UNQUALIFIED — Postgres can't tell the OUT variable from
-- repair_jobs.engineer_id, so it raises on EVERY call. Broken since r728;
-- the app shows the generic throw path "Profile unavailable / Something went
-- wrong". (r732's role-gate + LEFT JOIN change was a valid robustness
-- improvement but addressed the empty-rows path, not this throw.)
--
-- Fix: alias public.repair_jobs as rj in the completion-rate subquery and
-- qualify engineer_id + status. Function otherwise identical to r732 (keeps
-- the multi-role gate). Transactional CREATE OR REPLACE (fails safe).
--
-- NOT YET APPLIED to prod — run in the Supabase SQL editor.
BEGIN;

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
  -- r735: alias repair_jobs as rj and qualify engineer_id/status — otherwise
  -- `engineer_id` collides with the RETURNS TABLE OUT column of the same name
  -- ("column reference engineer_id is ambiguous").
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
    AND (
      coalesce(p.role::text, '') = 'engineer'
      OR 'engineer' = ANY(coalesce(p.roles::text[], ARRAY[]::text[]))
      OR coalesce(p.active_role::text, '') = 'engineer'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.engineer_public_profile(uuid) TO authenticated, anon;
COMMIT;
