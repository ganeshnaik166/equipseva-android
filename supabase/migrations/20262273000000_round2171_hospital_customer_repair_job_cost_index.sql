BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_repair_job_cost_index_r2171 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  total_jobs int NOT NULL DEFAULT 0,
  total_cost_rupees bigint NOT NULL DEFAULT 0,
  avg_cost_per_job_rupees bigint NOT NULL DEFAULT 0,
  cost_index_pct numeric(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'normal' CHECK (status IN ('below_avg','normal','above_avg','expensive')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_cost_action_log_r2171 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  index_id uuid NOT NULL REFERENCES public.hospital_customer_repair_job_cost_index_r2171(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('celebrated','escalated','closed','reviewed','intervention')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_repair_job_cost_index_r2171 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_cost_action_log_r2171 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2171_idx ON public.hospital_customer_repair_job_cost_index_r2171;
CREATE POLICY founder_all_r2171_idx ON public.hospital_customer_repair_job_cost_index_r2171
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2171_act ON public.hospital_cost_action_log_r2171;
CREATE POLICY founder_all_r2171_act ON public.hospital_cost_action_log_r2171
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_indices_r2171()
RETURNS TABLE(id uuid, hospital_id uuid, period_label text, total_jobs int, total_cost_rupees bigint, avg_cost_per_job_rupees bigint, cost_index_pct numeric, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT i.id, i.hospital_id, i.period_label, i.total_jobs, i.total_cost_rupees, i.avg_cost_per_job_rupees, i.cost_index_pct, i.status, i.captured_at
    FROM public.hospital_customer_repair_job_cost_index_r2171 i ORDER BY i.captured_at DESC LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_indices_r2171() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_indices_r2171() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_index_r2171(p_hospital_id uuid, p_period_label text, p_total_jobs int, p_total_cost_rupees bigint, p_avg_cost_per_job_rupees bigint, p_cost_index_pct numeric, p_status text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_repair_job_cost_index_r2171(hospital_id, period_label, total_jobs, total_cost_rupees, avg_cost_per_job_rupees, cost_index_pct, status)
  VALUES (p_hospital_id, p_period_label, p_total_jobs, p_total_cost_rupees, p_avg_cost_per_job_rupees, p_cost_index_pct, p_status) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_index_r2171', jsonb_build_object('id', v_id, 'hospital_id', p_hospital_id, 'period_label', p_period_label));
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION public.log_index_r2171(uuid, text, int, bigint, bigint, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_index_r2171(uuid, text, int, bigint, bigint, numeric, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.list_actions_r2171(p_index_id uuid)
RETURNS TABLE(id uuid, index_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.index_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_cost_action_log_r2171 a WHERE a.index_id = p_index_id ORDER BY a.taken_at DESC LIMIT 200;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2171(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_actions_r2171(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_action_r2171(p_index_id uuid, p_action_type text, p_by_email text, p_notes_md text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_cost_action_log_r2171(index_id, action_type, by_email, notes_md)
  VALUES (p_index_id, p_action_type, p_by_email, p_notes_md) RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2171', jsonb_build_object('id', v_id, 'index_id', p_index_id, 'action_type', p_action_type));
  RETURN v_id;
END; $$;
REVOKE EXECUTE ON FUNCTION public.log_action_r2171(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_r2171(uuid, text, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_status_r2171(p_index_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_repair_job_cost_index_r2171 SET status = p_status, updated_at = now() WHERE id = p_index_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2171', jsonb_build_object('id', p_index_id, 'status', p_status));
END; $$;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2171(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_r2171(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.expensive_r2171()
RETURNS TABLE(id uuid, hospital_id uuid, period_label text, total_jobs int, avg_cost_per_job_rupees bigint, cost_index_pct numeric, status text, captured_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT i.id, i.hospital_id, i.period_label, i.total_jobs, i.avg_cost_per_job_rupees, i.cost_index_pct, i.status, i.captured_at
    FROM public.hospital_customer_repair_job_cost_index_r2171 i WHERE i.status = 'expensive' ORDER BY i.cost_index_pct DESC LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION public.expensive_r2171() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expensive_r2171() TO authenticated;

CREATE OR REPLACE FUNCTION public.recent_actions_r2171()
RETURNS TABLE(id uuid, index_id uuid, action_type text, taken_at timestamptz, by_email text, notes_md text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.index_id, a.action_type, a.taken_at, a.by_email, a.notes_md
    FROM public.hospital_cost_action_log_r2171 a ORDER BY a.taken_at DESC LIMIT 100;
END; $$;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2171() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2171() TO authenticated;

COMMIT;
