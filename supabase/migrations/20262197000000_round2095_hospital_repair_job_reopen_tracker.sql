BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_repair_job_reopen_tracker_r2095 (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references public.profiles(id) on delete cascade,
  original_repair_job_id uuid,
  reopen_reason text not null check (reopen_reason in ('incomplete_fix','recurrence','customer_request','different_issue','escalation')),
  reopen_count int not null default 1,
  status text not null default 'reopened' check (status in ('reopened','closed','escalated','lost_customer')),
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

CREATE TABLE IF NOT EXISTS public.hospital_reopen_action_log_r2095 (
  id uuid primary key default gen_random_uuid(),
  reopen_id uuid not null references public.hospital_repair_job_reopen_tracker_r2095(id) on delete cascade,
  action_type text not null check (action_type in ('investigated','escalated','refunded','credited','customer_lost')),
  taken_at timestamptz not null default now(),
  by_email text,
  notes_md text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

ALTER TABLE public.hospital_repair_job_reopen_tracker_r2095 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_reopen_action_log_r2095 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_reopen_tracker_r2095 ON public.hospital_repair_job_reopen_tracker_r2095;
CREATE POLICY founder_all_reopen_tracker_r2095 ON public.hospital_repair_job_reopen_tracker_r2095
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_reopen_action_log_r2095 ON public.hospital_reopen_action_log_r2095;
CREATE POLICY founder_all_reopen_action_log_r2095 ON public.hospital_reopen_action_log_r2095
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_reopens_r2095()
RETURNS TABLE (id uuid, hospital_id uuid, original_repair_job_id uuid, reopen_reason text, reopen_count int, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.hospital_id, t.original_repair_job_id, t.reopen_reason, t.reopen_count, t.status, t.captured_at
    FROM public.hospital_repair_job_reopen_tracker_r2095 t ORDER BY t.captured_at DESC LIMIT 500;
END $$;

CREATE OR REPLACE FUNCTION public.log_reopen_r2095(p_hospital_id uuid, p_original_repair_job_id uuid, p_reopen_reason text, p_reopen_count int)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_repair_job_reopen_tracker_r2095 (hospital_id, original_repair_job_id, reopen_reason, reopen_count)
    VALUES (p_hospital_id, p_original_repair_job_id, p_reopen_reason, coalesce(p_reopen_count, 1)) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_reopen_r2095', jsonb_build_object('reopen_id', v_id, 'hospital_id', p_hospital_id, 'reason', p_reopen_reason));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2095(p_reopen_id uuid)
RETURNS TABLE (id uuid, reopen_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.reopen_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_reopen_action_log_r2095 a WHERE a.reopen_id = p_reopen_id ORDER BY a.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2095(p_reopen_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_reopen_action_log_r2095 (reopen_id, action_type, by_email, notes_md)
    VALUES (p_reopen_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2095', jsonb_build_object('action_id', v_id, 'reopen_id', p_reopen_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2095(p_reopen_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_repair_job_reopen_tracker_r2095 SET status = p_status, updated_at = now() WHERE id = p_reopen_id;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2095', jsonb_build_object('reopen_id', p_reopen_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.high_count_r2095()
RETURNS TABLE (id uuid, hospital_id uuid, reopen_count int, status text, reopen_reason text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT t.id, t.hospital_id, t.reopen_count, t.status, t.reopen_reason, t.captured_at
    FROM public.hospital_repair_job_reopen_tracker_r2095 t WHERE t.reopen_count >= 2 ORDER BY t.reopen_count DESC, t.captured_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2095()
RETURNS TABLE (id uuid, reopen_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.reopen_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_reopen_action_log_r2095 a ORDER BY a.taken_at DESC LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_reopens_r2095() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_reopen_r2095(uuid, uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2095(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2095(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2095(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.high_count_r2095() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2095() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_reopens_r2095() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reopen_r2095(uuid, uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2095(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2095(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2095(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.high_count_r2095() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2095() TO authenticated;

COMMIT;
