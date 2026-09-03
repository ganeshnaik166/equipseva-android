-- Round 3767 — same root cause as round3766, different artifact: an RPC's
-- own hand-rolled admin check rather than an RLS policy.
--
-- list_repair_job_bids_with_distance's "admin bypass" inlines the stale
-- `profiles.role = 'admin'` check directly instead of calling
-- public.is_admin() — so it was NOT automatically fixed by round3766's
-- function widening (that only helps callers that actually invoke
-- is_admin()). Found by re-running round3766's discovery grep against
-- every LIVE function body in the schema (not just RLS policies) — this
-- was the one remaining real hit (the other hit, guard_profile_self_
-- escalation, only contains the literal string 'admin' as part of ITS
-- OWN unrelated self-promotion-guard logic — already correctly calls
-- is_admin(auth.uid()) for its actual bypass, no fix needed there).
--
-- Same fix shape as round3766: swap the inline EXISTS check for a call
-- to public.is_admin(v_caller) — v_caller here is auth.uid() (declared
-- at function top), so this correctly benefits from round3766's
-- founder-widening. This RPC is Android-called (list_repair_job_bids_
-- with_distance — hospital-side bid list with distance), so this closes
-- the same "founder locked out of their own platform's data" gap for
-- anyone hitting this RPC directly, not just the web console.
BEGIN;

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

  -- Round 3767: was an inline `profiles.role = 'admin'` check — never
  -- true for the founder's real account (role='hospital_admin'). Routes
  -- through public.is_admin(), which round3766 widened to also cover
  -- the founder's own self-check.
  v_is_admin := public.is_admin(v_caller);

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
  'Round 3767 (was round #2 from the r2 repair_job_bids_with_distance ship) — admin bypass now routes through public.is_admin(), fixed by round3766 to also cover the founder''s own self-check. Previously the inline profiles.role=''admin'' check never matched the founder''s real role (hospital_admin), silently denying them this RPC for any job they weren''t a direct party to.';

COMMIT;
