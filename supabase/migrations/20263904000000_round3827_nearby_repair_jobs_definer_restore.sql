-- Round 3827 — restore the engineer "nearby jobs" feed.
--
-- Found by the owner-directed security audit of 26 September 2026; verified
-- against the production catalog snapshot (2026-09-18: list_nearby_repair_jobs
-- security_definer = false) and the column grants on public.organizations.
--
-- HIGH (core journey broken for every engineer with a saved base):
--   * 20260428120000 revoked table-wide SELECT on public.organizations and
--     re-granted a column whitelist to authenticated that EXCLUDES latitude
--     and longitude (no later migration grants them).
--   * 20260428160000 therefore made list_nearby_repair_jobs SECURITY DEFINER,
--     because under SECURITY INVOKER its join into organizations "failed for
--     every authenticated caller" — and replicated the repair_jobs visibility
--     rule in its WHERE clause, since a definer function bypasses RLS.
--   * 20260627010000 (radius/limit clamps) recreated it as SECURITY INVOKER,
--     silently undoing that fix. Every call now raises 42501 (permission
--     denied on organizations.latitude/longitude).
--   * The Android feed's default filter is 50 km (RepairJobsUiState.radiusKm
--     = 50), so every engineer who has saved a service location gets an
--     error banner instead of nearby work when they open Jobs.
--
-- Fix: SECURITY DEFINER again, keeping BOTH earlier intents —
--   * the clamps from 20260627010000 (radius 1..500 km, limit 1..200);
--   * the visibility rule from 20260428160000 (open 'requested' jobs for every
--     engineer; 'assigned' jobs only for the engineer assigned);
-- plus one privacy change consistent with round3826 and PRODUCT_PLAN §4
-- ("public feeds show only coarse service area"): hospital_latitude and
-- hospital_longitude are returned on the coarse 0.05° grid
-- (public.engineer_coarse_coord, added by round3826). Filtering and ordering
-- still use the exact organization coordinates, and distance_km is the exact
-- travel distance from the engineer's own base, which the engineer needs to
-- decide whether to bid; the exact site is disclosed after award as before.
--
-- Callers must be an engineer (the `me` CTE requires an engineers row with a
-- base location); anyone else gets zero rows. EXECUTE: authenticated only.
-- Proven locally by supabase/tests/nearby_repair_jobs_feed.test.mjs (PGlite),
-- including a negative control that reproduces the 42501 on the previous
-- definition. Not applied to production by this commit.
BEGIN;

CREATE OR REPLACE FUNCTION public.list_nearby_repair_jobs(
  p_radius_km double precision DEFAULT 50,
  p_limit integer DEFAULT 100
) RETURNS TABLE (
  id uuid,
  job_number text,
  hospital_user_id uuid,
  hospital_org_id uuid,
  equipment_brand text,
  equipment_model text,
  equipment_type text,
  urgency text,
  status text,
  issue_description text,
  scheduled_date date,
  scheduled_time_slot text,
  estimated_cost numeric,
  hospital_latitude double precision,
  hospital_longitude double precision,
  distance_km double precision,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH me AS (
    SELECT e.id AS engineer_id, e.latitude AS lat, e.longitude AS lng
    FROM public.engineers e
    WHERE e.user_id = auth.uid()
    LIMIT 1
  ), bounds AS (
    SELECT
      greatest(1::double precision, least(coalesce(p_radius_km, 50), 500)) AS radius_km,
      greatest(1, least(coalesce(p_limit, 100), 200))                       AS row_limit
  )
  SELECT
    rj.id,
    rj.job_number,
    rj.hospital_user_id,
    rj.hospital_org_id,
    rj.equipment_brand,
    rj.equipment_model,
    rj.equipment_type::text,
    rj.urgency::text,
    rj.status::text,
    rj.issue_description,
    rj.scheduled_date,
    rj.scheduled_time_slot,
    rj.estimated_cost,
    public.engineer_coarse_coord(o.latitude)  AS hospital_latitude,
    public.engineer_coarse_coord(o.longitude) AS hospital_longitude,
    public.haversine_km(me.lat, me.lng, o.latitude, o.longitude) AS distance_km,
    rj.created_at
  FROM public.repair_jobs rj
  JOIN public.organizations o ON o.id = rj.hospital_org_id
  CROSS JOIN me
  CROSS JOIN bounds
  WHERE me.lat IS NOT NULL
    AND me.lng IS NOT NULL
    AND o.latitude IS NOT NULL
    AND o.longitude IS NOT NULL
    AND (
      rj.status::text = 'requested'
      OR (rj.status::text = 'assigned' AND rj.engineer_id = me.engineer_id)
    )
    AND public.haversine_km(me.lat, me.lng, o.latitude, o.longitude) <= bounds.radius_km
  ORDER BY distance_km ASC, rj.created_at DESC
  LIMIT (SELECT row_limit FROM bounds);
$$;

COMMENT ON FUNCTION public.list_nearby_repair_jobs(double precision, integer) IS
  'Round 3827 — engineer feed of open repair jobs within p_radius_km (clamped 1..500) of the calling engineer''s base; limit clamped 1..200. SECURITY DEFINER so it can read organization coordinates past the column-level lockdown; visibility rule (open + own-assigned) replicated in WHERE; hospital coordinates returned on the coarse 0.05° grid.';

REVOKE ALL ON FUNCTION public.list_nearby_repair_jobs(double precision, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_nearby_repair_jobs(double precision, integer) TO authenticated;

COMMIT;
