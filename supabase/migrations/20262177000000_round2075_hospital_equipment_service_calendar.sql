BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_equipment_service_calendar_r2075 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  service_due_date date NOT NULL,
  service_interval_days int NOT NULL DEFAULT 90,
  last_service_date date,
  status text NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming','overdue','completed','cancelled','postponed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_service_calendar_action_log_r2075 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id uuid NOT NULL REFERENCES public.hospital_equipment_service_calendar_r2075(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('scheduled','completed','postponed','missed','cancelled')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_equipment_service_calendar_r2075 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_calendar_action_log_r2075 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_calendar_r2075 ON public.hospital_equipment_service_calendar_r2075;
CREATE POLICY founder_all_calendar_r2075 ON public.hospital_equipment_service_calendar_r2075
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_log_r2075 ON public.hospital_service_calendar_action_log_r2075;
CREATE POLICY founder_all_action_log_r2075 ON public.hospital_service_calendar_action_log_r2075
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_services_r2075(p_limit int DEFAULT 200)
RETURNS TABLE (id uuid, hospital_id uuid, equipment_label text, service_due_date date, service_interval_days int, last_service_date date, status text, captured_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_id, s.equipment_label, s.service_due_date, s.service_interval_days, s.last_service_date, s.status, s.captured_at
  FROM public.hospital_equipment_service_calendar_r2075 s
  ORDER BY s.service_due_date ASC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_service_r2075(
  p_hospital_id uuid,
  p_equipment_label text,
  p_service_due_date date,
  p_service_interval_days int,
  p_last_service_date date,
  p_status text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_equipment_service_calendar_r2075 (hospital_id, equipment_label, service_due_date, service_interval_days, last_service_date, status)
  VALUES (p_hospital_id, p_equipment_label, p_service_due_date, COALESCE(p_service_interval_days, 90), p_last_service_date, COALESCE(p_status, 'upcoming'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_service_r2075', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'equipment_label', p_equipment_label));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2075(p_service_id uuid DEFAULT NULL, p_limit int DEFAULT 200)
RETURNS TABLE (id uuid, service_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.service_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_service_calendar_action_log_r2075 a
  WHERE p_service_id IS NULL OR a.service_id = p_service_id
  ORDER BY a.taken_at DESC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2075(
  p_service_id uuid,
  p_action_type text,
  p_by_email text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_calendar_action_log_r2075 (service_id, action_type, by_email, notes_md)
  VALUES (p_service_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2075', jsonb_build_object('id', v_id, 'service_id', p_service_id, 'action_type', p_action_type));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2075(p_service_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_service_calendar_r2075
  SET status = p_status, updated_at = now()
  WHERE id = p_service_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2075', jsonb_build_object('service_id', p_service_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.overdue_services_r2075(p_limit int DEFAULT 200)
RETURNS TABLE (id uuid, hospital_id uuid, equipment_label text, service_due_date date, status text, days_overdue int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_id, s.equipment_label, s.service_due_date, s.status, (CURRENT_DATE - s.service_due_date)::int AS days_overdue
  FROM public.hospital_equipment_service_calendar_r2075 s
  WHERE s.service_due_date < CURRENT_DATE AND s.status NOT IN ('completed','cancelled')
  ORDER BY s.service_due_date ASC
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2075(p_limit int DEFAULT 100)
RETURNS TABLE (id uuid, service_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.service_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_service_calendar_action_log_r2075 a
  ORDER BY a.taken_at DESC
  LIMIT p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_services_r2075(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_service_r2075(uuid, text, date, int, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2075(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2075(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2075(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overdue_services_r2075(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2075(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_services_r2075(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_service_r2075(uuid, text, date, int, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2075(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2075(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2075(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overdue_services_r2075(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2075(int) TO authenticated;

COMMIT;
