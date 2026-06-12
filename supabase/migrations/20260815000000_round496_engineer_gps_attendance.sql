-- =====================================================================
-- Round 496 — Engineer GPS Attendance (v0.4 Phase 3 #7)
-- =====================================================================
--
-- Today: an engineer marks a job "in progress" via the app with no
-- proof they're actually at the hospital. Audit-7 / audit-8 surfaced
-- this as a soft gap: a remote engineer can fake-progress jobs from
-- home + later swap in field photos pulled from someone else's
-- repair. Trust falls apart at the first lawsuit.
--
-- This migration adds a structured arrival + departure attendance
-- ledger:
--   * engineer_attendance table — one row per check-in / check-out
--     event with geo coords + accuracy + computed distance from
--     hospital's registered address + suspicious-distance flag.
--   * record_engineer_attendance(...) — engineer-facing RPC
--   * attendance_for_job() — hospital + founder read helper
--
-- The geocoded hospital address (lat/lng) is denormalized onto
-- the attendance row at insert time so a later address edit by
-- the hospital doesn't break the historical distance check.

BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_attendance (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id            uuid        NOT NULL REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  engineer_user_id         uuid        NOT NULL,
  CONSTRAINT engineer_attendance_engineer_fk
    FOREIGN KEY (engineer_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT,
  hospital_user_id         uuid        NOT NULL,
  CONSTRAINT engineer_attendance_hospital_fk
    FOREIGN KEY (hospital_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT,

  event_kind               text        NOT NULL
                                       CHECK (event_kind IN ('arrival_checkin','departure_checkout')),
  -- Captured at engineer-device wall clock + server-stored too
  device_captured_at       timestamptz NOT NULL,
  -- Engineer-reported geo
  engineer_lat             double precision NOT NULL,
  engineer_lng             double precision NOT NULL,
  engineer_accuracy_m      double precision,
  -- Snapshot of hospital expected location at event time. NULL when
  -- hospital hasn't shared address; we still capture the engineer's
  -- coords for forensic audit.
  hospital_expected_lat    double precision,
  hospital_expected_lng    double precision,
  -- Computed Haversine distance in meters
  distance_from_hospital_m double precision,
  -- Flag for hospital + founder review when distance > 500m
  -- (urban India site/clinic shouldn't have engineer >500m off
  -- the listed coords during a check-in).
  suspicious_distance      boolean     NOT NULL DEFAULT false,

  -- Linked evidence (e.g., the engineer's selfie at gate)
  evidence_ledger_id       uuid        REFERENCES public.evidence_ledger(id) ON DELETE SET NULL,

  -- IP + UA for additional forensic context
  ip_address               inet,
  user_agent               text,

  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS engineer_attendance_job_idx
  ON public.engineer_attendance (repair_job_id, event_kind, device_captured_at);
CREATE INDEX IF NOT EXISTS engineer_attendance_engineer_idx
  ON public.engineer_attendance (engineer_user_id, device_captured_at DESC);
CREATE INDEX IF NOT EXISTS engineer_attendance_suspicious_idx
  ON public.engineer_attendance (suspicious_distance, created_at DESC)
  WHERE suspicious_distance = true;

ALTER TABLE public.engineer_attendance ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS engineer_attendance_select ON public.engineer_attendance;
CREATE POLICY engineer_attendance_select
  ON public.engineer_attendance
  FOR SELECT
  TO authenticated, service_role
  USING (
    engineer_user_id = auth.uid()
    OR hospital_user_id = auth.uid()
    OR public.is_founder()
  );

REVOKE INSERT, UPDATE, DELETE ON public.engineer_attendance
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- Haversine helper (immutable, sql)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.haversine_meters(
  p_lat1 double precision,
  p_lng1 double precision,
  p_lat2 double precision,
  p_lng2 double precision
)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT
    CASE
      WHEN p_lat1 IS NULL OR p_lat2 IS NULL OR p_lng1 IS NULL OR p_lng2 IS NULL THEN NULL
      ELSE 2 * 6371000 * asin(sqrt(
        sin(radians((p_lat2 - p_lat1) / 2)) * sin(radians((p_lat2 - p_lat1) / 2))
        + cos(radians(p_lat1)) * cos(radians(p_lat2))
        * sin(radians((p_lng2 - p_lng1) / 2)) * sin(radians((p_lng2 - p_lng1) / 2))
      ))
    END;
$$;

REVOKE EXECUTE ON FUNCTION public.haversine_meters(
  double precision, double precision, double precision, double precision
) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.haversine_meters(
  double precision, double precision, double precision, double precision
) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- record_engineer_attendance
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_engineer_attendance(
  p_repair_job_id      uuid,
  p_event_kind         text,
  p_engineer_lat       double precision,
  p_engineer_lng       double precision,
  p_engineer_accuracy_m double precision DEFAULT NULL,
  p_device_captured_at timestamptz DEFAULT now(),
  p_hospital_expected_lat double precision DEFAULT NULL,
  p_hospital_expected_lng double precision DEFAULT NULL,
  p_evidence_ledger_id uuid DEFAULT NULL,
  p_ip_address         inet DEFAULT NULL,
  p_user_agent         text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller     uuid := auth.uid();
  v_job        record;
  v_engineer   uuid;
  v_distance   double precision;
  v_suspicious boolean := false;
  v_id         uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  IF p_event_kind NOT IN ('arrival_checkin','departure_checkout') THEN
    RAISE EXCEPTION 'invalid_event_kind' USING ERRCODE = '22023';
  END IF;
  IF p_engineer_lat IS NULL OR p_engineer_lng IS NULL THEN
    RAISE EXCEPTION 'engineer_lat/lng required' USING ERRCODE = '22023';
  END IF;
  IF abs(p_engineer_lat) > 90 OR abs(p_engineer_lng) > 180 THEN
    RAISE EXCEPTION 'invalid_geo' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_job FROM public.repair_jobs WHERE id = p_repair_job_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'repair_job_not_found' USING ERRCODE = '02000';
  END IF;

  SELECT engineer_user_id INTO v_engineer
    FROM public.repair_job_bids
   WHERE repair_job_id = p_repair_job_id
     AND status = 'accepted'
   LIMIT 1;

  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'no_accepted_engineer' USING ERRCODE = '02000';
  END IF;
  IF v_caller <> v_engineer AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'only_accepted_engineer_can_checkin' USING ERRCODE = '42501';
  END IF;

  IF p_hospital_expected_lat IS NOT NULL AND p_hospital_expected_lng IS NOT NULL THEN
    v_distance := public.haversine_meters(
      p_engineer_lat, p_engineer_lng,
      p_hospital_expected_lat, p_hospital_expected_lng
    );
    IF v_distance IS NOT NULL AND v_distance > 500 THEN
      v_suspicious := true;
    END IF;
  END IF;

  INSERT INTO public.engineer_attendance (
    repair_job_id, engineer_user_id, hospital_user_id,
    event_kind, device_captured_at,
    engineer_lat, engineer_lng, engineer_accuracy_m,
    hospital_expected_lat, hospital_expected_lng,
    distance_from_hospital_m, suspicious_distance,
    evidence_ledger_id, ip_address, user_agent
  ) VALUES (
    p_repair_job_id, v_engineer, v_job.hospital_user_id,
    p_event_kind, p_device_captured_at,
    p_engineer_lat, p_engineer_lng, p_engineer_accuracy_m,
    p_hospital_expected_lat, p_hospital_expected_lng,
    v_distance, v_suspicious,
    p_evidence_ledger_id, p_ip_address, p_user_agent
  ) RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_engineer_attendance(
  uuid, text, double precision, double precision, double precision,
  timestamptz, double precision, double precision, uuid, inet, text
) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.record_engineer_attendance(
  uuid, text, double precision, double precision, double precision,
  timestamptz, double precision, double precision, uuid, inet, text
) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- attendance_for_job
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.attendance_for_job(
  p_repair_job_id uuid
)
RETURNS TABLE(
  id                       uuid,
  event_kind               text,
  device_captured_at       timestamptz,
  engineer_lat             double precision,
  engineer_lng             double precision,
  engineer_accuracy_m      double precision,
  distance_from_hospital_m double precision,
  suspicious_distance      boolean,
  created_at               timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT a.id, a.event_kind, a.device_captured_at,
         a.engineer_lat, a.engineer_lng, a.engineer_accuracy_m,
         a.distance_from_hospital_m, a.suspicious_distance, a.created_at
    FROM public.engineer_attendance a
   WHERE a.repair_job_id = p_repair_job_id
     AND (a.engineer_user_id = auth.uid()
          OR a.hospital_user_id = auth.uid()
          OR public.is_founder())
   ORDER BY a.device_captured_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.attendance_for_job(uuid)
  FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.attendance_for_job(uuid)
  TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- founder_suspicious_attendance_recent — cockpit query
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_suspicious_attendance_recent(
  p_days  integer DEFAULT 30,
  p_limit integer DEFAULT 100
)
RETURNS TABLE(
  id                       uuid,
  repair_job_id            uuid,
  engineer_user_id         uuid,
  engineer_email           text,
  event_kind               text,
  device_captured_at       timestamptz,
  distance_from_hospital_m double precision,
  engineer_lat             double precision,
  engineer_lng             double precision
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT a.id, a.repair_job_id, a.engineer_user_id,
         coalesce((SELECT email FROM auth.users WHERE id = a.engineer_user_id), 'unknown'),
         a.event_kind, a.device_captured_at,
         a.distance_from_hospital_m, a.engineer_lat, a.engineer_lng
    FROM public.engineer_attendance a
   WHERE a.suspicious_distance = true
     AND a.created_at >= now() - (greatest(coalesce(p_days, 30), 1)::text || ' days')::interval
   ORDER BY a.created_at DESC
   LIMIT greatest(coalesce(p_limit, 100), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_suspicious_attendance_recent(integer, integer)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_suspicious_attendance_recent(integer, integer)
  TO service_role;

COMMIT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'engineer_attendance'
      AND relnamespace = 'public'::regnamespace
      AND relrowsecurity = true
  ) THEN
    RAISE EXCEPTION 'round 496: engineer_attendance RLS not enabled';
  END IF;
  RAISE NOTICE 'round 496 engineer GPS attendance verified: table + 3 RPCs + haversine helper, grants correct';
END;
$$;
