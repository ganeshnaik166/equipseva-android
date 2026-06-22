BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_cancellation_heatmap_r1991 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  region_label text NOT NULL,
  day_of_week text NOT NULL CHECK (day_of_week IN ('mon','tue','wed','thu','fri','sat','sun')),
  cancellation_count int NOT NULL DEFAULT 0,
  sample_period_label text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','archived')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_cancellation_pattern_log_r1991 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  heatmap_id uuid NOT NULL REFERENCES public.hospital_service_cancellation_heatmap_r1991(id) ON DELETE CASCADE,
  pattern_type text NOT NULL CHECK (pattern_type IN ('spike','recurring','spike_resolved','no_pattern','escalation')),
  observed_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_service_cancellation_heatmap_r1991 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_cancellation_pattern_log_r1991 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_heatmap_r1991 ON public.hospital_service_cancellation_heatmap_r1991;
CREATE POLICY founder_all_heatmap_r1991 ON public.hospital_service_cancellation_heatmap_r1991
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_pattern_r1991 ON public.hospital_cancellation_pattern_log_r1991;
CREATE POLICY founder_all_pattern_r1991 ON public.hospital_cancellation_pattern_log_r1991
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_heatmaps_r1991()
RETURNS SETOF public.hospital_service_cancellation_heatmap_r1991
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_service_cancellation_heatmap_r1991 ORDER BY captured_at DESC LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_heatmap_r1991(
  p_hospital_id uuid,
  p_region_label text,
  p_day_of_week text,
  p_cancellation_count int,
  p_sample_period_label text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_cancellation_heatmap_r1991(hospital_id, region_label, day_of_week, cancellation_count, sample_period_label)
  VALUES (p_hospital_id, p_region_label, p_day_of_week, p_cancellation_count, p_sample_period_label)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_heatmap_r1991', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'count', p_cancellation_count));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_patterns_r1991(p_heatmap_id uuid)
RETURNS SETOF public.hospital_cancellation_pattern_log_r1991
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_cancellation_pattern_log_r1991 WHERE heatmap_id = p_heatmap_id ORDER BY observed_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_pattern_r1991(
  p_heatmap_id uuid,
  p_pattern_type text,
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
  INSERT INTO public.hospital_cancellation_pattern_log_r1991(heatmap_id, pattern_type, by_email, notes_md)
  VALUES (p_heatmap_id, p_pattern_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pattern_r1991', jsonb_build_object('id', v_id, 'heatmap_id', p_heatmap_id, 'pattern', p_pattern_type));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r1991(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_cancellation_heatmap_r1991 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1991', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.spike_zones_r1991()
RETURNS TABLE(region_label text, day_of_week text, total_cancellations bigint, hotspots bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.region_label, h.day_of_week, SUM(h.cancellation_count)::bigint, COUNT(*) FILTER (WHERE h.cancellation_count >= 5)::bigint
  FROM public.hospital_service_cancellation_heatmap_r1991 h
  WHERE h.status = 'active'
  GROUP BY h.region_label, h.day_of_week
  ORDER BY SUM(h.cancellation_count) DESC
  LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_patterns_r1991()
RETURNS SETOF public.hospital_cancellation_pattern_log_r1991
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_cancellation_pattern_log_r1991 ORDER BY observed_at DESC LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_heatmaps_r1991() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_heatmap_r1991(uuid, text, text, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_patterns_r1991(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pattern_r1991(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1991(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.spike_zones_r1991() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_patterns_r1991() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_heatmaps_r1991() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_heatmap_r1991(uuid, text, text, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_patterns_r1991(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pattern_r1991(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1991(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.spike_zones_r1991() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_patterns_r1991() TO authenticated;

COMMIT;
