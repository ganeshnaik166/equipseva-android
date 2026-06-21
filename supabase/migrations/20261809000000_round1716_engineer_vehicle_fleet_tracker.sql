BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_vehicles_r1716 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vehicle_type text NOT NULL CHECK (vehicle_type IN ('bike','car','scooter','auto')),
  registration_number text NOT NULL,
  assigned_on date NOT NULL DEFAULT CURRENT_DATE,
  retired_on date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','maintenance','retired','transferred')),
  total_km int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_vehicle_maintenance_r1716 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id uuid NOT NULL REFERENCES public.engineer_vehicles_r1716(id) ON DELETE CASCADE,
  maintenance_type text NOT NULL CHECK (maintenance_type IN ('service','oil','tire','repair','insurance','fitness')),
  performed_at timestamptz NOT NULL DEFAULT now(),
  cost_rupees int NOT NULL DEFAULT 0,
  next_due_at timestamptz,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_vehicles_r1716 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_vehicle_maintenance_r1716 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_vehicles_r1716 ON public.engineer_vehicles_r1716;
CREATE POLICY founder_all_vehicles_r1716 ON public.engineer_vehicles_r1716
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_maint_r1716 ON public.engineer_vehicle_maintenance_r1716;
CREATE POLICY founder_all_maint_r1716 ON public.engineer_vehicle_maintenance_r1716
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- 1) list_vehicles
CREATE OR REPLACE FUNCTION public.list_vehicles_r1716()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  vehicle_type text,
  registration_number text,
  assigned_on date,
  retired_on date,
  status text,
  total_km int,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.engineer_user_id, p.email, v.vehicle_type, v.registration_number,
           v.assigned_on, v.retired_on, v.status, v.total_km, v.created_at
    FROM public.engineer_vehicles_r1716 v
    LEFT JOIN public.profiles p ON p.id = v.engineer_user_id
    ORDER BY v.created_at DESC
    LIMIT 200;
END;
$$;

-- 2) assign_vehicle
CREATE OR REPLACE FUNCTION public.assign_vehicle_r1716(
  p_engineer_user_id uuid,
  p_vehicle_type text,
  p_registration_number text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_vehicles_r1716 (engineer_user_id, vehicle_type, registration_number)
  VALUES (p_engineer_user_id, p_vehicle_type, p_registration_number)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'assign_vehicle_r1716',
          jsonb_build_object('vehicle_id', v_id, 'engineer_user_id', p_engineer_user_id,
                             'vehicle_type', p_vehicle_type, 'reg', p_registration_number));
  RETURN v_id;
END;
$$;

-- 3) list_maintenance
CREATE OR REPLACE FUNCTION public.list_maintenance_r1716(p_vehicle_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  vehicle_id uuid,
  registration_number text,
  maintenance_type text,
  performed_at timestamptz,
  cost_rupees int,
  next_due_at timestamptz,
  note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.vehicle_id, v.registration_number, m.maintenance_type,
           m.performed_at, m.cost_rupees, m.next_due_at, m.note
    FROM public.engineer_vehicle_maintenance_r1716 m
    JOIN public.engineer_vehicles_r1716 v ON v.id = m.vehicle_id
    WHERE p_vehicle_id IS NULL OR m.vehicle_id = p_vehicle_id
    ORDER BY m.performed_at DESC
    LIMIT 200;
END;
$$;

-- 4) log_maintenance
CREATE OR REPLACE FUNCTION public.log_maintenance_r1716(
  p_vehicle_id uuid,
  p_maintenance_type text,
  p_cost_rupees int,
  p_next_due_at timestamptz,
  p_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_vehicle_maintenance_r1716 (vehicle_id, maintenance_type, cost_rupees, next_due_at, note)
  VALUES (p_vehicle_id, p_maintenance_type, COALESCE(p_cost_rupees, 0), p_next_due_at, p_note)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_maintenance_r1716',
          jsonb_build_object('maint_id', v_id, 'vehicle_id', p_vehicle_id,
                             'type', p_maintenance_type, 'cost_rupees', p_cost_rupees));
  RETURN v_id;
END;
$$;

-- 5) retire_vehicle
CREATE OR REPLACE FUNCTION public.retire_vehicle_r1716(p_vehicle_id uuid, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_vehicles_r1716
     SET status = 'retired', retired_on = CURRENT_DATE, updated_at = now()
   WHERE id = p_vehicle_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'retire_vehicle_r1716',
          jsonb_build_object('vehicle_id', p_vehicle_id, 'reason', p_reason));
END;
$$;

-- 6) upcoming_maintenance
CREATE OR REPLACE FUNCTION public.upcoming_maintenance_r1716()
RETURNS TABLE (
  id uuid,
  vehicle_id uuid,
  registration_number text,
  maintenance_type text,
  next_due_at timestamptz,
  days_until int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.vehicle_id, v.registration_number, m.maintenance_type, m.next_due_at,
           EXTRACT(DAY FROM (m.next_due_at - now()))::int
    FROM public.engineer_vehicle_maintenance_r1716 m
    JOIN public.engineer_vehicles_r1716 v ON v.id = m.vehicle_id
    WHERE m.next_due_at IS NOT NULL AND m.next_due_at >= now()
    ORDER BY m.next_due_at ASC
    LIMIT 100;
END;
$$;

-- 7) fleet_summary
CREATE OR REPLACE FUNCTION public.fleet_summary_r1716()
RETURNS TABLE (
  total_vehicles int,
  active_count int,
  maintenance_count int,
  retired_count int,
  total_maint_spend_rupees bigint,
  upcoming_due_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM public.engineer_vehicles_r1716),
      (SELECT (COUNT(*) FILTER (WHERE status = 'active'))::int FROM public.engineer_vehicles_r1716),
      (SELECT (COUNT(*) FILTER (WHERE status = 'maintenance'))::int FROM public.engineer_vehicles_r1716),
      (SELECT (COUNT(*) FILTER (WHERE status = 'retired'))::int FROM public.engineer_vehicles_r1716),
      (SELECT COALESCE(SUM(cost_rupees), 0)::bigint FROM public.engineer_vehicle_maintenance_r1716),
      (SELECT (COUNT(*) FILTER (WHERE next_due_at IS NOT NULL AND next_due_at >= now() AND next_due_at <= now() + interval '30 days'))::int
       FROM public.engineer_vehicle_maintenance_r1716);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_vehicles_r1716() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assign_vehicle_r1716(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_maintenance_r1716(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_maintenance_r1716(uuid, text, int, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.retire_vehicle_r1716(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_maintenance_r1716() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fleet_summary_r1716() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_vehicles_r1716() TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_vehicle_r1716(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_maintenance_r1716(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_maintenance_r1716(uuid, text, int, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.retire_vehicle_r1716(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_maintenance_r1716() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fleet_summary_r1716() TO authenticated;

COMMIT;