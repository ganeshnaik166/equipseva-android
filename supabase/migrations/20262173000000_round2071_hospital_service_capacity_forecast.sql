BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_capacity_forecast_r2071 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  forecast_month_label text NOT NULL,
  predicted_demand_jobs int NOT NULL DEFAULT 0,
  available_capacity_jobs int NOT NULL DEFAULT 0,
  capacity_gap int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'forecast' CHECK (status IN ('forecast','actualized','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_capacity_action_log_r2071 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  forecast_id uuid NOT NULL REFERENCES public.hospital_service_capacity_forecast_r2071(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('engineer_hired','transferred','declined_jobs','escalated','recovered')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_service_capacity_forecast_r2071 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_capacity_action_log_r2071 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hscf_r2071 ON public.hospital_service_capacity_forecast_r2071;
CREATE POLICY founder_all_hscf_r2071 ON public.hospital_service_capacity_forecast_r2071
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hcal_r2071 ON public.hospital_capacity_action_log_r2071;
CREATE POLICY founder_all_hcal_r2071 ON public.hospital_capacity_action_log_r2071
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_hscf_r2071_hospital ON public.hospital_service_capacity_forecast_r2071(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hscf_r2071_status ON public.hospital_service_capacity_forecast_r2071(status);
CREATE INDEX IF NOT EXISTS idx_hcal_r2071_forecast ON public.hospital_capacity_action_log_r2071(forecast_id);
CREATE INDEX IF NOT EXISTS idx_hcal_r2071_action ON public.hospital_capacity_action_log_r2071(action_type);

-- RPC 1: list_forecasts
DROP FUNCTION IF EXISTS public.list_forecasts_r2071();
CREATE OR REPLACE FUNCTION public.list_forecasts_r2071()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  forecast_month_label text,
  predicted_demand_jobs int,
  available_capacity_jobs int,
  capacity_gap int,
  status text,
  captured_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.hospital_id,
    COALESCE(o.name, p.email, 'unknown')::text AS hospital_name,
    f.forecast_month_label, f.predicted_demand_jobs, f.available_capacity_jobs,
    f.capacity_gap, f.status, f.captured_at
  FROM public.hospital_service_capacity_forecast_r2071 f
  LEFT JOIN public.profiles p ON p.id = f.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY f.captured_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: log_forecast
DROP FUNCTION IF EXISTS public.log_forecast_r2071(uuid, text, int, int, int, text);
CREATE OR REPLACE FUNCTION public.log_forecast_r2071(
  p_hospital_id uuid,
  p_month_label text,
  p_predicted int,
  p_capacity int,
  p_gap int,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_capacity_forecast_r2071
    (hospital_id, forecast_month_label, predicted_demand_jobs, available_capacity_jobs, capacity_gap, status)
  VALUES (p_hospital_id, p_month_label, p_predicted, p_capacity, p_gap, COALESCE(p_status,'forecast'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_forecast_r2071',
    jsonb_build_object('forecast_id', v_id, 'hospital_id', p_hospital_id, 'month', p_month_label, 'gap', p_gap));
  RETURN v_id;
END;
$$;

-- RPC 3: list_actions
DROP FUNCTION IF EXISTS public.list_actions_r2071(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2071(p_forecast_id uuid)
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.forecast_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_capacity_action_log_r2071 a
  WHERE a.forecast_id = p_forecast_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

-- RPC 4: log_action
DROP FUNCTION IF EXISTS public.log_action_r2071(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2071(
  p_forecast_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_capacity_action_log_r2071
    (forecast_id, action_type, by_email, notes_md)
  VALUES (p_forecast_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2071',
    jsonb_build_object('action_id', v_id, 'forecast_id', p_forecast_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
DROP FUNCTION IF EXISTS public.mark_status_r2071(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2071(p_forecast_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_capacity_forecast_r2071
  SET status = p_status, updated_at = now()
  WHERE id = p_forecast_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2071',
    jsonb_build_object('forecast_id', p_forecast_id, 'status', p_status));
END;
$$;

-- RPC 6: capacity_gaps
DROP FUNCTION IF EXISTS public.capacity_gaps_r2071();
CREATE OR REPLACE FUNCTION public.capacity_gaps_r2071()
RETURNS TABLE (
  hospital_id uuid,
  hospital_name text,
  total_forecasts bigint,
  avg_gap numeric,
  max_gap int,
  latest_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.hospital_id,
    COALESCE(o.name, p.email, 'unknown')::text AS hospital_name,
    COUNT(*)::bigint AS total_forecasts,
    ROUND(AVG(f.capacity_gap)::numeric, 2) AS avg_gap,
    MAX(f.capacity_gap) AS max_gap,
    (SELECT f2.status FROM public.hospital_service_capacity_forecast_r2071 f2
     WHERE f2.hospital_id = f.hospital_id ORDER BY f2.captured_at DESC LIMIT 1) AS latest_status
  FROM public.hospital_service_capacity_forecast_r2071 f
  LEFT JOIN public.profiles p ON p.id = f.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  GROUP BY f.hospital_id, o.name, p.email
  ORDER BY avg_gap DESC NULLS LAST
  LIMIT 100;
END;
$$;

-- RPC 7: recent_actions
DROP FUNCTION IF EXISTS public.recent_actions_r2071();
CREATE OR REPLACE FUNCTION public.recent_actions_r2071()
RETURNS TABLE (
  id uuid,
  forecast_id uuid,
  hospital_name text,
  forecast_month_label text,
  action_type text,
  taken_at timestamptz,
  by_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.forecast_id,
    COALESCE(o.name, p.email, 'unknown')::text AS hospital_name,
    f.forecast_month_label, a.action_type, a.taken_at, a.by_email
  FROM public.hospital_capacity_action_log_r2071 a
  JOIN public.hospital_service_capacity_forecast_r2071 f ON f.id = a.forecast_id
  LEFT JOIN public.profiles p ON p.id = f.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_forecasts_r2071() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_forecast_r2071(uuid, text, int, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2071(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2071(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2071(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.capacity_gaps_r2071() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2071() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_forecasts_r2071() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_forecast_r2071(uuid, text, int, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2071(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2071(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2071(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.capacity_gaps_r2071() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2071() TO authenticated;

COMMIT;
