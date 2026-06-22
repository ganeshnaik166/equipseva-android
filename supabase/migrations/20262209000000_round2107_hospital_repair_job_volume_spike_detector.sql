BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_repair_job_volume_spike_r2107 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  baseline_jobs int NOT NULL DEFAULT 0,
  current_jobs int NOT NULL DEFAULT 0,
  spike_pct numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('normal','spike','declining','resolved','escalated')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_volume_spike_action_log_r2107 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spike_id uuid NOT NULL REFERENCES public.hospital_repair_job_volume_spike_r2107(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('capacity_added','escalated','customer_alerted','closed','resolved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hrjvs_r2107_hospital ON public.hospital_repair_job_volume_spike_r2107(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hrjvs_r2107_status ON public.hospital_repair_job_volume_spike_r2107(status);
CREATE INDEX IF NOT EXISTS idx_hvsal_r2107_spike ON public.hospital_volume_spike_action_log_r2107(spike_id);

ALTER TABLE public.hospital_repair_job_volume_spike_r2107 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_volume_spike_action_log_r2107 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hrjvs_r2107 ON public.hospital_repair_job_volume_spike_r2107;
CREATE POLICY founder_all_hrjvs_r2107 ON public.hospital_repair_job_volume_spike_r2107
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hvsal_r2107 ON public.hospital_volume_spike_action_log_r2107;
CREATE POLICY founder_all_hvsal_r2107 ON public.hospital_volume_spike_action_log_r2107
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_spikes_r2107()
RETURNS TABLE (id uuid, hospital_id uuid, period_label text, baseline_jobs int, current_jobs int, spike_pct numeric, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.hospital_id, s.period_label, s.baseline_jobs, s.current_jobs, s.spike_pct, s.status, s.captured_at
    FROM public.hospital_repair_job_volume_spike_r2107 s ORDER BY s.captured_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_spike_r2107(p_hospital_id uuid, p_period text, p_baseline int, p_current int, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_pct numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_pct := CASE WHEN p_baseline = 0 THEN 0 ELSE ((p_current - p_baseline)::numeric / p_baseline) * 100 END;
  INSERT INTO public.hospital_repair_job_volume_spike_r2107(hospital_id, period_label, baseline_jobs, current_jobs, spike_pct, status)
    VALUES (p_hospital_id, p_period, p_baseline, p_current, v_pct, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2107_log_spike', jsonb_build_object('id', v_id, 'hospital', p_hospital_id, 'pct', v_pct));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2107(p_spike_id uuid)
RETURNS TABLE (id uuid, spike_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.spike_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_volume_spike_action_log_r2107 a WHERE a.spike_id = p_spike_id ORDER BY a.taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2107(p_spike_id uuid, p_action text, p_notes text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_volume_spike_action_log_r2107(spike_id, action_type, by_email, notes_md)
    VALUES (p_spike_id, p_action, (auth.jwt()->>'email'), p_notes) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2107_log_action', jsonb_build_object('id', v_id, 'spike', p_spike_id, 'action', p_action));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2107(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_repair_job_volume_spike_r2107 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2107_mark_status', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.active_spikes_r2107()
RETURNS TABLE (id uuid, hospital_id uuid, period_label text, spike_pct numeric, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT s.id, s.hospital_id, s.period_label, s.spike_pct, s.status, s.captured_at
    FROM public.hospital_repair_job_volume_spike_r2107 s WHERE s.status IN ('spike','escalated') ORDER BY s.spike_pct DESC LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2107()
RETURNS TABLE (id uuid, spike_id uuid, action_type text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.spike_id, a.action_type, a.taken_at, a.by_email
    FROM public.hospital_volume_spike_action_log_r2107 a ORDER BY a.taken_at DESC LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_spikes_r2107() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_spike_r2107(uuid, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2107(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2107(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2107(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.active_spikes_r2107() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2107() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_spikes_r2107() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_spike_r2107(uuid, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2107(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2107(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2107(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.active_spikes_r2107() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2107() TO authenticated;

COMMIT;
