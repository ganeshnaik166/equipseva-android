BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_workload_distribution_r2080 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_label text NOT NULL,
  period_label text NOT NULL,
  total_jobs int NOT NULL DEFAULT 0,
  active_engineers int NOT NULL DEFAULT 0,
  avg_jobs_per_engineer numeric NOT NULL DEFAULT 0,
  distribution_status text NOT NULL DEFAULT 'balanced' CHECK (distribution_status IN ('balanced','concentrated','skewed','critical')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_distribution_action_log_r2080 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dist_id uuid NOT NULL REFERENCES public.engineer_workload_distribution_r2080(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('rebalanced','escalated','transferred_engineers','hired','closed')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_workload_distribution_r2080 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_distribution_action_log_r2080 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_dist_r2080 ON public.engineer_workload_distribution_r2080;
CREATE POLICY founder_all_dist_r2080 ON public.engineer_workload_distribution_r2080
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_actions_r2080 ON public.engineer_distribution_action_log_r2080;
CREATE POLICY founder_all_actions_r2080 ON public.engineer_distribution_action_log_r2080
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_distributions_r2080()
RETURNS SETOF public.engineer_workload_distribution_r2080
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_workload_distribution_r2080
    ORDER BY captured_at DESC
    LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_distribution_r2080(
  p_region_label text,
  p_period_label text,
  p_total_jobs int,
  p_active_engineers int,
  p_avg_jobs_per_engineer numeric,
  p_distribution_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_workload_distribution_r2080(
    region_label, period_label, total_jobs, active_engineers, avg_jobs_per_engineer, distribution_status
  ) VALUES (
    p_region_label, p_period_label, p_total_jobs, p_active_engineers, p_avg_jobs_per_engineer, p_distribution_status
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_distribution_r2080',
    jsonb_build_object(
      'id', v_id,
      'region', p_region_label,
      'period', p_period_label,
      'total_jobs', p_total_jobs,
      'active_engineers', p_active_engineers,
      'status', p_distribution_status
    )
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r2080(p_dist_id uuid)
RETURNS SETOF public.engineer_distribution_action_log_r2080
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_distribution_action_log_r2080
    WHERE dist_id = p_dist_id
    ORDER BY taken_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r2080(
  p_dist_id uuid,
  p_action_type text,
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
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_distribution_action_log_r2080(dist_id, action_type, by_email, notes_md)
  VALUES (p_dist_id, p_action_type, p_by_email, p_notes_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_action_r2080',
    jsonb_build_object(
      'id', v_id,
      'dist_id', p_dist_id,
      'action', p_action_type,
      'by', p_by_email
    )
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_r2080(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('balanced','concentrated','skewed','critical') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.engineer_workload_distribution_r2080
    SET distribution_status = p_status, updated_at = now()
    WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r2080',
    jsonb_build_object('id', p_id, 'status', p_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.critical_distributions_r2080()
RETURNS SETOF public.engineer_workload_distribution_r2080
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_workload_distribution_r2080
    WHERE distribution_status = 'critical'
    ORDER BY captured_at DESC
    LIMIT 100;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_r2080(p_limit int DEFAULT 50)
RETURNS SETOF public.engineer_distribution_action_log_r2080
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT * FROM public.engineer_distribution_action_log_r2080
    ORDER BY taken_at DESC
    LIMIT COALESCE(p_limit, 50);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_distributions_r2080() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_distribution_r2080(text, text, int, int, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r2080(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r2080(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r2080(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.critical_distributions_r2080() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_actions_r2080(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_distributions_r2080() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_distribution_r2080(text, text, int, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r2080(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2080(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2080(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.critical_distributions_r2080() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2080(int) TO authenticated;

COMMIT;
