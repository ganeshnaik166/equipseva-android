BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_adoption_velocity_r2167 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  new_features_adopted int NOT NULL DEFAULT 0,
  total_features_used int NOT NULL DEFAULT 0,
  adoption_velocity_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'stable' CHECK (status IN ('accelerating','stable','decelerating','blocked')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_velocity_action_log_r2167 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  velocity_id uuid NOT NULL REFERENCES public.hospital_customer_adoption_velocity_r2167(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','intervention','escalated','blocked_review','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_adoption_velocity_r2167 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_velocity_action_log_r2167 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_velocity_r2167 ON public.hospital_customer_adoption_velocity_r2167;
CREATE POLICY founder_all_velocity_r2167 ON public.hospital_customer_adoption_velocity_r2167
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_velocity_log_r2167 ON public.hospital_velocity_action_log_r2167;
CREATE POLICY founder_all_velocity_log_r2167 ON public.hospital_velocity_action_log_r2167
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_velocity_r2167_hospital ON public.hospital_customer_adoption_velocity_r2167(hospital_id);
CREATE INDEX IF NOT EXISTS idx_velocity_r2167_status ON public.hospital_customer_adoption_velocity_r2167(status);
CREATE INDEX IF NOT EXISTS idx_velocity_log_r2167_velocity ON public.hospital_velocity_action_log_r2167(velocity_id);

DROP FUNCTION IF EXISTS public.list_velocities_r2167();
CREATE OR REPLACE FUNCTION public.list_velocities_r2167()
RETURNS TABLE(id uuid, hospital_id uuid, period_label text, new_features_adopted int, total_features_used int, adoption_velocity_pct numeric, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT v.id, v.hospital_id, v.period_label, v.new_features_adopted, v.total_features_used, v.adoption_velocity_pct, v.status, v.captured_at
    FROM public.hospital_customer_adoption_velocity_r2167 v ORDER BY v.captured_at DESC LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_velocities_r2167() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_velocities_r2167() TO authenticated;

DROP FUNCTION IF EXISTS public.log_velocity_r2167(uuid, text, int, int, numeric, text);
CREATE OR REPLACE FUNCTION public.log_velocity_r2167(p_hospital_id uuid, p_period_label text, p_new int, p_total int, p_pct numeric, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_adoption_velocity_r2167(hospital_id, period_label, new_features_adopted, total_features_used, adoption_velocity_pct, status)
    VALUES (p_hospital_id, p_period_label, p_new, p_total, p_pct, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_velocity_r2167', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'status', p_status));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_velocity_r2167(uuid, text, int, int, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_velocity_r2167(uuid, text, int, int, numeric, text) TO authenticated;

DROP FUNCTION IF EXISTS public.list_actions_r2167(uuid);
CREATE OR REPLACE FUNCTION public.list_actions_r2167(p_velocity_id uuid)
RETURNS TABLE(id uuid, velocity_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.velocity_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_velocity_action_log_r2167 a WHERE a.velocity_id = p_velocity_id ORDER BY a.taken_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2167(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2167(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_action_r2167(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_action_r2167(p_velocity_id uuid, p_action_type text, p_by_email text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_velocity_action_log_r2167(velocity_id, action_type, by_email, notes_md)
    VALUES (p_velocity_id, p_action_type, p_by_email, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2167', jsonb_build_object('id', v_id, 'velocity_id', p_velocity_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2167(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2167(uuid, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.mark_status_r2167(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_r2167(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_adoption_velocity_r2167 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2167', jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2167(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2167(uuid, text) TO authenticated;

DROP FUNCTION IF EXISTS public.accelerating_r2167();
CREATE OR REPLACE FUNCTION public.accelerating_r2167()
RETURNS TABLE(id uuid, hospital_id uuid, period_label text, adoption_velocity_pct numeric, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT v.id, v.hospital_id, v.period_label, v.adoption_velocity_pct, v.captured_at
    FROM public.hospital_customer_adoption_velocity_r2167 v WHERE v.status = 'accelerating' ORDER BY v.adoption_velocity_pct DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.accelerating_r2167() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accelerating_r2167() TO authenticated;

DROP FUNCTION IF EXISTS public.recent_actions_r2167();
CREATE OR REPLACE FUNCTION public.recent_actions_r2167()
RETURNS TABLE(id uuid, velocity_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.velocity_id, a.action_type, a.taken_at, a.by_email
    FROM public.hospital_velocity_action_log_r2167 a ORDER BY a.taken_at DESC LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2167() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2167() TO authenticated;

COMMIT;
