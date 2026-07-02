BEGIN;

-- Table 1: engineer driver + vehicle assignments (current state per engineer)
CREATE TABLE IF NOT EXISTS public.engineer_driver_vehicle_log_r2278 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  city text NOT NULL,
  vehicle_reg_no text NOT NULL,
  vehicle_make_model text NOT NULL,
  vehicle_type text NOT NULL CHECK (vehicle_type IN ('bike','scooter','sedan','suv','van','tempo','truck')),
  ownership text NOT NULL CHECK (ownership IN ('engineer_owned','company_owned','leased','rented')),
  driver_name text,
  driver_phone text,
  driver_license_no text,
  has_dedicated_driver boolean NOT NULL DEFAULT false,
  monthly_kms int NOT NULL DEFAULT 0,
  monthly_fuel_cost_rupees bigint NOT NULL DEFAULT 0,
  monthly_driver_cost_rupees bigint NOT NULL DEFAULT 0,
  last_service_at date,
  next_service_due_at date,
  insurance_expiry date,
  puc_expiry date,
  status text NOT NULL CHECK (status IN ('active','in_service','breakdown','retired')) DEFAULT 'active',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_edvl_r2278_engineer ON public.engineer_driver_vehicle_log_r2278(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_edvl_r2278_status ON public.engineer_driver_vehicle_log_r2278(status);
CREATE INDEX IF NOT EXISTS idx_edvl_r2278_next_service ON public.engineer_driver_vehicle_log_r2278(next_service_due_at);

ALTER TABLE public.engineer_driver_vehicle_log_r2278 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS edvl_r2278_founder_all ON public.engineer_driver_vehicle_log_r2278;
CREATE POLICY edvl_r2278_founder_all ON public.engineer_driver_vehicle_log_r2278
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: vehicle downtime / service events log
CREATE TABLE IF NOT EXISTS public.engineer_vehicle_downtime_r2278 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  engineer_name text NOT NULL,
  vehicle_reg_no text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('routine_service','breakdown','accident','insurance_renewal','puc_renewal','tyre_change','battery_change')),
  started_at timestamptz NOT NULL,
  ended_at timestamptz,
  downtime_hours numeric(8,2) NOT NULL DEFAULT 0,
  cost_rupees bigint NOT NULL DEFAULT 0,
  jobs_missed int NOT NULL DEFAULT 0,
  revenue_impact_rupees bigint NOT NULL DEFAULT 0,
  vendor_name text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_evd_r2278_engineer ON public.engineer_vehicle_downtime_r2278(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_evd_r2278_started ON public.engineer_vehicle_downtime_r2278(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_evd_r2278_type ON public.engineer_vehicle_downtime_r2278(event_type);

ALTER TABLE public.engineer_vehicle_downtime_r2278 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS evd_r2278_founder_all ON public.engineer_vehicle_downtime_r2278;
CREATE POLICY evd_r2278_founder_all ON public.engineer_vehicle_downtime_r2278
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_e1 uuid;
  v_e2 uuid;
  v_e3 uuid;
  v_e4 uuid;
  v_e5 uuid;
BEGIN
  SELECT id INTO v_e1 FROM public.profiles WHERE role = 'engineer' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_e2 FROM public.profiles WHERE role = 'engineer' AND id <> COALESCE(v_e1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_e3 FROM public.profiles WHERE role = 'engineer' AND id NOT IN (COALESCE(v_e1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_e2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_e4 FROM public.profiles WHERE role = 'engineer' AND id NOT IN (COALESCE(v_e1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_e2, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_e3, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;
  SELECT id INTO v_e5 FROM public.profiles WHERE role = 'engineer' AND id NOT IN (COALESCE(v_e1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_e2, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_e3, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_e4, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at LIMIT 1;

  IF v_e1 IS NOT NULL THEN
    INSERT INTO public.engineer_driver_vehicle_log_r2278 (engineer_user_id, engineer_name, city, vehicle_reg_no, vehicle_make_model, vehicle_type, ownership, driver_name, driver_phone, driver_license_no, has_dedicated_driver, monthly_kms, monthly_fuel_cost_rupees, monthly_driver_cost_rupees, last_service_at, next_service_due_at, insurance_expiry, puc_expiry, status, notes)
    VALUES (v_e1, 'Ravi Kumar', 'Hyderabad', 'TS09EZ4521', 'Maruti Eeco Cargo', 'van', 'company_owned', 'Mahesh Yadav', '+919876500001', 'DLAP20210054321', true, 2850, 18500, 22000, CURRENT_DATE - 45, CURRENT_DATE + 15, '2026-09-30', '2026-08-15', 'active', 'High-volume route — Apollo + KIMS daily');

    INSERT INTO public.engineer_vehicle_downtime_r2278 (engineer_user_id, engineer_name, vehicle_reg_no, event_type, started_at, ended_at, downtime_hours, cost_rupees, jobs_missed, revenue_impact_rupees, vendor_name, notes)
    VALUES (v_e1, 'Ravi Kumar', 'TS09EZ4521', 'routine_service', now() - interval '46 days', now() - interval '46 days' + interval '6 hours', 6.0, 4500, 1, 8000, 'Nexa Service Banjara', '10k km routine');

    INSERT INTO public.engineer_vehicle_downtime_r2278 (engineer_user_id, engineer_name, vehicle_reg_no, event_type, started_at, ended_at, downtime_hours, cost_rupees, jobs_missed, revenue_impact_rupees, vendor_name, notes)
    VALUES (v_e1, 'Ravi Kumar', 'TS09EZ4521', 'tyre_change', now() - interval '90 days', now() - interval '90 days' + interval '3 hours', 3.0, 18000, 0, 0, 'MRF Showroom', 'All 4 tyres swapped');
  END IF;

  IF v_e2 IS NOT NULL THEN
    INSERT INTO public.engineer_driver_vehicle_log_r2278 (engineer_user_id, engineer_name, city, vehicle_reg_no, vehicle_make_model, vehicle_type, ownership, driver_name, driver_phone, has_dedicated_driver, monthly_kms, monthly_fuel_cost_rupees, monthly_driver_cost_rupees, last_service_at, next_service_due_at, insurance_expiry, puc_expiry, status, notes)
    VALUES (v_e2, 'Suresh Reddy', 'Bengaluru', 'KA03MH8821', 'Honda Activa 6G', 'scooter', 'engineer_owned', NULL, NULL, false, 1200, 4200, 0, CURRENT_DATE - 20, CURRENT_DATE + 70, '2027-01-15', '2026-12-01', 'active', 'Self-driven; agile clinic routes');
  END IF;

  IF v_e3 IS NOT NULL THEN
    INSERT INTO public.engineer_driver_vehicle_log_r2278 (engineer_user_id, engineer_name, city, vehicle_reg_no, vehicle_make_model, vehicle_type, ownership, driver_name, driver_phone, driver_license_no, has_dedicated_driver, monthly_kms, monthly_fuel_cost_rupees, monthly_driver_cost_rupees, last_service_at, next_service_due_at, insurance_expiry, puc_expiry, status, notes)
    VALUES (v_e3, 'Priya Sharma', 'Mumbai', 'MH02CL3344', 'Tata Ace Gold', 'tempo', 'leased', 'Sanjay Patil', '+919876500003', 'DLMH20180012345', true, 3400, 24800, 26000, CURRENT_DATE - 80, CURRENT_DATE - 5, '2026-07-20', '2026-09-10', 'in_service', 'OVERDUE service — currently at workshop');

    INSERT INTO public.engineer_vehicle_downtime_r2278 (engineer_user_id, engineer_name, vehicle_reg_no, event_type, started_at, ended_at, downtime_hours, cost_rupees, jobs_missed, revenue_impact_rupees, vendor_name, notes)
    VALUES (v_e3, 'Priya Sharma', 'MH02CL3344', 'breakdown', now() - interval '3 days', now() - interval '1 day', 28.0, 12500, 4, 32000, 'Tata Concorde Andheri', 'Clutch plate failure — 4 hospital visits rescheduled');

    INSERT INTO public.engineer_vehicle_downtime_r2278 (engineer_user_id, engineer_name, vehicle_reg_no, event_type, started_at, ended_at, downtime_hours, cost_rupees, jobs_missed, revenue_impact_rupees, vendor_name, notes)
    VALUES (v_e3, 'Priya Sharma', 'MH02CL3344', 'routine_service', now() - interval '1 day', NULL, 16.0, 8200, 2, 14000, 'Tata Concorde Andheri', 'In progress; oil + filters');
  END IF;

  IF v_e4 IS NOT NULL THEN
    INSERT INTO public.engineer_driver_vehicle_log_r2278 (engineer_user_id, engineer_name, city, vehicle_reg_no, vehicle_make_model, vehicle_type, ownership, driver_name, driver_phone, has_dedicated_driver, monthly_kms, monthly_fuel_cost_rupees, monthly_driver_cost_rupees, last_service_at, next_service_due_at, insurance_expiry, puc_expiry, status, notes)
    VALUES (v_e4, 'Anil Verma', 'Delhi NCR', 'DL08CAB1290', 'Bajaj Pulsar 150', 'bike', 'engineer_owned', NULL, NULL, false, 1850, 6200, 0, CURRENT_DATE - 10, CURRENT_DATE + 80, '2026-11-22', '2026-10-05', 'active', 'Fast for traffic-heavy Gurgaon corridor');

    INSERT INTO public.engineer_vehicle_downtime_r2278 (engineer_user_id, engineer_name, vehicle_reg_no, event_type, started_at, ended_at, downtime_hours, cost_rupees, jobs_missed, revenue_impact_rupees, vendor_name, notes)
    VALUES (v_e4, 'Anil Verma', 'DL08CAB1290', 'battery_change', now() - interval '15 days', now() - interval '15 days' + interval '2 hours', 2.0, 3200, 0, 0, 'Exide Roadside', 'Old battery dead in morning');
  END IF;

  IF v_e5 IS NOT NULL THEN
    INSERT INTO public.engineer_driver_vehicle_log_r2278 (engineer_user_id, engineer_name, city, vehicle_reg_no, vehicle_make_model, vehicle_type, ownership, driver_name, driver_phone, driver_license_no, has_dedicated_driver, monthly_kms, monthly_fuel_cost_rupees, monthly_driver_cost_rupees, last_service_at, next_service_due_at, insurance_expiry, puc_expiry, status, notes)
    VALUES (v_e5, 'Deepak Mishra', 'Chennai', 'TN10AY7766', 'Mahindra Bolero', 'suv', 'company_owned', 'Karthik Raja', '+919876500005', 'DLTN20190023456', true, 2200, 16800, 21500, CURRENT_DATE - 30, CURRENT_DATE + 30, '2026-06-30', '2026-07-10', 'active', 'Insurance + PUC both due within 30d — RENEW NOW');

    INSERT INTO public.engineer_vehicle_downtime_r2278 (engineer_user_id, engineer_name, vehicle_reg_no, event_type, started_at, ended_at, downtime_hours, cost_rupees, jobs_missed, revenue_impact_rupees, vendor_name, notes)
    VALUES (v_e5, 'Deepak Mishra', 'TN10AY7766', 'accident', now() - interval '120 days', now() - interval '115 days', 96.0, 48000, 8, 64000, 'Mahindra Velachery', 'Minor rear-end at signal; bumper + boot');
  END IF;
END;
$seed$;

-- RPC 1: list vehicles
CREATE OR REPLACE FUNCTION public.r2278_list_vehicles()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  city text,
  vehicle_reg_no text,
  vehicle_make_model text,
  vehicle_type text,
  ownership text,
  driver_name text,
  has_dedicated_driver boolean,
  monthly_kms int,
  monthly_fuel_cost_rupees bigint,
  monthly_driver_cost_rupees bigint,
  last_service_at date,
  next_service_due_at date,
  insurance_expiry date,
  puc_expiry date,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT v.id, v.engineer_name, v.city, v.vehicle_reg_no, v.vehicle_make_model, v.vehicle_type,
         v.ownership, v.driver_name, v.has_dedicated_driver, v.monthly_kms,
         v.monthly_fuel_cost_rupees, v.monthly_driver_cost_rupees,
         v.last_service_at, v.next_service_due_at, v.insurance_expiry, v.puc_expiry, v.status
  FROM public.engineer_driver_vehicle_log_r2278 v
  ORDER BY v.next_service_due_at NULLS LAST, v.engineer_name;
END;
$$;

-- RPC 2: list downtime events
CREATE OR REPLACE FUNCTION public.r2278_list_downtime()
RETURNS TABLE (
  id uuid,
  engineer_name text,
  vehicle_reg_no text,
  event_type text,
  started_at timestamptz,
  ended_at timestamptz,
  downtime_hours numeric,
  cost_rupees bigint,
  jobs_missed int,
  revenue_impact_rupees bigint,
  vendor_name text,
  notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT d.id, d.engineer_name, d.vehicle_reg_no, d.event_type, d.started_at, d.ended_at,
         d.downtime_hours, d.cost_rupees, d.jobs_missed, d.revenue_impact_rupees, d.vendor_name, d.notes
  FROM public.engineer_vehicle_downtime_r2278 d
  ORDER BY d.started_at DESC;
END;
$$;

-- RPC 3: vehicle type mix
CREATE OR REPLACE FUNCTION public.r2278_vehicle_type_mix()
RETURNS TABLE (
  vehicle_type text,
  vehicle_count int,
  with_dedicated_driver int,
  total_monthly_kms bigint,
  total_monthly_fuel_rupees bigint,
  total_monthly_driver_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT v.vehicle_type,
         (COUNT(*))::int AS vehicle_count,
         (COUNT(*) FILTER (WHERE v.has_dedicated_driver))::int AS with_dedicated_driver,
         COALESCE(SUM(v.monthly_kms), 0)::bigint AS total_monthly_kms,
         COALESCE(SUM(v.monthly_fuel_cost_rupees), 0)::bigint AS total_monthly_fuel_rupees,
         COALESCE(SUM(v.monthly_driver_cost_rupees), 0)::bigint AS total_monthly_driver_rupees
  FROM public.engineer_driver_vehicle_log_r2278 v
  GROUP BY v.vehicle_type
  ORDER BY vehicle_count DESC;
END;
$$;

-- RPC 4: compliance alerts (service / insurance / puc due within 30d)
CREATE OR REPLACE FUNCTION public.r2278_compliance_alerts()
RETURNS TABLE (
  engineer_name text,
  vehicle_reg_no text,
  alert_type text,
  due_date date,
  days_remaining int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT v.engineer_name, v.vehicle_reg_no, 'service_due'::text AS alert_type,
         v.next_service_due_at AS due_date,
         (v.next_service_due_at - CURRENT_DATE)::int AS days_remaining
  FROM public.engineer_driver_vehicle_log_r2278 v
  WHERE v.next_service_due_at IS NOT NULL AND v.next_service_due_at <= CURRENT_DATE + 30
  UNION ALL
  SELECT v.engineer_name, v.vehicle_reg_no, 'insurance_expiry'::text,
         v.insurance_expiry,
         (v.insurance_expiry - CURRENT_DATE)::int
  FROM public.engineer_driver_vehicle_log_r2278 v
  WHERE v.insurance_expiry IS NOT NULL AND v.insurance_expiry <= CURRENT_DATE + 30
  UNION ALL
  SELECT v.engineer_name, v.vehicle_reg_no, 'puc_expiry'::text,
         v.puc_expiry,
         (v.puc_expiry - CURRENT_DATE)::int
  FROM public.engineer_driver_vehicle_log_r2278 v
  WHERE v.puc_expiry IS NOT NULL AND v.puc_expiry <= CURRENT_DATE + 30
  ORDER BY days_remaining ASC;
END;
$$;

-- RPC 5: downtime impact by event type
CREATE OR REPLACE FUNCTION public.r2278_downtime_by_type()
RETURNS TABLE (
  event_type text,
  event_count int,
  total_downtime_hours numeric,
  total_cost_rupees bigint,
  total_jobs_missed int,
  total_revenue_impact_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT d.event_type,
         (COUNT(*))::int,
         COALESCE(SUM(d.downtime_hours), 0)::numeric,
         COALESCE(SUM(d.cost_rupees), 0)::bigint,
         COALESCE(SUM(d.jobs_missed), 0)::int,
         COALESCE(SUM(d.revenue_impact_rupees), 0)::bigint
  FROM public.engineer_vehicle_downtime_r2278 d
  GROUP BY d.event_type
  ORDER BY total_revenue_impact_rupees DESC;
END;
$$;

-- RPC 6: KPIs
CREATE OR REPLACE FUNCTION public.r2278_kpis()
RETURNS TABLE (
  total_vehicles int,
  with_dedicated_drivers int,
  active_vehicles int,
  vehicles_in_service int,
  total_monthly_fuel_rupees bigint,
  total_monthly_driver_rupees bigint,
  downtime_hours_90d numeric,
  revenue_impact_90d_rupees bigint,
  jobs_missed_90d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.engineer_driver_vehicle_log_r2278),
    (SELECT (COUNT(*) FILTER (WHERE has_dedicated_driver))::int FROM public.engineer_driver_vehicle_log_r2278),
    (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.engineer_driver_vehicle_log_r2278),
    (SELECT (COUNT(*) FILTER (WHERE status = 'in_service'))::int FROM public.engineer_driver_vehicle_log_r2278),
    (SELECT COALESCE(SUM(monthly_fuel_cost_rupees), 0)::bigint FROM public.engineer_driver_vehicle_log_r2278),
    (SELECT COALESCE(SUM(monthly_driver_cost_rupees), 0)::bigint FROM public.engineer_driver_vehicle_log_r2278),
    (SELECT COALESCE(SUM(downtime_hours), 0)::numeric FROM public.engineer_vehicle_downtime_r2278 WHERE started_at > now() - interval '90 days'),
    (SELECT COALESCE(SUM(revenue_impact_rupees), 0)::bigint FROM public.engineer_vehicle_downtime_r2278 WHERE started_at > now() - interval '90 days'),
    (SELECT COALESCE(SUM(jobs_missed), 0)::int FROM public.engineer_vehicle_downtime_r2278 WHERE started_at > now() - interval '90 days');
END;
$$;

-- RPC 7: recent downtime feed
CREATE OR REPLACE FUNCTION public.r2278_recent_downtime()
RETURNS TABLE (
  engineer_name text,
  vehicle_reg_no text,
  event_type text,
  started_at timestamptz,
  downtime_hours numeric,
  jobs_missed int,
  revenue_impact_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT d.engineer_name, d.vehicle_reg_no, d.event_type, d.started_at, d.downtime_hours,
         d.jobs_missed, d.revenue_impact_rupees
  FROM public.engineer_vehicle_downtime_r2278 d
  WHERE d.started_at > now() - interval '180 days'
  ORDER BY d.started_at DESC
  LIMIT 25;
END;
$$;

REVOKE ALL ON FUNCTION public.r2278_list_vehicles() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2278_list_downtime() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2278_vehicle_type_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2278_compliance_alerts() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2278_downtime_by_type() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2278_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2278_recent_downtime() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2278_list_vehicles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2278_list_downtime() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2278_vehicle_type_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2278_compliance_alerts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2278_downtime_by_type() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2278_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2278_recent_downtime() TO authenticated;

COMMIT;
