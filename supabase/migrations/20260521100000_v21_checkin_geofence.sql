-- v2.1 PR-D6: GPS geofence on engineer check-in (T1.2 in the
-- anti-disintermediation strategy memo). The strategy doc says:
--
--   "Check in on-site only fires if device GPS within ~200m of
--   hospital address. Captures lat/lon. Proof-of-presence."
--
-- Why this matters: combined with PR-D4/D5 escrow + PR-D3 audit-trail
-- HTML report, geofenced check-in gives us cryptographic-style proof
-- that the engineer actually went on-site. Hospital can no longer
-- argue "no-show" after the fact, AND engineer can't fake-complete
-- from a coffee shop. Per-job escrow makes this actionable: if the
-- check-in didn't pass, no work happened, no payment release.
--
-- Geofence radius: 250m. Strategy memo says "~200m"; we use 250m so
-- a noisy first GPS fix in a multi-floor hospital basement still
-- passes. Tunable via a constant in the function body if false-fail
-- rate climbs.
--
-- Bypass paths (intentional):
--   * Job has no site_latitude/longitude (legacy rows, manual create) —
--     skip the geofence check, allow legacy behavior. PR-D7 will
--     backfill site coords from the hospital profile.
--   * is_admin or is_founder — admins can force check-in for ops
--     unblocking (e.g. engineer's phone died on-site).

-- ---------------------------------------------------------------------
-- engineer_check_in_with_geo
--   Single SECDEF entry point that replaces the generic status-transition
--   RPC for the assigned→in_progress hop. Captures the engineer's GPS
--   on the way through so the audit trail has a proof-of-presence
--   record. Returns the updated row distance_meters; the client can
--   show a friendly "Checked in 47m from site" toast.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.engineer_check_in_with_geo(
  p_repair_job_id uuid,
  p_lat           double precision,
  p_lng           double precision
)
RETURNS TABLE (
  status            text,
  distance_meters   double precision,
  geofence_passed   boolean,
  geofence_skipped  boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller        uuid := auth.uid();
  v_job           record;
  v_engineer_user uuid;
  v_distance_km   double precision;
  v_distance_m    double precision;
  v_skipped       boolean := false;
  v_passed        boolean := true;
  v_radius_m      constant double precision := 250.0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_lat IS NULL OR p_lng IS NULL OR p_lat NOT BETWEEN -90 AND 90
     OR p_lng NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid coordinates' USING ERRCODE = '22023';
  END IF;

  SELECT rj.id, rj.status::text AS status, rj.engineer_id,
         rj.site_latitude, rj.site_longitude, rj.completed_at
    INTO v_job
    FROM public.repair_jobs rj
   WHERE rj.id = p_repair_job_id
   FOR UPDATE;
  IF v_job IS NULL THEN
    RAISE EXCEPTION 'job not found' USING ERRCODE = '02000';
  END IF;
  IF v_job.engineer_id IS NULL THEN
    RAISE EXCEPTION 'job has no engineer assigned' USING ERRCODE = '22023';
  END IF;

  -- Translate engineers row id → user_id for the auth gate.
  SELECT e.user_id INTO v_engineer_user
    FROM public.engineers e
   WHERE e.id = v_job.engineer_id;
  IF v_caller <> v_engineer_user
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not the engineer on this job' USING ERRCODE = '42501';
  END IF;

  -- Status guard — must be in a pre-progress state.
  IF v_job.status NOT IN ('assigned','en_route') THEN
    RAISE EXCEPTION 'job not in assigned/en_route (got %)', v_job.status
      USING ERRCODE = '22023';
  END IF;

  -- Geofence. Only enforce when the job has site coordinates.
  IF v_job.site_latitude IS NULL OR v_job.site_longitude IS NULL THEN
    v_skipped := true;
    v_distance_m := NULL;
  ELSE
    v_distance_km := public.haversine_km(
      p_lat, p_lng, v_job.site_latitude, v_job.site_longitude
    );
    v_distance_m := v_distance_km * 1000.0;
    -- Admins / founders bypass the radius check — they may need to
    -- force-check-in an engineer whose phone died on-site.
    IF v_distance_m > v_radius_m
       AND NOT public.is_admin(v_caller)
       AND NOT public.is_founder() THEN
      v_passed := false;
      RAISE EXCEPTION 'too far from site (%.0f m > %.0f m)',
        v_distance_m, v_radius_m
        USING ERRCODE = '22023';
    END IF;
  END IF;

  UPDATE public.repair_jobs
     SET status              = 'in_progress',
         started_at          = COALESCE(started_at, now()),
         engineer_latitude   = p_lat,
         engineer_longitude  = p_lng,
         updated_at          = now()
   WHERE id = p_repair_job_id;

  RETURN QUERY
  SELECT
    'in_progress'::text                   AS status,
    v_distance_m                          AS distance_meters,
    v_passed                              AS geofence_passed,
    v_skipped                             AS geofence_skipped;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_check_in_with_geo(uuid, double precision, double precision) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_check_in_with_geo(uuid, double precision, double precision) TO authenticated;
