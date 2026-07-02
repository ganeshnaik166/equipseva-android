BEGIN;
-- Round 1437 — Founder engineer fleet tracker
-- 2 tables + 7 RPCs + RLS

-- =========================================================================
-- Table 1: engineer_fleet_vehicles
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_fleet_vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  vehicle_kind text NOT NULL CHECK (vehicle_kind IN ('two_wheeler','three_wheeler','four_wheeler_petrol','four_wheeler_diesel','four_wheeler_ev','personal_vehicle','rental','company_pool')),
  registration_number text,
  make_model text,
  ownership_kind text NOT NULL DEFAULT 'engineer_owned' CHECK (ownership_kind IN ('company_owned','engineer_owned','rental_monthly','rental_per_visit')),
  allotted_at date,
  retired_at date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','maintenance','retired','transferred','lost','damaged')),
  insurance_expiry date,
  puc_expiry date,
  last_service_at date,
  total_odometer_km int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_efv_engineer ON public.engineer_fleet_vehicles(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_efv_status ON public.engineer_fleet_vehicles(status);
CREATE INDEX IF NOT EXISTS idx_efv_kind ON public.engineer_fleet_vehicles(vehicle_kind);
CREATE INDEX IF NOT EXISTS idx_efv_ownership ON public.engineer_fleet_vehicles(ownership_kind);
CREATE INDEX IF NOT EXISTS idx_efv_insurance_expiry ON public.engineer_fleet_vehicles(insurance_expiry);
CREATE INDEX IF NOT EXISTS idx_efv_puc_expiry ON public.engineer_fleet_vehicles(puc_expiry);
CREATE INDEX IF NOT EXISTS idx_efv_created ON public.engineer_fleet_vehicles(created_at DESC);

ALTER TABLE public.engineer_fleet_vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS efv_founder_all ON public.engineer_fleet_vehicles;
CREATE POLICY efv_founder_all ON public.engineer_fleet_vehicles
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS efv_engineer_own_read ON public.engineer_fleet_vehicles;
CREATE POLICY efv_engineer_own_read ON public.engineer_fleet_vehicles
  FOR SELECT TO authenticated USING (engineer_user_id = auth.uid());

-- =========================================================================
-- Table 2: engineer_fleet_trips
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.engineer_fleet_trips (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES public.engineer_fleet_vehicles(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trip_purpose text NOT NULL CHECK (trip_purpose IN ('site_visit','calibration_pickup','parts_pickup','training','personal_use_logged','other')),
  repair_job_id uuid,
  distance_km numeric NOT NULL DEFAULT 0,
  fuel_cost_rupees numeric NOT NULL DEFAULT 0,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eft_vehicle ON public.engineer_fleet_trips(vehicle_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_eft_engineer ON public.engineer_fleet_trips(engineer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_eft_purpose ON public.engineer_fleet_trips(trip_purpose);
CREATE INDEX IF NOT EXISTS idx_eft_repair_job ON public.engineer_fleet_trips(repair_job_id);
CREATE INDEX IF NOT EXISTS idx_eft_started ON public.engineer_fleet_trips(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_eft_created ON public.engineer_fleet_trips(created_at DESC);

ALTER TABLE public.engineer_fleet_trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS eft_founder_all ON public.engineer_fleet_trips;
CREATE POLICY eft_founder_all ON public.engineer_fleet_trips
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS eft_engineer_own_read ON public.engineer_fleet_trips;
CREATE POLICY eft_engineer_own_read ON public.engineer_fleet_trips
  FOR SELECT TO authenticated USING (engineer_user_id = auth.uid());

DROP POLICY IF EXISTS eft_engineer_own_insert ON public.engineer_fleet_trips;
CREATE POLICY eft_engineer_own_insert ON public.engineer_fleet_trips
  FOR INSERT TO authenticated WITH CHECK (engineer_user_id = auth.uid());

-- =========================================================================
-- RPC 1: founder_engineer_fleet_summary (16 KPIs)
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_fleet_summary();
CREATE OR REPLACE FUNCTION public.founder_engineer_fleet_summary()
RETURNS TABLE (
  vehicles_total int,
  vehicles_active int,
  vehicles_maintenance int,
  vehicles_retired int,
  vehicles_damaged_lost int,
  engineers_with_vehicle int,
  company_owned_count int,
  engineer_owned_count int,
  rental_count int,
  trips_total int,
  trips_30d int,
  trips_90d int,
  total_distance_km numeric,
  total_fuel_cost_rupees numeric,
  insurance_expiring_30d int,
  puc_expiring_30d int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE status = 'active'),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE status = 'maintenance'),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE status = 'retired'),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE status IN ('damaged','lost')),
    (SELECT COUNT(DISTINCT engineer_user_id)::int FROM public.engineer_fleet_vehicles),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE ownership_kind = 'company_owned'),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE ownership_kind = 'engineer_owned'),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE ownership_kind IN ('rental_monthly','rental_per_visit')),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_trips),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_trips WHERE created_at >= now() - interval '30 days'),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_trips WHERE created_at >= now() - interval '90 days'),
    COALESCE((SELECT SUM(distance_km) FROM public.engineer_fleet_trips), 0),
    COALESCE((SELECT SUM(fuel_cost_rupees) FROM public.engineer_fleet_trips), 0),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE insurance_expiry IS NOT NULL AND insurance_expiry <= (current_date + interval '30 days')::date AND insurance_expiry >= current_date),
    (SELECT COUNT(*)::int FROM public.engineer_fleet_vehicles WHERE puc_expiry IS NOT NULL AND puc_expiry <= (current_date + interval '30 days')::date AND puc_expiry >= current_date);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_fleet_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_fleet_summary() TO authenticated;

-- =========================================================================
-- RPC 2: founder_engineer_fleet_vehicles_recent
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_fleet_vehicles_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_fleet_vehicles_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  vehicle_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  vehicle_kind text,
  registration_number text,
  make_model text,
  ownership_kind text,
  status text,
  allotted_at date,
  insurance_expiry date,
  puc_expiry date,
  last_service_at date,
  total_odometer_km int,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT v.id, v.engineer_user_id, u.email::text, v.vehicle_kind, v.registration_number, v.make_model,
         v.ownership_kind, v.status, v.allotted_at, v.insurance_expiry, v.puc_expiry, v.last_service_at,
         v.total_odometer_km, v.created_at
  FROM public.engineer_fleet_vehicles v
  LEFT JOIN auth.users u ON u.id = v.engineer_user_id
  ORDER BY v.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_fleet_vehicles_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_fleet_vehicles_recent(int) TO authenticated;

-- =========================================================================
-- RPC 3: founder_engineer_fleet_trips_recent
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_fleet_trips_recent(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_fleet_trips_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  trip_id uuid,
  vehicle_id uuid,
  engineer_user_id uuid,
  engineer_email text,
  registration_number text,
  trip_purpose text,
  repair_job_id uuid,
  distance_km numeric,
  fuel_cost_rupees numeric,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT t.id, t.vehicle_id, t.engineer_user_id, u.email::text, v.registration_number,
         t.trip_purpose, t.repair_job_id, t.distance_km, t.fuel_cost_rupees,
         t.started_at, t.ended_at, t.created_at
  FROM public.engineer_fleet_trips t
  LEFT JOIN public.engineer_fleet_vehicles v ON v.id = t.vehicle_id
  LEFT JOIN auth.users u ON u.id = t.engineer_user_id
  ORDER BY t.created_at DESC
  LIMIT COALESCE(p_limit, 50);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_fleet_trips_recent(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_fleet_trips_recent(int) TO authenticated;

-- =========================================================================
-- RPC 4: founder_engineer_fleet_expiring_docs
-- =========================================================================
DROP FUNCTION IF EXISTS public.founder_engineer_fleet_expiring_docs(int);
CREATE OR REPLACE FUNCTION public.founder_engineer_fleet_expiring_docs(p_days int DEFAULT 30)
RETURNS TABLE (
  vehicle_id uuid,
  engineer_email text,
  registration_number text,
  make_model text,
  doc_kind text,
  expires_on date,
  days_until_expiry int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT v.id, u.email::text, v.registration_number, v.make_model,
         'insurance'::text, v.insurance_expiry,
         (v.insurance_expiry - current_date)::int
  FROM public.engineer_fleet_vehicles v
  LEFT JOIN auth.users u ON u.id = v.engineer_user_id
  WHERE v.insurance_expiry IS NOT NULL
    AND v.insurance_expiry <= (current_date + (COALESCE(p_days, 30) || ' days')::interval)::date
  UNION ALL
  SELECT v.id, u.email::text, v.registration_number, v.make_model,
         'puc'::text, v.puc_expiry,
         (v.puc_expiry - current_date)::int
  FROM public.engineer_fleet_vehicles v
  LEFT JOIN auth.users u ON u.id = v.engineer_user_id
  WHERE v.puc_expiry IS NOT NULL
    AND v.puc_expiry <= (current_date + (COALESCE(p_days, 30) || ' days')::interval)::date
  ORDER BY expires_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_engineer_fleet_expiring_docs(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_engineer_fleet_expiring_docs(int) TO authenticated;

-- =========================================================================
-- RPC 5: engineer_fleet_my_vehicle (engineer auth)
-- =========================================================================
DROP FUNCTION IF EXISTS public.engineer_fleet_my_vehicle();
CREATE OR REPLACE FUNCTION public.engineer_fleet_my_vehicle()
RETURNS TABLE (
  vehicle_id uuid,
  vehicle_kind text,
  registration_number text,
  make_model text,
  ownership_kind text,
  status text,
  insurance_expiry date,
  puc_expiry date,
  total_odometer_km int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT v.id, v.vehicle_kind, v.registration_number, v.make_model,
         v.ownership_kind, v.status, v.insurance_expiry, v.puc_expiry, v.total_odometer_km
  FROM public.engineer_fleet_vehicles v
  WHERE v.engineer_user_id = auth.uid()
  LIMIT 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_fleet_my_vehicle() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_fleet_my_vehicle() TO authenticated;

-- =========================================================================
-- RPC 6: log_founder_fleet_register_vehicle (founder write)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_fleet_register_vehicle(uuid, text, text, text, text, date);
CREATE OR REPLACE FUNCTION public.log_founder_fleet_register_vehicle(
  p_engineer_user_id uuid,
  p_vehicle_kind text,
  p_registration_number text,
  p_make_model text,
  p_ownership_kind text,
  p_allotted_at date DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.engineer_fleet_vehicles(
    engineer_user_id, vehicle_kind, registration_number, make_model, ownership_kind, allotted_at, status
  ) VALUES (
    p_engineer_user_id, p_vehicle_kind, p_registration_number, p_make_model,
    COALESCE(p_ownership_kind, 'engineer_owned'), p_allotted_at, 'active'
  )
  ON CONFLICT (engineer_user_id) DO UPDATE
    SET vehicle_kind = EXCLUDED.vehicle_kind,
        registration_number = EXCLUDED.registration_number,
        make_model = EXCLUDED.make_model,
        ownership_kind = EXCLUDED.ownership_kind,
        allotted_at = COALESCE(EXCLUDED.allotted_at, public.engineer_fleet_vehicles.allotted_at),
        updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_fleet_register_vehicle(uuid, text, text, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_fleet_register_vehicle(uuid, text, text, text, text, date) TO authenticated;

-- =========================================================================
-- RPC 7: log_founder_fleet_record_trip (founder write)
-- =========================================================================
DROP FUNCTION IF EXISTS public.log_founder_fleet_record_trip(uuid, text, numeric, numeric, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_fleet_record_trip(
  p_vehicle_id uuid,
  p_trip_purpose text,
  p_distance_km numeric,
  p_fuel_cost_rupees numeric DEFAULT 0,
  p_repair_job_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_engineer uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  SELECT engineer_user_id INTO v_engineer FROM public.engineer_fleet_vehicles WHERE id = p_vehicle_id;
  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'vehicle not found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.engineer_fleet_trips(
    vehicle_id, engineer_user_id, trip_purpose, distance_km, fuel_cost_rupees, repair_job_id, started_at, ended_at
  ) VALUES (
    p_vehicle_id, v_engineer, p_trip_purpose, COALESCE(p_distance_km, 0),
    COALESCE(p_fuel_cost_rupees, 0), p_repair_job_id, now(), now()
  )
  RETURNING id INTO v_id;
  UPDATE public.engineer_fleet_vehicles
    SET total_odometer_km = total_odometer_km + COALESCE(p_distance_km, 0)::int,
        updated_at = now()
  WHERE id = p_vehicle_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_fleet_record_trip(uuid, text, numeric, numeric, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_fleet_record_trip(uuid, text, numeric, numeric, uuid) TO authenticated;

COMMIT;