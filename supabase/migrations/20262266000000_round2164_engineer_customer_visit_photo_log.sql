BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_customer_visit_photo_log_r2164 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  visit_date date NOT NULL DEFAULT CURRENT_DATE,
  photo_url text NOT NULL,
  photo_purpose text NOT NULL CHECK (photo_purpose IN ('repair_before','repair_after','site_documentation','team_photo','customer_thank_you')),
  status text NOT NULL DEFAULT 'captured' CHECK (status IN ('captured','used_for_marketing','restricted','deleted')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_photo_action_log_r2164 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid NOT NULL REFERENCES public.engineer_customer_visit_photo_log_r2164(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('approved','marketing_used','restricted','deleted','escalated')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_customer_visit_photo_log_r2164 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_photo_action_log_r2164 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ecvpl_r2164 ON public.engineer_customer_visit_photo_log_r2164;
CREATE POLICY founder_all_ecvpl_r2164 ON public.engineer_customer_visit_photo_log_r2164
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_epal_r2164 ON public.engineer_photo_action_log_r2164;
CREATE POLICY founder_all_epal_r2164 ON public.engineer_photo_action_log_r2164
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_photos_r2164()
RETURNS TABLE(id uuid, engineer_user_id uuid, hospital_id uuid, visit_date date, photo_url text, photo_purpose text, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.engineer_user_id, p.hospital_id, p.visit_date, p.photo_url, p.photo_purpose, p.status, p.captured_at
  FROM public.engineer_customer_visit_photo_log_r2164 p ORDER BY p.captured_at DESC LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_photos_r2164() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_photos_r2164() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_photo_r2164(p_engineer uuid, p_hospital uuid, p_url text, p_purpose text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_customer_visit_photo_log_r2164(engineer_user_id, hospital_id, photo_url, photo_purpose)
  VALUES (p_engineer, p_hospital, p_url, p_purpose) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_photo_r2164', jsonb_build_object('photo_id', v_id, 'purpose', p_purpose));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_photo_r2164(uuid, uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_photo_r2164(uuid, uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2164(p_photo uuid)
RETURNS TABLE(id uuid, photo_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.photo_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_photo_action_log_r2164 a WHERE a.photo_id = p_photo ORDER BY a.taken_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2164(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2164(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2164(p_photo uuid, p_action text, p_notes text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.engineer_photo_action_log_r2164(photo_id, action_type, by_email, notes_md)
  VALUES (p_photo, p_action, v_email, p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'log_action_r2164', jsonb_build_object('action_id', v_id, 'photo_id', p_photo, 'action_type', p_action));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2164(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2164(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2164(p_photo uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_customer_visit_photo_log_r2164 SET status = p_status, updated_at = now() WHERE id = p_photo;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2164', jsonb_build_object('photo_id', p_photo, 'status', p_status));
END $$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2164(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2164(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.marketing_approved_r2164()
RETURNS TABLE(id uuid, engineer_user_id uuid, hospital_id uuid, photo_url text, photo_purpose text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT p.id, p.engineer_user_id, p.hospital_id, p.photo_url, p.photo_purpose, p.captured_at
  FROM public.engineer_customer_visit_photo_log_r2164 p WHERE p.status = 'used_for_marketing' ORDER BY p.captured_at DESC LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.marketing_approved_r2164() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.marketing_approved_r2164() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2164()
RETURNS TABLE(id uuid, photo_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.photo_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.engineer_photo_action_log_r2164 a ORDER BY a.taken_at DESC LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2164() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2164() TO authenticated;

COMMIT;
