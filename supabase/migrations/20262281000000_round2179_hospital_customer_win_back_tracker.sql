BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_win_back_tracker_r2179 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lost_at date NOT NULL,
  win_back_attempt_count int NOT NULL DEFAULT 0,
  last_attempt_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','recovered','lost','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_win_back_action_log_r2179 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id uuid NOT NULL REFERENCES public.hospital_customer_win_back_tracker_r2179(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('outreach','call','offer','recovered','lost_final','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_win_back_tracker_r2179 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_win_back_action_log_r2179 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2179_tracker ON public.hospital_customer_win_back_tracker_r2179;
CREATE POLICY founder_all_r2179_tracker ON public.hospital_customer_win_back_tracker_r2179
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2179_actions ON public.hospital_win_back_action_log_r2179;
CREATE POLICY founder_all_r2179_actions ON public.hospital_win_back_action_log_r2179
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_r2179_tracker_status ON public.hospital_customer_win_back_tracker_r2179(status);
CREATE INDEX IF NOT EXISTS idx_r2179_tracker_hospital ON public.hospital_customer_win_back_tracker_r2179(hospital_id);
CREATE INDEX IF NOT EXISTS idx_r2179_actions_record ON public.hospital_win_back_action_log_r2179(record_id);
CREATE INDEX IF NOT EXISTS idx_r2179_actions_taken_at ON public.hospital_win_back_action_log_r2179(taken_at DESC);

-- list_records
CREATE OR REPLACE FUNCTION public.r2179_list_records()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, lost_at date, win_back_attempt_count int, last_attempt_at timestamptz, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_id, COALESCE(o.name, p.email, 'unknown')::text AS hospital_name,
         t.lost_at, t.win_back_attempt_count, t.last_attempt_at, t.status, t.captured_at
  FROM public.hospital_customer_win_back_tracker_r2179 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY t.captured_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2179_list_records() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2179_list_records() TO authenticated;

-- log_record
CREATE OR REPLACE FUNCTION public.r2179_log_record(p_hospital_id uuid, p_lost_at date, p_status text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_win_back_tracker_r2179(hospital_id, lost_at, status)
  VALUES (p_hospital_id, p_lost_at, COALESCE(p_status,'active'))
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2179_log_record',
          jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'lost_at', p_lost_at, 'status', p_status));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2179_log_record(uuid, date, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2179_log_record(uuid, date, text) TO authenticated;

-- list_actions
CREATE OR REPLACE FUNCTION public.r2179_list_actions(p_record_id uuid)
RETURNS TABLE(id uuid, record_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.record_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_win_back_action_log_r2179 a
  WHERE a.record_id = p_record_id
  ORDER BY a.taken_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2179_list_actions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2179_list_actions(uuid) TO authenticated;

-- log_action
CREATE OR REPLACE FUNCTION public.r2179_log_action(p_record_id uuid, p_action_type text, p_notes_md text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_win_back_action_log_r2179(record_id, action_type, by_email, notes_md)
  VALUES (p_record_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  UPDATE public.hospital_customer_win_back_tracker_r2179
  SET win_back_attempt_count = win_back_attempt_count + 1,
      last_attempt_at = now(),
      updated_at = now()
  WHERE id = p_record_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2179_log_action',
          jsonb_build_object('id', v_id, 'record_id', p_record_id, 'action_type', p_action_type));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2179_log_action(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2179_log_action(uuid, text, text) TO authenticated;

-- mark_status
CREATE OR REPLACE FUNCTION public.r2179_mark_status(p_record_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_win_back_tracker_r2179
  SET status = p_status, updated_at = now()
  WHERE id = p_record_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2179_mark_status',
          jsonb_build_object('id', p_record_id, 'status', p_status));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2179_mark_status(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2179_mark_status(uuid, text) TO authenticated;

-- active_attempts
CREATE OR REPLACE FUNCTION public.r2179_active_attempts()
RETURNS TABLE(id uuid, hospital_id uuid, hospital_name text, lost_at date, win_back_attempt_count int, last_attempt_at timestamptz, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.hospital_id, COALESCE(o.name, p.email, 'unknown')::text AS hospital_name,
         t.lost_at, t.win_back_attempt_count, t.last_attempt_at, t.status
  FROM public.hospital_customer_win_back_tracker_r2179 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE t.status IN ('active','escalated')
  ORDER BY t.last_attempt_at DESC NULLS LAST
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2179_active_attempts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2179_active_attempts() TO authenticated;

-- recent_actions
CREATE OR REPLACE FUNCTION public.r2179_recent_actions()
RETURNS TABLE(id uuid, record_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.record_id, a.action_type, a.taken_at, a.by_email, a.notes_md
  FROM public.hospital_win_back_action_log_r2179 a
  ORDER BY a.taken_at DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2179_recent_actions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2179_recent_actions() TO authenticated;

COMMIT;
