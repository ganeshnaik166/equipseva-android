BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_equipment_adoption_tracker_r2139 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  adoption_status text NOT NULL CHECK (adoption_status IN ('evaluating','piloting','active','declined','discontinued')),
  adoption_date date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed_won','closed_lost','superseded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_adopt_r2139_hosp ON public.hospital_equipment_adoption_tracker_r2139(hospital_id);
CREATE INDEX IF NOT EXISTS idx_adopt_r2139_status ON public.hospital_equipment_adoption_tracker_r2139(status);
CREATE INDEX IF NOT EXISTS idx_adopt_r2139_adoption_status ON public.hospital_equipment_adoption_tracker_r2139(adoption_status);

CREATE TABLE IF NOT EXISTS public.hospital_adoption_action_log_r2139 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  adoption_id uuid NOT NULL REFERENCES public.hospital_equipment_adoption_tracker_r2139(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('evaluation_started','pilot_started','adopted','declined','discontinued','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_adopt_actlog_r2139_adopt ON public.hospital_adoption_action_log_r2139(adoption_id);
CREATE INDEX IF NOT EXISTS idx_adopt_actlog_r2139_taken ON public.hospital_adoption_action_log_r2139(taken_at DESC);

ALTER TABLE public.hospital_equipment_adoption_tracker_r2139 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_adoption_action_log_r2139 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS adopt_r2139_founder_all ON public.hospital_equipment_adoption_tracker_r2139;
CREATE POLICY adopt_r2139_founder_all ON public.hospital_equipment_adoption_tracker_r2139
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS adopt_actlog_r2139_founder_all ON public.hospital_adoption_action_log_r2139;
CREATE POLICY adopt_actlog_r2139_founder_all ON public.hospital_adoption_action_log_r2139
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_adoptions_r2139()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, equipment_label text, adoption_status text, adoption_date date, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_id, COALESCE(o.name, p.email, 'unknown'), a.equipment_label, a.adoption_status, a.adoption_date, a.status, a.captured_at
  FROM public.hospital_equipment_adoption_tracker_r2139 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY a.captured_at DESC
  LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_adoption_r2139(p_hospital_id uuid, p_equipment_label text, p_adoption_status text, p_adoption_date date)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_equipment_adoption_tracker_r2139(hospital_id, equipment_label, adoption_status, adoption_date)
  VALUES (p_hospital_id, p_equipment_label, p_adoption_status, p_adoption_date)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_adoption_r2139', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'equipment_label', p_equipment_label));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2139(p_adoption_id uuid)
RETURNS TABLE(id uuid, adoption_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.adoption_id, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_adoption_action_log_r2139 l
  WHERE (p_adoption_id IS NULL OR l.adoption_id = p_adoption_id)
  ORDER BY l.taken_at DESC
  LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2139(p_adoption_id uuid, p_action_type text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_adoption_action_log_r2139(adoption_id, action_type, by_email, notes_md)
  VALUES (p_adoption_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2139', jsonb_build_object('id', v_id, 'adoption_id', p_adoption_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2139(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_adoption_tracker_r2139 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2139', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.active_pilots_r2139()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, equipment_label text, adoption_status text, adoption_date date, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_id, COALESCE(o.name, p.email, 'unknown'), a.equipment_label, a.adoption_status, a.adoption_date, a.captured_at
  FROM public.hospital_equipment_adoption_tracker_r2139 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE a.status = 'active' AND a.adoption_status IN ('evaluating','piloting')
  ORDER BY a.captured_at DESC
  LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2139()
RETURNS TABLE(id uuid, adoption_id uuid, equipment_label text, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.adoption_id, a.equipment_label, l.action_type, l.taken_at, l.by_email, l.notes_md
  FROM public.hospital_adoption_action_log_r2139 l
  LEFT JOIN public.hospital_equipment_adoption_tracker_r2139 a ON a.id = l.adoption_id
  ORDER BY l.taken_at DESC
  LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_adoptions_r2139() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_adoption_r2139(uuid, text, text, date) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2139(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2139(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2139(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_pilots_r2139() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2139() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_adoptions_r2139() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_adoption_r2139(uuid, text, text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2139(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2139(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2139(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_pilots_r2139() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2139() TO authenticated;

COMMIT;
