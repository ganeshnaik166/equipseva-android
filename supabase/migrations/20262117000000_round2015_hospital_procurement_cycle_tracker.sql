BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_procurement_cycle_r2015 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  cycle_label text NOT NULL,
  cycle_start_date date NOT NULL,
  cycle_end_date date,
  total_value_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'planning' CHECK (status IN ('planning','active','closed','cancelled')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_procurement_phase_log_r2015 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid NOT NULL REFERENCES public.hospital_procurement_cycle_r2015(id) ON DELETE CASCADE,
  phase text NOT NULL CHECK (phase IN ('needs_assessment','rfp','vendor_evaluation','negotiation','award','installation')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_procurement_cycle_r2015 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_procurement_phase_log_r2015 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_cycle_founder_r2015 ON public.hospital_procurement_cycle_r2015;
CREATE POLICY p_cycle_founder_r2015 ON public.hospital_procurement_cycle_r2015
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_phase_founder_r2015 ON public.hospital_procurement_phase_log_r2015;
CREATE POLICY p_phase_founder_r2015 ON public.hospital_procurement_phase_log_r2015
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_cycles_r2015()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  cycle_label text,
  cycle_start_date date,
  cycle_end_date date,
  total_value_rupees bigint,
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
    SELECT c.id, c.hospital_id, c.cycle_label, c.cycle_start_date, c.cycle_end_date,
           c.total_value_rupees, c.status, c.captured_at
      FROM public.hospital_procurement_cycle_r2015 c
     ORDER BY c.captured_at DESC
     LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_cycle_r2015(
  p_hospital_id uuid,
  p_cycle_label text,
  p_cycle_start_date date,
  p_cycle_end_date date,
  p_total_value_rupees bigint,
  p_status text
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
  INSERT INTO public.hospital_procurement_cycle_r2015 (
    hospital_id, cycle_label, cycle_start_date, cycle_end_date, total_value_rupees, status
  ) VALUES (
    p_hospital_id, p_cycle_label, p_cycle_start_date, p_cycle_end_date,
    COALESCE(p_total_value_rupees, 0), COALESCE(p_status, 'planning')
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_cycle_r2015',
          jsonb_build_object('cycle_id', v_id, 'hospital_id', p_hospital_id, 'label', p_cycle_label));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_phases_r2015(p_cycle_id uuid)
RETURNS TABLE (
  id uuid,
  cycle_id uuid,
  phase text,
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
    SELECT p.id, p.cycle_id, p.phase, p.taken_at, p.by_email, p.notes_md
      FROM public.hospital_procurement_phase_log_r2015 p
     WHERE p.cycle_id = p_cycle_id
     ORDER BY p.taken_at DESC
     LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_phase_r2015(
  p_cycle_id uuid,
  p_phase text,
  p_by_email text,
  p_notes_md text
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
  INSERT INTO public.hospital_procurement_phase_log_r2015 (cycle_id, phase, by_email, notes_md)
  VALUES (p_cycle_id, p_phase, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_phase_r2015',
          jsonb_build_object('phase_id', v_id, 'cycle_id', p_cycle_id, 'phase', p_phase));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2015(p_cycle_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_procurement_cycle_r2015
     SET status = p_status, updated_at = now()
   WHERE id = p_cycle_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2015',
          jsonb_build_object('cycle_id', p_cycle_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.active_cycles_r2015()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  cycle_label text,
  cycle_start_date date,
  cycle_end_date date,
  total_value_rupees bigint,
  status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.hospital_id, c.cycle_label, c.cycle_start_date, c.cycle_end_date,
           c.total_value_rupees, c.status
      FROM public.hospital_procurement_cycle_r2015 c
     WHERE c.status = 'active'
     ORDER BY c.cycle_start_date DESC
     LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_phases_r2015()
RETURNS TABLE (
  id uuid,
  cycle_id uuid,
  phase text,
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
    SELECT p.id, p.cycle_id, p.phase, p.taken_at, p.by_email
      FROM public.hospital_procurement_phase_log_r2015 p
     ORDER BY p.taken_at DESC
     LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_cycles_r2015() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_cycle_r2015(uuid, text, date, date, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_phases_r2015(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_phase_r2015(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2015(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_cycles_r2015() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_phases_r2015() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cycles_r2015() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_cycle_r2015(uuid, text, date, date, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_phases_r2015(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_phase_r2015(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2015(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_cycles_r2015() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_phases_r2015() TO authenticated;

COMMIT;
