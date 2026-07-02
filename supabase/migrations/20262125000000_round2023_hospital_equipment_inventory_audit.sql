BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_equipment_inventory_audit_r2023 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  audit_label text NOT NULL,
  audit_date date NOT NULL,
  equipment_count int NOT NULL DEFAULT 0,
  total_value_rupees bigint NOT NULL DEFAULT 0,
  missing_count int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','completed','escalated','disputed')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_heia_r2023_hospital ON public.hospital_equipment_inventory_audit_r2023(hospital_id);
CREATE INDEX IF NOT EXISTS idx_heia_r2023_status ON public.hospital_equipment_inventory_audit_r2023(status);
CREATE INDEX IF NOT EXISTS idx_heia_r2023_date ON public.hospital_equipment_inventory_audit_r2023(audit_date DESC);

CREATE TABLE IF NOT EXISTS public.hospital_audit_action_log_r2023 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.hospital_equipment_inventory_audit_r2023(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('planned','in_progress','completed','missing_found','disputed','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_haal_r2023_audit ON public.hospital_audit_action_log_r2023(audit_id);
CREATE INDEX IF NOT EXISTS idx_haal_r2023_taken ON public.hospital_audit_action_log_r2023(taken_at DESC);

ALTER TABLE public.hospital_equipment_inventory_audit_r2023 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_audit_action_log_r2023 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS heia_r2023_founder_all ON public.hospital_equipment_inventory_audit_r2023;
CREATE POLICY heia_r2023_founder_all ON public.hospital_equipment_inventory_audit_r2023
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS haal_r2023_founder_all ON public.hospital_audit_action_log_r2023;
CREATE POLICY haal_r2023_founder_all ON public.hospital_audit_action_log_r2023
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_audits_r2023()
RETURNS TABLE(id uuid, hospital_id uuid, audit_label text, audit_date date, equipment_count int, total_value_rupees bigint, missing_count int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.hospital_id, a.audit_label, a.audit_date, a.equipment_count, a.total_value_rupees, a.missing_count, a.status, a.captured_at
    FROM public.hospital_equipment_inventory_audit_r2023 a
    ORDER BY a.audit_date DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_audit_r2023(p_hospital_id uuid, p_audit_label text, p_audit_date date, p_equipment_count int, p_total_value_rupees bigint, p_missing_count int)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_equipment_inventory_audit_r2023(hospital_id, audit_label, audit_date, equipment_count, total_value_rupees, missing_count, status)
    VALUES (p_hospital_id, p_audit_label, p_audit_date, p_equipment_count, p_total_value_rupees, p_missing_count, 'planned')
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_audit_r2023', jsonb_build_object('audit_id', v_id, 'hospital_id', p_hospital_id, 'audit_label', p_audit_label), now());
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2023(p_audit_id uuid)
RETURNS TABLE(id uuid, audit_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.hospital_audit_action_log_r2023 l
    WHERE l.audit_id = p_audit_id
    ORDER BY l.taken_at DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.log_action_r2023(p_audit_id uuid, p_action_type text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_audit_action_log_r2023(audit_id, action_type, by_email, notes_md)
    VALUES (p_audit_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2023', jsonb_build_object('action_id', v_id, 'audit_id', p_audit_id, 'action_type', p_action_type), now());
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2023(p_audit_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_equipment_inventory_audit_r2023 SET status = p_status, updated_at = now() WHERE id = p_audit_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2023', jsonb_build_object('audit_id', p_audit_id, 'status', p_status), now());
END; $$;

CREATE OR REPLACE FUNCTION public.escalated_audits_r2023()
RETURNS TABLE(id uuid, hospital_id uuid, audit_label text, audit_date date, missing_count int, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.hospital_id, a.audit_label, a.audit_date, a.missing_count, a.status
    FROM public.hospital_equipment_inventory_audit_r2023 a
    WHERE a.status IN ('escalated','disputed')
    ORDER BY a.audit_date DESC LIMIT 200;
END; $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2023()
RETURNS TABLE(id uuid, audit_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT l.id, l.audit_id, l.action_type, l.taken_at, l.by_email, l.notes_md
    FROM public.hospital_audit_action_log_r2023 l
    ORDER BY l.taken_at DESC LIMIT 200;
END; $$;

REVOKE EXECUTE ON FUNCTION public.list_audits_r2023() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_audit_r2023(uuid, text, date, int, bigint, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2023(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2023(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2023(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.escalated_audits_r2023() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2023() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_audits_r2023() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_audit_r2023(uuid, text, date, int, bigint, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2023(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2023(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2023(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.escalated_audits_r2023() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2023() TO authenticated;

COMMIT;
