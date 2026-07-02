BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_multi_tenancy_workload_r2048 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  period_label text NOT NULL,
  hospitals_served int NOT NULL DEFAULT 0,
  total_jobs int NOT NULL DEFAULT 0,
  avg_jobs_per_hospital numeric(10,2) NOT NULL DEFAULT 0,
  workload_status text NOT NULL DEFAULT 'balanced' CHECK (workload_status IN ('balanced','concentrated','spread_thin','overloaded')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_workload_action_log_r2048 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workload_id uuid NOT NULL REFERENCES public.engineer_multi_tenancy_workload_r2048(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('rebalanced','concentrated','spread','escalated','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_multi_tenancy_workload_r2048 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_workload_action_log_r2048 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_workload_r2048 ON public.engineer_multi_tenancy_workload_r2048;
CREATE POLICY founder_all_workload_r2048 ON public.engineer_multi_tenancy_workload_r2048
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_action_r2048 ON public.engineer_workload_action_log_r2048;
CREATE POLICY founder_all_action_r2048 ON public.engineer_workload_action_log_r2048
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_workloads_r2048()
RETURNS SETOF public.engineer_multi_tenancy_workload_r2048
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_multi_tenancy_workload_r2048 ORDER BY captured_at DESC LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.log_workload_r2048(
  p_engineer_user_id uuid,
  p_period_label text,
  p_hospitals_served int,
  p_total_jobs int,
  p_avg_jobs_per_hospital numeric,
  p_workload_status text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_multi_tenancy_workload_r2048(engineer_user_id, period_label, hospitals_served, total_jobs, avg_jobs_per_hospital, workload_status)
  VALUES (p_engineer_user_id, p_period_label, p_hospitals_served, p_total_jobs, p_avg_jobs_per_hospital, p_workload_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_workload_r2048', jsonb_build_object('id', v_id, 'engineer_user_id', p_engineer_user_id, 'status', p_workload_status));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_actions_r2048(p_workload_id uuid)
RETURNS SETOF public.engineer_workload_action_log_r2048
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_workload_action_log_r2048 WHERE workload_id = p_workload_id ORDER BY taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_action_r2048(
  p_workload_id uuid,
  p_action_type text,
  p_notes_md text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.engineer_workload_action_log_r2048(workload_id, action_type, by_email, notes_md)
  VALUES (p_workload_id, p_action_type, (auth.jwt()->>'email'), p_notes_md)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2048', jsonb_build_object('id', v_id, 'workload_id', p_workload_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_status_r2048(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.engineer_multi_tenancy_workload_r2048 SET workload_status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2048', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.overloaded_r2048()
RETURNS SETOF public.engineer_multi_tenancy_workload_r2048
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_multi_tenancy_workload_r2048 WHERE workload_status = 'overloaded' ORDER BY captured_at DESC LIMIT 100;
END $$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2048()
RETURNS SETOF public.engineer_workload_action_log_r2048
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.engineer_workload_action_log_r2048 ORDER BY taken_at DESC LIMIT 100;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_workloads_r2048() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_workload_r2048(uuid, text, int, int, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2048(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2048(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2048(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.overloaded_r2048() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2048() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_workloads_r2048() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_workload_r2048(uuid, text, int, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2048(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2048(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2048(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.overloaded_r2048() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2048() TO authenticated;

COMMIT;
