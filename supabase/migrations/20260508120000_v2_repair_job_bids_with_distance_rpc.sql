-- v2.1 PR-B: bid-card distance — convert hospital's bid-list read path
-- from a direct table SELECT (SupabaseRepairBidRepository.fetchBidsForJob)
-- to an RPC that joins engineer trust signals + computes haversine
-- distance from job site → engineer base.
--
-- PR-A skipped this because the read was a direct table select; with
-- this RPC the hospital sees distance_km on every bid card without
-- exposing engineer base coords to the client.
--
-- RLS posture: SECURITY DEFINER + an explicit auth.uid() gate inside
-- the function body. Mirrors the table policies:
--   - hospital that posted the job (rj.hospital_user_id = auth.uid())
--   - engineer who placed any bid on the job
--   - admin (profiles.role = 'admin'::user_role)
-- Anyone else: RAISE EXCEPTION 42501 (insufficient privilege).
--
-- Reuses haversine_km(). engineers.latitude/longitude + repair_jobs
-- .site_latitude/site_longitude verified in 20260507100000 column probe.

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

  -- admin bypass
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
     WHERE p.id = v_caller AND p.role = 'admin'::user_role
  ) INTO v_is_admin;

  -- engineer-bidder bypass: caller has any bid on this job
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
    e.city                                           AS engineer_city,
    CASE
      WHEN v_site_lat IS NOT NULL
        AND v_site_lng IS NOT NULL
        AND e.latitude IS NOT NULL
        AND e.longitude IS NOT NULL
      THEN public.haversine_km(v_site_lat, v_site_lng, e.latitude, e.longitude)
      ELSE NULL
    END                                              AS distance_km
  FROM public.repair_job_bids b
  LEFT JOIN public.engineers e ON e.user_id = b.engineer_user_id
  LEFT JOIN public.profiles  p ON p.id      = b.engineer_user_id
  WHERE b.repair_job_id = p_repair_job_id
  ORDER BY b.created_at ASC;
END;
$$;

ALTER FUNCTION public.list_repair_job_bids_with_distance(uuid) OWNER TO postgres;

REVOKE EXECUTE ON FUNCTION public.list_repair_job_bids_with_distance(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.list_repair_job_bids_with_distance(uuid) TO authenticated;

COMMENT ON FUNCTION public.list_repair_job_bids_with_distance(uuid) IS
  'Hospital bid-list read path with engineer trust signals + distance '
  'from job site to engineer base. SECURITY DEFINER w/ explicit '
  'auth.uid() gate: only the posting hospital, an engineer-bidder, or '
  'admin can read. Replaces the direct repair_job_bids table SELECT.';
