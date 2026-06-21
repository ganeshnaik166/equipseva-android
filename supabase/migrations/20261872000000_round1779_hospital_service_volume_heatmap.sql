BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_service_volume_heatmap_r1779 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  day_of_week int NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  hour_of_day int NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
  avg_service_count numeric NOT NULL DEFAULT 0,
  recorded_window_start date NOT NULL,
  recorded_window_end date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_service_volume_anomalies_r1779 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  window_start date NOT NULL,
  anomaly_type text NOT NULL CHECK (anomaly_type IN ('spike','drop','flatline')),
  severity text NOT NULL CHECK (severity IN ('info','warning','critical')),
  anomaly_text text NOT NULL DEFAULT '',
  detected_at timestamptz NOT NULL DEFAULT now(),
  ack boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.hospital_service_volume_heatmap_r1779 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_volume_anomalies_r1779 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_heatmap_r1779 ON public.hospital_service_volume_heatmap_r1779;
CREATE POLICY founder_all_heatmap_r1779 ON public.hospital_service_volume_heatmap_r1779
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_anomalies_r1779 ON public.hospital_service_volume_anomalies_r1779;
CREATE POLICY founder_all_anomalies_r1779 ON public.hospital_service_volume_anomalies_r1779
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_heatmap
CREATE OR REPLACE FUNCTION public.list_heatmap_r1779()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  day_of_week int,
  hour_of_day int,
  avg_service_count numeric,
  recorded_window_start date,
  recorded_window_end date,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.hospital_user_id, p.email, h.day_of_week, h.hour_of_day,
         h.avg_service_count, h.recorded_window_start, h.recorded_window_end, h.created_at
  FROM public.hospital_service_volume_heatmap_r1779 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  ORDER BY h.hospital_user_id, h.day_of_week, h.hour_of_day
  LIMIT 500;
END;
$$;

-- RPC 2: recompute_heatmap
CREATE OR REPLACE FUNCTION public.recompute_heatmap_r1779(p_hospital_user_id uuid, p_window_start date, p_window_end date)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rows int := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  DELETE FROM public.hospital_service_volume_heatmap_r1779
  WHERE hospital_user_id = p_hospital_user_id
    AND recorded_window_start = p_window_start
    AND recorded_window_end = p_window_end;

  INSERT INTO public.hospital_service_volume_heatmap_r1779
    (hospital_user_id, day_of_week, hour_of_day, avg_service_count, recorded_window_start, recorded_window_end)
  SELECT
    p_hospital_user_id,
    EXTRACT(DOW FROM completed_at)::int,
    EXTRACT(HOUR FROM completed_at)::int,
    COUNT(*)::numeric,
    p_window_start,
    p_window_end
  FROM public.repair_jobs
  WHERE hospital_id = p_hospital_user_id
    AND completed_at IS NOT NULL
    AND completed_at::date BETWEEN p_window_start AND p_window_end
  GROUP BY EXTRACT(DOW FROM completed_at)::int, EXTRACT(HOUR FROM completed_at)::int;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'recompute_heatmap_r1779',
          jsonb_build_object('hospital_user_id', p_hospital_user_id, 'window_start', p_window_start, 'window_end', p_window_end, 'rows', v_rows));

  RETURN v_rows;
END;
$$;

-- RPC 3: list_anomalies
CREATE OR REPLACE FUNCTION public.list_anomalies_r1779()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  window_start date,
  anomaly_type text,
  severity text,
  anomaly_text text,
  detected_at timestamptz,
  ack boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_user_id, p.email, a.window_start, a.anomaly_type, a.severity,
         a.anomaly_text, a.detected_at, a.ack
  FROM public.hospital_service_volume_anomalies_r1779 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  ORDER BY a.detected_at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: raise_anomaly
CREATE OR REPLACE FUNCTION public.raise_anomaly_r1779(
  p_hospital_user_id uuid,
  p_window_start date,
  p_anomaly_type text,
  p_severity text,
  p_anomaly_text text
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

  INSERT INTO public.hospital_service_volume_anomalies_r1779
    (hospital_user_id, window_start, anomaly_type, severity, anomaly_text)
  VALUES (p_hospital_user_id, p_window_start, p_anomaly_type, p_severity, p_anomaly_text)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'raise_anomaly_r1779',
          jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'severity', p_severity, 'anomaly_type', p_anomaly_type));

  RETURN v_id;
END;
$$;

-- RPC 5: ack_anomaly
CREATE OR REPLACE FUNCTION public.ack_anomaly_r1779(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_service_volume_anomalies_r1779
  SET ack = true, updated_at = now()
  WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'ack_anomaly_r1779',
          jsonb_build_object('id', p_id));

  RETURN true;
END;
$$;

-- RPC 6: peak_hours_per_hospital
CREATE OR REPLACE FUNCTION public.peak_hours_per_hospital_r1779()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  peak_day_of_week int,
  peak_hour_of_day int,
  peak_avg_service_count numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (h.hospital_user_id)
    h.hospital_user_id, p.email, h.day_of_week, h.hour_of_day, h.avg_service_count
  FROM public.hospital_service_volume_heatmap_r1779 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  ORDER BY h.hospital_user_id, h.avg_service_count DESC
  LIMIT 200;
END;
$$;

-- RPC 7: critical_anomalies
CREATE OR REPLACE FUNCTION public.critical_anomalies_r1779()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  window_start date,
  anomaly_type text,
  anomaly_text text,
  detected_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_user_id, p.email, a.window_start, a.anomaly_type, a.anomaly_text, a.detected_at
  FROM public.hospital_service_volume_anomalies_r1779 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  WHERE a.severity = 'critical' AND a.ack = false
  ORDER BY a.detected_at DESC
  LIMIT 100;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_heatmap_r1779() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_heatmap_r1779() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.recompute_heatmap_r1779(uuid, date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recompute_heatmap_r1779(uuid, date, date) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.list_anomalies_r1779() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_anomalies_r1779() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.raise_anomaly_r1779(uuid, date, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.raise_anomaly_r1779(uuid, date, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.ack_anomaly_r1779(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ack_anomaly_r1779(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.peak_hours_per_hospital_r1779() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.peak_hours_per_hospital_r1779() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.critical_anomalies_r1779() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.critical_anomalies_r1779() TO authenticated;

COMMIT;